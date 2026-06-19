extends Node
## Audio manager with volume controls. Registered as autoload in project.godot.

const SFX_POOL_SIZE = 8
const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"
const SETTINGS_PATH = "user://settings.cfg"

var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var _current_music_path: String = ""

var music_volume: float = 0.8
var sfx_volume: float = 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_setup_buses()

	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)

	for i in SFX_POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_pool.append(player)

	_apply_volumes()

func _setup_buses():
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, MUSIC_BUS)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, "Master")

func play_music(track_name: String):
	var path = "res://assets/audio/music/%s" % track_name
	if path == _current_music_path and music_player.playing:
		return
	var stream = _load_audio(path)
	if stream:
		_current_music_path = path
		music_player.stream = stream
		music_player.play()

func stop_music():
	music_player.stop()
	_current_music_path = ""

func _on_music_finished():
	if _current_music_path != "":
		music_player.play()

func play_sfx(sfx_name: String):
	var stream = _load_audio("res://assets/audio/sfx/%s" % sfx_name)
	if stream:
		var player = _get_free_player()
		player.stream = stream
		player.play()

func _load_audio(base_path: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path = "%s.%s" % [base_path, ext]
		var stream = load(path)
		if stream:
			return stream
	return null

func _get_free_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	return sfx_pool[0]

func set_music_volume(value: float):
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_sfx_volume(value: float):
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func _apply_volumes():
	var music_idx = AudioServer.get_bus_index(MUSIC_BUS)
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume) if music_volume > 0.0 else -80.0)
		AudioServer.set_bus_mute(music_idx, music_volume <= 0.0)
	var sfx_idx = AudioServer.get_bus_index(SFX_BUS)
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0)
		AudioServer.set_bus_mute(sfx_idx, sfx_volume <= 0.0)

func _save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)

func _load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
