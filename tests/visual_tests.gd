extends SceneTree
var failures = 0
var checks = 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + title)
	else: print("PASS: " + title)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://scripts/icons.gd"), "ability and item icon catalog exists")
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await process_frame
	check(actor.has_method("animate_attack"), "actor supports timed attack presentation")
	check(actor.has_method("tick_visual"), "visual lifecycle can advance independently of combat")
	if failures > 0:
		actor.queue_free()
		await process_frame
		quit(1)
		return
	var icons = load("res://scripts/icons.gd")
	var signatures: Array = []
	for id in ["slash", "ember", "nova", "mend", "weapon", "armor", "accessory"]:
		var texture = icons.texture(id)
		check(texture != null and texture.get_width() == 64, id + " has a 64px icon")
		var digest = texture.get_image().get_data().hex_encode()
		check(not signatures.has(digest), id + " has a unique silhouette")
		signatures.append(digest)
		check(texture == icons.texture(id), id + " reuses its cached texture")
	check(icons.rarity_color(0) != icons.rarity_color(1) and icons.rarity_color(1) != icons.rarity_color(2), "rarities have distinct colors")
	actor.activate("hero", Vector3.ZERO, 100, Color.WHITE)
	var root_position = actor.position
	actor.animate_attack("slash", 0.2, 0.3)
	actor.tick_visual(0.1)
	check(absf(actor.weapon_pivot.rotation.y) > 0.1, "slash visibly anticipates impact")
	check(actor.position == root_position and actor.hp == 100, "animation does not change combat position or health")
	actor.tick_visual(0.5)
	check(actor.attack_time == 0 and actor.weapon_pivot.rotation == Vector3.ZERO, "finished attack returns weapon to rest")
	actor.hurt(100)
	check(not actor.active and actor.visible, "dead actor leaves combat immediately but remains visible for death animation")
	actor.tick_visual(0.6)
	check(not actor.visible, "death animation eventually hides pooled actor")
	actor.activate("melee", Vector3.ZERO, 42, Color.RED)
	check(actor.visible and actor.body.rotation.z == 0 and actor.attack_time == 0, "reuse resets death and attack pose")
	actor.animate_attack("slash", 0.55, 0.2)
	actor.hurt(1)
	check(actor.attack_time > 0, "noninterrupting enemy hit preserves attack presentation")
	actor.queue_free()
	await process_frame
	var game = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store = load("res://scripts/profile_store.gd").new("user://visual-test-%d.json" % Time.get_ticks_usec())
	game.profile = game.store.fresh()
	game.start_run(719)
	game.try_cast(0)
	check(game.hero.attack_time > 0, "real casts trigger actor animation")
	game.hit_actor(game.hero, 1)
	check(game.cast_index == -1 and game.hero.attack_time == 0, "interrupted hero cast cancels its animation")
	var enemy = game.enemies[0]
	enemy.activate("melee", game.hero.position + Vector3(1, 0, 0), 42, Color.RED)
	enemy.windup = 0.5
	enemy.animate_attack("slash", 0.5, 0.2)
	game.ground_target = game.hero.position
	game.resolve_effect(load("res://content/skills/nova.tres"), {"kind":"knockback", "stagger":1.5, "distance":0.7})
	check(enemy.windup == 0 and enemy.attack_time == 0, "Nova cancels both enemy windup and animation")
	enemy.stagger = 0
	enemy.windup = 0.3
	enemy.aim = Vector3.RIGHT
	game.tick_enemy(enemy, 0.01)
	check(is_equal_approx(enemy.body.rotation.y, -PI / 2), "enemy facing follows aim while winding up")
	check(game.projectiles.entries[0].mesh.mesh is BoxMesh, "projectiles use block geometry")
	check(game.fx[0].node.has_method("configure"), "pooled effects support distinct ability visuals")
	if game.fx[0].node.has_method("configure"):
		var effect = game.fx[0].node
		for id in ["slash", "ember", "nova", "mend"]:
			effect.configure(id, 3.0, Vector3.FORWARD)
			effect.tick(0.2)
			check(effect.visible and effect.get_child_count() == 12, id + " uses bounded block pool")
			effect.tick(1.0)
			check(not effect.visible, id + " effect expires")
	var sample = {"id":"visual-sword", "slot":"weapon", "name":"Ashsteel blade", "level":1, "rarity":2, "value":5, "affixes":{}}
	game.profile.inventory.append(sample)
	game.show_inventory()
	var buttons = game.modal.find_children("*", "Button", true, false)
	var found = false
	for button in buttons:
		if "Ashsteel" in button.text: found = button.icon != null
	check(found, "inventory items display their icon")
	game.queue_free()
	await process_frame
	print("VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
