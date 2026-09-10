extends RefCounted
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
