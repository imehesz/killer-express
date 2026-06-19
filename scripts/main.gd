extends Control
## Main game scene — manages split-screen viewports, HUD, and game flow.
## Both worlds handle their own input via SubViewportContainer forwarding.

@onready var top_viewport: SubViewport = %TopViewport
@onready var bottom_viewport: SubViewport = %BottomViewport
@onready var top_container: SubViewportContainer = %TopContainer
@onready var bottom_container: SubViewportContainer = %BottomContainer
@onready var score_label: Label = %ScoreLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var divider: ColorRect = %Divider

var combat_world: Node2D
var track_world: Node2D

func _ready():
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.game_over.connect(_on_game_over)

	var combat_scene = preload("res://scenes/combat_world.tscn")
	combat_world = combat_scene.instantiate()
	top_viewport.add_child(combat_world)

	var track_scene = preload("res://scenes/track_world.tscn")
	track_world = track_scene.instantiate()
	bottom_viewport.add_child(track_world)

	_on_health_changed(GameManager.health)
	_on_score_changed(GameManager.score)

func _process(delta: float):
	_sync_viewport_sizes()

	if GameManager.is_playing:
		GameManager.update_speed(delta)
		# Push same speed to both worlds on the same frame
		var spd = GameManager.game_speed
		if combat_world:
			combat_world.set_scroll_speed(spd)
		if track_world:
			track_world.set_scroll_speed(spd)

func _sync_viewport_sizes():
	var top_size = top_container.size
	var bot_size = bottom_container.size
	if top_size.x > 10 and top_size.y > 10:
		var target = Vector2i(int(top_size.x), int(top_size.y))
		if top_viewport.size != target:
			top_viewport.size = target
	if bot_size.x > 10 and bot_size.y > 10:
		var target = Vector2i(int(bot_size.x), int(bot_size.y))
		if bottom_viewport.size != target:
			bottom_viewport.size = target

func _on_score_changed(new_score: int):
	score_label.text = "%d" % new_score

func _on_health_changed(new_health: float):
	var ratio = new_health / GameManager.max_health
	health_bar.value = ratio * 100.0
	health_label.text = "%d%%" % int(ratio * 100.0)
	if ratio > 0.6:
		health_bar.modulate = Color(0.2, 0.9, 0.2)
	elif ratio > 0.3:
		health_bar.modulate = Color(0.9, 0.9, 0.2)
	else:
		health_bar.modulate = Color(0.9, 0.2, 0.2)

func _on_game_over():
	AudioManager.play_sfx("game_over")
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
