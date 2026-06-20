extends Node
## Audio manager with volume controls. Registered as autoload in project.godot.
## Uses the default Master bus — custom buses created in code don't work on web.
## Volume is set directly on each AudioStreamPlayer.

const SFX_POOL_SIZE = 8
const SETTINGS_PATH = "user://settings.cfg"

var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var _current_music_path: String = ""

var music_volume: float = 0.8
var sfx_volume: float = 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)

	for i in SFX_POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_pool.append(player)

	_apply_volumes()

func play_music(track_name: String):
	var path = "res://assets/sounds/music/%s" % track_name
	if path == _current_music_path and music_player.playing:
		return
	var stream = _load_audio(path)
	if stream:
		_current_music_path = path
		music_player.stream = stream
		music_player.volume_db = linear_to_db(music_volume) if music_volume > 0.0 else -80.0
		music_player.play()

func stop_music():
	music_player.stop()
	_current_music_path = ""

func _on_music_finished():
	if _current_music_path != "":
		music_player.play()

func play_sfx(sfx_name: String):
	var stream = _load_audio("res://assets/sounds/sfx/%s" % sfx_name)
	if stream:
		var player = _get_free_player()
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0
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
	music_player.volume_db = linear_to_db(music_volume) if music_volume > 0.0 else -80.0
	for player in sfx_pool:
		player.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0

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
