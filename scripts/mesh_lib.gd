extends RefCounted

const Defs = preload("res://scripts/defs.gd")
const Hard = preload("res://scripts/hard_surface.gd")

var scheme := "woodland"
var _hard := Hard.new()
var _packed := {}
var _tex := {}
var _mats := {}
var _atlas := {}
var _wheel_i := 0


func build(kind: String, enemy: bool = false, camo_name: String = "") -> Node3D:
	if camo_name != "":
		scheme = camo_name
	_wheel_i = 0
	var root := Node3D.new()
	root.name = kind
	var paint := "hostile" if enemy else scheme
	match kind:
		"cargo":
			_kenney(root, "res://assets/cc0/vehicles/delivery.glb", 1.62, paint, enemy)
			_flag(root, Vector3(0, 2.55, 0.2))
		"humvee":
			_kenney(root, "res://assets/cc0/vehicles/suv.glb", 1.85, paint, enemy)
			_gun_turret(root, Vector3(0, 2.05, 0.15), 1.15, 0.045, paint)
		"apc":
			_quaternius(root, "res://assets/cc0/military/Tank2.fbx", 0.28)
		"tank":
			_quaternius(root, "res://assets/cc0/military/Tank.fbx", 0.3)
		"aa":
			_quaternius(root, "res://assets/cc0/military/Tank3.fbx", 0.28)
		"repair":
			_kenney(root, "res://assets/cc0/vehicles/van.glb", 1.7, paint, enemy)
			_repair_kit(root)
		"technical":
			_kenney(root, "res://assets/cc0/vehicles/truck-flat.glb", 1.75, "hostile", true)
			_gun_turret(root, Vector3(0, 1.7, 0.55), 1.05, 0.04, "hostile")
			var crew := _person(true, false)
			crew.position = Vector3(0.15, 1.15, 0.35)
			crew.scale = Vector3.ONE * 0.72
			root.add_child(crew)
		"infantry":
			root.add_child(_person(enemy, false))
		"rpg":
			var a := _person(enemy, true)
			a.position = Vector3(-0.45, 0, 0)
			root.add_child(a)
			var b := _person(enemy, false)
			b.position = Vector3(0.5, 0, -0.2)
			root.add_child(b)
			_muzzle(root, Vector3(-0.2, 1.45, -0.7))
		"heli":
			_heli(root)
		_:
			_kenney(root, "res://assets/cc0/vehicles/truck.glb", 1.6, paint, enemy)
	if kind != "infantry" and kind != "rpg" and kind != "heli":
		_dust(root, 2.1)
	if kind == "heli":
		_wash(root)
	_blob(root, 2.2 if kind == "tank" or kind == "heli" else 1.6)
	return root


func mat(color: Color) -> StandardMaterial3D:
	var key := "solid:%s" % color
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	_mats[key] = m
	return m


func puff(color: Color, lit: bool) -> QuadMesh:
	return _puff(color, lit)


func outpost() -> Node3D:
	var root := Node3D.new()
	root.name = "outpost"
	var walls := _surf()
	_hard.add_bevel_box(walls, Vector3(0, 1.35, 0), Vector3(4.4, 2.5, 3.6), 0.14)
	_hard.add_bevel_box(walls, Vector3(0, 2.72, 0), Vector3(4.7, 0.22, 3.9), 0.06)
	_commit(root, walls, scheme if scheme != "" else "olive")
	var glass := _surf()
	_hard.add_bevel_box(glass, Vector3(-0.7, 1.55, -1.82), Vector3(0.9, 0.7, 0.06), 0.02)
	_hard.add_bevel_box(glass, Vector3(0.85, 1.55, -1.82), Vector3(0.9, 0.7, 0.06), 0.02)
	_commit(root, glass, "glass")
	var door := _surf()
	_hard.add_bevel_box(door, Vector3(0.05, 0.7, -1.84), Vector3(0.7, 1.3, 0.08), 0.03)
	_commit(root, door, "dark")
	return root


func prop(kind: String) -> Node3D:
	var path := ""
	match kind:
		"pine":
			path = "res://assets/cc0/nature/tree_pineDefaultA.glb"
		"oak":
			path = "res://assets/cc0/nature/tree_oak.glb"
		"palm":
			path = "res://assets/cc0/nature/tree_palmTall.glb"
		"cactus":
			path = "res://assets/cc0/nature/cactus_tall.glb"
		"rock":
			path = "res://assets/cc0/nature/rock_largeA.glb"
		"rock_b":
			path = "res://assets/cc0/nature/rock_largeB.glb"
		_:
			path = "res://assets/cc0/nature/tree_detailed.glb"
	var root := _instantiate(path)
	root.name = kind
	_fix_nature(root)
	return root


func _quaternius(root: Node3D, path: String, scale: float) -> void:
	var holder := Node3D.new()
	holder.name = "body"
	holder.rotation_degrees = Vector3(0, 180, 0)
	holder.scale = Vector3.ONE * scale
	var inst := _instantiate(path)
	if inst == null:
		root.add_child(holder)
		return
	holder.add_child(inst)
	root.add_child(holder)
	_keep_model_materials(inst)
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 1.5, -0.2)
	root.add_child(turret)
	_muzzle(turret, Vector3(0, 0.35, -1.8))


func _keep_model_materials(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for s in mesh_inst.mesh.get_surface_count():
			var src := mesh_inst.mesh.surface_get_material(s)
			var dup: StandardMaterial3D
			if src is StandardMaterial3D:
				dup = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				dup = StandardMaterial3D.new()
				dup.albedo_color = Color(0.34, 0.38, 0.24)
			var arrays: Array = mesh_inst.mesh.surface_get_arrays(s)
			var raw = arrays[Mesh.ARRAY_COLOR]
			var has_color := raw is PackedColorArray and (raw as PackedColorArray).size() > 0
			dup.vertex_color_use_as_albedo = has_color
			if dup.albedo_texture == null and not dup.vertex_color_use_as_albedo:
				dup.albedo_color = Color(0.36, 0.4, 0.24)
			elif dup.albedo_texture == null and dup.albedo_color.r > 0.75 and dup.albedo_color.g > 0.75 and dup.albedo_color.b > 0.7:
				dup.albedo_color = Color(0.72, 0.74, 0.62)
			dup.roughness = clampf(dup.roughness, 0.62, 0.92)
			dup.metallic = minf(dup.metallic, 0.15)
			mesh_inst.set_surface_override_material(s, dup)


func _kenney(root: Node3D, path: String, scale: float, paint: String, enemy: bool) -> void:
	var holder := Node3D.new()
	holder.name = "body"
	holder.rotation_degrees = Vector3(0, 180, 0)
	holder.scale = Vector3.ONE * scale
	var inst := _instantiate(path)
	var spare := inst.find_child("wheel-back", true, false)
	if spare != null and str(spare.name) == "wheel-back":
		spare.name = "spare"
	holder.add_child(inst)
	root.add_child(holder)
	_tint_tree(inst, paint, enemy)


func _apc(root: Node3D, paint: String) -> void:
	var camo := _surf()
	var metal := _surf()
	var glass := _surf()
	_hard.add_bevel_box(camo, Vector3(0, 1.05, 0.1), Vector3(2.35, 1.05, 5.3), 0.12)
	_hard.add_bevel_box(camo, Vector3(0, 1.25, -1.85), Vector3(2.15, 0.7, 1.7), 0.1, Vector3(-22, 0, 0))
	_hard.add_bevel_box(camo, Vector3(0, 1.62, 0.35), Vector3(1.7, 0.28, 2.4), 0.06)
	_hard.add_bevel_box(glass, Vector3(0, 1.35, -2.45), Vector3(1.15, 0.28, 0.08), 0.02, Vector3(-28, 0, 0))
	_hard.add_cylinder(metal, 0.06, 0.08, Vector3(-0.7, 0.95, -2.55), Vector3(90, 0, 0), 12)
	_hard.add_cylinder(metal, 0.06, 0.08, Vector3(0.7, 0.95, -2.55), Vector3(90, 0, 0), 12)
	_commit(root, camo, paint)
	_commit(root, metal, "metal")
	_commit(root, glass, "glass")
	for z in [-1.7, -0.45, 0.8, 2.05]:
		_glb_wheel(root, Vector3(-1.15, 0.42, z), 1.25)
		_glb_wheel(root, Vector3(1.15, 0.42, z), 1.25)
	_gun_turret(root, Vector3(0, 1.85, -0.15), 1.7, 0.07, paint)


func _tank(root: Node3D, paint: String) -> void:
	var camo := _surf()
	var rubber := _surf()
	var metal := _surf()
	_hard.add_bevel_box(camo, Vector3(0, 0.78, 0.05), Vector3(2.05, 0.62, 4.35), 0.14)
	_hard.add_bevel_box(camo, Vector3(0, 1.02, -1.72), Vector3(1.9, 0.48, 1.35), 0.1, Vector3(-28, 0, 0))
	_hard.add_bevel_box(camo, Vector3(0, 0.92, 1.85), Vector3(1.7, 0.36, 0.95), 0.08, Vector3(18, 0, 0))
	_hard.add_bevel_box(camo, Vector3(-1.05, 0.72, 0.05), Vector3(0.18, 0.22, 3.6), 0.04)
	_hard.add_bevel_box(camo, Vector3(1.05, 0.72, 0.05), Vector3(0.18, 0.22, 3.6), 0.04)
	_hard.add_track(rubber, -1.28, 4.7, 0.48, 0.34)
	_hard.add_track(rubber, 1.28, 4.7, 0.48, 0.34)
	_commit(root, camo, paint)
	_commit(root, rubber, "rubber")
	for z in [-1.55, -0.7, 0.15, 1.0, 1.75]:
		_road_wheel(root, Vector3(-1.28, 0.48, z))
		_road_wheel(root, Vector3(1.28, 0.48, z))
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 1.28, -0.05)
	root.add_child(turret)
	var body := _surf()
	var gun := _surf()
	var profile := PackedVector2Array([
		Vector2(0.2, 0.62),
		Vector2(0.72, 0.48),
		Vector2(1.02, 0.28),
		Vector2(1.12, 0.08),
		Vector2(1.02, -0.08),
		Vector2(0.55, -0.16),
	])
	_hard.add_lathe(body, profile, Vector3(0, 0.15, 0.1), Vector3.ZERO, 22)
	_hard.add_lathe(body, PackedVector2Array([
		Vector2(0.08, 0.22),
		Vector2(0.22, 0.12),
		Vector2(0.2, 0.0),
	]), Vector3(-0.55, 0.55, 0.15), Vector3.ZERO, 12)
	_hard.add_bevel_box(body, Vector3(0.15, 0.42, 0.55), Vector3(0.7, 0.28, 0.85), 0.06)
	_hard.add_cylinder(gun, 0.075, 2.5, Vector3(0, 0.38, -1.35), Vector3(90, 0, 0), 16)
	_hard.add_cylinder(gun, 0.12, 0.22, Vector3(0, 0.38, -2.55), Vector3(90, 0, 0), 16)
	_hard.add_cylinder(gun, 0.035, 0.7, Vector3(0.28, 0.48, -0.35), Vector3(90, 0, 0), 10)
	_commit(turret, body, paint)
	_commit(turret, gun, "metal")
	_muzzle(turret, Vector3(0, 0.38, -2.7))
	_hard.add_cylinder(metal, 0.05, 0.06, Vector3(-0.45, 0.95, -2.35), Vector3(90, 0, 0), 10)
	_hard.add_cylinder(metal, 0.05, 0.06, Vector3(0.45, 0.95, -2.35), Vector3(90, 0, 0), 10)
	_commit(root, metal, "lamp")


func _aa_mount(root: Node3D, paint: String) -> void:
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 1.85, 0.35)
	root.add_child(turret)
	var body := _surf()
	var gun := _surf()
	_hard.add_cylinder(body, 0.42, 0.16, Vector3(0, 0.08, 0), Vector3.ZERO, 16)
	_hard.add_bevel_box(body, Vector3(0, 0.32, 0.05), Vector3(0.7, 0.28, 0.5), 0.05)
	_hard.add_cylinder(gun, 0.045, 1.7, Vector3(-0.14, 0.48, -0.75), Vector3(90, 0, 0), 14)
	_hard.add_cylinder(gun, 0.045, 1.7, Vector3(0.14, 0.48, -0.75), Vector3(90, 0, 0), 14)
	_hard.add_torus(gun, 0.28, 0.035, Vector3(0, 0.85, 0.05), Vector3(90, 0, 0), 16, 8)
	_commit(turret, body, paint)
	_commit(turret, gun, "metal")
	_muzzle(turret, Vector3(0, 0.48, -1.6))


func _heli(root: Node3D) -> void:
	var body := _surf()
	var glass := _surf()
	var metal := _surf()
	var profile := PackedVector2Array([
		Vector2(0.02, -1.85),
		Vector2(0.22, -1.55),
		Vector2(0.48, -1.15),
		Vector2(0.62, -0.55),
		Vector2(0.58, 0.05),
		Vector2(0.36, 0.7),
		Vector2(0.16, 1.45),
		Vector2(0.07, 2.55),
	])
	_hard.add_lathe(body, profile, Vector3.ZERO, Vector3(90, 0, 0), 18)
	var cockpit := PackedVector2Array([
		Vector2(0.05, -0.35),
		Vector2(0.32, -0.1),
		Vector2(0.28, 0.25),
		Vector2(0.08, 0.4),
	])
	_hard.add_lathe(glass, cockpit, Vector3(0, 0.18, -0.85), Vector3(90, 0, 0), 14)
	_hard.add_bevel_box(body, Vector3(0, 0.35, 2.15), Vector3(0.12, 0.55, 0.7), 0.04)
	_hard.add_bevel_box(body, Vector3(0, 0.55, 2.35), Vector3(1.3, 0.06, 0.28), 0.02)
	_hard.add_cylinder(metal, 0.035, 1.7, Vector3(-0.55, -0.28, 0.1), Vector3(0, 0, 90), 8)
	_hard.add_cylinder(metal, 0.035, 1.7, Vector3(0.55, -0.28, 0.1), Vector3(0, 0, 90), 8)
	_hard.add_cylinder(metal, 0.08, 0.9, Vector3(-0.72, -0.05, -0.2), Vector3(0, 0, 90), 10)
	_hard.add_cylinder(metal, 0.08, 0.9, Vector3(0.72, -0.05, -0.2), Vector3(0, 0, 90), 10)
	_commit(root, body, "hostile")
	_commit(root, glass, "glass")
	_commit(root, metal, "metal")
	var rotor := Node3D.new()
	rotor.name = "rotor"
	rotor.position = Vector3(0, 0.72, -0.15)
	root.add_child(rotor)
	var blades := _surf()
	_hard.add_bevel_box(blades, Vector3.ZERO, Vector3(7.6, 0.04, 0.28), 0.015)
	_hard.add_bevel_box(blades, Vector3.ZERO, Vector3(0.28, 0.04, 7.6), 0.015)
	_hard.add_cylinder(blades, 0.12, 0.08, Vector3.ZERO, Vector3.ZERO, 12)
	_commit(rotor, blades, "dark")
	var tail := Node3D.new()
	tail.name = "tail_rotor"
	tail.position = Vector3(0.08, 0.35, 2.35)
	root.add_child(tail)
	var tmesh := _surf()
	_hard.add_bevel_box(tmesh, Vector3.ZERO, Vector3(0.04, 1.35, 0.12), 0.01)
	_hard.add_bevel_box(tmesh, Vector3.ZERO, Vector3(0.04, 0.12, 1.35), 0.01)
	_commit(tail, tmesh, "dark")
	_muzzle(root, Vector3(0, -0.05, -1.7))


func _gun_turret(root: Node3D, pos: Vector3, length: float, radius: float, paint: String) -> void:
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = pos
	root.add_child(turret)
	var body := _surf()
	var gun := _surf()
	_hard.add_lathe(body, PackedVector2Array([
		Vector2(0.12, 0.22),
		Vector2(0.38, 0.12),
		Vector2(0.42, 0.0),
		Vector2(0.28, -0.08),
	]), Vector3.ZERO, Vector3.ZERO, 14)
	_hard.add_bevel_box(body, Vector3(0, 0.18, -0.05), Vector3(0.55, 0.22, 0.16), 0.03)
	_hard.add_cylinder(gun, radius, length, Vector3(0, 0.2, -length * 0.45), Vector3(90, 0, 0), 14)
	_hard.add_cylinder(gun, radius * 1.6, 0.1, Vector3(0, 0.2, -length * 0.92), Vector3(90, 0, 0), 12)
	_commit(turret, body, paint)
	_commit(turret, gun, "metal")
	_muzzle(turret, Vector3(0, 0.2, -length * 0.98))


func _repair_kit(root: Node3D) -> void:
	var mark := _surf()
	_hard.add_bevel_box(mark, Vector3(-0.55, 1.55, 0.15), Vector3(0.62, 0.12, 0.08), 0.02)
	_hard.add_bevel_box(mark, Vector3(-0.55, 1.55, 0.15), Vector3(0.12, 0.62, 0.08), 0.02)
	_commit(root, mark, "white")
	var lamp := _surf()
	_hard.add_cylinder(lamp, 0.08, 0.12, Vector3(0, 2.15, 0.1), Vector3.ZERO, 10)
	_commit(root, lamp, "lamp")


func _person(enemy: bool, rpg: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "soldier"
	var holder := Node3D.new()
	holder.rotation_degrees = Vector3(0, 180, 0)
	holder.scale = Vector3.ONE * 2.2
	var inst := _instantiate("res://assets/cc0/characters/character-male-c.glb" if not rpg else "res://assets/cc0/characters/character-male-e.glb")
	holder.add_child(inst)
	root.add_child(holder)
	_pose_arms(inst)
	_tint_soldier(inst, enemy)
	var gun := Node3D.new()
	gun.position = Vector3(0.16, 0.46, 0.28)
	holder.add_child(gun)
	var mesh := _surf()
	if rpg:
		_hard.add_cylinder(mesh, 0.045, 0.62, Vector3(0, 0.02, 0.22), Vector3(78, 8, 0), 12)
		_hard.add_taper(mesh, 0.07, 0.045, 0.12, Vector3(0, 0.08, 0.5), Vector3(78, 8, 0), 12)
	else:
		_hard.add_bevel_box(mesh, Vector3(0.0, 0.02, 0.16), Vector3(0.045, 0.07, 0.38), 0.012)
		_hard.add_cylinder(mesh, 0.012, 0.28, Vector3(0.0, 0.035, 0.42), Vector3(90, 0, 0), 8)
		_hard.add_bevel_box(mesh, Vector3(0.0, -0.02, 0.08), Vector3(0.03, 0.09, 0.08), 0.008)
	_commit(gun, mesh, "dark")
	var helm := _surf()
	_hard.add_lathe(helm, PackedVector2Array([
		Vector2(0.01, 0.1),
		Vector2(0.16, 0.06),
		Vector2(0.18, -0.02),
		Vector2(0.14, -0.06),
	]), Vector3(0, 0.72, 0.02), Vector3.ZERO, 14)
	_commit(holder, helm, "hostile" if enemy else scheme)
	if not rpg:
		_muzzle(root, Vector3(0.35, 1.15, -1.15))
	return root


func _pose_arms(inst: Node) -> void:
	var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	_bend_arm(skel, "arm-right", Vector3(-70, 30, -15))
	_bend_arm(skel, "arm-left", Vector3(-55, -18, 22))


func _bend_arm(skel: Skeleton3D, bone_name: String, euler_deg: Vector3) -> void:
	var idx := skel.find_bone(bone_name)
	if idx < 0:
		return
	var rest := skel.get_bone_rest(idx)
	var bend := Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	skel.set_bone_pose(idx, rest * Transform3D(bend, Vector3.ZERO))


func _flag(root: Node3D, pos: Vector3) -> void:
	var flag := MeshInstance3D.new()
	flag.name = "beacon"
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.32, 0.03)
	flag.mesh = box
	flag.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("e2b84a")
	m.roughness = 0.6
	flag.material_override = m
	root.add_child(flag)


func _glb_wheel(parent: Node3D, pos: Vector3, scale: float) -> void:
	var pivot := Node3D.new()
	pivot.name = "wheel%d" % _wheel_i
	_wheel_i += 1
	pivot.position = pos
	var inst := _instantiate("res://assets/cc0/vehicles/wheel-truck.glb")
	inst.name = "tire"
	inst.scale = Vector3.ONE * scale
	_paint_rubber(inst)
	pivot.add_child(inst)
	parent.add_child(pivot)


func _road_wheel(parent: Node3D, pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.name = "wheel%d" % _wheel_i
	_wheel_i += 1
	pivot.position = pos
	var st := _surf()
	_hard.add_torus(st, 0.28, 0.09, Vector3.ZERO, Vector3(0, 0, 90), 18, 8)
	_hard.add_cylinder(st, 0.12, 0.16, Vector3.ZERO, Vector3(0, 0, 90), 12)
	_commit(pivot, st, "rubber")
	var hub := _surf()
	_hard.add_cylinder(hub, 0.07, 0.18, Vector3.ZERO, Vector3(0, 0, 90), 10)
	_commit(pivot, hub, "metal")
	parent.add_child(pivot)


func _muzzle(parent: Node3D, pos: Vector3) -> void:
	if parent.get_node_or_null("muzzle"):
		return
	var muzzle := Marker3D.new()
	muzzle.name = "muzzle"
	muzzle.position = pos
	parent.add_child(muzzle)


func _dust(parent: Node3D, back: float) -> void:
	var dust := CPUParticles3D.new()
	dust.name = "dust"
	dust.position = Vector3(0, 0.25, back)
	dust.amount = 14
	dust.lifetime = 0.85
	dust.explosiveness = 0.05
	dust.randomness = 0.45
	dust.emitting = false
	dust.local_coords = false
	dust.direction = Vector3(0.4, 0.45, 1)
	dust.spread = 24.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.6
	dust.angular_velocity_min = -30
	dust.angular_velocity_max = 30
	dust.gravity = Vector3(0.6, 0.2, 0.2)
	dust.scale_amount_min = 0.7
	dust.scale_amount_max = 1.8
	dust.mesh = _puff(Color(0.78, 0.68, 0.5, 0.35), false)
	parent.add_child(dust)


func _wash(parent: Node3D) -> void:
	var wash := CPUParticles3D.new()
	wash.name = "wash"
	wash.position = Vector3(0, -14.4, 0)
	wash.amount = 22
	wash.lifetime = 0.9
	wash.emitting = false
	wash.local_coords = false
	wash.direction = Vector3(0, 0.2, 0)
	wash.spread = 85.0
	wash.initial_velocity_min = 1.5
	wash.initial_velocity_max = 4.0
	wash.gravity = Vector3(0.4, -0.2, 0.1)
	wash.scale_amount_min = 1.2
	wash.scale_amount_max = 2.8
	wash.mesh = _puff(Color(0.8, 0.72, 0.55, 0.28), false)
	parent.add_child(wash)


func _blob(parent: Node3D, radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "blob"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.025
	cyl.radial_segments = 16
	mi.mesh = cyl
	mi.position = Vector3(0, 0.03, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _instantiate(path: String) -> Node3D:
	if not _packed.has(path):
		var res = load(path)
		if res == null:
			return null
		_packed[path] = res
	var packed: PackedScene = _packed[path]
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _paint_rubber(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).material_override = _mat("rubber")


func _body_mat(paint: String) -> Material:
	var key := "bodytex:" + paint
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _military_atlas(paint)
	m.albedo_color = Color(0.9, 0.9, 0.86)
	m.roughness = 0.86
	m.metallic = 0.02
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


func _tones(paint: String) -> Array:
	if paint == "desert":
		return [Color(0.5, 0.4, 0.24), Color(0.4, 0.32, 0.18), Color(0.33, 0.36, 0.2)]
	if paint == "hostile":
		return [Color(0.32, 0.16, 0.12), Color(0.2, 0.12, 0.1), Color(0.14, 0.13, 0.12)]
	if paint == "winter":
		return [Color(0.58, 0.62, 0.64), Color(0.4, 0.46, 0.48), Color(0.28, 0.34, 0.32)]
	if paint == "urban":
		return [Color(0.36, 0.38, 0.36), Color(0.22, 0.24, 0.23), Color(0.46, 0.44, 0.38)]
	return [Color(0.28, 0.34, 0.16), Color(0.18, 0.24, 0.11), Color(0.36, 0.34, 0.18)]


func _military_atlas(paint: String) -> Texture2D:
	if _atlas.has(paint):
		return _atlas[paint]
	var src := Image.new()
	var err := ERR_FILE_NOT_FOUND
	var loaded := load("res://assets/cc0/vehicles/Textures/colormap.png")
	if loaded is Texture2D:
		src = (loaded as Texture2D).get_image()
		err = OK if src != null else ERR_FILE_NOT_FOUND
	var out := Image.create(8, 8, false, Image.FORMAT_RGB8)
	if err != OK:
		var flat: Color = _tones(paint)[0]
		out.fill(flat)
	else:
		src.convert(Image.FORMAT_RGBA8)
		var w := src.get_width()
		var h := src.get_height()
		out = Image.create(w, h, false, Image.FORMAT_RGB8)
		var tones := _tones(paint)
		for y in h:
			for x in w:
				var c := src.get_pixel(x, y)
				var luma := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				var maxc := maxf(c.r, maxf(c.g, c.b))
				var minc := minf(c.r, minf(c.g, c.b))
				if luma < 0.18 or maxc < 0.22:
					var d := clampf(luma * 0.22, 0.02, 0.07)
					out.set_pixel(x, y, Color(d, d, d * 0.95))
				elif c.b > c.r + 0.04 and c.b + 0.02 > c.g and c.b > 0.28 and (c.b - minc) > 0.08:
					var g := 0.62 + luma * 0.3
					out.set_pixel(x, y, Color(0.12 * g, 0.22 * g, 0.32 * g))
				else:
					var tone: Color = tones[0].lerp(tones[1], clampf(1.0 - luma, 0.0, 1.0))
					tone = tone.lerp(tones[2], _pix_noise(x >> 2, y >> 2) * 0.45)
					var shade := clampf(0.42 + luma * 0.85, 0.35, 1.2)
					out.set_pixel(x, y, Color(tone.r * shade, tone.g * shade, tone.b * shade))
	var tex := ImageTexture.create_from_image(out)
	_atlas[paint] = tex
	return tex


func _pix_noise(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _fix_nature(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		var mesh: Mesh = mesh_inst.mesh.duplicate()
		for s in mesh.get_surface_count():
			var src: Material = mesh_inst.mesh.surface_get_material(s)
			var mat_name := ""
			var albedo := Color.WHITE
			if src != null:
				mat_name = str(src.resource_name)
			if src is StandardMaterial3D:
				albedo = (src as StandardMaterial3D).albedo_color
			var painted := StandardMaterial3D.new()
			painted.albedo_color = _nature_color(mat_name, albedo)
			painted.roughness = 0.94
			painted.metallic = 0.0
			mesh.surface_set_material(s, painted)
		mesh_inst.mesh = mesh
		mesh_inst.material_override = null


func _nature_color(mat_name: String, albedo: Color) -> Color:
	var n := mat_name.to_lower()
	if n.find("leaf") >= 0:
		return Color(0.09, 0.3, 0.07)
	if n.find("grass") >= 0:
		return Color(0.16, 0.38, 0.1)
	if n.find("wood") >= 0 or n.find("bark") >= 0:
		return Color(0.34, 0.22, 0.13)
	if n.find("dirt") >= 0:
		return Color(0.4, 0.3, 0.18)
	if albedo.g > 0.55 and albedo.b > 0.45 and albedo.r < 0.45:
		return Color(0.09, 0.3, 0.07)
	if albedo.r > 0.7 and albedo.g > 0.35 and albedo.b < 0.55:
		return Color(0.4, 0.3, 0.18)
	return Color(0.44, 0.42, 0.39)


func _tint_tree(node: Node, paint: String, _enemy: bool) -> void:
	var body := _body_mat(paint)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D):
			continue
		var mesh_inst := mi as MeshInstance3D
		var n := str(mesh_inst.name).to_lower()
		if n.find("wheel") >= 0:
			mesh_inst.material_override = _mat("rubber")
		else:
			mesh_inst.material_override = body


func _tint_soldier(node: Node, enemy: bool) -> void:
	var cloth: Color = Color("6a4038") if enemy else Color("4e5c32")
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D):
			continue
		var tint: Color = cloth
		if str(mi.name).find("head") >= 0:
			tint = Color("c9aa8a")
		_tint_mesh(mi, tint)


func _tint_mesh(mi: MeshInstance3D, tint: Color) -> void:
	var base := mi.get_active_material(0)
	var dup: Material = base.duplicate() if base else StandardMaterial3D.new()
	if dup is StandardMaterial3D:
		(dup as StandardMaterial3D).albedo_color = tint
	mi.set_surface_override_material(0, dup)


func _palette(which: String) -> Dictionary:
	if which == "hostile":
		return {"a": Color("6e342c"), "b": Color("3a1c18"), "c": Color("8a5a32")}
	if Defs.CAMOS.has(which):
		return Defs.CAMOS[which]
	return Defs.CAMOS["woodland"]


func _surf() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _commit(node: Node3D, st: SurfaceTool, key: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "part_%s" % key
	mi.mesh = st.commit()
	mi.material_override = _mat(key)
	if key == "glass" or key == "lamp":
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


func _mat(key: String) -> Material:
	if _mats.has(key + scheme):
		return _mats[key + scheme]
	var m := StandardMaterial3D.new()
	if key == "glass":
		m.albedo_color = Color(0.65, 0.78, 0.85, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.06
		m.metallic = 0.2
	elif key == "lamp":
		m.albedo_color = Color("fff1c2")
		m.emission_enabled = true
		m.emission = Color("fff1c2")
		m.emission_energy_multiplier = 2.2
	elif key == "white":
		m.albedo_color = Color("f4f7f4")
		m.roughness = 0.45
	elif key == "rubber" or key == "dark":
		m.albedo_color = Color("1a1c1a") if key == "dark" else Color("22241f")
		m.roughness = 0.95
		m.metallic = 0.05
	elif key == "metal":
		m.albedo_color = Color("8d9490")
		m.metallic = 0.72
		m.roughness = 0.38
	else:
		var pal := _palette(key if key == "hostile" else scheme)
		m.albedo_texture = _camo_texture(pal)
		m.albedo_color = Color(0.78, 0.76, 0.7)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.42, 0.42, 0.42)
		m.roughness = 0.86
		m.metallic = 0.04
	_mats[key + scheme] = m
	return m


func _camo_texture(pal: Dictionary) -> ImageTexture:
	var id := "%s|%s|%s" % [pal["a"], pal["b"], pal["c"]]
	if _tex.has(id):
		return _tex[id]
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(pal["a"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pal["a"].r * 10000.0) ^ int(pal["b"].g * 8000.0)
	for n in 36:
		var cx := rng.randi_range(0, 127)
		var cy := rng.randi_range(0, 127)
		var rad := rng.randi_range(9, 24)
		var col: Color = pal["b"] if n % 2 == 0 else pal["c"]
		var y0 := maxi(0, cy - rad)
		var y1 := mini(128, cy + rad)
		var x0 := maxi(0, cx - rad)
		var x1 := mini(128, cx + rad)
		for y in range(y0, y1):
			for x in range(x0, x1):
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy <= rad * rad:
					img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_tex[id] = tex
	return tex


func _puff(color: Color, lit: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 1.1)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	return quad
