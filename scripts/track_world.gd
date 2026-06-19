extends Node2D
## Bottom viewport: 5-lane monorail with junction-based routing.
## Junctions scroll down — train switches lanes only at junctions.

const LANE_COUNT: int = 5
const LANE_SPACING: float = 44.0  # Narrow monorail spacing
const TRACK_LINE_WIDTH: float = 3.0

var current_lane: int = 2  # Start at center (0-indexed)
var target_x: float = 0.0
var lane_positions: Array[float] = []
var scroll_offset: float = 0.0
var scroll_speed: float = 120.0

# Input buffering — queued direction for next junction
var queued_turn: String = "none"  # "none", "left", "right"

# Junctions
var junctions: Array[Node2D] = []
var junction_timer: float = 0.0
var junction_min_interval: float = 0.25
var junction_max_interval: float = 0.5
var next_junction_delay: float = 0.0

# Swipe detection
var swipe_start: Vector2 = Vector2.ZERO
var minimum_drag: float = 20.0

# Train node (position updated by smooth interpolation)
var train_node: Node2D
var lanes_initialized: bool = false

# Obstacles
var obstacles: Array[Node2D] = []
var obstacle_timer: float = 0.0
var obstacle_spawn_interval: float = 1.5  # Slightly slower with wider track
var obstacle_scene: PackedScene

# Bullets
var bullets: Array[Node2D] = []
var bullet_speed: float = 300.0
var shoot_cooldown: float = 0.0
var shoot_rate: float = 0.3
var is_holding_shoot: bool = false

# Junction configs: valid path combos per lane (0-indexed).
# Lane 0 = far left (no left), Lane 4 = far right (no right).
var LANE_CONFIGS: Array = [
	# Lane 0 — far left, no left path
	[["straight"], ["straight", "right"], ["right"]],
	# Lane 1
	[["straight"], ["straight", "left"], ["straight", "right"], ["left", "right"], ["left"], ["right"]],
	# Lane 2 — center
	[["straight"], ["straight", "left"], ["straight", "right"], ["left", "right"], ["left"], ["right"]],
	# Lane 3
	[["straight"], ["straight", "left"], ["straight", "right"], ["left", "right"], ["left"], ["right"]],
	# Lane 4 — far right, no right path
	[["straight"], ["straight", "left"], ["left"]],
]

func _ready():
	obstacle_scene = preload("res://scenes/obstacle.tscn")
	train_node = Node2D.new()
	train_node.name = "Train"
	add_child(train_node)
	next_junction_delay = randf_range(0.25, 0.5)

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
	var total_width = (LANE_COUNT - 1) * LANE_SPACING
	var start_x = (vs.x - total_width) / 2.0
	for i in range(LANE_COUNT):
		lane_positions.append(start_x + i * LANE_SPACING)
	target_x = lane_positions[current_lane]
	train_node.position = Vector2(target_x, vs.y * 0.75)

# --- Input handling ---

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
					_queue_turn(1 if swipe_dir.x > 0 else -1)
	elif event is InputEventMouseButton:
		if event.pressed:
			swipe_start = event.position
			is_holding_shoot = true
		else:
			is_holding_shoot = false
			var swipe_dir = event.position - swipe_start
			if swipe_dir.length() > minimum_drag:
				if abs(swipe_dir.x) > abs(swipe_dir.y):
					_queue_turn(1 if swipe_dir.x > 0 else -1)
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE:
			is_holding_shoot = event.pressed
		elif event.keycode == KEY_LEFT:
			_queue_turn(-1)
		elif event.keycode == KEY_RIGHT:
			_queue_turn(1)

func _queue_turn(direction: int):
	if direction < 0:
		queued_turn = "left"
	elif direction > 0:
		queued_turn = "right"

# --- Main loop ---

func _process(delta: float):
	if not GameManager.is_playing:
		return

	_ensure_lanes()
	if lane_positions.is_empty():
		return

	var vs = get_viewport_rect().size
	scroll_offset += scroll_speed * delta

	# Smooth train sliding toward target lane
	var diff = target_x - train_node.position.x
	if abs(diff) > 1.0:
		train_node.position.x += diff * 10.0 * delta
	else:
		train_node.position.x = target_x

	# Shooting
	if shoot_cooldown > 0:
		shoot_cooldown -= delta
	if is_holding_shoot and shoot_cooldown <= 0:
		_shoot()
		shoot_cooldown = shoot_rate

	_update_bullets(delta, vs)
	_update_obstacles(delta, vs)

	obstacle_timer += delta
	if obstacle_timer >= obstacle_spawn_interval:
		obstacle_timer = 0.0
		_spawn_obstacle()

	_check_obstacle_collisions()
	_bullet_obstacle_collisions()

	# Junctions
	_update_junctions(delta, vs)
	_check_junction_passage()

	queue_redraw()

# --- Junction management ---

func _update_junctions(delta: float, vs: Vector2):
	# Scroll junctions down
	var to_remove: Array[Node2D] = []
	for j in junctions:
		j.position.y += scroll_speed * delta
		if j.position.y > vs.y + 60:
			to_remove.append(j)
	for j in to_remove:
		junctions.erase(j)
		j.queue_free()

	# Spawn new junctions
	junction_timer += delta
	if junction_timer >= next_junction_delay:
		junction_timer = 0.0
		_spawn_junction(vs)
		next_junction_delay = randf_range(junction_min_interval, junction_max_interval)

func _spawn_junction(vs: Vector2):
	var lane = randi() % LANE_COUNT
	var configs = LANE_CONFIGS[lane]
	var config = configs[randi() % configs.size()]

	var junction = Node2D.new()
	junction.name = "Junction"
	junction.set_meta("lane", lane)
	junction.set_meta("has_left", "left" in config)
	junction.set_meta("has_straight", "straight" in config)
	junction.set_meta("has_right", "right" in config)
	junction.set_meta("paths", config)
	junction.position = Vector2(lane_positions[lane], -40.0)
	add_child(junction)
	junctions.append(junction)

func _check_junction_passage():
	var train_y = train_node.position.y
	var train_x = train_node.position.x

	for j in junctions:
		# Skip junctions that already triggered
		if j.get_meta("triggered", false):
			continue
		# Train passes junction when Y positions overlap AND train is on same lane
		if j.position.y > 0 and abs(j.position.y - train_y) < 12.0:
			var j_lane: int = j.get_meta("lane", 2)
			# Only trigger if train is close to this lane's X position
			if abs(train_x - lane_positions[j_lane]) < LANE_SPACING * 0.6:
				j.set_meta("triggered", true)
				_execute_junction(j)

func _execute_junction(junction: Node2D):
	var j_lane: int = junction.get_meta("lane", 2)
	var has_left: bool = junction.get_meta("has_left", false)
	var has_straight: bool = junction.get_meta("has_straight", true)
	var has_right: bool = junction.get_meta("has_right", false)

	var switched = false

	# Try to honor the queued turn
	if queued_turn == "left" and has_left and j_lane > 0:
		current_lane = j_lane - 1
		switched = true
	elif queued_turn == "right" and has_right and j_lane < LANE_COUNT - 1:
		current_lane = j_lane + 1
		switched = true
	elif queued_turn == "left" and not has_left and has_right:
		# Can't go left, fall back to right
		current_lane = j_lane + 1
		switched = true
	elif queued_turn == "right" and not has_right and has_left:
		# Can't go right, fall back to left
		current_lane = j_lane - 1
		switched = true
	elif queued_turn == "none" and not has_straight and (has_left or has_right):
		# No straight path and no player input — pick randomly
		if has_left and has_right:
			current_lane = j_lane + (1 if randi() % 2 == 0 else -1)
		elif has_left:
			current_lane = j_lane - 1
		else:
			current_lane = j_lane + 1
		# Clamp just in case
		current_lane = clampi(current_lane, 0, LANE_COUNT - 1)
		switched = true
	# else: go straight (stay on current lane)

	if switched:
		target_x = lane_positions[current_lane]
		GameManager.player_lane = current_lane
		AudioManager.play_sfx("lane_switch")

	# Always reset turn signal after junction
	queued_turn = "none"

# --- Obstacle management ---

func _spawn_obstacle():
	var obs = obstacle_scene.instantiate()
	var lane = randi() % LANE_COUNT
	obs.position = Vector2(lane_positions[lane], -40.0)
	add_child(obs)
	obstacles.append(obs)

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

func _check_obstacle_collisions():
	var train_pos = train_node.position
	for obs in obstacles:
		if obs.position.distance_to(train_pos) < 18.0:
			GameManager.take_damage(20.0)
			obstacles.erase(obs)
			obs.queue_free()
			AudioManager.play_sfx("crash")
			break

func _bullet_obstacle_collisions():
	var bullets_to_remove: Array[Node2D] = []
	var obstacles_to_remove: Array[Node2D] = []

	for b in bullets:
		for obs in obstacles:
			if b.position.distance_to(obs.position) < 18.0:
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

# --- Bullet management ---

func _shoot():
	var bullet = Node2D.new()
	bullet.name = "Bullet"
	bullet.position = Vector2(train_node.position.x, train_node.position.y - 18.0)
	bullet.set_meta("velocity", Vector2(0, -bullet_speed))
	add_child(bullet)
	bullets.append(bullet)
	AudioManager.play_sfx("shoot")

func _update_bullets(delta: float, vs: Vector2):
	var to_remove: Array[Node2D] = []
	for b in bullets:
		var vel: Vector2 = b.get_meta("velocity", Vector2(0, -bullet_speed))
		b.position += vel * delta
		if b.position.y < -10:
			to_remove.append(b)
	for b in to_remove:
		bullets.erase(b)
		b.queue_free()

# --- Drawing ---

func _draw():
	var vs = get_viewport_rect().size
	var w = vs.x
	var h = vs.y

	if w < 10 or h < 10:
		return

	# Background
	draw_rect(Rect2(0, 0, w, h), Color(0.06, 0.08, 0.06))

	if lane_positions.is_empty():
		return

	# Track bed area
	var track_left = lane_positions[0] - LANE_SPACING / 2.0
	var track_right = lane_positions[LANE_COUNT - 1] + LANE_SPACING / 2.0
	draw_rect(Rect2(track_left, 0, track_right - track_left, h), Color(0.08, 0.10, 0.08))

	# Track borders
	draw_rect(Rect2(track_left - 2, 0, 2, h), Color(0.3, 0.25, 0.15))
	draw_rect(Rect2(track_right, 0, 2, h), Color(0.3, 0.25, 0.15))

	# Main track lines (thin monorail rails)
	for i in range(LANE_COUNT):
		var lx = lane_positions[i]
		draw_rect(Rect2(lx - TRACK_LINE_WIDTH / 2.0, 0, TRACK_LINE_WIDTH, h), Color(0.3, 0.35, 0.3))

	# Erase track lines at junctions that have no straight path
	# (visually tells the player they MUST turn here)
	var bg_color = Color(0.06, 0.08, 0.06)
	var erase_h = 18.0  # Gap height above and below junction point
	for j in junctions:
		if not j.get_meta("has_straight", true):
			var j_lane: int = j.get_meta("lane", 2)
			var jx = lane_positions[j_lane]
			var jy = j.position.y
			# Draw background-colored rect to erase the track line (only above junction)
			draw_rect(Rect2(jx - TRACK_LINE_WIDTH / 2.0 - 1, jy - erase_h, TRACK_LINE_WIDTH + 2, erase_h), bg_color)

	# Junction crossovers
	_draw_junctions()

	# Turn indicator (green glow on next junction path)
	_draw_turn_indicator()

	# Bullets
	for b in bullets:
		draw_rect(Rect2(b.position.x - 3, b.position.y - 7, 6, 14), Color(1.0, 0.9, 0.2, 0.25))
		draw_rect(Rect2(b.position.x - 2, b.position.y - 5, 4, 10), Color(1.0, 1.0, 0.4))
		draw_rect(Rect2(b.position.x - 1, b.position.y - 3, 2, 6), Color(1.0, 1.0, 0.9))

	# Train
	_draw_train()

	# Obstacles
	for obs in obstacles:
		draw_rect(Rect2(obs.position.x - 8, obs.position.y - 8, 16, 16), Color(0.8, 0.2, 0.1))
		draw_line(Vector2(obs.position.x - 5, obs.position.y - 5), Vector2(obs.position.x + 5, obs.position.y + 5), Color(1, 1, 0.3), 2.0)
		draw_line(Vector2(obs.position.x + 5, obs.position.y - 5), Vector2(obs.position.x - 5, obs.position.y + 5), Color(1, 1, 0.3), 2.0)

func _draw_train():
	var tx = train_node.position.x
	var ty = train_node.position.y

	# Narrow monorail train body
	draw_rect(Rect2(tx - 7, ty - 14, 14, 28), Color(0.2, 0.5, 0.8))
	# Cab
	draw_rect(Rect2(tx - 5, ty - 18, 10, 5), Color(0.3, 0.6, 0.9))
	# Headlight
	draw_rect(Rect2(tx - 2, ty - 20, 4, 3), Color(1.0, 1.0, 0.6))
	# Wheels (small, monorail style)
	draw_rect(Rect2(tx - 8, ty - 10, 2, 5), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(tx + 6, ty - 10, 2, 5), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(tx - 8, ty + 5, 2, 5), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(tx + 6, ty + 5, 2, 5), Color(0.15, 0.15, 0.15))

func _draw_junctions():
	for j in junctions:
		var j_lane: int = j.get_meta("lane", 2)
		var jx = lane_positions[j_lane]
		var jy = j.position.y
		var has_left: bool = j.get_meta("has_left", false)
		var has_right: bool = j.get_meta("has_right", false)

		var crossover_h = 18.0  # Height of diagonal crossover (forward = upward)

		# Draw crossover diagonal lines (always point forward = upward)
		if has_left and j_lane > 0:
			var target_x = lane_positions[j_lane - 1]
			draw_line(Vector2(jx, jy), Vector2(target_x, jy - crossover_h), Color(0.5, 0.4, 0.2), 2.0)
			# Switch point marker
			draw_circle(Vector2(jx, jy), 3.5, Color(0.6, 0.5, 0.2))

		if has_right and j_lane < LANE_COUNT - 1:
			var target_x = lane_positions[j_lane + 1]
			draw_line(Vector2(jx, jy), Vector2(target_x, jy - crossover_h), Color(0.5, 0.4, 0.2), 2.0)
			draw_circle(Vector2(jx, jy), 3.5, Color(0.6, 0.5, 0.2))

		# Straight-only junctions get a subtle marker
		if not has_left and not has_right:
			draw_circle(Vector2(jx, jy), 2.5, Color(0.35, 0.35, 0.3))

func _draw_turn_indicator():
	# Two arrow indicators at the top of the viewport
	# Gray by default, green when the player has queued that direction
	var vs = get_viewport_rect().size
	var arrow_y = 14.0  # Near top of viewport
	var arrow_size = 10.0
	var gap = 20.0  # Gap between arrows
	var cx = vs.x / 2.0  # Center of viewport

	var gray = Color(0.4, 0.4, 0.4, 0.8)
	var green = Color(0.2, 0.9, 0.2, 0.9)

	# Left arrow (triangle pointing left)
	var left_color = green if queued_turn == "left" else gray
	var lx = cx - gap
	var pts_left = PackedVector2Array([
		Vector2(lx - arrow_size, arrow_y),
		Vector2(lx + arrow_size * 0.5, arrow_y - arrow_size * 0.6),
		Vector2(lx + arrow_size * 0.5, arrow_y + arrow_size * 0.6),
	])
	draw_colored_polygon(pts_left, left_color)

	# Right arrow (triangle pointing right)
	var right_color = green if queued_turn == "right" else gray
	var rx = cx + gap
	var pts_right = PackedVector2Array([
		Vector2(rx + arrow_size, arrow_y),
		Vector2(rx - arrow_size * 0.5, arrow_y - arrow_size * 0.6),
		Vector2(rx - arrow_size * 0.5, arrow_y + arrow_size * 0.6),
	])
	draw_colored_polygon(pts_right, right_color)
