extends RefCounted

const Defs = preload("res://scripts/defs.gd")

var route = null
var level: Dictionary = {}
var friendlies: Array = []
var enemies: Array = []
var events: Array = []
var strikes: Array = []
var charges := {"smoke": 0, "airstrike": 0, "repair": 0}
var smoke_timer := 0.0
var time := 0.0
var lead_s := 0.0
var status := "running"
var kills := 0
var delivered := 0
var escorts_lost := 0
var cargo_total := 0
var ambush_spawned: Array = []
var finished_sent := false
var next_id := 1
var rng := RandomNumberGenerator.new()
var sandbox := false
var god_mode := false
var threat := 1.0
var ieds: Array = []
var fuel_clock := 0.0
var player_gun_id := -1
var charge_cap := {"smoke": 0, "airstrike": 0, "repair": 0}

func start(p_level: Dictionary, roster: Array, p_route, combat_seed: int) -> void:
	level = p_level
	route = p_route
	friendlies.clear()
	enemies.clear()
	events.clear()
	strikes.clear()
	ambush_spawned.clear()
	for _i in level["ambushes"]:
		ambush_spawned.append(false)
	rng.seed = combat_seed
	time = 0.0
	lead_s = 0.0
	status = "running"
	kills = 0
	delivered = 0
	escorts_lost = 0
	cargo_total = 0
	finished_sent = false
	next_id = 1
	var src: Dictionary = level["charges"]
	charges = {
		"smoke": int(src["smoke"]),
		"airstrike": int(src["airstrike"]),
		"repair": int(src["repair"]),
	}
	smoke_timer = 0.0
	fuel_clock = 0.0
	player_gun_id = -1
	ieds.clear()
	charge_cap = {
		"smoke": int(src["smoke"]),
		"airstrike": int(src["airstrike"]),
		"repair": int(src["repair"]),
	}
	for spec in level.get("ieds", []):
		if typeof(spec) != TYPE_DICTIONARY:
			continue
		var mine_at := float(spec.get("at", 0.0))
		var sm_m: Dictionary = route.sample(mine_at)
		var mine_pos: Vector3 = sm_m["pos"] + sm_m["right"] * float(spec.get("lat", 0.0))
		ieds.append({
			"pos": mine_pos,
			"live": true,
			"warn": false,
			"fuse": 1.15,
		})
	for i in roster.size():
		var entry = roster[i]
		if typeof(entry) == TYPE_DICTIONARY:
			_add_friendly(
				str(entry["kind"]),
				Defs.unit_along(entry),
				Defs.unit_lateral(entry),
				float(entry.get("yaw", 0.0)),
				int(entry.get("armor", 0)),
				int(entry.get("weapon", 0)),
				int(entry.get("speed", 0))
			)
		else:
			_add_friendly(str(entry), -float(i) * Defs.SPACING, 0.0, 0.0, 0, 0, 0)


func tick(dt: float) -> void:
	if status != "running":
		return
	time += dt
	smoke_timer = maxf(0.0, smoke_timer - dt)
	for strike in strikes:
		strike["eta"] = float(strike["eta"]) - dt
	_move_friendlies(dt)
	_spawn_ambushes()
	_move_enemies(dt)
	_separate_enemies()
	_acquire_targets()
	_passive_repairs(dt)
	_tick_fuel(dt)
	_tick_ieds(dt)
	_friendly_fire(dt)
	_enemy_fire(dt)
	_resolve_strikes()
	_cleanup()
	_check_end()


func try_ability(ability: String) -> bool:
	if status != "running":
		return false
	if ability_hint(ability) != "":
		return false
	if ability == "smoke":
		charges["smoke"] = int(charges["smoke"]) - 1
		var dur := 7.5
		if _living_role("fuel"):
			dur *= 1.5
		smoke_timer = dur
		events.append({"type": "ability", "name": "smoke"})
		return true
	if ability == "repair":
		for u in friendlies:
			if u["alive"] and not u["delivered"] and float(u["hp"]) < float(u["max_hp"]) - 4.0:
				u["hp"] = minf(float(u["max_hp"]), float(u["hp"]) + 34.0)
		charges["repair"] = int(charges["repair"]) - 1
		events.append({"type": "ability", "name": "repair"})
		return true
	if ability == "airstrike":
		var p: Vector3 = _strike_point()
		charges["airstrike"] = int(charges["airstrike"]) - 1
		strikes.append({
			"pos": p,
			"eta": 1.15,
			"radius": 14.0,
			"dmg": 74.0,
			"boom": false,
		})
		events.append({"type": "ability", "name": "airstrike", "pos": p})
		return true
	return false


func ability_hint(ability: String) -> String:
	if int(charges.get(ability, 0)) <= 0:
		return "No charges left"
	if ability == "airstrike" and _strike_point() == null:
		return "No hostiles in range"
	if ability == "repair" and not _anyone_hurt():
		return "Column is healthy"
	return ""


func cargo_health_ratio() -> float:
	var hp := 0.0
	var mx := 0.0
	for u in friendlies:
		if u["role"] != "cargo" or u["delivered"]:
			continue
		mx += float(u["max_hp"])
		if u["alive"]:
			hp += maxf(float(u["hp"]), 0.0)
	if mx <= 0.0:
		return 1.0
	return hp / mx


func column_health_ratio() -> float:
	var hp := 0.0
	var mx := 0.0
	for u in friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		hp += maxf(float(u["hp"]), 0.0)
		mx += float(u["max_hp"])
	if mx <= 0.0:
		return 0.0
	return hp / mx


func hostiles_within(radius: float) -> int:
	var n := 0
	for e in enemies:
		if not e["alive"]:
			continue
		if _near_column(e["pos"], radius):
			n += 1
	return n


func heavy_threats_within(radius: float) -> int:
	var n := 0
	for e in enemies:
		if not e["alive"]:
			continue
		if e["kind"] != "tank" and e["kind"] != "heli" and e["kind"] != "rpg":
			continue
		if _near_column(e["pos"], radius):
			n += 1
	return n


func living_hostiles() -> int:
	var n := 0
	for e in enemies:
		if e["alive"]:
			n += 1
	return n


func progress() -> float:
	if route == null or route.total <= 0.0:
		return 0.0
	return clampf(lead_s / route.total, 0.0, 1.0)


func _add_friendly(kind: String, along: float, lateral: float = 0.0, yaw: float = 0.0, armor: int = 0, weapon: int = 0, speed_lv: int = 0) -> void:
	var spec: Dictionary = Defs.UNITS[kind]
	var stats: Dictionary = Defs.scaled(kind, armor, weapon, speed_lv)
	var u := {
		"id": next_id,
		"kind": kind,
		"role": spec["role"],
		"hp": float(stats["hp"]),
		"max_hp": float(stats["hp"]),
		"dmg": float(stats["dmg"]),
		"range": float(spec["rng"]),
		"speed": float(stats["spd"]),
		"rof": float(spec["rof"]),
		"heal": float(spec["heal"]),
		"s": along,
		"lateral": lateral,
		"yaw": yaw,
		"armor": armor,
		"weapon": weapon,
		"speed_lv": speed_lv,
		"air": bool(spec.get("air", false)),
		"alt": float(spec.get("alt", 0.0)),
		"pos": Vector3.ZERO,
		"dir": Vector3(0, 0, 1),
		"cooldown": 0.0,
		"alive": true,
		"delivered": false,
		"credited": false,
		"target_id": -1,
		"moving": true,
	}
	next_id += 1
	if kind == "cargo":
		cargo_total += 1
	_place_friendly(u)
	friendlies.append(u)


func _place_friendly(u) -> void:
	var sm: Dictionary = route.sample(float(u["s"]))
	u["pos"] = sm["pos"] + sm["right"] * float(u.get("lateral", 0.0))
	if bool(u.get("air", false)):
		u["pos"].y = float(u.get("alt", 12.0))
	var dir: Vector3 = sm["dir"]
	var yaw := deg_to_rad(float(u.get("yaw", 0.0)))
	if absf(yaw) > 0.001:
		dir = Basis(Vector3.UP, yaw) * dir
	u["dir"] = dir


func _living_role(role: String) -> bool:
	for u in friendlies:
		if u["alive"] and not u["delivered"] and str(u["role"]) == role:
			return true
	return false


func _tick_fuel(dt: float) -> void:
	if not _living_role("fuel"):
		return
	fuel_clock += dt
	if fuel_clock < 22.0:
		return
	fuel_clock = 0.0
	var best := ""
	var best_n := 99
	for key in ["smoke", "repair", "airstrike"]:
		var n := int(charges.get(key, 0))
		var cap := int(charge_cap.get(key, 0))
		if n < cap and n < best_n:
			best_n = n
			best = key
	if best == "":
		return
	charges[best] = int(charges[best]) + 1
	events.append({"type": "ability", "name": "fuel"})


func _tick_ieds(dt: float) -> void:
	for mine in ieds:
		if not bool(mine["live"]):
			continue
		var pos: Vector3 = mine["pos"]
		var found := false
		var eng_d := 28.0
		for u in friendlies:
			if not u["alive"] or u["delivered"] or str(u["role"]) != "engineer":
				continue
			var d := Vector2(u["pos"].x, u["pos"].z).distance_to(Vector2(pos.x, pos.z))
			if d < eng_d:
				eng_d = d
				found = true
		if found:
			mine["warn"] = true
			mine["fuse"] = float(mine["fuse"]) - dt
			if float(mine["fuse"]) <= 0.0:
				mine["live"] = false
				events.append({"type": "ied", "action": "clear", "pos": pos})
			continue
		for u in friendlies:
			if not u["alive"] or u["delivered"] or bool(u.get("air", false)):
				continue
			if Vector2(u["pos"].x, u["pos"].z).distance_to(Vector2(pos.x, pos.z)) > 3.3:
				continue
			mine["live"] = false
			events.append({"type": "ied", "action": "boom", "pos": pos})
			for v in friendlies:
				if not v["alive"] or v["delivered"] or bool(v.get("air", false)):
					continue
				var blast := Vector2(v["pos"].x, v["pos"].z).distance_to(Vector2(pos.x, pos.z))
				if blast > 7.0 or god_mode:
					continue
				v["hp"] = float(v["hp"]) - 46.0 * (1.0 - blast / 7.0)
				if float(v["hp"]) <= 0.0:
					v["hp"] = 0.0
					v["alive"] = false
			break


func _move_friendlies(dt: float) -> void:
	var pace := _pace()
	for u in friendlies:
		if not u["alive"] or u["delivered"]:
			u["moving"] = false
			_place_friendly(u)
			continue
		u["s"] = float(u["s"]) + pace * dt
		u["moving"] = pace > 0.1
		if u["role"] == "cargo" and float(u["s"]) >= route.total:
			u["delivered"] = true
			u["moving"] = false
			u["s"] = route.total + 14.0
			delivered += 1
			events.append({"type": "delivered", "id": u["id"]})
		elif u["role"] != "cargo" and float(u["s"]) > route.total:
			u["s"] = route.total
			u["moving"] = false
		_place_friendly(u)
		if u["alive"] and not u["delivered"]:
			lead_s = maxf(lead_s, minf(float(u["s"]), route.total))


func _pace() -> float:
	var sum := 0.0
	var n := 0
	for u in friendlies:
		if u["alive"] and not u["delivered"]:
			sum += float(u["speed"])
			n += 1
	if n == 0:
		return 0.0
	return clampf(sum / float(n), 8.5, 13.5)


func _spawn_ambushes() -> void:
	var ambushes: Array = level["ambushes"]
	for i in ambushes.size():
		if ambush_spawned[i]:
			continue
		var amb: Dictionary = ambushes[i]
		if lead_s < float(amb["at"]):
			continue
		ambush_spawned[i] = true
		events.append({"type": "banner", "text": str(amb["banner"])})
		for sp in amb["units"]:
			_spawn_enemy(sp, float(amb["at"]))


func spawn_at(kind: String, pos: Vector3) -> bool:
	if status != "running" or not Defs.ENEMIES.has(kind):
		return false
	var spec: Dictionary = Defs.ENEMIES[kind]
	var air: bool = bool(spec["air"])
	var placed := Vector3(pos.x, float(spec["alt"]) if air else 0.0, pos.z)
	_append_enemy(kind, spec, placed)
	events.append({"type": "banner", "text": "Contact — %s" % str(spec["name"])})
	return true


func _spawn_enemy(sp: Dictionary, at: float) -> void:
	var kind := str(sp["k"])
	var spec: Dictionary = Defs.ENEMIES[kind]
	var along := at + float(sp.get("ahead", 0.0))
	var sm: Dictionary = route.sample(along)
	var lateral := float(sp["lat"]) * float(sp["side"])
	var pos: Vector3 = sm["pos"] + sm["right"] * lateral
	var air: bool = bool(spec["air"])
	pos.y = float(spec["alt"]) if air else 0.0
	_append_enemy(kind, spec, pos)


func _append_enemy(kind: String, spec: Dictionary, pos: Vector3) -> void:
	var scale := maxf(threat, 0.15)
	var hp := float(spec["hp"]) * scale
	var e := {
		"id": next_id,
		"kind": kind,
		"hp": hp,
		"max_hp": hp,
		"dmg": float(spec["dmg"]) * scale,
		"range": float(spec["rng"]),
		"speed": float(spec["spd"]),
		"rof": float(spec["rof"]),
		"air": bool(spec["air"]),
		"alt": float(spec["alt"]),
		"pos": pos,
		"cooldown": rng.randf_range(0.25, 0.7),
		"alive": true,
		"credited": false,
		"target_id": -1,
		"strafe": 1.0 if rng.randf() > 0.5 else -1.0,
	}
	next_id += 1
	enemies.append(e)


func _move_enemies(dt: float) -> void:
	for e in enemies:
		if not e["alive"]:
			continue
		var pos: Vector3 = e["pos"]
		var tgt = _nearest_column_unit(pos, true)
		if tgt == null:
			continue
		var tp: Vector3 = tgt["pos"]
		if e["air"]:
			var flat := Vector3(tp.x - pos.x, 0.0, tp.z - pos.z)
			var dist := flat.length()
			var hold: float = float(e["range"]) * 0.7
			if dist > hold and dist > 0.1:
				pos += flat.normalized() * minf(float(e["speed"]) * dt, dist - hold)
			else:
				var side := Vector3(flat.z, 0.0, -flat.x)
				if side.length() > 0.1:
					pos += side.normalized() * float(e["strafe"]) * float(e["speed"]) * 0.35 * dt
			pos.y = float(e["alt"])
		else:
			var flat2 := Vector3(tp.x - pos.x, 0.0, tp.z - pos.z)
			var dist2 := flat2.length()
			var hold2: float = float(e["range"]) * 0.78
			if dist2 > hold2 and dist2 > 0.1:
				var step: float = minf(float(e["speed"]) * dt, dist2 - hold2)
				pos += flat2.normalized() * step
			pos.y = 0.0
		e["pos"] = pos


func _separate_enemies() -> void:
	for i in enemies.size():
		var e = enemies[i]
		if not e["alive"] or e["air"]:
			continue
		var ep: Vector3 = e["pos"]
		for j in range(i + 1, enemies.size()):
			var o = enemies[j]
			if not o["alive"] or o["air"]:
				continue
			var op: Vector3 = o["pos"]
			var d := Vector3(ep.x - op.x, 0.0, ep.z - op.z)
			var len := d.length()
			if len < 2.4 and len > 0.001:
				var push := d.normalized() * (2.4 - len) * 0.5
				ep += push
				op -= push
				o["pos"] = op
		e["pos"] = ep


func _acquire_targets() -> void:
	for u in friendlies:
		if not u["alive"] or u["delivered"] or float(u["dmg"]) <= 0.0:
			u["target_id"] = -1
			continue
		var best = _best_enemy_for(u)
		u["target_id"] = best["id"] if best != null else -1
	for e in enemies:
		if not e["alive"]:
			e["target_id"] = -1
			continue
		var best_f = _best_friendly_for(e)
		e["target_id"] = best_f["id"] if best_f != null else -1


func _passive_repairs(dt: float) -> void:
	for u in friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		if u["role"] != "repair" and u["role"] != "medic":
			continue
		var best = null
		var best_score := 0.0
		for v in friendlies:
			if v["id"] == u["id"] or not v["alive"] or v["delivered"]:
				continue
			if u["pos"].distance_to(v["pos"]) > float(u["range"]):
				continue
			var missing: float = float(v["max_hp"]) - float(v["hp"])
			if v["role"] == "cargo":
				missing += 20.0
			if missing > best_score:
				best_score = missing
				best = v
		if best != null and best_score > 0.5:
			best["hp"] = minf(float(best["max_hp"]), float(best["hp"]) + float(u["heal"]) * dt)


func _friendly_fire(dt: float) -> void:
	for u in friendlies:
		if not u["alive"] or u["delivered"] or float(u["dmg"]) <= 0.0:
			continue
		u["cooldown"] = maxf(0.0, float(u["cooldown"]) - dt)
		if int(u["id"]) == player_gun_id:
			continue
		if float(u["cooldown"]) > 0.0:
			continue
		var tgt = _find_enemy(int(u["target_id"]))
		if tgt == null or not tgt["alive"]:
			continue
		var dst: Vector3 = tgt["pos"]
		if u["pos"].distance_to(dst) > float(u["range"]):
			continue
		var mult := Defs.air_multiplier(str(u["role"]), bool(tgt["air"]))
		if mult <= 0.0:
			continue
		var profile := "light"
		if u["role"] == "heavy":
			profile = "heavy"
		elif u["role"] == "aa":
			profile = "aa"
		elif u["role"] == "medium":
			profile = "medium"
		if u["role"] == "artillery":
			profile = "heavy"
		var lift := 0.2 if bool(tgt["air"]) else 1.0
		var origin_y := float(u.get("alt", 0.0)) + 1.2 if bool(u.get("air", false)) else 1.35
		_fire(u, tgt, u["pos"] + Vector3(0, origin_y, 0), dst + Vector3(0, lift, 0), float(u["dmg"]) * mult, profile, "friendly", 0.84)
		if u["role"] == "artillery":
			for other in enemies:
				if other == tgt or not other["alive"]:
					continue
				var splash := Vector2(other["pos"].x, other["pos"].z).distance_to(Vector2(dst.x, dst.z))
				if splash > 6.5:
					continue
				other["hp"] = float(other["hp"]) - float(u["dmg"]) * 0.38
				if float(other["hp"]) <= 0.0:
					other["hp"] = 0.0
					other["alive"] = false


func player_shot(unit_id: int, src: Vector3, aim: Vector3, dmg: float, profile: String, rof: float, indirect: bool) -> bool:
	var attacker = _find_friendly(unit_id)
	if attacker == null or not attacker["alive"] or attacker["delivered"]:
		return false
	attacker["cooldown"] = 1.0 / maxf(rof, 0.05)
	var weapon := "bullet"
	if profile == "aa":
		weapon = "aa"
	elif profile == "heavy":
		weapon = "shell"
	if indirect:
		events.append({
			"type": "tracer",
			"a": src,
			"b": aim,
			"profile": profile,
			"team": "friendly",
			"hit": true,
			"weapon": weapon,
			"target_kind": "",
		})
		var splashed := false
		for e in enemies:
			if not e["alive"]:
				continue
			var blast: float = Vector2(e["pos"].x, e["pos"].z).distance_to(Vector2(aim.x, aim.z))
			if blast > 6.5:
				continue
			var fall := 1.0 - blast / 6.5
			e["hp"] = float(e["hp"]) - dmg * (0.45 + 0.55 * fall)
			if float(e["hp"]) <= 0.0:
				e["hp"] = 0.0
				e["alive"] = false
			splashed = true
		return splashed
	var dir := aim - src
	if dir.length() < 0.2:
		return false
	dir = dir.normalized()
	var reach := src.distance_to(aim)
	var best = null
	var best_t := reach + 1.0
	for e in enemies:
		if not e["alive"]:
			continue
		var lift := 1.2 if bool(e["air"]) else 1.0
		var body := Vector3(e["pos"].x, e["pos"].y + lift, e["pos"].z)
		var to := body - src
		var t := to.dot(dir)
		if t < 1.2 or t > reach + 0.4:
			continue
		var closest := src + dir * t
		var miss := closest.distance_to(body)
		var radius := 1.45
		if bool(e["air"]):
			radius = 2.4
		if miss > radius or t >= best_t:
			continue
		best_t = t
		best = e
	var end := aim
	var hit := best != null
	if hit:
		var hit_lift := 1.2 if bool(best["air"]) else 1.0
		end = Vector3(best["pos"].x, best["pos"].y + hit_lift, best["pos"].z)
	events.append({
		"type": "tracer",
		"a": src,
		"b": end,
		"profile": profile,
		"team": "friendly",
		"hit": hit,
		"weapon": weapon,
		"target_kind": str(best["kind"]) if hit else "",
	})
	if not hit:
		return false
	var mult := Defs.air_multiplier(str(attacker["role"]), bool(best["air"]))
	if mult <= 0.0:
		return false
	best["hp"] = float(best["hp"]) - dmg * mult * rng.randf_range(0.96, 1.04)
	if float(best["hp"]) <= 0.0:
		best["hp"] = 0.0
		best["alive"] = false
	return true


func _enemy_fire(dt: float) -> void:
	for e in enemies:
		if not e["alive"]:
			continue
		e["cooldown"] = maxf(0.0, float(e["cooldown"]) - dt)
		if float(e["cooldown"]) > 0.0:
			continue
		var tgt = _find_friendly(int(e["target_id"]))
		if tgt == null or not tgt["alive"] or tgt["delivered"]:
			continue
		var dst: Vector3 = tgt["pos"]
		if e["pos"].distance_to(dst) > float(e["range"]):
			continue
		var accuracy := 0.26 if smoke_timer > 0.0 else 0.78
		var profile := "light"
		if e["kind"] == "tank" or e["kind"] == "rpg":
			profile = "heavy"
		var src: Vector3 = e["pos"] + Vector3(0, 0.4 if e["air"] else 1.1, 0)
		_fire(e, tgt, src, dst + Vector3(0, 1.1, 0), float(e["dmg"]), profile, "enemy", accuracy)


func _fire(attacker, target, src: Vector3, dst: Vector3, dmg: float, profile: String, team: String, accuracy: float) -> void:
	attacker["cooldown"] = 1.0 / maxf(float(attacker["rof"]), 0.05)
	var hit := rng.randf() <= accuracy
	var aim := dst
	if not hit:
		aim = dst + Vector3(rng.randf_range(-3.5, 3.5), rng.randf_range(-0.4, 1.4), rng.randf_range(-3.5, 3.5))
	var weapon := "bullet"
	if profile == "aa":
		weapon = "aa"
	elif profile == "heavy":
		weapon = "shell"
	if str(attacker.get("kind", "")) == "rpg":
		weapon = "rocket"
	events.append({
		"type": "tracer",
		"a": src,
		"b": aim if not hit else dst,
		"profile": profile,
		"team": team,
		"hit": hit,
		"weapon": weapon,
		"target_kind": str(target.get("kind", "")),
	})
	if not hit or (god_mode and team == "enemy"):
		return
	target["hp"] = float(target["hp"]) - dmg * rng.randf_range(0.92, 1.08)
	if float(target["hp"]) <= 0.0:
		target["hp"] = 0.0
		target["alive"] = false


func _resolve_strikes() -> void:
	for strike in strikes:
		if strike["boom"]:
			continue
		if float(strike["eta"]) > 0.0:
			continue
		strike["boom"] = true
		var pos: Vector3 = strike["pos"]
		var radius := float(strike["radius"])
		var dmg := float(strike["dmg"])
		for e in enemies:
			if not e["alive"]:
				continue
			var d := Vector2(e["pos"].x, e["pos"].z).distance_to(Vector2(pos.x, pos.z))
			if d > radius:
				continue
			var fall := 1.0 - d / radius
			e["hp"] = float(e["hp"]) - dmg * (0.5 + 0.5 * fall)
			if float(e["hp"]) <= 0.0:
				e["hp"] = 0.0
				e["alive"] = false
		events.append({"type": "boom", "pos": pos, "big": true, "strike": true})


func _cleanup() -> void:
	for e in enemies:
		if not e["alive"] and not e["credited"]:
			e["credited"] = true
			kills += 1
			events.append({"type": "dead", "team": "enemy", "kind": e["kind"], "pos": e["pos"], "air": e["air"]})
	for u in friendlies:
		if not u["alive"] and not u["credited"]:
			u["credited"] = true
			if u["role"] != "cargo":
				escorts_lost += 1
			events.append({
				"type": "dead",
				"team": "friendly",
				"kind": u["kind"],
				"role": u["role"],
				"pos": u["pos"],
				"air": false,
			})


func _check_end() -> void:
	if status != "running":
		return
	var cargo_left := 0
	for u in friendlies:
		if u["role"] == "cargo" and u["alive"] and not u["delivered"]:
			cargo_left += 1
	if cargo_total == 0:
		status = "lost"
	elif cargo_left == 0:
		status = "won" if delivered > 0 else "lost"
	elif time > 240.0 and not sandbox:
		status = "lost"
	if status != "running" and not finished_sent:
		finished_sent = true
		events.append({"type": "finished", "status": status})


func _best_enemy_for(u) -> Variant:
	var best = null
	var best_score := -1.0e9
	for e in enemies:
		if not e["alive"]:
			continue
		var mult := Defs.air_multiplier(str(u["role"]), bool(e["air"]))
		if mult <= 0.0:
			continue
		var d: float = u["pos"].distance_to(e["pos"])
		if d > float(u["range"]):
			continue
		var score := mult * 120.0 - d + float(e["dmg"]) * 0.35
		if u["role"] == "aa" and e["air"]:
			score += 90.0
		if u["role"] != "aa" and not e["air"]:
			score += 18.0
		if score > best_score:
			best_score = score
			best = e
	return best


func _best_friendly_for(e) -> Variant:
	var best = null
	var best_score := -1.0e9
	for u in friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		var d: float = e["pos"].distance_to(u["pos"])
		if d > float(e["range"]):
			continue
		var score := -d
		if u["role"] == "cargo":
			score += 55.0
		elif u["role"] == "repair" or u["role"] == "medic" or u["role"] == "fuel":
			score += 10.0
		if str(e.get("kind", "")) == "spaa" and bool(u.get("air", false)):
			score += 80.0
		if score > best_score:
			best_score = score
			best = u
	return best


func _nearest_column_unit(pos: Vector3, prefer_cargo: bool):
	var best = null
	var best_d := 1.0e9
	for u in friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		var d: float = pos.distance_to(u["pos"])
		if prefer_cargo and u["role"] == "cargo":
			d -= 8.0
		if d < best_d:
			best_d = d
			best = u
	return best


func _near_column(pos: Vector3, radius: float) -> bool:
	for u in friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		if u["role"] == "cargo" and pos.distance_to(u["pos"]) <= radius:
			return true
	for u in friendlies:
		if u["alive"] and not u["delivered"] and pos.distance_to(u["pos"]) <= radius:
			return true
	return false


func _strike_point():
	var center := _column_center()
	var candidates: Array = []
	for e in enemies:
		if not e["alive"]:
			continue
		if e["pos"].distance_to(center) <= 85.0:
			candidates.append(e)
	if candidates.is_empty():
		return null
	var best: Vector3 = candidates[0]["pos"]
	var best_score := -1.0
	for e in candidates:
		var score := 0.0
		for o in candidates:
			if Vector2(e["pos"].x, e["pos"].z).distance_to(Vector2(o["pos"].x, o["pos"].z)) <= 12.0:
				score += 1.0
		if e["air"] or e["kind"] == "tank" or e["kind"] == "rpg":
			score += 2.0
		if score > best_score:
			best_score = score
			best = e["pos"]
	best.y = 0.0
	return best


func _column_center() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for u in friendlies:
		if u["alive"] and not u["delivered"]:
			c += u["pos"]
			n += 1
	if n == 0:
		return Vector3.ZERO
	return c / float(n)


func _anyone_hurt() -> bool:
	for u in friendlies:
		if u["alive"] and not u["delivered"] and float(u["hp"]) < float(u["max_hp"]) - 4.0:
			return true
	return false


func _find_enemy(id: int):
	if id < 0:
		return null
	for e in enemies:
		if int(e["id"]) == id:
			return e
	return null


func _find_friendly(id: int):
	if id < 0:
		return null
	for u in friendlies:
		if int(u["id"]) == id:
			return u
	return null
