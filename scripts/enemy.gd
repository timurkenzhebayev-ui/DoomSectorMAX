extends CharacterBody3D

var game
var player
var health := 3
var attack_cooldown := 0.0
var hurt_timer := 0.0
var phase := 0.0
var activated := false
var dead := false

var body_root: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D
var skin_mat: StandardMaterial3D
var suit_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D

const SPEED := 2.45

func _ready():
    collision_layer = 2
    collision_mask = 1
    phase = randf() * TAU

    var cs = CollisionShape3D.new()
    var cap = CapsuleShape3D.new()
    cap.radius = 0.38
    cap.height = 1.78
    cs.shape = cap
    add_child(cs)

    _build_character()

func _physics_process(delta):
    if dead or not player or not is_instance_valid(player):
        return

    attack_cooldown = max(0.0, attack_cooldown - delta)
    hurt_timer = max(0.0, hurt_timer - delta)

    var to_player = player.global_position - global_position
    var dist = to_player.length()
    var visible = _can_see_player()
    if visible and dist < 13.0:
        activated = true

    var moving = false
    if activated and visible and dist > 1.55:
        var dir = Vector3(to_player.x, 0, to_player.z).normalized()
        velocity.x = dir.x * SPEED
        velocity.z = dir.z * SPEED
        moving = true
        var target_yaw = atan2(-dir.x, -dir.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, delta * 7.0))
    else:
        velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)

    velocity.y = 0.0
    move_and_slide()

    if activated and visible and dist <= 1.65 and attack_cooldown <= 0.0:
        attack_cooldown = 0.85
        player.take_damage(9)
        _attack_anim()

    _animate(delta, moving)

func _can_see_player() -> bool:
    var from = global_position + Vector3(0, 1.15, 0)
    var to = player.camera.global_position
    var q = PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [get_rid()]
    q.collide_with_areas = false
    var hit = get_world_3d().direct_space_state.intersect_ray(q)
    if hit.is_empty():
        return true
    return hit.get("collider") == player

func _animate(delta: float, moving: bool):
    phase += delta * (7.0 if moving else 2.0)
    if body_root:
        body_root.position.y = 0.03 * sin(phase * 2.0)
    var swing = sin(phase) * (0.55 if moving else 0.08)
    if left_arm: left_arm.rotation.x = swing
    if right_arm: right_arm.rotation.x = -swing
    if left_leg: left_leg.rotation.x = -swing * 0.70
    if right_leg: right_leg.rotation.x = swing * 0.70
    if head: head.rotation.y = 0.08 * sin(phase * 0.7)

func _attack_anim():
    if right_arm:
        right_arm.rotation.x = -1.05
        get_tree().create_timer(0.16).timeout.connect(func():
            if is_instance_valid(right_arm): right_arm.rotation.x = 0.0
        )

func take_damage(amount: int):
    if dead:
        return
    health -= amount
    activated = true
    hurt_timer = 0.18
    game.play_sfx("res://assets/audio/enemy_hurt.wav", -6.0)
    game.spawn_blood(global_position + Vector3(0,1.05,0), Vector3.UP, false)
    if health <= 0:
        _die()

func _die():
    if dead:
        return
    dead = true
    collision_layer = 0
    velocity = Vector3.ZERO
    game.play_sfx("res://assets/audio/enemy_die.wav", -5.0)
    game.spawn_blood(global_position + Vector3(0,1.0,0), Vector3.UP, true)
    game.enemy_killed()

    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(body_root, "rotation_degrees:z", 82.0, 0.30)
    tween.tween_property(body_root, "position:y", -0.45, 0.38)
    tween.tween_property(body_root, "scale", Vector3(1.0,0.72,1.0), 0.38)
    get_tree().create_timer(3.0).timeout.connect(func(): queue_free())

func _build_character():
    skin_mat = StandardMaterial3D.new()
    skin_mat.albedo_color = Color(0.32,0.36,0.34)
    skin_mat.roughness = 0.60

    suit_mat = StandardMaterial3D.new()
    suit_mat.albedo_color = Color(0.095,0.12,0.145)
    suit_mat.metallic = 0.18
    suit_mat.roughness = 0.46

    eye_mat = StandardMaterial3D.new()
    eye_mat.albedo_color = Color(0.9,0.03,0.01)
    eye_mat.emission_enabled = true
    eye_mat.emission = Color(1.0,0.015,0.005)
    eye_mat.emission_energy_multiplier = 4.8

    var horn_mat = StandardMaterial3D.new()
    horn_mat.albedo_color = Color(0.055,0.045,0.04)
    horn_mat.roughness = 0.42

    body_root = Node3D.new()
    body_root.position.y = -0.88
    add_child(body_root)

    # Torso and chest armour.
    _box(body_root, Vector3(0,1.18,0), Vector3(0.72,0.82,0.38), suit_mat)
    _box(body_root, Vector3(0,1.36,-0.205), Vector3(0.54,0.30,0.055), _accent_mat())
    _box(body_root, Vector3(0,0.82,0.02), Vector3(0.54,0.22,0.32), suit_mat)

    # Head / jaw / glowing eyes.
    head = Node3D.new(); head.position = Vector3(0,1.86,0); body_root.add_child(head)
    _sphere(head, Vector3.ZERO, Vector3(0.29,0.34,0.28), skin_mat)
    _box(head, Vector3(0,-0.18,-0.17), Vector3(0.34,0.16,0.17), skin_mat)
    _sphere(head, Vector3(-0.105,0.035,-0.245), Vector3(0.042,0.034,0.025), eye_mat)
    _sphere(head, Vector3(0.105,0.035,-0.245), Vector3(0.042,0.034,0.025), eye_mat)
    _horn(head, Vector3(-0.18,0.25,-0.02), -14.0, horn_mat)
    _horn(head, Vector3(0.18,0.25,-0.02), 14.0, horn_mat)

    # Arms with shoulder pivots.
    left_arm = Node3D.new(); left_arm.position = Vector3(-0.48,1.48,0); body_root.add_child(left_arm)
    right_arm = Node3D.new(); right_arm.position = Vector3(0.48,1.48,0); body_root.add_child(right_arm)
    _capsule(left_arm, Vector3(0,-0.34,0), 0.12, 0.72, skin_mat)
    _capsule(right_arm, Vector3(0,-0.34,0), 0.12, 0.72, skin_mat)
    _box(left_arm, Vector3(0,-0.10,0), Vector3(0.29,0.26,0.31), suit_mat)
    _box(right_arm, Vector3(0,-0.10,0), Vector3(0.29,0.26,0.31), suit_mat)
    _sphere(left_arm, Vector3(0,-0.73,-0.02), Vector3(.14,.16,.15), skin_mat)
    _sphere(right_arm, Vector3(0,-0.73,-0.02), Vector3(.14,.16,.15), skin_mat)

    # Legs with hip pivots.
    left_leg = Node3D.new(); left_leg.position = Vector3(-0.20,0.70,0); body_root.add_child(left_leg)
    right_leg = Node3D.new(); right_leg.position = Vector3(0.20,0.70,0); body_root.add_child(right_leg)
    _capsule(left_leg, Vector3(0,-0.38,0), 0.14, 0.82, suit_mat)
    _capsule(right_leg, Vector3(0,-0.38,0), 0.14, 0.82, suit_mat)
    _box(left_leg, Vector3(0,-0.80,-0.08), Vector3(0.27,0.16,0.46), horn_mat)
    _box(right_leg, Vector3(0,-0.80,-0.08), Vector3(0.27,0.16,0.46), horn_mat)

func _accent_mat() -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = Color(0.28,0.065,0.045)
    m.metallic = 0.45
    m.roughness = 0.31
    return m

func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material):
    var mi = MeshInstance3D.new(); var mesh = BoxMesh.new(); mesh.size = size
    mi.mesh = mesh; mi.material_override = mat; mi.position = pos; parent.add_child(mi)

func _sphere(parent: Node, pos: Vector3, scale_v: Vector3, mat: Material):
    var mi = MeshInstance3D.new(); var mesh = SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0
    mesh.radial_segments = 20; mesh.rings = 12
    mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.scale = scale_v * 2.0; parent.add_child(mi)

func _capsule(parent: Node, pos: Vector3, radius: float, height: float, mat: Material):
    var mi = MeshInstance3D.new(); var mesh = CapsuleMesh.new(); mesh.radius = radius; mesh.height = height
    mesh.radial_segments = 16; mesh.rings = 8
    mi.mesh = mesh; mi.material_override = mat; mi.position = pos; parent.add_child(mi)

func _horn(parent: Node, pos: Vector3, tilt: float, mat: Material):
    var mi = MeshInstance3D.new(); var mesh = CylinderMesh.new()
    mesh.top_radius = 0.0; mesh.bottom_radius = 0.075; mesh.height = 0.34; mesh.radial_segments = 12
    mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.rotation_degrees.z = tilt; parent.add_child(mi)
