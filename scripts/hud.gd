extends Control

var game
var font := ThemeDB.fallback_font

func _ready():
    set_process(true)

func _draw():
    if not game or not game.player:
        return
    var size = get_viewport_rect().size
    var p = game.player

    # cinematic vignette
    draw_rect(Rect2(0,0,size.x,58),Color(0,0,0,0.48))
    draw_string(font,Vector2(24,38),"DOOM SECTOR",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color(0.86,0.90,0.94))

    var objective = "УНИЧТОЖЬ ВСЕХ: %d" % game.enemies_left if game.enemies_left > 0 else "ВЫХОД ОТКРЫТ — ИДИ К ЗЕЛЁНОЙ ДВЕРИ"
    draw_string(font,Vector2(size.x*0.5-250,38),objective,HORIZONTAL_ALIGNMENT_CENTER,500,22,Color(1.0,0.77,0.26) if game.enemies_left>0 else Color(0.2,1.0,0.38))

    # health panel
    draw_rect(Rect2(24,size.y-52,240,22),Color(0.02,0.02,0.025,0.8))
    draw_rect(Rect2(28,size.y-48,232.0*float(p.health)/100.0,14),Color(0.72,0.08,0.04))
    draw_string(font,Vector2(28,size.y-62),"HP %d"%p.health,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)

    # crosshair
    var c=size*0.5
    var cross=Color(0.95,0.95,0.90,0.85)
    draw_line(c+Vector2(-12,0),c+Vector2(-4,0),cross,2)
    draw_line(c+Vector2(4,0),c+Vector2(12,0),cross,2)
    draw_line(c+Vector2(0,-12),c+Vector2(0,-4),cross,2)
    draw_line(c+Vector2(0,4),c+Vector2(0,12),cross,2)

    # touch controls
    var joy=Vector2(size.x*0.13,size.y*0.77)
    draw_circle(joy,72,Color(0.12,0.14,0.16,0.34))
    draw_arc(joy,72,0,TAU,48,Color(0.65,0.72,0.78,0.33),3)
    draw_circle(joy+p.touch_move*42,25,Color(0.75,0.80,0.84,0.45))
    var fire=Vector2(size.x*0.885,size.y*0.77)
    draw_circle(fire,62,Color(0.42,0.025,0.015,0.46))
    draw_arc(fire,62,0,TAU,48,Color(1.0,0.26,0.10,0.70),4)
    draw_string(font,fire+Vector2(-34,8),"ОГОНЬ",HORIZONTAL_ALIGNMENT_CENTER,68,17,Color(1.0,0.85,0.72))

    if game.enemies_left == 0 and not game.won:
        var to_exit = game.exit_pos - p.global_position
        var meters=int(to_exit.length())
        var flat=Vector3(to_exit.x,0,to_exit.z).normalized()
        var fwd=-p.global_transform.basis.z; fwd.y=0; fwd=fwd.normalized()
        var right=p.global_transform.basis.x; right.y=0; right=right.normalized()
        var angle=atan2(right.dot(flat),fwd.dot(flat))
        var arrow="↑"
        if angle>0.42: arrow="→"
        elif angle<-0.42: arrow="←"
        draw_string(font,Vector2(size.x*0.5-120,85),"%s  ВЫХОД  %d м"%[arrow,meters],HORIZONTAL_ALIGNMENT_CENTER,240,24,Color(0.20,1.0,0.38))

    if p.damage_flash > 0:
        draw_rect(Rect2(0,0,size.x,size.y),Color(0.8,0.0,0.0,0.18*p.damage_flash))

    if game.won:
        draw_rect(Rect2(0,0,size.x,size.y),Color(0,0,0,0.78))
        draw_string(font,Vector2(size.x*0.5-310,size.y*0.43),"SECTOR CLEARED",HORIZONTAL_ALIGNMENT_CENTER,620,48,Color(0.20,1.0,0.40))
        var mins=int(game.game_time)/60
        var secs=int(game.game_time)%60
        draw_string(font,Vector2(size.x*0.5-250,size.y*0.52),"Все цели уничтожены. Время %02d:%02d"%[mins,secs],HORIZONTAL_ALIGNMENT_CENTER,500,25,Color.WHITE)
