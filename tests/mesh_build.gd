extends SceneTree

func _init() -> void:
	var lib = load("res://scripts/mesh_lib.gd").new()
	var kinds := ["cargo", "humvee", "apc", "tank", "aa", "repair", "technical", "infantry", "rpg", "heli"]
	for kind in kinds:
		var enemy: bool = kind == "technical" or kind == "heli"
		var node: Node3D = lib.build(kind, enemy, "desert")
		var meshes := node.find_children("*", "MeshInstance3D", true, false).size()
		print("BUILT ", kind, " meshes=", meshes, " wheels=", node.find_children("wheel*", "Node3D", true, false).size())
	quit(0)
