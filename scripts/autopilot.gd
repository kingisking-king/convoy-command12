extends RefCounted

static func consider(sim) -> void:
	if sim.status != "running":
		return
	if (sim.cargo_health_ratio() < 0.8 or sim.column_health_ratio() < 0.58) and sim.try_ability("repair"):
		return
	var near: int = sim.hostiles_within(40.0)
	var heavy: int = sim.heavy_threats_within(75.0)
	if sim.smoke_timer <= 0.0 and near >= 3 and sim.try_ability("smoke"):
		return
	if heavy >= 1 and near >= 1 and sim.try_ability("airstrike"):
		return
	if near >= 5 and sim.try_ability("airstrike"):
		return
