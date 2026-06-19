extends Node2D
## Bottom viewport: top-down scrolling track with 3 lanes.
## Input is forwarded from the SubViewportContainer.

const LANE_COUNT: int = 3
const LANE_WIDTH: float = 80.0

var current_lane: int = 1
var target_x: float = 0.0
var lane_positions: Array[float] = []
var scroll_offset: float = 0.0
var scroll_speed: float = 120.0

var wants_to_switch: int = 0

# Obstacles
var obstacles: Array[Node2D] = []
var obstacle_timer: float = 0.0
var obstacle_spawn_interval: float = 1.2
var obstacle_scene: PackedScene

# Swipe detection
var swipe_start: Vector2 = Vector2.ZERO
var minimum_drag: float = 20.0

# Visuals
var train_node: Node2D
var lanes_initialized: bool = false

# Bullets
var bullets: Array[Node2D] = []
var bullet_speed: float = 300.0
var shoot_cooldown: float = 0.0
var shoot_rate: float = 0.3
var is_holding_shoot: bool = false

func _ready():
	obstacle_scene = preload("res://scenes/obstacle.tscn")
	train_node = Node2D.new()
	train_node.name = "Train"
	add_child(train_node)

func set_scroll_speed(speed: float):
	scroll_speed = speed

func _ensure_lanes():
	var vs = get_viewport_rect().size
	if vs.x < 10 or vs.y < 10:
		return
	if lanes_initialized:
		return
	lanes_initialized = true
	lane_positions.clear()
	var total_width = LANE_COUNT * LANE_WIDTH
	var start_x = (vs.x - total_width) / 2.0 + LANE_WIDTH / 2.0
	for i in range(LANE_COUNT):
		lane_positions.append(start_x + i * LANE_WIDTH)
	target_x = lane_positions[current_lane]
	train_node.position = Vector2(target_x, vs.y * 0.75)

func switch_lane(direction: int):
	var new_lane = current_lane + direction
	if new_lane >= 0 and new_lane < LANE_COUNT:
		current_lane = new_lane
		target_x = lane_positions[current_lane]
		AudioManager.play_sfx("lane_switch")

# --- Input handling (forwarded from SubViewportContainer) ---

func _input(event):
	if not GameManager.is_playing:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
			is_holding_shoot = true
		else:
			is_holding_shoot = false
			var swipe_dir = event.position - swipe_start
			if swipe_dir.length() > minimum_drag:
				if abs(swipe_dir.x) > abs(swipe_dir.y):
					switch_lane(1 if swipe_dir.x > 0 else -1)
	elif event is InputEventMouseButton:
		if event.pressed:
			swipe_start = event.position
			is_holding_shoot = true
		else:
			is_holding_shoot = false
			var swipe_dir = event.position - swipe_start
			if swipe_dir.length() > minimum_drag:
				if abs(swipe_dir.x) > abs(swipe_dir.y):
					switch_lane(1 if swipe_dir.x > 0 else -1)
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE:
			is_holding_shoot = event.pressed
		elif event.keycode == KEY_LEFT:
			switch_lane(-1)
		elif event.keycode == KEY_RIGHT:
			switch_lane(1)

func _process(delta: float):
	if not GameManager.is_playing:
		return

	_ensure_lanes()
	if lane_positions.is_empty():
		return

	var vs = get_viewport_rect().size
	scroll_offset += scroll_speed * delta

	# Smooth lane movement
	var diff = target_x - train_node.position.x
	if abs(diff) > 1.0:
		train_node.position.x += diff * 10.0 * delta
	else:
		train_node.position.x = target_x

	# Shoot bullets when holding fire
	if shoot_cooldown > 0:
		shoot_cooldown -= delta
	if is_holding_shoot and shoot_cooldown <= 0:
		_shoot()
		shoot_cooldown = shoot_rate

	# Update bullets
	_update_bullets(delta, vs)

	# Update obstacles
	_update_obstacles(delta, vs)

	# Spawn obstacles
	obstacle_timer += delta
	if obstacle_timer >= obstacle_spawn_interval:
		obstacle_timer = 0.0
		_spawn_obstacle()

	# Check collisions
	_check_collisions()

	# Bullet-obstacle collisions
	_bullet_obstacle_collisions()

	queue_redraw()

# --- Bullet management ---

func _shoot():
	var bullet = Node2D.new()
	bullet.name = "Bullet"
	bullet.position = Vector2(train_node.position.x, train_node.position.y - 20.0)
	bullet.set_meta("velocity", Vector2(0, -bullet_speed))
	add_child(bullet)
	bullets.append(bullet)
	AudioManager.play_sfx("shoot")

func _update_bullets(delta: float, vs: Vector2):
	var to_remove: Array[Node2D] = []
	for b in bullets:
		var vel: Vector2 = b.get_meta("velocity", Vector2(0, -bullet_speed))
		b.position += vel * delta
		# Remove bullet when it reaches the top of the viewport
		if b.position.y < -10:
			to_remove.append(b)
	for b in to_remove:
		bullets.erase(b)
		b.queue_free()

func _bullet_obstacle_collisions():
	var bullets_to_remove: Array[Node2D] = []
	var obstacles_to_remove: Array[Node2D] = []

	for b in bullets:
		for obs in obstacles:
			if b.position.distance_to(obs.position) < 20.0:
				bullets_to_remove.append(b)
				obstacles_to_remove.append(obs)
				GameManager.add_score(5)
				AudioManager.play_sfx("enemy_hit")
				break

	for b in bullets_to_remove:
		if b in bullets:
			bullets.erase(b)
			b.queue_free()
	for obs in obstacles_to_remove:
		if obs in obstacles:
			obstacles.erase(obs)
			obs.queue_free()

func _update_obstacles(delta: float, vs: Vector2):
	var to_remove: Array[Node2D] = []
	for obs in obstacles:
		obs.position.y += scroll_speed * delta
		if obs.position.y > vs.y + 50:
			to_remove.append(obs)
			GameManager.add_score(1)
	for obs in to_remove:
		obstacles.erase(obs)
		obs.queue_free()

func _spawn_obstacle():
	var obs = obstacle_scene.instantiate()
	var lane = randi() % LANE_COUNT
	obs.position = Vector2(lane_positions[lane], -40.0)
	add_child(obs)
	obstacles.append(obs)

func _check_collisions():
	var train_pos = train_node.position
	for obs in obstacles:
		if obs.position.distance_to(train_pos) < 25.0:
			GameManager.take_damage(20.0)
			obstacles.erase(obs)
			obs.queue_free()
			AudioManager.play_sfx("crash")
			break

func _draw():
	var vs = get_viewport_rect().size
	var w = vs.x
	var h = vs.y

	if w < 10 or h < 10:
		return

	# Background
	draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.12, 0.08))

	if lane_positions.is_empty():
		return

	# Track area
	var track_left = lane_positions[0] - LANE_WIDTH / 2.0
	var track_right = lane_positions[LANE_COUNT - 1] + LANE_WIDTH / 2.0
	draw_rect(Rect2(track_left, 0, track_right - track_left, h), Color(0.15, 0.18, 0.12))

	# Lane dividers (dashed, animated)
	for i in range(1, LANE_COUNT):
		var lx = (lane_positions[i - 1] + lane_positions[i]) / 2.0
		var y = fmod(scroll_offset, 30.0)
		while y < h:
			draw_rect(Rect2(lx - 1, y, 2, 15), Color(0.3, 0.35, 0.25))
			y += 30.0

	# Track borders
	draw_rect(Rect2(track_left - 2, 0, 2, h), Color(0.4, 0.35, 0.2))
	draw_rect(Rect2(track_right, 0, 2, h), Color(0.4, 0.35, 0.2))

	# Bullets
	for b in bullets:
		# Glow
		draw_rect(Rect2(b.position.x - 4, b.position.y - 8, 8, 16), Color(1.0, 0.9, 0.2, 0.25))
		# Core
		draw_rect(Rect2(b.position.x - 2, b.position.y - 5, 4, 10), Color(1.0, 1.0, 0.4))
		# Bright center
		draw_rect(Rect2(b.position.x - 1, b.position.y - 4, 2, 8), Color(1.0, 1.0, 0.9))

	# Train
	var tx = train_node.position.x
	var ty = train_node.position.y
	draw_rect(Rect2(tx - 15, ty - 20, 30, 40), Color(0.2, 0.5, 0.8))
	draw_rect(Rect2(tx - 12, ty - 25, 24, 8), Color(0.3, 0.6, 0.9))
	draw_rect(Rect2(tx - 3, ty - 28, 6, 4), Color(1.0, 1.0, 0.6))
	draw_rect(Rect2(tx - 16, ty - 16, 5, 10), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(tx + 11, ty - 16, 5, 10), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(tx - 16, ty + 8, 5, 10), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(tx + 11, ty + 8, 5, 10), Color(0.15, 0.15, 0.15))

	# Obstacles
	for obs in obstacles:
		draw_rect(Rect2(obs.position.x - 12, obs.position.y - 12, 24, 24), Color(0.8, 0.2, 0.1))
		draw_line(Vector2(obs.position.x - 8, obs.position.y - 8), Vector2(obs.position.x + 8, obs.position.y + 8), Color(1, 1, 0.3), 2.0)
		draw_line(Vector2(obs.position.x + 8, obs.position.y - 8), Vector2(obs.position.x - 8, obs.position.y + 8), Color(1, 1, 0.3), 2.0)
