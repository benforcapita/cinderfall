extends SceneTree
## Accelerated playtest using real movement/casts/damage; never grants combat stats.
var game
var elapsed = 0.0
var frames = 0
var advancing = 0.0
var test_path = ""

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	game = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(game)
	test_path = "user://test-playthrough-%d.json" % Time.get_ticks_usec()
	game.store = load("res://scripts/profile_store.gd").new(test_path)
	game.profile = game.store.fresh()
	game.checkpoint = game.profile.duplicate(true)
	var seed_value = 719
	var arguments = OS.get_cmdline_user_args()
	if not arguments.is_empty(): seed_value = int(arguments[0])
	game.start_run(seed_value)
	print("PLAYTHROUGH: fresh level-one character, seed %d" % seed_value)

func _physics_process(delta: float) -> bool:
	if game == null: return false
	elapsed += delta
	frames += 1
	if not game.playing:
		finish(game.profile.wins > 0)
		return false
	if elapsed > 600:
		finish(false)
		return false
	if game.cleared:
		advancing += delta
		game.hud.movement = Vector2.ZERO
		if advancing > 1.5:
			print("CLEARED: room %d, HP %d/%d, level %d" % [game.room_index, game.hero.hp, game.hero.maximum, game.profile.level])
			# Use legitimately collected equipment between rooms.
			for item in game.profile.inventory:
				game.profile.equipment[item.slot] = item.id
			game.stats = game.Store.stats(game.profile)
			game.hero.maximum = game.stats.health
			game.advance_room()
			advancing = 0
		return false
	var target = game.best_target()
	if target == null: return false
	var offset: Vector3 = target.position - game.hero.position
	var distance = offset.length()
	var direction = offset.normalized()
	if target.windup > 0 and distance < 4:
		direction = -direction
	elif distance < 2.4:
		direction = Vector3.ZERO
	var right: Vector3 = game.camera.global_basis.x
	var down: Vector3 = game.camera.global_basis.z
	right.y = 0
	down.y = 0
	game.hud.movement = Vector2(direction.dot(right.normalized()), direction.dot(down.normalized()))
	if game.hero.hp < game.hero.maximum * 0.65:
		game.try_cast(3)
	if distance < 4 and game.mana > 48:
		game.try_cast(2)
	if distance > 3 and game.mana > 45:
		game.try_cast(1)
	if distance < 3:
		game.try_cast(0)
	return false

func finish(won: bool) -> void:
	print("PLAYTHROUGH %s: %.1f simulated seconds; room %d; HP %.1f; frames %d" % ["PASS" if won else "FAIL", elapsed, game.room_index, game.hero.hp, frames])
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix): DirAccess.remove_absolute(test_path + suffix)
	quit(0 if won else 1)
