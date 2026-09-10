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
	V.box(body, Vector3(-0.24, 0.24, 0), Vector3(0.22, 0.48, 0.3), Color("343747"))
	V.box(body, Vector3(0.24, 0.24, 0), Vector3(0.22, 0.48, 0.3), Color("343747"))
	V.box(body, Vector3(0.5, 0.8, -0.3), Vector3(0.12, 0.14, 1.1), Color("f5d9a0"))
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
		active = false
		visible = false
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
	if direction.length() > 0.1:
		aim = direction.normalized()
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-aim.x, -aim.z), delta * 14)
		body.position.y = absf(sin(Time.get_ticks_msec() * 0.012)) * 0.075
	else:
		body.position.y = 0
	flash = maxf(0, flash - delta)
	body.scale.y = (1.9 if kind == "boss" else (1.3 if kind == "brute" or elite else 1.0)) * (0.87 if flash > 0 else 1.0)
