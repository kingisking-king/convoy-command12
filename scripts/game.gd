extends Node

const Defs = preload("res://scripts/defs.gd")
const RouteScript = preload("res://scripts/route.gd")
const SimScript = preload("res://scripts/battle_sim.gd")
const Checks = preload("res://scripts/sim_checks.gd")
const WorldScript = preload("res://scripts/world_view.gd")
const HudScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio_fx.gd")

enum Phase { MENU, HELP, BRIEF, BUILD, DRIVE, PAUSE, RESULTS, SANDBOX }

const SAVE_PATH := "user://campaign.cfg"
const PRESET_PATH := "user://formations.cfg"
const START_BANK := 500

var phase: int = Phase.MENU
var bank := START_BANK
var level_index := 0
var campaign_done := false
var formation: Array = []
var selected_kind := "humvee"
var selected_i := -1
var drag_index := -1
var drag_from := Vector2i(-1, -1)
var convoy_name := "Column One"
var camo := "desert"
var route = null
var sim = null
var column_cost := 0
var attempt := 0
var mission_level := 0
var world
var hud
var audio
var shot_dir := ""
var catalog_dir := ""
var lands_dir := ""
var manual_sim := false
var mission_resolved := false
var sim_acc := 0.0
var show_fps := false
var fps_label: Label
var return_phase: int = Phase.MENU
var sandbox := false
var sandbox_map := 0
var sandbox_god := false
var sandbox_threat := 1.0
var sandbox_speed := 1.0
var sandbox_level: Dictionary = {}
var sandbox_shot := ""

func _ready() -> void:
	audio = AudioScript.new()
	add_child(audio)
	audio.setup()
	world = WorldScript.new()
	add_child(world)
	world.setup()
	hud = HudScript.new()
	add_child(hud)
	hud.setup(audio)
	_connect_hud()
	fps_label = Label.new()
	fps_label.position = Vector2(12, 12)
	fps_label.visible = false
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.root.add_child(fps_label)
	_parse_args()
	if _has_arg("--autotest"):
		var ok: bool = Checks.run()
		get_tree().quit(0 if ok else 1)
		return
	if catalog_dir != "":
		world.set_shadows(false)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		_enter_menu()
		call_deferred("_catalog_run")
		return
	if lands_dir != "":
		world.set_shadows(false)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		_enter_menu()
		call_deferred("_lands_run")
		return
	if sandbox_shot != "":
		world.set_shadows(false)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		_enter_menu()
		call_deferred("_sandbox_shot_run")
		return
	if shot_dir != "":
		manual_sim = true
		world.set_shadows(false)
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		_enter_menu()
		call_deferred("_shot_run")
		return
	_load_save()
	_enter_menu()


func _process(dt: float) -> void:
	fps_label.visible = show_fps
	if show_fps:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	world.tick(dt)
	if phase == Phase.DRIVE and sim != null:
		if not manual_sim:
			_advance(dt)
		world.sync(sim, dt)
		hud.refresh_drive(sim, route)
		audio.set_engine(true)
		audio.set_heli(_living_heli())
	else:
		audio.set_engine(false)
		audio.set_heli(false)
	if phase == Phase.PAUSE and sim != null:
		world.sync(sim, dt)
		hud.refresh_drive(sim, route)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_F11:
			_toggle_fullscreen()
			return
		if key == KEY_M:
			var muted: bool = audio.toggle_mute()
			hud.toast("Sound off" if muted else "Sound on")
			return
		if key == KEY_F3:
			show_fps = not show_fps
			return
		if key == KEY_ESCAPE:
			_on_escape()
			return
	if phase == Phase.BUILD:
		_build_input(event)
	elif phase == Phase.DRIVE:
		_drive_input(event)
		if sandbox:
			_sandbox_click(event)
	if phase == Phase.BUILD or phase == Phase.DRIVE or phase == Phase.BRIEF:
		_camera_input(event)


func _connect_hud() -> void:
	hud.play_pressed.connect(_on_play)
	hud.restart_pressed.connect(_on_restart)
	hud.help_pressed.connect(_on_help)
	hud.quit_pressed.connect(func() -> void: get_tree().quit())
	hud.back_pressed.connect(_on_back)
	hud.arm_pressed.connect(_on_arm)
	hud.deploy_pressed.connect(_on_deploy)
	hud.quick_pressed.connect(_on_quick)
	hud.unit_selected.connect(_on_unit_selected)
	hud.ability_pressed.connect(_on_ability)
	hud.next_pressed.connect(_on_next)
	hud.retry_pressed.connect(_on_retry)
	hud.menu_pressed.connect(_on_menu)
	hud.resume_pressed.connect(_on_resume)
	hud.rotate_pressed.connect(_on_rotate)
	hud.remove_pressed.connect(_on_remove_selected)
	hud.arrange_pressed.connect(_on_arrange)
	hud.upgrade_pressed.connect(_on_upgrade)
	hud.camo_pressed.connect(_on_camo)
	hud.name_changed.connect(_on_name)
	hud.preset_save.connect(_on_preset_save)
	hud.preset_load.connect(_on_preset_load)
	hud.preset_delete.connect(_on_preset_delete)
	hud.sandbox_pressed.connect(_on_sandbox)
	hud.sandbox_arm_pressed.connect(_on_sandbox_arm)
	hud.sandbox_god_toggled.connect(_on_sandbox_god)
	hud.sandbox_speed_changed.connect(_on_sandbox_speed)
	hud.sandbox_threat_changed.connect(_on_sandbox_threat)
	hud.sandbox_restart_pressed.connect(_on_retry)


func _enter_menu() -> void:
	phase = Phase.MENU
	world.show_menu()
	audio.set_music("music_menu")
	hud.show_menu(bank, level_index, Defs.levels().size(), campaign_done)


func _on_play() -> void:
	if campaign_done:
		_on_restart()
		return
	_open_brief()


func _on_restart() -> void:
	bank = START_BANK
	level_index = 0
	campaign_done = false
	attempt = 0
	_save()
	_open_brief()


func _on_help() -> void:
	return_phase = phase
	phase = Phase.HELP
	hud.show_help()


func _on_back() -> void:
	if phase == Phase.HELP:
		if return_phase == Phase.MENU:
			_enter_menu()
		else:
			_open_brief()
		return
	if phase == Phase.SANDBOX:
		_leave_sandbox()
		return
	if phase == Phase.BUILD:
		if sandbox:
			phase = Phase.SANDBOX
			hud.show_sandbox()
			return
		_open_brief()
		return
	_enter_menu()


func _budget() -> int:
	return 999999 if sandbox else bank


func _on_sandbox() -> void:
	sandbox = true
	phase = Phase.SANDBOX
	hud.set_sandbox_chrome(true)
	hud.show_sandbox()


func _on_sandbox_arm() -> void:
	var settings: Dictionary = hud.sandbox_settings()
	sandbox = true
	sandbox_map = clampi(int(settings["map"]), 0, Defs.levels().size() - 1)
	sandbox_god = bool(settings["god"])
	sandbox_threat = clampf(float(settings["threat"]), 0.5, 2.5)
	sandbox_speed = clampf(float(settings["speed"]), 0.25, 3.0)
	_prepare_sandbox_level(settings["counts"])
	_on_arm()


func _prepare_sandbox_level(counts: Dictionary) -> void:
	var src: Dictionary = Defs.levels()[sandbox_map].duplicate(true)
	src["charges"] = {"smoke": 99, "airstrike": 99, "repair": 99}
	src["base_pay"] = 0
	src["brief"] = "Sandbox. Unlimited budget. This run does not touch the campaign."
	src["ambushes"] = _sandbox_ambushes(float(src["length"]), counts)
	sandbox_level = src


func _sandbox_ambushes(length: float, counts: Dictionary) -> Array:
	var kinds := ["infantry", "technical", "rpg", "tank", "heli"]
	var queue: Array = []
	for kind in kinds:
		var n := clampi(int(counts.get(kind, 0)), 0, 30)
		for _i in n:
			queue.append(kind)
	if queue.is_empty():
		return []
	var waves: Array = []
	var chunk: Array = []
	for kind in queue:
		chunk.append(kind)
		if chunk.size() >= 5:
			waves.append(chunk.duplicate())
			chunk.clear()
	if not chunk.is_empty():
		waves.append(chunk)
	var ambushes: Array = []
	var span := maxf(length - 160.0, 80.0)
	for i in waves.size():
		var at := 80.0 + span * (float(i) + 0.5) / float(maxi(waves.size(), 1))
		var specs: Array = []
		var side := 1.0
		for kind in waves[i]:
			specs.append({
				"k": str(kind),
				"side": side,
				"lat": 18.0 + float(specs.size() % 3) * 5.0,
				"ahead": float(specs.size()) * 7.0,
			})
			side = -side
		ambushes.append({"at": at, "banner": "Sandbox contact", "units": specs})
	return ambushes


func _leave_sandbox() -> void:
	sandbox = false
	sim = null
	hud.set_sandbox_chrome(false)
	_enter_menu()


func _open_brief() -> void:
	phase = Phase.BRIEF
	var level: Dictionary = Defs.levels()[level_index]
	route = RouteScript.new(level)
	world.show_level(level, route)
	world.camera_mode = "build"
	audio.set_music("music_menu")
	hud.show_brief(level, level_index, Defs.levels().size(), bank)


func _on_arm() -> void:
	phase = Phase.BUILD
	formation.clear()
	selected_i = -1
	drag_index = -1
	selected_kind = "humvee"
	var level: Dictionary = _active_level()
	if sandbox:
		route = RouteScript.new(level)
		world.show_level(level, route)
		world.camera_mode = "build"
	camo = Defs.camo_for_biome(str(level["biome"]))
	if convoy_name == "":
		convoy_name = "Column One"
	_refresh_build()
	if sandbox:
		hud.toast("Sandbox budget is unlimited. Upgrades are all unlocked.")


func _active_level() -> Dictionary:
	if sandbox and not sandbox_level.is_empty():
		return sandbox_level
	return Defs.levels()[level_index]


func _refresh_build() -> void:
	var level: Dictionary = _active_level()
	world.meshes.scheme = camo
	hud.show_build(level, _budget(), formation, selected_kind, route, {
		"name": convoy_name,
		"camo": camo,
		"selected": selected_i,
		"presets": _preset_names(),
		"unlimited": sandbox,
	})
	world.show_formation(formation, camo, selected_i)


func _on_unit_selected(kind: String) -> void:
	selected_kind = kind
	_refresh_build()


func _on_quick() -> void:
	formation = Defs.recommended(sandbox_map if sandbox else level_index, _budget())
	selected_i = -1
	audio.play("ui_place", -4.0)
	_refresh_build()
	hud.toast("Suggested wedge loaded. Drag it into the shape you want.")


func _build_input(event: InputEvent) -> void:
	if hud.typing() and event is InputEventKey:
		return
	if event is InputEventMouseMotion and not hud.hovering_ui():
		_hover_cell((event as InputEventMouseMotion).position)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
			KEY_4: idx = 3
			KEY_5: idx = 4
			KEY_6: idx = 5
			KEY_Q:
				_on_quick()
				return
			KEY_R:
				_on_rotate()
				return
			KEY_ENTER, KEY_KP_ENTER:
				_on_deploy()
				return
		if idx >= 0 and idx < Defs.CARD_ORDER.size():
			_on_unit_selected(Defs.CARD_ORDER[idx])
		return
	if event is InputEventMouseButton:
		if hud.hovering_ui():
			return
		var mb := event as InputEventMouseButton
		var cell: Vector2i = world.pick_cell(mb.position)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_remove_at(cell)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_cell(cell)
		elif drag_index >= 0:
			_drop_cell(cell)


func _hover_cell(screen: Vector2) -> void:
	var cell: Vector2i = world.pick_cell(screen)
	var occupied: bool = Defs.index_at(formation, cell.x, cell.y) >= 0 if cell.x >= 0 else false
	var ghost_kind := ""
	var ok: bool = false
	if drag_index >= 0 and drag_index < formation.size():
		ghost_kind = str(formation[drag_index]["kind"])
		ok = cell.x >= 0 and (not occupied or Defs.index_at(formation, cell.x, cell.y) == drag_index)
	elif cell.x >= 0 and not occupied and selected_kind != "":
		ghost_kind = selected_kind
		ok = _can_add(selected_kind)
	world.set_cell_hover(cell, "ok" if ok else ("bad" if cell.x >= 0 and not occupied else "none"))
	world.set_ghost(ghost_kind, cell if not occupied or drag_index >= 0 else Vector2i(-1, -1), ok, camo)


func _press_cell(cell: Vector2i) -> void:
	if cell.x < 0:
		selected_i = -1
		drag_index = -1
		_refresh_build()
		return
	var idx := Defs.index_at(formation, cell.x, cell.y)
	if idx >= 0:
		selected_i = idx
		drag_index = idx
		drag_from = cell
		_refresh_build()
		return
	drag_index = -1
	if selected_kind == "":
		hud.toast("Pick a unit first.")
		return
	if formation.size() >= Defs.MAX_UNITS:
		hud.toast("The formation is full.")
		return
	if not _can_add(selected_kind):
		hud.toast("Not enough budget.")
		return
	formation.append(Defs.make_unit(selected_kind, cell.x, cell.y))
	selected_i = formation.size() - 1
	audio.play("ui_place", -3.0)
	_refresh_build()


func _drop_cell(cell: Vector2i) -> void:
	var idx := drag_index
	drag_index = -1
	if idx < 0 or idx >= formation.size():
		return
	if cell.x < 0 or cell == drag_from:
		_refresh_build()
		return
	var other := Defs.index_at(formation, cell.x, cell.y)
	if other >= 0 and other != idx:
		hud.toast("That cell is taken.")
		_refresh_build()
		return
	formation[idx]["lane"] = cell.x
	formation[idx]["row"] = cell.y
	audio.play("ui_place", -6.0)
	_refresh_build()


func _remove_at(cell: Vector2i) -> void:
	var idx := Defs.index_at(formation, cell.x, cell.y)
	if idx < 0:
		return
	formation.remove_at(idx)
	if selected_i == idx:
		selected_i = -1
	elif selected_i > idx:
		selected_i -= 1
	audio.play("ui_click", -6.0, 0.8)
	_refresh_build()


func _can_add(kind: String) -> bool:
	var trial: Array = formation.duplicate()
	trial.append(Defs.make_unit(kind, 0, 0))
	return Defs.roster_cost(trial) <= _budget()


func _on_rotate() -> void:
	if selected_i < 0 or selected_i >= formation.size():
		return
	formation[selected_i]["yaw"] = posmod(int(formation[selected_i]["yaw"]) + Defs.YAW_STEP, 360)
	_refresh_build()


func _on_remove_selected() -> void:
	if selected_i < 0 or selected_i >= formation.size():
		return
	_remove_at(Vector2i(int(formation[selected_i]["lane"]), int(formation[selected_i]["row"])))


func _on_arrange(style: String) -> void:
	if formation.is_empty():
		return
	var kinds: Array = []
	var kept: Array = []
	for entry in formation:
		kinds.append(str(entry["kind"]))
		kept.append(entry)
	var laid: Array = Defs.arrange(kinds, style)
	var pool: Array = kept.duplicate()
	for spot in laid:
		for i in pool.size():
			if str(pool[i]["kind"]) == str(spot["kind"]):
				spot["armor"] = int(pool[i]["armor"])
				spot["weapon"] = int(pool[i]["weapon"])
				spot["speed"] = int(pool[i]["speed"])
				spot["yaw"] = int(pool[i]["yaw"])
				pool.remove_at(i)
				break
	formation = laid
	selected_i = -1
	_refresh_build()


func _on_upgrade(stat: String, level: int) -> void:
	if selected_i < 0 or selected_i >= formation.size():
		hud.toast("Select a vehicle first.")
		return
	if stat != "armor" and stat != "weapon" and stat != "speed":
		return
	var previous := int(formation[selected_i][stat])
	formation[selected_i][stat] = clampi(level, 0, 2)
	if Defs.roster_cost(formation) > _budget():
		formation[selected_i][stat] = previous
		hud.toast("Not enough budget for that upgrade.")
		return
	_refresh_build()


func _on_camo(next: String) -> void:
	if not Defs.CAMOS.has(next):
		return
	camo = next
	_refresh_build()


func _on_name(next: String) -> void:
	var trimmed := next.strip_edges()
	convoy_name = trimmed if trimmed != "" else "Column One"
	_refresh_build()


func _on_preset_save(preset_name: String) -> void:
	var trimmed := preset_name.strip_edges()
	if trimmed == "":
		hud.toast("Name the preset first.")
		return
	var cfg := ConfigFile.new()
	cfg.load(PRESET_PATH)
	var names: Array = _preset_names()
	if trimmed not in names:
		names.append(trimmed)
	cfg.set_value("presets", "names", names)
	cfg.set_value(trimmed, "camo", camo)
	cfg.set_value(trimmed, "convoy", convoy_name)
	cfg.set_value(trimmed, "units", JSON.stringify(formation))
	cfg.save(PRESET_PATH)
	hud.toast("Saved preset %s." % trimmed)
	_refresh_build()


func _on_preset_load(preset_name: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PRESET_PATH) != OK:
		return
	var raw := str(cfg.get_value(preset_name, "units", "[]"))
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		hud.toast("That preset could not be read.")
		return
	var loaded: Array = []
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		loaded.append(Defs.make_unit(
			str(entry.get("kind", "")),
			int(entry.get("lane", 0)),
			int(entry.get("row", 0)),
			int(entry.get("yaw", 0)),
			int(entry.get("armor", 0)),
			int(entry.get("weapon", 0)),
			int(entry.get("speed", 0)),
		))
	if Defs.roster_cost(loaded) > _budget():
		hud.toast("That preset costs more than the budget.")
		return
	if Defs.count_kind(loaded, "cargo") > 4:
		return
	formation = loaded
	camo = str(cfg.get_value(preset_name, "camo", camo))
	convoy_name = str(cfg.get_value(preset_name, "convoy", convoy_name))
	selected_i = -1
	_refresh_build()
	hud.toast("Loaded %s." % preset_name)


func _on_preset_delete(preset_name: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PRESET_PATH) != OK:
		return
	var names: Array = []
	for preset in _preset_names():
		if str(preset) != preset_name:
			names.append(preset)
	cfg.set_value("presets", "names", names)
	cfg.erase_section(preset_name)
	cfg.save(PRESET_PATH)
	_refresh_build()


func _preset_names() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(PRESET_PATH) != OK:
		return []
	var names: Variant = cfg.get_value("presets", "names", [])
	var out: Array = []
	if names is Array or names is PackedStringArray:
		for preset_name in names:
			out.append(str(preset_name))
	return out


func _on_deploy() -> void:
	if phase != Phase.BUILD:
		return
	var roster := _packed_roster()
	if Defs.count_kind(roster, "cargo") < 1:
		hud.toast("Bring at least one cargo truck.")
		return
	column_cost = Defs.roster_cost(roster)
	if column_cost > _budget():
		hud.toast("Over budget.")
		return
	_start_drive(roster)


func _start_drive(roster: Array) -> void:
	phase = Phase.DRIVE
	mission_resolved = false
	mission_level = sandbox_map if sandbox else level_index
	sim_acc = 0.0
	var level: Dictionary = _active_level()
	sim = SimScript.new()
	world.meshes.scheme = camo
	sim.start(level, roster, route, int(level["seed"]) + 100 + attempt * 17)
	sim.sandbox = sandbox
	sim.god_mode = sandbox_god
	sim.threat = sandbox_threat
	world.begin_drive()
	audio.set_music("music_drive")
	hud.show_drive(sandbox)
	hud.show_banner("Sandbox rolling." if sandbox else "Convoy rolling. Stay with the cargo.")
	world.sync(sim, 0.016)


func _advance(dt: float) -> void:
	if sim == null or sim.status != "running":
		return
	var speed := sandbox_speed if sandbox else 1.0
	sim_acc += minf(dt, 0.1) * speed
	var cap := 10 if sandbox else 5
	var steps := 0
	while sim_acc >= 1.0 / 60.0 and steps < cap and sim.status == "running":
		sim.tick(1.0 / 60.0)
		_drain()
		sim_acc -= 1.0 / 60.0
		steps += 1


func _drain() -> void:
	var finished := ""
	for ev in sim.events:
		audio.on_event(ev)
		world.on_event(ev)
		if str(ev.get("type", "")) == "banner":
			hud.show_banner(str(ev["text"]))
		elif str(ev.get("type", "")) == "finished":
			finished = str(ev["status"])
	sim.events.clear()
	if finished != "" and not mission_resolved:
		mission_resolved = true
		_finish(finished)


func _drive_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			_on_ability("smoke")
		KEY_E:
			_on_ability("airstrike")
		KEY_R:
			_on_ability("repair")


func _on_ability(ability: String) -> void:
	if phase != Phase.DRIVE or sim == null or sim.status != "running":
		return
	var hint := str(sim.ability_hint(ability))
	if hint != "":
		hud.toast(hint)
		return
	sim.try_ability(ability)
	_drain()


func _camera_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if hud.hovering_ui():
			return
		world.yaw -= event.relative.x * 0.005
		world.pitch = clampf(world.pitch + event.relative.y * 0.004, 0.18, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.dist = clampf(world.dist - 1.8, 14.0, 60.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.dist = clampf(world.dist + 1.8, 14.0, 60.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				world.reset_camera()
			KEY_A:
				world.yaw -= 0.14
			KEY_D:
				world.yaw += 0.14
			KEY_W:
				world.dist = clampf(world.dist - 2.0, 14.0, 60.0)
			KEY_S:
				world.dist = clampf(world.dist + 2.0, 14.0, 60.0)


func _on_escape() -> void:
	match phase:
		Phase.DRIVE:
			phase = Phase.PAUSE
			hud.show_pause()
		Phase.PAUSE:
			_on_resume()
		Phase.BUILD, Phase.BRIEF, Phase.HELP, Phase.SANDBOX:
			_on_back()
		Phase.RESULTS:
			pass
		_:
			get_tree().quit()


func _on_resume() -> void:
	if phase != Phase.PAUSE:
		return
	phase = Phase.DRIVE
	hud.hide_pause()


func _finish(status: String) -> void:
	var won := status == "won"
	if sandbox:
		var sand: Dictionary = _active_level()
		phase = Phase.RESULTS
		audio.set_music("music_menu")
		hud.show_results({
			"won": won,
			"grade": Defs.grade(won, sim.delivered, sim.cargo_total, sim.escorts_lost),
			"level_name": sand["name"],
			"delivered": sim.delivered,
			"cargo_total": sim.cargo_total,
			"kills": sim.kills,
			"escorts_lost": sim.escorts_lost,
			"time": sim.time,
			"pay": {"cost": 0, "salvage": 0, "base": 0, "cargo": 0, "kills": 0, "net": 0},
			"bank": bank,
			"last": false,
			"sandbox": true,
		})
		return
	var level: Dictionary = Defs.levels()[level_index]
	var pay := Defs.payout(level, sim.delivered, sim.kills, column_cost) if won else {
		"cost": column_cost, "salvage": 0, "base": 0, "cargo": 0, "kills": 0, "net": 0,
	}
	if won:
		bank += int(pay["net"])
	var grade := Defs.grade(won, sim.delivered, sim.cargo_total, sim.escorts_lost)
	var last := won and mission_level >= Defs.levels().size() - 1
	if won and not last:
		level_index = mission_level + 1
		attempt = 0
	elif last:
		campaign_done = true
	_save()
	phase = Phase.RESULTS
	audio.set_music("music_menu")
	hud.show_results({
		"won": won,
		"grade": grade,
		"level_name": level["name"],
		"delivered": sim.delivered,
		"cargo_total": sim.cargo_total,
		"kills": sim.kills,
		"escorts_lost": sim.escorts_lost,
		"time": sim.time,
		"pay": pay,
		"bank": bank,
		"last": last,
	})


func _on_next() -> void:
	if campaign_done or level_index >= Defs.levels().size():
		_enter_menu()
		return
	_open_brief()


func _on_retry() -> void:
	if sandbox:
		_restart_sandbox_drive()
		return
	level_index = mission_level
	campaign_done = false
	attempt += 1
	_save()
	_open_brief()
	_on_arm()
	_on_quick()


func _on_menu() -> void:
	sim = null
	if sandbox:
		_leave_sandbox()
		return
	_enter_menu()


func _restart_sandbox_drive() -> void:
	if not sandbox or route == null or sandbox_level.is_empty():
		return
	mission_resolved = false
	sim_acc = 0.0
	world.clear_actors()
	var level: Dictionary = sandbox_level
	sim = SimScript.new()
	sim.start(level, _packed_roster(), route, int(level["seed"]) + 100)
	sim.sandbox = true
	sim.god_mode = sandbox_god
	sim.threat = sandbox_threat
	phase = Phase.DRIVE
	world.begin_drive()
	audio.set_music("music_drive")
	hud.show_drive(true)
	hud.show_banner("Drive restarted.")
	world.sync(sim, 0.016)


func _on_sandbox_god(on: bool) -> void:
	sandbox_god = on
	if sim != null:
		sim.god_mode = on


func _on_sandbox_speed(speed: float) -> void:
	sandbox_speed = clampf(speed, 0.25, 3.0)


func _on_sandbox_threat(scale: float) -> void:
	sandbox_threat = clampf(scale, 0.5, 2.5)
	if sim != null:
		sim.threat = sandbox_threat


func _sandbox_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if hud.hovering_ui() or sim == null or sim.status != "running":
		return
	var hit: Dictionary = world.pick_ground(click.position)
	if not bool(hit["ok"]):
		return
	var kind: String = hud.spawn_kind()
	var pos: Vector3 = hit["pos"]
	if sim.spawn_at(kind, pos):
		_drain()


func _packed_roster() -> Array:
	return formation.duplicate()


func _living_heli() -> bool:
	if sim == null:
		return false
	for e in sim.enemies:
		if e["alive"] and e["air"]:
			return true
	return false


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "bank", bank)
	cfg.set_value("campaign", "level", level_index)
	cfg.set_value("campaign", "done", campaign_done)
	cfg.save(SAVE_PATH)


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	bank = int(cfg.get_value("campaign", "bank", START_BANK))
	level_index = int(cfg.get_value("campaign", "level", 0))
	campaign_done = bool(cfg.get_value("campaign", "done", false))
	level_index = clampi(level_index, 0, Defs.levels().size() - 1)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for a in args:
		if str(a).begins_with("--shots="):
			shot_dir = str(a).trim_prefix("--shots=")
		elif str(a).begins_with("--catalog="):
			catalog_dir = str(a).trim_prefix("--catalog=")
		elif str(a).begins_with("--lands="):
			lands_dir = str(a).trim_prefix("--lands=")
		elif str(a).begins_with("--sandboxshot="):
			sandbox_shot = str(a).trim_prefix("--sandboxshot=")


func _has_arg(flag: String) -> bool:
	if flag in OS.get_cmdline_user_args():
		return true
	return flag in OS.get_cmdline_args()


func _shot_run() -> void:
	for _i in 25:
		await get_tree().process_frame
	await _capture("01_menu")
	_on_play()
	for _i in 8:
		await get_tree().process_frame
	await _capture("02_briefing")
	_on_arm()
	_on_quick()
	for _i in 10:
		await get_tree().process_frame
	await _capture("03_build")
	_on_deploy()
	var guard := 0
	while sim != null and sim.status == "running" and sim.living_hostiles() == 0 and guard < 4000:
		sim.tick(1.0 / 30.0)
		_drain()
		guard += 1
	for _i in 45:
		if sim.status != "running":
			break
		sim.tick(1.0 / 30.0)
		_drain()
	world.sync(sim, 0.016)
	for _i in 8:
		await get_tree().process_frame
	await _capture("04_combat")
	guard = 0
	while sim != null and sim.status == "running" and guard < 8000:
		var Autopilot = preload("res://scripts/autopilot.gd")
		Autopilot.consider(sim)
		sim.tick(1.0 / 30.0)
		_drain()
		guard += 1
	if sim != null:
		world.sync(sim, 0.016)
	for _i in 10:
		await get_tree().process_frame
	await _capture("05_result")
	get_tree().quit(0)


func _sandbox_shot_run() -> void:
	for _i in 6:
		await get_tree().process_frame
	_on_sandbox()
	for _i in 8:
		await get_tree().process_frame
	await _capture_to(sandbox_shot, "sandbox_setup")
	_on_sandbox_arm()
	formation = Defs.recommended(sandbox_map, _budget())
	_refresh_build()
	for _i in 6:
		await get_tree().process_frame
	await _capture_to(sandbox_shot, "sandbox_build")
	_start_drive(_packed_roster())
	for _i in 4:
		await get_tree().process_frame
	var hit: Dictionary = world.pick_ground(Vector2(780, 430))
	if bool(hit.get("ok", false)):
		var spot: Vector3 = hit["pos"]
		sim.spawn_at(hud.spawn_kind(), spot)
		world.sync(sim, 0.016)
	for _i in 6:
		await get_tree().process_frame
	await _capture_to(sandbox_shot, "sandbox_drive")
	get_tree().quit(0)


func _lands_run() -> void:
	hud.root.visible = false
	for _i in 4:
		await get_tree().process_frame
	for level in Defs.levels():
		var built = RouteScript.new(level)
		route = built
		world.show_level(level, built)
		for body in world.slot_bodies:
			body.visible = false
		var dist := 220.0
		if float(built.total) < 280.0:
			dist = float(built.total) * 0.45
		var camo := Defs.camo_for_biome(str(level["biome"]))
		var parade := ["tank", "humvee", "cargo"]
		for i in parade.size():
			var unit: Node3D = world.meshes.build(str(parade[i]), false, camo)
			world.unit_root.add_child(unit)
			var along := dist - float(i) * 9.0
			var pose: Dictionary = built.sample(along)
			var spot: Vector3 = pose["pos"]
			spot.y = world.road_height(along) + 0.05
			unit.position = spot
			var face: Vector3 = pose["dir"]
			world._face_along(unit, face, world._grade_pitch(along))
		var sm: Dictionary = built.sample(dist)
		world.camera_mode = "drive"
		world.yaw = 0.42
		world.pitch = 0.4
		world.dist = 36.0
		world.cam_ready = false
		world.focus = sm["pos"]
		world.focus.y = world.road_height(dist)
		world.travel_dir = sm["dir"]
		for _j in 8:
			world.tick(0.05)
			await get_tree().process_frame
		await _capture_to(lands_dir, "land_%s" % str(level["biome"]))
	get_tree().quit(0)


func _catalog_run() -> void:
	for _i in 4:
		await get_tree().process_frame
	world.meshes.scheme = "desert"
	if world.menu_root:
		world.menu_root.visible = false
	var stage := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 14.0
	disc.bottom_radius = 14.0
	disc.height = 0.3
	stage.mesh = disc
	stage.position = Vector3(0, -0.16, 0)
	stage.material_override = world.meshes.mat(Color(0.45, 0.36, 0.22))
	world.add_child(stage)
	var kinds: Array = ["cargo", "humvee", "apc", "tank", "aa", "repair", "technical", "infantry", "rpg", "heli"]
	for kind in kinds:
		var enemy: bool = kind == "technical" or kind == "infantry" or kind == "rpg" or kind == "heli"
		var node: Node3D = world.meshes.build(str(kind), enemy, "desert" if not enemy else "")
		world.add_child(node)
		node.position = Vector3(0, 0.0 if kind != "heli" else 1.4, 0)
		node.rotation_degrees = Vector3(0, 28, 0)
		var focus := Vector3(0, 1.15, 0)
		var dist := 7.5
		if kind == "infantry" or kind == "rpg":
			dist = 3.4
			focus = Vector3(0, 1.0, 0)
		elif kind == "heli":
			dist = 8.5
			focus = Vector3(0, 1.6, 0)
		elif kind == "tank":
			dist = 8.2
		world.cam.global_position = focus + Vector3(dist * 0.72, dist * 0.38, dist * 0.62)
		world.cam.look_at(focus, Vector3.UP)
		for _j in 2:
			await get_tree().process_frame
		await _capture_to(catalog_dir, "unit_%s" % kind)
		node.queue_free()
		for _j in 2:
			await get_tree().process_frame
	get_tree().quit(0)


func _capture_to(dir_path: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := dir_path.trim_suffix("/") + "/" + name + ".png"
	image.save_png(path)
	print("SHOT ", path)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := shot_dir.trim_suffix("/") + "/" + name + ".png"
	image.save_png(path)
	print("SHOT ", path)
