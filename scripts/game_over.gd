extends Control
## Game over screen showing final score with retry and menu options.

@onready var score_label: Label = %ScoreLabel
@onready var distance_label: Label = %DistanceLabel
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton
@onready var title_label: Label = %TitleLabel

func _ready():
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	title_label.text = "GAME OVER"
	_save_score()
	_show_results()

func _save_score():
	var dist_m = int(GameManager.distance / 10.0)
	LeaderboardManager.add_entry(GameManager.score, dist_m)

func _show_results():
	score_label.text = "Score: %d" % GameManager.score
	var dist_m = int(GameManager.distance / 10.0)
	distance_label.text = "Distance: %dm" % dist_m

func _on_retry_pressed():
	AudioManager.play_sfx("menu_click")
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_menu_pressed():
	AudioManager.play_sfx("menu_click")
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
