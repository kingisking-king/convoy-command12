extends RefCounted

const Defs = preload("res://scripts/defs.gd")
const RouteScript = preload("res://scripts/route.gd")
const SimScript = preload("res://scripts/battle_sim.gd")
const Autopilot = preload("res://scripts/autopilot.gd")

static func run() -> bool:
	var ok := true
	var levels := Defs.levels()
	for i in levels.size():
		var route = RouteScript.new(levels[i])
		print("Level %d route length %.1f  ambushes %d" % [i + 1, route.total, levels[i]["ambushes"].size()])
		for amb in levels[i]["ambushes"]:
			if float(amb["at"]) >= route.total:
				print("FAIL ambush beyond route on level %d" % (i + 1))
				ok = false

	print("--- campaign, quick column, no abilities ---")
	var bank := 500
	for i in levels.size():
		var roster: Array = Defs.recommended(i, bank)
		var result: Dictionary = _play(levels[i], roster, int(levels[i]["seed"]) + 100, false)
		var pay: Dictionary = Defs.payout(levels[i], int(result["delivered"]), int(result["kills"]), Defs.roster_cost(roster))
		print("L%d %-12s roster=%s cost=%d %s delivered=%d/%d kills=%d cargo_hp=%.0f escorts_lost=%d t=%.1f bank %d -> %d" % [
			i + 1, levels[i]["name"], str(roster), Defs.roster_cost(roster), result["status"],
			result["delivered"], result["cargo_total"], result["kills"], result["cargo_hp"],
			result["escorts_lost"], result["time"], bank, bank + int(pay["net"]),
		])
		if result["status"] != "won":
			ok = false
		if int(result["ambushes"]) != levels[i]["ambushes"].size():
			print("FAIL not all ambushes spawned (%d)" % int(result["ambushes"]))
			ok = false
		bank += int(pay["net"])

	print("--- campaign, quick column, autopilot abilities ---")
	bank = 500
	for i in levels.size():
		var roster2: Array = Defs.recommended(i, bank)
		var result2: Dictionary = _play(levels[i], roster2, int(levels[i]["seed"]) + 100, true)
		var pay2: Dictionary = Defs.payout(levels[i], int(result2["delivered"]), int(result2["kills"]), Defs.roster_cost(roster2))
		print("L%d %s delivered=%d/%d kills=%d cargo_hp=%.0f grade=%s" % [
			i + 1, result2["status"], result2["delivered"], result2["cargo_total"],
			result2["kills"], result2["cargo_hp"],
			Defs.grade(result2["status"] == "won", int(result2["delivered"]), int(result2["cargo_total"]), int(result2["escorts_lost"])),
		])
		if result2["status"] != "won":
			ok = false
		for extra in [1, 2]:
			var alt: Dictionary = _play(levels[i], roster2, int(levels[i]["seed"]) + 100 + extra * 17, true)
			print("  seed+%d %s cargo_hp=%.0f delivered=%d" % [extra * 17, alt["status"], alt["cargo_hp"], alt["delivered"]])
			if alt["status"] != "won":
				ok = false
		bank += int(pay2["net"])

	print("--- cargo only should lose ---")
	for i in levels.size():
		var lonely: Dictionary = _play(levels[i], ["cargo", "cargo"], int(levels[i]["seed"]) + 100, true)
		print("L%d cargo-only %s delivered=%d" % [i + 1, lonely["status"], lonely["delivered"]])
		if lonely["status"] != "lost":
			ok = false

	print("SIM CHECKS %s" % ("OK" if ok else "FAILED"))
	return ok


static func _play(level: Dictionary, roster: Array, combat_seed: int, use_abilities: bool) -> Dictionary:
	var route = RouteScript.new(level)
	var sim = SimScript.new()
	sim.start(level, roster, route, combat_seed)
	var guard := 0
	while sim.status == "running" and guard < 9000:
		if use_abilities:
			Autopilot.consider(sim)
		sim.tick(1.0 / 30.0)
		sim.events.clear()
		guard += 1
	var cargo_hp := 0.0
	for u in sim.friendlies:
		if u["role"] == "cargo" and (u["alive"] or u["delivered"]):
			cargo_hp += float(u["hp"])
	var spawned := 0
	for flag in sim.ambush_spawned:
		if flag:
			spawned += 1
	return {
		"status": sim.status,
		"delivered": sim.delivered,
		"cargo_total": sim.cargo_total,
		"kills": sim.kills,
		"escorts_lost": sim.escorts_lost,
		"time": sim.time,
		"cargo_hp": cargo_hp,
		"ambushes": spawned,
	}
