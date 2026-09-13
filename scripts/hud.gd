extends Control

var game
var font := ThemeDB.fallback_font

func _ready():
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func _draw():
    if not game or not game.player:
        return

    var size = get_viewport_rect().size
    var p = game.player
    var s = max(0.72, size.y / 1080.0)

    # Compact HUD: no black cinematic bars, no vignette, no flashlight mask.
    draw_rect(Rect2(18*s, 18*s, 300*s, 58*s), Color(0.04,0.05,0.06,0.64), true)
    draw_string(font, Vector2(34*s, 55*s), "HOUSE ASSAULT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(25*s), Color(0.95,0.96,0.98))

    var objective = "ВРАГОВ: %d" % game.enemies_left if game.enemies_left > 0 else "ВЫХОД ОТКРЫТ"
    var objective_color = Color(1.0,0.60,0.16) if game.enemies_left > 0 else Color(0.18,0.92,0.38)
    draw_rect(Rect2(size.x*0.5-150*s, 18*s, 300*s, 58*s), Color(0.04,0.05,0.06,0.58), true)
    draw_string(font, Vector2(size.x*0.5-135*s, 56*s), objective, HORIZONTAL_ALIGNMENT_CENTER, 270*s, int(24*s), objective_color)

    # Health.
    var hp_w = 220*s
    var hp_x = 26*s
    var hp_y = size.y - 54*s
    draw_rect(Rect2(hp_x, hp_y, hp_w, 18*s), Color(0.04,0.04,0.045,0.72), true)
    draw_rect(Rect2(hp_x+3*s, hp_y+3*s, (hp_w-6*s)*float(p.health)/100.0, 12*s), Color(0.80,0.13,0.08,0.92), true)
    draw_string(font, Vector2(hp_x, hp_y-8*s), "HP %d" % p.health, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19*s), Color.WHITE)

    # Crosshair.
    var c = size * 0.5
    var cross = Color(1,1,1,0.82)
    draw_circle(c, 2.4*s, cross)
    draw_line(c+Vector2(-13*s,0), c+Vector2(-5*s,0), cross, 2*s)
    draw_line(c+Vector2(5*s,0), c+Vector2(13*s,0), cross, 2*s)
    draw_line(c+Vector2(0,-13*s), c+Vector2(0,-5*s), cross, 2*s)
    draw_line(c+Vector2(0,5*s), c+Vector2(0,13*s), cross, 2*s)

    # Floating movement joystick. It follows the movement finger instead of forcing the player into a tiny fixed circle.
    var default_joy = Vector2(size.x*0.15, size.y*0.78)
    var joy = p.move_origin if p.move_touch != -1 else default_joy
    var joy_r = min(size.x,size.y) * 0.115
    draw_circle(joy, joy_r, Color(0.08,0.09,0.11,0.24))
    draw_arc(joy, joy_r, 0, TAU, 56, Color(0.85,0.88,0.92,0.28), 3*s)
    draw_circle(joy + p.touch_move * joy_r * 0.58, joy_r*0.31, Color(0.88,0.91,0.95,0.42))

    # Dedicated fire button. The player script uses the exact same centre/radius and touch ID isolation.
    var fire = Vector2(size.x*0.885, size.y*0.76)
    var fire_r = min(size.x,size.y) * 0.105
    draw_circle(fire, fire_r, Color(0.48,0.05,0.025,0.34))
    draw_arc(fire, fire_r, 0, TAU, 56, Color(1.0,0.30,0.12,0.76), 4*s)
    draw_string(font, fire+Vector2(-fire_r*0.55, 8*s), "ОГОНЬ", HORIZONTAL_ALIGNMENT_CENTER, fire_r*1.1, int(19*s), Color(1.0,0.92,0.82))

    # Right half stays visually clear for swiping/looking.
    if game.enemies_left == 0 and not game.won:
        var to_exit = game.exit_pos - p.global_position
        var meters = int(to_exit.length())
        var flat = Vector3(to_exit.x,0,to_exit.z).normalized()
        var fwd = -p.global_transform.basis.z; fwd.y=0; fwd=fwd.normalized()
        var right = p.global_transform.basis.x; right.y=0; right=right.normalized()
        var angle = atan2(right.dot(flat), fwd.dot(flat))
        var arrow = "↑"
        if angle > 0.40: arrow = "→"
        elif angle < -0.40: arrow = "←"
        draw_rect(Rect2(size.x*0.5-125*s, 88*s, 250*s, 45*s), Color(0.02,0.10,0.035,0.60), true)
        draw_string(font, Vector2(size.x*0.5-110*s,118*s), "%s  ВЫХОД  %d м" % [arrow,meters], HORIZONTAL_ALIGNMENT_CENTER, 220*s, int(20*s), Color(0.25,1.0,0.45))

    if p.damage_flash > 0:
        draw_rect(Rect2(0,0,size.x,size.y), Color(0.80,0.0,0.0,0.14*p.damage_flash), true)

    if game.won:
        draw_rect(Rect2(0,0,size.x,size.y), Color(0.02,0.03,0.04,0.82), true)
        draw_string(font, Vector2(size.x*0.5-320*s,size.y*0.43), "CONGRATULATIONS", HORIZONTAL_ALIGNMENT_CENTER, 640*s, int(48*s), Color(0.24,1.0,0.46))
        var total = int(game.game_time)
        var mins = int(total / 60)
        var secs = total % 60
        draw_string(font, Vector2(size.x*0.5-270*s,size.y*0.51), "Дом зачищен. Время %02d:%02d" % [mins,secs], HORIZONTAL_ALIGNMENT_CENTER, 540*s, int(25*s), Color.WHITE)
