extends Control
## Leaderboard screen — shows top 15 scores with date, score, and distance.

@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var entry_container: VBoxContainer = %EntryContainer
@onready var empty_label: Label = %EmptyLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	title_label.text = "LEADERBOARD"
	_build_entries()

func _build_entries():
	# Clear any existing children
	for child in entry_container.get_children():
		child.queue_free()

	var entries = LeaderboardManager.get_entries()
	if entries.is_empty():
		empty_label.visible = true
		return

	empty_label.visible = false

	# Header row
	var header = _make_row("#", "SCORE", "DIST", "DATE", Color(0.6, 0.6, 0.6))
	entry_container.add_child(header)

	var rank = 1
	for entry in entries:
		var score: int = entry.get("score", 0)
		var dist: int = entry.get("distance", 0)
		var date: String = entry.get("date", "???")
		var row = _make_row(str(rank), str(score), "%dm" % dist, date, Color.WHITE)
		entry_container.add_child(row)
		rank += 1

func _make_row(rank: String, score: String, dist: String, date: String, color: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 18)

	var rank_label = _make_label(rank, 30, color, 0)
	var score_label = _make_label(score, 70, color, 0)
	var dist_label = _make_label(dist, 50, color, 0)
	var date_label = _make_label(date, 140, color, 0)

	row.add_child(rank_label)
	row.add_child(score_label)
	row.add_child(dist_label)
	row.add_child(date_label)
	return row

func _make_label(text: String, width: float, color: Color, align: int) -> Label:
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_font_override("font", load("res://assets/fonts/PressStart2P-Regular.ttf"))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	return label

func _on_back_pressed():
	AudioManager.play_sfx("menu_click")
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
