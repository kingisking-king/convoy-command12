extends SceneTree

const Checks = preload("res://scripts/sim_checks.gd")

func _init() -> void:
	var ok: bool = Checks.run()
	quit(0 if ok else 1)
