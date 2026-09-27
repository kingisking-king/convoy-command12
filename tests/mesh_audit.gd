extends SceneTree

const Hard = preload("res://scripts/hard_surface.gd")

func _init() -> void:
	_audit_box()
	var lib = load("res://scripts/mesh_lib.gd").new()
	var kinds := ["cargo", "humvee", "apc", "tank", "aa", "repair", "technical", "infantry", "rpg", "heli"]
	var worst := 1.0
	for kind in kinds:
		var enemy: bool = kind == "technical" or kind == "heli" or kind == "infantry"
		var node: Node3D = lib.build(kind, enemy, "woodland")
		var ratio := _ratio(node)
		print("AUDIT ", kind, " outward=", snappedf(ratio, 0.001))
		if ratio < worst:
			worst = ratio
		node.free()
	print("WORST ", snappedf(worst, 0.001))
	quit(0 if worst > 0.72 else 1)


func _audit_box() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Hard.new().add_bevel_box(st, Vector3.ZERO, Vector3(2, 1, 3), 0.15)
	var mesh := st.commit()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var root := Node3D.new()
	root.add_child(node)
	print("AUDIT box outward=", snappedf(_ratio(root), 0.001), " tris=", _tris(root))
	root.free()


func _ratio(root: Node3D) -> float:
	var outward := 0
	var total := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name) == "blob" or str(mi.name) == "beacon":
			continue
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var xf: Transform3D = (mi as Node3D).global_transform
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var centroid := Vector3.ZERO
			if verts.is_empty():
				continue
			for v in verts:
				centroid += xf * v
			centroid /= float(verts.size())
			for i in range(0, verts.size(), 3):
				var a: Vector3 = xf * verts[i]
				var b: Vector3 = xf * verts[i + 1]
				var c: Vector3 = xf * verts[i + 2]
				var geo: Vector3 = (b - a).cross(c - a)
				if geo.length_squared() < 0.0000001:
					continue
				total += 1
				var mid: Vector3 = (a + b + c) / 3.0
				if geo.dot(mid - centroid) > 0.0:
					outward += 1
	if total == 0:
		return 0.0
	return float(outward) / float(total)


func _tris(root: Node3D) -> int:
	var total := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += verts.size() / 3
	return total
