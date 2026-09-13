extends Node3D

const HOUSE_W := 34.0
const HOUSE_D := 24.0
const WALL_H := 3.25
const ENEMY_COUNT := 6

var player
var hud
var enemies_left := ENEMY_COUNT
var won := false
var game_time := 0.0
var exit_pos := Vector3(13.5, 0.9, 11.0)
var exit_body: StaticBody3D
var exit_mesh: MeshInstance3D
var exit_collision: CollisionShape3D
var rng := RandomNumberGenerator.new()

var mat_wall: StandardMaterial3D
var mat_wall_blue: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_tile: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_trim: StandardMaterial3D
var mat_dark_wood: StandardMaterial3D
var mat_fabric: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_rug: StandardMaterial3D
var mat_exit_locked: StandardMaterial3D
var mat_exit_open: StandardMaterial3D

func _ready():
    rng.seed = 22092026
    _make_materials()
    _setup_environment()
    _build_house()
    _spawn_player()
    _spawn_enemies()
    _make_exit()
    _make_hud()
    _start_music()

func _process(delta):
    if not won:
        game_time += delta
    if hud:
        hud.queue_redraw()
    if not won and enemies_left == 0 and player and player.global_position.distance_to(exit_pos) < 2.15:
        _win()

func _make_materials():
    mat_wall = StandardMaterial3D.new()
    mat_wall.albedo_texture = load("res://assets/textures/plaster_color.jpg")
    mat_wall.normal_enabled = true
    mat_wall.normal_texture = load("res://assets/textures/plaster_normal.jpg")
    mat_wall.roughness_texture = load("res://assets/textures/plaster_rough.jpg")
    mat_wall.roughness = 0.9
    mat_wall.albedo_color = Color(1.04,1.02,0.98)
    mat_wall.uv1_scale = Vector3(3.8,2.2,3.8)

    mat_wall_blue = mat_wall.duplicate()
    mat_wall_blue.albedo_color = Color(0.68,0.82,0.92)

    mat_wood = StandardMaterial3D.new()
    mat_wood.albedo_texture = load("res://assets/textures/wood_color.jpg")
    mat_wood.normal_enabled = true
    mat_wood.normal_texture = load("res://assets/textures/wood_normal.jpg")
    mat_wood.roughness_texture = load("res://assets/textures/wood_rough.jpg")
    mat_wood.roughness = 0.62
    mat_wood.uv1_scale = Vector3(8.0,8.0,1.0)

    mat_tile = StandardMaterial3D.new()
    mat_tile.albedo_texture = load("res://assets/textures/tile_color.jpg")
    mat_tile.normal_enabled = true
    mat_tile.normal_texture = load("res://assets/textures/tile_normal.jpg")
    mat_tile.roughness_texture = load("res://assets/textures/tile_rough.jpg")
    mat_tile.roughness = 0.72
    mat_tile.uv1_scale = Vector3(5.0,5.0,1.0)

    mat_ceiling = StandardMaterial3D.new()
    mat_ceiling.albedo_color = Color(0.94,0.94,0.91)
    mat_ceiling.roughness = 0.92

    mat_trim = StandardMaterial3D.new()
    mat_trim.albedo_color = Color(0.90,0.88,0.82)
    mat_trim.roughness = 0.56

    mat_dark_wood = StandardMaterial3D.new()
    mat_dark_wood.albedo_color = Color(0.19,0.105,0.055)
    mat_dark_wood.roughness = 0.48

    mat_fabric = StandardMaterial3D.new()
    mat_fabric.albedo_color = Color(0.16,0.28,0.38)
    mat_fabric.roughness = 0.84

    mat_metal = StandardMaterial3D.new()
    mat_metal.albedo_color = Color(0.19,0.21,0.23)
    mat_metal.metallic = 0.82
    mat_metal.roughness = 0.25

    mat_glass = StandardMaterial3D.new()
    mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat_glass.albedo_color = Color(0.44,0.76,0.96,0.34)
    mat_glass.metallic = 0.08
    mat_glass.roughness = 0.08
    mat_glass.emission_enabled = true
    mat_glass.emission = Color(0.14,0.36,0.60)
    mat_glass.emission_energy_multiplier = 0.48

    mat_rug = StandardMaterial3D.new()
    mat_rug.albedo_texture = load("res://assets/textures/rug.jpg")
    mat_rug.roughness = 0.82

    mat_exit_locked = StandardMaterial3D.new()
    mat_exit_locked.albedo_color = Color(0.34,0.07,0.045)
    mat_exit_locked.metallic = 0.40
    mat_exit_locked.roughness = 0.33
    mat_exit_locked.emission_enabled = true
    mat_exit_locked.emission = Color(0.72,0.025,0.01)
    mat_exit_locked.emission_energy_multiplier = 1.4

    mat_exit_open = StandardMaterial3D.new()
    mat_exit_open.albedo_color = Color(0.035,0.36,0.11)
    mat_exit_open.metallic = 0.32
    mat_exit_open.roughness = 0.30
    mat_exit_open.emission_enabled = true
    mat_exit_open.emission = Color(0.02,0.95,0.18)
    mat_exit_open.emission_energy_multiplier = 2.2

func _setup_environment():
    var world = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.18,0.25,0.33)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(1.0,0.97,0.91)
    env.ambient_light_energy = 1.08
    env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    env.glow_enabled = true
    env.glow_intensity = 0.28
    env.glow_bloom = 0.06
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.tonemap_exposure = 1.08
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.04
    env.adjustment_saturation = 1.03
    world.environment = env
    add_child(world)

func _build_house():
    # Floor and ceiling.
    _static_box(Vector3(0,-0.07,0), Vector3(HOUSE_W,0.14,HOUSE_D), mat_wood, true)
    _visual_box(Vector3(0,WALL_H+0.055,0), Vector3(HOUSE_W,0.11,HOUSE_D), mat_ceiling)

    # Tile zones: kitchen and bathroom.
    _visual_box(Vector3(-11,0.008,-0.5), Vector3(10.7,0.025,6.4), mat_tile)
    _visual_box(Vector3(0,0.009,-8.0), Vector3(9.7,0.027,7.4), mat_tile)

    # Outer shell. Front wall has a 2.6 m exit opening centred near x=13.5.
    _wall_x(-12.0,-17.0,17.0)
    _wall_z(-17.0,-12.0,12.0)
    _wall_z(17.0,-12.0,12.0)
    _wall_x(12.0,-17.0,12.2)
    _wall_x(12.0,14.8,17.0)

    # Front / middle division with two wide doorways.
    _wall_x(3.0,-17.0,-7.2)
    _wall_x(3.0,-4.7,4.4)
    _wall_x(3.0,7.0,17.0)
    _door_frame(Vector3(-5.95,0,3.0), true)
    _door_frame(Vector3(5.70,0,3.0), true)

    # Middle / rear division.
    _wall_x(-4.0,-17.0,-10.4)
    _wall_x(-4.0,-8.0,0.8)
    _wall_x(-4.0,3.2,17.0)
    _door_frame(Vector3(-9.2,0,-4.0), true)
    _door_frame(Vector3(2.0,0,-4.0), true)

    # Middle room separators.
    _wall_z(-5.0,-4.0,-0.2)
    _wall_z(-5.0,1.7,3.0)
    _door_frame(Vector3(-5.0,0,0.75), false)
    _wall_z(6.0,-4.0,-0.7)
    _wall_z(6.0,1.5,3.0)
    _door_frame(Vector3(6.0,0,0.4), false)

    # Rear separators with wide doors.
    _wall_z(-6.0,-12.0,-8.6)
    _wall_z(-6.0,-6.2,-4.0)
    _door_frame(Vector3(-6.0,0,-7.4), false)
    _wall_z(5.0,-12.0,-8.3)
    _wall_z(5.0,-6.0,-4.0)
    _door_frame(Vector3(5.0,0,-7.15), false)

    # Bright faux windows on exterior walls.
    _window(Vector3(-11.0,1.75,-11.86), Vector3(4.0,1.55,0.055))
    _window(Vector3(0.0,1.75,-11.86), Vector3(4.0,1.55,0.055))
    _window(Vector3(11.0,1.75,-11.86), Vector3(4.0,1.55,0.055))
    _window(Vector3(-16.86,1.75,7.2), Vector3(0.055,1.55,3.7))
    _window(Vector3(16.86,1.75,7.2), Vector3(0.055,1.55,3.7))

    # Ceiling lights. Ambient lighting is deliberately high, so none of the house is flashlight-dark.
    for pos in [Vector3(-10,0,8),Vector3(0,0,8),Vector3(10,0,8),Vector3(-11,0,0),Vector3(0,0,0),Vector3(11,0,0),Vector3(-11,0,-8),Vector3(0,0,-8),Vector3(11,0,-8)]:
        _ceiling_light(pos)

    # Furniture / landmarks.
    _living_room()
    _dining_room()
    _kitchen()
    _office()
    _bedroom(Vector3(-11,0,-8), false)
    _bathroom()
    _bedroom(Vector3(11,0,-8), true)

func _living_room():
    _rug(Vector3(-7.8,0.025,8.0), Vector2(6.5,4.2))
    _sofa(Vector3(-10.0,0,8.5), 0.0)
    _sofa(Vector3(-6.9,0,10.0), -90.0)
    _table(Vector3(-7.5,0,7.1), Vector3(2.3,0.50,1.15))
    _visual_box(Vector3(-12.8,1.35,4.2), Vector3(2.7,1.55,0.18), mat_metal)
    _visual_box(Vector3(-12.8,1.40,4.08), Vector3(2.35,1.22,0.035), _screen_mat())

func _dining_room():
    _table(Vector3(6.2,0,8.0), Vector3(3.5,0.72,1.6))
    for p in [Vector3(4.1,0,8),Vector3(8.3,0,8),Vector3(5.2,0,6.7),Vector3(7.2,0,6.7),Vector3(5.2,0,9.3),Vector3(7.2,0,9.3)]:
        _chair(p)
    _visual_box(Vector3(12.2,0.62,10.4), Vector3(5.2,1.20,0.55), mat_dark_wood)

func _kitchen():
    for x in [-14.2,-12.6,-11.0,-9.4,-7.8]:
        _visual_box(Vector3(x,0.55,-3.35), Vector3(1.45,1.05,0.62), mat_trim)
        _visual_box(Vector3(x,1.17,-3.35), Vector3(1.45,0.10,0.68), mat_dark_wood)
    _visual_box(Vector3(-11.0,0.53,-0.4), Vector3(3.6,1.0,1.25), mat_trim)
    _visual_box(Vector3(-11.0,1.08,-0.4), Vector3(3.75,0.10,1.38), mat_dark_wood)
    _visual_box(Vector3(-15.5,1.25,1.5), Vector3(1.2,2.4,1.0), mat_metal)

func _office():
    _table(Vector3(11.5,0,-2.3), Vector3(3.1,0.72,1.25))
    _chair(Vector3(11.5,0,-0.9))
    _visual_box(Vector3(11.5,1.32,-2.70), Vector3(1.35,0.86,0.08), mat_metal)
    _visual_box(Vector3(11.5,1.34,-2.75), Vector3(1.16,0.67,0.025), _screen_mat())
    for y in [0.45,1.20,1.95]:
        _visual_box(Vector3(15.4,y,0.8), Vector3(0.65,0.10,3.25), mat_dark_wood)

func _bedroom(center: Vector3, mirrored: bool):
    var dir = -1.0 if mirrored else 1.0
    _visual_box(center+Vector3(dir*1.3,0.28,-1.15), Vector3(3.3,0.48,4.0), mat_dark_wood)
    _visual_box(center+Vector3(dir*1.3,0.58,-1.15), Vector3(3.12,0.34,3.72), _bed_mat(mirrored))
    _visual_box(center+Vector3(dir*1.3,0.88,-2.42), Vector3(2.6,0.18,0.78), mat_trim)
    _visual_box(center+Vector3(-dir*3.5,1.15,-1.7), Vector3(1.25,2.2,3.0), mat_dark_wood)
    _table(center+Vector3(dir*3.3,0,-2.0), Vector3(0.8,0.48,0.8))

func _bathroom():
    _visual_box(Vector3(-2.9,0.55,-10.8), Vector3(3.4,1.05,0.62), mat_trim)
    _visual_box(Vector3(-2.9,1.14,-10.8), Vector3(3.55,0.08,0.70), mat_dark_wood)
    _visual_box(Vector3(-2.9,1.78,-11.15), Vector3(3.0,1.0,0.045), mat_glass)
    _visual_box(Vector3(2.6,0.32,-9.6), Vector3(1.2,0.62,2.0), mat_trim)
    _visual_box(Vector3(2.6,1.15,-10.85), Vector3(1.4,1.55,0.055), mat_glass)

func _wall_x(z: float, x1: float, x2: float):
    var length = x2 - x1
    if length <= 0.05: return
    _wall(Vector3((x1+x2)*0.5, WALL_H*0.5, z), Vector3(length,WALL_H,0.22))

func _wall_z(x: float, z1: float, z2: float):
    var length = z2 - z1
    if length <= 0.05: return
    _wall(Vector3(x,WALL_H*0.5,(z1+z2)*0.5), Vector3(0.22,WALL_H,length))

func _wall(center: Vector3, size: Vector3):
    var tint = mat_wall_blue if (int(abs(center.x*3.0 + center.z*5.0)) % 11 == 3) else mat_wall
    _static_box(center,size,tint,true)
    # Baseboard and crown trim make the interior read like a house rather than a block maze.
    var base_size = size
    base_size.y = 0.13
    var crown_size = size
    crown_size.y = 0.09
    if size.x > size.z:
        base_size.z += 0.035; crown_size.z += 0.035
    else:
        base_size.x += 0.035; crown_size.x += 0.035
    _visual_box(Vector3(center.x,0.075,center.z), base_size, mat_trim)
    _visual_box(Vector3(center.x,WALL_H-0.055,center.z), crown_size, mat_trim)

func _door_frame(pos: Vector3, along_x: bool):
    var w = 2.25
    var post = Vector3(0.12,2.75,0.18) if along_x else Vector3(0.18,2.75,0.12)
    var side = Vector3(w*0.5,1.375,0) if along_x else Vector3(0,1.375,w*0.5)
    _visual_box(pos + side, post, mat_dark_wood)
    _visual_box(pos - side, post, mat_dark_wood)
    var top_size = Vector3(w+0.22,0.13,0.18) if along_x else Vector3(0.18,0.13,w+0.22)
    _visual_box(pos + Vector3(0,2.69,0), top_size, mat_dark_wood)

func _window(pos: Vector3, size: Vector3):
    _visual_box(pos,size,mat_glass)
    var frame = mat_dark_wood
    if size.x > size.z:
        _visual_box(pos+Vector3(0,size.y*.5+0.07,0),Vector3(size.x+0.18,0.10,size.z+0.07),frame)
        _visual_box(pos-Vector3(0,size.y*.5+0.07,0),Vector3(size.x+0.18,0.10,size.z+0.07),frame)
    else:
        _visual_box(pos+Vector3(0,size.y*.5+0.07,0),Vector3(size.x+0.07,0.10,size.z+0.18),frame)
        _visual_box(pos-Vector3(0,size.y*.5+0.07,0),Vector3(size.x+0.07,0.10,size.z+0.18),frame)

func _ceiling_light(pos: Vector3):
    var panel_mat = StandardMaterial3D.new()
    panel_mat.albedo_color = Color(1.0,0.94,0.79)
    panel_mat.emission_enabled = true
    panel_mat.emission = Color(1.0,0.88,0.66)
    panel_mat.emission_energy_multiplier = 2.4
    _visual_box(Vector3(pos.x,WALL_H-0.09,pos.z),Vector3(1.35,0.055,0.42),panel_mat)
    var light = OmniLight3D.new()
    light.position = Vector3(pos.x,WALL_H-0.30,pos.z)
    light.light_color = Color(1.0,0.91,0.78)
    light.light_energy = 2.15
    light.omni_range = 8.5
    light.shadow_enabled = false
    add_child(light)

func _static_box(pos: Vector3, size: Vector3, mat: Material, collision: bool):
    var body = StaticBody3D.new()
    body.position = pos
    body.collision_layer = 1
    var mi = MeshInstance3D.new(); var mesh = BoxMesh.new(); mesh.size = size
    mi.mesh = mesh; mi.material_override = mat; body.add_child(mi)
    if collision:
        var cs = CollisionShape3D.new(); var sh = BoxShape3D.new(); sh.size = size
        cs.shape = sh; body.add_child(cs)
    add_child(body)

func _visual_box(pos: Vector3, size: Vector3, mat: Material):
    var mi = MeshInstance3D.new(); var mesh = BoxMesh.new(); mesh.size = size
    mi.mesh = mesh; mi.material_override = mat; mi.position = pos; add_child(mi)

func _table(pos: Vector3, top_size: Vector3):
    _visual_box(pos+Vector3(0,top_size.y,0), Vector3(top_size.x,0.11,top_size.z), mat_dark_wood)
    for sx in [-1.0,1.0]:
        for sz in [-1.0,1.0]:
            _visual_box(pos+Vector3(sx*(top_size.x*.42),top_size.y*.5,sz*(top_size.z*.38)),Vector3(.10,top_size.y,.10),mat_metal)

func _chair(pos: Vector3):
    _visual_box(pos+Vector3(0,.48,0),Vector3(.62,.10,.62),mat_dark_wood)
    _visual_box(pos+Vector3(0,.94,.27),Vector3(.62,.82,.10),mat_dark_wood)
    for sx in [-1.0,1.0]:
        for sz in [-1.0,1.0]:
            _visual_box(pos+Vector3(sx*.24,.23,sz*.24),Vector3(.075,.46,.075),mat_metal)

func _sofa(pos: Vector3, yaw_deg: float):
    var root = Node3D.new(); root.position = pos; root.rotation_degrees.y = yaw_deg; add_child(root)
    _box_to(root,Vector3(0,.38,0),Vector3(3.0,.55,1.0),mat_fabric)
    _box_to(root,Vector3(0,.90,.42),Vector3(3.0,.85,.24),mat_fabric)
    _box_to(root,Vector3(-1.43,.62,0),Vector3(.20,.70,1.0),mat_fabric)
    _box_to(root,Vector3(1.43,.62,0),Vector3(.20,.70,1.0),mat_fabric)
    _box_to(root,Vector3(-.72,.70,-.20),Vector3(1.28,.22,.66),_cushion_mat())
    _box_to(root,Vector3(.72,.70,-.20),Vector3(1.28,.22,.66),_cushion_mat())

func _box_to(parent: Node3D, pos: Vector3, size: Vector3, mat: Material):
    var mi=MeshInstance3D.new(); var b=BoxMesh.new(); b.size=size
    mi.mesh=b; mi.material_override=mat; mi.position=pos; parent.add_child(mi)

func _rug(pos: Vector3, dims: Vector2):
    var mi=MeshInstance3D.new(); var p=PlaneMesh.new(); p.size=dims
    mi.mesh=p; mi.material_override=mat_rug; mi.position=pos; add_child(mi)

func _screen_mat() -> StandardMaterial3D:
    var m=StandardMaterial3D.new(); m.albedo_color=Color(.015,.022,.03); m.metallic=.15; m.roughness=.18
    m.emission_enabled=true; m.emission=Color(.04,.20,.36); m.emission_energy_multiplier=.75
    return m

func _cushion_mat() -> StandardMaterial3D:
    var m=StandardMaterial3D.new(); m.albedo_color=Color(.52,.61,.65); m.roughness=.90
    return m

func _bed_mat(blue: bool) -> StandardMaterial3D:
    var m=StandardMaterial3D.new(); m.albedo_color=Color(.18,.33,.52) if blue else Color(.56,.41,.30); m.roughness=.88
    return m

func _spawn_player():
    player = CharacterBody3D.new()
    player.set_script(load("res://scripts/player.gd"))
    player.game = self
    player.position = Vector3(0,0.92,8.6)
    add_child(player)

func _spawn_enemies():
    var points = [
        Vector3(-11.0,0.92,0.0),
        Vector3(0.2,0.92,0.0),
        Vector3(11.0,0.92,0.0),
        Vector3(-10.7,0.92,-8.0),
        Vector3(0.0,0.92,-8.1),
        Vector3(10.8,0.92,-8.0)
    ]
    var script = load("res://scripts/enemy.gd")
    for i in range(points.size()):
        var e = CharacterBody3D.new()
        e.set_script(script)
        e.game = self
        e.player = player
        e.position = points[i]
        e.rotation.y = (i * 0.9) - 1.6
        add_child(e)

func _make_exit():
    exit_body = StaticBody3D.new()
    exit_body.position = Vector3(13.5,1.50,11.87)
    exit_body.collision_layer = 1
    add_child(exit_body)

    exit_mesh = MeshInstance3D.new()
    var b = BoxMesh.new(); b.size = Vector3(2.45,3.0,0.16)
    exit_mesh.mesh = b; exit_mesh.material_override = mat_exit_locked
    exit_body.add_child(exit_mesh)

    exit_collision = CollisionShape3D.new()
    var sh = BoxShape3D.new(); sh.size = Vector3(2.45,3.0,0.19)
    exit_collision.shape = sh; exit_body.add_child(exit_collision)

    _visual_box(Vector3(13.5,3.08,11.88),Vector3(2.75,.13,.24),mat_dark_wood)
    _visual_box(Vector3(12.22,1.52,11.88),Vector3(.13,3.12,.24),mat_dark_wood)
    _visual_box(Vector3(14.78,1.52,11.88),Vector3(.13,3.12,.24),mat_dark_wood)

func _make_hud():
    var layer = CanvasLayer.new(); layer.layer = 20; add_child(layer)
    hud = Control.new(); hud.set_script(load("res://scripts/hud.gd")); hud.game = self
    layer.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func enemy_killed():
    enemies_left = max(0, enemies_left - 1)
    if enemies_left == 0:
        exit_mesh.material_override = mat_exit_open
        exit_collision.set_deferred("disabled", true)
        play_sfx("res://assets/audio/unlock.wav", -3.0)
        var green = OmniLight3D.new()
        green.position = Vector3(13.5,2.45,10.8)
        green.light_color = Color(0.15,1.0,0.30)
        green.light_energy = 2.8
        green.omni_range = 6.0
        add_child(green)

func _win():
    won = true
    if player:
        player.controls_enabled = false
        player.touch_move = Vector2.ZERO

func player_died():
    get_tree().reload_current_scene()

func _start_music():
    var p = AudioStreamPlayer.new()
    var stream = load("res://assets/audio/music.wav")
    if stream is AudioStreamWAV:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    p.stream = stream
    p.volume_db = -18.5
    add_child(p)
    p.play()

func play_sfx(path: String, volume_db := -4.0):
    var p = AudioStreamPlayer.new()
    p.stream = load(path)
    p.volume_db = volume_db
    add_child(p)
    p.finished.connect(p.queue_free)
    p.play()

func spawn_sparks(pos: Vector3, normal: Vector3):
    var root = Node3D.new(); root.position = pos + normal * 0.025; add_child(root)
    var mat = StandardMaterial3D.new(); mat.albedo_color=Color(1.0,.55,.12); mat.emission_enabled=true; mat.emission=Color(1.0,.22,.015); mat.emission_energy_multiplier=4.0
    for i in range(8):
        var mi=MeshInstance3D.new(); var sp=SphereMesh.new(); sp.radius=.025; sp.height=.05; sp.radial_segments=8; sp.rings=4
        mi.mesh=sp; mi.material_override=mat; root.add_child(mi)
        var dir=(normal + Vector3(rng.randf_range(-.85,.85),rng.randf_range(-.25,.85),rng.randf_range(-.85,.85))).normalized()
        var tw=create_tween(); tw.set_parallel(true)
        tw.tween_property(mi,"position",dir*rng.randf_range(.35,.85),.20)
        tw.tween_property(mi,"scale",Vector3.ZERO,.22)
    get_tree().create_timer(.28).timeout.connect(root.queue_free)

func spawn_blood(pos: Vector3, normal: Vector3, big: bool):
    var root=Node3D.new(); root.position=pos; add_child(root)
    var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.42,.015,.012); mat.roughness=.72
    var count=18 if big else 9
    for i in range(count):
        var mi=MeshInstance3D.new(); var sp=SphereMesh.new(); sp.radius=.035 if big else .024; sp.height=sp.radius*2.0; sp.radial_segments=8; sp.rings=4
        mi.mesh=sp; mi.material_override=mat; root.add_child(mi)
        var dir=(normal*.45 + Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-.15,1.0),rng.randf_range(-1.0,1.0))).normalized()
        var distance=rng.randf_range(.45,1.15) if big else rng.randf_range(.25,.65)
        var target=dir*distance + Vector3(0,-.22,0)
        var tw=create_tween(); tw.set_parallel(true)
        tw.tween_property(mi,"position",target,.32)
        tw.tween_property(mi,"scale",Vector3.ZERO,.40)
    get_tree().create_timer(.48).timeout.connect(root.queue_free)
