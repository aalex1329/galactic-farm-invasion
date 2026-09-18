extends Node2D

const W := 720.0
const H := 1280.0

var player := Vector2(360, 1110)
var target := player
var bullets: Array[Vector2] = []
var enemy_bullets: Array[Vector2] = []
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []

var score := 0
var lives := 3
var wave := 0
var shoot_timer := 0.0
var enemy_shoot_timer := 0.0
var elapsed := 0.0
var game_over := false
var rng := RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    spawn_wave()
    queue_redraw()

func spawn_wave():
    wave += 1
    enemies.clear()
    var rows := mini(2 + int(wave / 2), 5)
    var cols := 6
    for r in range(rows):
        for c in range(cols):
            enemies.append({
                "p": Vector2(100 + c * 104, 180 + r * 88),
                "hp": 1 + int((wave - 1) / 3),
                "phase": float(c + r) * 0.7
            })

func _process(delta):
    if game_over:
        queue_redraw()
        return

    elapsed += delta
    shoot_timer -= delta
    enemy_shoot_timer -= delta
    player = player.lerp(target, minf(1.0, delta * 12.0))
    player.x = clampf(player.x, 45.0, W - 45.0)
    player.y = clampf(player.y, 650.0, H - 80.0)

    if shoot_timer <= 0.0:
        bullets.append(player + Vector2(0, -45))
        shoot_timer = 0.18

    for i in range(bullets.size() - 1, -1, -1):
        bullets[i].y -= 900.0 * delta
        if bullets[i].y < -30:
            bullets.remove_at(i)

    for e in enemies:
        e["p"].x += sin(elapsed * 1.8 + e["phase"]) * 35.0 * delta

    if enemy_shoot_timer <= 0.0 and not enemies.is_empty():
        var e = enemies[rng.randi_range(0, enemies.size() - 1)]
        enemy_bullets.append(e["p"] + Vector2(0, 30))
        enemy_shoot_timer = maxf(0.35, 1.1 - wave * 0.035)

    for i in range(enemy_bullets.size() - 1, -1, -1):
        enemy_bullets[i].y += 420.0 * delta
        if enemy_bullets[i].distance_to(player) < 32.0:
            enemy_bullets.remove_at(i)
            lives -= 1
            if lives <= 0:
                game_over = true
        elif enemy_bullets[i].y > H + 30:
            enemy_bullets.remove_at(i)

    for bi in range(bullets.size() - 1, -1, -1):
        var hit := -1
        for ei in range(enemies.size()):
            if bullets[bi].distance_to(enemies[ei]["p"]) < 34.0:
                hit = ei
                break
        if hit >= 0:
            bullets.remove_at(bi)
            enemies[hit]["hp"] -= 1
            if enemies[hit]["hp"] <= 0:
                explode(enemies[hit]["p"])
                enemies.remove_at(hit)
                score += 100

    if enemies.is_empty() and not game_over:
        spawn_wave()

    for i in range(particles.size() - 1, -1, -1):
        particles[i]["life"] -= delta
        particles[i]["p"] += particles[i]["v"] * delta
        if particles[i]["life"] <= 0:
            particles.remove_at(i)

    queue_redraw()

func explode(pos: Vector2):
    for i in range(12):
        var a := rng.randf_range(0.0, TAU)
        particles.append({
            "p": pos,
            "v": Vector2(cos(a), sin(a)) * rng.randf_range(80.0, 260.0),
            "life": 0.5
        })

func _input(event):
    var scale := Vector2(W / get_viewport_rect().size.x, H / get_viewport_rect().size.y)
    if event is InputEventScreenTouch and event.pressed:
        if game_over:
            restart()
        else:
            target = event.position * scale
    elif event is InputEventScreenDrag:
        target = event.position * scale
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        target = event.position * scale
    elif event is InputEventMouseButton and event.pressed and game_over:
        restart()

func restart():
    score = 0
    lives = 3
    wave = 0
    game_over = false
    player = Vector2(360, 1110)
    target = player
    bullets.clear()
    enemy_bullets.clear()
    particles.clear()
    spawn_wave()

func _draw():
    draw_rect(Rect2(0, 0, W, H), Color("#06142f"))

    for i in range(80):
        var x := float((i * 83) % 720)
        var y := float((i * 151 + int(elapsed * 30.0)) % 1280)
        draw_circle(Vector2(x, y), 1.5, Color(0.65, 0.82, 1.0, 0.7))

    draw_string(ThemeDB.fallback_font, Vector2(28, 52), "SCORE %06d" % score,
        HORIZONTAL_ALIGNMENT_LEFT, 280, 28, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(520, 52), "WAVE %d" % wave,
        HORIZONTAL_ALIGNMENT_LEFT, 170, 26, Color.WHITE)

    for i in range(lives):
        draw_circle(Vector2(35 + i * 34, 88), 11, Color("#ff405d"))

    for e in enemies:
        draw_enemy(e["p"])

    for b in bullets:
        draw_line(b, b + Vector2(0, -25), Color("#62ff79"), 8, true)

    for b in enemy_bullets:
        draw_circle(b, 7, Color("#ff493d"))
        draw_circle(b, 3, Color("#fff3a0"))

    for p in particles:
        draw_circle(p["p"], 5, Color("#ffb52e"))

    draw_ship(player)

    if game_over:
        draw_rect(Rect2(70, 470, 580, 270), Color(0.02, 0.06, 0.15, 0.94))
        draw_string(ThemeDB.fallback_font, Vector2(150, 560), "FARM OVERRUN!",
            HORIZONTAL_ALIGNMENT_CENTER, 420, 42, Color("#ffcf3d"))
        draw_string(ThemeDB.fallback_font, Vector2(150, 625), "Score: %d" % score,
            HORIZONTAL_ALIGNMENT_CENTER, 420, 30, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(150, 690), "Tap to retry",
            HORIZONTAL_ALIGNMENT_CENTER, 420, 26, Color("#6ee7ff"))

func draw_ship(p: Vector2):
    var body := PackedVector2Array([
        p + Vector2(0, -48), p + Vector2(38, 34),
        p + Vector2(0, 20), p + Vector2(-38, 34)
    ])
    draw_colored_polygon(body, Color("#d8f2ff"))
    draw_colored_polygon(PackedVector2Array([
        p + Vector2(0, -35), p + Vector2(13, 10), p + Vector2(-13, 10)
    ]), Color("#1fb7ff"))
    draw_line(p + Vector2(-22, 30), p + Vector2(-12, 58), Color("#ff7b32"), 8)
    draw_line(p + Vector2(22, 30), p + Vector2(12, 58), Color("#ff7b32"), 8)

func draw_enemy(p: Vector2):
    draw_circle(p, 29, Color("#f6c33b"))
    draw_circle(p + Vector2(-10, -5), 6, Color.WHITE)
    draw_circle(p + Vector2(10, -5), 6, Color.WHITE)
    draw_circle(p + Vector2(-9, -5), 2.5, Color("#10213b"))
    draw_circle(p + Vector2(9, -5), 2.5, Color("#10213b"))
    draw_colored_polygon(PackedVector2Array([
        p + Vector2(-8, 5), p + Vector2(9, 5), p + Vector2(0, 15)
    ]), Color("#ff7338"))
    draw_line(p + Vector2(-24, -21), p + Vector2(-10, -34), Color("#e74a38"), 7)
    draw_line(p + Vector2(-10, -34), p + Vector2(1, -23), Color("#e74a38"), 7)
