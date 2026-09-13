extends Node3D

const GRID := 21
const CELL := 4.0
const WALL_H := 3.6
const ENEMY_COUNT := 7

var maze: Array = []
var astar := AStarGrid2D.new()
var player
var hud
var exit_cell := Vector2i(19, 19)
var exit_pos := Vector3.ZERO
var exit_door: Node3D
var exit_collision: CollisionShape3D
var enemies_left := ENEMY_COUNT
var won := false
var game_time := 0.0
var rng := RandomNumberGenerator.new()
var flicker_lights: Array = []

var mat_wall_concrete: StandardMaterial3D
var mat_wall_metal: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_dark_metal: StandardMaterial3D
var mat_pipe: StandardMaterial3D
var mat_exit_locked: StandardMaterial3D
var mat_exit_open: StandardMaterial3D

func _ready():
    rng.seed = 13092026
    _make_materials()
    _generate_maze()
    _build_astar()
    _setup_environment()
    _build_level()
    _spawn_player()
    _spawn_enemies()
    _make_exit()
    _make_hud()
    _start_music()

func _process(delta):
    if not won:
        game_time += delta
    var t = Time.get_ticks_msec() * 0.001
    for item in flicker_lights:
        if is_instance_valid(item[0]):
            var light = item[0]
            var phase = item[1]
            var base = item[2]
            var pulse = 0.78 + 0.22 * sin(t * 2.7 + phase) + 0.08 * sin(t * 13.0 + phase * 2.1)
            light.light_energy = max(0.3, base * pulse)
    if hud:
        hud.queue_redraw()
    if not won and enemies_left == 0 and player and player.global_position.distance_to(exit_pos) < 2.2:
        _win()

func _make_materials():
    mat_wall_concrete = _pbr_mat("wall_concrete", 0.0)
    mat_wall_metal = _pbr_mat("wall_metal", 0.45)
    mat_floor = _pbr_mat("floor", 0.18)
    mat_ceiling = _pbr_mat("ceiling", 0.35)
    mat_floor.uv1_scale = Vector3(20.0, 20.0, 1.0)
    mat_ceiling.uv1_scale = Vector3(20.0, 20.0, 1.0)

    mat_dark_metal = StandardMaterial3D.new()
    mat_dark_metal.albedo_color = Color(0.055, 0.065, 0.075)
    mat_dark_metal.metallic = 0.85
    mat_dark_metal.roughness = 0.22

    mat_pipe = StandardMaterial3D.new()
    mat_pipe.albedo_color = Color(0.16, 0.18, 0.19)
    mat_pipe.metallic = 0.72
    mat_pipe.roughness = 0.34

    mat_exit_locked = StandardMaterial3D.new()
    mat_exit_locked.albedo_color = Color(0.16, 0.025, 0.018)
    mat_exit_locked.metallic = 0.65
    mat_exit_locked.roughness = 0.25
    mat_exit_locked.emission_enabled = true
    mat_exit_locked.emission = Color(1.0, 0.025, 0.008)
    mat_exit_locked.emission_energy_multiplier = 3.5

    mat_exit_open = StandardMaterial3D.new()
    mat_exit_open.albedo_color = Color(0.015, 0.18, 0.055)
    mat_exit_open.metallic = 0.55
    mat_exit_open.roughness = 0.22
    mat_exit_open.emission_enabled = true
    mat_exit_open.emission = Color(0.02, 1.0, 0.14)
    mat_exit_open.emission_energy_multiplier = 4.5

func _pbr_mat(name: String, metallic: float) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/textures/%s_albedo.png" % name)
    m.normal_enabled = true
    m.normal_texture = load("res://assets/textures/%s_normal.png" % name)
    m.roughness_texture = load("res://assets/textures/%s_rough.png" % name)
    m.roughness = 1.0
    m.metallic = metallic
    return m

func _generate_maze():
    maze.clear()
    for y in range(GRID):
        var row := []
        for x in range(GRID):
            row.append(true)
        maze.append(row)

    var stack: Array[Vector2i] = [Vector2i(1, 1)]
    maze[1][1] = false
    var dirs = [Vector2i(2,0), Vector2i(-2,0), Vector2i(0,2), Vector2i(0,-2)]
    while not stack.is_empty():
        var cur: Vector2i = stack[-1]
        var options: Array[Vector2i] = []
        for d in dirs:
            var n = cur + d
            if n.x > 0 and n.y > 0 and n.x < GRID - 1 and n.y < GRID - 1 and maze[n.y][n.x]:
                options.append(n)
        if options.is_empty():
            stack.pop_back()
        else:
            var nxt: Vector2i = options[rng.randi_range(0, options.size() - 1)]
            var mid = Vector2i(int((cur.x + nxt.x) / 2), int((cur.y + nxt.y) / 2))
            maze[mid.y][mid.x] = false
            maze[nxt.y][nxt.x] = false
            stack.append(nxt)

    # Add loops: still maze-like, but ~20% less punishing than a perfect maze.
    var opened := 0
    var attempts := 0
    while opened < 18 and attempts < 500:
        attempts += 1
        var x = rng.randi_range(1, GRID - 2)
        var y = rng.randi_range(1, GRID - 2)
        if not maze[y][x]:
            continue
        var horizontal = (not maze[y][x-1]) and (not maze[y][x+1])
        var vertical = (not maze[y-1][x]) and (not maze[y+1][x])
        if horizontal != vertical:
            maze[y][x] = false
            opened += 1

    var dist = _bfs_dist(Vector2i(1,1))
    var farthest = Vector2i(1,1)
    var best = -1
    for y in range(GRID):
        for x in range(GRID):
            var c = Vector2i(x,y)
            if not maze[y][x] and dist.has(c) and int(dist[c]) > best:
                best = int(dist[c])
                farthest = c
    exit_cell = farthest
    exit_pos = cell_to_world(exit_cell)

func _bfs_dist(start: Vector2i) -> Dictionary:
    var d := {start: 0}
    var q: Array[Vector2i] = [start]
    var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
    var i := 0
    while i < q.size():
        var c = q[i]
        i += 1
        for dir in dirs:
            var n = c + dir
            if n.x >= 0 and n.y >= 0 and n.x < GRID and n.y < GRID and not maze[n.y][n.x] and not d.has(n):
                d[n] = int(d[c]) + 1
                q.append(n)
    return d

func _build_astar():
    astar.region = Rect2i(0, 0, GRID, GRID)
    astar.cell_size = Vector2(CELL, CELL)
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    astar.update()
    for y in range(GRID):
        for x in range(GRID):
            if maze[y][x]:
                astar.set_point_solid(Vector2i(x,y), true)

func _setup_environment():
    var world = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.003, 0.005, 0.009)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.055, 0.07, 0.095)
    env.ambient_light_energy = 0.42
    # Forward+ high-end effects: deliberately not the Mobile/Compatibility renderer.
    env.fog_enabled = true
    env.fog_density = 0.010
    env.fog_light_color = Color(0.075, 0.095, 0.135)
    env.fog_light_energy = 0.52
    env.volumetric_fog_enabled = true
    env.volumetric_fog_density = 0.021
    env.volumetric_fog_albedo = Color(0.70, 0.77, 0.88)
    env.volumetric_fog_emission = Color(0.012, 0.018, 0.032)
    env.volumetric_fog_emission_energy = 0.62
    env.volumetric_fog_anisotropy = 0.35
    env.volumetric_fog_length = 42.0
    env.volumetric_fog_detail_spread = 2.4
    env.volumetric_fog_temporal_reprojection_enabled = true
    env.ssao_enabled = true
    env.ssao_radius = 1.7
    env.ssao_intensity = 2.35
    env.ssao_power = 1.35
    env.ssil_enabled = true
    env.ssil_radius = 3.2
    env.ssil_intensity = 1.18
    env.ssr_enabled = true
    env.ssr_max_steps = 64
    env.ssr_fade_in = 0.10
    env.ssr_fade_out = 2.2
    env.sdfgi_enabled = true
    env.sdfgi_use_occlusion = true
    env.sdfgi_bounce_feedback = 0.55
    env.glow_enabled = true
    env.glow_intensity = 0.86
    env.glow_bloom = 0.22
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.tonemap_exposure = 1.10
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.10
    env.adjustment_saturation = 0.91
    world.environment = env
    add_child(world)

func _build_level():
    # floor
    var floor_mesh = MeshInstance3D.new()
    var pm = PlaneMesh.new()
    pm.size = Vector2(GRID * CELL, GRID * CELL)
    pm.subdivide_width = GRID
    pm.subdivide_depth = GRID
    floor_mesh.mesh = pm
    floor_mesh.material_override = mat_floor
    floor_mesh.position.y = 0.0
    add_child(floor_mesh)

    var floor_body = StaticBody3D.new()
    floor_body.collision_layer = 1
    var floor_col = CollisionShape3D.new()
    var floor_shape = BoxShape3D.new()
    floor_shape.size = Vector3(GRID * CELL, 0.25, GRID * CELL)
    floor_col.shape = floor_shape
    floor_col.position.y = -0.13
    floor_body.add_child(floor_col)
    add_child(floor_body)

    # ceiling
    var ceil_mesh = MeshInstance3D.new()
    var cp = PlaneMesh.new()
    cp.size = Vector2(GRID * CELL, GRID * CELL)
    cp.subdivide_width = GRID
    cp.subdivide_depth = GRID
    ceil_mesh.mesh = cp
    ceil_mesh.material_override = mat_ceiling
    ceil_mesh.rotation_degrees.x = 180
    ceil_mesh.position.y = WALL_H
    add_child(ceil_mesh)

    for y in range(GRID):
        for x in range(GRID):
            if maze[y][x]:
                _add_wall(Vector2i(x,y))
            elif ((x * 17 + y * 31) % 23) == 7:
                _add_light_fixture(Vector2i(x,y), (x + y) % 3)
            elif ((x * 13 + y * 19) % 37) == 11:
                _add_crate(Vector2i(x,y))

    # distinctive signs and pipes: navigation landmarks + detail.
    var open_cells := []
    for y in range(2, GRID-2):
        for x in range(2, GRID-2):
            if not maze[y][x]:
                open_cells.append(Vector2i(x,y))
    for i in range(min(14, open_cells.size())):
        var c: Vector2i = open_cells[(i * 17 + 9) % open_cells.size()]
        _add_pipe(c, i % 2 == 0)
    for i in range(min(6, open_cells.size())):
        var c: Vector2i = open_cells[(i * 29 + 15) % open_cells.size()]
        _add_sign(c)
    for i in range(min(26, open_cells.size())):
        var c: Vector2i = open_cells[(i * 11 + 5) % open_cells.size()]
        _add_grime(c, i)

func _add_wall(c: Vector2i):
    var body = StaticBody3D.new()
    body.collision_layer = 1
    var mi = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(CELL, WALL_H, CELL)
    mi.mesh = mesh
    mi.material_override = mat_wall_metal if ((c.x * 5 + c.y * 7) % 9 < 3) else mat_wall_concrete
    mi.position.y = WALL_H * 0.5
    body.add_child(mi)
    var cs = CollisionShape3D.new()
    var sh = BoxShape3D.new()
    sh.size = Vector3(CELL, WALL_H, CELL)
    cs.shape = sh
    cs.position.y = WALL_H * 0.5
    body.add_child(cs)
    body.position = cell_to_world(c)
    add_child(body)

func _add_light_fixture(c: Vector2i, kind: int):
    var p = cell_to_world(c)
    var fixture = MeshInstance3D.new()
    var bm = BoxMesh.new()
    bm.size = Vector3(1.1, 0.08, 0.28)
    fixture.mesh = bm
    var em = StandardMaterial3D.new()
    var colors = [Color(0.18,0.62,1.0), Color(1.0,0.20,0.08), Color(1.0,0.65,0.18)]
    em.albedo_color = colors[kind]
    em.emission_enabled = true
    em.emission = colors[kind]
    em.emission_energy_multiplier = 3.0
    fixture.material_override = em
    fixture.position = p + Vector3(0, WALL_H - 0.08, 0)
    add_child(fixture)

    var light = OmniLight3D.new()
    light.position = p + Vector3(0, WALL_H - 0.35, 0)
    light.omni_range = 9.0
    light.light_color = colors[kind]
    light.light_energy = 2.5
    light.shadow_enabled = ((c.x + c.y) % 4 == 0)
    add_child(light)
    flicker_lights.append([light, rng.randf_range(0.0, 6.28), 2.5])

func _add_crate(c: Vector2i):
    var mi = MeshInstance3D.new()
    var b = BoxMesh.new()
    b.size = Vector3(0.8, 0.8, 0.8)
    mi.mesh = b
    mi.material_override = mat_dark_metal
    mi.position = cell_to_world(c) + Vector3(rng.randf_range(-1.1,1.1),0.4,rng.randf_range(-1.1,1.1))
    mi.rotation.y = rng.randf_range(0, PI)
    add_child(mi)

func _add_pipe(c: Vector2i, along_x: bool):
    var mi = MeshInstance3D.new()
    var cy = CylinderMesh.new()
    cy.top_radius = 0.12
    cy.bottom_radius = 0.12
    cy.height = CELL * 0.88
    cy.radial_segments = 12
    mi.mesh = cy
    mi.material_override = mat_pipe
    mi.position = cell_to_world(c) + Vector3(0, WALL_H - 0.48, 0)
    mi.rotation_degrees.z = 90 if along_x else 0
    if not along_x:
        mi.rotation_degrees.x = 90
    add_child(mi)

func _add_sign(c: Vector2i):
    var mi = MeshInstance3D.new()
    var q = QuadMesh.new()
    q.size = Vector2(1.6, 1.0)
    mi.mesh = q
    var m = StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/textures/sign.png")
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.emission_enabled = true
    m.emission_texture = load("res://assets/textures/sign.png")
    m.emission_energy_multiplier = 1.5
    mi.material_override = m
    var p = cell_to_world(c)
    mi.position = p + Vector3(0, 1.8, -1.85)
    add_child(mi)

func _add_grime(c: Vector2i, idx: int):
    var mi = MeshInstance3D.new()
    var q = QuadMesh.new()
    q.size = Vector2(rng.randf_range(0.8, 2.2), rng.randf_range(0.6, 1.8))
    mi.mesh = q
    var m = StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/textures/grime.png")
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = m
    mi.position = cell_to_world(c) + Vector3(rng.randf_range(-1.0,1.0), 0.012, rng.randf_range(-1.0,1.0))
    mi.rotation_degrees.x = -90.0
    mi.rotation_degrees.y = rng.randf_range(0.0, 360.0)
    add_child(mi)

func _spawn_player():
    player = CharacterBody3D.new()
    player.set_script(load("res://scripts/player.gd"))
    player.game = self
    add_child(player)
    player.global_position = cell_to_world(Vector2i(1,1)) + Vector3(0, 1.0, 0)

func _spawn_enemies():
    var dist = _bfs_dist(Vector2i(1,1))
    var candidates: Array[Vector2i] = []
    for y in range(1, GRID-1):
        for x in range(1, GRID-1):
            var c = Vector2i(x,y)
            if not maze[y][x] and c != exit_cell and dist.has(c) and int(dist[c]) > 12:
                candidates.append(c)
    candidates.sort_custom(func(a, b): return int(dist[a]) > int(dist[b]))
    var chosen: Array[Vector2i] = []
    for c in candidates:
        var ok := true
        for used in chosen:
            if abs(c.x-used.x) + abs(c.y-used.y) < 5:
                ok = false
                break
        if ok:
            chosen.append(c)
        if chosen.size() >= ENEMY_COUNT:
            break
    while chosen.size() < ENEMY_COUNT and not candidates.is_empty():
        var c = candidates[rng.randi_range(0, candidates.size()-1)]
        if not chosen.has(c):
            chosen.append(c)
    enemies_left = chosen.size()
    for i in range(chosen.size()):
        var e = CharacterBody3D.new()
        e.set_script(load("res://scripts/enemy.gd"))
        e.game = self
        e.target = player
        e.variant = i % 3
        add_child(e)
        e.global_position = cell_to_world(chosen[i]) + Vector3(0, 0.95, 0)

func _make_exit():
    exit_door = Node3D.new()
    exit_door.position = exit_pos
    var vertical = false
    var up = exit_cell + Vector2i(0,-1)
    var down = exit_cell + Vector2i(0,1)
    if up.y >= 0 and down.y < GRID:
        vertical = (not maze[up.y][up.x]) or (not maze[down.y][down.x])

    var mi = MeshInstance3D.new()
    var b = BoxMesh.new()
    b.size = Vector3(CELL * 0.9, 3.1, 0.28) if vertical else Vector3(0.28, 3.1, CELL * 0.9)
    mi.mesh = b
    mi.material_override = mat_exit_locked
    mi.position.y = 1.55
    mi.name = "DoorMesh"
    exit_door.add_child(mi)

    var door_body = StaticBody3D.new()
    door_body.collision_layer = 1
    exit_collision = CollisionShape3D.new()
    var sh = BoxShape3D.new()
    sh.size = b.size
    exit_collision.shape = sh
    exit_collision.position.y = 1.55
    door_body.add_child(exit_collision)
    exit_door.add_child(door_body)

    var l = OmniLight3D.new()
    l.name = "DoorLight"
    l.light_color = Color(1.0,0.03,0.01)
    l.light_energy = 4.0
    l.omni_range = 9.0
    l.position.y = 2.2
    exit_door.add_child(l)
    add_child(exit_door)

func _make_hud():
    hud = Control.new()
    hud.set_script(load("res://scripts/hud.gd"))
    hud.game = self
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var layer = CanvasLayer.new()
    layer.layer = 10
    layer.add_child(hud)
    add_child(layer)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _start_music():
    var music = AudioStreamPlayer.new()
    music.stream = load("res://assets/audio/music.wav")
    music.volume_db = -8.0
    music.finished.connect(func(): music.play())
    add_child(music)
    music.play()

func play_sfx(path: String, db := 0.0):
    var p = AudioStreamPlayer.new()
    p.stream = load(path)
    p.volume_db = db
    add_child(p)
    p.finished.connect(p.queue_free)
    p.play()

func enemy_killed(enemy):
    enemies_left = max(0, enemies_left - 1)
    _spawn_death_flash(enemy.global_position)
    if enemies_left == 0:
        _unlock_exit()

func _spawn_death_flash(pos: Vector3):
    var light = OmniLight3D.new()
    light.light_color = Color(1.0, 0.08, 0.015)
    light.light_energy = 5.0
    light.omni_range = 5.5
    light.position = pos + Vector3(0,0.8,0)
    add_child(light)
    var tw = create_tween()
    tw.tween_property(light, "light_energy", 0.0, 0.35)
    tw.tween_callback(light.queue_free)

func _unlock_exit():
    play_sfx("res://assets/audio/unlock.wav", -2.0)
    var mi = exit_door.get_node("DoorMesh")
    mi.material_override = mat_exit_open
    var l = exit_door.get_node("DoorLight")
    l.light_color = Color(0.02,1.0,0.10)
    l.light_energy = 5.0
    if exit_collision:
        exit_collision.disabled = true
    var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_property(mi, "position:y", 4.1, 1.0)

func player_died():
    if won:
        return
    get_tree().reload_current_scene()

func _win():
    won = true
    if player:
        player.controls_enabled = false
    play_sfx("res://assets/audio/unlock.wav", -1.0)

func find_path(from_world: Vector3, to_world: Vector3) -> Array:
    var a = world_to_cell(from_world)
    var b = world_to_cell(to_world)
    if astar.is_point_solid(a) or astar.is_point_solid(b):
        return []
    var ids = astar.get_id_path(a,b)
    var out := []
    for id in ids:
        out.append(cell_to_world(id) + Vector3(0,0.95,0))
    return out

func cell_to_world(c: Vector2i) -> Vector3:
    return Vector3((c.x - GRID * 0.5 + 0.5) * CELL, 0, (c.y - GRID * 0.5 + 0.5) * CELL)

func world_to_cell(p: Vector3) -> Vector2i:
    var x = int(round(p.x / CELL + GRID * 0.5 - 0.5))
    var y = int(round(p.z / CELL + GRID * 0.5 - 0.5))
    return Vector2i(clamp(x,0,GRID-1), clamp(y,0,GRID-1))
