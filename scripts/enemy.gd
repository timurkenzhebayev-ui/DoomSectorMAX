extends CharacterBody3D

var game
var target
var variant := 0
var hp := 3
var repath := 0.0
var attack_cd := 0.0
var path: Array = []
var path_index := 1
var body_root: Node3D
var alive := true
var mat_body: StandardMaterial3D

func _ready():
    collision_layer = 2
    collision_mask = 1
    add_to_group("enemies")
    var cs = CollisionShape3D.new()
    var cap = CapsuleShape3D.new()
    cap.radius = 0.44
    cap.height = 1.8
    cs.shape = cap
    add_child(cs)
    _build_model()

func _physics_process(delta):
    if not alive or not is_instance_valid(target):
        return
    repath -= delta
    attack_cd = max(0.0, attack_cd - delta)
    if repath <= 0.0:
        repath = 0.38 + randf() * 0.15
        path = game.find_path(global_position, target.global_position)
        path_index = 1 if path.size() > 1 else 0
    var dist = global_position.distance_to(target.global_position)
    if dist < 1.5:
        velocity.x = move_toward(velocity.x,0.0,delta*12.0)
        velocity.z = move_toward(velocity.z,0.0,delta*12.0)
        if attack_cd <= 0.0:
            attack_cd = 0.85
            target.take_damage(13)
    else:
        var goal = target.global_position
        if path.size() > path_index:
            goal = path[path_index]
            if global_position.distance_to(goal) < 0.7 and path_index < path.size()-1:
                path_index += 1
                goal = path[path_index]
        var dir = goal - global_position
        dir.y = 0
        if dir.length() > 0.05:
            dir = dir.normalized()
            var speed = 2.25 + variant * 0.12
            velocity.x = move_toward(velocity.x, dir.x * speed, delta * 8.0)
            velocity.z = move_toward(velocity.z, dir.z * speed, delta * 8.0)
            look_at(global_position + Vector3(dir.x,0,dir.z), Vector3.UP)
    velocity.y = 0
    move_and_slide()
    if body_root:
        var tm = Time.get_ticks_msec() * 0.001
        body_root.position.y = sin(tm * 6.5 + float(get_instance_id()%10)) * 0.035
        body_root.rotation.z = sin(tm * 3.2) * 0.025

func take_damage(amount: int):
    if not alive:
        return
    hp -= amount
    game.play_sfx("res://assets/audio/enemy_hurt.wav", -6.0)
    var old = mat_body.albedo_color
    mat_body.albedo_color = Color(0.9,0.06,0.025)
    get_tree().create_timer(0.09).timeout.connect(func():
        if is_instance_valid(self) and alive: mat_body.albedo_color = old
    )
    if hp <= 0:
        _die()

func _die():
    alive = false
    game.play_sfx("res://assets/audio/enemy_die.wav", -2.0)
    game.enemy_killed(self)
    collision_layer = 0
    collision_mask = 0
    var tw = create_tween().set_parallel(true)
    tw.tween_property(self,"scale",Vector3(1.1,0.08,1.1),0.3)
    tw.tween_property(self,"rotation:x",deg_to_rad(78.0),0.3)
    tw.chain().tween_callback(queue_free)

func _build_model():
    body_root = Node3D.new()
    add_child(body_root)

    mat_body = StandardMaterial3D.new()
    var body_colors = [Color(0.16,0.20,0.14), Color(0.22,0.075,0.055), Color(0.055,0.13,0.19)]
    mat_body.albedo_color = body_colors[variant]
    mat_body.roughness = 0.48
    mat_body.metallic = 0.18

    var armor = StandardMaterial3D.new()
    armor.albedo_color = Color(0.035,0.040,0.045)
    armor.metallic = 0.78
    armor.roughness = 0.28

    var flesh = StandardMaterial3D.new()
    flesh.albedo_color = Color(0.20,0.055,0.035)
    flesh.roughness = 0.72

    var eye = StandardMaterial3D.new()
    eye.albedo_color = Color(1.0,0.025,0.004)
    eye.emission_enabled = true
    eye.emission = Color(1.0,0.005,0.0)
    eye.emission_energy_multiplier = 9.0

    var vein = StandardMaterial3D.new()
    vein.albedo_color = Color(0.9,0.055,0.01)
    vein.emission_enabled = true
    vein.emission = Color(1.0,0.015,0.0)
    vein.emission_energy_multiplier = 4.5

    _part_sphere(Vector3(0,0.22,0),0.49,mat_body,Vector3(1.0,1.25,0.72))
    _part_box(Vector3(0,0.30,-0.30),Vector3(0.72,0.42,0.12),armor,Vector3(-8,0,0))
    _part_box(Vector3(0,0.05,-0.37),Vector3(0.52,0.08,0.05),vein)
    _part_sphere(Vector3(0,0.95,-0.02),0.34,armor,Vector3(0.95,1.04,0.92))
    _part_box(Vector3(0,0.76,-0.29),Vector3(0.34,0.16,0.24),flesh,Vector3(10,0,0))
    _part_box(Vector3(0,0.74,-0.425),Vector3(0.25,0.035,0.03),vein)
    _part_sphere(Vector3(-0.12,0.99,-0.30),0.055,eye)
    _part_sphere(Vector3(0.12,0.99,-0.30),0.055,eye)
    _part_cyl(Vector3(-0.23,1.22,-0.01),0.052,0.48,armor,Vector3(0,0,-31))
    _part_cyl(Vector3(0.23,1.22,-0.01),0.052,0.48,armor,Vector3(0,0,31))
    _part_cyl(Vector3(-0.47,0.52,0.02),0.06,0.34,armor,Vector3(0,0,-58))
    _part_cyl(Vector3(0.47,0.52,0.02),0.06,0.34,armor,Vector3(0,0,58))
    _part_cyl(Vector3(-0.48,0.12,0),0.14,0.78,mat_body,Vector3(0,0,10))
    _part_cyl(Vector3(0.48,0.12,0),0.14,0.78,mat_body,Vector3(0,0,-10))
    _part_box(Vector3(-0.53,-0.14,-0.03),Vector3(0.22,0.36,0.22),armor)
    _part_box(Vector3(0.53,-0.14,-0.03),Vector3(0.22,0.36,0.22),armor)
    for sx in [-1.0, 1.0]:
        for j in range(3):
            _part_cyl(Vector3(0.60*sx,-0.39,-0.15 + j*0.105),0.022,0.22,armor,Vector3(72,0,12*sx))
    _part_cyl(Vector3(-0.21,-0.55,0),0.16,0.76,mat_body,Vector3(0,0,-3))
    _part_cyl(Vector3(0.21,-0.55,0),0.16,0.76,mat_body,Vector3(0,0,3))
    _part_box(Vector3(-0.21,-0.92,-0.11),Vector3(0.32,0.20,0.48),armor)
    _part_box(Vector3(0.21,-0.92,-0.11),Vector3(0.32,0.20,0.48),armor)
    _part_box(Vector3(-0.18,0.34,-0.375),Vector3(0.035,0.28,0.025),vein,Vector3(0,0,-18))
    _part_box(Vector3(0.16,0.30,-0.375),Vector3(0.035,0.24,0.025),vein,Vector3(0,0,14))

    var glow = OmniLight3D.new()
    glow.light_color = Color(1.0,0.035,0.006)
    glow.light_energy = 1.25
    glow.omni_range = 2.2
    glow.position = Vector3(0,0.65,-0.25)
    body_root.add_child(glow)

func _part_box(pos: Vector3,size: Vector3,mat: Material,rot := Vector3.ZERO):
    var mi=MeshInstance3D.new()
    var b=BoxMesh.new()
    b.size=size
    mi.mesh=b
    mi.material_override=mat
    mi.position=pos
    mi.rotation_degrees=rot
    body_root.add_child(mi)

func _part_sphere(pos: Vector3,r: float,mat: Material,scale_v := Vector3.ONE):
    var mi=MeshInstance3D.new()
    var sp=SphereMesh.new()
    sp.radius=r
    sp.height=r*2.0
    sp.radial_segments=24
    sp.rings=12
    mi.mesh=sp
    mi.material_override=mat
    mi.position=pos
    mi.scale=scale_v
    body_root.add_child(mi)

func _part_cyl(pos: Vector3,r: float,h: float,mat: Material,rot: Vector3):
    var mi=MeshInstance3D.new()
    var c=CylinderMesh.new()
    c.top_radius=r*0.45
    c.bottom_radius=r
    c.height=h
    c.radial_segments=14
    mi.mesh=c
    mi.material_override=mat
    mi.position=pos
    mi.rotation_degrees=rot
    body_root.add_child(mi)
