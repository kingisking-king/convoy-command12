extends CanvasLayer

const Defs = preload("res://scripts/defs.gd")
const RouteMap = preload("res://scripts/route_map.gd")

signal play_pressed
signal restart_pressed
signal help_pressed
signal quit_pressed
signal back_pressed
signal arm_pressed
signal deploy_pressed
signal quick_pressed
signal unit_selected(kind: String)
signal ability_pressed(ability: String)
signal next_pressed
signal retry_pressed
signal menu_pressed
signal resume_pressed
signal rotate_pressed
signal remove_pressed
signal arrange_pressed(style: String)
signal upgrade_pressed(stat: String, level: int)
signal camo_pressed(camo_name: String)
signal name_changed(convoy_name: String)
signal preset_save(preset_name: String)
signal preset_load(preset_name: String)
signal preset_delete(preset_name: String)
signal sandbox_pressed
signal missions_pressed
signal mission_picked(index: int)
signal sandbox_arm_pressed
signal sandbox_god_toggled(on: bool)
signal sandbox_speed_changed(speed: float)
signal sandbox_threat_changed(scale: float)
signal sandbox_restart_pressed

var audio = null
var root: Control
var menu_box: PanelContainer
var help_box: PanelContainer
var brief_box: PanelContainer
var build_top: PanelContainer
var build_bottom: PanelContainer
var build_dock: PanelContainer
var drive_top: PanelContainer
var drive_bottom: PanelContainer
var pause_box: PanelContainer
var result_box: PanelContainer
var banner: Label
var toast_label: Label
var banner_t := 0.0
var toast_t := 0.0
var map: Control
var cards := {}
var selected_kind := "humvee"

var menu_title: Label
var menu_sub: Label
var menu_buttons: VBoxContainer
var help_body: Label
var brief_title: Label
var brief_sub: Label
var brief_body: Label
var brief_meta: Label
var build_title: Label
var build_budget: Label
var build_column: Label
var build_warn: Label
var deploy_button: Button
var name_edit: LineEdit
var preset_edit: LineEdit
var preset_pick: OptionButton
var upgrade_label: Label
var camo_buttons := {}
var drive_title: Label
var drive_progress: ProgressBar
var drive_cargo: Label
var drive_hp: Label
var drive_hostiles: Label
var drive_hint: Label
var smoke_button: Button
var strike_button: Button
var repair_button: Button
var result_title: Label
var result_grade: Label
var result_body: Label
var result_next: Button
var result_retry: Button
var pause_retry: Button
var sandbox_box: PanelContainer
var sandbox_drive: PanelContainer
var sandbox_map_buttons: Array = []
var sandbox_map_index := 0
var sandbox_spins := {}
var sandbox_god: CheckBox
var sandbox_diff: HSlider
var sandbox_speed: HSlider
var sandbox_diff_label: Label
var sandbox_speed_label: Label
var drive_god: CheckBox
var drive_diff: HSlider
var drive_speed: HSlider
var drive_diff_label: Label
var drive_speed_label: Label
var spawn_pick: OptionButton
var mission_box: PanelContainer
var mission_list: VBoxContainer
var sandbox_sync := false

func setup(p_audio) -> void:
	audio = p_audio
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	_build_menu()
	_build_sandbox()
	_build_missions()
	_build_help()
	_build_brief()
	_build_build()
	_build_drive()
	_build_pause()
	_build_results()
	banner = Label.new()
	banner.visible = false
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_color_override("font_color", Color("f2d48a"))
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 78
	banner.offset_bottom = 120
	banner.offset_left = -420
	banner.offset_right = 420
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	toast_label = Label.new()
	toast_label.visible = false
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_top = -150
	toast_label.offset_bottom = -118
	toast_label.offset_left = -320
	toast_label.offset_right = 320
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	map = RouteMap.new()
	map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map.offset_left = -228
	map.offset_right = -16
	map.offset_top = 16
	map.offset_bottom = 166
	map.visible = false
	root.add_child(map)
	hide_all()


func _process(dt: float) -> void:
	if banner_t > 0.0:
		banner_t -= dt
		banner.modulate.a = 1.0 if banner_t > 1.0 else maxf(banner_t, 0.0)
		if banner_t <= 0.0:
			banner.visible = false
	if toast_t > 0.0:
		toast_t -= dt
		toast_label.modulate.a = 1.0 if toast_t > 0.6 else maxf(toast_t / 0.6, 0.0)
		if toast_t <= 0.0:
			toast_label.visible = false


func hovering_ui() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	return c != null and c.mouse_filter != Control.MOUSE_FILTER_IGNORE


func typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit


func hide_all() -> void:
	for panel in [menu_box, sandbox_box, sandbox_drive, help_box, brief_box, build_top, build_dock, build_bottom, drive_top, drive_bottom, pause_box, result_box, mission_box]:
		panel.visible = false
	map.visible = false


func show_menu(bank: int, level_index: int, level_count: int, campaign_done: bool) -> void:
	hide_all()
	menu_box.visible = true
	for c in menu_buttons.get_children():
		c.queue_free()
	var progressed: bool = level_index > 0 and not campaign_done
	if campaign_done:
		menu_sub.text = "Contract cleared. War chest $%d." % bank
		_menu_button("New Campaign", restart_pressed)
	elif progressed:
		menu_sub.text = "War chest $%d  ·  Mission %d of %d" % [bank, level_index + 1, level_count]
		_menu_button("Continue", play_pressed)
		_menu_button("Restart Campaign", restart_pressed)
	else:
		menu_sub.text = "Build the column. Drive the route. Deliver the cargo."
		_menu_button("Campaign", play_pressed)
	_menu_button("Missions", missions_pressed)
	_menu_button("Sandbox", sandbox_pressed)
	_menu_button("How to Play", help_pressed)
	_menu_button("Quit", quit_pressed)


func _build_missions() -> void:
	mission_box = PanelContainer.new()
	mission_box.set_anchors_preset(Control.PRESET_CENTER)
	mission_box.offset_left = -360
	mission_box.offset_right = 360
	mission_box.offset_top = -280
	mission_box.offset_bottom = 280
	mission_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.94), Color(0.55, 0.48, 0.28), 10))
	root.add_child(mission_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	mission_box.add_child(box)
	var title := Label.new()
	title.text = "MISSIONS"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	mission_list = VBoxContainer.new()
	mission_list.add_theme_constant_override("separation", 6)
	box.add_child(mission_list)
	box.add_child(_button("Back", back_pressed))
	mission_box.visible = false


func show_missions(progress: int, cleared: bool) -> void:
	hide_all()
	mission_box.visible = true
	for c in mission_list.get_children():
		c.queue_free()
	var levels := Defs.levels()
	for i in levels.size():
		var btn := Button.new()
		var open := cleared or i <= progress
		btn.text = "%d  %s  —  %s" % [i + 1, levels[i]["name"], "open" if open else "locked"]
		btn.disabled = not open
		btn.pressed.connect(mission_picked.emit.bind(i))
		mission_list.add_child(btn)


func show_help() -> void:
	hide_all()
	help_box.visible = true


func show_brief(level: Dictionary, index: int, level_count: int, bank: int) -> void:
	hide_all()
	brief_box.visible = true
	brief_title.text = str(level["name"]).to_upper()
	brief_sub.text = "Mission %d of %d  ·  %s" % [index + 1, level_count, level["subtitle"]]
	brief_body.text = str(level["brief"])
	var charges: Dictionary = level["charges"]
	brief_meta.text = "War chest $%d\nSupport: smoke x%d, airstrike x%d, repair x%d\nWin: at least one cargo truck reaches the drop." % [
		bank, int(charges["smoke"]), int(charges["airstrike"]), int(charges["repair"]),
	]


func show_build(level: Dictionary, bank: int, units: Array, kind: String, p_route, state: Dictionary = {}) -> void:
	hide_all()
	build_top.visible = true
	build_dock.visible = true
	build_bottom.visible = true
	map.visible = true
	selected_kind = kind
	var convoy := str(state.get("name", "Column"))
	build_title.text = "%s  ·  %s" % [str(level["name"]).to_upper(), convoy.to_upper()]
	var cost := Defs.roster_cost(units)
	var cargo := Defs.count_kind(units, "cargo")
	var unlimited := bool(state.get("unlimited", false))
	if unlimited:
		build_budget.text = "Budget  unlimited"
		build_column.text = "Formation  $%d    vehicles  %d    cargo  %d" % [cost, units.size(), cargo]
	else:
		build_budget.text = "Budget  $%d" % bank
		build_column.text = "Formation  $%d    left  $%d    vehicles  %d    cargo  %d" % [cost, bank - cost, units.size(), cargo]
	var warn := ""
	if cargo == 0:
		warn = "Place at least one cargo truck."
	elif not unlimited and cost > bank:
		warn = "That formation costs more than the budget."
	elif Defs.cargo_is_leading(units):
		warn = "Cargo is ahead of the guns. It will take the first hits."
	build_warn.text = warn
	deploy_button.disabled = cargo == 0 or (not unlimited and cost > bank)
	for key in cards:
		var btn: Button = cards[key]
		if key == kind:
			btn.add_theme_stylebox_override("normal", _style(Color("3a3420"), Color("e2b84a"), 6))
		else:
			btn.add_theme_stylebox_override("normal", _style(Color("1c2118"), Color("3c4030"), 6))
	_sync_dock(state, units)
	if p_route:
		var blips: Array = []
		for entry in units:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var sm: Dictionary = p_route.sample(Defs.along(int(entry.get("row", 0))))
			var pos: Vector3 = sm["pos"] + sm["right"] * Defs.lateral(int(entry.get("lane", Defs.CENTER)))
			var ekind := str(entry.get("kind", ""))
			var col := Color("e2b84a") if ekind == "cargo" else Color("9dc56a")
			blips.append({"x": pos.x, "z": pos.z, "color": col, "r": 4.0 if ekind == "cargo" else 3.0})
		map.set_state(p_route, blips, 0.0)


func show_drive(sandbox_mode: bool = false) -> void:
	hide_all()
	drive_top.visible = true
	drive_bottom.visible = true
	map.visible = true
	sandbox_drive.visible = sandbox_mode
	if sandbox_mode:
		sandbox_sync = true
		drive_god.button_pressed = sandbox_god.button_pressed
		drive_diff.value = sandbox_diff.value
		drive_speed.value = sandbox_speed.value
		sandbox_sync = false
		_refresh_sandbox_readout()


func refresh_drive(sim, p_route) -> void:
	if sim == null:
		return
	drive_title.text = "%s    %d%%" % [str(sim.level["name"]).to_upper(), int(sim.progress() * 100.0)]
	drive_progress.value = sim.progress() * 100.0
	var cargo_bits: Array = []
	var hp := 0.0
	var mx := 0.0
	for u in sim.friendlies:
		mx += float(u["max_hp"]) if u["alive"] or u["delivered"] else 0.0
		if u["alive"] or u["delivered"]:
			hp += float(u["hp"])
		if u["role"] != "cargo":
			continue
		if u["delivered"]:
			cargo_bits.append("OK")
		elif not u["alive"]:
			cargo_bits.append("LOST")
		else:
			cargo_bits.append("%d%%" % int(100.0 * float(u["hp"]) / float(u["max_hp"])))
	var cargo_text := "Cargo  "
	for i in cargo_bits.size():
		if i > 0:
			cargo_text += "   "
		cargo_text += str(cargo_bits[i])
	drive_cargo.text = cargo_text
	drive_hp.text = "Column  %d%%" % int(100.0 * hp / maxf(mx, 1.0))
	drive_hostiles.text = "Hostiles  %d" % sim.living_hostiles()
	if bool(sim.sandbox):
		var god_note := "    God mode" if bool(sim.god_mode) else ""
		drive_hint.text = "Left click the ground to spawn" + god_note
	elif sim.smoke_timer > 0.0:
		drive_hint.text = "Smoke is up"
	else:
		drive_hint.text = "Q smoke    E airstrike    R repair"
	smoke_button.text = "SMOKE  x%d" % int(sim.charges["smoke"])
	strike_button.text = "AIRSTRIKE  x%d" % int(sim.charges["airstrike"])
	repair_button.text = "REPAIR  x%d" % int(sim.charges["repair"])
	smoke_button.disabled = int(sim.charges["smoke"]) <= 0
	strike_button.disabled = int(sim.charges["airstrike"]) <= 0
	repair_button.disabled = int(sim.charges["repair"]) <= 0
	var blips: Array = []
	for u in sim.friendlies:
		if not u["alive"] and not u["delivered"]:
			continue
		var col := Color("e2b84a") if u["role"] == "cargo" else Color("9dc56a")
		if not u["alive"]:
			col = Color("5a4038")
		blips.append({"x": u["pos"].x, "z": u["pos"].z, "color": col, "r": 3.5 if u["role"] == "cargo" else 2.6})
	for e in sim.enemies:
		if not e["alive"]:
			continue
		blips.append({"x": e["pos"].x, "z": e["pos"].z, "color": Color("e15b4c"), "r": 3.0 if e["air"] else 2.4})
	map.set_state(p_route, blips, sim.lead_s)


func show_pause() -> void:
	pause_box.visible = true


func hide_pause() -> void:
	pause_box.visible = false


func show_results(payload: Dictionary) -> void:
	hide_all()
	result_box.visible = true
	var won: bool = bool(payload["won"])
	result_title.text = "CARGO DELIVERED" if won else "CONVOY LOST"
	result_grade.text = str(payload["grade"])
	result_grade.add_theme_color_override("font_color", Color("e2b84a") if won else Color("e15b4c"))
	var pay: Dictionary = payload["pay"]
	var lines := PackedStringArray()
	lines.append("%s" % payload["level_name"])
	lines.append("Delivered  %d / %d cargo" % [payload["delivered"], payload["cargo_total"]])
	lines.append("Hostiles destroyed  %d" % payload["kills"])
	lines.append("Escorts lost  %d" % payload["escorts_lost"])
	lines.append("Time  %ds" % int(payload["time"]))
	lines.append("")
	if won:
		lines.append("Column cost     $%d" % int(pay["cost"]))
		lines.append("Salvage         +$%d" % int(pay["salvage"]))
		lines.append("Contract        +$%d" % int(pay["base"]))
		lines.append("Cargo bonus     +$%d" % int(pay["cargo"]))
		lines.append("Kill bonus      +$%d" % int(pay["kills"]))
		lines.append("Net             %s$%d" % ["+" if int(pay["net"]) >= 0 else "-", absi(int(pay["net"]))])
		lines.append("War chest       $%d" % int(payload["bank"]))
	else:
		lines.append("No payout. War chest stays $%d." % int(payload["bank"]))
		lines.append("Retry with a tougher column, or spend smoke when the radio calls contact.")
	if bool(payload.get("sandbox", false)):
		lines.clear()
		lines.append("%s" % payload["level_name"])
		lines.append("Delivered  %d / %d cargo" % [payload["delivered"], payload["cargo_total"]])
		lines.append("Hostiles destroyed  %d" % payload["kills"])
		lines.append("Escorts lost  %d" % payload["escorts_lost"])
		lines.append("Time  %ds" % int(payload["time"]))
		lines.append("")
		lines.append("Sandbox run. Campaign progress was not changed.")
	result_body.text = "\n".join(lines)
	if bool(payload.get("sandbox", false)):
		result_next.visible = false
	elif won and not bool(payload["last"]):
		result_next.text = "Next Mission"
		result_next.visible = true
	elif won:
		result_next.text = "Finish"
		result_next.visible = true
	else:
		result_next.visible = false


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	banner_t = 4.2


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	toast_t = 2.2


func _build_menu() -> void:
	menu_box = PanelContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	menu_box.offset_left = 36
	menu_box.offset_top = 48
	menu_box.offset_right = 520
	menu_box.offset_bottom = -48
	menu_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.88), Color(0.55, 0.48, 0.28), 10))
	root.add_child(menu_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	menu_box.add_child(box)
	var kicker := Label.new()
	kicker.text = "FIELD CONTRACT"
	kicker.add_theme_color_override("font_color", Color("e2b84a"))
	kicker.add_theme_font_size_override("font_size", 14)
	box.add_child(kicker)
	menu_title = Label.new()
	menu_title.text = "CONVOY\nCOMMAND"
	menu_title.add_theme_font_size_override("font_size", 54)
	box.add_child(menu_title)
	menu_sub = Label.new()
	menu_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_sub.custom_minimum_size = Vector2(420, 48)
	box.add_child(menu_sub)
	box.add_child(HSeparator.new())
	menu_buttons = VBoxContainer.new()
	menu_buttons.add_theme_constant_override("separation", 8)
	box.add_child(menu_buttons)
	var foot := Label.new()
	foot.text = "v1.0   ·   F11 fullscreen   ·   M mute"
	foot.add_theme_color_override("font_color", Color(0.7, 0.7, 0.62))
	box.add_child(foot)


func show_sandbox() -> void:
	hide_all()
	sandbox_box.visible = true
	_mark_sandbox_map(sandbox_map_index)
	_refresh_sandbox_readout()


func sandbox_settings() -> Dictionary:
	var counts := {}
	for kind in sandbox_spins.keys():
		var spin: SpinBox = sandbox_spins[kind]
		counts[str(kind)] = int(spin.value)
	return {
		"map": sandbox_map_index,
		"counts": counts,
		"god": sandbox_god.button_pressed,
		"threat": sandbox_diff.value / 100.0,
		"speed": sandbox_speed.value / 100.0,
	}


func spawn_kind() -> String:
	var kinds := ["infantry", "technical", "rpg", "tank", "heli"]
	var idx := spawn_pick.selected
	if idx < 0 or idx >= kinds.size():
		return "infantry"
	return kinds[idx]


func set_sandbox_chrome(on: bool) -> void:
	pause_retry.text = "Restart Drive" if on else "Retry Mission"
	result_retry.text = "Restart" if on else "Retry"


func _build_sandbox() -> void:
	sandbox_box = PanelContainer.new()
	sandbox_box.set_anchors_preset(Control.PRESET_CENTER)
	sandbox_box.offset_left = -430
	sandbox_box.offset_right = 430
	sandbox_box.offset_top = -330
	sandbox_box.offset_bottom = 330
	sandbox_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.94), Color(0.55, 0.48, 0.28), 10))
	root.add_child(sandbox_box)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	sandbox_box.add_child(outer)
	var title := Label.new()
	title.text = "SANDBOX"
	title.add_theme_font_size_override("font_size", 28)
	outer.add_child(title)
	var blurb := Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Unlimited budget. Every unit and upgrade is available. This run does not change the campaign."
	outer.add_child(blurb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	body.add_child(_sandbox_heading("Map"))
	var maps := GridContainer.new()
	maps.columns = 3
	maps.add_theme_constant_override("h_separation", 8)
	maps.add_theme_constant_override("v_separation", 6)
	body.add_child(maps)
	var map_names: Array = Defs.levels()
	for i in map_names.size():
		var map_btn := Button.new()
		map_btn.text = str(map_names[i]["name"])
		map_btn.custom_minimum_size = Vector2(180, 34)
		map_btn.pressed.connect(_mark_sandbox_map.bind(i))
		maps.add_child(map_btn)
		sandbox_map_buttons.append(map_btn)
	body.add_child(_sandbox_heading("Attackers"))
	var attackers := [
		["infantry", "Infantry", 4],
		["technical", "Technical", 2],
		["rpg", "RPG team", 1],
		["tank", "Tank", 0],
		["heli", "Helicopter", 0],
	]
	for spec in attackers:
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = str(spec[1])
		name.custom_minimum_size = Vector2(160, 0)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 30
		spin.step = 1
		spin.value = float(spec[2])
		spin.rounded = true
		spin.custom_minimum_size = Vector2(110, 0)
		row.add_child(spin)
		body.add_child(row)
		sandbox_spins[str(spec[0])] = spin
	body.add_child(_sandbox_heading("Difficulty"))
	sandbox_diff_label = Label.new()
	sandbox_diff_label.text = "Difficulty  100%"
	body.add_child(sandbox_diff_label)
	sandbox_diff = HSlider.new()
	sandbox_diff.min_value = 50
	sandbox_diff.max_value = 250
	sandbox_diff.step = 5
	sandbox_diff.value = 100
	sandbox_diff.custom_minimum_size = Vector2(0, 22)
	sandbox_diff.value_changed.connect(_on_setup_diff)
	body.add_child(sandbox_diff)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	body.add_child(presets)
	for preset in [["Easy", 60.0], ["Normal", 100.0], ["Hard", 150.0], ["Brutal", 220.0]]:
		var preset_btn := Button.new()
		preset_btn.text = str(preset[0])
		preset_btn.custom_minimum_size = Vector2(110, 34)
		preset_btn.pressed.connect(_set_setup_diff.bind(float(preset[1])))
		presets.add_child(preset_btn)
	sandbox_god = CheckBox.new()
	sandbox_god.text = "God mode — the convoy cannot be hurt"
	body.add_child(sandbox_god)
	body.add_child(_sandbox_heading("Game speed"))
	sandbox_speed_label = Label.new()
	sandbox_speed_label.text = "Speed  1.00x"
	body.add_child(sandbox_speed_label)
	sandbox_speed = HSlider.new()
	sandbox_speed.min_value = 25
	sandbox_speed.max_value = 300
	sandbox_speed.step = 5
	sandbox_speed.value = 100
	sandbox_speed.custom_minimum_size = Vector2(0, 22)
	sandbox_speed.value_changed.connect(_on_setup_speed)
	body.add_child(sandbox_speed)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	outer.add_child(actions)
	actions.add_child(_button("Arm Column", sandbox_arm_pressed))
	actions.add_child(_button("Back", back_pressed))
	_build_sandbox_drive()


func _build_sandbox_drive() -> void:
	sandbox_drive = PanelContainer.new()
	sandbox_drive.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sandbox_drive.offset_left = 16
	sandbox_drive.offset_top = 108
	sandbox_drive.offset_right = 300
	sandbox_drive.offset_bottom = 470
	sandbox_drive.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.86), Color(0.55, 0.48, 0.28), 8))
	root.add_child(sandbox_drive)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	sandbox_drive.add_child(box)
	var heading := Label.new()
	heading.text = "SANDBOX"
	heading.add_theme_color_override("font_color", Color("e2b84a"))
	box.add_child(heading)
	drive_god = CheckBox.new()
	drive_god.text = "God mode"
	drive_god.toggled.connect(_on_drive_god)
	box.add_child(drive_god)
	drive_diff_label = Label.new()
	drive_diff_label.text = "Difficulty  100%"
	box.add_child(drive_diff_label)
	drive_diff = HSlider.new()
	drive_diff.min_value = 50
	drive_diff.max_value = 250
	drive_diff.step = 5
	drive_diff.value = 100
	drive_diff.custom_minimum_size = Vector2(0, 18)
	drive_diff.value_changed.connect(_on_drive_diff)
	box.add_child(drive_diff)
	drive_speed_label = Label.new()
	drive_speed_label.text = "Speed  1.00x"
	box.add_child(drive_speed_label)
	drive_speed = HSlider.new()
	drive_speed.min_value = 25
	drive_speed.max_value = 300
	drive_speed.step = 5
	drive_speed.value = 100
	drive_speed.custom_minimum_size = Vector2(0, 18)
	drive_speed.value_changed.connect(_on_drive_speed)
	box.add_child(drive_speed)
	var spawn_label := Label.new()
	spawn_label.text = "Spawn on left click"
	box.add_child(spawn_label)
	spawn_pick = OptionButton.new()
	spawn_pick.add_item("Infantry")
	spawn_pick.add_item("Technical")
	spawn_pick.add_item("RPG team")
	spawn_pick.add_item("Tank")
	spawn_pick.add_item("Helicopter")
	box.add_child(spawn_pick)
	var restart := Button.new()
	restart.text = "Restart Drive"
	restart.pressed.connect(func() -> void:
		if audio:
			audio.play("ui_click", -4.0)
		sandbox_restart_pressed.emit()
	)
	box.add_child(restart)


func _sandbox_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_color_override("font_color", Color("e2b84a"))
	label.add_theme_font_size_override("font_size", 13)
	return label


func _mark_sandbox_map(index: int) -> void:
	sandbox_map_index = index
	for i in sandbox_map_buttons.size():
		var btn: Button = sandbox_map_buttons[i]
		if i == index:
			btn.add_theme_stylebox_override("normal", _style(Color("3a3420"), Color("e2b84a"), 6))
		else:
			btn.add_theme_stylebox_override("normal", _style(Color("24281c"), Color("5a5340"), 6))


func _set_setup_diff(value: float) -> void:
	sandbox_diff.value = value


func _on_setup_diff(value: float) -> void:
	sandbox_diff_label.text = "Difficulty  %d%%" % int(value)
	if sandbox_sync:
		return
	sandbox_sync = true
	drive_diff.value = value
	sandbox_sync = false
	_refresh_sandbox_readout()
	sandbox_threat_changed.emit(value / 100.0)


func _on_setup_speed(value: float) -> void:
	sandbox_speed_label.text = "Speed  %.2fx" % (value / 100.0)


func _on_drive_god(on: bool) -> void:
	if sandbox_sync:
		return
	sandbox_god.button_pressed = on
	sandbox_god_toggled.emit(on)


func _on_drive_diff(value: float) -> void:
	if sandbox_sync:
		return
	sandbox_sync = true
	sandbox_diff.value = value
	sandbox_sync = false
	sandbox_diff_label.text = "Difficulty  %d%%" % int(value)
	drive_diff_label.text = "Difficulty  %d%%" % int(value)
	sandbox_threat_changed.emit(value / 100.0)


func _on_drive_speed(value: float) -> void:
	if sandbox_sync:
		return
	sandbox_speed.value = value
	sandbox_speed_label.text = "Speed  %.2fx" % (value / 100.0)
	drive_speed_label.text = "Speed  %.2fx" % (value / 100.0)
	sandbox_speed_changed.emit(value / 100.0)


func _refresh_sandbox_readout() -> void:
	sandbox_diff_label.text = "Difficulty  %d%%" % int(sandbox_diff.value)
	sandbox_speed_label.text = "Speed  %.2fx" % (sandbox_speed.value / 100.0)
	drive_diff_label.text = "Difficulty  %d%%" % int(drive_diff.value)
	drive_speed_label.text = "Speed  %.2fx" % (drive_speed.value / 100.0)


func _build_help() -> void:
	help_box = PanelContainer.new()
	help_box.set_anchors_preset(Control.PRESET_CENTER)
	help_box.offset_left = -390
	help_box.offset_right = 390
	help_box.offset_top = -280
	help_box.offset_bottom = 280
	help_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.94), Color(0.55, 0.48, 0.28), 10))
	root.add_child(help_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	help_box.add_child(box)
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	help_body = Label.new()
	help_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_body.text = "Arm a formation, then ride it to the drop.\n\nBuild\n1-9, 0, minus and equals pick a unit. Left click anywhere in the yard to place it. Drag a vehicle to move it. Right click removes it. R rotates. Q fills a suggested wedge. Enter deploys.\nThere is no lane cap. Wide lines and clusters keep their spacing while they drive.\nFuel stretches smoke and returns a charge. Engineers clear IEDs. Mortars splash. The escort helicopter flies with the column. Medevac heals. Bring at least one cargo truck.\n\nDrive\nGuns fire on their own. Right-drag orbits the camera, the wheel zooms, F snaps back. A/D orbit, W/S zoom.\nQ smoke — thick cover, hostiles miss more.\nE airstrike — a jet, then a blast on the densest group. It does not hit your trucks.\nR field repair — a burst of healing.\nEsc pauses.\n\nDeliver at least one cargo truck. Lose if they all die. Pay rolls into the next mission's budget.\n\nSandbox, from the main menu, gives an unlimited budget on any map. Choose the attackers, a difficulty, god mode, and the game speed. Left click spawns a hostile. Restart Drive runs the same column again. Sandbox does not change the campaign."
	box.add_child(help_body)
	box.add_child(_button("Back", back_pressed))


func _build_brief() -> void:
	brief_box = PanelContainer.new()
	brief_box.set_anchors_preset(Control.PRESET_CENTER)
	brief_box.offset_left = -360
	brief_box.offset_right = 360
	brief_box.offset_top = -230
	brief_box.offset_bottom = 230
	brief_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.94), Color(0.55, 0.48, 0.28), 10))
	root.add_child(brief_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	brief_box.add_child(box)
	brief_sub = Label.new()
	brief_sub.add_theme_color_override("font_color", Color("e2b84a"))
	box.add_child(brief_sub)
	brief_title = Label.new()
	brief_title.add_theme_font_size_override("font_size", 36)
	box.add_child(brief_title)
	brief_body = Label.new()
	brief_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(brief_body)
	brief_meta = Label.new()
	brief_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(brief_meta)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_button("Arm Convoy", arm_pressed))
	row.add_child(_button("Back", back_pressed))


func _build_build() -> void:
	build_top = PanelContainer.new()
	build_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	build_top.offset_left = 16
	build_top.offset_top = 12
	build_top.offset_right = -240
	build_top.offset_bottom = 108
	build_top.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.82), Color(0.45, 0.4, 0.24), 8))
	root.add_child(build_top)
	var top := VBoxContainer.new()
	build_top.add_child(top)
	build_title = Label.new()
	build_title.add_theme_font_size_override("font_size", 20)
	top.add_child(build_title)
	build_budget = Label.new()
	build_budget.add_theme_font_size_override("font_size", 22)
	build_budget.add_theme_color_override("font_color", Color("e2b84a"))
	top.add_child(build_budget)
	build_column = Label.new()
	top.add_child(build_column)
	build_warn = Label.new()
	build_warn.add_theme_color_override("font_color", Color("e7a2a2"))
	top.add_child(build_warn)

	build_bottom = PanelContainer.new()
	build_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	build_bottom.offset_left = 12
	build_bottom.offset_right = -12
	build_bottom.offset_top = -188
	build_bottom.offset_bottom = -12
	build_bottom.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.9), Color(0.45, 0.4, 0.24), 8))
	root.add_child(build_bottom)
	var row_scroll := ScrollContainer.new()
	row_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row_scroll.custom_minimum_size = Vector2(900, 120)
	build_bottom.add_child(row_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row_scroll.add_child(row)
	for i in Defs.CARD_ORDER.size():
		var kind: String = Defs.CARD_ORDER[i]
		var spec: Dictionary = Defs.UNITS[kind]
		var btn := Button.new()
		btn.text = "%d  %s\n$%d   HP %d   DMG %d\nRNG %d   SPD %d" % [
			i + 1, spec["name"], spec["cost"], spec["hp"], int(spec["dmg"]), int(spec["rng"]), int(spec["spd"]),
		]
		btn.custom_minimum_size = Vector2(128, 100)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_card.bind(kind))
		row.add_child(btn)
		cards[kind] = btn
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	side.add_child(_button("Quick Fill", quick_pressed))
	deploy_button = _button("Deploy", deploy_pressed)
	side.add_child(deploy_button)
	side.add_child(_button("Back", back_pressed))
	_build_dock()


func _build_dock() -> void:
	build_dock = PanelContainer.new()
	build_dock.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	build_dock.offset_left = 12
	build_dock.offset_top = 118
	build_dock.offset_right = 318
	build_dock.offset_bottom = -180
	build_dock.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.9), Color(0.45, 0.4, 0.24), 8))
	root.add_child(build_dock)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_dock.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	box.add_child(_caption("CONVOY NAME"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Name the column"
	name_edit.text = "Column One"
	name_edit.focus_exited.connect(func() -> void: name_changed.emit(name_edit.text))
	name_edit.text_submitted.connect(func(text: String) -> void: name_changed.emit(text))
	box.add_child(name_edit)
	box.add_child(_caption("CAMO"))
	var camo_row := HBoxContainer.new()
	camo_row.add_theme_constant_override("separation", 4)
	box.add_child(camo_row)
	for camo_name in Defs.CAMO_ORDER:
		var spec: Dictionary = Defs.CAMOS[camo_name]
		var swatch := Button.new()
		swatch.text = str(spec["name"]).substr(0, 1)
		swatch.tooltip_text = str(spec["name"])
		swatch.custom_minimum_size = Vector2(36, 28)
		var col: Color = spec["a"]
		swatch.add_theme_stylebox_override("normal", _style(col, Color("2a2a24"), 4))
		swatch.pressed.connect(camo_pressed.emit.bind(camo_name))
		camo_row.add_child(swatch)
		camo_buttons[camo_name] = swatch
	box.add_child(_caption("SELECTED VEHICLE"))
	upgrade_label = Label.new()
	upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_label.text = "Click a vehicle on the grid."
	box.add_child(upgrade_label)
	box.add_child(_upgrade_row("Armor", "armor"))
	box.add_child(_upgrade_row("Weapon", "weapon"))
	box.add_child(_upgrade_row("Speed", "speed"))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	box.add_child(tools)
	tools.add_child(_emit_button("Rotate", rotate_pressed))
	tools.add_child(_emit_button("Remove", remove_pressed))
	box.add_child(_caption("FORMATION"))
	var shapes := HBoxContainer.new()
	shapes.add_theme_constant_override("separation", 4)
	box.add_child(shapes)
	for style in ["line", "wedge", "box"]:
		var shape := Button.new()
		shape.text = style.capitalize()
		shape.pressed.connect(arrange_pressed.emit.bind(style))
		shapes.add_child(shape)
	box.add_child(_caption("PRESETS"))
	preset_edit = LineEdit.new()
	preset_edit.placeholder_text = "Preset name"
	box.add_child(preset_edit)
	preset_pick = OptionButton.new()
	box.add_child(preset_pick)
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 4)
	box.add_child(preset_row)
	var save_b := Button.new()
	save_b.text = "Save"
	save_b.pressed.connect(func() -> void: preset_save.emit(preset_edit.text))
	preset_row.add_child(save_b)
	var load_b := Button.new()
	load_b.text = "Load"
	load_b.pressed.connect(func() -> void:
		if preset_pick.item_count == 0:
			return
		preset_load.emit(preset_pick.get_item_text(preset_pick.selected))
	)
	preset_row.add_child(load_b)
	var del_b := Button.new()
	del_b.text = "Delete"
	del_b.pressed.connect(func() -> void:
		if preset_pick.item_count == 0:
			return
		preset_delete.emit(preset_pick.get_item_text(preset_pick.selected))
	)
	preset_row.add_child(del_b)


func _sync_dock(state: Dictionary, units: Array) -> void:
	var convoy := str(state.get("name", ""))
	if name_edit and not name_edit.has_focus() and convoy != "":
		name_edit.text = convoy
	var camo := str(state.get("camo", "woodland"))
	for key in camo_buttons:
		var swatch: Button = camo_buttons[key]
		var col: Color = Defs.CAMOS[key]["a"]
		var border := Color("e2b84a") if key == camo else Color("2a2a24")
		swatch.add_theme_stylebox_override("normal", _style(col, border, 4))
	var selected := int(state.get("selected", -1))
	if selected >= 0 and selected < units.size():
		var unit: Dictionary = units[selected]
		var spec: Dictionary = Defs.UNITS[str(unit["kind"])]
		upgrade_label.text = "%s\nArmor %d   Weapon %d   Speed %d\nYaw %d°   lane %d   row %d" % [
			spec["name"], int(unit["armor"]), int(unit["weapon"]), int(unit["speed"]),
			int(unit["yaw"]), int(unit["lane"]) + 1, int(unit["row"]) + 1,
		]
	else:
		upgrade_label.text = "Click a vehicle on the grid."
	var names: Array = state.get("presets", [])
	if preset_pick:
		var current := preset_pick.get_item_text(preset_pick.selected) if preset_pick.item_count > 0 else ""
		preset_pick.clear()
		for preset_name in names:
			preset_pick.add_item(str(preset_name))
		for i in preset_pick.item_count:
			if preset_pick.get_item_text(i) == current:
				preset_pick.select(i)
				break


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("e2b84a"))
	label.add_theme_font_size_override("font_size", 12)
	return label


func _upgrade_row(title: String, stat: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(70, 0)
	row.add_child(label)
	for level in 3:
		var btn := Button.new()
		btn.text = str(level)
		btn.custom_minimum_size = Vector2(36, 0)
		btn.pressed.connect(upgrade_pressed.emit.bind(stat, level))
		row.add_child(btn)
	return row


func _emit_button(text: String, which: Signal) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(func() -> void: which.emit())
	return btn


func _build_drive() -> void:
	drive_top = PanelContainer.new()
	drive_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	drive_top.offset_left = 16
	drive_top.offset_top = 12
	drive_top.offset_right = -240
	drive_top.offset_bottom = 92
	drive_top.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.78), Color(0.45, 0.4, 0.24), 8))
	root.add_child(drive_top)
	var top := VBoxContainer.new()
	drive_top.add_child(top)
	var line := HBoxContainer.new()
	top.add_child(line)
	drive_title = Label.new()
	drive_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drive_title.add_theme_font_size_override("font_size", 18)
	line.add_child(drive_title)
	drive_hostiles = Label.new()
	drive_hostiles.add_theme_color_override("font_color", Color("e7a2a2"))
	line.add_child(drive_hostiles)
	drive_progress = ProgressBar.new()
	drive_progress.max_value = 100
	drive_progress.show_percentage = false
	drive_progress.custom_minimum_size = Vector2(0, 14)
	top.add_child(drive_progress)
	var stats := HBoxContainer.new()
	top.add_child(stats)
	drive_cargo = Label.new()
	drive_cargo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(drive_cargo)
	drive_hp = Label.new()
	stats.add_child(drive_hp)

	drive_bottom = PanelContainer.new()
	drive_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	drive_bottom.offset_left = 180
	drive_bottom.offset_right = -180
	drive_bottom.offset_top = -92
	drive_bottom.offset_bottom = -16
	drive_bottom.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.82), Color(0.45, 0.4, 0.24), 8))
	root.add_child(drive_bottom)
	var col := VBoxContainer.new()
	drive_bottom.add_child(col)
	drive_hint = Label.new()
	drive_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(drive_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	smoke_button = _button("SMOKE", ability_pressed, "smoke")
	strike_button = _button("AIRSTRIKE", ability_pressed, "airstrike")
	repair_button = _button("REPAIR", ability_pressed, "repair")
	row.add_child(smoke_button)
	row.add_child(strike_button)
	row.add_child(repair_button)


func _build_pause() -> void:
	pause_box = PanelContainer.new()
	pause_box.set_anchors_preset(Control.PRESET_CENTER)
	pause_box.offset_left = -180
	pause_box.offset_right = 180
	pause_box.offset_top = -120
	pause_box.offset_bottom = 120
	pause_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.94), Color(0.55, 0.48, 0.28), 10))
	root.add_child(pause_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pause_box.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	box.add_child(_button("Resume", resume_pressed))
	pause_retry = _button("Retry Mission", retry_pressed)
	box.add_child(pause_retry)
	box.add_child(_button("Main Menu", menu_pressed))


func _build_results() -> void:
	result_box = PanelContainer.new()
	result_box.set_anchors_preset(Control.PRESET_CENTER)
	result_box.offset_left = -320
	result_box.offset_right = 320
	result_box.offset_top = -280
	result_box.offset_bottom = 280
	result_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.94), Color(0.55, 0.48, 0.28), 10))
	root.add_child(result_box)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	result_box.add_child(box)
	result_grade = Label.new()
	result_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_grade.add_theme_font_size_override("font_size", 64)
	box.add_child(result_grade)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 26)
	box.add_child(result_title)
	result_body = Label.new()
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	result_next = _button("Next Mission", next_pressed)
	row.add_child(result_next)
	result_retry = _button("Retry", retry_pressed)
	row.add_child(result_retry)
	row.add_child(_button("Menu", menu_pressed))


func _menu_button(text: String, which: Signal) -> void:
	menu_buttons.add_child(_button(text, which))


func _on_card(kind: String) -> void:
	if audio:
		audio.play("ui_click", -4.0)
	selected_kind = kind
	unit_selected.emit(kind)


func _button(text: String, which: Signal, arg: String = "") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 42)
	if arg == "":
		btn.pressed.connect(func() -> void:
			if audio:
				audio.play("ui_click", -4.0)
			which.emit()
		)
	else:
		btn.pressed.connect(func() -> void:
			if audio:
				audio.play("ui_click", -4.0)
			which.emit(arg)
		)
	return btn


func _theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "DejaVu Sans", "Sans"])
	font.font_weight = 600
	theme.default_font = font
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "Label", Color(0.94, 0.93, 0.88))
	theme.set_font_size("font_size", "Button", 15)
	theme.set_color("font_color", "Button", Color(0.95, 0.94, 0.88))
	theme.set_color("font_hover_color", "Button", Color(1, 0.96, 0.84))
	theme.set_color("font_pressed_color", "Button", Color(1, 0.95, 0.8))
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.54, 0.48))
	theme.set_stylebox("normal", "Button", _style(Color("24281c"), Color("5a5340"), 6))
	theme.set_stylebox("hover", "Button", _style(Color("343824"), Color("e2b84a"), 6))
	theme.set_stylebox("pressed", "Button", _style(Color("3d3820"), Color("e2b84a"), 6))
	theme.set_stylebox("disabled", "Button", _style(Color("171815"), Color("2c2c26"), 6))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.12, 0.1)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("e2b84a")
	bar_fill.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme


func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
