extends Node3D
const V = preload("res://scripts/visuals.gd")
@export_range(0, 7) var variant = 0
var exit_ring: MeshInstance3D
var door: MeshInstance3D

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = variant * 93 + 17
	for x in range(-9, 9, 2):
		for z in range(-9, 9, 2):
			var shade = rng.randf_range(0.12, 0.19)
			V.box(self, Vector3(x + 1, -0.16, z + 1), Vector3(1.97, 0.3, 1.97), Color(shade, shade * 1.1, shade * 1.22))
	for x in [-9.3, 9.3]:
		wall(Vector3(x, 0.7, 0), Vector3(0.5, 1.4, 19))
	for z in [-9.3, 9.3]:
		wall(Vector3(0, 0.7, z), Vector3(19, 1.4, 0.5))
	# Columns sit against the boundary so the combat arena remains navigable.
	for x in [-8.5, 8.5]:
		for z in [-7, -2, 3, 8]:
			V.box(self, Vector3(x, 1.2, z), Vector3(0.9, 2.4, 0.9), Color("303b49"))
			V.box(self, Vector3(x, 2.5, z), Vector3(1.2, 0.3, 1.2), Color("4b5157"))
	for at in [Vector3(-7, 0, -6), Vector3(7, 0, -6), Vector3(-7, 0, 6), Vector3(7, 0, 6)]:
		V.box(self, at + Vector3(0, 0.5, 0), Vector3(0.45, 1, 0.45), Color("46424a"))
		V.sphere(self, at + Vector3(0, 1.2, 0), 0.23, Color("ffbd75"))
		var light = OmniLight3D.new()
		add_child(light)
		light.position = at + Vector3(0, 1.8, 0)
		light.light_color = Color("ffab68")
		light.light_energy = 1.4
		light.omni_range = 5
	var rune = V.ring(self, 2.8 + variant * 0.1, Color("526c72"))
	rune.position.y = 0.025
	for i in range(8):
		var angle = i * TAU / 8 + variant * 0.2
		var mark = V.box(self, Vector3(sin(angle) * 3.3, 0.025, cos(angle) * 3.3), Vector3(0.12, 0.025, 0.6), Color("526c72"))
		mark.rotation.y = angle
	var entrance = Marker3D.new()
	entrance.name = "EntrySocket"
	entrance.position = Vector3(0, 0, 7)
	add_child(entrance)
	var exit = Marker3D.new()
	exit.name = "ExitSocket"
	exit.position = Vector3(0, 0, -7)
	add_child(exit)
	exit_ring = V.ring(self, 1.1, Color("7bdfce"))
	exit_ring.position = exit.position + Vector3(0, 0.1, 0)
	V.box(self, Vector3(-1.5, 1.4, -8.4), Vector3(0.65, 2.8, 0.7), Color("777b79"))
	V.box(self, Vector3(1.5, 1.4, -8.4), Vector3(0.65, 2.8, 0.7), Color("777b79"))
	V.box(self, Vector3(0, 3, -8.4), Vector3(3.7, 0.6, 0.8), Color("777b79"))
	door = V.box(self, Vector3(0, 1.3, -8.4), Vector3(2.5, 2.6, 0.2), Color("734446"))
	set_unlocked(false)
	# These open arena rooms use a pre-authored walkable polygon (no runtime bake).
	var region = NavigationRegion3D.new()
	var navmesh = NavigationMesh.new()
	navmesh.vertices = PackedVector3Array([Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, 8)])
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navmesh
	add_child(region)

func wall(at: Vector3, size: Vector3) -> void:
	V.box(self, at, size, Color("29323f"))
	var body = StaticBody3D.new()
	body.position = at
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func set_unlocked(value: bool) -> void:
	exit_ring.visible = value
	door.visible = not value
