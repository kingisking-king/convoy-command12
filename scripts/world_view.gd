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
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_bias = 0.04
	sun.shadow_blur = 1.2
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
	yaw = 0.55
	pitch = 0.78
	dist = 44.0
	route = p_route
	biome = str(level["biome"])
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
	for entry in units:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kind := str(entry.get("kind", ""))
		if kind == "":
			continue
		var lane := int(entry.get("lane", Defs.CENTER))
		var row := int(entry.get("row", 0))
		var yaw_deg := int(entry.get("yaw", 0))
		var placed := _cell_pose(lane, row, yaw_deg)
		var node := meshes.build(kind, false, camo)
		preview_root.add_child(node)
		node.position = placed["pos"]
		var look: Vector3 = placed["pos"] + placed["dir"]
		if look.distance_to(node.position) > 0.1:
			node.look_at(look, Vector3.UP)
		var key := _cell_key(lane, row)
		if cell_pad.has(key):
			var mark: MeshInstance3D = cell_pad[key]
			mark.material_override = pad_select if lane == sel_lane and row == sel_row else pad_filled


func set_ghost(kind: String, cell: Vector2i, ok: bool, camo: String) -> void:
	if kind == "" or cell.x < 0 or route == null:
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
	var placed := _cell_pose(cell.x, cell.y, 0)
	ghost.position = placed["pos"] + Vector3(0, 0.15, 0)
	var look: Vector3 = ghost.position + placed["dir"]
	if look.distance_to(ghost.position) > 0.1:
		ghost.look_at(look, Vector3.UP)


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
		node.position = pos
		var alive: bool = bool(u["alive"])
		if alive:
			var face: Vector3 = pos + u["dir"]
			if face.distance_to(pos) > 0.05:
				node.look_at(face, Vector3.UP)
			_spin(node, dt, bool(u["moving"]))
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
		node_e.position = e["pos"]
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
			var flat := Vector3(focus.x - e["pos"].x, 0, focus.z - e["pos"].z)
			if flat.length() > 0.2:
				node_e.look_at(node_e.position + flat.normalized(), Vector3.UP)
	if count > 0:
		focus = acc / float(count)
		if dir_acc.length() > 0.1:
			travel_dir = dir_acc.normalized()
	_sync_smoke(sim)
	_sync_strikes(sim)


func tick(dt: float) -> void:
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
		yaw = 0.0
		pitch = 0.48
		dist = 28.0
	else:
		yaw = 0.55
		pitch = 0.78
		dist = 44.0


func _frame_build(dt: float) -> void:
	if route == null:
		return
	var sm: Dictionary = route.sample(-20.0)
	var anchor: Vector3 = sm["pos"] + Vector3(0, 1.0, 0)
	var behind: Vector3 = -sm["dir"]
	var swung: Vector3 = Basis(Vector3.UP, yaw) * behind
	swung.y = 0.0
	if swung.length() < 0.01:
		swung = Vector3(0, 0, -1)
	swung = swung.normalized()
	var elev := clampf(pitch, 0.22, 1.2)
	var offset := swung * cos(elev) * dist + Vector3.UP * sin(elev) * dist
	_glide(anchor + offset, anchor, dt)


func _frame_drive(dt: float) -> void:
	var elev := clampf(pitch, 0.18, 1.15)
	var back := -travel_dir
	if back.length() < 0.01:
		back = Vector3(0, 0, -1)
	back = Basis(Vector3.UP, yaw) * back
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3(0, 0, -1)
	back = back.normalized()
	var look := focus + Vector3(0, 1.5, 0)
	var offset := back * cos(elev) * dist + Vector3.UP * sin(elev) * dist
	_glide(look + offset, look, dt)


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
	var local_target: Vector3 = node.to_local(target["pos"])
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
			puff.global_position = u["pos"] + Vector3(0, 1.4, 0)
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
		marker.position = Vector3(p.x, 0.35, p.z)
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
	mi.position = Vector3(pos.x, 0.18, pos.z)
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


func _cell_pose(lane: int, row: int, yaw_deg: int) -> Dictionary:
	var sm: Dictionary = route.sample(Defs.along(row))
	var pos: Vector3 = sm["pos"] + sm["right"] * Defs.lateral(lane)
	var dir: Vector3 = Basis(Vector3.UP, deg_to_rad(float(yaw_deg))) * sm["dir"]
	return {"pos": pos, "dir": dir}


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
	var top := Color("6ea4c8")
	var horizon := Color("e7c7a2")
	var ground := Color("c4a06a")
	var fog := Color("e0c39a")
	var density := 0.0028
	if which == "forest":
		top = Color("4f86b0")
		horizon = Color("c5d4c4")
		ground = Color("3d5a38")
		fog = Color("b7c6b4")
		density = 0.0042
	elif which == "mountain":
		top = Color("6a88aa")
		horizon = Color("d5dde4")
		ground = Color("8d949c")
		fog = Color("c9d3dc")
		density = 0.0034
	mat.sky_top_color = top
	mat.sky_horizon_color = horizon
	mat.ground_horizon_color = horizon.darkened(0.05)
	mat.ground_bottom_color = ground
	mat.sun_angle_max = 35.0
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = horizon.lerp(top, 0.35)
	env.ambient_light_energy = 0.72
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = density
	env.fog_light_color = fog
	env.fog_aerial_perspective = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.85
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	if RenderingServer.get_rendering_device() != null:
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.15
		env.ssao_power = 1.4
	env_node.environment = env
	if which == "mountain":
		sun.rotation_degrees = Vector3(-32, -50, 0)
		sun.light_color = Color(0.92, 0.95, 1.0)
	elif which == "forest":
		sun.rotation_degrees = Vector3(-50, -20, 0)
		sun.light_color = Color(1.0, 0.97, 0.9)
	else:
		sun.rotation_degrees = Vector3(-48, -28, 0)
		sun.light_color = Color(1.0, 0.93, 0.78)


func _build_terrain() -> void:
	var bounds: Rect2 = route.bounds(78.0)
	var step := 4.2
	var nx := int(bounds.size.x / step) + 1
	var nz := int(bounds.size.y / step) + 1
	if nx * nz > 28000:
		step *= sqrt(float(nx * nz) / 28000.0)
		nx = int(bounds.size.x / step) + 1
		nz = int(bounds.size.y / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	grid.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var x := bounds.position.x + float(ix) * step
			var z := bounds.position.y + float(iz) * step
			grid[ix + iz * nx] = Vector3(x, _height(x, z), z)
	for iz in nz - 1:
		for ix in nx - 1:
			var a: Vector3 = grid[ix + iz * nx]
			var b: Vector3 = grid[ix + 1 + iz * nx]
			var c: Vector3 = grid[ix + (iz + 1) * nx]
			var d: Vector3 = grid[ix + 1 + (iz + 1) * nx]
			_tri(st, a, c, b)
			_tri(st, b, c, d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_color(_ground_color(a))
	st.add_vertex(a)
	st.set_color(_ground_color(b))
	st.add_vertex(b)
	st.set_color(_ground_color(c))
	st.add_vertex(c)


func _height(x: float, z: float) -> float:
	var d: float = route.distance_to_route(Vector3(x, 0, z))
	var raw := _raw_height(x, z)
	return raw * smoothstep(12.0, 26.0, d)


func _raw_height(x: float, z: float) -> float:
	if biome == "forest":
		return sin(x * 0.021) * 1.15 + sin(z * 0.024 + 0.5) * 1.25 + sin(x * 0.08 + z * 0.05) * 0.35
	if biome == "mountain":
		return sin(x * 0.013) * 8.5 + sin(z * 0.011 + 1.4) * 10.5 + sin(x * 0.042 + z * 0.03) * 2.2
	return sin(x * 0.031 + 0.8) * 1.7 + sin(z * 0.026) * 2.1 + sin((x + z) * 0.07) * 0.4


func _ground_color(p: Vector3) -> Color:
	var raw := _raw_height(p.x, p.z)
	if biome == "forest":
		return Color("3f6a38").lerp(Color("2a4424"), clampf(raw / 2.0, 0, 1))
	if biome == "mountain":
		var rock := Color("6c7278").lerp(Color("596066"), clampf(p.y / 8.0, 0, 1))
		if raw > 7.5:
			rock = rock.lerp(Color("e7eef2"), clampf((raw - 7.5) / 4.0, 0, 1))
		return rock
	return Color("c6a36c").lerp(Color("a07d49"), clampf(raw / 2.5, 0, 1))


func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dash := SurfaceTool.new()
	dash.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := -70.0
	var prev_l: Vector3
	var prev_r: Vector3
	var prev_al: Vector3
	var prev_ar: Vector3
	var has_prev := false
	var step := 2.2
	while dist < route.total + 24.0:
		var sm: Dictionary = route.sample(dist)
		var l: Vector3 = sm["pos"] + sm["right"] * 11.2 + Vector3.UP * 0.08
		var r: Vector3 = sm["pos"] - sm["right"] * 11.2 + Vector3.UP * 0.08
		var al: Vector3 = sm["pos"] + sm["right"] * 8.4 + Vector3.UP * 0.14
		var ar: Vector3 = sm["pos"] - sm["right"] * 8.4 + Vector3.UP * 0.14
		if has_prev:
			_flat(st, prev_l, prev_r, r, l, Color("6a5840") if biome == "desert" else Color("4e5648"))
			_flat(st, prev_al, prev_ar, ar, al, Color("3e3c38"))
			var span := fposmod(dist, 10.0)
			if span < 4.0:
				var cl: Vector3 = sm["pos"] + sm["right"] * 0.12 + Vector3.UP * 0.16
				var cr: Vector3 = sm["pos"] - sm["right"] * 0.12 + Vector3.UP * 0.16
				var pl: Vector3 = prev_l.lerp(prev_r, 0.5) + Vector3.UP * 0.04
				var pr: Vector3 = pl
				# center from previous midpoint
				var prev_sm: Dictionary = route.sample(dist - step)
				pl = prev_sm["pos"] + prev_sm["right"] * 0.12 + Vector3.UP * 0.16
				pr = prev_sm["pos"] - prev_sm["right"] * 0.12 + Vector3.UP * 0.16
				_flat(dash, pl, pr, cr, cl, Color("e2c36a"))
		prev_l = l
		prev_r = r
		prev_al = al
		prev_ar = ar
		has_prev = true
		dist += step
	st.generate_normals()
	dash.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = _vertex_mat()
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(road)
	var line := MeshInstance3D.new()
	line.mesh = dash.commit()
	line.material_override = _vertex_mat()
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(line)


func _flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(b)
	st.set_color(color)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color)
	st.add_vertex(c)
	st.set_color(color)
	st.add_vertex(d)


func _vertex_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	return m


func _build_props(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 19
	var bounds: Rect2 = route.bounds(70.0)
	var trees := 70 if biome == "forest" else (18 if biome == "mountain" else 8)
	var rocks := 26 if biome == "desert" else (40 if biome == "mountain" else 16)
	_scatter(rng, bounds, trees, true)
	_scatter(rng, bounds, rocks, false)
	var dist := 40.0
	var side := 1.0
	while dist < route.total - 30.0:
		var sm: Dictionary = route.sample(dist)
		var spot: Vector3 = sm["pos"] + sm["right"] * 16.0 * side
		spot.y = _height(spot.x, spot.z)
		var house := meshes.outpost()
		house.position = spot
		var ahead: Vector3 = spot + sm["dir"]
		level_root.add_child(house)
		if ahead.distance_to(spot) > 0.2:
			house.look_at(ahead, Vector3.UP)
		side *= -1.0
		dist += 95.0


func _scatter(rng: RandomNumberGenerator, bounds: Rect2, count: int, trees: bool) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 12:
		tries += 1
		var x := rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x)
		var z := rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		var d: float = route.distance_to_route(Vector3(x, 0, z))
		if d < 12.0 or d > 68.0:
			continue
		var y := _height(x, z)
		if trees:
			_tree(Vector3(x, y, z), rng.randf_range(0.8, 1.5))
		else:
			_rock(Vector3(x, y, z), rng.randf_range(0.6, 1.8))
		placed += 1


func _tree(pos: Vector3, scale: float) -> void:
	var kind := "pine"
	if biome == "desert":
		kind = "cactus" if int(absf(pos.x * 3.0)) % 2 == 0 else "palm"
	elif biome == "forest":
		kind = "oak" if int(absf(pos.z)) % 2 == 0 else "pine"
	var node := meshes.prop(kind)
	node.position = pos
	var fit := 1.35 if kind == "cactus" else 1.7
	node.scale = Vector3.ONE * scale * fit
	level_root.add_child(node)


func _rock(pos: Vector3, scale: float) -> void:
	var node := meshes.prop("rock" if int(absf(pos.x)) % 2 == 0 else "rock_b")
	node.position = pos
	node.scale = Vector3.ONE * scale * 0.85
	level_root.add_child(node)


func _build_gate(dist: float, text: String, color: Color) -> void:
	var sm: Dictionary = route.sample(dist)
	var root := Node3D.new()
	root.position = sm["pos"]
	level_root.add_child(root)
	var ahead: Vector3 = sm["pos"] + sm["dir"]
	if ahead.distance_to(sm["pos"]) > 0.1:
		root.look_at(ahead, Vector3.UP)
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
	for row in Defs.ROWS:
		for lane in Defs.LANES:
			var sm: Dictionary = route.sample(Defs.along(row))
			var pos: Vector3 = sm["pos"] + sm["right"] * Defs.lateral(lane)
			var body := StaticBody3D.new()
			body.collision_layer = 2
			body.collision_mask = 0
			body.position = pos + Vector3(0, 0.45, 0)
			body.set_meta("lane", lane)
			body.set_meta("row", row)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(3.05, 1.2, 6.4)
			shape.shape = box
			body.add_child(shape)
			var pad := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3.0, 0.07, 6.3)
			pad.mesh = bm
			pad.position = Vector3(0, -0.38, 0)
			pad.material_override = pad_empty
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(pad)
			var ahead: Vector3 = pos + sm["dir"]
			level_root.add_child(body)
			if ahead.distance_to(pos) > 0.1:
				body.look_at(ahead, Vector3.UP)
			slot_bodies.append(body)
			slot_pads.append(pad)
			cell_pad[_cell_key(lane, row)] = pad


func _pad_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
