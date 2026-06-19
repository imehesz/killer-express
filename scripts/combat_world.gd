extends Node2D
## Top viewport: side-scrolling combat with enemies and shooting.
## 5 depth lanes — sizes scale to simulate 3D perspective.
## Input is forwarded from the SubViewportContainer.

var scroll_speed: float = 120.0
var scroll_offset: float = 0.0
var shoot_cooldown: float = 0.0
var shoot_rate: float = 0.25
var is_holding_shoot: bool = false

# Enemies
var enemies: Array[Node2D] = []
var enemy_spawn_timer: float = 0.0
var enemy_spawn_interval: float = 1.5

# Bullets
var bullets: Array[Node2D] = []
var bullet_speed: float = 400.0

# Player position (recalculated each frame from viewport + lane)
var player_x: float = 180.0
var player_y: float = 240.0
const PLAYER_BASE_WIDTH: float = 14.0
const PLAYER_BASE_HEIGHT: float = 20.0

# 5-lane depth scaling (back to front)
const LANE_SCALES: Array[float] = [0.4, 0.7, 1.0, 1.3, 1.6]

# Parallax
var bg_offset: float = 0.0
var fg_offset: float = 0.0

func _ready():
	pass

func set_scroll_speed(speed: float):
	scroll_speed = speed

func _process(delta: float):
	if not GameManager.is_playing:
		return

	var vs = get_viewport_rect().size
	if vs.x < 10 or vs.y < 10:
		return

	player_x = vs.x / 2.0
	# Player Y shifts slightly based on lane (deeper = higher on screen)
	var lane = GameManager.player_lane
	var lane_y_factors = [0.82, 0.80, 0.78, 0.76, 0.74]
	player_y = vs.y * lane_y_factors[lane]

	# Scroll
	scroll_offset += scroll_speed * delta
	bg_offset += scroll_speed * 0.3 * delta
	fg_offset += scroll_speed * 0.7 * delta

	# Shoot cooldown
	if shoot_cooldown > 0:
		shoot_cooldown -= delta

	# Auto-fire while holding
	if is_holding_shoot and shoot_cooldown <= 0:
		_shoot()
		shoot_cooldown = shoot_rate

	# Update bullets
	_update_bullets(delta)

	# Spawn enemies
	enemy_spawn_timer += delta
	if enemy_spawn_timer >= enemy_spawn_interval:
		enemy_spawn_timer = 0.0
		_spawn_enemy(vs)

	# Update enemies
	_update_enemies(delta)

	# Check collisions
	_check_combat_collisions()

	queue_redraw()

# --- Input handling (forwarded from SubViewportContainer) ---

func _input(event):
	if not GameManager.is_playing:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			is_holding_shoot = true
		else:
			is_holding_shoot = false
	elif event is InputEventMouseButton:
		if event.pressed:
			is_holding_shoot = true
		else:
			is_holding_shoot = false
	elif event is InputEventKey:
		if event.keycode == KEY_SPACE:
			is_holding_shoot = event.pressed

# --- Bullet management ---

func _shoot():
	var bullet = Node2D.new()
	bullet.name = "Bullet"
	bullet.position = Vector2(player_x, player_y - PLAYER_BASE_HEIGHT * LANE_SCALES[GameManager.player_lane] / 2.0)
	bullet.set_meta("velocity", Vector2(0, -bullet_speed))
	add_child(bullet)
	bullets.append(bullet)
	AudioManager.play_sfx("shoot")

func _update_bullets(delta: float):
	var to_remove: Array[Node2D] = []
	for b in bullets:
		var vel: Vector2 = b.get_meta("velocity", Vector2(0, -bullet_speed))
		b.position += vel * delta
		if b.position.y < -20:
			to_remove.append(b)
	for b in to_remove:
		bullets.erase(b)
		b.queue_free()

# --- Enemy management ---

func _spawn_enemy(vs: Vector2):
	var enemy = Node2D.new()
	enemy.name = "Enemy"
	var lane = randi() % 5
	enemy.set_meta("lane", lane)
	enemy.set_meta("lane_scale", LANE_SCALES[lane])
	# Y position based on depth lane (back lanes higher, front lanes lower)
	var lane_y_factors = [0.12, 0.22, 0.35, 0.50, 0.65]
	var lane_y = vs.y * lane_y_factors[lane]
	enemy.position = Vector2(vs.x + 20.0, lane_y)
	enemy.set_meta("health", 2)
	enemy.set_meta("points", 10)
	add_child(enemy)
	enemies.append(enemy)

func _update_enemies(delta: float):
	var to_remove: Array[Node2D] = []
	for e in enemies:
		e.position.x -= scroll_speed * delta
		e.position.y += sin(e.position.x * 0.02 + e.position.y * 0.1) * 0.3
		if e.position.x < -30:
			to_remove.append(e)
			# Only damage player if enemy is in the same depth lane
			if e.get_meta("lane", 1) == GameManager.player_lane:
				GameManager.take_damage(5.0)
	for e in to_remove:
		enemies.erase(e)
		e.queue_free()

func _check_combat_collisions():
	var bullets_to_remove: Array[Node2D] = []
	var enemies_to_remove: Array[Node2D] = []

	for b in bullets:
		for e in enemies:
			var hit_radius: float = 14.0 * e.get_meta("lane_scale", 1.0)
			if b.position.distance_to(e.position) < hit_radius:
				var hp: int = e.get_meta("health", 1) - 1
				e.set_meta("health", hp)
				bullets_to_remove.append(b)
				if hp <= 0:
					enemies_to_remove.append(e)
					GameManager.add_score(e.get_meta("points", 10))
					AudioManager.play_sfx("enemy_hit")
				break

	for b in bullets_to_remove:
		if b in bullets:
			bullets.erase(b)
			b.queue_free()
	for e in enemies_to_remove:
		if e in enemies:
			enemies.erase(e)
			e.queue_free()

# --- Drawing ---

func _draw():
	var vs = get_viewport_rect().size
	var w = vs.x
	var h = vs.y

	if w < 10 or h < 10:
		return

	var ground_y = h * 0.88

	# Sky
	draw_rect(Rect2(0, 0, w, ground_y), Color(0.05, 0.05, 0.15))

	# Stars (slow parallax)
	var star_seed = 42
	for i in range(20):
		star_seed = (star_seed * 1103515245 + 12345) & 0x7fffffff
		var sx = fmod(float(star_seed % int(w + 20)) + bg_offset, w + 20.0) - 10.0
		star_seed = (star_seed * 1103515245 + 12345) & 0x7fffffff
		var sy = float(star_seed % int(ground_y - 20)) + 10.0
		draw_rect(Rect2(sx, sy, 2, 2), Color(0.7, 0.7, 0.9))

	# Buildings (medium parallax)
	for i in range(6):
		var raw_x = float(i * 70) - fg_offset * 0.5
		var bx = fmod(raw_x, w + 60.0)
		if bx < 0.0:
			bx += w + 60.0
		bx -= 30.0
		var bh = 30.0 + fmod(float(i * 17), 40.0)
		draw_rect(Rect2(bx, ground_y - bh, 50, bh), Color(0.1, 0.08, 0.12))
		for wy in range(0, int(bh) - 8, 10):
			for wx in range(4, 46, 14):
				draw_rect(Rect2(bx + wx, ground_y - bh + wy + 3, 6, 6), Color(0.6, 0.5, 0.2, 0.6))

	# Ground
	draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.12, 0.15, 0.08))

	# Bullets
	for b in bullets:
		# Glow
		draw_rect(Rect2(b.position.x - 3, b.position.y - 8, 6, 16), Color(1.0, 0.9, 0.2, 0.25))
		# Core
		draw_rect(Rect2(b.position.x - 2, b.position.y - 5, 4, 10), Color(1.0, 1.0, 0.4))
		# Bright center
		draw_rect(Rect2(b.position.x - 1, b.position.y - 3, 2, 6), Color(1.0, 1.0, 0.9))

	# Enemies — size scales by lane (3D depth)
	for e in enemies:
		var ex = e.position.x
		var ey = e.position.y
		var sc: float = e.get_meta("lane_scale", 1.0)
		var bw = 18.0 * sc
		var bh = 10.0 * sc
		# Main body
		draw_rect(Rect2(ex - bw / 2, ey - bh / 2, bw, bh), Color(0.7, 0.1, 0.1))
		# Wings
		var ww = 5.0 * sc
		var wh = 5.0 * sc
		draw_rect(Rect2(ex - bw / 2 - ww, ey - wh / 2, ww, wh), Color(0.5, 0.05, 0.05))
		draw_rect(Rect2(ex + bw / 2, ey - wh / 2, ww, wh), Color(0.5, 0.05, 0.05))
		# Eye
		var ew = 5.0 * sc
		draw_rect(Rect2(ex - ew / 2, ey - ew / 2, ew, ew), Color(0.2, 0.9, 0.2))
		# Damage flash
		var hp: int = e.get_meta("health", 2)
		if hp < 2:
			draw_rect(Rect2(ex - bw / 2 - 1, ey - bh / 2 - 1, bw + 2, bh + 2), Color(1, 1, 1, 0.3))

	# Player train (gun turret view) — size scales with lane
	var lane = GameManager.player_lane
	var sc = LANE_SCALES[lane]
	var pw = PLAYER_BASE_WIDTH * sc
	var ph = PLAYER_BASE_HEIGHT * sc
	# Slight Y offset per lane for depth feel
	var lane_y_offsets = [12.0, 6.0, 0.0, -6.0, -12.0]
	var py = player_y + lane_y_offsets[lane]
	# Body
	draw_rect(Rect2(player_x - pw / 2, py - ph / 2, pw, ph), Color(0.2, 0.5, 0.8))
	# Turret barrel
	draw_rect(Rect2(player_x - 2 * sc, py - ph / 2.0 - 8 * sc, 4 * sc, 8 * sc), Color(0.4, 0.4, 0.5))
	# Turret base
	draw_rect(Rect2(player_x - 5 * sc, py - ph / 2.0 - 3 * sc, 10 * sc, 5 * sc), Color(0.3, 0.3, 0.4))
