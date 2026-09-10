extends Node3D
const Content = preload("res://scripts/content.gd")
const Store = preload("res://scripts/profile_store.gd")
const Combat = preload("res://scripts/combat.gd")
const Actor = preload("res://scripts/actor.gd")
const HUD = preload("res://scripts/mobile_hud.gd")
const Projectiles = preload("res://scripts/projectile_pool.gd")
const V = preload("res://scripts/visuals.gd")
const StatusEffects = preload("res://scripts/status_effects.gd")
const Icons = preload("res://scripts/icons.gd")
const BlockEffect = preload("res://scripts/block_effect.gd")
var statuses = StatusEffects.new()
var haptics = preload("res://scripts/haptics.gd").new()
var store = Store.new()
var profile: Dictionary
var checkpoint: Dictionary
var stats: Dictionary
var rng = RandomNumberGenerator.new()
var run_seed = 0
var layout: Array = []
var room_index = 0
var wave = 0
var wave_wait = 0.0
var room
var hero
var enemies: Array = []
var projectiles
var hud
var camera: Camera3D
var ui: CanvasLayer
var modal: Control
var mana = 100.0
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0]
var cast_index = -1
var cast_timer = 0.0
var recovery = 0.0
var cast_aim = Vector3.FORWARD
var cleared = true
var playing = false
var paused = false
var ai_timer = 0.0
var drops: Array = []
var fx: Array = []
var text_pool: Array = []
var clock = 0.0
var beep: AudioStreamPlayer
var portrait_cover: ColorRect
var ground_target = Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = store.load_profile()
	checkpoint = profile.duplicate(true)
	stats = Store.stats(profile)
	Engine.max_fps = profile.settings.fps
	_setup_world()
	_setup_ui()
	_setup_pools()
	_setup_audio()
	show_menu()
	if not store.warning.is_empty(): hud.notify(store.warning)

func _setup_world() -> void:
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101922")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("9cbbd1")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_color = Color("b5c6de")
	light.light_energy = 1.3
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 26
	camera.position = Vector3(16, 22, 19)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	hero = Actor.new()
	hero.name = "Hero"
	add_child(hero)
	projectiles = Projectiles.new()
	projectiles.name = "ProjectilePool"
	add_child(projectiles)
	for i in range(20):
		var enemy = Actor.new()
		enemy.name = "Enemy%02d" % i
		add_child(enemy)
		enemies.append(enemy)
	_load_room(0)

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = HUD.new()
	ui.add_child(hud)
	hud.action.connect(try_cast)
	hud.pause_requested.connect(toggle_pause)
	hud.inventory_requested.connect(show_inventory)
	hud.advance_requested.connect(advance_room)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	portrait_cover = ColorRect.new()
	portrait_cover.color = Color("101922")
	portrait_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_cover.visible = false
	ui.add_child(portrait_cover)
	var rotate_text = Label.new()
	rotate_text.text = "ROTATE YOUR PHONE\n\nCinderfall is played in landscape."
	rotate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_text.add_theme_font_size_override("font_size", 32)
	portrait_cover.add_child(rotate_text)

func _setup_pools() -> void:
	for i in range(16):
		var ring = BlockEffect.new()
		add_child(ring)
		ring.visible = false
		fx.append({"node":ring, "life":0.0, "radius":1.0})
	for i in range(24):
		var label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 36
		label.pixel_size = 0.015
		label.visible = false
		add_child(label)
		text_pool.append({"node":label, "life":0.0})
	for i in range(20):
		var mesh = V.loot_model(self)
		mesh.visible = false
		drops.append({"node":mesh, "active":false, "item":{}})

func _setup_audio() -> void:
	beep = AudioStreamPlayer.new()
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes = PackedByteArray()
	bytes.resize(4410)
	for i in range(2205):
		var sample = int(sin(i * TAU * 440.0 / 22050.0) * 6500 * (1.0 - i / 2205.0))
		bytes.encode_s16(i * 2, sample)
	stream.data = bytes
	beep.stream = stream
	beep.volume_db = -16
	add_child(beep)

func sound(pitch: float = 1.0) -> void:
	if profile.settings.sound and DisplayServer.get_name() != "headless":
		beep.pitch_scale = pitch
		beep.play()

func _load_room(id: int) -> void:
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	var scene = load("res://scenes/rooms/room_%d.tscn" % id)
	if scene == null:
		push_error("Missing required room content")
		return
	room = scene.instantiate()
	add_child(room)

func start_run(seed_override: int = -1) -> void:
	for i in range(8):
		if not ResourceLoader.exists("res://scenes/rooms/room_%d.tscn" % i):
			var error_panel = panel("DUNGEON UNAVAILABLE", "Required room content is missing. Restore the project files and retry.")
			add_button(error_panel, "RETRY", start_run)
			add_button(error_panel, "RETURN TO MENU", show_menu)
			return
	profile = checkpoint.duplicate(true)
	stats = Store.stats(profile)
	run_seed = int(Time.get_unix_time_from_system()) if seed_override < 0 else seed_override
	rng.seed = run_seed
	layout = Content.layout(run_seed)
	room_index = 0
	playing = true
	paused = false
	mana = 100
	cooldowns = [0.0, 0.0, 0.0, 0.0]
	cast_index = -1
	recovery = 0
	statuses.active.clear()
	hero.activate("hero", Vector3(0, 0, 5), stats.health, Color("548fa3"))
	close_modal()
	enter_room()
	hud.notify("Hold SLASH to attack. Drag it to aim.")

func enter_room() -> void:
	projectiles.clear_all()
	for entry in text_pool:
		entry.life = 0
		entry.node.visible = false
	for effect in fx:
		effect.life = 0
		effect.node.visible = false
	for enemy in enemies:
		enemy.active = false
		enemy.visible = false
	for drop in drops:
		drop.active = false
		drop.node.visible = false
	_load_room(layout[room_index])
	hero.position = Vector3(0, 0, 5)
	hero.velocity = Vector3.ZERO
	cast_index = -1
	recovery = 0
	cleared = room_index == 0
	wave = 0
	wave_wait = 0.0
	room.set_unlocked(cleared)
	if not cleared: spawn_wave()

func spawn_wave() -> void:
	wave += 1
	var count = 1 if room_index == 5 else 2 + room_index + wave
	for i in range(count):
		var kind = ["melee", "ranged", "brute"][(i + room_index + wave) % 3]
		if room_index == 5: kind = "boss"
		var definition: Dictionary = Content.ENEMIES[kind]
		var elite = room_index == 4 and i == 0
		var angle = TAU * i / count
		var at = Vector3(sin(angle) * 5, 0, cos(angle) * 3 - 2)
		for enemy in enemies:
			if not enemy.active:
				enemy.activate(kind, at, definition.hp * (1 + (profile.level - 1) * 0.12) * (1.7 if elite else 1.0), Color("d5ad67") if elite else definition.color, elite)
				break
	hud.notify("The Warden awakens" if room_index == 5 else "Wave %d · Defeat the guardians" % wave)

func advance_room() -> void:
	if not cleared or not playing or paused: return
	if room_index >= 5:
		finish_run(true)
		return
	save_checkpoint()
	room_index += 1
	enter_room()

func _physics_process(delta: float) -> void:
	if not paused:
		hero.tick_visual(delta)
		for enemy in enemies: enemy.tick_visual(delta)
	if not playing or paused: return
	clock += delta
	statuses.tick(delta)
	for i in range(4): cooldowns[i] = maxf(0, cooldowns[i] - delta)
	recovery = maxf(0, recovery - delta)
	mana = minf(100, mana + delta * 7)
	var direction = hud.movement
	if direction.length() < 0.1:
		direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var world_direction = screen_direction(direction)
	hero.move_intent(world_direction, 5.0 * (0.45 if cast_index >= 0 else 1.0), delta)
	if hud.held_attack or Input.is_physical_key_pressed(KEY_SPACE): try_cast(0)
	if cast_index >= 0:
		cast_timer -= delta
		if cast_timer <= 0: commit_cast()
	ai_timer -= delta
	if ai_timer <= 0:
		ai_timer = 0.12
		for enemy in enemies:
			if not enemy.active: continue
			var offset: Vector3 = hero.position - enemy.position
			if NavigationServer3D.map_get_iteration_id(enemy.navigation.get_navigation_map()) > 0:
				enemy.navigation.target_position = hero.position
				if not enemy.navigation.is_navigation_finished():
					offset = enemy.navigation.get_next_path_position() - enemy.position
			enemy.aim = offset.normalized()
	for enemy in enemies:
		if enemy.active: tick_enemy(enemy, delta)
	projectiles.tick(delta, hero, enemies, hit_actor)
	if not playing: return
	for drop in drops:
		if not drop.active: continue
		drop.node.rotation.y += delta * 1.8
		drop.node.position.y = 0.45 + sin(clock * 3) * 0.08
		if hero.position.distance_to(drop.node.position) < 1.5 and profile.inventory.size() < 20:
			profile.inventory.append(drop.item)
			drop.active = false
			drop.node.visible = false
			hud.notify("Found " + drop.item.name + " · Equip from BAG after combat")
			sound(1.5)
			haptics.pulse("loot", profile.settings.haptics)
			if cleared: save_checkpoint()
	if not cleared and alive_count() == 0:
		wave_wait += delta
		if wave_wait > 0.8:
			wave_wait = 0
			if room_index < 5 and wave < 2:
				spawn_wave()
			else:
				clear_room()
	if cleared and hero.position.distance_to(Vector3(0, 0, -7)) < 1.2:
		advance_room()
	for effect in fx:
		if effect.life <= 0: continue
		effect.life -= delta
		effect.node.tick(1.0 - effect.life / 0.4)
	for entry in text_pool:
		if entry.life <= 0: continue
		entry.life -= delta
		entry.node.position.y += delta * 1.1
		entry.node.visible = entry.life > 0

func screen_direction(input: Vector2) -> Vector3:
	var right = camera.global_basis.x
	var down = camera.global_basis.z
	right.y = 0
	down.y = 0
	return (right.normalized() * input.x + down.normalized() * input.y).limit_length(1)

func best_target():
	var best = null
	var distance = 100.0
	for enemy in enemies:
		if not enemy.active: continue
		var d: float = hero.position.distance_squared_to(enemy.position)
		if d < distance:
			distance = d
			best = enemy
	return best

func try_cast(index: int) -> void:
	if not playing or paused: return
	var skill: Resource = Content.SKILLS[index]
	var rejection = Combat.validate(skill, hero.active, cast_index >= 0 or recovery > 0, cooldowns[index], mana)
	if not rejection.is_empty():
		if rejection == "mana" and index > 0: hud.notify("Not enough mana · it regenerates over time")
		return
	cast_index = index
	cast_timer = skill.windup
	cast_aim = hero.aim
	if hud.aim.length() > 0.2:
		cast_aim = screen_direction(hud.aim).normalized()
	else:
		var target = best_target()
		if target != null: cast_aim = (target.position - hero.position).normalized()
	hero.body.rotation.y = atan2(-cast_aim.x, -cast_aim.z)
	hero.animate_attack(skill.id, skill.windup, skill.recovery)
	ground_target = hero.position
	if skill.targeting == "ground" and hud.aim.length() > 0.2:
		ground_target = hero.position + cast_aim * 3.5

func commit_cast() -> void:
	var index = cast_index
	cast_index = -1
	var skill: Resource = Content.SKILLS[index]
	if not hero.active: return
	mana -= skill.cost
	cooldowns[index] = skill.cooldown
	recovery = skill.recovery
	sound(0.8 + index * 0.3)
	haptics.pulse("attack", profile.settings.haptics)
	for effect in skill.effects:
		resolve_effect(skill, effect)

func resolve_effect(skill: Resource, effect: Dictionary) -> void:
	match effect.kind:
		"cone":
			burst(hero.position, skill.range, "slash", cast_aim)
			for enemy in enemies:
				if not enemy.active: continue
				var offset: Vector3 = enemy.position - hero.position
				if offset.length() < skill.range and offset.normalized().dot(cast_aim) > 0.15:
					hit_actor(enemy, stats.power * skill.power)
		"projectile":
			projectiles.fire(hero.position + cast_aim * 0.8, cast_aim, stats.power * skill.power, false)
			burst(hero.position, 2.0, "ember", cast_aim)
		"area":
			burst(ground_target, skill.range)
			for enemy in enemies:
				if enemy.active and enemy.position.distance_to(ground_target) < skill.range:
					hit_actor(enemy, stats.power * skill.power)
		"knockback":
			for enemy in enemies:
				if enemy.active and enemy.position.distance_to(ground_target) < skill.range:
					enemy.stagger = effect.stagger
					enemy.windup = 0
					enemy.attack_time = 0
					enemy.position += (enemy.position - ground_target).normalized() * effect.distance
		"modifier":
			statuses.apply(skill.id, effect.stat, effect.value, effect.duration)
		"heal":
			hero.hp = minf(hero.maximum, hero.hp + skill.power)
			floating(hero.position, "+42", Color("8ae4c3"))
			burst(hero.position, 2.0, "mend")

func tick_enemy(enemy, delta: float) -> void:
	var definition: Dictionary = Content.ENEMIES[enemy.kind]
	enemy.cooldown -= delta
	enemy.stagger = maxf(0, enemy.stagger - delta)
	if enemy.stagger > 0:
		enemy.state = "stagger"
		enemy.warning_ring.visible = false
		enemy.move_intent(Vector3.ZERO, 0, delta)
		return
	if enemy.kind == "boss" and enemy.phase == 1 and enemy.hp < enemy.maximum * 0.5:
		enemy.phase = 2
		hud.notify("PHASE II · The Warden is enraged")
		burst(enemy.position, 5)
	var distance: float = enemy.position.distance_to(hero.position)
	if enemy.windup > 0:
		enemy.body.rotation.y = atan2(-enemy.aim.x, -enemy.aim.z)
		enemy.state = "windup"
		enemy.windup -= delta
		enemy.warning_ring.visible = true
		enemy.warning_ring.scale = Vector3.ONE * definition.range
		if enemy.windup <= 0:
			enemy.warning_ring.visible = false
			enemy.cooldown = definition.cooldown / (1.45 if enemy.phase == 2 else 1.0)
			if enemy.kind == "ranged":
				projectiles.fire(enemy.position, enemy.aim, definition.damage, true)
			elif distance < definition.range + 0.3:
				hit_actor(hero, definition.damage * (1.35 if enemy.elite else 1.0))
			if enemy.kind == "boss":
				for i in range(8 if enemy.phase == 2 else 4):
					var angle = i * TAU / (8 if enemy.phase == 2 else 4)
					projectiles.fire(enemy.position, Vector3(sin(angle), 0, cos(angle)), definition.damage * 0.6, true)
		enemy.move_intent(Vector3.ZERO, 0, delta)
		return
	if distance <= definition.range and enemy.cooldown <= 0:
		enemy.windup = 0.85 if enemy.kind != "melee" else 0.55
		enemy.body.rotation.y = atan2(-enemy.aim.x, -enemy.aim.z)
		enemy.animate_attack("ember" if enemy.kind == "ranged" else "slash", enemy.windup, 0.2)
		enemy.move_intent(Vector3.ZERO, 0, delta)
	elif distance > definition.range * 0.9:
		enemy.state = "chase"
		var move_direction: Vector3 = enemy.aim
		for other in enemies:
			if other == enemy or not other.active: continue
			var away: Vector3 = enemy.position - other.position
			if away.length_squared() < 1.4:
				move_direction += away.normalized() * 0.8
		enemy.move_intent(move_direction.limit_length(1), definition.speed * (1.25 if enemy.phase == 2 else 1.0), delta)
	else:
		enemy.state = "recover"
		enemy.move_intent(Vector3.ZERO, 0, delta)

func hit_actor(actor, power: float) -> void:
	if not actor.active: return
	var critical = actor != hero and rng.randf() < 0.14
	var amount = Combat.damage(power, stats.defense + statuses.bonus("defense") if actor == hero else 5.0, critical)
	var dead: bool = actor.hurt(amount)
	floating(actor.position, str(int(amount)) + ("!" if critical else ""), Color("ee887d") if actor == hero else Color("ffe5ac"))
	if actor == hero:
		haptics.pulse("damage", profile.settings.haptics)
		# Wind-up cancellation costs nothing; committed casts keep their cooldown.
		if cast_index >= 0: hero.attack_time = 0
		cast_index = -1
		if dead: finish_run(false)
	elif dead:
		profile.gold += 8 if actor.kind != "boss" else 100
		profile.xp += 15 if actor.kind != "boss" else 100
		while profile.xp >= profile.level * 75:
			profile.xp -= profile.level * 75
			profile.level += 1
			stats = Store.stats(profile)
			hero.maximum = stats.health
			hero.hp = minf(hero.maximum, hero.hp + 25)
			hud.notify("LEVEL %d · Your strength grows" % profile.level)
		if actor.elite or actor.kind == "boss" or rng.randf() < 0.27:
			spawn_loot(actor.position)

func spawn_loot(at: Vector3) -> void:
	for drop in drops:
		if not drop.active:
			drop.active = true
			drop.item = Content.roll_item(rng, profile.level)
			drop.node.position = at + Vector3(0, 0.4, 0)
			drop.node.visible = true
			V.style_loot(drop.node, drop.item.slot, drop.item.rarity)
			return

func burst(at: Vector3, radius: float, kind: String = "nova", direction: Vector3 = Vector3.FORWARD) -> void:
	for effect in fx:
		if effect.life <= 0:
			effect.life = 0.4
			effect.radius = radius
			effect.node.position = at + Vector3(0, 0.08, 0)
			effect.node.visible = true
			effect.node.configure(kind, radius, direction)
			return

func floating(at: Vector3, text: String, color: Color) -> void:
	for entry in text_pool:
		if entry.life <= 0:
			entry.life = 0.75
			entry.node.text = text
			entry.node.modulate = color
			entry.node.position = at + Vector3(0, 2.3, 0)
			entry.node.visible = true
			return

func alive_count() -> int:
	var count = 0
	for enemy in enemies:
		if enemy.active: count += 1
	return count

func clear_room() -> void:
	if cleared: return
	cleared = true
	projectiles.clear_all()
	room.set_unlocked(true)
	hero.hp = minf(hero.maximum, hero.hp + 20)
	mana = minf(100, mana + 25)
	spawn_loot(hero.position + Vector3(1, 0, 0))
	save_checkpoint()
	hud.notify("Room cleared · Collect loot, equip, then enter the gate")
	sound(2)

func save_checkpoint() -> void:
	checkpoint = profile.duplicate(true)
	var error = store.save_profile(checkpoint)
	if error != OK: hud.notify("Save failed · progress remains in this session")

func finish_run(won: bool) -> void:
	if not playing: return
	playing = false
	projectiles.clear_all()
	if won:
		profile.wins += 1
		save_checkpoint()
	else:
		profile = checkpoint.duplicate(true)
	hud.reset_input()
	var column = panel("THE PYRE IS SILENT" if won else "THE EMBERS FADE", "Dungeon complete. Your spoils are saved." if won else "You fell. Progress from cleared rooms is safe.")
	add_button(column, "RETURN TO SANCTUARY", show_menu)

func _process(_delta: float) -> void:
	var window_size = DisplayServer.window_get_size()
	var portrait = window_size.y > window_size.x
	portrait_cover.visible = portrait
	if portrait and playing and not paused: toggle_pause()
	hud.health = hero.hp / maxf(1, hero.maximum)
	hud.mana = mana / 100
	hud.hp_text = "%d / %d" % [hero.hp, hero.maximum]
	hud.character_text = "WARDEN  ·  LV %d  ·  %d GOLD" % [profile.level, profile.gold]
	hud.room_text = "%02d / 06   %s" % [room_index + 1, Content.ROOMS[layout[room_index] if not layout.is_empty() else 0]]
	hud.objective = "Sanctuary · Prepare for descent" if room_index == 0 else ("Room clear · Collect your spoils" if cleared else "Wave %d / %d   ·   %d guardians" % [wave, 1 if room_index == 5 else 2, alive_count()])
	if profile.inventory.size() >= 20: hud.objective += " · PACK FULL"
	hud.cooldowns = cooldowns
	hud.clear = cleared and playing and not paused
	hud.boss_ratio = -1
	for enemy in enemies:
		if enemy.active and enemy.kind == "boss": hud.boss_ratio = enemy.hp / enemy.maximum
	hud.debug_text = "%d FPS  ·  %d / 20 HOSTILES  ·  SEED %d" % [Engine.get_frames_per_second(), alive_count(), run_seed]
	if Input.is_physical_key_pressed(KEY_1): try_cast(1)
	if Input.is_physical_key_pressed(KEY_2): try_cast(2)
	if Input.is_physical_key_pressed(KEY_3): try_cast(3)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE: toggle_pause()
		if event.physical_keycode == KEY_I: show_inventory()
		if event.physical_keycode == KEY_E: advance_room()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		haptics.stop()
		if is_instance_valid(hud):
			hud.reset_input()
			if playing and not paused: toggle_pause()
		if not checkpoint.is_empty(): store.save_profile(checkpoint)

func panel(title: String, subtitle: String) -> VBoxContainer:
	haptics.stop()
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.visible = true
	hud.locked = true
	hud.reset_input()
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var centered = CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(centered)
	var column = VBoxContainer.new()
	column.custom_minimum_size.x = 580
	column.add_theme_constant_override("separation", 16)
	centered.add_child(column)
	var heading = Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 42)
	heading.add_theme_color_override("font_color", Color("e6c18c"))
	column.add_child(heading)
	var sub = Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("a7bdc6"))
	column.add_child(sub)
	return column

func add_button(parent: Control, title: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 80
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", hud.button_style())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func close_modal() -> void:
	modal.visible = false
	hud.locked = false
	hud.reset_input()
	paused = false

func show_menu() -> void:
	playing = false
	paused = false
	projectiles.clear_all()
	for enemy in enemies:
		enemy.active = false
		enemy.visible = false
	profile = checkpoint.duplicate(true)
	var column = panel("C I N D E R F A L L", "A descent into the ashes\n\nWarden level %d  ·  %d victories  ·  %d gold" % [profile.level, profile.wins, profile.gold])
	add_button(column, "DESCEND INTO THE DUNGEON", start_run)
	add_button(column, "EQUIPMENT & INVENTORY", show_inventory)
	add_button(column, "SETTINGS", show_settings)
	var help = Label.new()
	help.text = "TOUCH  ·  Touch & drag lower-left to move  /  Hold Slash to attack\nEmber: firebolt  ·  Nova: blast & stun  ·  Mend: heal\n\nDESKTOP  ·  WASD / Space / 1 2 3 / E next room / Esc pause"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("8da5b0"))
	column.add_child(help)

func toggle_pause() -> void:
	if not playing: return
	if paused:
		close_modal()
		return
	paused = true
	var column = panel("REST BY THE EMBERS", "The dungeon is paused.")
	add_button(column, "RESUME", close_modal)
	add_button(column, "SETTINGS", show_settings)
	add_button(column, "ABANDON RUN · KEEP CLEARED-ROOM PROGRESS", show_menu)

func show_settings() -> void:
	var column = panel("SETTINGS", "Haptics require a supported device and browser.")
	add_button(column, "FRAME LIMIT: %d FPS · TAP TO SWITCH" % profile.settings.fps, func():
		profile.settings.fps = 30 if profile.settings.fps == 60 else 60
		Engine.max_fps = profile.settings.fps
		checkpoint.settings = profile.settings.duplicate()
		store.save_profile(checkpoint)
		show_settings())
	add_button(column, "SOUND: " + ("ON" if profile.settings.sound else "OFF"), func():
		profile.settings.sound = not profile.settings.sound
		checkpoint.settings = profile.settings.duplicate()
		store.save_profile(checkpoint)
		show_settings())
	add_button(column, "HAPTICS: " + ("ON" if profile.settings.haptics else "OFF"), func():
		profile.settings.haptics = not profile.settings.haptics
		if not profile.settings.haptics: haptics.stop()
		checkpoint.settings = profile.settings.duplicate()
		store.save_profile(checkpoint)
		show_settings())
	add_button(column, "BACK", close_modal if playing else show_menu)

func show_inventory(scroll_position: int = 0) -> void:
	if playing and not cleared:
		hud.notify("Equipment is available after the room is cleared")
		return
	paused = playing
	var column = panel("THE WARDEN'S PACK", "%d of 20 slots free  ·  Swipe to browse / tap to equip" % (20 - profile.inventory.size()))
	column.add_theme_constant_override("separation", 10)
	var derived = Store.stats(profile)
	var summary = Label.new()
	summary.text = "POWER %d   /   ARMOR %d   /   HEALTH %d" % [derived.power, derived.defense, derived.health]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(summary)
	var equipment = HBoxContainer.new()
	equipment.name = "EquipmentSlots"
	equipment.add_theme_constant_override("separation", 8)
	column.add_child(equipment)
	for slot in ["weapon", "armor", "accessory"]:
		var equipped_name = "EMPTY"
		for item in profile.inventory:
			if profile.equipment.get(slot, "") == item.id:
				equipped_name = item.name + " +" + str(item.value)
		var card = Button.new()
		card.text = slot.to_upper() + "\n" + equipped_name
		card.icon = Icons.texture(slot)
		card.add_theme_constant_override("icon_max_width", 32)
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_stylebox_override("disabled", hud.button_style())
		card.disabled = true
		card.custom_minimum_size = Vector2(220, 72)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equipment.add_child(card)
	var scroll = preload("res://scripts/inventory_scroll.gd").new()
	scroll.custom_minimum_size = Vector2(660, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.get_v_scroll_bar().custom_minimum_size.x = 24
	column.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for item in profile.inventory:
		var equipped = profile.equipment.get(item.slot, "") == item.id
		var text = ("◆ " if equipped else "") + ["COMMON", "RARE", "EPIC"][item.rarity] + "  " + item.name + "  +" + str(item.value)
		var item_button = add_button(list, text, func():
			profile.equipment[item.slot] = item.id
			stats = Store.stats(profile)
			hero.maximum = stats.health
			hero.hp = minf(hero.hp, hero.maximum)
			save_checkpoint()
			show_inventory(scroll.scroll_vertical))
		item_button.icon = Icons.texture(item.slot)
		item_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		item_button.add_theme_constant_override("icon_max_width", 52)
		item_button.add_theme_constant_override("h_separation", 18)
		var item_style = hud.button_style().duplicate()
		item_style.border_color = Icons.rarity_color(item.rarity)
		item_style.set_border_width_all(2)
		item_style.content_margin_left = 18
		item_style.content_margin_right = 18
		item_button.add_theme_stylebox_override("normal", item_style)
		item_button.add_theme_color_override("font_color", Icons.rarity_color(item.rarity))
	for i in range(profile.inventory.size(), 20):
		var empty = add_button(list, "SLOT %02d  ·  EMPTY" % (i + 1), func(): pass)
		empty.disabled = true
		empty.add_theme_stylebox_override("disabled", hud.button_style())
		empty.add_theme_color_override("font_disabled_color", Color("7d939d"))
	scroll.set_deferred("scroll_vertical", scroll_position)
	var back = add_button(column, "BACK", close_modal if playing else show_menu)
	back.name = "InventoryBack"
