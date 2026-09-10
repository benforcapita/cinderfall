extends SceneTree
const Content = preload("res://scripts/content.gd")
const Store = preload("res://scripts/profile_store.gd")
const Combat = preload("res://scripts/combat.gd")
const StatusEffects = preload("res://scripts/status_effects.gd")
var failures = 0
var checks = 0

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + title)
	else:
		print("PASS: " + title)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in range(30):
		var rooms = Content.layout(seed_value)
		check(rooms == Content.layout(seed_value) and rooms.size() == 6, "seed %d produces six repeatable rooms" % seed_value)
		check(rooms[1] != rooms[2] and rooms[2] != rooms[3], "no adjacent combat repeats")
	check(Combat.damage(20, 0, false) == 20, "unmitigated damage")
	check(Combat.damage(20, 100, false) == 10, "armor mitigation")
	check(Combat.damage(20, 0, true) == 30, "critical multiplier")
	var statuses = StatusEffects.new()
	statuses.apply("mend", "defense", 12, 4)
	statuses.tick(2)
	statuses.apply("mend", "defense", 12, 4)
	check(statuses.bonus("defense") == 12, "same status refreshes instead of stacking")
	statuses.tick(3)
	check(statuses.bonus("defense") == 12, "refreshed duration preserved")
	statuses.tick(1.1)
	check(statuses.bonus("defense") == 0, "expired modifiers restore base defense")
	check(Combat.validate(Content.SKILLS[1], true, false, 0, 0) == "mana", "insufficient mana rejects cast")
	check(Combat.validate(Content.SKILLS[1], false, false, 0, 100) == "dead", "dead actors cannot cast")
	check(Combat.validate(Content.SKILLS[1], true, false, 1, 100) == "cooldown", "cooldown rejects cast")
	var test_store = Store.new("user://test-profile-%d.json" % Time.get_ticks_usec())
	var data = test_store.fresh()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var item = Content.roll_item(rng, 2)
	data.inventory.append(item)
	data.equipment[item.slot] = item.id
	check(Store.stats(data) != Store.stats(test_store.fresh()), "equipment modifies derived stats")
	check(test_store.save_profile(data) == OK, "atomic save succeeds")
	check(test_store.load_profile().inventory[0].id == item.id, "item identity survives save round trip")
	data.gold = 55
	test_store.save_profile(data)
	var broken = FileAccess.open(test_store.path, FileAccess.WRITE)
	broken.store_string("corrupt")
	broken.close()
	check(test_store.load_profile().gold == 0, "corrupt primary restores prior backup")
	var invalid = data.duplicate(true)
	invalid.equipment[item.slot] = "missing"
	invalid.inventory.append(item.duplicate(true))
	check(test_store.repair(invalid).inventory.size() == 1, "duplicate item IDs repaired")
	check(test_store.repair(invalid).equipment.is_empty(), "dangling equipment removed")
	var game = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store = Store.new("user://test-run-%d.json" % Time.get_ticks_usec())
	game.profile = game.store.fresh()
	game.checkpoint = game.profile.duplicate(true)
	game.start_run(101)
	check(game.hero.active and game.room_index == 0, "run starts in sanctuary")
	check(game.enemies.size() == 20 and game.projectiles.entries.size() == 40, "actor and projectile pools prewarmed to budget")
	for i in range(40): game.projectiles.fire(Vector3.ZERO, Vector3.FORWARD, 1, false)
	check(not game.projectiles.fire(Vector3.ZERO, Vector3.FORWARD, 1, false), "projectile capacity is bounded")
	game.projectiles.clear_all()
	check(game.projectiles.fire(Vector3.ZERO, Vector3.FORWARD, 1, true), "cleared pool can be reused with new faction")
	game.projectiles.clear_all()
	# Feed real multitouch events: left stick and right attack remain independent.
	var touch = InputEventScreenTouch.new()
	touch.index = 3
	touch.position = game.hud.center + Vector2(50, 0)
	touch.pressed = true
	game.hud._input(touch)
	var movement_drag = InputEventScreenDrag.new()
	movement_drag.index = 3
	movement_drag.position = touch.position + Vector2(50, 0)
	game.hud._input(movement_drag)
	var attack = InputEventScreenTouch.new()
	attack.index = 4
	attack.position = game.hud.attack_rect.get_center()
	attack.pressed = true
	game.hud._input(attack)
	check(game.hud.movement.x > 0.5 and game.hud.held_attack, "two fingers move and attack simultaneously")
	attack.pressed = false
	game.hud._input(attack)
	check(game.hud.movement.x > 0.5 and not game.hud.held_attack, "attack release preserves joystick finger")
	game.hud.reset_input()
	var before: Vector3 = game.hero.position
	game.hud.movement = Vector2(1, 0)
	game._physics_process(0.1)
	check(game.hero.position != before, "movement changes world position")
	game.hud.reset_input()
	game.try_cast(1)
	check(game.cast_index == 1 and game.mana == 100, "windup reserves without spending")
	game.hit_actor(game.hero, 1)
	check(game.cast_index == -1 and game.cooldowns[1] == 0 and game.mana == 100, "precommit interruption refunds cast")
	game.try_cast(1)
	game.commit_cast()
	check(game.mana == 82 and game.cooldowns[1] == 3, "commit consumes cost and starts cooldown")
	game.hit_actor(game.hero, 1)
	check(game.cooldowns[1] == 3, "postcommit interruption keeps cooldown")
	game.advance_room()
	check(game.room_index == 1 and not game.cleared, "first combat room locks exit")
	var enemy = game.enemies[0]
	var original_hp: float = enemy.hp
	game.projectiles.fire(enemy.position + Vector3(0, 0, 1), Vector3.FORWARD, 2, false)
	game.projectiles.tick(0.1, game.hero, game.enemies, game.hit_actor)
	check(enemy.hp < original_hp, "projectile sweep hits hostile actor")
	game.projectiles.clear_all()
	game.hit_actor(enemy, 99999)
	var gold = game.profile.gold
	game.hit_actor(enemy, 99999)
	check(game.profile.gold == gold, "death rewards are idempotent")
	# Run all encounters through the same resolver and encounter tick as gameplay.
	for room_number in range(1, 6):
		if room_number == 5:
			var boss = game.enemies[0]
			boss.hp = boss.maximum * 0.49
			game.tick_enemy(boss, 0.1)
			check(boss.phase == 2, "boss enters phase two at half health")
		var guard = 0
		while not game.cleared and guard < 8:
			for target in game.enemies:
				if target.active: game.hit_actor(target, 99999)
			game._physics_process(0.9)
			guard += 1
		check(game.cleared, "room %d clears after all waves" % room_number)
		check(game.room.exit_ring.visible and not game.room.door.visible, "clear room unlocks gate")
		game.advance_room()
	check(not game.playing and game.profile.wins == 1, "boss completion reaches victory screen")
	check(game.store.load_profile().wins == 1, "victory persisted")
	game.start_run(202)
	game.advance_room()
	var checkpoint_gold = game.checkpoint.gold
	game.profile.gold += 123
	game.finish_run(false)
	check(game.profile.gold == checkpoint_gold, "death rolls back uncommitted room rewards")
	game.start_run(203)
	game.toggle_pause()
	before = game.hero.position
	game.hud.movement = Vector2(1, 1)
	game._physics_process(0.1)
	check(game.hero.position == before, "pause freezes simulation")
	game.close_modal()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and game.hud.movement == Vector2.ZERO, "background pauses and clears held touch")
	game.close_modal()
	game.profile.inventory.clear()
	for i in range(20): game.profile.inventory.append(Content.roll_item(rng, 1))
	game.spawn_loot(game.hero.position)
	game._physics_process(0.1)
	var on_ground = false
	for drop in game.drops:
		if drop.active: on_ground = true
	check(game.profile.inventory.size() == 20 and on_ground, "full inventory leaves gear on ground")
	game.profile.inventory.pop_back()
	game._physics_process(0.1)
	check(game.profile.inventory.size() == 20, "gear is picked up when capacity becomes available")
	var game_save_path: String = game.store.path
	game.queue_free()
	await process_frame
	await process_frame
	# Only delete isolated test saves created in this test invocation.
	for save_path in [test_store.path, game_save_path]:
		if save_path.is_empty(): continue
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
