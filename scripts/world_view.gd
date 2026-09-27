extends Node3D

const Defs = preload("res://scripts/defs.gd")
const MeshLib = preload("res://scripts/mesh_lib.gd")

var meshes = MeshLib.new()
var cam: Camera3D
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env_node: WorldEnvironment
var level_root: Node3D
var menu_root: Node3D
var preview_root: Node3D
var unit_root: Node3D
var fx_root: Node3D
var route = null
var biome := "desert"
var slot_bodies: Array = []
var slot_pads: Array = []
var unit_nodes := {}
var yaw := 0.2
var pitch := 0.62
var dist := 34.0
var focus := Vector3.ZERO
var travel_dir := Vector3(0, 0, 1)
var cam_ready := false
var camera_mode := "menu"
var gunner_id := -1
var gunner_yaw := 0.0
var gunner_pitch := 0.0
var shake := 0.0
var menu_spin := 0.0
var smoke_puffs: Array = []
var rings: Array = []
var fx_items: Array = []
var pad_empty: StandardMaterial3D
var pad_hover: StandardMaterial3D
var pad_bad: StandardMaterial3D
var pad_filled: StandardMaterial3D
var pad_select: StandardMaterial3D
var cell_pad := {}
var ghost: Node3D
var smoke_clouds := {}
var scorch_count := 0
var shadows_on := true
var land_seed := 1
var grade := PackedFloat32Array()
var grade_bridge := PackedByteArray()
var grade_origin := -64.0
var grade_step := 8.0
var water_y := -3.0
var ground_grain: Texture2D
var mountain_grain: Texture2D
var desert_grain: Texture2D
var forest_grain: Texture2D
var ground_normal: Texture2D

func setup() -> void:
	pad_empty = _pad_mat(Color(0.78, 0.66, 0.38, 0.55))
	pad_hover = _pad_mat(Color(0.35, 0.62, 0.32, 0.9))
	pad_bad = _pad_mat(Color(0.62, 0.24, 0.18, 0.9))
	pad_filled = _pad_mat(Color(0.28, 0.32, 0.18, 1))
	pad_select = _pad_mat(Color(0.78, 0.64, 0.28, 1))
	env_node = WorldEnvironment.new()
	add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -32, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.35
	sun.shadow_normal_bias = 3.0
	sun.shadow_blur = 1.05
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 150, 0)
	fill.light_energy = 0.38
	fill.light_color = Color(0.75, 0.82, 0.95)
	fill.shadow_enabled = false
	add_child(fill)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 58.0
	cam.near = 0.15
	cam.far = 900.0
	add_child(cam)
	level_root = Node3D.new()
	add_child(level_root)
	preview_root = Node3D.new()
	add_child(preview_root)
	unit_root = Node3D.new()
	add_child(unit_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	show_menu()


func set_shadows(enabled: bool) -> void:
	shadows_on = enabled
	if sun:
		sun.shadow_enabled = enabled


func show_menu() -> void:
	camera_mode = "menu"
	cam_ready = false
	_clear_level()
	if menu_root:
		menu_root.queue_free()
	menu_root = Node3D.new()
	add_child(menu_root)
	_apply_biome("desert")
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 18
	disc.bottom_radius = 18
	disc.height = 0.4
	disc.radial_segments = 8
	ground.mesh = disc
	ground.position = Vector3(0, -0.2, 0)
	ground.material_override = meshes.mat(Color("b08958"))
	meshes.scheme = "desert"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	menu_root.add_child(ground)
	var truck := meshes.build("cargo")
	truck.position = Vector3(-1.2, 0, 0.4)
	truck.rotation_degrees = Vector3(0, 28, 0)
	menu_root.add_child(truck)
	var hum := meshes.build("humvee")
	hum.position = Vector3(2.4, 0, -1.6)
	hum.rotation_degrees = Vector3(0, -18, 0)
	menu_root.add_child(hum)
	var tank := meshes.build("tank")
	tank.position = Vector3(0.2, 0, 3.4)
	tank.rotation_degrees = Vector3(0, 12, 0)
	tank.scale = Vector3(0.82, 0.82, 0.82)
	menu_root.add_child(tank)
	for i in 4:
		var rock := meshes.prop("rock" if i % 2 == 0 else "rock_b")
		rock.position = Vector3(-5.2 + float(i) * 1.15, 0.0, 4.8)
		rock.scale = Vector3.ONE * (0.7 + float(i) * 0.08)
		menu_root.add_child(rock)
	var palm := meshes.prop("palm")
	palm.position = Vector3(-4.6, 0, -3.2)
	palm.scale = Vector3.ONE * 1.15
	menu_root.add_child(palm)


func show_level(level: Dictionary, p_route) -> void:
	camera_mode = "build"
	cam_ready = false
	yaw = 0.4
	pitch = 0.95
	dist = 78.0
	route = p_route
	biome = str(level["biome"])
	land_seed = int(level["seed"])
	if menu_root:
		menu_root.queue_free()
		menu_root = null
	_clear_level()
	_apply_biome(biome)
	_build_terrain()
	_build_road()
	_build_props(int(level["seed"]))
	_build_gate(0.0, "START", Color("d7c07a"))
	_build_gate(route.total, "DROP", Color("7dcea0"))
	_build_slots()
	var sm: Dictionary = route.sample(-20.0)
	focus = sm["pos"]
	focus.y = road_height(-20.0)
	travel_dir = sm["dir"]


func show_formation(units: Array, camo: String, selected: int) -> void:
	if camo != "":
		meshes.scheme = camo
	for c in preview_root.get_children():
		c.free()
	ghost = null
	if route == null:
		return
	for pad in cell_pad.values():
		(pad as MeshInstance3D).material_override = pad_empty
	var sel_lane := -1
	var sel_row := -1
	if selected >= 0 and selected < units.size():
		sel_lane = int(units[selected]["lane"])
		sel_row = int(units[selected]["row"])
	for i in units.size():
		var entry = units[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kind := str(entry.get("kind", ""))
		if kind == "":
			continue
		var lane := int(entry.get("lane", Defs.CENTER))
		var row := int(entry.get("row", Defs.CENTER))
		var yaw_deg := int(entry.get("yaw", 0))
		var placed: Dictionary = pose_at(Defs.unit_along(entry), Defs.unit_lateral(entry), yaw_deg)
		var node := meshes.build(kind, false, camo)
		preview_root.add_child(node)
		node.position = placed["pos"]
		var face_dir: Vector3 = placed["dir"]
		_face_along(node, face_dir, float(placed["pitch"]))
		if i == selected:
			sel_lane = lane
			sel_row = row


func set_ghost(kind: String, along: float, lateral: float, ok: bool, camo: String) -> void:
	if kind == "" or along < -800.0 or route == null:
		if is_instance_valid(ghost):
			ghost.queue_free()
		ghost = null
		return
	if is_instance_valid(ghost) and str(ghost.get_meta("kind", "")) == kind:
		pass
	else:
		if is_instance_valid(ghost):
			ghost.queue_free()
		ghost = meshes.build(kind, false, camo)
		ghost.name = "ghost"
		ghost.set_meta("kind", kind)
		ghost.set_meta("ok", not ok)
		preview_root.add_child(ghost)
	if bool(ghost.get_meta("ok", true)) != ok:
		ghost.set_meta("ok", ok)
		_ghost_tint(ghost, ok)
	var placed: Dictionary = pose_at(along, lateral, 0)
	ghost.position = placed["pos"] + Vector3(0, 0.15, 0)
	var face_dir: Vector3 = placed["dir"]
	_face_along(ghost, face_dir, float(placed["pitch"]))


func set_cell_hover(cell: Vector2i, mode: String) -> void:
	for key in cell_pad.keys():
		var pad: MeshInstance3D = cell_pad[key]
		if pad.material_override == pad_filled or pad.material_override == pad_select:
			continue
		pad.material_override = pad_empty
	if cell.x < 0:
		return
	var key := _cell_key(cell.x, cell.y)
	if not cell_pad.has(key):
		return
	var hover_pad: MeshInstance3D = cell_pad[key]
	if hover_pad.material_override == pad_filled or hover_pad.material_override == pad_select:
		return
	if mode == "bad":
		hover_pad.material_override = pad_bad
	elif mode == "ok":
		hover_pad.material_override = pad_hover


func pick_cell(screen: Vector2) -> Vector2i:
	if cam == null or get_world_3d() == null:
		return Vector2i(-1, -1)
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 900.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	var body = hit["collider"]
	if body and body.has_meta("lane"):
		return Vector2i(int(body.get_meta("lane")), int(body.get_meta("row")))
	return Vector2i(-1, -1)


func show_column(slots: Array) -> void:
	show_formation(slots, meshes.scheme, -1)


func clear_actors() -> void:
	for c in unit_root.get_children():
		c.free()
	for c in fx_root.get_children():
		c.free()
	unit_nodes.clear()
	smoke_clouds.clear()
	rings.clear()
	fx_items.clear()
	scorch_count = 0


func pick_ground(screen: Vector2) -> Dictionary:
	if cam == null:
		return {"ok": false, "pos": Vector3.ZERO}
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var prev := origin
	var prev_ground := _height(prev.x, prev.z)
	for i in 140:
		var dist := 1.4 * float(i + 1)
		if dist > 420.0:
			break
		var p := origin + dir * dist
		var ground := _height(p.x, p.z)
		if prev.y >= prev_ground and p.y <= ground:
			return {"ok": true, "pos": Vector3(p.x, 0.0, p.z)}
		prev = p
		prev_ground = ground
	if absf(dir.y) < 0.02:
		return {"ok": false, "pos": Vector3.ZERO}
	var t := (focus.y - origin.y) / dir.y
	if t < 1.0 or t > 420.0:
		return {"ok": false, "pos": Vector3.ZERO}
	var hit := origin + dir * t
	return {"ok": true, "pos": Vector3(hit.x, 0.0, hit.z)}


func begin_drive() -> void:
	camera_mode = "drive"
	cam_ready = false
	yaw = 0.0
	pitch = 0.48
	dist = 28.0
	preview_root.visible = false
	for body in slot_bodies:
		body.visible = false


func sync(sim, dt: float) -> void:
	if sim == null:
		return
	var count := 0
	var acc := Vector3.ZERO
	var dir_acc := Vector3.ZERO
	var seen := {}
	for u in sim.friendlies:
		seen[int(u["id"])] = true
		var node := _ensure_actor(int(u["id"]), str(u["kind"]), false, 2.3 if u["role"] == "cargo" else 2.0, _friendly_bar_color(u))
		var pos: Vector3 = u["pos"]
		var gy := road_height(float(u["s"])) + 0.05
		if bool(u.get("air", false)):
			gy = _height(pos.x, pos.z) + float(u.get("alt", 12.0))
		elif absf(float(u.get("lateral", 0.0))) > 6.2:
			gy = _height(pos.x, pos.z) + 0.08
		node.position = Vector3(pos.x, gy, pos.z)
		var alive: bool = bool(u["alive"])
		if alive:
			var face_dir: Vector3 = u["dir"]
			var pitch := 0.0 if bool(u.get("air", false)) else _grade_pitch(float(u["s"]))
			_face_along(node, face_dir, pitch)
			_spin(node, dt, bool(u["moving"]) and not bool(u.get("air", false)))
			if bool(u.get("air", false)):
				var frotor := node.get_node_or_null("rotor")
				if frotor:
					frotor.rotate_y(dt * 18.0)
				var ftail := node.get_node_or_null("tail_rotor")
				if ftail:
					ftail.rotate_x(dt * 32.0)
			if int(u["id"]) == gunner_id:
				_apply_gunner_turret(node)
			else:
				_aim(node, u, sim, dt)
			_set_emitting(node, "dust", bool(u["moving"]) and not bool(u["delivered"]))
		else:
			_set_emitting(node, "dust", false)
		var ratio := float(u["hp"]) / maxf(float(u["max_hp"]), 1.0)
		_hp(node, ratio, alive)
		if not alive:
			_wreck(node)
		elif u["delivered"]:
			_mark_delivered(node)
		elif ratio < 0.42:
			_hurt(node)
		if u["alive"] and not u["delivered"]:
			acc += pos
			dir_acc += u["dir"]
			count += 1
	for e in sim.enemies:
		seen[int(e["id"])] = true
		var node_e := _ensure_actor(int(e["id"]), str(e["kind"]), true, 1.6 if e["kind"] == "infantry" or e["kind"] == "rpg" else 2.1, Color("e15b4c"))
		var enemy_pos: Vector3 = e["pos"]
		if bool(e["air"]):
			node_e.position = Vector3(enemy_pos.x, _height(enemy_pos.x, enemy_pos.z) + float(e["alt"]), enemy_pos.z)
		else:
			node_e.position = Vector3(enemy_pos.x, _height(enemy_pos.x, enemy_pos.z) + 0.04, enemy_pos.z)
		var enemy_alive: bool = bool(e["alive"])
		if enemy_alive:
			_spin(node_e, dt, not bool(e["air"]))
			_set_emitting(node_e, "dust", not bool(e["air"]))
		else:
			_set_emitting(node_e, "dust", false)
		if bool(e["air"]):
			var rotor := node_e.get_node_or_null("rotor")
			if rotor and enemy_alive:
				rotor.rotate_y(dt * 18.0)
			var tail := node_e.get_node_or_null("tail_rotor")
			if tail and enemy_alive:
				tail.rotate_x(dt * 32.0)
			var wash := node_e.get_node_or_null("wash")
			if wash is CPUParticles3D:
				(wash as CPUParticles3D).emitting = enemy_alive
		_hp(node_e, float(e["hp"]) / float(e["max_hp"]), bool(e["alive"]))
		if not e["alive"]:
			_wreck(node_e)
		elif count > 0:
			var flat := Vector3(focus.x - enemy_pos.x, 0.0, focus.z - enemy_pos.z)
			if flat.length() > 0.2:
				if bool(e["air"]):
					var aim := Vector3(focus.x, focus.y + 1.2, focus.z)
					if node_e.global_position.distance_to(aim) > 0.3:
						node_e.look_at(aim, Vector3.UP)
				else:
					_face_along(node_e, flat, _slope_pitch(node_e.position, flat.normalized()))
	if count > 0:
		focus = acc / float(count)
		if route != null:
			var focus_proj: Dictionary = route.project(focus)
			focus.y = road_height(float(focus_proj["dist"]))
		else:
			focus.y = 0.0
		if dir_acc.length() > 0.1:
			travel_dir = dir_acc.normalized()
	_sync_smoke(sim)
	_sync_strikes(sim)


func tick(dt: float) -> void:
	if camera_mode == "locked" or camera_mode == "gunner":
		return
	if camera_mode == "menu":
		menu_spin += dt * 0.25
		var radius := 11.5
		var eye := Vector3(sin(menu_spin) * radius, 4.4, cos(menu_spin) * radius)
		cam.global_position = eye
		cam.look_at(Vector3(0, 1.1, 0), Vector3.UP)
		if menu_root:
			var hum := menu_root.get_child_count()
			if hum > 2 and menu_root.get_child(2) is Node3D:
				pass
		return
	if camera_mode == "build":
		_frame_build(dt)
	elif camera_mode == "drive":
		_frame_drive(dt)
	_fade_fx(dt)


func on_event(ev: Dictionary) -> void:
	var kind := str(ev.get("type", ""))
	if kind == "tracer":
		var col := Color("f0d78a")
		if str(ev.get("team", "")) == "enemy":
			col = Color("ff6a45")
		elif str(ev.get("profile", "")) == "aa":
			col = Color("9ad7ff")
		elif str(ev.get("profile", "")) == "heavy":
			col = Color("ffb15a")
		if not bool(ev.get("hit", true)):
			col.a = 0.45
		_tracer(ev["a"], ev["b"], col, str(ev.get("weapon", "bullet")))
		if bool(ev.get("hit", true)):
			_impact(ev["b"], str(ev.get("weapon", "bullet")))
	elif kind == "boom":
		_explosion(ev["pos"], bool(ev.get("big", false)), bool(ev.get("strike", false)))
		shake = maxf(shake, 0.7 if bool(ev.get("strike", false)) else (0.55 if bool(ev.get("big", false)) else 0.25))
	elif kind == "dead":
		_explosion(ev["pos"], str(ev.get("kind", "")) == "tank" or str(ev.get("kind", "")) == "heli")
		shake = maxf(shake, 0.2)
	elif kind == "ability" and str(ev.get("name", "")) == "airstrike":
		shake = maxf(shake, 0.1)


func reset_camera() -> void:
	if camera_mode == "drive":
		yaw = 0.2
		pitch = 0.3
		dist = 40.0
	else:
		yaw = 0.55
		pitch = 0.78
		dist = 44.0


func _frame_build(dt: float) -> void:
	if route == null:
		return
	var sm: Dictionary = route.sample(36.0)
	var anchor: Vector3 = sm["pos"]
	anchor.y = road_height(-20.0) + 1.4
	var behind: Vector3 = -sm["dir"]
	var swung: Vector3 = Basis(Vector3.UP, yaw) * behind
	swung.y = 0.0
	if swung.length() < 0.01:
		swung = Vector3(0, 0, -1)
	swung = swung.normalized()
	var elev := clampf(pitch, 0.22, 1.2)
	var offset := swung * cos(elev) * dist + Vector3.UP * sin(elev) * dist
	_glide(_keep_above(anchor + offset), anchor, dt)


func _frame_drive(dt: float) -> void:
	var elev := clampf(pitch, 0.18, 1.15)
	var look := focus + Vector3(0, 2.6, 0)
	var eye := look
	if route != null:
		var proj: Dictionary = route.project(focus)
		var along := float(proj["dist"])
		var back_len := clampf(dist, 26.0, 62.0)
		var back_dist := along - back_len
		var sm: Dictionary = route.sample(back_dist)
		var side := clampf(yaw, -0.8, 0.8) * 6.0
		var pos: Vector3 = sm["pos"]
		var right: Vector3 = sm["right"]
		eye = pos + right * side
		var lift := clampf(9.0 + dist * 0.24, 14.0, 24.0)
		eye.y = road_height(back_dist) + lift
		var floor_y := _height(eye.x, eye.z) + 4.5
		if eye.y < floor_y:
			eye.y = floor_y
		var ahead: Dictionary = route.sample(along + 28.0)
		look = ahead["pos"]
		look.y = road_height(along + 28.0) + 2.2
	else:
		var back := -travel_dir
		if back.length() < 0.01:
			back = Vector3(0, 0, -1)
		back.y = 0.0
		back = back.normalized()
		eye = look + back * cos(elev) * dist + Vector3.UP * sin(elev) * dist
	_glide(eye, look, dt)


func _glide(pos: Vector3, look: Vector3, dt: float) -> void:
	if not cam_ready:
		cam.global_position = pos
		cam_ready = true
	else:
		var k := 1.0 - exp(-5.5 * dt)
		cam.global_position = cam.global_position.lerp(pos, k)
	if shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * shake * 0.4
		shake = maxf(0.0, shake - dt)
	cam.global_position = _keep_above(cam.global_position)
	if cam.global_position.distance_to(look) > 0.05:
		cam.look_at(look, Vector3.UP)


func _ensure_actor(id: int, kind: String, enemy: bool, bar_y: float, bar_color: Color) -> Node3D:
	if unit_nodes.has(id):
		return unit_nodes[id]
	var node: Node3D = meshes.build(kind, enemy)
	_attach_hp(node, bar_y, bar_color)
	unit_root.add_child(node)
	unit_nodes[id] = node
	return node


func _attach_hp(node: Node3D, y: float, color: Color) -> void:
	var hp := Node3D.new()
	hp.name = "hp"
	hp.position = Vector3(0, y, 0)
	node.add_child(hp)
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.35, 0.12, 0.06)
	bg.mesh = bm
	bg.material_override = meshes.mat(Color(0.05, 0.05, 0.05))
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp.add_child(bg)
	var fill := MeshInstance3D.new()
	fill.name = "fill"
	var fm := BoxMesh.new()
	fm.size = Vector3(1.25, 0.08, 0.07)
	fill.mesh = fm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	fill.material_override = m
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp.add_child(fill)


func _hp(node: Node3D, ratio: float, alive: bool) -> void:
	var hp := node.get_node_or_null("hp")
	if hp == null:
		return
	hp.visible = alive
	var fill := hp.get_node_or_null("fill")
	if fill == null:
		return
	var r := clampf(ratio, 0.0, 1.0)
	fill.scale.x = maxf(r, 0.001)
	fill.position.x = (r - 1.0) * 0.62
	if cam:
		hp.look_at(cam.global_position, Vector3.UP)


func _apply_gunner_turret(node: Node3D) -> void:
	var turret := node.get_node_or_null("turret") as Node3D
	if turret == null:
		return
	turret.rotation = Vector3(gunner_pitch, gunner_yaw, 0.0)
	var hp := node.get_node_or_null("hp")
	if hp:
		hp.visible = false


func pick_gun(screen: Vector2, sim) -> int:
	if cam == null or sim == null:
		return -1
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var best_id := -1
	var best_miss := 2.6
	for u in sim.friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		if Defs.gun_list(str(u["kind"])).is_empty():
			continue
		var body := Vector3(u["pos"].x, u["pos"].y + 1.5, u["pos"].z)
		var to := body - origin
		var t := to.dot(dir)
		if t < 3.0:
			continue
		var miss := (origin + dir * t).distance_to(body)
		if miss < best_miss:
			best_miss = miss
			best_id = int(u["id"])
	return best_id


func _aim(node: Node3D, u, sim, dt: float) -> void:
	var turret := node.get_node_or_null("turret")
	if turret == null or int(u["target_id"]) < 0:
		return
	var target = null
	for e in sim.enemies:
		if int(e["id"]) == int(u["target_id"]):
			target = e
			break
	if target == null:
		return
	var tp: Vector3 = target["pos"]
	var aim_y := _height(tp.x, tp.z) + (float(target["alt"]) if bool(target["air"]) else 1.1)
	var local_target: Vector3 = node.to_local(Vector3(tp.x, aim_y, tp.z))
	if local_target.length() < 0.2:
		return
	if absf(local_target.normalized().dot(Vector3.UP)) > 0.96:
		local_target.y *= 0.2
	var desired := Basis.looking_at(local_target, Vector3.UP)
	turret.basis = turret.basis.slerp(desired, clampf(dt * 8.0, 0.0, 1.0))


func _spin(node: Node3D, dt: float, moving: bool) -> void:
	if not moving:
		return
	for c in node.find_children("wheel*", "Node3D", true, false):
		if c is Node3D:
			(c as Node3D).rotate_x(dt * 10.0)


func _wreck(node: Node3D) -> void:
	if node.has_meta("wreck"):
		return
	node.set_meta("wreck", true)
	node.rotate_z(randf_range(-0.18, 0.18))
	node.rotate_x(randf_range(-0.05, 0.05))
	var hp := node.get_node_or_null("hp")
	if hp:
		hp.visible = false
	for c in node.find_children("*", "MeshInstance3D", true, false):
		if str(c.name) == "blob":
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.1, 0.09)
		m.roughness = 0.95
		c.material_override = m
	var fire := _billow(Color(1.0, 0.45, 0.12, 0.85), 16, 0.55, true)
	fire.position = Vector3(0, 0.8, 0)
	fire.amount = 16
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 18.0
	fire.initial_velocity_min = 0.4
	fire.initial_velocity_max = 1.6
	fire.gravity = Vector3(0.2, 0.4, 0)
	node.add_child(fire)
	var soot := _billow(Color(0.08, 0.08, 0.08, 0.55), 28, 2.6, false)
	soot.position = Vector3(0, 1.2, 0)
	soot.direction = Vector3(0.6, 1.0, 0.1)
	soot.spread = 22.0
	soot.initial_velocity_min = 0.8
	soot.initial_velocity_max = 2.2
	soot.gravity = Vector3(0.35, 0.2, 0)
	node.add_child(soot)


func _mark_delivered(node: Node3D) -> void:
	var beacon := node.find_child("beacon", true, false)
	if beacon and beacon is MeshInstance3D and not node.has_meta("safe"):
		node.set_meta("safe", true)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("7dcea0")
		m.emission_enabled = true
		m.emission = Color("7dcea0")
		m.emission_energy_multiplier = 1.6
		beacon.material_override = m


func _friendly_bar_color(u) -> Color:
	if u["role"] == "cargo":
		return Color("e2b84a")
	if u["role"] == "repair":
		return Color("7dcea0")
	return Color("9dc56a")


func _tracer(a: Vector3, b: Vector3, color: Color, weapon: String) -> void:
	a = _lift(a)
	b = _lift(b)
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var thick := 0.07
	var life := 0.07
	if weapon == "shell":
		thick = 0.16
		life = 0.12
	elif weapon == "rocket":
		thick = 0.12
		life = 0.28
	elif weapon == "aa":
		thick = 0.05
		life = 0.06
	var mi := MeshInstance3D.new()
	var box := CylinderMesh.new()
	box.top_radius = thick
	box.bottom_radius = thick
	box.height = len
	box.radial_segments = 6
	mi.mesh = box
	mi.position = (a + b) * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(mi)
	if mi.global_position.distance_to(b) > 0.05:
		mi.look_at(b, Vector3.UP)
		mi.rotate_x(PI * 0.5)
	fx_items.append({"node": mi, "life": life, "max": life})
	var flash := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.28 if weapon != "shell" else 0.45
	sph.height = sph.radius * 2.0
	sph.radial_segments = 8
	sph.rings = 4
	flash.mesh = sph
	flash.position = a
	flash.material_override = m.duplicate()
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(flash)
	fx_items.append({"node": flash, "life": 0.05, "max": 0.05, "scale": true})


func _impact(pos: Vector3, weapon: String) -> void:
	pos = _lift(pos)
	var spark := weapon == "shell" or weapon == "rocket"
	var parts := _billow(Color(1.0, 0.72, 0.35, 0.9) if spark else Color(0.62, 0.5, 0.34, 0.55), 8 if spark else 10, 0.35, spark)
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.position = pos + Vector3(0, 0.3, 0)
	parts.direction = Vector3.UP
	parts.spread = 55.0
	parts.initial_velocity_min = 1.5
	parts.initial_velocity_max = 5.0
	parts.gravity = Vector3(0, -6, 0)
	parts.scale_amount_min = 0.2
	parts.scale_amount_max = 0.55
	fx_root.add_child(parts)
	fx_items.append({"node": parts, "life": 0.7, "max": 0.7})


func _explosion(pos: Vector3, big: bool, strike: bool = false) -> void:
	pos = _lift(pos)
	var radius := 2.4 if strike else (1.3 if big else 0.7)
	var flash := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 12
	sph.rings = 6
	flash.mesh = sph
	flash.position = pos + Vector3(0, 0.9, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.55, 0.16, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.42, 0.08)
	m.emission_energy_multiplier = 3.2
	flash.material_override = m
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(flash)
	fx_items.append({"node": flash, "life": 0.42, "max": 0.42, "scale": true})
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.08
	cyl.radial_segments = 24
	ring.mesh = cyl
	ring.position = Vector3(pos.x, pos.y + 0.25, pos.z)
	var rm := m.duplicate()
	rm.albedo_color = Color(1.0, 0.75, 0.4, 0.55)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(ring)
	fx_items.append({"node": ring, "life": 0.45, "max": 0.45, "shock": 7.0 if strike else (4.2 if big else 2.4)})
	var debris := _billow(Color(0.35, 0.22, 0.14, 1), 18 if big else 10, 0.8, true)
	debris.one_shot = true
	debris.explosiveness = 0.92
	debris.position = pos + Vector3(0, 0.7, 0)
	debris.direction = Vector3.UP
	debris.spread = 78.0
	debris.initial_velocity_min = 4.0
	debris.initial_velocity_max = 11.0 if strike else 8.0
	debris.gravity = Vector3(0, -9, 0)
	var chunk := SphereMesh.new()
	chunk.radius = 0.18
	chunk.height = 0.36
	chunk.material = meshes.mat(Color(0.42, 0.28, 0.16))
	debris.mesh = chunk
	debris.scale_amount_min = 0.15
	debris.scale_amount_max = 0.4
	fx_root.add_child(debris)
	fx_items.append({"node": debris, "life": 1.2, "max": 1.2})
	var smoke := _billow(Color(0.12, 0.1, 0.09, 0.5), 24 if big else 14, 1.8, false)
	smoke.one_shot = true
	smoke.explosiveness = 0.4
	smoke.position = pos + Vector3(0, 0.8, 0)
	smoke.direction = Vector3(0.4, 1, 0)
	smoke.spread = 30.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0.5, 0.15, 0.1)
	fx_root.add_child(smoke)
	fx_items.append({"node": smoke, "life": 2.2, "max": 2.2})
	_scorch(pos, 2.4 if strike else (1.6 if big else 0.9))
	if big or strike:
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 1.5, 0)
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 4.0 if strike else 2.2
		light.omni_range = 18.0 if strike else 10.0
		light.shadow_enabled = false
		fx_root.add_child(light)
		fx_items.append({"node": light, "life": 0.18, "max": 0.18})


func _fade_fx(dt: float) -> void:
	var keep: Array = []
	for item in fx_items:
		item["life"] = float(item["life"]) - dt
		var node = item["node"]
		if not is_instance_valid(node):
			continue
		if float(item["life"]) <= 0.0:
			node.queue_free()
			continue
		var a := float(item["life"]) / float(item["max"])
		if node is GeometryInstance3D and node.material_override:
			var col: Color = node.material_override.albedo_color
			col.a = a
			node.material_override.albedo_color = col
		if item.get("scale", false) and node is Node3D:
			var s := 1.0 + (1.0 - a) * 2.4
			node.scale = Vector3.ONE * s
		if item.has("shock") and node is Node3D:
			var span := float(item["shock"]) * (1.0 - a)
			node.scale = Vector3(span, 1.0, span)
		keep.append(item)
	fx_items = keep


func _sync_smoke(sim) -> void:
	var active: bool = sim.smoke_timer > 0.0
	var seen := {}
	if active:
		for u in sim.friendlies:
			if not u["alive"] or u["delivered"]:
				continue
			var id := int(u["id"])
			seen[id] = true
			if not smoke_clouds.has(id) or not is_instance_valid(smoke_clouds[id]):
				var cloud := _billow(Color(0.78, 0.78, 0.74, 0.42), 40, 2.5, false)
				cloud.amount = 40
				cloud.direction = Vector3(1.1, 0.55, 0.15)
				cloud.spread = 38.0
				cloud.initial_velocity_min = 0.5
				cloud.initial_velocity_max = 2.4
				cloud.gravity = Vector3(0.8, 0.25, 0.1)
				cloud.scale_amount_min = 2.2
				cloud.scale_amount_max = 4.6
				fx_root.add_child(cloud)
				smoke_clouds[id] = cloud
			var puff: CPUParticles3D = smoke_clouds[id]
			puff.emitting = true
			var smoke_y := road_height(float(u["s"])) + 1.6
			puff.global_position = Vector3(u["pos"].x, smoke_y, u["pos"].z)
	for id in smoke_clouds.keys():
		if not seen.has(id) and is_instance_valid(smoke_clouds[id]):
			(smoke_clouds[id] as CPUParticles3D).emitting = false


func _sync_strikes(sim) -> void:
	var live: Array = []
	for strike in sim.strikes:
		if bool(strike["boom"]):
			continue
		live.append(strike)
	while rings.size() < live.size():
		var marker := Node3D.new()
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 14.0
		cyl.bottom_radius = 14.0
		cyl.height = 0.12
		cyl.radial_segments = 28
		mi.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.32, 0.12, 0.4)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(1.0, 0.3, 0.1)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(mi)
		var jet := _jet()
		jet.name = "jet"
		marker.add_child(jet)
		fx_root.add_child(marker)
		rings.append(marker)
	for i in rings.size():
		if i >= live.size():
			rings[i].visible = false
			continue
		var strike = live[i]
		var marker: Node3D = rings[i]
		marker.visible = true
		var p: Vector3 = strike["pos"]
		marker.position = Vector3(p.x, _height(p.x, p.z) + 0.35, p.z)
		var eta := float(strike["eta"])
		var travel := clampf(eta / 1.15, 0.0, 1.0)
		var jet: Node3D = marker.get_node_or_null("jet")
		if jet:
			jet.position = Vector3(-48.0 * travel, 10.0 + 16.0 * travel, -18.0 * travel)
			if jet.global_position.distance_to(marker.global_position) > 0.5:
				jet.look_at(marker.global_position, Vector3.UP)


func _billow(color: Color, amount: int, life: float, lit: bool) -> CPUParticles3D:
	var parts := CPUParticles3D.new()
	parts.amount = amount
	parts.lifetime = life
	parts.explosiveness = 0.08
	parts.randomness = 0.4
	parts.emitting = true
	parts.local_coords = false
	parts.mesh = meshes.puff(color, lit)
	parts.color = color
	return parts


func _scorch(pos: Vector3, radius: float) -> void:
	if scorch_count >= 24:
		return
	scorch_count += 1
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.15
	cyl.height = 0.04
	cyl.radial_segments = 16
	mi.mesh = cyl
	mi.position = Vector3(pos.x, _height(pos.x, pos.z) + 0.2, pos.z)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.07, 0.06, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(mi)


func _jet() -> Node3D:
	var jet := Node3D.new()
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.45
	cyl.height = 4.2
	cyl.radial_segments = 10
	body.mesh = cyl
	body.rotation_degrees = Vector3(90, 0, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("5c646c")
	m.metallic = 0.6
	m.roughness = 0.35
	body.material_override = m
	jet.add_child(body)
	var wing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.4, 0.08, 0.9)
	wing.mesh = box
	wing.position = Vector3(0, 0, 0.2)
	wing.material_override = m
	jet.add_child(wing)
	return jet


func _hurt(node: Node3D) -> void:
	if node.has_meta("hurt"):
		return
	node.set_meta("hurt", true)
	var leak := _billow(Color(0.2, 0.2, 0.2, 0.4), 12, 1.4, false)
	leak.position = Vector3(0, 1.3, 0.4)
	leak.direction = Vector3(0.2, 1, 0)
	leak.spread = 16.0
	leak.initial_velocity_min = 0.4
	leak.initial_velocity_max = 1.2
	leak.gravity = Vector3(0.3, 0.2, 0)
	node.add_child(leak)


func _set_emitting(node: Node3D, child_name: String, on: bool) -> void:
	var found := node.get_node_or_null(child_name)
	if found is CPUParticles3D:
		(found as CPUParticles3D).emitting = on


func _cell_key(lane: int, row: int) -> String:
	return "%d,%d" % [lane, row]


func pose_at(along: float, lateral: float, yaw_deg: int) -> Dictionary:
	var sm: Dictionary = route.sample(along)
	var pos: Vector3 = sm["pos"] + sm["right"] * lateral
	if absf(lateral) <= 6.2:
		pos.y = road_height(along) + 0.05
	else:
		pos.y = _height(pos.x, pos.z) + 0.08
	var dir: Vector3 = Basis(Vector3.UP, deg_to_rad(float(yaw_deg))) * sm["dir"]
	var pitch := _grade_pitch(along) if absf(lateral) <= 6.2 else 0.0
	return {"pos": pos, "dir": dir, "pitch": pitch}


func _ghost_tint(node: Node3D, ok: bool) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name) == "blob":
			continue
		var src: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
		var dup: Material = src.duplicate() if src else StandardMaterial3D.new()
		if dup is StandardMaterial3D:
			var mat := dup as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var col := mat.albedo_color
			if ok:
				col.a = 0.45
			else:
				col = Color(0.75, 0.22, 0.16, 0.42)
			mat.albedo_color = col
		mi.material_override = dup


func _clear_level() -> void:
	for c in level_root.get_children():
		c.free()
	for c in preview_root.get_children():
		c.free()
	for c in unit_root.get_children():
		c.free()
	for c in fx_root.get_children():
		c.free()
	preview_root.visible = true
	slot_bodies.clear()
	slot_pads.clear()
	cell_pad.clear()
	unit_nodes.clear()
	smoke_puffs.clear()
	smoke_clouds.clear()
	rings.clear()
	fx_items.clear()
	ghost = null
	scorch_count = 0


func _apply_biome(which: String) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	var top := Color(0.42, 0.66, 0.96)
	var horizon := Color(0.82, 0.88, 0.96)
	var ground := Color(0.55, 0.4, 0.24)
	var fog := Color(0.84, 0.76, 0.6)
	var density := 0.00028
	var sun_rot := Vector3(-40.0, 54.0, 0.0)
	var sun_col := Color(1.0, 0.96, 0.86)
	var sun_energy := 1.32
	var fill_col := Color(0.55, 0.64, 0.82)
	var fill_energy := 0.14
	var exposure := 1.04
	var saturation := 1.18
	if which == "forest":
		top = Color(0.45, 0.62, 0.78)
		horizon = Color(0.68, 0.76, 0.74)
		ground = Color(0.16, 0.28, 0.14)
		fog = Color(0.62, 0.72, 0.68)
		density = 0.00072
		sun_rot = Vector3(-46.0, 24.0, 0.0)
		sun_col = Color(0.86, 0.91, 0.98)
		sun_energy = 1.08
		fill_col = Color(0.45, 0.58, 0.62)
		fill_energy = 0.18
		exposure = 0.94
		saturation = 0.92
	elif which == "desert":
		top = Color(0.45, 0.62, 0.9)
		horizon = Color(0.9, 0.72, 0.46)
		ground = Color(0.62, 0.42, 0.22)
		fog = Color(0.9, 0.7, 0.42)
		density = 0.0009
		sun_rot = Vector3(-44.0, 36.0, 0.0)
		sun_col = Color(1.0, 0.86, 0.64)
		sun_energy = 1.22
		fill_col = Color(0.72, 0.5, 0.32)
		fill_energy = 0.16
		exposure = 0.96
		saturation = 0.98
	elif which == "arctic":
		top = Color(0.55, 0.64, 0.78)
		horizon = Color(0.78, 0.82, 0.86)
		ground = Color(0.72, 0.76, 0.8)
		fog = Color(0.8, 0.84, 0.88)
		density = 0.00155
		sun_rot = Vector3(-32.0, 48.0, 0.0)
		sun_col = Color(0.78, 0.84, 0.96)
		sun_energy = 0.92
		fill_col = Color(0.55, 0.62, 0.78)
		fill_energy = 0.2
		exposure = 0.9
		saturation = 0.78
	elif which == "urban":
		top = Color(0.42, 0.46, 0.52)
		horizon = Color(0.62, 0.6, 0.56)
		ground = Color(0.28, 0.26, 0.24)
		fog = Color(0.55, 0.52, 0.48)
		density = 0.00085
		sun_rot = Vector3(-52.0, 18.0, 0.0)
		sun_col = Color(0.84, 0.8, 0.72)
		sun_energy = 0.9
		fill_col = Color(0.5, 0.52, 0.56)
		fill_energy = 0.2
		exposure = 0.9
		saturation = 0.72
	elif which == "jungle":
		top = Color(0.42, 0.58, 0.62)
		horizon = Color(0.62, 0.72, 0.52)
		ground = Color(0.16, 0.28, 0.12)
		fog = Color(0.52, 0.64, 0.46)
		density = 0.00115
		sun_rot = Vector3(-50.0, 28.0, 0.0)
		sun_col = Color(0.95, 0.88, 0.68)
		sun_energy = 1.0
		fill_col = Color(0.4, 0.55, 0.4)
		fill_energy = 0.18
		exposure = 0.92
		saturation = 0.9
	elif which == "mountain":
		top = Color(0.34, 0.56, 0.94)
		horizon = Color(0.78, 0.84, 0.94)
		ground = Color(0.34, 0.36, 0.4)
		fog = Color(0.78, 0.82, 0.88)
		density = 0.00022
		sun_rot = Vector3(-36.0, -58.0, 0.0)
		sun_col = Color(1.0, 0.96, 0.9)
		sun_energy = 1.34
		fill_col = Color(0.55, 0.64, 0.8)
		fill_energy = 0.16
		exposure = 1.04
		saturation = 1.12
	mat.sky_top_color = top
	mat.sky_horizon_color = horizon
	mat.ground_horizon_color = horizon.darkened(0.18)
	mat.ground_bottom_color = ground
	mat.sun_angle_max = 18.0
	mat.sky_energy_multiplier = 0.95
	mat.sky_curve = 0.08
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.52
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = density
	env.fog_light_color = fog
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.12
	env.glow_strength = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.45
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = saturation
	env.volumetric_fog_enabled = false
	if RenderingServer.get_rendering_device() != null:
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.05
		env.ssao_power = 1.35
	env_node.environment = env
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.light_specular = 0.15
	sun.shadow_enabled = shadows_on
	fill.rotation_degrees = Vector3(-24.0, sun_rot.y + 170.0, 0.0)
	fill.light_color = fill_col
	fill.light_energy = fill_energy
	fill.light_specular = 0.0


func _build_terrain() -> void:
	_bake_land()
	var margin := 400.0 if biome == "mountain" else 440.0
	_build_heightfield(margin, 4.0)
	if biome == "forest":
		_build_stream()
	elif biome == "jungle":
		_build_jungle_water()
	elif biome == "arctic":
		_build_ice()


func _build_heightfield(margin: float, step: float) -> void:
	var area: Rect2 = route.bounds(margin)
	var x0: float = area.position.x
	var z0: float = area.position.y
	var nx := int(ceil(area.size.x / step)) + 1
	var nz := int(ceil(area.size.y / step)) + 1
	if nx < 2:
		nx = 2
	if nz < 2:
		nz = 2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	grid.resize(nx * nz)
	var colors: Array = []
	colors.resize(nx * nz)
	var norms: Array = []
	norms.resize(nx * nz)
	for iz in nz:
		var z: float = z0 + float(iz) * step
		for ix in nx:
			var x: float = x0 + float(ix) * step
			grid[ix + iz * nx] = Vector3(x, _height(x, z), z)
	for iz in nz:
		for ix in nx:
			var p: Vector3 = grid[ix + iz * nx]
			var n := _strip_normal(grid, nx, nz, ix, iz)
			norms[ix + iz * nx] = n
			var slope := clampf(sqrt(maxf(0.0, 1.0 - n.y * n.y)) / maxf(n.y, 0.25), 0.0, 1.6)
			colors[ix + iz * nx] = _blend_color(p, slope)
	for iz in nz - 1:
		for ix in nx - 1:
			var a: Vector3 = grid[ix + iz * nx]
			var b: Vector3 = grid[ix + 1 + iz * nx]
			var c: Vector3 = grid[ix + (iz + 1) * nx]
			var d: Vector3 = grid[ix + 1 + (iz + 1) * nx]
			var ca: Color = colors[ix + iz * nx]
			var cb: Color = colors[ix + 1 + iz * nx]
			var cc: Color = colors[ix + (iz + 1) * nx]
			var cd: Color = colors[ix + 1 + (iz + 1) * nx]
			var na: Vector3 = norms[ix + iz * nx]
			var nb: Vector3 = norms[ix + 1 + iz * nx]
			var nc: Vector3 = norms[ix + (iz + 1) * nx]
			var nd: Vector3 = norms[ix + 1 + (iz + 1) * nx]
			_add_shaded_tri_flip(st, a, b, c, ca, cb, cc, na, nb, nc)
			_add_shaded_tri_flip(st, b, d, c, cb, cd, cc, nb, nd, nc)
	st.index()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _ground_material(true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(mi)



func _ground_material(triplanar: bool) -> StandardMaterial3D:
	_ensure_ground_tex()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.albedo_texture = ground_grain
	m.normal_enabled = true
	m.normal_texture = ground_normal
	m.normal_scale = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.92
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.16, 0.16, 0.16)
		m.normal_scale = 1.15
		if biome == "desert":
			m.albedo_texture = _desert_grain()
			m.roughness = 0.96
		elif biome == "forest" or biome == "jungle":
			m.albedo_texture = _forest_grain()
			m.roughness = 0.94
		elif biome == "arctic":
			m.albedo_texture = _make_grain(Color(0.9, 0.94, 1.0))
			m.roughness = 0.9
		elif biome == "urban":
			m.albedo_texture = _make_grain(Color(0.78, 0.76, 0.72))
			m.roughness = 0.96
		else:
			m.uv1_scale = Vector3(0.14, 0.14, 0.14)
			m.normal_scale = 1.2
			m.albedo_texture = _mountain_grain()
	return m


func _strip_normal(grid: Array, nx: int, nz: int, ix: int, iz: int) -> Vector3:
	var ix0 := maxi(ix - 1, 0)
	var ix1 := mini(ix + 1, nx - 1)
	var iz0 := maxi(iz - 1, 0)
	var iz1 := mini(iz + 1, nz - 1)
	var left: Vector3 = grid[ix0 + iz * nx]
	var right: Vector3 = grid[ix1 + iz * nx]
	var back: Vector3 = grid[ix + iz0 * nx]
	var ahead: Vector3 = grid[ix + iz1 * nx]
	var n := (right - left).cross(ahead - back)
	if n.y < 0.0:
		n = -n
	if n.length() < 0.001:
		return Vector3.UP
	return n.normalized()


func _add_shaded_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face := (b - a).cross(c - a)
	if face.y < 0.0:
		var swap_p := b
		b = c
		c = swap_p
		var swap_c := cb
		cb = cc
		cc = swap_c
		var swap_n := nb
		nb = nc
		nc = swap_n
	_put_ground_vert(st, a, ca, na)
	_put_ground_vert(st, b, cb, nb)
	_put_ground_vert(st, c, cc, nc)


func _add_shaded_tri_flip(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Mountain heightfield quads face the other way from the route ribbon.
	var face := (b - a).cross(c - a)
	if face.y > 0.0:
		var swap_p := b
		b = c
		c = swap_p
		var swap_c := cb
		cb = cc
		cc = swap_c
		var swap_n := nb
		nb = nc
		nc = swap_n
	_put_ground_vert(st, a, ca, na)
	_put_ground_vert(st, b, cb, nb)
	_put_ground_vert(st, c, cc, nc)


func _put_ground_vert(st: SurfaceTool, p: Vector3, col: Color, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(p.x * 0.045, p.z * 0.045))
	st.add_vertex(p)


func _grid_normal(grid: Array, nx: int, nz: int, ix: int, iz: int, step: float) -> Vector3:
	var ix0 := maxi(ix - 1, 0)
	var ix1 := mini(ix + 1, nx - 1)
	var iz0 := maxi(iz - 1, 0)
	var iz1 := mini(iz + 1, nz - 1)
	var left: Vector3 = grid[ix0 + iz * nx]
	var right: Vector3 = grid[ix1 + iz * nx]
	var down: Vector3 = grid[ix + iz0 * nx]
	var up: Vector3 = grid[ix + iz1 * nx]
	var sx := (right.y - left.y) / maxf(step * float(maxi(ix1 - ix0, 1)), 0.001)
	var sz := (up.y - down.y) / maxf(step * float(maxi(iz1 - iz0, 1)), 0.001)
	var n := Vector3(-sx, 1.0, -sz)
	if n.length() < 0.001:
		return Vector3.UP
	return n.normalized()


func _add_up_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.y < 0.0:
		var swap_p := b
		b = c
		c = swap_p
		var swap_c := cb
		cb = cc
		cc = swap_c
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


func road_height(dist: float) -> float:
	if grade.is_empty():
		return 0.0
	var t := (dist - grade_origin) / grade_step
	var i := clampi(int(floor(t)), 0, grade.size() - 1)
	var j := clampi(i + 1, 0, grade.size() - 1)
	return lerpf(grade[i], grade[j], clampf(t - float(i), 0.0, 1.0)) + 0.22


func _bridge_at(dist: float) -> bool:
	if grade_bridge.is_empty():
		return false
	var idx := clampi(int(round((dist - grade_origin) / grade_step)), 0, grade_bridge.size() - 1)
	return grade_bridge[idx] != 0


func _grade_pitch(dist: float) -> float:
	return atan2(road_height(dist + 5.0) - road_height(dist - 1.0), 6.0)


func _slope_pitch(pos: Vector3, dir: Vector3) -> float:
	var ahead := _height(pos.x + dir.x * 3.0, pos.z + dir.z * 3.0)
	return atan2(ahead - pos.y, 3.0)


func _face_along(node: Node3D, dir: Vector3, pitch: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.05:
		return
	node.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	node.rotate_object_local(Vector3.RIGHT, pitch)


func _keep_above(pos: Vector3) -> Vector3:
	if route == null:
		return pos
	var floor_y := _height(pos.x, pos.z) + 4.5
	if pos.y < floor_y:
		pos.y = floor_y
	return pos


func _lift(p: Vector3) -> Vector3:
	return Vector3(p.x, _height(p.x, p.z) + p.y, p.z)


func _bake_land() -> void:
	grade_origin = -64.0
	grade_step = 8.0
	var count := int(ceil((route.total + 56.0 - grade_origin) / grade_step)) + 1
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var dist := grade_origin + float(i) * grade_step
		var p: Vector3 = route.sample(dist)["pos"]
		raw[i] = _macro(p.x, p.z)
	var smooth := PackedFloat32Array()
	smooth.resize(count)
	var radius := 6
	if biome == "desert" or biome == "arctic" or biome == "urban":
		radius = 8
	elif biome == "forest" or biome == "jungle":
		radius = 6
	for i in count:
		var acc := 0.0
		var wsum := 0.0
		for k in range(-radius, radius + 1):
			var j := clampi(i + k, 0, count - 1)
			var w := float(radius + 1 - absi(k))
			acc += raw[j] * w
			wsum += w
		smooth[i] = acc / wsum
	var max_rise := 1.45
	if biome == "desert":
		max_rise = 1.05
	elif biome == "arctic":
		max_rise = 0.9
	elif biome == "urban":
		max_rise = 0.5
	elif biome == "mountain":
		max_rise = 1.85
	for i in range(1, count):
		smooth[i] = minf(smooth[i], smooth[i - 1] + max_rise)
	for i in range(count - 2, -1, -1):
		smooth[i] = minf(smooth[i], smooth[i + 1] + max_rise)
	water_y = 6.0
	if biome == "desert" or biome == "urban":
		water_y = 4.2
	elif biome == "arctic":
		water_y = 5.2
	elif biome == "forest" or biome == "jungle":
		water_y = 6.2
	elif biome == "mountain":
		water_y = 8.5
	for i in count:
		smooth[i] = maxf(smooth[i], water_y + 1.7)
	grade = smooth
	grade_bridge = PackedByteArray()
	grade_bridge.resize(count)
	for i in count:
		grade_bridge[i] = 1 if raw[i] < smooth[i] - 5.2 else 0
	var expanded := grade_bridge.duplicate()
	for i in count:
		if grade_bridge[i] == 0:
			continue
		for k in range(-2, 3):
			expanded[clampi(i + k, 0, count - 1)] = 1
	grade_bridge = expanded
	if biome == "jungle":
		for i in grade_bridge.size():
			var span_d := grade_origin + float(i) * grade_step
			grade_bridge[i] = 1 if absf(span_d - 260.0) < 22.0 else 0
	elif biome != "mountain":
		for i in grade_bridge.size():
			grade_bridge[i] = 0


func _hash2(ix: int, iz: int) -> float:
	var n: int = ix * 374761393 + iz * 668265263 + land_seed * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _noise(x: float, z: float) -> float:
	var x0 := int(floor(x))
	var z0 := int(floor(z))
	var fx := x - float(x0)
	var fz := z - float(z0)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	var n00 := _hash2(x0, z0)
	var n10 := _hash2(x0 + 1, z0)
	var n01 := _hash2(x0, z0 + 1)
	var n11 := _hash2(x0 + 1, z0 + 1)
	return lerpf(lerpf(n00, n10, ux), lerpf(n01, n11, ux), uz)


func _fbm(x: float, z: float, octaves: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var freq := 1.0
	var norm := 0.0
	for _i in octaves:
		sum += _noise(x * freq, z * freq) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.05
	return sum / maxf(norm, 0.001)


func _ridged(x: float, z: float) -> float:
	var sum := 0.0
	var amp := 0.55
	var freq := 1.0
	var norm := 0.0
	for _i in 4:
		var n := 1.0 - absf(_noise(x * freq, z * freq) * 2.0 - 1.0)
		sum += pow(n, 0.72) * amp
		norm += amp
		amp *= 0.48
		freq *= 2.17
	return sum / maxf(norm, 0.001)


func _stretch(n: float) -> float:
	var c := (n - 0.5) * 2.0
	return signf(c) * pow(absf(c), 0.85)


func _macro(x: float, z: float) -> float:
	if biome == "forest" or biome == "jungle":
		return 9.0 + _fbm(x * 0.0036, z * 0.0032, 3) * 11.0
	if biome == "mountain":
		return 12.0 + _fbm(x * 0.0026, z * 0.0024, 3) * 12.0
	if biome == "arctic":
		return 8.0 + _fbm(x * 0.0028, z * 0.0026, 3) * 4.0
	if biome == "urban":
		return 6.0 + _fbm(x * 0.004, z * 0.004, 2) * 1.1
	return 7.0 + _fbm(x * 0.003, z * 0.0027, 3) * 5.0


func _detail(x: float, z: float) -> float:
	if biome == "arctic":
		var drift := pow(_fbm(x * 0.02, z * 0.018, 4), 1.2) * 6.5
		var wind := (_fbm(x * 0.006, z * 0.02, 3) - 0.5) * 2.2
		return drift + wind
	if biome == "urban":
		return pow(_fbm(x * 0.04 + 3.0, z * 0.038, 3), 1.4) * 3.2
	if biome == "jungle":
		var hills_j := (_fbm(x * 0.016, z * 0.015, 4) - 0.3) * 8.0
		var bumps_j := (_fbm(x * 0.05, z * 0.048, 3) - 0.5) * 2.2
		return hills_j + bumps_j
	if biome == "forest":
		var hills := (_fbm(x * 0.018, z * 0.016, 4) - 0.32) * 9.0
		var bumps := (_fbm(x * 0.055 + 2.0, z * 0.05, 3) - 0.5) * 2.4
		return hills + bumps
	if biome == "mountain":
		var ridge := pow(_ridged(x * 0.011 + 1.7, z * 0.01), 1.12)
		var rolls := (_fbm(x * 0.018, z * 0.016, 3) - 0.42) * 6.0
		var bumps := (_fbm(x * 0.052 + 3.0, z * 0.048, 3) - 0.5) * 8.0
		return ridge * 36.0 + rolls + bumps
	var along := x * 0.011 + z * 0.026
	var across := x * 0.034 - z * 0.008
	var dune := pow(_fbm(along, across, 4), 1.35) * 11.0
	var rip := (_fbm(x * 0.07 + 5.0, z * 0.055, 2) - 0.5) * 1.8
	var mesa := smoothstep(0.7, 0.88, _ridged(x * 0.0062 + 4.0, z * 0.0056)) * 14.0
	return dune + rip + mesa


func _natural(x: float, z: float) -> float:
	return _macro(x, z) + _detail(x, z)


func _wash_depth(dist: float, lateral: float) -> float:
	var center := 38.0 + sin(dist * 0.017 + 0.6) * 10.0
	var d := absf(lateral - center)
	if d > 9.0:
		return 0.0
	return (1.0 - smoothstep(2.0, 9.0, d)) * 1.8


func _stream_lat(dist: float) -> float:
	return 28.0 + sin(dist * 0.021 + 1.1) * 6.0


func _stream_depth(dist: float, lateral: float) -> float:
	var d := absf(lateral - _stream_lat(dist))
	if d > 7.5:
		return 0.0
	return (1.0 - smoothstep(1.8, 7.5, d)) * 2.4


func _river_carve(dist: float, lateral: float) -> float:
	var center := 48.0 + sin(dist * 0.012 + float(land_seed) * 0.001) * 8.0
	if biome == "mountain":
		center = 54.0 + sin(dist * 0.009) * 6.0
	elif biome == "desert":
		center = 44.0 + sin(dist * 0.016) * 7.0
	var half := 5.5 if biome == "desert" else 7.0
	var d := absf(lateral - center)
	var reach := half + 16.0
	if d > reach:
		return 0.0
	var depth := 6.5 if biome == "desert" else (7.5 if biome == "forest" else 8.5)
	if d < half:
		return depth
	return depth * (1.0 - smoothstep(half, reach, d))


func _height(x: float, z: float) -> float:
	var land := _macro(x, z) + _detail(x, z)
	if route == null:
		return land
	var proj: Dictionary = route.project(Vector3(x, 0.0, z))
	var dist := float(proj["dist"])
	var lat_signed := float(proj["lateral"])
	var lat := absf(lat_signed)
	var road_y := road_height(dist)
	if biome == "desert":
		var shelf := road_y - 0.3
		if lat < 8.2:
			return shelf
		var t := smoothstep(8.2, 24.0, lat)
		var mesa_gate := smoothstep(26.0, 42.0, lat)
		var dune := maxf(_detail(x, z), 0.8)
		var mesa := smoothstep(0.7, 0.88, _ridged(x * 0.0062 + 4.0, z * 0.0056)) * 14.0
		dune = maxf(dune - mesa, 0.8) + mesa * mesa_gate
		var wash := _wash_depth(dist, lat_signed)
		return maxf(lerpf(shelf, shelf + dune, t) - wash * t, shelf - 0.2)
	if biome == "forest":
		var shelf_f := road_y - 0.18
		if lat < 7.2:
			return shelf_f
		var tf := smoothstep(7.2, 18.0, lat)
		var rise := _detail(x, z) + 3.2
		var yf := lerpf(shelf_f, shelf_f + rise, tf) - _stream_depth(dist, lat_signed) * tf
		return maxf(yf, shelf_f - 2.8)
	if biome == "arctic":
		var shelf_a := road_y - 0.22
		if lat < 8.0:
			return shelf_a
		var ta := smoothstep(8.0, 26.0, lat)
		var drift := maxf(_detail(x, z), 0.5)
		var lake := 0.0
		if dist > 190.0 and dist < 340.0:
			lake = smoothstep(8.0, 20.0, lat) * 1.7
		return maxf(lerpf(shelf_a, shelf_a + drift, ta) - lake, shelf_a - 1.9)
	if biome == "urban":
		var shelf_u := road_y - 0.1
		if lat < 8.5:
			return shelf_u
		var tu := smoothstep(8.5, 22.0, lat)
		return lerpf(shelf_u, shelf_u + maxf(_detail(x, z), 0.2), tu)
	if biome == "jungle":
		var shelf_j := road_y - 0.16
		var crossing := absf(dist - 260.0) < 18.0
		if lat < 7.4:
			return shelf_j
		if crossing:
			return lerpf(shelf_j, shelf_j - 6.2, smoothstep(7.4, 16.0, lat))
		var tj := smoothstep(7.4, 18.0, lat)
		var yj := lerpf(shelf_j, shelf_j + _detail(x, z) + 2.6, tj) - _stream_depth(dist, lat_signed) * tj
		return maxf(yj, shelf_j - 2.6)
	if biome == "mountain":
		# Wide valley shelf, then a slope spread over tens of meters. No gorge cut.
		var shelf := road_y - 0.4
		if lat < 10.5:
			return shelf
		# Reach a crest before the next switchback leg (~30m away) so both sides are walls.
		var t := smoothstep(10.5, 32.0, lat)
		var far := smoothstep(70.0, 200.0, lat)
		var peak := maxf(land, road_y + 16.0) + far * 20.0
		return lerpf(shelf, peak, t)
	land -= _river_carve(dist, lat_signed)
	if _bridge_at(dist) and lat < 30.0:
		var gorge := minf(land, road_y - 8.0)
		return lerpf(road_y - 0.4, gorge, smoothstep(8.0, 22.0, lat))
	if lat < 7.2:
		return road_y - 0.45
	if lat < 13.0:
		return lerpf(road_y - 0.45, land, smoothstep(7.2, 13.0, lat))
	return land


func _grid_slope(grid: Array, nx: int, nz: int, ix: int, iz: int, step: float) -> float:
	var ix0 := maxi(ix - 1, 0)
	var ix1 := mini(ix + 1, nx - 1)
	var iz0 := maxi(iz - 1, 0)
	var iz1 := mini(iz + 1, nz - 1)
	var left: Vector3 = grid[ix0 + iz * nx]
	var right: Vector3 = grid[ix1 + iz * nx]
	var down: Vector3 = grid[ix + iz0 * nx]
	var up: Vector3 = grid[ix + iz1 * nx]
	var sx := (right.y - left.y) / maxf(step * float(maxi(ix1 - ix0, 1)), 0.001)
	var sz := (up.y - down.y) / maxf(step * float(maxi(iz1 - iz0, 1)), 0.001)
	return clampf(Vector2(sx, sz).length(), 0.0, 1.6)


func _blend_color(p: Vector3, slope: float) -> Color:
	var h := p.y
	var sand := Color(0.86, 0.68, 0.38)
	var sand_dark := Color(0.55, 0.38, 0.18)
	var dirt := Color(0.4, 0.27, 0.14)
	var grass := Color(0.3, 0.55, 0.16)
	var grass_dark := Color(0.1, 0.32, 0.08)
	var rock := Color(0.58, 0.56, 0.54)
	var rock_dark := Color(0.32, 0.31, 0.3)
	var snow := Color(0.97, 0.98, 0.99)
	var patch := _fbm(p.x * 0.05, p.z * 0.046, 3)
	var col := sand
	if biome == "desert":
		var relief := clampf((_detail(p.x, p.z) - 1.0) / 12.0, 0.0, 1.0)
		var pale := Color(0.95, 0.78, 0.42)
		var rust := Color(0.62, 0.34, 0.14)
		var ochre := Color(0.82, 0.58, 0.26)
		col = rust.lerp(ochre, patch)
		col = col.lerp(pale, relief)
		if slope > 0.28:
			col = col.lerp(Color(0.58, 0.46, 0.34), clampf((slope - 0.28) * 1.5, 0.0, 0.8))
		var proj_d: Dictionary = route.project(Vector3(p.x, 0.0, p.z)) if route != null else {}
		if not proj_d.is_empty() and _wash_depth(float(proj_d["dist"]), float(proj_d["lateral"])) > 0.45:
			col = col.lerp(Color(0.48, 0.3, 0.16), 0.55)
		var shade_d := 0.9 + _hash2(int(floor(p.x * 0.4)), int(floor(p.z * 0.4))) * 0.16
		return Color(col.r * shade_d, col.g * shade_d, col.b * shade_d)
	elif biome == "forest":
		col = grass_dark.lerp(grass, 0.35 + patch * 0.65)
		col = col.lerp(dirt, clampf((0.45 - patch) * 0.9, 0.0, 0.55))
		if slope > 0.3:
			col = col.lerp(dirt, clampf((slope - 0.3) * 1.2, 0.0, 0.65))
		if slope > 0.6:
			col = col.lerp(rock, clampf((slope - 0.6) * 1.3, 0.0, 0.7))
		var proj_f: Dictionary = route.project(Vector3(p.x, 0.0, p.z)) if route != null else {}
		if not proj_f.is_empty():
			var lat_f := absf(float(proj_f["lateral"]))
			if lat_f < 13.0:
				col = col.lerp(Color(0.4, 0.29, 0.16), 1.0 - smoothstep(5.5, 13.0, lat_f))
			if _stream_depth(float(proj_f["dist"]), float(proj_f["lateral"])) > 0.7:
				col = Color(0.24, 0.2, 0.12)
		var shade_f := 0.86 + _hash2(int(floor(p.x * 0.45)), int(floor(p.z * 0.45))) * 0.22
		return Color(col.r * shade_f, col.g * shade_f, col.b * shade_f)
	elif biome == "arctic":
		var snow_c := Color(0.86, 0.9, 0.94)
		var ice := Color(0.62, 0.74, 0.82)
		var rock_a := Color(0.45, 0.48, 0.52)
		col = snow_c.lerp(Color(0.72, 0.76, 0.8), patch)
		if slope > 0.35:
			col = col.lerp(rock_a, clampf((slope - 0.35) * 1.4, 0.0, 0.7))
		var proj_a: Dictionary = route.project(Vector3(p.x, 0.0, p.z)) if route != null else {}
		if not proj_a.is_empty():
			var da := float(proj_a["dist"])
			var la := absf(float(proj_a["lateral"]))
			if da > 190.0 and da < 340.0 and la > 9.0 and la < 42.0:
				col = col.lerp(ice, 0.72)
		var shade_a := 0.9 + _hash2(int(floor(p.x * 0.4)), int(floor(p.z * 0.4))) * 0.12
		return Color(col.r * shade_a, col.g * shade_a, col.b * shade_a)
	elif biome == "urban":
		var asphalt_g := Color(0.32, 0.31, 0.3)
		var concrete := Color(0.48, 0.46, 0.43)
		var dirt_u := Color(0.36, 0.28, 0.2)
		col = concrete.lerp(asphalt_g, patch)
		col = col.lerp(dirt_u, clampf((0.5 - patch) * 0.8, 0.0, 0.45))
		if slope > 0.25:
			col = col.lerp(Color(0.28, 0.26, 0.24), 0.45)
		var shade_u := 0.84 + _hash2(int(floor(p.x * 0.5)), int(floor(p.z * 0.5))) * 0.18
		return Color(col.r * shade_u, col.g * shade_u, col.b * shade_u)
	elif biome == "jungle":
		var leaf := Color(0.12, 0.34, 0.1)
		var leaf_d := Color(0.08, 0.22, 0.08)
		var mud_j := Color(0.28, 0.2, 0.1)
		col = leaf_d.lerp(leaf, 0.3 + patch * 0.7)
		if slope > 0.28:
			col = col.lerp(mud_j, clampf((slope - 0.28) * 1.3, 0.0, 0.65))
		var proj_j: Dictionary = route.project(Vector3(p.x, 0.0, p.z)) if route != null else {}
		if not proj_j.is_empty():
			var dj := float(proj_j["dist"])
			if absf(dj - 260.0) < 18.0 and absf(float(proj_j["lateral"])) > 8.0:
				col = Color(0.16, 0.28, 0.22)
			elif _stream_depth(dj, float(proj_j["lateral"])) > 0.6:
				col = Color(0.2, 0.24, 0.12)
		var shade_j := 0.84 + _hash2(int(floor(p.x * 0.45)), int(floor(p.z * 0.45))) * 0.2
		return Color(col.r * shade_j, col.g * shade_j, col.b * shade_j)
	else:
		var snow_line := 32.0
		var rock_warm := Color(0.55, 0.48, 0.4)
		if h < 18.0:
			col = Color(0.36, 0.46, 0.18).lerp(Color(0.48, 0.34, 0.18), 0.35 + patch * 0.45)
		elif h < 26.0:
			col = Color(0.45, 0.32, 0.18).lerp(rock_warm, clampf((h - 18.0) / 8.0, 0.0, 1.0))
		elif h < snow_line:
			col = rock_warm.lerp(rock, clampf((h - 26.0) / 6.0, 0.0, 1.0))
		else:
			col = rock.lerp(snow, clampf((h - snow_line) / 4.5, 0.0, 1.0))
		var strata := _fbm(h * 0.22 + p.x * 0.01, p.z * 0.01, 2)
		if h < snow_line:
			col = col.lerp(rock_dark, clampf((strata - 0.45) * 1.4, 0.0, 0.55))
			col = col.lerp(rock_warm.lightened(0.15), clampf((0.4 - strata) * 1.2, 0.0, 0.35))
		if slope > 0.55 and h < snow_line:
			col = col.lerp(rock_dark, 0.35)
		if h >= snow_line:
			return col
		var shade := 0.9 + _hash2(int(floor(p.x * 0.45)), int(floor(p.z * 0.45))) * 0.18
		return Color(col.r * shade, col.g * shade, col.b * shade)
	return col


func _speckle(col: Color, p: Vector3) -> Color:
	var ix := int(floor(p.x * 0.62))
	var iz := int(floor(p.z * 0.62))
	var fine := _hash2(ix, iz)
	var blot := _hash2(ix >> 2, iz >> 2)
	var shade := 0.58 + fine * 0.62
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	if blot > 0.66:
		col = col.lerp(col.lightened(0.22), 0.55)
	elif blot < 0.28:
		col = col.darkened(0.22)
	return col


func _ensure_ground_tex() -> void:
	if ground_grain != null and ground_normal != null:
		return
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var hmap := PackedFloat32Array()
	hmap.resize(size * size)
	for y in size:
		for x in size:
			var coarse := _hash2(x >> 4, y >> 4)
			var mid := _hash2(x >> 2, y >> 2)
			var fine := _hash2(x * 3 + 2, y * 5 + 7)
			var n2 := _hash2(x * 7 + 1, y * 3 + 4)
			var n := coarse * 0.5 + mid * 0.32 + fine * 0.18
			hmap[x + y * size] = n
			var crack := 1.0
			if absf(fine - n2) < 0.04:
				crack = 0.62
			var v := clampf((0.2 + n * 1.15) * crack, 0.12, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.96, v * 0.88))
	ground_grain = ImageTexture.create_from_image(img)
	mountain_grain = ground_grain
	var nimg := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var xl := (x - 1) & 127
			var xr := (x + 1) & 127
			var yd := (y - 1) & 127
			var yu := (y + 1) & 127
			var hl: float = hmap[xl + y * size]
			var hr: float = hmap[xr + y * size]
			var hd: float = hmap[x + yd * size]
			var hu: float = hmap[x + yu * size]
			var nx := (hl - hr) * 2.4
			var ny := (hd - hu) * 2.4
			var nz := 1.0
			var inv := 1.0 / sqrt(nx * nx + ny * ny + nz * nz)
			nimg.set_pixel(x, y, Color(nx * inv * 0.5 + 0.5, ny * inv * 0.5 + 0.5, nz * inv * 0.5 + 0.5))
	ground_normal = ImageTexture.create_from_image(nimg)


func _desert_grain() -> Texture2D:
	if desert_grain != null:
		return desert_grain
	desert_grain = _make_grain(Color(1.0, 0.9, 0.7))
	return desert_grain


func _forest_grain() -> Texture2D:
	if forest_grain != null:
		return forest_grain
	forest_grain = _make_grain(Color(0.82, 0.95, 0.78))
	return forest_grain


func _make_grain(tint: Color) -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var mid := _hash2(x >> 2, y >> 2)
			var fine := _hash2(x * 3 + 2, y * 5 + 7)
			var v := 0.8 + mid * 0.14 + fine * 0.06
			if absf(fine - mid) < 0.04:
				v = 0.66
			img.set_pixel(x, y, Color(v * tint.r, v * tint.g, v * tint.b))
	return ImageTexture.create_from_image(img)


func _mountain_grain() -> Texture2D:
	if mountain_grain != null and mountain_grain != ground_grain:
		return mountain_grain
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var mid := _hash2(x >> 2, y >> 2)
			var fine := _hash2(x * 3 + 2, y * 5 + 7)
			var v := 0.78 + mid * 0.14 + fine * 0.08
			if absf(fine - mid) < 0.05:
				v = 0.62
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.94))
	mountain_grain = ImageTexture.create_from_image(img)
	return mountain_grain


func _build_water_cells(grid: Array, nx: int, nz: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var col := Color(0.16, 0.38, 0.36)
	if biome == "desert":
		col = Color(0.2, 0.4, 0.36)
	elif biome == "mountain":
		col = Color(0.14, 0.28, 0.34)
	for iz in nz - 1:
		for ix in nx - 1:
			var a: Vector3 = grid[ix + iz * nx]
			var b: Vector3 = grid[ix + 1 + iz * nx]
			var c: Vector3 = grid[ix + (iz + 1) * nx]
			var d: Vector3 = grid[ix + 1 + (iz + 1) * nx]
			var avg := (a.y + b.y + c.y + d.y) * 0.25
			if avg > water_y + 0.25:
				continue
			var mid := (a + b + c + d) * 0.25
			var proj: Dictionary = route.project(mid)
			if absf(float(proj["lateral"])) < 16.0:
				continue
			var y := water_y + 0.16
			var wa := Vector3(a.x, y, a.z)
			var wb := Vector3(b.x, y, b.z)
			var wc := Vector3(c.x, y, c.z)
			var wd := Vector3(d.x, y, d.z)
			_add_up_tri(st, wa, wb, wc, col, col, col)
			_add_up_tri(st, wb, wd, wc, col, col, col)
			count += 1
	if count == 0:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.55
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(mi)


func _build_stream() -> void:
	_ribbon_water(func(dist: float) -> float: return _stream_lat(dist), 3.2, Color(0.12, 0.28, 0.32), false)


func _build_jungle_water() -> void:
	_ribbon_water(func(dist: float) -> float: return _stream_lat(dist), 3.6, Color(0.1, 0.32, 0.28), false)
	var sm: Dictionary = route.sample(260.0)
	var pos: Vector3 = sm["pos"]
	var right: Vector3 = sm["right"]
	var dir: Vector3 = sm["dir"]
	var y := road_height(260.0) - 4.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 46.0
	var a := Vector3(pos.x + right.x * -half + dir.x * -8.0, y, pos.z + right.z * -half + dir.z * -8.0)
	var b := Vector3(pos.x + right.x * half + dir.x * -8.0, y, pos.z + right.z * half + dir.z * -8.0)
	var c := Vector3(pos.x + right.x * half + dir.x * 8.0, y, pos.z + right.z * half + dir.z * 8.0)
	var d := Vector3(pos.x + right.x * -half + dir.x * 8.0, y, pos.z + right.z * -half + dir.z * 8.0)
	_flat(st, a, b, c, d, Color(0.08, 0.26, 0.24))
	_commit_surface(st)
	for side in [-1.0, 1.0]:
		var deck := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 0.8, 14.0)
		deck.mesh = box
		var edge: Vector3 = pos + right * float(side) * 6.2
		edge.y = road_height(260.0) + 0.5
		deck.position = edge
		deck.basis = Basis(right, Vector3.UP, -dir)
		deck.material_override = meshes.mat(Color(0.35, 0.32, 0.28))
		level_root.add_child(deck)


func _build_ice() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 196.0
	var prev: Dictionary = {}
	while dist < 334.0:
		var sm: Dictionary = route.sample(dist)
		var y := road_height(dist) - 1.15
		var l: Vector3 = _road_pt(sm, 42.0, y)
		var r: Vector3 = _road_pt(sm, -42.0, y)
		if not prev.is_empty():
			_flat(st, prev["l"], prev["r"], r, l, Color(0.62, 0.78, 0.86))
		prev = {"l": l, "r": r}
		dist += 6.0
	_commit_surface(st)


func _ribbon_water(lat_fn: Callable, half: float, col: Color, _decks: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 8.0
	var prev: Dictionary = {}
	while dist < route.total - 8.0:
		var sm: Dictionary = route.sample(dist)
		var lat: float = float(lat_fn.call(dist))
		var center: Vector3 = _road_pt(sm, lat, 0.0)
		var y := _height(center.x, center.z) + 0.2
		var l: Vector3 = _road_pt(sm, lat - half, y)
		var r: Vector3 = _road_pt(sm, lat + half, y)
		if not prev.is_empty():
			_flat(st, prev["l"], prev["r"], r, l, col)
		prev = {"l": l, "r": r}
		dist += 4.0
	_commit_surface(st)


func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dash := SurfaceTool.new()
	dash.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bridge := SurfaceTool.new()
	bridge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := -70.0
	var step := 2.4
	var prev: Dictionary = {}
	var bridge_used := false
	var shoulder_w := 7.6
	var asphalt_w := 5.4
	var paint_lines := biome != "forest" and biome != "jungle"
	if biome == "forest" or biome == "jungle":
		shoulder_w = 6.4
		asphalt_w = 4.6
	elif biome == "urban":
		shoulder_w = 6.8
		asphalt_w = 5.6
	while dist < route.total + 24.0:
		var sm: Dictionary = route.sample(dist)
		var y := road_height(dist)
		var l := _road_pt(sm, shoulder_w, y + 0.1)
		var r := _road_pt(sm, -shoulder_w, y + 0.1)
		var al := _road_pt(sm, asphalt_w, y + 0.18)
		var ar := _road_pt(sm, -asphalt_w, y + 0.18)
		var bridged := _bridge_at(dist)
		if not prev.is_empty():
			var prev_l: Vector3 = prev["l"]
			var prev_r: Vector3 = prev["r"]
			var prev_al: Vector3 = prev["al"]
			var prev_ar: Vector3 = prev["ar"]
			var n := _hash2(int(dist), land_seed)
			var shoulder := Color(0.26, 0.25, 0.22)
			var asphalt := Color(0.08, 0.08, 0.075)
			if biome == "desert":
				shoulder = Color(0.62, 0.48, 0.28).lerp(Color(0.78, 0.62, 0.36), n)
				asphalt = Color(0.16, 0.15, 0.13).lerp(Color(0.28, 0.25, 0.2), n)
			elif biome == "forest" or biome == "jungle":
				shoulder = Color(0.32, 0.24, 0.14).lerp(Color(0.42, 0.3, 0.16), n)
				asphalt = Color(0.34, 0.25, 0.14).lerp(Color(0.46, 0.32, 0.16), n)
			elif biome == "arctic":
				shoulder = Color(0.72, 0.76, 0.8).lerp(Color(0.58, 0.64, 0.7), n)
				asphalt = Color(0.22, 0.24, 0.26).lerp(Color(0.34, 0.36, 0.38), n)
			elif biome == "urban":
				shoulder = Color(0.34, 0.32, 0.3).lerp(Color(0.42, 0.4, 0.36), n)
				asphalt = Color(0.14, 0.14, 0.13).lerp(Color(0.22, 0.21, 0.2), n)
			_flat(st, prev_l, prev_r, r, l, shoulder)
			_flat(st, prev_al, prev_ar, ar, al, asphalt)
			var prev_sm_e: Dictionary = prev["sm"]
			var py_e: float = float(prev["y"])
			if paint_lines:
				for edge in [-1.0, 1.0]:
					var el0 := _road_pt(prev_sm_e, edge * 4.7, py_e + 0.26)
					var er0 := _road_pt(prev_sm_e, edge * 5.05, py_e + 0.26)
					var el1 := _road_pt(sm, edge * 4.7, y + 0.26)
					var er1 := _road_pt(sm, edge * 5.05, y + 0.26)
					_flat(dash, el0, er0, er1, el1, Color(0.9, 0.88, 0.78))
			if paint_lines and fposmod(dist, 10.0) < 4.2:
				var prev_sm: Dictionary = prev["sm"]
				var py: float = float(prev["y"])
				var pl := _road_pt(prev_sm, 0.16, py + 0.22)
				var pr := _road_pt(prev_sm, -0.16, py + 0.22)
				var cl := _road_pt(sm, 0.16, y + 0.22)
				var cr := _road_pt(sm, -0.16, y + 0.22)
				_flat(dash, pl, pr, cr, cl, Color(0.95, 0.82, 0.28))
			if bridged and bool(prev["bridge"]):
				bridge_used = true
				var rail := Color(0.55, 0.5, 0.44)
				var prev_sm_b: Dictionary = prev["sm"]
				var py_b: float = float(prev["y"])
				_flat(bridge, _road_pt(prev_sm_b, 10.5, py_b + 0.25), _road_pt(prev_sm_b, 10.5, py_b + 1.2), _road_pt(sm, 10.5, y + 1.2), _road_pt(sm, 10.5, y + 0.25), rail)
				_flat(bridge, _road_pt(prev_sm_b, -10.5, py_b + 1.2), _road_pt(prev_sm_b, -10.5, py_b + 0.25), _road_pt(sm, -10.5, y + 0.25), _road_pt(sm, -10.5, y + 1.2), rail)
				var center: Vector3 = sm["pos"]
				var bed := _natural(center.x, center.z)
				if y - bed > 3.2 and fposmod(dist, 18.0) < step:
					_pier(bridge, center, bed, y)
		prev = {"l": l, "r": r, "al": al, "ar": ar, "y": y, "sm": sm, "bridge": bridged}
		dist += step
	_commit_surface(st)
	_commit_surface(dash)
	if bridge_used:
		_commit_surface(bridge)


func _road_pt(sm: Dictionary, lateral: float, y: float) -> Vector3:
	var pos: Vector3 = sm["pos"]
	var right: Vector3 = sm["right"]
	return Vector3(pos.x + right.x * lateral, y, pos.z + right.z * lateral)


func _pier(st: SurfaceTool, pos: Vector3, bottom: float, top: float) -> void:
	var h := top - bottom
	if h < 0.6:
		return
	_aabb(st, Vector3(pos.x, bottom + h * 0.5, pos.z), Vector3(1.5, h, 1.5), Color(0.42, 0.4, 0.37))


func _aabb(st: SurfaceTool, c: Vector3, size: Vector3, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var x0 := c.x - hx
	var x1 := c.x + hx
	var y0 := c.y - hy
	var y1 := c.y + hy
	var z0 := c.z - hz
	var z1 := c.z + hz
	_flat(st, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), color)
	_flat(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), color)
	_flat(st, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), color)
	_flat(st, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), color)
	_flat(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), color)
	_flat(st, Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), color)


func _commit_surface(st: SurfaceTool) -> void:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	var mesh := st.commit()
	mi.mesh = mesh
	mi.material_override = _vertex_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(mi)


func _flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var face := (b - a).cross(c - a)
	if face.y < -0.001:
		_flat_tri(st, a, c, b, color)
		_flat_tri(st, a, d, c, color)
	else:
		_flat_tri(st, a, b, c, color)
		_flat_tri(st, a, c, d, color)


func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 0.0001:
		n = Vector3.UP
	else:
		n = n.normalized()
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(c)


func _vertex_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.94
	# Road triangles are wound against the terrain. Draw both sides so the ribbon stays visible.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_props(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 19
	var buckets := {}
	var dist := 8.0
	while dist < route.total - 8.0:
		for side in [-1.0, 1.0]:
			var lat_lo := 13.0
			var lat_hi := 40.0
			if biome == "mountain":
				lat_lo = 13.0
				lat_hi = 30.0
			var lat: float = float(side) * rng.randf_range(lat_lo, lat_hi)
			var sm: Dictionary = route.sample(dist)
			var pos: Vector3 = sm["pos"] + sm["right"] * lat
			var y := _height(pos.x, pos.z)
			if y < water_y + 0.6:
				continue
			if biome == "forest" and _stream_depth(dist, lat) > 0.4:
				continue
			if biome == "desert" and _wash_depth(dist, lat) > 0.5:
				continue
			var kind := "rock"
			var s := rng.randf_range(1.4, 2.4)
			if biome == "forest" or biome == "jungle":
				var roll_f := rng.randf()
				if biome == "jungle" and roll_f > 0.45:
					kind = "palm"
					s = rng.randf_range(2.4, 5.2)
				elif roll_f > 0.72:
					kind = "bush"
					s = rng.randf_range(1.2, 2.2)
				elif roll_f > 0.62:
					kind = "log" if biome == "forest" else "shrub"
					s = rng.randf_range(0.8, 1.4)
				elif roll_f > 0.5:
					kind = "pine_b" if biome == "forest" else "rock"
					s = rng.randf_range(1.6, 3.4)
				else:
					kind = "pine" if biome == "forest" else "palm"
					s = rng.randf_range(2.2, 5.6)
			elif biome == "arctic":
				var roll_a := rng.randf()
				if roll_a > 0.72:
					kind = "pine"
					s = rng.randf_range(1.4, 3.2)
				elif roll_a > 0.4:
					kind = "rock_b"
					s = rng.randf_range(1.2, 2.8)
				else:
					kind = "rock"
					s = rng.randf_range(0.8, 2.2)
			elif biome == "urban":
				kind = "rock" if rng.randf() > 0.45 else "rock_b"
				s = rng.randf_range(0.6, 1.6)
			elif biome == "mountain":
				var above := y - road_height(dist)
				if above < 22.0:
					kind = "pine"
					s = rng.randf_range(4.6, 7.2)
				elif above < 32.0:
					kind = "pine" if rng.randf() > 0.55 else "rock"
					s = rng.randf_range(2.4, 4.2)
				else:
					kind = "rock_b"
					s = rng.randf_range(2.4, 4.8)
			else:
				var roll := rng.randf()
				if roll > 0.62:
					kind = "cactus"
					s = rng.randf_range(2.2, 4.2)
				elif roll > 0.38:
					kind = "rock"
					s = rng.randf_range(1.6, 3.4)
				elif roll > 0.18:
					kind = "shrub"
					s = rng.randf_range(0.8, 1.6)
				elif roll > 0.08:
					kind = "rock_b"
					s = rng.randf_range(1.4, 2.8)
				else:
					kind = "palm"
					s = rng.randf_range(2.4, 4.2)
			var yaw := rng.randf_range(0.0, TAU)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
			if not buckets.has(kind):
				buckets[kind] = []
			buckets[kind].append(Transform3D(basis, Vector3(pos.x, y, pos.z)))
		if biome == "mountain":
			dist += rng.randf_range(3.4, 5.2)
		elif biome == "forest" or biome == "jungle":
			dist += rng.randf_range(3.2, 4.8)
		elif biome == "urban":
			dist += rng.randf_range(7.0, 11.0)
		elif biome == "arctic":
			dist += rng.randf_range(8.0, 14.0)
		else:
			dist += rng.randf_range(5.5, 9.0)
	if biome == "desert" or biome == "urban":
		_scatter_wrecks(rng)
	if biome == "urban":
		_scatter_blocks(rng)
	for kind in buckets.keys():
		_spawn_multi(str(kind), buckets[kind])
	_build_villages(rng)


func _scatter_kind(rng: RandomNumberGenerator, bounds: Rect2, buckets: Dictionary, kind: String, count: int, min_s: float, max_s: float, max_slope: float, cliffs: bool) -> void:
	var placed := 0
	var tries := 0
	var limit := count * 18
	var batch: Array = []
	while placed < count and tries < limit:
		tries += 1
		var x := rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x)
		var z := rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		var proj: Dictionary = route.project(Vector3(x, 0.0, z))
		if absf(float(proj["lateral"])) < 14.5:
			continue
		var y := _height(x, z)
		if y < water_y + 0.55:
			continue
		var slope := _slope_pitch(Vector3(x, y, z), Vector3(1, 0, 0))
		var steep := absf(slope)
		if cliffs:
			if steep < 0.22:
				continue
		elif kind == "pine" and biome == "mountain" and (y > 13.0 or steep > max_slope):
			continue
		elif steep > max_slope and kind != "rock" and kind != "rock_b":
			continue
		var s := rng.randf_range(min_s, max_s)
		if cliffs:
			s *= rng.randf_range(1.0, 1.35)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		batch.append(Transform3D(basis, Vector3(x, y, z)))
		placed += 1
	buckets[kind] = batch


func _spawn_multi(kind: String, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var node := meshes.prop(kind)
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		var local := _chain_xf(node, mesh_inst)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_inst.mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf * local)
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		var surfaces := mesh_inst.mesh.get_surface_count()
		if surfaces <= 1:
			var mat: Material = mesh_inst.material_override
			if mat == null and surfaces > 0:
				mat = mesh_inst.mesh.surface_get_material(0)
			if mat == null:
				var fallback := StandardMaterial3D.new()
				fallback.roughness = 0.94
				fallback.metallic = 0.0
				if kind == "rock" or kind == "rock_b":
					fallback.albedo_color = Color(0.44, 0.42, 0.39)
				elif kind == "cactus":
					fallback.albedo_color = Color(0.2, 0.42, 0.16)
				elif kind == "palm":
					fallback.albedo_color = Color(0.18, 0.42, 0.14)
				else:
					fallback.albedo_color = Color(0.16, 0.4, 0.14)
				mat = fallback
			inst.material_override = mat
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		level_root.add_child(inst)
	node.free()


func _chain_xf(root: Node3D, mi: Node3D) -> Transform3D:
	var xf := mi.transform
	var p: Node = mi.get_parent()
	while p is Node3D and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _scatter_wrecks(rng: RandomNumberGenerator) -> void:
	var dist := 70.0
	while dist < route.total - 40.0:
		var sm: Dictionary = route.sample(dist)
		var side := 1.0 if rng.randf() > 0.5 else -1.0
		var lat := side * rng.randf_range(16.0, 28.0)
		var pos: Vector3 = sm["pos"] + sm["right"] * lat
		pos.y = _height(pos.x, pos.z) - 0.25
		var wreck := meshes.build("cargo" if rng.randf() > 0.5 else "humvee", true, "desert")
		wreck.position = pos
		wreck.rotation_degrees = Vector3(rng.randf_range(-12.0, 8.0), rng.randf_range(0.0, 360.0), rng.randf_range(-18.0, 18.0))
		level_root.add_child(wreck)
		dist += rng.randf_range(110.0, 160.0)


func _scatter_blocks(rng: RandomNumberGenerator) -> void:
	var dist := 40.0
	while dist < route.total - 30.0:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.25:
				continue
			var sm: Dictionary = route.sample(dist)
			var lat := float(side) * rng.randf_range(14.0, 24.0)
			var pos: Vector3 = sm["pos"] + sm["right"] * lat
			pos.y = _height(pos.x, pos.z)
			var house := meshes.outpost()
			var s := rng.randf_range(1.1, 2.4)
			var crush := rng.randf_range(0.35, 1.0)
			house.scale = Vector3(s, s * crush, s)
			house.position = pos
			house.rotation_degrees = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(0.0, 360.0), rng.randf_range(-4.0, 4.0))
			_tint_ruin(house, Color(0.42, 0.38, 0.34))
			level_root.add_child(house)
		dist += rng.randf_range(16.0, 26.0)


func _build_villages(rng: RandomNumberGenerator) -> void:
	var clusters := 5 if biome == "desert" else (2 if biome == "forest" or biome == "jungle" else 0)
	if biome == "arctic":
		clusters = 2
	if biome == "urban":
		return
	for _c in clusters:
		var dist := rng.randf_range(90.0, maxf(route.total - 90.0, 120.0))
		var sm: Dictionary = route.sample(dist)
		var right: Vector3 = sm["right"]
		var origin: Vector3 = sm["pos"] + right * -rng.randf_range(26.0, 42.0)
		origin.y = _height(origin.x, origin.z)
		if origin.y < water_y + 1.0:
			continue
		var houses := rng.randi_range(3, 5)
		for _h in houses:
			var spot := origin + Vector3(rng.randf_range(-9.0, 9.0), 0.0, rng.randf_range(-9.0, 9.0))
			spot.y = _height(spot.x, spot.z)
			if absf(float(route.project(spot)["lateral"])) < 15.0:
				continue
			var house := meshes.outpost()
			var s := rng.randf_range(0.65, 1.15)
			var crush := rng.randf_range(0.42, 1.0)
			house.scale = Vector3(s, s * crush, s)
			house.position = spot - Vector3(0, (1.0 - crush) * 0.6, 0)
			house.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 360.0), rng.randf_range(-7.0, 7.0))
			var ruin_tint := Color(0.4, 0.3, 0.18)
			if biome == "desert":
				ruin_tint = Color(0.72, 0.5, 0.3)
			elif biome == "arctic":
				ruin_tint = Color(0.62, 0.66, 0.7)
			_tint_ruin(house, ruin_tint)
			level_root.add_child(house)
		for _r in 7:
			var rock := meshes.prop("rock" if rng.randf() > 0.5 else "rock_b")
			var rp := origin + Vector3(rng.randf_range(-11.0, 11.0), 0.0, rng.randf_range(-11.0, 11.0))
			rp.y = _height(rp.x, rp.z)
			rock.position = rp
			rock.scale = Vector3.ONE * rng.randf_range(0.45, 1.15)
			rock.rotation_degrees = Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-12, 12))
			level_root.add_child(rock)


func _tint_ruin(node: Node3D, tint: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var src: Material = mi.material_override
		if src is StandardMaterial3D:
			var dup := src.duplicate() as StandardMaterial3D
			dup.albedo_color = tint.lerp(dup.albedo_color, 0.2)
			dup.roughness = 0.94
			mi.material_override = dup


func _build_gate(dist: float, text: String, color: Color) -> void:
	var sm: Dictionary = route.sample(dist)
	var root := Node3D.new()
	var gate_pos: Vector3 = sm["pos"]
	gate_pos.y = road_height(dist)
	root.position = gate_pos
	level_root.add_child(root)
	var gate_dir: Vector3 = sm["dir"]
	_face_along(root, gate_dir, _grade_pitch(dist))
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.45, 4.2, 0.45)
		pillar.mesh = box
		pillar.position = Vector3(side * 10.2, 2.1, 0)
		pillar.material_override = meshes.mat(color.darkened(0.25))
		root.add_child(pillar)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(21.0, 0.35, 0.4)
	beam.mesh = bb
	beam.position = Vector3(0, 4.1, 0)
	beam.material_override = meshes.mat(color)
	root.add_child(beam)
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.position = Vector3(0, 4.7, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.outline_size = 8
	root.add_child(label)


func _build_slots() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := Defs.BUILD_BACK
	var prev: Dictionary = {}
	while dist <= Defs.BUILD_AHEAD:
		var sm: Dictionary = route.sample(dist)
		var y := road_height(dist) + 0.12
		var l: Vector3 = _road_pt(sm, Defs.BUILD_LAT, y)
		var r: Vector3 = _road_pt(sm, -Defs.BUILD_LAT, y)
		if not prev.is_empty():
			_flat(st, prev["l"], prev["r"], r, l, Color(0.35, 0.48, 0.28, 0.28))
		prev = {"l": l, "r": r}
		dist += 4.0
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var yard := Node3D.new()
	yard.name = "yard"
	yard.add_child(mi)
	level_root.add_child(yard)
	slot_bodies.append(yard)


func _pad_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
