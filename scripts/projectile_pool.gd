extends Node3D
const V = preload("res://scripts/visuals.gd")
var entries: Array = []
var overflows = 0

func _ready() -> void:
	for i in range(40):
		var mesh = V.sphere(self, Vector3.ZERO, 0.18, Color("ffc082"))
		mesh.visible = false
		entries.append({"mesh":mesh, "active":false, "velocity":Vector3.ZERO, "power":0.0, "hostile":false, "life":0.0})

func fire(at: Vector3, direction: Vector3, power: float, hostile: bool) -> bool:
	for p in entries:
		if p.active: continue
		p.active = true
		p.mesh.visible = true
		p.mesh.position = at + Vector3(0, 0.8, 0)
		p.velocity = direction.normalized() * (6.0 if hostile else 15.0)
		p.power = power
		p.hostile = hostile
		p.life = 3.0
		return true
	overflows += 1
	return false

func clear_all() -> void:
	for p in entries:
		p.active = false
		p.mesh.visible = false

func tick(delta: float, hero, enemies: Array, hit: Callable) -> void:
	for p in entries:
		if not p.active: continue
		p.life -= delta
		var before: Vector3 = p.mesh.position
		p.mesh.position += p.velocity * delta
		var targets = [hero] if p.hostile else enemies
		for actor in targets:
			if not actor.active: continue
			var target: Vector3 = actor.position + Vector3(0, 0.8, 0)
			var closest = Geometry3D.get_closest_point_to_segment(target, before, p.mesh.position)
			if target.distance_to(closest) < (1.0 if actor.kind == "boss" else 0.65):
				hit.call(actor, p.power)
				p.life = 0
				break
		if p.life <= 0 or absf(p.mesh.position.x) > 9 or absf(p.mesh.position.z) > 9:
			p.active = false
			p.mesh.visible = false
