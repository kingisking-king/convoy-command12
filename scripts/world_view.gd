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
var pad_filled: StandardMaterial3D
var shadows_on := true

func setup() -> void:
	pad_empty = _pad_mat(Color(0.18, 0.16, 0.12, 1))
	pad_hover = _pad_mat(Color(0.72, 0.58, 0.22, 1))
	pad_filled = _pad_mat(Color(0.32, 0.36, 0.2, 1))
	env_node = WorldEnvironment.new()
	add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -32, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 180.0
	sun.shadow_bias = 0.05
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
	for i in 5:
		var rock := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.45 + float(i) * 0.08
		sph.height = sph.radius * 1.6
		sph.radial_segments = 6
		sph.rings = 3
		rock.mesh = sph
		rock.position = Vector3(-6.0 + i * 0.7, 0.2, 5.5)
		rock.scale = Vector3(1.4, 0.7, 1.0)
		rock.material_override = meshes.mat(Color("8a7058"))
		menu_root.add_child(rock)


func show_level(level: Dictionary, p_route) -> void:
	camera_mode = "build"
	cam_ready = false
	yaw = 0.15
	pitch = 0.7
	dist = 36.0
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


func show_column(slots: Array) -> void:
	for c in preview_root.get_children():
		c.free()
	if route == null:
		return
	for i in slots.size():
		var kind := str(slots[i])
		var filled: bool = kind != ""
		if i < slot_pads.size():
			slot_pads[i].material_override = pad_filled if filled else pad_empty
		if not filled:
			continue
		var sm: Dictionary = route.sample(-float(i) * Defs.SPACING)
		var node := meshes.build(kind, false)
		var look: Vector3 = sm["pos"] + sm["dir"]
		preview_root.add_child(node)
		node.position = sm["pos"]
		if look.distance_to(node.position) > 0.1:
			node.look_at(look, Vector3.UP)


func set_hover(slot: int) -> void:
	for i in slot_pads.size():
		var pad: MeshInstance3D = slot_pads[i]
		if pad.material_override == pad_filled:
			continue
		pad.material_override = pad_hover if i == slot else pad_empty


func pick_slot(screen: Vector2) -> int:
	if cam == null or get_world_3d() == null:
		return -1
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 900.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	var body = hit["collider"]
	if body and body.has_meta("slot"):
		return int(body.get_meta("slot"))
	return -1


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
		var face: Vector3 = pos + u["dir"]
		if face.distance_to(pos) > 0.05:
			node.look_at(face, Vector3.UP)
		_spin(node, dt, bool(u["moving"]))
		_aim(node, u, sim, dt)
		_hp(node, float(u["hp"]) / float(u["max_hp"]), bool(u["alive"]))
		if not u["alive"]:
			_wreck(node)
		elif u["delivered"]:
			_mark_delivered(node)
		if u["alive"] and not u["delivered"]:
			acc += pos
			dir_acc += u["dir"]
			count += 1
	for e in sim.enemies:
		seen[int(e["id"])] = true
		var node_e := _ensure_actor(int(e["id"]), str(e["kind"]), true, 1.6 if e["kind"] == "infantry" or e["kind"] == "rpg" else 2.1, Color("e15b4c"))
		node_e.position = e["pos"]
		_spin(node_e, dt, bool(e["alive"]) and not bool(e["air"]))
		if bool(e["air"]):
			var rotor := node_e.get_node_or_null("rotor")
			if rotor:
				rotor.rotate_y(dt * 16.0)
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
		_tracer(ev["a"], ev["b"], col)
	elif kind == "boom":
		_explosion(ev["pos"], bool(ev.get("big", false)))
		shake = maxf(shake, 0.55 if bool(ev.get("big", false)) else 0.25)
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
		yaw = 0.15
		pitch = 0.7
		dist = 36.0


func _frame_build(dt: float) -> void:
	if route == null:
		return
	var sm: Dictionary = route.sample(-24.0)
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
	for c in node.get_children():
		if str(c.name).begins_with("wheel"):
			c.rotate_x(dt * 10.0)


func _wreck(node: Node3D) -> void:
	if node.has_meta("wreck"):
		return
	node.set_meta("wreck", true)
	var hp := node.get_node_or_null("hp")
	if hp:
		hp.visible = false
	for c in node.find_children("*", "MeshInstance3D", true, false):
		if str(c.name) == "blob":
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.16, 0.13, 0.11)
		m.roughness = 1.0
		c.material_override = m


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


func _tracer(a: Vector3, b: Vector3, color: Color) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, len)
	mi.mesh = box
	mi.position = (a + b) * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(mi)
	if mi.global_position.distance_to(b) > 0.05:
		mi.look_at(b, Vector3.UP)
	fx_items.append({"node": mi, "life": 0.08, "max": 0.08})


func _explosion(pos: Vector3, big: bool) -> void:
	var flash := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.1 if big else 0.55
	sph.height = sph.radius * 2.0
	sph.radial_segments = 8
	sph.rings = 4
	flash.mesh = sph
	flash.position = pos + Vector3(0, 0.8, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.62, 0.22, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 2.5
	flash.material_override = m
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(flash)
	fx_items.append({"node": flash, "life": 0.35, "max": 0.35, "scale": true})
	var parts := CPUParticles3D.new()
	parts.position = pos + Vector3(0, 0.6, 0)
	parts.one_shot = true
	parts.explosiveness = 0.92
	parts.amount = 28 if big else 14
	parts.lifetime = 0.7
	parts.emitting = true
	parts.direction = Vector3.UP
	parts.spread = 70
	parts.initial_velocity_min = 3
	parts.initial_velocity_max = 9 if big else 6
	parts.gravity = Vector3(0, -8, 0)
	parts.scale_amount_min = 0.25
	parts.scale_amount_max = 0.7
	parts.color = Color(1.0, 0.55, 0.2)
	parts.mesh = SphereMesh.new()
	fx_root.add_child(parts)
	fx_items.append({"node": parts, "life": 1.3, "max": 1.3})


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
		if item.get("scale", false):
			var s := 1.0 + (1.0 - a) * 2.2
			node.scale = Vector3.ONE * s
		keep.append(item)
	fx_items = keep


func _sync_smoke(sim) -> void:
	var active: bool = sim.smoke_timer > 0.0
	if not active:
		for n in smoke_puffs:
			if is_instance_valid(n):
				n.visible = false
		return
	var needed := 0
	for u in sim.friendlies:
		if u["alive"] and not u["delivered"]:
			needed += 1
	while smoke_puffs.size() < needed:
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 3.2
		sph.height = 5.0
		sph.radial_segments = 8
		sph.rings = 4
		mi.mesh = sph
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.75, 0.75, 0.72, 0.28)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		smoke_puffs.append(mi)
	var i := 0
	for u in sim.friendlies:
		if not u["alive"] or u["delivered"]:
			continue
		var puff: MeshInstance3D = smoke_puffs[i]
		puff.visible = true
		puff.position = u["pos"] + Vector3(0, 1.8, 0)
		i += 1
	while i < smoke_puffs.size():
		smoke_puffs[i].visible = false
		i += 1


func _sync_strikes(sim) -> void:
	var live: Array = []
	for strike in sim.strikes:
		if bool(strike["boom"]):
			continue
		live.append(strike)
	while rings.size() < live.size():
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 14.0
		cyl.bottom_radius = 14.0
		cyl.height = 0.15
		cyl.radial_segments = 20
		mi.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.28, 0.12, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		rings.append(mi)
	for i in rings.size():
		if i >= live.size():
			rings[i].visible = false
			continue
		var strike = live[i]
		rings[i].visible = true
		var p: Vector3 = strike["pos"]
		rings[i].position = Vector3(p.x, 0.4, p.z)
		var pulse := 0.85 + 0.2 * sin(float(strike["eta"]) * 18.0)
		rings[i].scale = Vector3(pulse, 1, pulse)


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
	unit_nodes.clear()
	smoke_puffs.clear()
	rings.clear()
	fx_items.clear()


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
	return raw * smoothstep(8.0, 22.0, d)


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
	var has_prev := false
	var step := 2.2
	while dist < route.total + 24.0:
		var sm: Dictionary = route.sample(dist)
		var l: Vector3 = sm["pos"] + sm["right"] * 4.3 + Vector3.UP * 0.12
		var r: Vector3 = sm["pos"] - sm["right"] * 4.3 + Vector3.UP * 0.12
		if has_prev:
			_flat(st, prev_l, prev_r, r, l, Color("4a463f"))
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
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	level_root.add_child(root)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.26
	cyl.height = 1.3
	cyl.radial_segments = 6
	trunk.mesh = cyl
	trunk.position = Vector3(0, 0.65, 0)
	trunk.material_override = meshes.mat(Color("6a4a2e"))
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trunk)
	var crown := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.35
	cone.height = 2.8
	cone.radial_segments = 6
	crown.mesh = cone
	crown.position = Vector3(0, 2.3, 0)
	var leaf := Color("1f4d2c") if biome != "desert" else Color("8a7048")
	if biome == "forest":
		leaf = Color("1c5a30") if pos.x + pos.z > 0 else Color("245c38")
	crown.material_override = meshes.mat(leaf)
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(crown)


func _rock(pos: Vector3, scale: float) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.7
	sph.height = 1.0
	sph.radial_segments = 5
	sph.rings = 3
	mi.mesh = sph
	mi.position = pos + Vector3(0, 0.25 * scale, 0)
	mi.scale = Vector3(scale, scale * 0.65, scale * 0.85)
	var col := Color("8d7860") if biome == "desert" else Color("6a7076")
	mi.material_override = meshes.mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(mi)


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
		pillar.position = Vector3(side * 4.6, 2.1, 0)
		pillar.material_override = meshes.mat(color.darkened(0.25))
		root.add_child(pillar)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(9.6, 0.4, 0.4)
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
	for i in Defs.MAX_SLOTS:
		var sm: Dictionary = route.sample(-float(i) * Defs.SPACING)
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = sm["pos"] + Vector3(0, 0.5, 0)
		body.set_meta("slot", i)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.4, 1.4, 6.6)
		shape.shape = box
		body.add_child(shape)
		var pad := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, 0.08, 5.4)
		pad.mesh = bm
		pad.position = Vector3(0, -0.42, 0)
		pad.material_override = pad_empty
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(pad)
		var label := Label3D.new()
		label.text = str(i + 1)
		label.font_size = 56
		label.position = Vector3(0, 0.15, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.95, 0.86, 0.55)
		body.add_child(label)
		var ahead: Vector3 = sm["pos"] + sm["dir"]
		level_root.add_child(body)
		if ahead.distance_to(sm["pos"]) > 0.1:
			body.look_at(ahead, Vector3.UP)
		slot_bodies.append(body)
		slot_pads.append(pad)


func _pad_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m
