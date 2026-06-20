extends Control
## Settings screen with volume sliders and back button.

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_label: Label = %MusicLabel
@onready var sfx_label: Label = %SfxLabel
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	music_slider.value = AudioManager.get_music_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()
	_update_music_label(music_slider.value)
	_update_sfx_label(sfx_slider.value)
	title_label.text = "SETTINGS"

func _on_music_changed(value: float):
	AudioManager.set_music_volume(value)
	_update_music_label(value)

func _on_sfx_changed(value: float):
	AudioManager.set_sfx_volume(value)
	_update_sfx_label(value)
	AudioManager.play_sfx("menu_click")

func _update_music_label(value: float):
	music_label.text = "Music: %d%%" % int(value * 100)

func _update_sfx_label(value: float):
	sfx_label.text = "SFX: %d%%" % int(value * 100)

func _on_back_pressed():
	AudioManager.play_sfx("menu_click")
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
