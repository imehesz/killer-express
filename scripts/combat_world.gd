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
var train_texture: Texture2D
const TRAIN_TEX_ASPECT: float = 881.0 / 348.0  # width / height
const TRAIN_BASE_WIDTH: float = 168.0  # pixels at scale 1.0

# Parallax textures
var tracks_closer_md: Texture2D  # Middle layer (2906x800)
var tracks_closest: Texture2D    # Foreground layer (2304x800)
const TEX_NATIVE_H: float = 800.0  # Both track textures are 800px tall

# Enemy textures
var alien_textures: Array[Texture2D] = []
const ALIEN_BASE_WIDTH: float = 32.0  # pixels at scale 1.0

# 5-lane depth scaling (back to front) — used for enemies
const LANE_SCALES: Array[float] = [0.4, 0.7, 1.0, 1.3, 1.6]

# Parallax
var bg_offset: float = 0.0
var fg_offset: float = 0.0

# Particles
var particles: Array = []  # [{pos, vel, life, max_life, color, size}]
var muzzle_flashes: Array = []  # [{pos, vel, life, max_life, color, size}]
var is_dead: bool = false

func _ready():
	train_texture = preload("res://assets/images/train_top.png")
	tracks_closer_md = preload("res://assets/images/tracks-closer_md.png")
	tracks_closest = preload("res://assets/images/tracks-closest.png")
	alien_textures = [
		preload("res://assets/images/alien-1.png"),
		preload("res://assets/images/alien-2.png"),
	]
	GameManager.game_over.connect(_on_game_over)

func set_scroll_speed(speed: float):
	scroll_speed = speed

func _process(delta: float):
	if is_dead:
		_update_particles(delta)
		queue_redraw()
		return

	if not GameManager.is_playing:
		return

	var vs = get_viewport_rect().size
	if vs.x < 10 or vs.y < 10:
		return

	player_x = vs.x / 2.0
	player_y = vs.y * 0.74

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

	# Update particles
	_update_particles(delta)
	_update_muzzle_flashes(delta)

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
	var pw = TRAIN_BASE_WIDTH * 1.6
	var ph = pw / TRAIN_TEX_ASPECT
	var py = player_y
	# Upward bullet
	var bullet = Node2D.new()
	bullet.name = "Bullet"
	bullet.position = Vector2(player_x, py - ph / 2.0)
	bullet.set_meta("velocity", Vector2(0, -bullet_speed))
	add_child(bullet)
	bullets.append(bullet)
	# Forward bullet (to the right)
	var bullet2 = Node2D.new()
	bullet2.name = "Bullet"
	bullet2.position = Vector2(player_x + pw / 2.0, py)
	bullet2.set_meta("velocity", Vector2(bullet_speed, 0))
	add_child(bullet2)
	bullets.append(bullet2)
	# Muzzle flashes — upward gun
	_spawn_muzzle_flash(Vector2(player_x, py - ph / 2.0), Vector2(0, -1))
	# Muzzle flashes — forward gun
	_spawn_muzzle_flash(Vector2(player_x + pw / 2.0, py), Vector2(1, 0))
	AudioManager.play_sfx("shoot")

func _update_bullets(delta: float):
	var to_remove: Array[Node2D] = []
	var vs = get_viewport_rect().size
	for b in bullets:
		var vel: Vector2 = b.get_meta("velocity", Vector2(0, -bullet_speed))
		b.position += vel * delta
		if b.position.y < -20 or b.position.x > vs.x + 20 or b.position.x < -20:
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
	enemy.set_meta("texture_index", randi() % alien_textures.size())
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
			# Explosion + damage if enemy is in the same depth lane
			if e.get_meta("lane", 1) == GameManager.player_lane:
				GameManager.take_damage(5.0)
				_spawn_hit_particles(e.position, e.get_meta("lane_scale", 1.0))
			else:
				# Still explode visually even if no damage
				_spawn_hit_particles(e.position, e.get_meta("lane_scale", 1.0))
	for e in to_remove:
		enemies.erase(e)
		e.queue_free()

func _check_combat_collisions():
	var bullets_to_remove: Array[Node2D] = []
	var enemies_to_remove: Array[Node2D] = []

	for b in bullets:
		for e in enemies:
			var hit_radius: float = 18.0 * e.get_meta("lane_scale", 1.0)
			if b.position.distance_to(e.position) < hit_radius:
				var hp: int = e.get_meta("health", 1) - 1
				e.set_meta("health", hp)
				bullets_to_remove.append(b)
				if hp <= 0:
					enemies_to_remove.append(e)
					GameManager.add_score(e.get_meta("points", 10))
					AudioManager.play_sfx("enemy_hit")
					_spawn_hit_particles(e.position, e.get_meta("lane_scale", 1.0))
					break

	for b in bullets_to_remove:
		if b in bullets:
			bullets.erase(b)
			b.queue_free()
	for e in enemies_to_remove:
		if e in enemies:
			enemies.erase(e)
			e.queue_free()

# --- Particles ---

func _spawn_muzzle_flash(pos: Vector2, dir: Vector2):
	# Burst of bright fire particles in the given direction
	for i in range(8):
		var spread = randf_range(-0.6, 0.6)  # lateral spread
		var forward = randf_range(0.5, 1.0)   # how far forward
		var speed = randf_range(80.0, 200.0)
		var vel = Vector2(
			dir.x * forward * speed + dir.y * spread * speed,
			dir.y * forward * speed + dir.x * spread * speed
		)
		var bright = randf_range(0.8, 1.0)
		var hue = randf_range(0.05, 0.12)  # orange-yellow range
		muzzle_flashes.append({
			"pos": pos,
			"vel": vel,
			"life": randf_range(0.05, 0.15),
			"max_life": 0.15,
			"color": Color.from_hsv(hue, 0.9, bright),
			"size": randf_range(3.0, 6.0),
		})

func _spawn_hit_particles(center: Vector2, _scale: float):
	for i in range(20):
		var angle = randf() * TAU
		var speed = randf_range(20.0, 100.0)
		var bright = randf_range(0.7, 1.0)
		var hue = randf_range(0.0, 0.15)
		particles.append({
			"pos": center,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed),
			"life": randf_range(0.6, 1.2),
			"max_life": 1.2,
			"color": Color.from_hsv(hue, 0.8, bright),
			"size": randf_range(4.0, 9.0),
		})
	GameManager.alien_exploded.emit(center)

func _spawn_death_explosion(center: Vector2):
	for i in range(100):
		var angle = randf() * TAU
		var speed = randf_range(30.0, 400.0)
		var bright = randf_range(0.6, 1.0)
		var hue = randf_range(0.0, 0.15)
		particles.append({
			"pos": center,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed),
			"life": randf_range(0.5, 2.0),
			"max_life": 2.0,
			"color": Color.from_hsv(hue, 0.8, bright),
			"size": randf_range(4.0, 12.0),
		})

func _update_particles(delta: float):
	var to_remove: Array = []
	for p in particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.96  # drag
		p["life"] -= delta
		if p["life"] <= 0:
			to_remove.append(p)
	for p in to_remove:
		particles.erase(p)

func _update_muzzle_flashes(delta: float):
	var to_remove: Array = []
	for f in muzzle_flashes:
		f["pos"] += f["vel"] * delta
		f["vel"] *= 0.85  # fast decay
		f["life"] -= delta
		if f["life"] <= 0:
			to_remove.append(f)
	for f in to_remove:
		muzzle_flashes.erase(f)

func _on_game_over():
	is_dead = true
	_spawn_death_explosion(Vector2(player_x, player_y))
	# Keep updating particles briefly after death so they animate
	var timer = get_tree().create_timer(1.5)
	await timer.timeout
	particles.clear()

# --- Drawing ---

func _draw():
	var vs = get_viewport_rect().size
	var w = vs.x
	var h = vs.y

	if w < 10 or h < 10:
		return

	var ground_y = h * 0.88

	# Sky — pure black
	draw_rect(Rect2(0, 0, w, ground_y), Color(0.0, 0.0, 0.0))

	# Stars (slowest parallax — furthest background layer)
	var star_seed = 42
	var star_offset = bg_offset * 0.3  # even slower than middle layer
	for i in range(80):
		star_seed = (star_seed * 1103515245 + 12345) & 0x7fffffff
		var sx = fmod(float(star_seed % int(w + 20)) + star_offset, w + 20.0) - 10.0
		star_seed = (star_seed * 1103515245 + 12345) & 0x7fffffff
		var sy = float(star_seed % int(ground_y - 20)) + 10.0
		star_seed = (star_seed * 1103515245 + 12345) & 0x7fffffff
		var brightness = 0.4 + fmod(float(star_seed % 60), 60.0) / 100.0  # 0.4–1.0
		var sz = 1.0 + fmod(float(star_seed % 3), 3.0)  # 1–2 px
		draw_rect(Rect2(sx, sy, sz, sz), Color(brightness, brightness, brightness * 1.1))

	# Middle parallax layer (tracks-closer_md) — 0.3x speed
	var md_scale = h / TEX_NATIVE_H
	var md_w = tracks_closer_md.get_width() * md_scale
	var md_h = h
	var md_offset_x = fmod(bg_offset, md_w)
	var md_x = -md_offset_x
	while md_x < w:
		draw_texture_rect(tracks_closer_md, Rect2(md_x, 0, md_w, md_h), false)
		md_x += md_w

	# Foreground parallax layer (tracks-closest) — 0.7x speed
	var fg_scale = h / TEX_NATIVE_H
	var fg_tex_w = tracks_closest.get_width() * fg_scale
	var fg_tex_h = h
	var fg_offset_x = fmod(fg_offset, fg_tex_w)
	var fg_x = -fg_offset_x
	while fg_x < w:
		draw_texture_rect(tracks_closest, Rect2(fg_x, 0, fg_tex_w, fg_tex_h), false)
		fg_x += fg_tex_w

	# Ground
	draw_rect(Rect2(0, ground_y, w, h - ground_y), Color(0.12, 0.15, 0.08))

	# Bullets
	for b in bullets:
		# Glow
		draw_rect(Rect2(b.position.x - 3, b.position.y - 8, 6, 16), Color(1.0, 0.15, 0.1, 0.25))
		# Core
		draw_rect(Rect2(b.position.x - 2, b.position.y - 5, 4, 10), Color(1.0, 0.2, 0.15))
		# Bright center
		draw_rect(Rect2(b.position.x - 1, b.position.y - 3, 2, 6), Color(1.0, 0.6, 0.5))

	# Enemies — textured sprites scaled by lane depth
	for e in enemies:
		var ex = e.position.x
		var ey = e.position.y
		var sc: float = e.get_meta("lane_scale", 1.0)
		var tex: Texture2D = alien_textures[e.get_meta("texture_index", 0)]
		var tex_w: float = tex.get_width()
		var tex_h: float = tex.get_height()
		var draw_w: float = ALIEN_BASE_WIDTH * sc
		var draw_h: float = draw_w * (tex_h / tex_w)
		# Damage flash
		var hp: int = e.get_meta("health", 2)
		if hp < 2:
			draw_texture_rect(tex, Rect2(ex - draw_w / 2 - 1, ey - draw_h / 2 - 1, draw_w + 2, draw_h + 2), false, Color(1, 1, 1, 0.5))
		draw_texture_rect(tex, Rect2(ex - draw_w / 2, ey - draw_h / 2, draw_w, draw_h), false)

	# Player train (gun turret view) — fixed position and size
	if not is_dead:
		var pw = TRAIN_BASE_WIDTH * 1.6
		var ph = pw / TRAIN_TEX_ASPECT
		var py = player_y
		# Subtle motion shake — layered sine waves for organic feel
		var t = scroll_offset * 0.05
		var shake_x = sin(t * 3.7) * 1.2 + sin(t * 7.1) * 0.6
		var shake_y = cos(t * 4.3) * 0.8 + cos(t * 6.3) * 0.5
		# Centered on player position with shake
		var train_rect = Rect2(player_x - pw / 2.0 + shake_x, py - ph / 2.0 + shake_y, pw, ph)
		draw_texture_rect(train_texture, train_rect, false)

	# Muzzle flashes (bright fire between train and particles)
	for f in muzzle_flashes:
		var alpha = clampf(f["life"] / f["max_life"], 0.0, 1.0)
		var c: Color = f["color"]
		var sz: float = f["size"] * (0.3 + alpha * 0.7)
		var pos: Vector2 = f["pos"]
		# Hot core (white-yellow)
		var core = Color(1.0, 1.0, 0.7, alpha)
		draw_rect(Rect2(pos.x - sz * 0.3, pos.y - sz * 0.3, sz * 0.6, sz * 0.6), core)
		# Glow (orange)
		var gc = Color(c.r, c.g, c.b, alpha * 0.5)
		draw_rect(Rect2(pos.x - sz, pos.y - sz, sz * 2, sz * 2), gc)

	# Particles (drawn on top of everything)
	for p in particles:
		var alpha = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var c: Color = p["color"]
		c.a = alpha
		var sz: float = p["size"] * (0.5 + alpha * 0.5)
		var pos: Vector2 = p["pos"]
		# Glow
		var gc = Color(c.r, c.g, c.b, alpha * 0.3)
		draw_rect(Rect2(pos.x - sz, pos.y - sz, sz * 2, sz * 2), gc)
		# Core
		draw_rect(Rect2(pos.x - sz * 0.4, pos.y - sz * 0.4, sz * 0.8, sz * 0.8), c)
