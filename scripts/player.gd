extends CharacterBody3D

var game
var camera: Camera3D
var gun: Node3D
var muzzle_light: OmniLight3D
var muzzle_mesh: MeshInstance3D
var health := 100
var controls_enabled := true
var touch_move := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var shoot_cooldown := 0.0
var recoil := 0.0
var damage_flash := 0.0

const SPEED := 5.5
const ACCEL := 18.0
const LOOK_SENS := 0.0032

func _ready():
    collision_layer = 1
    collision_mask = 3
    var cs = CollisionShape3D.new()
    var cap = CapsuleShape3D.new()
    cap.radius = 0.34
    cap.height = 1.65
    cs.shape = cap
    add_child(cs)

    camera = Camera3D.new()
    camera.position = Vector3(0, 0.55, 0)
    camera.fov = 74.0
    camera.near = 0.06
    add_child(camera)

    var flashlight = SpotLight3D.new()
    flashlight.light_color = Color(0.90, 0.95, 1.0)
    flashlight.light_energy = 5.2
    flashlight.spot_range = 21.0
    flashlight.spot_angle = 34.0
    flashlight.spot_angle_attenuation = 0.75
    flashlight.shadow_enabled = true
    flashlight.position = Vector3(0.16, -0.05, -0.12)
    camera.add_child(flashlight)
    _build_gun()

    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
    shoot_cooldown = max(0.0, shoot_cooldown - delta)
    damage_flash = max(0.0, damage_flash - delta * 2.8)
    recoil = move_toward(recoil, 0.0, delta * 7.0)
    if gun:
        gun.position = Vector3(0.34, -0.30 + recoil * 0.05, -0.72 + recoil * 0.16)
        gun.rotation_degrees.x = recoil * 7.0

    if not controls_enabled:
        velocity.x = move_toward(velocity.x,0.0,ACCEL*delta)
        velocity.z = move_toward(velocity.z,0.0,ACCEL*delta)
        move_and_slide()
        return

    var inp := touch_move
    if not OS.has_feature("mobile"):
        var kb = Vector2.ZERO
        if Input.is_key_pressed(KEY_A): kb.x -= 1.0
        if Input.is_key_pressed(KEY_D): kb.x += 1.0
        if Input.is_key_pressed(KEY_W): kb.y -= 1.0
        if Input.is_key_pressed(KEY_S): kb.y += 1.0
        if kb.length() > 0.0:
            inp = kb.normalized()
    var fwd = -global_transform.basis.z
    var right = global_transform.basis.x
    fwd.y = 0
    right.y = 0
    var dir = (right * inp.x + fwd * -inp.y)
    if dir.length() > 1.0:
        dir = dir.normalized()
    velocity.x = move_toward(velocity.x, dir.x * SPEED, ACCEL * delta)
    velocity.z = move_toward(velocity.z, dir.z * SPEED, ACCEL * delta)
    velocity.y = 0.0
    move_and_slide()

func _input(event):
    if not controls_enabled:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _look(event.relative)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        shoot()
    elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    elif event is InputEventScreenTouch:
        var size = get_viewport().get_visible_rect().size
        var fire_center = Vector2(size.x * 0.885, size.y * 0.77)
        if event.pressed:
            if event.position.distance_to(fire_center) < min(size.x,size.y) * 0.095:
                shoot()
            elif event.position.x < size.x * 0.46:
                if move_touch == -1:
                    move_touch = event.index
                    move_origin = event.position
                    touch_move = Vector2.ZERO
            elif look_touch == -1:
                look_touch = event.index
        else:
            if event.index == move_touch:
                move_touch = -1
                touch_move = Vector2.ZERO
            if event.index == look_touch:
                look_touch = -1
    elif event is InputEventScreenDrag:
        if event.index == move_touch:
            var v = (event.position - move_origin) / 92.0
            if v.length() > 1.0:
                v = v.normalized()
            touch_move = v
        elif event.index == look_touch:
            _look(event.relative * 0.85)

func _look(rel: Vector2):
    yaw -= rel.x * LOOK_SENS
    pitch = clamp(pitch - rel.y * LOOK_SENS, deg_to_rad(-70), deg_to_rad(70))
    rotation.y = yaw
    camera.rotation.x = pitch

func shoot():
    if shoot_cooldown > 0.0 or not controls_enabled:
        return
    shoot_cooldown = 0.22
    recoil = 1.0
    game.play_sfx("res://assets/audio/shot.wav", -1.0)
    muzzle_light.visible = true
    muzzle_mesh.visible = true
    get_tree().create_timer(0.045).timeout.connect(func():
        if is_instance_valid(muzzle_light): muzzle_light.visible = false
        if is_instance_valid(muzzle_mesh): muzzle_mesh.visible = false
    )
    var from = camera.global_position
    var to = from + (-camera.global_transform.basis.z) * 70.0
    var q = PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [get_rid()]
    q.collide_with_areas = false
    var hit = get_world_3d().direct_space_state.intersect_ray(q)
    if not hit.is_empty():
        var c = hit.get("collider")
        if c and c.has_method("take_damage"):
            c.take_damage(1)
            game.play_sfx("res://assets/audio/hit.wav", -4.0)

func take_damage(amount: int):
    if not controls_enabled:
        return
    health = max(0, health - amount)
    damage_flash = 1.0
    game.play_sfx("res://assets/audio/damage.wav", -5.0)
    if health <= 0:
        controls_enabled = false
        get_tree().create_timer(0.6).timeout.connect(game.player_died)

func _build_gun():
    gun = Node3D.new()
    gun.position = Vector3(0.34,-0.30,-0.72)
    camera.add_child(gun)

    var metal = StandardMaterial3D.new()
    metal.albedo_color = Color(0.075,0.085,0.095)
    metal.metallic = 0.92
    metal.roughness = 0.18
    var grip_mat = StandardMaterial3D.new()
    grip_mat.albedo_color = Color(0.028,0.030,0.032)
    grip_mat.metallic = 0.25
    grip_mat.roughness = 0.55

    _gun_box(Vector3(0,0,0), Vector3(0.22,0.17,0.58), metal)
    _gun_box(Vector3(0,-0.15,0.13), Vector3(0.17,0.32,0.20), grip_mat, Vector3(12,0,0))
    _gun_box(Vector3(0,0.105,-0.02), Vector3(0.19,0.055,0.48), metal)
    _gun_box(Vector3(0,0.105,-0.245), Vector3(0.24,0.035,0.07), metal)
    _gun_box(Vector3(-0.105,0.02,0.10), Vector3(0.025,0.10,0.24), grip_mat)
    _gun_box(Vector3(0.105,0.02,0.10), Vector3(0.025,0.10,0.24), grip_mat)
    var sight_mat = StandardMaterial3D.new()
    sight_mat.albedo_color = Color(0.8,0.04,0.01)
    sight_mat.emission_enabled = true
    sight_mat.emission = Color(1.0,0.01,0.0)
    sight_mat.emission_energy_multiplier = 3.5
    _gun_box(Vector3(0,0.15,-0.18), Vector3(0.035,0.035,0.055), sight_mat)

    var barrel = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = 0.052
    cyl.bottom_radius = 0.052
    cyl.height = 0.46
    cyl.radial_segments = 18
    barrel.mesh = cyl
    barrel.material_override = metal
    barrel.rotation_degrees.x = 90
    barrel.position = Vector3(0,0.01,-0.41)
    gun.add_child(barrel)

    muzzle_mesh = MeshInstance3D.new()
    var sp = SphereMesh.new()
    sp.radius = 0.065
    sp.height = 0.13
    muzzle_mesh.mesh = sp
    var flash = StandardMaterial3D.new()
    flash.albedo_color = Color(1,0.5,0.05)
    flash.emission_enabled = true
    flash.emission = Color(1,0.16,0.01)
    flash.emission_energy_multiplier = 8.0
    muzzle_mesh.material_override = flash
    muzzle_mesh.position = Vector3(0,0.01,-0.66)
    muzzle_mesh.visible = false
    gun.add_child(muzzle_mesh)

    muzzle_light = OmniLight3D.new()
    muzzle_light.light_color = Color(1.0,0.27,0.04)
    muzzle_light.light_energy = 7.0
    muzzle_light.omni_range = 6.0
    muzzle_light.position = Vector3(0,0.01,-0.68)
    muzzle_light.visible = false
    gun.add_child(muzzle_light)

func _gun_box(pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO):
    var mi = MeshInstance3D.new()
    var b = BoxMesh.new()
    b.size = size
    mi.mesh = b
    mi.material_override = mat
    mi.position = pos
    mi.rotation_degrees = rot
    gun.add_child(mi)
