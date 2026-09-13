extends CharacterBody3D

var game
var camera: Camera3D
var gun: Node3D
var muzzle_root: Node3D
var muzzle_light: OmniLight3D
var muzzle_mesh: MeshInstance3D
var health := 100
var controls_enabled := true
var touch_move := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var fire_touch := -1
var move_origin := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var shoot_cooldown := 0.0
var recoil := 0.0
var damage_flash := 0.0

const SPEED := 5.2
const ACCEL := 20.0
const LOOK_SENS := 0.00235
const GUN_BASE := Vector3(0.28, -0.25, -0.50)

func _ready():
    collision_layer = 1
    collision_mask = 1

    var cs = CollisionShape3D.new()
    var cap = CapsuleShape3D.new()
    cap.radius = 0.34
    cap.height = 1.72
    cs.shape = cap
    add_child(cs)

    camera = Camera3D.new()
    camera.position = Vector3(0, 0.63, 0)
    camera.fov = 82.0
    camera.near = 0.045
    add_child(camera)

    _build_weapon()

    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
    shoot_cooldown = max(0.0, shoot_cooldown - delta)
    damage_flash = max(0.0, damage_flash - delta * 3.4)
    recoil = move_toward(recoil, 0.0, delta * 8.5)

    if gun:
        gun.position = GUN_BASE + Vector3(0, recoil * 0.025, recoil * 0.11)
        gun.rotation_degrees.x = recoil * 5.5

    if not controls_enabled:
        velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
        velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
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
    fwd.y = 0.0
    right.y = 0.0
    fwd = fwd.normalized()
    right = right.normalized()
    var dir = right * inp.x + fwd * -inp.y
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
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        shoot()
        return
    if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
        return

    if event is InputEventScreenTouch:
        var size = get_viewport().get_visible_rect().size
        var fire_center = Vector2(size.x * 0.885, size.y * 0.76)
        var fire_radius = min(size.x, size.y) * 0.105

        if event.pressed:
            # Fire is an isolated touch target. It never shares the movement/look finger.
            if event.position.distance_to(fire_center) <= fire_radius and fire_touch == -1:
                fire_touch = event.index
                shoot()
                return

            # Left lower half = movement only. Floating joystick starts exactly under the finger.
            if event.position.x < size.x * 0.44 and event.position.y > size.y * 0.34 and move_touch == -1:
                move_touch = event.index
                move_origin = event.position
                touch_move = Vector2.ZERO
                return

            # Right half, except the fire button = camera look only.
            if event.position.x >= size.x * 0.44 and look_touch == -1:
                look_touch = event.index
                return
        else:
            if event.index == fire_touch:
                fire_touch = -1
            if event.index == move_touch:
                move_touch = -1
                touch_move = Vector2.ZERO
            if event.index == look_touch:
                look_touch = -1
        return

    if event is InputEventScreenDrag:
        if event.index == move_touch:
            var radius = min(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.115
            var v = (event.position - move_origin) / max(1.0, radius)
            if v.length() > 1.0:
                v = v.normalized()
            touch_move = v
        elif event.index == look_touch:
            _look(event.relative)

func _look(rel: Vector2):
    yaw -= rel.x * LOOK_SENS
    pitch = clamp(pitch - rel.y * LOOK_SENS, deg_to_rad(-66.0), deg_to_rad(66.0))
    rotation.y = yaw
    camera.rotation.x = pitch

func shoot():
    if shoot_cooldown > 0.0 or not controls_enabled:
        return
    shoot_cooldown = 0.24
    recoil = 1.0
    Input.vibrate_handheld(18)
    game.play_sfx("res://assets/audio/shot.wav", -2.0)
    _flash_muzzle()

    var from = camera.global_position
    var to = from + (-camera.global_transform.basis.z) * 70.0
    var q = PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [get_rid()]
    q.collide_with_areas = false
    var hit = get_world_3d().direct_space_state.intersect_ray(q)
    if hit.is_empty():
        return

    var collider = hit.get("collider")
    var pos: Vector3 = hit.get("position")
    var normal: Vector3 = hit.get("normal")
    if collider and collider.has_method("take_damage"):
        collider.take_damage(1)
        game.spawn_blood(pos, normal, false)
        game.play_sfx("res://assets/audio/hit.wav", -5.0)
    else:
        game.spawn_sparks(pos, normal)

func _flash_muzzle():
    if not muzzle_mesh or not muzzle_light:
        return
    muzzle_mesh.visible = true
    muzzle_light.visible = true
    get_tree().create_timer(0.055).timeout.connect(func():
        if is_instance_valid(muzzle_mesh): muzzle_mesh.visible = false
        if is_instance_valid(muzzle_light): muzzle_light.visible = false
    )

func take_damage(amount: int):
    if not controls_enabled:
        return
    health = max(0, health - amount)
    damage_flash = 1.0
    Input.vibrate_handheld(35)
    game.play_sfx("res://assets/audio/damage.wav", -7.0)
    if health <= 0:
        controls_enabled = false
        touch_move = Vector2.ZERO
        get_tree().create_timer(0.7).timeout.connect(game.player_died)

func _build_weapon():
    var packed = load("res://assets/models/pistol.glb")
    if packed is PackedScene:
        gun = packed.instantiate()
        gun.position = GUN_BASE
        gun.scale = Vector3.ONE * 3.35
        gun.rotation_degrees = Vector3(0, 0, 0)
        camera.add_child(gun)
    else:
        # Fallback only if the external CC0 model failed to import.
        gun = Node3D.new()
        gun.position = GUN_BASE
        camera.add_child(gun)
        var body = MeshInstance3D.new()
        var b = BoxMesh.new(); b.size = Vector3(.16,.13,.48)
        body.mesh = b
        var m = StandardMaterial3D.new(); m.albedo_color = Color(.08,.09,.10); m.metallic=.9; m.roughness=.2
        body.material_override = m
        gun.add_child(body)

    muzzle_root = Node3D.new()
    muzzle_root.position = Vector3(0.28, -0.20, -0.93)
    camera.add_child(muzzle_root)

    muzzle_mesh = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.055
    sphere.height = 0.11
    muzzle_mesh.mesh = sphere
    var flash = StandardMaterial3D.new()
    flash.albedo_color = Color(1.0, 0.72, 0.18)
    flash.emission_enabled = true
    flash.emission = Color(1.0, 0.24, 0.015)
    flash.emission_energy_multiplier = 8.0
    muzzle_mesh.material_override = flash
    muzzle_mesh.visible = false
    muzzle_root.add_child(muzzle_mesh)

    muzzle_light = OmniLight3D.new()
    muzzle_light.light_color = Color(1.0, 0.42, 0.12)
    muzzle_light.light_energy = 4.5
    muzzle_light.omni_range = 4.2
    muzzle_light.visible = false
    muzzle_root.add_child(muzzle_light)
