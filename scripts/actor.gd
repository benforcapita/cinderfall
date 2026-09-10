extends CharacterBody3D
const V = preload("res://scripts/visuals.gd")
var hp = 100.0
var maximum = 100.0
var kind = "hero"
var active = false
var elite = false
var phase = 1
var cooldown = 0.0
var windup = 0.0
var stagger = 0.0
var state = "dormant"
var aim = Vector3.FORWARD
var body: Node3D
var health_label: Label3D
var warning_ring: MeshInstance3D
var flash = 0.0
var navigation: NavigationAgent3D
var weapon_pivot: Node3D
var legs: Array = []
var attack_time = 0.0
var attack_duration = 0.0
var anticipation = 0.0
var attack_kind = "slash"
var death_time = 0.0
var gait = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.5
	collider.shape = shape
	collider.position.y = 0.75
	add_child(collider)
	navigation = NavigationAgent3D.new()
	navigation.path_desired_distance = 0.5
	navigation.target_desired_distance = 0.8
	add_child(navigation)
	body = Node3D.new()
	add_child(body)
	V.box(body, Vector3(0, 0.85, 0), Vector3(0.7, 0.85, 0.45), Color("486d7d"))
	V.box(body, Vector3(0, 1.5, 0), Vector3(0.42, 0.44, 0.42), Color("d6cbb4"))
	for side in [-1, 1]:
		var leg = Node3D.new()
		body.add_child(leg)
		leg.position = Vector3(side * 0.24, 0.48, 0)
		V.box(leg, Vector3(0, -0.24, 0), Vector3(0.22, 0.48, 0.3), Color("343747"))
		legs.append(leg)
	weapon_pivot = Node3D.new()
	body.add_child(weapon_pivot)
	weapon_pivot.position = Vector3(0.45, 1.0, 0)
	V.box(weapon_pivot, Vector3(0, -0.12, -0.12), Vector3(0.25, 0.38, 0.25), Color("667c8e"))
	V.box(weapon_pivot, Vector3(0, -0.2, -0.65), Vector3(0.14, 0.12, 1.0), Color("e6eff0"))
	V.box(weapon_pivot, Vector3(0, -0.2, -0.25), Vector3(0.45, 0.16, 0.14), Color("f5d9a0"))
	V.box(body, Vector3(-0.5, 0.9, 0), Vector3(0.15, 0.65, 0.6), Color("667c8e"))
	warning_ring = V.ring(self, 1.0, Color("ff825c"))
	warning_ring.visible = false
	health_label = Label3D.new()
	health_label.position.y = 2.2
	health_label.font_size = 28
	health_label.pixel_size = 0.012
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(health_label)
	visible = false

func activate(actor_kind: String, at: Vector3, health: float, color: Color, is_elite: bool = false) -> void:
	kind = actor_kind
	position = at
	hp = health
	maximum = health
	elite = is_elite
	phase = 1
	cooldown = 0.7
	windup = 0
	stagger = 0
	state = "acquire"
	active = true
	visible = true
	velocity = Vector3.ZERO
	attack_time = 0
	death_time = 0
	flash = 0
	gait = 0
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	weapon_pivot.rotation = Vector3.ZERO
	for leg in legs: leg.rotation = Vector3.ZERO
	body.scale = Vector3.ONE * (1.9 if kind == "boss" else (1.3 if kind == "brute" or elite else 1.0))
	body.get_child(0).material_override = V.material(color)
	health_label.position.y = 3.7 if kind == "boss" else 2.2
	update_health()

func hurt(amount: float) -> bool:
	if not active: return false
	hp = maxf(0, hp - amount)
	flash = 0.13
	update_health()
	if hp <= 0:
		attack_time = 0
		active = false
		death_time = 0.5
		state = "dead"
		warning_ring.visible = false
		return true
	return false

func update_health() -> void:
	health_label.text = "" if kind == "hero" else ("◆ " if elite else "") + str(int(hp))
	health_label.modulate = Color("ffd49a") if elite else Color("f5d5c7")

func move_intent(direction: Vector3, speed: float, delta: float) -> void:
	velocity = velocity.move_toward(direction * speed, delta * 35)
	move_and_slide()
	position.x = clampf(position.x, -8.4, 8.4)
	position.z = clampf(position.z, -8.4, 8.4)
	position.y = 0
	if direction.length() > 0.1 and attack_time <= 0:
		aim = direction.normalized()
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-aim.x, -aim.z), delta * 14)

func animate_attack(id: String, windup_seconds: float, recovery_seconds: float) -> void:
	attack_kind = id
	anticipation = maxf(0.01, windup_seconds)
	attack_duration = anticipation + maxf(0.12, recovery_seconds)
	attack_time = attack_duration

func tick_visual(delta: float) -> void:
	if not visible: return
	var base = 1.9 if kind == "boss" else (1.3 if kind == "brute" or elite else 1.0)
	if not active:
		death_time = maxf(0, death_time - delta)
		var progress = 1.0 - death_time / 0.5
		body.rotation.z = progress * 1.4
		body.position.y = -progress * 0.5
		body.scale = Vector3.ONE * base * (1.0 - progress * 0.8)
		visible = death_time > 0
		return
	gait += delta * velocity.length() * 2.8
	var stride = minf(1, velocity.length() / 2.0)
	legs[0].rotation.x = sin(gait) * 0.65 * stride
	legs[1].rotation.x = -sin(gait) * 0.65 * stride
	body.position.y = absf(sin(gait)) * 0.09 * stride
	body.rotation.z = sin(gait * 0.5) * 0.035 * stride
	attack_time = maxf(0, attack_time - delta)
	weapon_pivot.rotation = Vector3.ZERO
	if attack_time > 0:
		var elapsed = attack_duration - attack_time
		var pose = elapsed / anticipation if elapsed < anticipation else maxf(0, 1.0 - (elapsed - anticipation) / (attack_duration - anticipation))
		if attack_kind == "slash":
			weapon_pivot.rotation.y = -1.6 * pose if elapsed < anticipation else 1.8 * pose
			body.rotation.z = -0.16 * pose
		elif attack_kind == "ember":
			weapon_pivot.rotation.x = -0.8 * pose
		else:
			weapon_pivot.rotation.z = -1.6 * pose
			body.position.y += 0.12 * pose
	flash = maxf(0, flash - delta)
	body.scale = Vector3(base * (1.12 if flash > 0 else 1.0), base * (0.84 if flash > 0 else 1.0), base)
	if flash > 0: body.rotation.z = -0.18
