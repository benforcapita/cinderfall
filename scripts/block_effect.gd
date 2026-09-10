extends Node3D
const V = preload("res://scripts/visuals.gd")
const Icons = preload("res://scripts/icons.gd")
var blocks: Array = []
var tint: StandardMaterial3D
var kind = "nova"
var radius = 1.0

func _ready() -> void:
	tint = V.material(Color.WHITE, true)
	for i in range(12):
		var block = V.box(self, Vector3.ZERO, Vector3.ONE, Color.WHITE)
		block.material_override = tint
		blocks.append(block)
	visible = false

func configure(id: String, reach: float, direction: Vector3) -> void:
	kind = id
	radius = reach
	rotation.y = atan2(-direction.x, -direction.z)
	tint.albedo_color = Icons.ability_color(id)
	visible = true
	tick(0)

func tick(progress: float) -> void:
	visible = progress < 1.0
	if not visible: return
	var shrink = maxf(0.01, 1.0 - progress)
	for i in range(blocks.size()):
		var block = blocks[i]
		var angle = i * TAU / 12
		block.rotation = Vector3.ZERO
		match kind:
			"slash":
				angle = -1.15 + i * 2.3 / 11 + progress * 0.45
				block.position = Vector3(sin(angle), 0.3, -cos(angle)) * radius * (0.65 + progress * 0.35)
				block.rotation.y = -angle
				block.scale = Vector3(0.48, 0.10, 0.2) * shrink
			"mend":
				block.position = Vector3(cos(angle) * 0.85, progress * 2.8 + (i % 3) * 0.15, sin(angle) * 0.85)
				block.rotation = Vector3(progress, angle, progress)
				block.scale = Vector3.ONE * (0.17 + (i % 2) * 0.09) * shrink
			"ember":
				block.position = Vector3(cos(angle) * progress * 0.8, 0.7 + sin(angle) * progress * 0.8, -progress * radius)
				block.scale = Vector3.ONE * 0.25 * shrink
			_:
				block.position = Vector3(cos(angle), 0, sin(angle)) * radius * (0.12 + progress * 0.88)
				block.position.y = sin(progress * PI) * (0.3 + (i % 3) * 0.2)
				block.rotation = Vector3(progress * 2, -angle, progress)
				block.scale = Vector3(0.55, 0.18, 0.35) * shrink
