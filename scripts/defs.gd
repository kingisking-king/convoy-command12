extends RefCounted

const SPACING := 7.6
const LANES := 5
const ROWS := 8
const LANE_GAP := 3.35
const CENTER := 2
const MAX_UNITS := 8
const MAX_SLOTS := MAX_UNITS
const YAW_STEP := 45

const ARMOR_COST := [0, 35, 80]
const WEAPON_COST := [0, 40, 95]
const SPEED_COST := [0, 25, 55]
const ARMOR_HP := [1.0, 1.22, 1.48]
const WEAPON_DMG := [1.0, 1.18, 1.4]
const SPEED_MUL := [1.0, 1.1, 1.22]

const CAMO_ORDER := ["woodland", "desert", "olive", "winter", "urban"]
const CAMOS := {
	"woodland": {"name": "Woodland", "a": Color("4e5c2e"), "b": Color("2a381c"), "c": Color("8d7846")},
	"desert": {"name": "Desert", "a": Color("c2a56c"), "b": Color("8d6a40"), "c": Color("6e7a46")},
	"olive": {"name": "Olive", "a": Color("556238"), "b": Color("3a4526"), "c": Color("747e4a")},
	"winter": {"name": "Winter", "a": Color("d4d8dc"), "b": Color("8d98a2"), "c": Color("5c6b64")},
	"urban": {"name": "Urban", "a": Color("6c706c"), "b": Color("3a3e3c"), "c": Color("8c8676")},
}

const UNITS := {
	"cargo": {
		"name": "Cargo Truck",
		"cost": 50,
		"hp": 180,
		"dmg": 0,
		"rng": 0,
		"spd": 11.0,
		"rof": 0.0,
		"role": "cargo",
		"heal": 0.0,
		"blurb": "The payload. If every truck dies, the contract fails.",
	},
	"humvee": {
		"name": "Humvee",
		"cost": 75,
		"hp": 105,
		"dmg": 9,
		"rng": 32.0,
		"spd": 14.0,
		"rof": 3.6,
		"role": "light",
		"heal": 0.0,
		"blurb": "Fast mounted gun. Chews up infantry and technicals.",
	},
	"apc": {
		"name": "APC",
		"cost": 130,
		"hp": 200,
		"dmg": 16,
		"rng": 36.0,
		"spd": 12.0,
		"rof": 1.8,
		"role": "medium",
		"heal": 0.0,
		"blurb": "Balanced armor and an autocannon.",
	},
	"tank": {
		"name": "Tank",
		"cost": 210,
		"hp": 360,
		"dmg": 46,
		"rng": 44.0,
		"spd": 9.0,
		"rof": 0.6,
		"role": "heavy",
		"heal": 0.0,
		"blurb": "Heavy cannon. Poor against aircraft.",
	},
	"aa": {
		"name": "Anti-Air",
		"cost": 145,
		"hp": 125,
		"dmg": 10,
		"rng": 56.0,
		"spd": 12.0,
		"rof": 6.0,
		"role": "aa",
		"heal": 0.0,
		"blurb": "Rapid guns. Built to knock down helicopters.",
	},
	"repair": {
		"name": "Repair Truck",
		"cost": 85,
		"hp": 120,
		"dmg": 0,
		"rng": 18.0,
		"spd": 11.0,
		"rof": 0.0,
		"role": "repair",
		"heal": 12.0,
		"blurb": "Patches the most damaged neighbor. Cargo first.",
	},
}

const ENEMIES := {
	"infantry": {"name": "Infantry", "hp": 52, "dmg": 7, "rng": 23.0, "spd": 6.6, "rof": 1.25, "air": false, "alt": 0.0},
	"technical": {"name": "Technical", "hp": 110, "dmg": 12, "rng": 30.0, "spd": 15.5, "rof": 2.7, "air": false, "alt": 0.0},
	"rpg": {"name": "RPG Team", "hp": 52, "dmg": 48, "rng": 33.0, "spd": 5.5, "rof": 0.3, "air": false, "alt": 0.0},
	"tank": {"name": "Enemy Tank", "hp": 320, "dmg": 40, "rng": 40.0, "spd": 7.2, "rof": 0.4, "air": false, "alt": 0.0},
	"heli": {"name": "Helicopter", "hp": 120, "dmg": 13, "rng": 44.0, "spd": 20.0, "rof": 4.0, "air": true, "alt": 15.0},
}

const CARD_ORDER := ["cargo", "humvee", "apc", "tank", "aa", "repair"]

static func levels() -> Array:
	return [
		{
			"name": "Dust Road",
			"subtitle": "Qasr Corridor",
			"biome": "desert",
			"seed": 1107,
			"length": 520.0,
			"base_pay": 400,
			"brief": "Two supply trucks have to cross open desert. Infantry and gun-trucks are waiting in the rocks. Put armor beside the cargo, not a mile ahead of it.",
			"charges": {"smoke": 2, "airstrike": 1, "repair": 2},
			"ambushes": [
				{"at": 90.0, "banner": "Contact — infantry in the rocks", "units": [
					{"k": "infantry", "side": -1, "lat": 20.0, "ahead": 6.0},
					{"k": "infantry", "side": -1, "lat": 24.0, "ahead": 14.0},
					{"k": "infantry", "side": -1, "lat": 18.0, "ahead": 22.0},
					{"k": "infantry", "side": 1, "lat": 22.0, "ahead": 12.0},
					{"k": "infantry", "side": 1, "lat": 27.0, "ahead": 20.0},
				]},
				{"at": 240.0, "banner": "Technicals coming in on the flank", "units": [
					{"k": "technical", "side": 1, "lat": 26.0, "ahead": 16.0},
					{"k": "technical", "side": 1, "lat": 32.0, "ahead": 30.0},
					{"k": "infantry", "side": -1, "lat": 18.0, "ahead": 8.0},
					{"k": "infantry", "side": -1, "lat": 22.0, "ahead": 18.0},
				]},
				{"at": 400.0, "banner": "Ambush at the bend — RPG on the ridge", "units": [
					{"k": "rpg", "side": -1, "lat": 30.0, "ahead": 18.0},
					{"k": "technical", "side": -1, "lat": 24.0, "ahead": 8.0},
					{"k": "infantry", "side": 1, "lat": 18.0, "ahead": 4.0},
					{"k": "infantry", "side": 1, "lat": 22.0, "ahead": 14.0},
					{"k": "infantry", "side": 1, "lat": 26.0, "ahead": 24.0},
				]},
			],
		},
		{
			"name": "Pine Cut",
			"subtitle": "Blackpine Road",
			"biome": "forest",
			"seed": 2209,
			"length": 620.0,
			"base_pay": 480,
			"brief": "The timber road is short on sightlines. RPG teams and a tank will try to stop the column between the trees. Keep a cannon with the cargo.",
			"charges": {"smoke": 2, "airstrike": 2, "repair": 2},
			"ambushes": [
				{"at": 80.0, "banner": "Infantry in the tree line", "units": [
					{"k": "infantry", "side": -1, "lat": 16.0, "ahead": 4.0},
					{"k": "infantry", "side": -1, "lat": 20.0, "ahead": 12.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 8.0},
					{"k": "infantry", "side": 1, "lat": 22.0, "ahead": 18.0},
					{"k": "technical", "side": 1, "lat": 28.0, "ahead": 26.0},
				]},
				{"at": 210.0, "banner": "RPG teams on both shoulders", "units": [
					{"k": "rpg", "side": -1, "lat": 26.0, "ahead": 10.0},
					{"k": "rpg", "side": 1, "lat": 28.0, "ahead": 22.0},
					{"k": "infantry", "side": -1, "lat": 16.0, "ahead": 0.0},
					{"k": "infantry", "side": 1, "lat": 18.0, "ahead": 8.0},
					{"k": "infantry", "side": -1, "lat": 20.0, "ahead": 18.0},
				]},
				{"at": 360.0, "banner": "Armor on the road — enemy tank", "units": [
					{"k": "tank", "side": -1, "lat": 22.0, "ahead": 20.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 6.0},
					{"k": "infantry", "side": 1, "lat": 20.0, "ahead": 16.0},
					{"k": "technical", "side": 1, "lat": 30.0, "ahead": 28.0},
				]},
				{"at": 500.0, "banner": "They are hitting the column again", "units": [
					{"k": "technical", "side": -1, "lat": 24.0, "ahead": 10.0},
					{"k": "technical", "side": 1, "lat": 26.0, "ahead": 24.0},
					{"k": "rpg", "side": -1, "lat": 32.0, "ahead": 18.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 4.0},
					{"k": "infantry", "side": -1, "lat": 18.0, "ahead": 28.0},
				]},
			],
		},
		{
			"name": "High Pass",
			"subtitle": "Khar Pass",
			"biome": "mountain",
			"seed": 3311,
			"length": 700.0,
			"base_pay": 560,
			"brief": "The pass is narrow, and rotary scouts own the sky. Bring anti-air. Smoke and the airstrike are how you live through the last bend.",
			"charges": {"smoke": 3, "airstrike": 2, "repair": 3},
			"ambushes": [
				{"at": 70.0, "banner": "Technicals blocking the climb", "units": [
					{"k": "technical", "side": -1, "lat": 22.0, "ahead": 12.0},
					{"k": "technical", "side": 1, "lat": 24.0, "ahead": 26.0},
					{"k": "infantry", "side": -1, "lat": 16.0, "ahead": 4.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 14.0},
					{"k": "infantry", "side": 1, "lat": 20.0, "ahead": 22.0},
				]},
				{"at": 190.0, "banner": "Helicopter overhead", "units": [
					{"k": "heli", "side": 1, "lat": 18.0, "ahead": 20.0},
					{"k": "infantry", "side": -1, "lat": 16.0, "ahead": 6.0},
					{"k": "infantry", "side": -1, "lat": 20.0, "ahead": 16.0},
					{"k": "rpg", "side": 1, "lat": 28.0, "ahead": 10.0},
				]},
				{"at": 330.0, "banner": "Tank in the cut", "units": [
					{"k": "tank", "side": -1, "lat": 20.0, "ahead": 18.0},
					{"k": "rpg", "side": 1, "lat": 26.0, "ahead": 8.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 0.0},
					{"k": "infantry", "side": -1, "lat": 16.0, "ahead": 10.0},
					{"k": "technical", "side": 1, "lat": 30.0, "ahead": 28.0},
				]},
				{"at": 470.0, "banner": "Two helicopters on the column", "units": [
					{"k": "heli", "side": -1, "lat": 16.0, "ahead": 14.0},
					{"k": "heli", "side": 1, "lat": 20.0, "ahead": 32.0},
					{"k": "technical", "side": -1, "lat": 24.0, "ahead": 6.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 4.0},
					{"k": "infantry", "side": 1, "lat": 18.0, "ahead": 12.0},
				]},
				{"at": 590.0, "banner": "Last bend — everything they have left", "units": [
					{"k": "tank", "side": 1, "lat": 18.0, "ahead": 16.0},
					{"k": "heli", "side": -1, "lat": 14.0, "ahead": 28.0},
					{"k": "rpg", "side": -1, "lat": 26.0, "ahead": 8.0},
					{"k": "technical", "side": 1, "lat": 28.0, "ahead": 6.0},
					{"k": "infantry", "side": -1, "lat": 16.0, "ahead": 0.0},
					{"k": "infantry", "side": 1, "lat": 16.0, "ahead": 20.0},
				]},
			],
		},
	]


static func cost(kind: String) -> int:
	return int(UNITS[kind]["cost"])


static func entry_kind(entry) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str(entry.get("kind", ""))
	return str(entry)


static func entry_cost(entry) -> int:
	var kind := entry_kind(entry)
	if kind == "" or not UNITS.has(kind):
		return 0
	var total := int(UNITS[kind]["cost"])
	if typeof(entry) == TYPE_DICTIONARY:
		total += ARMOR_COST[clampi(int(entry.get("armor", 0)), 0, 2)]
		total += WEAPON_COST[clampi(int(entry.get("weapon", 0)), 0, 2)]
		total += SPEED_COST[clampi(int(entry.get("speed", 0)), 0, 2)]
	return total


static func roster_cost(roster: Array) -> int:
	var total := 0
	for entry in roster:
		total += entry_cost(entry)
	return total


static func roster_kinds(roster: Array) -> Array:
	var out: Array = []
	for entry in roster:
		var kind := entry_kind(entry)
		if kind != "":
			out.append(kind)
	return out


static func count_kind(roster: Array, kind: String) -> int:
	var n := 0
	for entry in roster:
		if entry_kind(entry) == kind:
			n += 1
	return n


static func lateral(lane: int) -> float:
	return float(lane - CENTER) * LANE_GAP


static func along(row: int) -> float:
	return -float(row) * SPACING


static func make_unit(kind: String, lane: int, row: int, yaw: int = 0, armor: int = 0, weapon: int = 0, speed: int = 0) -> Dictionary:
	return {
		"kind": kind,
		"lane": clampi(lane, 0, LANES - 1),
		"row": clampi(row, 0, ROWS - 1),
		"yaw": posmod(yaw, 360),
		"armor": clampi(armor, 0, 2),
		"weapon": clampi(weapon, 0, 2),
		"speed": clampi(speed, 0, 2),
	}


static func index_at(units: Array, lane: int, row: int) -> int:
	for i in units.size():
		if int(units[i]["lane"]) == lane and int(units[i]["row"]) == row:
			return i
	return -1


static func cargo_is_leading(units: Array) -> bool:
	var cargo_row := 99
	var gun_row := 99
	var guns := 0
	for entry in units:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kind := entry_kind(entry)
		if kind == "" or not UNITS.has(kind):
			continue
		var row := int(entry["row"])
		if kind == "cargo":
			cargo_row = mini(cargo_row, row)
		elif float(UNITS[kind]["dmg"]) > 0.0:
			guns += 1
			gun_row = mini(gun_row, row)
	if guns == 0:
		return false
	return cargo_row < gun_row


static func scaled(kind: String, armor: int, weapon: int, speed: int) -> Dictionary:
	var spec: Dictionary = UNITS[kind]
	var hp: float = float(spec["hp"]) * ARMOR_HP[clampi(armor, 0, 2)]
	var dmg: float = float(spec["dmg"])
	if dmg > 0.0:
		dmg *= WEAPON_DMG[clampi(weapon, 0, 2)]
	var spd: float = float(spec["spd"]) * SPEED_MUL[clampi(speed, 0, 2)]
	return {"hp": hp, "dmg": dmg, "spd": spd}


static func arrange(kinds: Array, style: String = "wedge") -> Array:
	var clean: Array = []
	for kind in kinds:
		var k := str(kind)
		if UNITS.has(k):
			clean.append(k)
	if style == "line":
		var line: Array = []
		for i in clean.size():
			line.append(make_unit(clean[i], CENTER, i))
		return line
	var guns: Array = []
	var cargos: Array = []
	var repairs: Array = []
	for k in clean:
		var role := str(UNITS[k]["role"])
		if role == "cargo":
			cargos.append(k)
		elif role == "repair":
			repairs.append(k)
		else:
			guns.append(k)
	var taken := {}
	var out: Array = []
	var gun_spots: Array = [
		Vector2i(2, 0), Vector2i(1, 2), Vector2i(3, 4),
		Vector2i(3, 2), Vector2i(1, 4), Vector2i(0, 3), Vector2i(4, 3), Vector2i(2, 1),
	]
	var cargo_spots: Array = [Vector2i(2, 2), Vector2i(2, 4), Vector2i(2, 6), Vector2i(1, 6)]
	var repair_spots: Array = [Vector2i(2, 3), Vector2i(2, 5), Vector2i(1, 3), Vector2i(3, 5)]
	if style == "box":
		gun_spots = [
			Vector2i(1, 1), Vector2i(3, 1), Vector2i(0, 2), Vector2i(4, 2),
			Vector2i(1, 3), Vector2i(3, 3), Vector2i(2, 0), Vector2i(2, 4),
		]
		cargo_spots = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(1, 2), Vector2i(3, 2)]
		repair_spots = [Vector2i(2, 4), Vector2i(2, 5), Vector2i(1, 4), Vector2i(3, 4)]
	for i in guns.size():
		var spot: Vector2i = gun_spots[mini(i, gun_spots.size() - 1)]
		spot = _free_spot(taken, spot)
		taken["%d,%d" % [spot.x, spot.y]] = true
		out.append(make_unit(str(guns[i]), spot.x, spot.y))
	for i in cargos.size():
		var cspot: Vector2i = cargo_spots[mini(i, cargo_spots.size() - 1)]
		cspot = _free_spot(taken, cspot)
		taken["%d,%d" % [cspot.x, cspot.y]] = true
		out.append(make_unit(str(cargos[i]), cspot.x, cspot.y))
	for i in repairs.size():
		var rspot: Vector2i = repair_spots[mini(i, repair_spots.size() - 1)]
		rspot = _free_spot(taken, rspot)
		taken["%d,%d" % [rspot.x, rspot.y]] = true
		out.append(make_unit(str(repairs[i]), rspot.x, rspot.y))
	return out


static func _free_spot(taken: Dictionary, spot: Vector2i) -> Vector2i:
	if not taken.has("%d,%d" % [spot.x, spot.y]):
		return spot
	for row in ROWS:
		for lane in LANES:
			var key := "%d,%d" % [lane, row]
			if not taken.has(key):
				return Vector2i(lane, row)
	return spot


static func camo_for_biome(biome: String) -> String:
	if biome == "desert":
		return "desert"
	if biome == "mountain":
		return "olive"
	return "woodland"


static func _recommended_kinds(level_index: int, bank: int) -> Array:
	var basic := [
		["humvee", "apc", "cargo", "repair", "cargo", "humvee"],
		["tank", "apc", "cargo", "repair", "cargo", "aa", "humvee"],
		["tank", "apc", "aa", "cargo", "repair", "cargo", "aa", "humvee"],
	]
	var rich := [
		["apc", "humvee", "cargo", "repair", "cargo", "apc", "humvee"],
		["tank", "apc", "aa", "cargo", "repair", "cargo", "humvee", "humvee"],
		["tank", "aa", "apc", "cargo", "repair", "cargo", "tank", "aa"],
	]
	var pick: Array = rich[level_index].duplicate()
	if roster_cost(pick) > bank:
		pick = basic[level_index].duplicate()
	while roster_cost(pick) > bank and pick.size() > 2:
		var removed := false
		for i in range(pick.size() - 1, -1, -1):
			var guns := 0
			for k in pick:
				if float(UNITS[k]["dmg"]) > 0.0:
					guns += 1
			if pick[i] == "cargo":
				continue
			if float(UNITS[pick[i]]["dmg"]) > 0.0 and guns <= 1:
				continue
			pick.remove_at(i)
			removed = true
			break
		if not removed:
			break
	return pick


static func recommended(level_index: int, bank: int) -> Array:
	return arrange(_recommended_kinds(level_index, bank), "wedge")


static func payout(level: Dictionary, delivered: int, kills: int, column_cost: int) -> Dictionary:
	var salvage := int(round(float(column_cost) * 0.55))
	var base := int(level["base_pay"])
	var cargo_bonus := 120 * delivered
	var kill_bonus := 10 * kills
	var net := -column_cost + salvage + base + cargo_bonus + kill_bonus
	return {
		"cost": column_cost,
		"salvage": salvage,
		"base": base,
		"cargo": cargo_bonus,
		"kills": kill_bonus,
		"net": net,
	}


static func grade(won: bool, delivered: int, cargo_total: int, escorts_lost: int) -> String:
	if not won:
		return "FAIL"
	if delivered == cargo_total and escorts_lost == 0:
		return "S"
	if delivered == cargo_total:
		return "A"
	return "B"


static func air_multiplier(role: String, target_air: bool) -> float:
	if not target_air:
		if role == "aa":
			return 0.42
		return 1.0
	if role == "aa":
		return 1.45
	if role == "heavy":
		return 0.1
	if role == "medium":
		return 0.42
	if role == "light":
		return 0.5
	return 0.0
