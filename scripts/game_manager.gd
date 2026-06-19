extends Node
## Global game state manager. Registered as autoload in project.godot.

signal score_changed(new_score: int)
signal health_changed(new_health: float)
signal game_over
signal game_started
signal speed_changed(new_speed: float)

var score: int = 0
var health: float = 100.0
var max_health: float = 100.0
var game_speed: float = 120.0
var base_speed: float = 120.0
var is_playing: bool = false
var distance: float = 0.0
var player_lane: int = 1

# Difficulty scaling
var speed_increase_rate: float = 2.0
var max_speed: float = 280.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_game():
	score = 0
	health = max_health
	game_speed = base_speed
	distance = 0.0
	is_playing = true
	score_changed.emit(score)
	health_changed.emit(health)
	speed_changed.emit(game_speed)
	game_started.emit()

func add_score(points: int):
	score += points
	score_changed.emit(score)

func take_damage(amount: float):
	if not is_playing:
		return
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		health = 0
		health_changed.emit(health)
		_game_over()

func heal(amount: float):
	health = min(health + amount, max_health)
	health_changed.emit(health)

func update_speed(delta: float):
	if not is_playing:
		return
	distance += game_speed * delta
	game_speed = min(base_speed + (distance / 100.0) * speed_increase_rate, max_speed)
	speed_changed.emit(game_speed)

func _game_over():
	is_playing = false
	game_over.emit()

func get_speed_ratio() -> float:
	return game_speed / base_speed
