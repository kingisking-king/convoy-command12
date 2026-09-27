extends RefCounted

# Original military meshes for Convoy Command. Root forward is local -Z.
# A nose marker is placed on the visual front and aligned at load time.

var host


func cargo(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.35, 1.15, 6.6, 0.55)
	_cab(body, paint, Vector3(0, 1.55, -1.85), Vector3(2.15, 1.15, 2.1))
	_glass(body, Vector3(0, 1.7, -2.85))
	_bed(body, paint, 2.6)
	_canvas(body, paint, 2.4)
	_stowage(body, paint, Vector3(-0.85, 1.35, 1.6))
	_details(body, paint, -3.15, true)
	_axles(body, [-2.15, -0.55, 0.85, 2.15], 1.22, 0.46)
	_nose(body, -3.35)
	_driver(body, Vector3(0.38, 1.15, -1.7), false)
	host._conform_forward(body)


func humvee(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.05, 0.85, 4.7, 0.48)
	_cab(body, paint, Vector3(0, 1.35, -0.15), Vector3(1.9, 0.85, 2.3))
	_glass(body, Vector3(0, 1.45, -1.35))
	_hard_box(body, paint, Vector3(0, 0.7, -2.05), Vector3(2.0, 0.45, 0.7), 0.06)
	_details(body, paint, -2.35, true)
	_axles(body, [-1.45, 1.35], 1.12, 0.42)
	_nose(body, -2.5)
	_driver(body, Vector3(0.42, 0.95, -0.35), false)
	host._conform_forward(body)
	host._gun_turret(root, Vector3(0, 1.85, -0.05), 1.25, 0.05, paint)
	_gunner(root, Vector3(0, 1.72, 0.15))


func mrap(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.35, 1.05, 5.6, 0.62)
	_hard_box(body, paint, Vector3(0, 0.42, 0.1), Vector3(1.5, 0.35, 4.4), 0.08)
	_cab(body, paint, Vector3(0, 1.7, -0.85), Vector3(2.2, 1.05, 2.5))
	_glass(body, Vector3(0, 1.85, -2.05))
	_hard_box(body, paint, Vector3(0, 1.15, 1.35), Vector3(2.2, 0.7, 1.8), 0.06)
	_details(body, paint, -2.7, true)
	_axles(body, [-1.75, 1.55], 1.28, 0.5)
	_nose(body, -2.9)
	_driver(body, Vector3(0.45, 1.2, -0.9), false)
	host._conform_forward(body)
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 2.35, -0.55)
	root.add_child(turret)
	var cup : SurfaceTool = host._surf()
	host._hard.add_cylinder(cup, 0.42, 0.22, Vector3(0, 0.05, 0), Vector3.ZERO, 14)
	host._hard.add_bevel_box(cup, Vector3(0, 0.28, -0.15), Vector3(0.55, 0.28, 0.7), 0.04)
	host._commit(turret, cup, paint)
	var gun : SurfaceTool = host._surf()
	host._hard.add_cylinder(gun, 0.045, 1.15, Vector3(0, 0.32, -0.7), Vector3(90, 0, 0), 12)
	host._commit(turret, gun, "metal")
	host._muzzle(turret, Vector3(0, 0.32, -1.25))
	_gunner(root, Vector3(0, 2.15, -0.35))


func apc(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_tracked_hull(body, paint, 2.55, 1.15, 6.4, 0.72)
	_hard_box(body, paint, Vector3(0, 1.55, -1.7), Vector3(2.2, 0.55, 1.5), 0.08)
	_glass(body, Vector3(0, 1.45, -2.55))
	_hatch(body, paint, Vector3(-0.45, 1.78, 0.4))
	_hatch(body, paint, Vector3(0.45, 1.78, 1.15))
	_details(body, paint, -3.05, false)
	_nose(body, -3.25)
	_driver(body, Vector3(0.35, 1.05, -1.55), false)
	host._conform_forward(body)
	host._gun_turret(root, Vector3(0, 2.05, -0.35), 1.85, 0.06, paint)
	_gunner(root, Vector3(0, 1.85, -0.15))


func tank(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_tracked_hull(body, paint, 2.15, 0.85, 6.8, 0.62)
	_hard_box(body, paint, Vector3(0, 0.95, -2.35), Vector3(2.0, 0.55, 1.5), 0.08)
	_hard_box(body, paint, Vector3(0, 0.85, 2.55), Vector3(1.9, 0.4, 1.1), 0.06)
	_details(body, paint, -3.2, false)
	_nose(body, -3.45)
	_driver(body, Vector3(0.28, 0.85, -0.4), false)
	host._conform_forward(body)
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 1.22, -0.15)
	root.add_child(turret)
	var shell : SurfaceTool = host._surf()
	host._hard.add_lathe(shell, PackedVector2Array([
		Vector2(0.15, 0.55), Vector2(0.85, 0.42), Vector2(1.15, 0.22),
		Vector2(1.2, 0.02), Vector2(0.7, -0.12),
	]), Vector3(0, 0.15, 0.15), Vector3.ZERO, 18)
	host._hard.add_bevel_box(shell, Vector3(0, 0.55, 0.55), Vector3(1.3, 0.28, 1.5), 0.06)
	host._commit(turret, shell, paint)
	var gun : SurfaceTool = host._surf()
	host._hard.add_cylinder(gun, 0.09, 3.3, Vector3(0, 0.42, -1.85), Vector3(90, 0, 0), 14)
	host._hard.add_cylinder(gun, 0.13, 0.28, Vector3(0, 0.42, -3.4), Vector3(90, 0, 0), 12)
	host._hard.add_cylinder(gun, 0.035, 0.85, Vector3(0.28, 0.55, -0.2), Vector3(90, 0, 0), 8)
	host._commit(turret, gun, "metal")
	host._muzzle(turret, Vector3(0, 0.42, -3.55))
	_gunner(root, Vector3(-0.35, 1.85, 0.35))


func aa(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_tracked_hull(body, paint, 2.4, 0.9, 5.8, 0.58)
	_details(body, paint, -2.7, false)
	_nose(body, -2.95)
	_driver(body, Vector3(0.32, 0.9, -1.2), false)
	host._conform_forward(body)
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 1.7, 0.15)
	root.add_child(turret)
	var base : SurfaceTool = host._surf()
	host._hard.add_cylinder(base, 0.55, 0.2, Vector3.ZERO, Vector3.ZERO, 14)
	host._hard.add_bevel_box(base, Vector3(0, 0.35, 0.05), Vector3(0.7, 0.4, 0.9), 0.05)
	host._commit(turret, base, paint)
	var guns : SurfaceTool = host._surf()
	host._hard.add_cylinder(guns, 0.045, 1.8, Vector3(-0.16, 0.55, -0.85), Vector3(78, 0, 0), 10)
	host._hard.add_cylinder(guns, 0.045, 1.8, Vector3(0.16, 0.55, -0.85), Vector3(78, 0, 0), 10)
	host._hard.add_torus(guns, 0.38, 0.04, Vector3(0, 1.15, 0.15), Vector3(70, 0, 0), 14, 8)
	host._commit(turret, guns, "metal")
	host._muzzle(turret, Vector3(0, 0.7, -1.7))
	_gunner(root, Vector3(0.45, 1.85, 0.35))


func mortar(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.25, 0.9, 5.4, 0.5)
	_cab(body, paint, Vector3(0, 1.4, -1.55), Vector3(2.05, 0.95, 1.7))
	_glass(body, Vector3(0, 1.5, -2.35))
	_hard_box(body, paint, Vector3(0, 1.15, 0.85), Vector3(2.1, 0.45, 2.2), 0.05)
	_details(body, paint, -2.55, true)
	_axles(body, [-1.7, 1.15], 1.18, 0.44)
	_nose(body, -2.75)
	_driver(body, Vector3(0.4, 1.0, -1.45), false)
	host._conform_forward(body)
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0, 1.45, 0.7)
	root.add_child(turret)
	var tube : SurfaceTool = host._surf()
	host._hard.add_cylinder(tube, 0.11, 2.1, Vector3(0, 0.55, -0.55), Vector3(58, 0, 0), 12)
	host._hard.add_cylinder(tube, 0.16, 0.18, Vector3(0, 0.15, 0.15), Vector3(58, 0, 0), 12)
	host._hard.add_bevel_box(tube, Vector3(0, 0.15, 0.2), Vector3(0.7, 0.16, 0.7), 0.03)
	host._commit(turret, tube, "metal")
	host._muzzle(turret, Vector3(0, 1.15, -1.35))
	_gunner(root, Vector3(0.55, 1.35, 0.85))


func repair(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.15, 0.9, 5.5, 0.48)
	_cab(body, paint, Vector3(0, 1.4, -1.45), Vector3(2.05, 1.0, 1.8))
	_glass(body, Vector3(0, 1.5, -2.3))
	_hard_box(body, paint, Vector3(0, 1.55, 0.85), Vector3(2.15, 1.35, 2.6), 0.06)
	_mark_cross(body, Vector3(0, 1.7, 2.2))
	_details(body, paint, -2.6, true)
	_axles(body, [-1.65, 0.35, 1.45], 1.15, 0.42)
	_nose(body, -2.8)
	_driver(body, Vector3(0.4, 1.0, -1.35), false)
	host._conform_forward(body)


func fuel(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.2, 0.85, 6.8, 0.48)
	_cab(body, paint, Vector3(0, 1.45, -2.15), Vector3(2.1, 1.05, 1.8))
	_glass(body, Vector3(0, 1.55, -3.0))
	var tank : SurfaceTool = host._surf()
	host._hard.add_cylinder(tank, 0.72, 3.4, Vector3(0, 1.45, 0.7), Vector3(0, 0, 90), 16)
	host._hard.add_bevel_box(tank, Vector3(0, 2.15, 0.7), Vector3(0.35, 0.2, 2.4), 0.03)
	host._commit(body, tank, paint)
	var band : SurfaceTool = host._surf()
	host._hard.add_bevel_box(band, Vector3(0, 1.45, 0.2), Vector3(1.5, 0.08, 0.12), 0.02)
	host._hard.add_bevel_box(band, Vector3(0, 1.45, 1.3), Vector3(1.5, 0.08, 0.12), 0.02)
	host._commit(body, band, "metal")
	_details(body, paint, -3.2, true)
	_axles(body, [-2.35, -0.85, 1.15, 2.35], 1.18, 0.44)
	_nose(body, -3.4)
	_driver(body, Vector3(0.4, 1.05, -2.05), false)
	host._conform_forward(body)


func engineer(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.3, 0.95, 5.8, 0.52)
	_cab(body, paint, Vector3(0, 1.5, -1.15), Vector3(2.15, 1.05, 2.0))
	_glass(body, Vector3(0, 1.6, -2.15))
	_hard_box(body, paint, Vector3(0, 0.55, -2.7), Vector3(2.4, 0.55, 0.35), 0.04)
	_hard_box(body, paint, Vector3(0, 0.28, -3.05), Vector3(2.6, 0.18, 0.45), 0.03)
	_hard_box(body, paint, Vector3(-0.9, 1.7, 1.3), Vector3(0.45, 0.45, 0.8), 0.04)
	_hard_box(body, paint, Vector3(0.9, 1.7, 1.3), Vector3(0.45, 0.45, 0.8), 0.04)
	_details(body, paint, -2.4, true)
	_axles(body, [-1.55, 1.45], 1.22, 0.48)
	_nose(body, -3.2)
	_driver(body, Vector3(0.4, 1.05, -1.1), false)
	host._conform_forward(body)
	host._gun_turret(root, Vector3(0, 2.15, -0.7), 1.05, 0.04, paint)
	_gunner(root, Vector3(0, 1.95, -0.45))


func medic(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 2.15, 0.9, 5.6, 0.48)
	_cab(body, paint, Vector3(0, 1.4, -1.5), Vector3(2.05, 1.0, 1.7))
	_glass(body, Vector3(0, 1.5, -2.3))
	_hard_box(body, paint, Vector3(0, 1.6, 0.75), Vector3(2.15, 1.4, 2.7), 0.06)
	_mark_cross(body, Vector3(0, 1.75, 2.15))
	_mark_cross(body, Vector3(1.1, 1.6, 0.6))
	_details(body, paint, -2.65, true)
	_axles(body, [-1.7, 1.35], 1.15, 0.42)
	_nose(body, -2.85)
	_driver(body, Vector3(0.4, 1.0, -1.4), false)
	host._conform_forward(body)


func heli(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	var fuse : SurfaceTool = host._surf()
	host._hard.add_bevel_box(fuse, Vector3(0, 0.15, -0.2), Vector3(1.7, 1.35, 4.4), 0.18)
	host._hard.add_bevel_box(fuse, Vector3(0, 0.05, -2.55), Vector3(1.15, 0.95, 1.3), 0.12)
	host._hard.add_bevel_box(fuse, Vector3(0, 0.35, 2.6), Vector3(0.28, 0.55, 2.2), 0.06)
	host._hard.add_bevel_box(fuse, Vector3(0, 0.55, 3.55), Vector3(1.7, 0.08, 0.45), 0.02)
	host._hard.add_bevel_box(fuse, Vector3(0.15, 0.85, 3.35), Vector3(0.08, 0.7, 0.35), 0.02)
	host._commit(body, fuse, paint)
	var glass : SurfaceTool = host._surf()
	host._hard.add_bevel_box(glass, Vector3(0, 0.35, -2.85), Vector3(1.05, 0.55, 0.12), 0.02)
	host._hard.add_bevel_box(glass, Vector3(-0.86, 0.25, -0.4), Vector3(0.06, 0.45, 1.1), 0.02)
	host._hard.add_bevel_box(glass, Vector3(0.86, 0.25, -0.4), Vector3(0.06, 0.45, 1.1), 0.02)
	host._commit(body, glass, "glass")
	var gear : SurfaceTool = host._surf()
	host._hard.add_cylinder(gear, 0.04, 1.5, Vector3(-0.55, -0.7, -0.2), Vector3(0, 0, 90), 8)
	host._hard.add_cylinder(gear, 0.04, 1.5, Vector3(0.55, -0.7, -0.2), Vector3(0, 0, 90), 8)
	host._hard.add_cylinder(gear, 0.035, 1.3, Vector3(0, -0.55, 0.15), Vector3(0, 0, 90), 8)
	host._commit(body, gear, "metal")
	_nose(body, -3.2)
	_driver(body, Vector3(0.28, 0.15, -1.6), false)
	host._conform_forward(body)
	var rotor := Node3D.new()
	rotor.name = "rotor"
	rotor.position = Vector3(0, 1.05, -0.35)
	root.add_child(rotor)
	var blades : SurfaceTool = host._surf()
	host._hard.add_bevel_box(blades, Vector3.ZERO, Vector3(10.5, 0.04, 0.28), 0.01)
	host._hard.add_bevel_box(blades, Vector3.ZERO, Vector3(0.28, 0.04, 10.5), 0.01)
	host._hard.add_cylinder(blades, 0.16, 0.1, Vector3.ZERO, Vector3.ZERO, 12)
	host._commit(rotor, blades, "dark")
	var tail := Node3D.new()
	tail.name = "tail_rotor"
	tail.position = Vector3(0.22, 0.55, 3.35)
	root.add_child(tail)
	var tmesh : SurfaceTool = host._surf()
	host._hard.add_bevel_box(tmesh, Vector3.ZERO, Vector3(0.04, 1.35, 0.12), 0.01)
	host._hard.add_bevel_box(tmesh, Vector3.ZERO, Vector3(0.04, 0.12, 1.35), 0.01)
	host._commit(tail, tmesh, "dark")
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = Vector3(0.45, 0.05, -1.7)
	root.add_child(turret)
	var gun : SurfaceTool = host._surf()
	host._hard.add_cylinder(gun, 0.05, 1.15, Vector3(0, 0.05, -0.7), Vector3(90, 0, 0), 10)
	host._commit(turret, gun, "metal")
	host._muzzle(turret, Vector3(0, 0.05, -1.25))
	_gunner(root, Vector3(-0.28, 0.15, -1.15))


func technical(root: Node3D, paint: String) -> void:
	var body := _holder(root)
	_hull(body, paint, 1.9, 0.75, 4.8, 0.42)
	_cab(body, paint, Vector3(0, 1.2, -1.15), Vector3(1.8, 0.8, 1.5))
	_glass(body, Vector3(0, 1.3, -1.85))
	_hard_box(body, paint, Vector3(0, 0.85, 0.85), Vector3(1.85, 0.35, 1.8), 0.04)
	_details(body, paint, -2.2, true)
	_axles(body, [-1.45, 1.25], 1.02, 0.4)
	_nose(body, -2.4)
	_driver(body, Vector3(0.35, 0.85, -1.05), true)
	host._conform_forward(body)
	host._gun_turret(root, Vector3(0, 1.45, 0.7), 1.15, 0.045, paint)
	_gunner(root, Vector3(0, 1.25, 0.55))


func _holder(root: Node3D) -> Node3D:
	var body := Node3D.new()
	body.name = "body"
	root.add_child(body)
	return body


func _hull(body: Node3D, paint: String, width: float, height: float, length: float, y: float) -> void:
	_hard_box(body, paint, Vector3(0, y, 0.05), Vector3(width, height, length), 0.1)
	var mud : SurfaceTool = host._surf()
	host._hard.add_bevel_box(mud, Vector3(0, y * 0.35, 0.05), Vector3(width * 1.02, height * 0.28, length * 0.96), 0.04)
	host._commit(body, mud, "mud")


func _tracked_hull(body: Node3D, paint: String, width: float, height: float, length: float, y: float) -> void:
	_hard_box(body, paint, Vector3(0, y + 0.25, 0), Vector3(width, height, length * 0.92), 0.1)
	var mud : SurfaceTool = host._surf()
	host._hard.add_bevel_box(mud, Vector3(0, 0.35, 0), Vector3(width * 0.7, 0.2, length * 0.8), 0.04)
	host._commit(body, mud, "mud")
	var belt : SurfaceTool = host._surf()
	host._hard.add_track(belt, -width * 0.62, length, 0.42, 0.36)
	host._hard.add_track(belt, width * 0.62, length, 0.42, 0.36)
	host._commit(body, belt, "rubber")
	var skirt : SurfaceTool = host._surf()
	host._hard.add_bevel_box(skirt, Vector3(-width * 0.62, 0.72, 0), Vector3(0.16, 0.34, length * 0.7), 0.03)
	host._hard.add_bevel_box(skirt, Vector3(width * 0.62, 0.72, 0), Vector3(0.16, 0.34, length * 0.7), 0.03)
	host._commit(body, skirt, paint)
	var zs: Array[float] = []
	var count := 5
	for i in count:
		zs.append(lerpf(-length * 0.36, length * 0.36, float(i) / float(count - 1)))
	for z in zs:
		_roadwheel(body, Vector3(-width * 0.62, 0.42, z), 0.22)
		_roadwheel(body, Vector3(width * 0.62, 0.42, z), 0.22)


func _cab(body: Node3D, paint: String, center: Vector3, size: Vector3) -> void:
	_hard_box(body, paint, center, size, 0.08)


func _glass(body: Node3D, center: Vector3) -> void:
	var glass : SurfaceTool = host._surf()
	host._hard.add_bevel_box(glass, center, Vector3(1.35, 0.42, 0.08), 0.02)
	host._commit(body, glass, "glass")


func _bed(body: Node3D, paint: String, z: float) -> void:
	_hard_box(body, paint, Vector3(0, 1.15, z * 0.15 + 0.4), Vector3(2.2, 0.35, 3.2), 0.05)
	var rails : SurfaceTool = host._surf()
	host._hard.add_bevel_box(rails, Vector3(-1.05, 1.55, 0.55), Vector3(0.08, 0.55, 3.0), 0.02)
	host._hard.add_bevel_box(rails, Vector3(1.05, 1.55, 0.55), Vector3(0.08, 0.55, 3.0), 0.02)
	host._hard.add_bevel_box(rails, Vector3(0, 1.55, 2.05), Vector3(2.1, 0.55, 0.08), 0.02)
	host._commit(body, rails, "metal")


func _canvas(body: Node3D, paint: String, length_z: float) -> void:
	var bows : SurfaceTool = host._surf()
	for z in [0.1, 0.9, 1.7]:
		host._hard.add_cylinder(bows, 0.04, 2.2, Vector3(0, 1.85, z), Vector3(0, 0, 70), 8)
	host._commit(body, bows, "metal")
	_hard_box(body, paint, Vector3(0, 2.05, 0.7), Vector3(1.9, 0.08, length_z), 0.02)


func _hard_box(body: Node3D, paint: String, center: Vector3, size: Vector3, bevel: float) -> void:
	var st : SurfaceTool = host._surf()
	host._hard.add_bevel_box(st, center, size, bevel)
	host._commit(body, st, paint)


func _stowage(body: Node3D, paint: String, pos: Vector3) -> void:
	_hard_box(body, paint, pos, Vector3(0.45, 0.32, 0.7), 0.04)
	_hard_box(body, "metal", pos + Vector3(0.55, 0.05, 0.1), Vector3(0.28, 0.38, 0.28), 0.04)


func _hatch(body: Node3D, paint: String, pos: Vector3) -> void:
	_hard_box(body, paint, pos, Vector3(0.55, 0.08, 0.55), 0.02)
	var handle : SurfaceTool = host._surf()
	host._hard.add_cylinder(handle, 0.03, 0.2, pos + Vector3(0, 0.08, 0), Vector3.ZERO, 8)
	host._commit(body, handle, "metal")


func _details(body: Node3D, paint: String, front_z: float, mirrors: bool) -> void:
	var lamps : SurfaceTool = host._surf()
	host._hard.add_cylinder(lamps, 0.07, 0.06, Vector3(-0.55, 0.72, front_z), Vector3(90, 0, 0), 8)
	host._hard.add_cylinder(lamps, 0.07, 0.06, Vector3(0.55, 0.72, front_z), Vector3(90, 0, 0), 8)
	host._commit(body, lamps, "lamp")
	var ant : SurfaceTool = host._surf()
	host._hard.add_cylinder(ant, 0.02, 1.15, Vector3(-0.7, 2.05, 0.2), Vector3.ZERO, 6)
	host._commit(body, ant, "metal")
	if mirrors:
		var mir : SurfaceTool = host._surf()
		host._hard.add_bevel_box(mir, Vector3(-1.15, 1.35, front_z + 0.45), Vector3(0.22, 0.16, 0.05), 0.01)
		host._hard.add_bevel_box(mir, Vector3(1.15, 1.35, front_z + 0.45), Vector3(0.22, 0.16, 0.05), 0.01)
		host._hard.add_cylinder(mir, 0.02, 0.28, Vector3(-1.05, 1.2, front_z + 0.45), Vector3(0, 0, 90), 6)
		host._hard.add_cylinder(mir, 0.02, 0.28, Vector3(1.05, 1.2, front_z + 0.45), Vector3(0, 0, 90), 6)
		host._commit(body, mir, "dark")
	var plate : SurfaceTool = host._surf()
	host._hard.add_bevel_box(plate, Vector3(0, 0.55, front_z - 0.02), Vector3(0.42, 0.16, 0.04), 0.01)
	host._commit(body, plate, "white")


func _axles(body: Node3D, zs: Array, x: float, radius: float) -> void:
	for z in zs:
		_wheel(body, Vector3(-x, radius, float(z)), radius)
		_wheel(body, Vector3(x, radius, float(z)), radius)


func _wheel(parent: Node3D, pos: Vector3, radius: float) -> void:
	var pivot := Node3D.new()
	pivot.name = "wheel%d" % host._wheel_i
	host._wheel_i += 1
	pivot.position = pos
	var tire : SurfaceTool = host._surf()
	host._hard.add_cylinder(tire, radius, radius * 0.55, Vector3.ZERO, Vector3(0, 0, 90), 12)
	host._commit(pivot, tire, "rubber")
	var hub : SurfaceTool = host._surf()
	host._hard.add_cylinder(hub, radius * 0.42, radius * 0.22, Vector3.ZERO, Vector3(0, 0, 90), 8)
	host._commit(pivot, hub, "metal")
	parent.add_child(pivot)


func _roadwheel(parent: Node3D, pos: Vector3, radius: float) -> void:
	_wheel(parent, pos, radius)


func _mark_cross(body: Node3D, pos: Vector3) -> void:
	var mark : SurfaceTool = host._surf()
	host._hard.add_bevel_box(mark, pos, Vector3(0.42, 0.1, 0.06), 0.01)
	host._hard.add_bevel_box(mark, pos, Vector3(0.1, 0.42, 0.06), 0.01)
	host._commit(body, mark, "white")


func _nose(body: Node3D, z: float) -> void:
	var nose := Marker3D.new()
	nose.name = "nose"
	nose.position = Vector3(0, 1.0, z)
	body.add_child(nose)


func _driver(body: Node3D, pos: Vector3, enemy: bool) -> void:
	var crew : Node3D = host._person(enemy, false)
	crew.position = pos
	crew.scale = Vector3.ONE * 0.42
	body.add_child(crew)


func _gunner(root: Node3D, pos: Vector3) -> void:
	var crew : Node3D = host._person(false, false)
	crew.position = pos
	crew.scale = Vector3.ONE * 0.4
	root.add_child(crew)
