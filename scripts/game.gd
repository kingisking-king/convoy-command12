extends Node

const Defs = preload("res://scripts/defs.gd")
const RouteScript = preload("res://scripts/route.gd")
const SimScript = preload("res://scripts/battle_sim.gd")
const Checks = preload("res://scripts/sim_checks.gd")
const WorldScript = preload("res://scripts/world_view.gd")
const HudScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio_fx.gd")

enum Phase { MENU, HELP, BRIEF, BUILD, DRIVE, PAUSE, RESULTS }

const SAVE_PATH := "user://campaign.cfg"
const START_BANK := 500

var phase: int = Phase.MENU
var bank := START_BANK
var level_index := 0
var campaign_done := false
var slots: Array = []
var selected_kind := "humvee"
var route = null
var sim = null
var column_cost := 0
var attempt := 0
var mission_level := 0
var world
var hud
var audio
var shot_dir := ""
var manual_sim := false
var mission_resolved := false
var sim_acc := 0.0
var show_fps := false
var fps_label: Label
var return_phase: int = Phase.MENU

func _ready() -> void:
	_blank_slots()
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
	if phase == Phase.BUILD:
		if not hud.hovering_ui():
			world.set_hover(world.pick_slot(get_viewport().get_mouse_position()))
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
	if phase == Phase.BUILD:
		_open_brief()
		return
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
	_blank_slots()
	selected_kind = "humvee"
	_refresh_build()


func _refresh_build() -> void:
	var level: Dictionary = Defs.levels()[level_index]
	hud.show_build(level, bank, slots, selected_kind, route)
	world.show_column(slots)


func _on_unit_selected(kind: String) -> void:
	selected_kind = kind
	_refresh_build()


func _on_quick() -> void:
	var roster: Array = Defs.recommended(level_index, bank)
	_blank_slots()
	for i in roster.size():
		if i < slots.size():
			slots[i] = roster[i]
	audio.play("ui_place", -4.0)
	_refresh_build()
	hud.toast("Suggested column loaded. Edit it, then deploy.")


func _build_input(event: InputEvent) -> void:
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
			KEY_ENTER, KEY_KP_ENTER:
				_on_deploy()
				return
		if idx >= 0 and idx < Defs.CARD_ORDER.size():
			_on_unit_selected(Defs.CARD_ORDER[idx])
		return
	if event is InputEventMouseButton and event.pressed:
		if hud.hovering_ui():
			return
		var slot: int = world.pick_slot((event as InputEventMouseButton).position)
		if slot < 0:
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if str(slots[slot]) != "":
				slots[slot] = ""
				audio.play("ui_click", -6.0, 0.8)
				_refresh_build()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if selected_kind == "":
			hud.toast("Pick a unit first.")
			return
		var trial: Array = slots.duplicate()
		trial[slot] = selected_kind
		if Defs.roster_cost(trial) > bank:
			hud.toast("Not enough budget.")
			return
		slots[slot] = selected_kind
		audio.play("ui_place", -3.0)
		_refresh_build()


func _on_deploy() -> void:
	if phase != Phase.BUILD:
		return
	var roster := _packed_roster()
	if Defs.count_kind(roster, "cargo") < 1:
		hud.toast("Bring at least one cargo truck.")
		return
	column_cost = Defs.roster_cost(roster)
	if column_cost > bank:
		hud.toast("Over budget.")
		return
	_start_drive(roster)


func _start_drive(roster: Array) -> void:
	phase = Phase.DRIVE
	mission_resolved = false
	mission_level = level_index
	sim_acc = 0.0
	var level: Dictionary = Defs.levels()[level_index]
	sim = SimScript.new()
	sim.start(level, roster, route, int(level["seed"]) + 100 + attempt * 17)
	world.begin_drive()
	audio.set_music("music_drive")
	hud.show_drive()
	hud.show_banner("Convoy rolling. Stay with the cargo.")
	world.sync(sim, 0.016)


func _advance(dt: float) -> void:
	if sim == null or sim.status != "running":
		return
	sim_acc += minf(dt, 0.1)
	var steps := 0
	while sim_acc >= 1.0 / 60.0 and steps < 5 and sim.status == "running":
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
		Phase.BUILD, Phase.BRIEF, Phase.HELP:
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
	level_index = mission_level
	campaign_done = false
	attempt += 1
	_save()
	_open_brief()
	_on_arm()
	_on_quick()


func _on_menu() -> void:
	sim = null
	_enter_menu()


func _packed_roster() -> Array:
	var roster: Array = []
	for entry in slots:
		if str(entry) != "":
			roster.append(entry)
	return roster


func _blank_slots() -> void:
	slots.clear()
	for _i in Defs.MAX_SLOTS:
		slots.append("")


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


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := shot_dir.trim_suffix("/") + "/" + name + ".png"
	image.save_png(path)
	print("SHOT ", path)
