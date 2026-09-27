extends RefCounted

const Defs = preload("res://scripts/defs.gd")
const RouteScript = preload("res://scripts/route.gd")
const SimScript = preload("res://scripts/battle_sim.gd")
const Autopilot = preload("res://scripts/autopilot.gd")

static func run() -> bool:
	var ok := true
	var levels := Defs.levels()
	for i in levels.size():
		var route = RouteScript.new(levels[i])
		print("Level %d route length %.1f  ambushes %d" % [i + 1, route.total, levels[i]["ambushes"].size()])
		for amb in levels[i]["ambushes"]:
			if float(amb["at"]) >= route.total:
				print("FAIL ambush beyond route on level %d" % (i + 1))
				ok = false

	print("--- campaign, quick column, no abilities ---")
	var bank := 500
	for i in levels.size():
		var roster: Array = Defs.recommended(i, bank)
		var result: Dictionary = _play(levels[i], roster, int(levels[i]["seed"]) + 100, false)
		var pay: Dictionary = Defs.payout(levels[i], int(result["delivered"]), int(result["kills"]), Defs.roster_cost(roster))
		print("L%d %-12s roster=%s cost=%d %s delivered=%d/%d kills=%d cargo_hp=%.0f escorts_lost=%d t=%.1f bank %d -> %d" % [
			i + 1, levels[i]["name"], str(Defs.roster_kinds(roster)), Defs.roster_cost(roster), result["status"],
			result["delivered"], result["cargo_total"], result["kills"], result["cargo_hp"],
			result["escorts_lost"], result["time"], bank, bank + int(pay["net"]),
		])
		if result["status"] != "won":
			ok = false
		if int(result["ambushes"]) != levels[i]["ambushes"].size():
			print("FAIL not all ambushes spawned (%d)" % int(result["ambushes"]))
			ok = false
		bank += int(pay["net"])

	print("--- campaign, quick column, autopilot abilities ---")
	bank = 500
	for i in levels.size():
		var roster2: Array = Defs.recommended(i, bank)
		var result2: Dictionary = _play(levels[i], roster2, int(levels[i]["seed"]) + 100, true)
		var pay2: Dictionary = Defs.payout(levels[i], int(result2["delivered"]), int(result2["kills"]), Defs.roster_cost(roster2))
		print("L%d %s delivered=%d/%d kills=%d cargo_hp=%.0f grade=%s" % [
			i + 1, result2["status"], result2["delivered"], result2["cargo_total"],
			result2["kills"], result2["cargo_hp"],
			Defs.grade(result2["status"] == "won", int(result2["delivered"]), int(result2["cargo_total"]), int(result2["escorts_lost"])),
		])
		if result2["status"] != "won":
			ok = false
		for extra in [1, 2]:
			var alt: Dictionary = _play(levels[i], roster2, int(levels[i]["seed"]) + 100 + extra * 17, true)
			print("  seed+%d %s cargo_hp=%.0f delivered=%d" % [extra * 17, alt["status"], alt["cargo_hp"], alt["delivered"]])
			if alt["status"] != "won":
				ok = false
		bank += int(pay2["net"])

	print("--- maps, facing, and new kit ---")
	var seen := {}
	for level in levels:
		seen[str(level["biome"])] = true
		if float(level["length"]) < 400.0:
			print("FAIL short route %s" % level["name"])
			ok = false
	for need in ["desert", "forest", "mountain", "arctic", "urban", "jungle"]:
		if not seen.has(need):
			print("FAIL missing biome %s" % need)
			ok = false
	var urban: Dictionary = levels[4]
	if int(urban.get("ieds", []).size()) < 2:
		print("FAIL urban IEDs")
		ok = false
	var MeshLib = preload("res://scripts/mesh_lib.gd")
	var lib = MeshLib.new()
	for kind in Defs.CARD_ORDER:
		var node: Node3D = lib.build(str(kind), false, "woodland")
		var nose := node.find_child("nose", true, false) as Node3D
		if nose == null:
			print("FAIL %s has no nose" % kind)
			ok = false
			continue
		var p := Vector3.ZERO
		var walker: Node = nose
		while walker is Node3D and walker != node:
			p = (walker as Node3D).transform * p
			walker = walker.get_parent()
		if p.z > -0.4 or absf(p.x) > absf(p.z) * 0.45:
			print("FAIL %s faces off axis x=%.2f z=%.2f" % [kind, p.x, p.z])
			ok = false
	var ied_level: Dictionary = levels[0].duplicate(true)
	ied_level["ambushes"] = []
	ied_level["length"] = 120.0
	ied_level["ieds"] = [{"at": 40.0, "lat": 0.0}]
	var bare = SimScript.new()
	var ied_route = RouteScript.new(ied_level)
	bare.start(ied_level, [Defs.make_unit("cargo", Defs.CENTER, 2)], ied_route, 3)
	for _n in 180:
		bare.tick(1.0 / 30.0)
	if bare.friendlies[0]["hp"] >= float(bare.friendlies[0]["max_hp"]) - 5.0:
		print("FAIL IED did not damage cargo")
		ok = false
	var cleared = SimScript.new()
	cleared.start(ied_level, [Defs.make_unit("engineer", Defs.CENTER, 0), Defs.make_unit("cargo", Defs.CENTER, 3)], ied_route, 4)
	for _n2 in 180:
		cleared.tick(1.0 / 30.0)
	if cleared.ieds.size() == 0 or bool(cleared.ieds[0]["live"]):
		print("FAIL engineer did not clear IED")
		ok = false
	if cleared.friendlies[1]["hp"] < float(cleared.friendlies[1]["max_hp"]) - 5.0:
		print("FAIL cargo took a cleared IED")
		ok = false

	var gun_level: Dictionary = levels[0].duplicate(true)
	gun_level["ambushes"] = []
	gun_level["length"] = 80.0
	var gun_route = RouteScript.new(gun_level)
	var held = SimScript.new()
	held.start(gun_level, [Defs.make_unit("humvee", Defs.CENTER, 0)], gun_route, 9)
	held.player_gun_id = int(held.friendlies[0]["id"])
	var ahead: Vector3 = gun_route.sample(24.0)["pos"]
	held.spawn_at("infantry", ahead)
	var hp_before := float(held.enemies[0]["hp"])
	for _g in 50:
		held.tick(1.0 / 30.0)
	if float(held.enemies[0]["hp"]) < hp_before - 0.5:
		print("FAIL AI fired while the player was gunning")
		ok = false
	var src: Vector3 = held.friendlies[0]["pos"] + Vector3(0, 1.6, 0)
	var dst: Vector3 = held.enemies[0]["pos"] + Vector3(0, 1.0, 0)
	if not held.player_shot(int(held.friendlies[0]["id"]), src, dst, 9.0, "light", 8.0, false):
		print("FAIL player shot missed a lined-up target")
		ok = false
	if float(held.enemies[0]["hp"]) > hp_before - 1.0:
		print("FAIL player shot did no damage")
		ok = false

	print("--- grid formation holds lanes and upgrades scale ---")
	var wedge: Array = Defs.arrange(["humvee", "apc", "cargo"], "wedge")
	if wedge.size() != 3:
		print("FAIL wedge size")
		ok = false
	var lanes := {}
	for entry in wedge:
		lanes[int(entry["lane"])] = true
	if lanes.size() < 2:
		print("FAIL wedge did not use multiple lanes")
		ok = false
	var probe_level: Dictionary = levels[0]
	var probe_route = RouteScript.new(probe_level)
	var probe = SimScript.new()
	probe.start(probe_level, wedge, probe_route, 5)
	probe.tick(0.5)
	var lat0 := float(probe.friendlies[0]["lateral"])
	var lat1 := float(probe.friendlies[1]["lateral"])
	if absf(lat0 - lat1) < 2.0:
		print("FAIL formation collapsed lanes")
		ok = false
	var armored: Array = [Defs.make_unit("tank", 2, 1, 90, 2, 1, 1)]
	var armed = SimScript.new()
	armed.start(probe_level, armored, probe_route, 6)
	var base_hp := float(Defs.UNITS["tank"]["hp"])
	if float(armed.friendlies[0]["max_hp"]) <= base_hp:
		print("FAIL armor upgrade did not raise hp")
		ok = false
	if absf(float(armed.friendlies[0]["yaw"]) - 90.0) > 0.1:
		print("FAIL yaw was not kept")
		ok = false
	if Defs.entry_cost(armored[0]) <= Defs.cost("tank"):
		print("FAIL upgrade cost")
		ok = false
	print("grid lanes=%s armor_hp=%.0f yaw=%.0f" % [str(lanes.keys()), armed.friendlies[0]["max_hp"], armed.friendlies[0]["yaw"]])

	print("--- cargo only should lose ---")
	for i in levels.size():
		var lonely: Dictionary = _play(levels[i], Defs.arrange(["cargo", "cargo"], "line"), int(levels[i]["seed"]) + 100, true)
		print("L%d cargo-only %s delivered=%d" % [i + 1, lonely["status"], lonely["delivered"]])
		if lonely["status"] != "lost":
			ok = false

	print("--- sandbox god mode ignores enemy fire ---")
	var sand_level: Dictionary = levels[0].duplicate(true)
	sand_level["ambushes"] = []
	sand_level["charges"] = {"smoke": 1, "airstrike": 1, "repair": 1}
	var sand_route = RouteScript.new(sand_level)
	var sand = SimScript.new()
	sand.sandbox = true
	sand.god_mode = true
	sand.threat = 2.0
	sand.start(sand_level, [Defs.make_unit("cargo", Defs.CENTER, 2)], sand_route, 1107)
	var origin: Vector3 = sand.friendlies[0]["pos"]
	var spawned: bool = sand.spawn_at("tank", origin + Vector3(10, 0, 0))
	if not spawned:
		print("FAIL sandbox spawn")
		ok = false
	for _n in 90:
		sand.tick(1.0 / 30.0)
		sand.events.clear()
	var cargo_hp := float(sand.friendlies[0]["hp"])
	var tank_hp := float(sand.enemies[0]["max_hp"]) if sand.enemies.size() > 0 else 0.0
	if cargo_hp < float(sand.friendlies[0]["max_hp"]) - 0.01:
		print("FAIL god mode took damage %.1f" % cargo_hp)
		ok = false
	if tank_hp < 640.0:
		print("FAIL threat did not scale tank hp %.1f" % tank_hp)
		ok = false
	sand.time = 250.0
	sand.tick(1.0 / 30.0)
	if sand.status != "running":
		print("FAIL sandbox ended on the campaign timer (%s)" % sand.status)
		ok = false
	print("sandbox cargo_hp=%.0f tank_hp=%.0f status=%s" % [cargo_hp, tank_hp, sand.status])

	print("SIM CHECKS %s" % ("OK" if ok else "FAILED"))
	return ok


static func _play(level: Dictionary, roster: Array, combat_seed: int, use_abilities: bool) -> Dictionary:
	var route = RouteScript.new(level)
	var sim = SimScript.new()
	sim.start(level, roster, route, combat_seed)
	var guard := 0
	while sim.status == "running" and guard < 9000:
		if use_abilities:
			Autopilot.consider(sim)
		sim.tick(1.0 / 30.0)
		sim.events.clear()
		guard += 1
	var cargo_hp := 0.0
	for u in sim.friendlies:
		if u["role"] == "cargo" and (u["alive"] or u["delivered"]):
			cargo_hp += float(u["hp"])
	var spawned := 0
	for flag in sim.ambush_spawned:
		if flag:
			spawned += 1
	return {
		"status": sim.status,
		"delivered": sim.delivered,
		"cargo_total": sim.cargo_total,
		"kills": sim.kills,
		"escorts_lost": sim.escorts_lost,
		"time": sim.time,
		"cargo_hp": cargo_hp,
		"ambushes": spawned,
	}
