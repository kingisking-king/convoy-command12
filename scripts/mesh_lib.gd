extends RefCounted

const OLIVE := Color("55612e")
const OLIVE_DARK := Color("3c4422")
const TAN := Color("c6b27a")
const CANVAS := Color("b7a56b")
const RUBBER := Color("1a1b18")
const METAL := Color("8a8f8c")
const GLASS := Color("8fb4c2")
const STEEL := Color("3a3f44")
const ENEMY := Color("7a332c")
const ENEMY_DARK := Color("4e221e")
const RUST := Color("8d5334")
const CARGO_RED := Color("8e3a32")

var _mats := {}
var _boxes := {}


func mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.04
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_mats[key] = m
	return m


func build(kind: String, enemy: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	match kind:
		"cargo":
			_cargo(root)
		"humvee":
			_humvee(root, enemy)
		"apc":
			_apc(root, enemy)
		"tank":
			_tank(root, enemy)
		"aa":
			_aa(root, enemy)
		"repair":
			_repair(root)
		"infantry":
			_soldier(root, enemy, false)
		"rpg":
			_soldier(root, enemy, true)
		"technical":
			_technical(root)
		"heli":
			_heli(root)
		_:
			_box(root, Vector3(1.5, 1, 3), Vector3.ZERO, OLIVE)
	_blob(root)
	return root


func _cargo(root: Node3D) -> void:
	_box(root, Vector3(1.85, 1.15, 1.7), Vector3(0, 0.95, -1.7), OLIVE)
	_box(root, Vector3(1.55, 0.7, 1.15), Vector3(0, 1.7, -1.85), OLIVE_DARK)
	_box(root, Vector3(1.2, 0.55, 0.08), Vector3(0, 1.75, -2.45), GLASS)
	_box(root, Vector3(1.9, 0.85, 3.3), Vector3(0, 0.85, 0.85), OLIVE_DARK)
	_box(root, Vector3(1.75, 0.7, 3.05), Vector3(0, 1.55, 0.85), CANVAS)
	_box(root, Vector3(0.08, 1.5, 0.08), Vector3(-0.7, 2.4, 0.2), STEEL)
	var flag := _box(root, Vector3(0.7, 0.38, 0.05), Vector3(-0.35, 2.95, 0.2), Color("e2b84a"))
	flag.name = "beacon"
	_wheels(root, [Vector3(-0.85, 0.42, -1.7), Vector3(0.85, 0.42, -1.7), Vector3(-0.85, 0.42, 0.3), Vector3(0.85, 0.42, 0.3), Vector3(-0.85, 0.42, 1.7), Vector3(0.85, 0.42, 1.7)], 0.42)


func _humvee(root: Node3D, enemy: bool) -> void:
	var body: Color = ENEMY if enemy else OLIVE
	var dark: Color = ENEMY_DARK if enemy else OLIVE_DARK
	_box(root, Vector3(1.9, 0.7, 3.7), Vector3(0, 0.75, 0.1), body)
	_box(root, Vector3(1.6, 0.62, 1.5), Vector3(0, 1.35, -0.35), dark)
	_box(root, Vector3(1.35, 0.42, 0.06), Vector3(0, 1.4, -1.12), GLASS)
	_wheels(root, [Vector3(-0.95, 0.4, -1.25), Vector3(0.95, 0.4, -1.25), Vector3(-0.95, 0.4, 1.2), Vector3(0.95, 0.4, 1.2)], 0.4)
	var turret := _turret(root, Vector3(0, 1.25, 0.85), 1.35, 0.07, METAL, 0.0)
	_box(turret, Vector3(0.7, 0.28, 0.7), Vector3(0, 0.05, 0), STEEL)


func _apc(root: Node3D, enemy: bool) -> void:
	var body: Color = ENEMY if enemy else Color("4a5630")
	_box(root, Vector3(2.15, 1.05, 4.5), Vector3(0, 0.9, 0.1), body)
	_box(root, Vector3(1.7, 0.45, 1.2), Vector3(0, 1.15, -1.7), body.darkened(0.15))
	_wheels(root, [Vector3(-1.05, 0.42, -1.4), Vector3(1.05, 0.42, -1.4), Vector3(-1.05, 0.42, 0.1), Vector3(1.05, 0.42, 0.1), Vector3(-1.05, 0.42, 1.5), Vector3(1.05, 0.42, 1.5)], 0.42)
	var turret := _turret(root, Vector3(0, 1.5, -0.2), 1.7, 0.09, METAL, 0.0)
	_box(turret, Vector3(1.15, 0.42, 1.35), Vector3(0, 0.15, 0.1), STEEL)


func _tank(root: Node3D, enemy: bool) -> void:
	var body: Color = ENEMY_DARK if enemy else Color("3e4a28")
	_box(root, Vector3(2.5, 0.55, 5.1), Vector3(0, 0.7, 0), body)
	_box(root, Vector3(0.45, 0.7, 5.0), Vector3(-1.15, 0.75, 0), RUBBER)
	_box(root, Vector3(0.45, 0.7, 5.0), Vector3(1.15, 0.75, 0), RUBBER)
	_box(root, Vector3(1.5, 0.35, 1.1), Vector3(0, 0.85, -2.0), body.lightened(0.08))
	var turret := _turret(root, Vector3(0, 1.25, -0.15), 2.5, 0.1, Color("2c3130"), 0.0)
	_box(turret, Vector3(1.45, 0.5, 1.8), Vector3(0, 0.2, 0.15), STEEL)


func _aa(root: Node3D, enemy: bool) -> void:
	var body: Color = ENEMY if enemy else Color("5d6840")
	_box(root, Vector3(1.9, 0.7, 4.0), Vector3(0, 0.75, 0.15), body)
	_box(root, Vector3(1.4, 0.55, 1.2), Vector3(0, 1.3, -1.15), body.darkened(0.12))
	_wheels(root, [Vector3(-0.95, 0.4, -1.2), Vector3(0.95, 0.4, -1.2), Vector3(-0.95, 0.4, 1.15), Vector3(0.95, 0.4, 1.15)], 0.4)
	var turret := _turret(root, Vector3(0, 1.25, 0.55), 1.55, 0.06, METAL, -38.0)
	var left := _box(turret, Vector3(0.08, 0.08, 1.5), Vector3(-0.18, 0.28, -0.55), Color("d7d2c4"))
	left.rotation_degrees = Vector3(-38, 0, 0)
	var right := _box(turret, Vector3(0.08, 0.08, 1.5), Vector3(0.18, 0.28, -0.55), Color("d7d2c4"))
	right.rotation_degrees = Vector3(-38, 0, 0)


func _repair(root: Node3D) -> void:
	_box(root, Vector3(1.8, 1.05, 1.6), Vector3(0, 0.9, -1.55), Color("2f5e48"))
	_box(root, Vector3(1.45, 0.6, 1.05), Vector3(0, 1.6, -1.65), Color("244a38"))
	_box(root, Vector3(1.85, 0.7, 2.8), Vector3(0, 0.85, 0.85), Color("3d6b52"))
	_box(root, Vector3(0.12, 0.7, 0.12), Vector3(0, 1.55, 0.7), Color("e8f0ea"))
	_box(root, Vector3(0.62, 0.12, 0.12), Vector3(0, 1.55, 0.7), Color("e8f0ea"))
	_box(root, Vector3(0.1, 0.1, 1.4), Vector3(0.55, 1.7, 0.2), METAL)
	_wheels(root, [Vector3(-0.85, 0.4, -1.5), Vector3(0.85, 0.4, -1.5), Vector3(-0.85, 0.4, 0.4), Vector3(0.85, 0.4, 0.4), Vector3(-0.85, 0.4, 1.6), Vector3(0.85, 0.4, 1.6)], 0.4)


func _technical(root: Node3D) -> void:
	_box(root, Vector3(1.7, 0.55, 3.4), Vector3(0, 0.7, 0.1), RUST)
	_box(root, Vector3(1.45, 0.55, 1.15), Vector3(0, 1.2, -0.85), ENEMY_DARK)
	_box(root, Vector3(1.55, 0.35, 1.5), Vector3(0, 0.95, 0.95), Color("6a3a28"))
	_wheels(root, [Vector3(-0.8, 0.38, -1.15), Vector3(0.8, 0.38, -1.15), Vector3(-0.8, 0.38, 1.1), Vector3(0.8, 0.38, 1.1)], 0.38)
	_turret(root, Vector3(0, 1.25, 0.9), 1.15, 0.06, STEEL, 0.0)


func _soldier(root: Node3D, enemy: bool, rpg: bool) -> void:
	var cloth: Color = ENEMY if enemy else OLIVE
	_box(root, Vector3(0.42, 0.7, 0.28), Vector3(0, 0.85, 0), cloth)
	_box(root, Vector3(0.28, 0.28, 0.28), Vector3(0, 1.38, 0), Color("c9a27a"))
	_box(root, Vector3(0.16, 0.45, 0.16), Vector3(-0.18, 0.45, 0), cloth)
	_box(root, Vector3(0.16, 0.45, 0.16), Vector3(0.18, 0.45, 0), cloth)
	if rpg:
		_box(root, Vector3(0.1, 0.1, 1.15), Vector3(0.22, 1.15, -0.35), Color("2a2a28"))
	else:
		_box(root, Vector3(0.08, 0.08, 0.7), Vector3(0.2, 1.05, -0.25), STEEL)
	var muzzle := Marker3D.new()
	muzzle.name = "muzzle"
	muzzle.position = Vector3(0.2, 1.1, -0.7)
	root.add_child(muzzle)


func _heli(root: Node3D) -> void:
	_box(root, Vector3(1.3, 0.7, 2.6), Vector3(0, 0, -0.2), ENEMY)
	_box(root, Vector3(0.9, 0.4, 0.7), Vector3(0, 0.35, -0.7), GLASS)
	_box(root, Vector3(0.28, 0.28, 2.3), Vector3(0, 0.1, 1.8), ENEMY_DARK)
	_box(root, Vector3(1.4, 0.08, 0.18), Vector3(0, 0.15, 2.85), STEEL)
	_box(root, Vector3(0.08, 0.55, 0.08), Vector3(1.25, 0.15, 2.85), STEEL)
	_box(root, Vector3(2.4, 0.08, 0.28), Vector3(0, -0.45, -0.2), STEEL)
	var rotor := Node3D.new()
	rotor.name = "rotor"
	rotor.position = Vector3(0, 0.55, -0.3)
	root.add_child(rotor)
	_box(rotor, Vector3(4.6, 0.05, 0.18), Vector3.ZERO, Color("222420"))
	_box(rotor, Vector3(0.18, 0.05, 4.6), Vector3.ZERO, Color("222420"))
	var muzzle := Marker3D.new()
	muzzle.name = "muzzle"
	muzzle.position = Vector3(0, -0.2, -1.5)
	root.add_child(muzzle)


func _turret(parent: Node3D, pos: Vector3, length: float, radius: float, color: Color, pitch: float) -> Node3D:
	var turret := Node3D.new()
	turret.name = "turret"
	turret.position = pos
	parent.add_child(turret)
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 8
	barrel.mesh = cyl
	barrel.rotation_degrees = Vector3(-90, 0, 0)
	barrel.position = Vector3(0, 0.08, -length * 0.5)
	barrel.material_override = mat(color, 0.55)
	turret.add_child(barrel)
	if absf(pitch) > 0.1:
		barrel.rotation_degrees = Vector3(-90 + pitch, 0, 0)
		barrel.position = Vector3(0, 0.15 + sin(deg_to_rad(-pitch)) * length * 0.25, -length * 0.45)
	var muzzle := Marker3D.new()
	muzzle.name = "muzzle"
	muzzle.position = barrel.position + Vector3(0, sin(deg_to_rad(-pitch)) * length * 0.5, -cos(deg_to_rad(-pitch)) * length * 0.5)
	turret.add_child(muzzle)
	return turret


func _wheels(parent: Node3D, spots: Array, radius: float) -> void:
	for i in spots.size():
		var pivot := Node3D.new()
		pivot.name = "wheel%d" % i
		pivot.position = spots[i]
		parent.add_child(pivot)
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 0.26
		cyl.radial_segments = 8
		mi.mesh = cyl
		mi.rotation_degrees = Vector3(0, 0, 90)
		mi.material_override = mat(RUBBER, 1.0)
		pivot.add_child(mi)
		var hub := MeshInstance3D.new()
		var h := CylinderMesh.new()
		h.top_radius = radius * 0.4
		h.bottom_radius = radius * 0.4
		h.height = 0.28
		h.radial_segments = 6
		hub.mesh = h
		hub.rotation_degrees = Vector3(0, 0, 90)
		hub.material_override = mat(METAL, 0.45)
		pivot.add_child(hub)


func _blob(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "blob"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.5
	cyl.bottom_radius = 1.5
	cyl.height = 0.04
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.position = Vector3(0, 0.05, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var key := "%s" % size
	if not _boxes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_boxes[key] = mesh
	mi.mesh = _boxes[key]
	mi.position = pos
	mi.material_override = mat(color)
	parent.add_child(mi)
	return mi
