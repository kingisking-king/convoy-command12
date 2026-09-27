extends Node

var streams := {}
var pool: Array = []
var pool_i := 0
var music: AudioStreamPlayer
var engine: AudioStreamPlayer
var heli: AudioStreamPlayer
var current_music := ""
var last_ms := {}
var rng := RandomNumberGenerator.new()

func setup() -> void:
	rng.randomize()
	var names := [
		"ui_click", "ui_place", "gun_light", "gun_heavy", "gun_aa",
		"explosion", "ambush", "win", "lose", "repair", "smoke",
		"whistle", "heli", "engine", "music_menu", "music_drive", "death",
	]
	for n in names:
		var path := "res://assets/sfx/%s.wav" % n
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream is AudioStreamWAV and (n == "engine" or n == "heli" or n.begins_with("music_")):
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		streams[n] = stream
	for i in 18:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -18.0
	add_child(music)
	engine = AudioStreamPlayer.new()
	engine.volume_db = -14.0
	add_child(engine)
	heli = AudioStreamPlayer.new()
	heli.volume_db = -10.0
	add_child(heli)
	if streams.has("engine"):
		engine.stream = streams["engine"]
	if streams.has("heli"):
		heli.stream = streams["heli"]


func play(name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	var gap := 0
	if name == "gun_aa":
		gap = 55
	elif name == "gun_light":
		gap = 35
	elif name == "gun_heavy":
		gap = 90
	elif name == "explosion":
		gap = 60
	elif name == "death":
		gap = 70
	if gap > 0 and now - int(last_ms.get(name, 0)) < gap:
		return
	last_ms[name] = now
	var player: AudioStreamPlayer = pool[pool_i % pool.size()]
	pool_i += 1
	player.stream = streams[name]
	player.volume_db = vol_db
	player.pitch_scale = pitch
	player.play()


func play_varied(name: String, vol_db: float = 0.0) -> void:
	play(name, vol_db, rng.randf_range(0.94, 1.06))


func set_music(which: String) -> void:
	if which == current_music:
		return
	current_music = which
	if which == "" or not streams.has(which):
		music.stop()
		return
	music.stream = streams[which]
	music.play()


func set_engine(on: bool) -> void:
	if on and not engine.playing and engine.stream != null:
		engine.play()
	elif not on and engine.playing:
		engine.stop()


func set_heli(on: bool) -> void:
	if on and not heli.playing and heli.stream != null:
		heli.play()
	elif not on and heli.playing:
		heli.stop()


func toggle_mute() -> bool:
	var bus := AudioServer.get_bus_index("Master")
	var muted := not AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, muted)
	return muted


func on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"tracer":
			var profile := str(ev.get("profile", "light"))
			if profile == "heavy":
				play_varied("gun_heavy", -2.0)
			elif profile == "aa":
				play_varied("gun_aa", -6.0)
			else:
				play_varied("gun_light", -4.0)
		"boom":
			play_varied("explosion", -1.0)
		"dead":
			if str(ev.get("kind", "")) == "tank" or str(ev.get("kind", "")) == "heli" or str(ev.get("role", "")) == "cargo":
				play("explosion", -3.0)
			else:
				play_varied("death", -6.0)
		"banner":
			play("ambush", -4.0)
		"ability":
			var ability := str(ev.get("name", ""))
			if ability == "smoke":
				play("smoke", -2.0)
			elif ability == "repair":
				play("repair", -2.0)
			elif ability == "airstrike":
				play("whistle", -4.0)
		"delivered":
			play("ui_place", -6.0, 1.25)
		"finished":
			if str(ev.get("status", "")) == "won":
				play("win", -2.0)
			else:
				play("lose", -2.0)
