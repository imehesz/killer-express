extends Control
## Title screen with start button and settings access.

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	_update_labels()

func _update_labels():
	title_label.text = "KILLER XPRESS"
	subtitle_label.text = "Defend the train. Destroy the aliens."

func _on_start_pressed():
	AudioManager.play_sfx("menu_click")
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed():
	AudioManager.play_sfx("menu_click")
	get_tree().change_scene_to_file("res://scenes/settings_screen.tscn")
