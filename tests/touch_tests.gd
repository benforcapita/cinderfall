extends SceneTree
var checks = 0
var failures = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + title)
	else: print("PASS: " + title)
func _initialize() -> void:
	call_deferred("run")
func touch(hud, id: int, point: Vector2, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = down
	hud._input(event)
func drag(hud, id: int, point: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.index = id
	event.position = point
	hud._input(event)
func run() -> void:
	var hud = load("res://scripts/mobile_hud.gd").new()
	root.add_child(hud)
	await process_frame
	hud.size = Vector2(1280, 720)
	hud._layout()
	var home = hud.center
	var origin = Vector2(390, 420)
	touch(hud, 7, origin, true)
	check(hud.finger == 7 and hud.center == origin and hud.movement == Vector2.ZERO, "joystick spawns beneath thumb without movement")
	drag(hud, 7, origin + Vector2(33, 0))
	check(is_equal_approx(hud.movement.x, 0.5), "drag is relative to new thumb origin")
	drag(hud, 7, origin + Vector2(160, 0))
	check(hud.center == origin + Vector2(94, 0) and hud.movement.x == 1, "base follows thumb beyond joystick radius")
	touch(hud, 8, hud.attack_rect.get_center(), true)
	touch(hud, 9, Vector2(200, 440), true)
	check(hud.finger == 7 and hud.held_attack, "extra fingers do not steal movement while attacking")
	touch(hud, 8, hud.attack_rect.get_center(), false)
	check(hud.finger == 7 and hud.movement.x == 1 and not hud.held_attack, "attack release preserves movement")
	touch(hud, 7, origin, false)
	check(hud.finger == -1 and hud.movement == Vector2.ZERO and hud.center == home, "release stops movement and resets idle hint")
	touch(hud, 3, Vector2(80, 80), true)
	check(hud.finger == -1, "top HUD is not a movement area")
	hud.next_button.visible = true
	touch(hud, 3, hud.next_button.position + Vector2(20, 20), true)
	check(hud.finger == -1, "gate button is not captured by joystick")
	touch(hud, 3, origin, true)
	hud._layout()
	check(hud.finger == -1 and hud.movement == Vector2.ZERO, "resize cancels active gesture")
	hud.locked = true
	touch(hud, 3, origin, true)
	check(hud.finger == -1, "modal prevents movement acquisition")
	var store = load("res://scripts/profile_store.gd").new("user://touch-test-%d.json" % Time.get_ticks_usec())
	check(store.repair({"version":1}).settings.get("haptics", false), "old profiles get haptics default")
	var data = store.fresh()
	data.settings.haptics = false
	store.save_profile(data)
	check(store.load_profile().settings.get("haptics", true) == false, "haptics off survives save round trip")
	check(ResourceLoader.exists("res://scripts/haptics.gd"), "rate-limited haptics policy exists")
	if ResourceLoader.exists("res://scripts/haptics.gd"):
		var h = load("res://scripts/haptics.gd").new()
		check(h.request("attack", true, 1000) == 12, "attack produces short pulse")
		check(h.request("damage", true, 1050) == 0, "rapid events are rate limited")
		check(h.request("damage", true, 1200) == 35, "damage pulse is distinct")
		check(h.request("loot", false, 1400) == 0, "disabled haptics produce no pulse")
		check(h.request("loot", true, 1400) == 20, "loot pulse recovers after cooldown")
		check(h.request("unknown", true, 1700) == 0, "unknown events do not vibrate")
	hud.queue_free()
	await process_frame
	print("TOUCH RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
