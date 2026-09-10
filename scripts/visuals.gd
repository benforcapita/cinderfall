extends RefCounted
const Icons = preload("res://scripts/icons.gd")

static func loot_model(parent: Node3D) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	for slot in range(3):
		var model = Node3D.new()
		root.add_child(model)
		match slot:
			0:
				box(model, Vector3(0, 0.32, 0), Vector3(0.12, 0.7, 0.12), Color("cfdee5"))
				box(model, Vector3(0, 0.02, 0), Vector3(0.42, 0.12, 0.14), Color("e8bd79"))
				box(model, Vector3(0, -0.15, 0), Vector3(0.12, 0.28, 0.12), Color("906440"))
			1:
				box(model, Vector3(0, 0.12, 0), Vector3(0.5, 0.55, 0.22), Color("91b6c4"))
				box(model, Vector3(0, 0.3, 0), Vector3(0.8, 0.2, 0.28), Color("cfdee5"))
				box(model, Vector3(0, 0.12, 0.14), Vector3(0.12, 0.5, 0.06), Color("e8bd79"))
			2:
				for side in [-1, 1]:
					box(model, Vector3(side * 0.22, 0, 0), Vector3(0.1, 0.45, 0.12), Color("e8bd79"))
					box(model, Vector3(0, side * 0.22, 0), Vector3(0.45, 0.1, 0.12), Color("e8bd79"))
				var gem = box(model, Vector3(0, 0.28, 0), Vector3(0.23, 0.23, 0.2), Color("c69bff"))
				gem.rotation.z = PI / 4
	var frame = Node3D.new()
	root.add_child(frame)
	for side in [-1, 1]:
		box(frame, Vector3(side * 0.45, -0.3, 0), Vector3(0.05, 0.04, 0.9), Color.WHITE)
		box(frame, Vector3(0, -0.3, side * 0.45), Vector3(0.9, 0.04, 0.05), Color.WHITE)
	return root

static func style_loot(root: Node3D, slot: String, rarity: int) -> void:
	for i in range(3): root.get_child(i).visible = ["weapon", "armor", "accessory"][i] == slot
	var tint = material(Icons.rarity_color(rarity), true)
	for bar in root.get_child(3).get_children(): bar.material_override = tint

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = at
	return mesh

static func sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	mesh.mesh = shape
	mesh.material_override = material(color, true)
	parent.add_child(mesh)
	mesh.position = at
	return mesh

static func ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = radius - 0.06
	torus.outer_radius = radius + 0.06
	torus.rings = 32
	torus.ring_segments = 6
	mesh.mesh = torus
	mesh.material_override = material(color, true)
	parent.add_child(mesh)
	mesh.position.y = 0.08
	return mesh
