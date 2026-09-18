extends Node2D

const W := 720.0
const H := 1280.0

var player := Vector2(360, 1110)
var target := player
var bullets: Array[Dictionary] = []
var enemy_bullets: Array[Vector2] = []
var enemies: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var particles: Array[Dictionary] = []

var score := 0
var lives := 3
var wave := 0
var weapon_level := 1
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
    if wave % 5 == 0:
        var hp := 25 + wave * 3
        enemies.append({"p":Vector2(W/2,230),"hp":hp,"max_hp":hp,"phase":0.0,"boss":true})
    else:
        var rows := mini(2 + int(wave / 2), 5)
        for r in range(rows):
            for c in range(6):
                var hp := 1 + int((wave - 1) / 3)
                enemies.append({"p":Vector2(100+c*104,180+r*88),"hp":hp,"max_hp":hp,
                    "phase":float(c+r)*0.7,"boss":false})

func fire():
    var count := mini(weapon_level, 5)
    if count == 1:
        bullets.append({"p":player+Vector2(0,-45),"v":Vector2(0,-950)})
    else:
        for i in range(count):
            var spread := (float(i)-float(count-1)/2.0)*0.11
            bullets.append({"p":player+Vector2(0,-45),
                "v":Vector2(sin(spread)*950,-cos(spread)*950)})

func _process(delta):
    if game_over:
        queue_redraw()
        return

    elapsed += delta
    shoot_timer -= delta
    enemy_shoot_timer -= delta

    player = player.lerp(target, minf(1.0, delta * 12.0))
    player.x = clampf(player.x,45.0,W-45.0)
    player.y = clampf(player.y,650.0,H-80.0)

    if shoot_timer <= 0.0:
        fire()
        shoot_timer = maxf(0.09,0.19-weapon_level*0.012)

    for i in range(bullets.size()-1,-1,-1):
        bullets[i]["p"] += bullets[i]["v"] * delta
        var p:Vector2 = bullets[i]["p"]
        if p.y < -40 or p.x < -40 or p.x > W+40:
            bullets.remove_at(i)

    for e in enemies:
        if e["boss"]:
            e["p"].x = W/2 + sin(elapsed*1.1)*230
        else:
            e["p"].x += sin(elapsed*1.8+e["phase"])*35.0*delta

    if enemy_shoot_timer <= 0.0 and not enemies.is_empty():
        var e = enemies[rng.randi_range(0,enemies.size()-1)]
        if e["boss"]:
            for s in range(3):
                enemy_bullets.append(e["p"]+Vector2((s-1)*24,40))
        else:
            enemy_bullets.append(e["p"]+Vector2(0,30))
        enemy_shoot_timer = maxf(0.28,1.05-wave*0.035)

    for i in range(enemy_bullets.size()-1,-1,-1):
        enemy_bullets[i].y += 430.0*delta
        if enemy_bullets[i].distance_to(player) < 32:
            enemy_bullets.remove_at(i)
            lives -= 1
            weapon_level = maxi(1,weapon_level-1)
            if lives <= 0:
                game_over = true
        elif enemy_bullets[i].y > H+30:
            enemy_bullets.remove_at(i)

    for bi in range(bullets.size()-1,-1,-1):
        var hit := -1
        for ei in range(enemies.size()):
            var radius := 72.0 if enemies[ei]["boss"] else 34.0
            if bullets[bi]["p"].distance_to(enemies[ei]["p"]) < radius:
                hit = ei
                break
        if hit >= 0:
            bullets.remove_at(bi)
            enemies[hit]["hp"] -= 1
            if enemies[hit]["hp"] <= 0:
                var pos:Vector2 = enemies[hit]["p"]
                var boss:bool = enemies[hit]["boss"]
                explode(pos,30 if boss else 12)
                enemies.remove_at(hit)
                score += 2500 if boss else 100
                if boss or rng.randf() < 0.12:
                    drops.append({"p":pos,"kind":"weapon" if rng.randf()<0.75 else "life"})

    for i in range(drops.size()-1,-1,-1):
        drops[i]["p"].y += 150.0*delta
        if drops[i]["p"].distance_to(player) < 40:
            if drops[i]["kind"] == "weapon":
                weapon_level = mini(5,weapon_level+1)
            else:
                lives = mini(5,lives+1)
            score += 250
            drops.remove_at(i)
        elif drops[i]["p"].y > H+30:
            drops.remove_at(i)

    if enemies.is_empty() and not game_over:
        spawn_wave()

    for i in range(particles.size()-1,-1,-1):
        particles[i]["life"] -= delta
        particles[i]["p"] += particles[i]["v"]*delta
        if particles[i]["life"] <= 0:
            particles.remove_at(i)

    queue_redraw()

func explode(pos:Vector2,count:int):
    for i in range(count):
        var a := rng.randf_range(0.0,TAU)
        particles.append({"p":pos,
            "v":Vector2(cos(a),sin(a))*rng.randf_range(80.0,300.0),
            "life":rng.randf_range(0.3,0.7)})

func _input(event):
    var scale := Vector2(W/get_viewport_rect().size.x,H/get_viewport_rect().size.y)
    if event is InputEventScreenTouch and event.pressed:
        if game_over:
            restart()
        else:
            target = event.position*scale
    elif event is InputEventScreenDrag:
        target = event.position*scale
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        target = event.position*scale
    elif event is InputEventMouseButton and event.pressed and game_over:
        restart()

func restart():
    score=0
    lives=3
    wave=0
    weapon_level=1
    game_over=false
    player=Vector2(360,1110)
    target=player
    bullets.clear()
    enemy_bullets.clear()
    drops.clear()
    particles.clear()
    spawn_wave()

func _draw():
    draw_rect(Rect2(0,0,W,H),Color("#06142f"))
    for i in range(90):
        var x := float((i*83)%720)
        var y := float((i*151+int(elapsed*35.0))%1280)
        draw_circle(Vector2(x,y),1.5,Color(0.65,0.82,1.0,0.7))

    draw_string(ThemeDB.fallback_font,Vector2(28,52),"SCORE %06d"%score,
        HORIZONTAL_ALIGNMENT_LEFT,280,28,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(510,52),"WAVE %d"%wave,
        HORIZONTAL_ALIGNMENT_LEFT,180,26,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(28,122),"WEAPON LV.%d"%weapon_level,
        HORIZONTAL_ALIGNMENT_LEFT,260,22,Color("#62ff79"))

    for i in range(lives):
        draw_circle(Vector2(35+i*34,88),11,Color("#ff405d"))

    for e in enemies:
        if e["boss"]:
            draw_boss(e)
        else:
            draw_enemy(e["p"])

    for b in bullets:
        draw_line(b["p"],b["p"]+Vector2(0,-24),Color("#62ff79"),8,true)

    for b in enemy_bullets:
        draw_circle(b,7,Color("#ff493d"))
        draw_circle(b,3,Color("#fff3a0"))

    for d in drops:
        draw_circle(d["p"],18,Color("#66f5ff") if d["kind"]=="weapon" else Color("#ff5b82"))
        draw_string(ThemeDB.fallback_font,d["p"]+Vector2(-8,7),
            "W" if d["kind"]=="weapon" else "+",
            HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#07142c"))

    for p in particles:
        draw_circle(p["p"],5,Color("#ffb52e"))

    draw_ship(player)

    if game_over:
        draw_rect(Rect2(70,470,580,270),Color(0.02,0.06,0.15,0.94))
        draw_string(ThemeDB.fallback_font,Vector2(150,560),"FARM OVERRUN!",
            HORIZONTAL_ALIGNMENT_CENTER,420,42,Color("#ffcf3d"))
        draw_string(ThemeDB.fallback_font,Vector2(150,625),"Score: %d"%score,
            HORIZONTAL_ALIGNMENT_CENTER,420,30,Color.WHITE)
        draw_string(ThemeDB.fallback_font,Vector2(150,690),"Tap to retry",
            HORIZONTAL_ALIGNMENT_CENTER,420,26,Color("#6ee7ff"))

func draw_ship(p:Vector2):
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(0,-48),p+Vector2(38,34),p+Vector2(0,20),p+Vector2(-38,34)
    ]),Color("#d8f2ff"))
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(0,-35),p+Vector2(13,10),p+Vector2(-13,10)
    ]),Color("#1fb7ff"))
    draw_line(p+Vector2(-22,30),p+Vector2(-12,58),Color("#ff7b32"),8)
    draw_line(p+Vector2(22,30),p+Vector2(12,58),Color("#ff7b32"),8)

func draw_enemy(p:Vector2):
    draw_circle(p,29,Color("#f6c33b"))
    draw_circle(p+Vector2(-10,-5),6,Color.WHITE)
    draw_circle(p+Vector2(10,-5),6,Color.WHITE)
    draw_circle(p+Vector2(-9,-5),2.5,Color("#10213b"))
    draw_circle(p+Vector2(9,-5),2.5,Color("#10213b"))
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(-8,5),p+Vector2(9,5),p+Vector2(0,15)
    ]),Color("#ff7338"))
    draw_line(p+Vector2(-24,-21),p+Vector2(-10,-34),Color("#e74a38"),7)

func draw_boss(e:Dictionary):
    var p:Vector2=e["p"]
    draw_circle(p,72,Color("#a94aff"))
    draw_circle(p,58,Color("#f2b93b"))
    draw_circle(p+Vector2(-24,-10),12,Color.WHITE)
    draw_circle(p+Vector2(24,-10),12,Color.WHITE)
    draw_circle(p+Vector2(-22,-9),5,Color("#1a1838"))
    draw_circle(p+Vector2(22,-9),5,Color("#1a1838"))
    draw_colored_polygon(PackedVector2Array([
        p+Vector2(-18,15),p+Vector2(20,15),p+Vector2(0,38)
    ]),Color("#ff623d"))
    var ratio:float=float(e["hp"])/float(e["max_hp"])
    draw_rect(Rect2(110,135,500,14),Color("#351b42"))
    draw_rect(Rect2(110,135,500*ratio,14),Color("#ff4d6d"))
