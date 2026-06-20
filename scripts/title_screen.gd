extends Control
## Title screen with start button and settings access.

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	_update_labels()
	AudioManager.play_music("music_menu")

func _update_labels():
	title_label.text = "KILLER XPRESS"
	subtitle_label.text = "Defend the train. Destroy the aliens."
	var dt = Time.get_datetime_dict_from_system()
	version_label.text = "v.0.1.%04d%02d%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func _on_start_pressed():
	AudioManager.play_sfx("menu_click")
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed():
	AudioManager.play_sfx("menu_click")
	get_tree().change_scene_to_file("res://scenes/settings_screen.tscn")

func _on_leaderboard_pressed():
	AudioManager.play_sfx("menu_click")
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
