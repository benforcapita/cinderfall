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
func settle() -> void:
	for i in range(5): await process_frame
func touch(point: Vector2, down: bool, id: int = 4, canceled: bool = false) -> void:
	var e = InputEventScreenTouch.new()
	e.index = id
	e.position = point
	e.pressed = down
	e.canceled = canceled
	root.push_input(e)
func drag(point: Vector2, relative: Vector2, id: int = 4) -> void:
	var e = InputEventScreenDrag.new()
	e.index = id
	e.position = point
	e.relative = relative
	root.push_input(e)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.store = load("res://scripts/profile_store.gd").new("user://inventory-test-%d.json" % Time.get_ticks_usec())
	game.profile = game.store.fresh()
	game.checkpoint = game.profile.duplicate(true)
	game.show_inventory()
	await settle()
	var scroll = game.modal.find_children("*", "ScrollContainer", true, false)[0]
	check(scroll.get_child(0).get_child_count() == 20, "empty pack exposes all twenty available slots")
	check(game.modal.find_child("EquipmentSlots", true, false) != null, "equipment slot overview exists")
	for i in range(15):
		game.profile.inventory.append({"id":"test%d" % i, "slot":"weapon", "name":"Ash Blade", "value":i + 2, "level":1, "rarity":0, "affixes":[]})
	game.show_inventory()
	await settle()
	scroll = game.modal.find_children("*", "ScrollContainer", true, false)[0]
	var empties = 0
	for button in scroll.get_child(0).get_children():
		if button.disabled: empties += 1
	check(empties == 5, "fifteen items leave five visible empty slots")
	var p: Vector2 = scroll.global_position + Vector2(140, 170)
	touch(p, true)
	drag(p - Vector2(0, 120), Vector2(0, -120))
	touch(p - Vector2(0, 120), false)
	await settle()
	check(scroll.scroll_vertical >= 100, "raw web touch swipe scrolls over item buttons")
	check(game.profile.equipment.is_empty(), "swiping does not equip an item")
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = p
	var before: int = scroll.scroll_vertical
	root.push_input(wheel)
	await settle()
	check(scroll.scroll_vertical > before, "desktop wheel scrolls over item buttons")
	before = scroll.scroll_vertical
	touch(p, true)
	touch(p, false, 4, true)
	check(game.profile.equipment.is_empty(), "canceled tap does not equip")
	touch(p, true)
	touch(p, false)
	await settle()
	check(game.profile.equipment.has("weapon"), "stationary touch equips the tapped item")
	scroll = game.modal.find_children("*", "ScrollContainer", true, false)[0]
	check(scroll.scroll_vertical == before, "equipping preserves scroll position")
	var slots = game.modal.find_child("EquipmentSlots", true, false)
	check("Ash Blade" in slots.get_child(0).text and "EMPTY" in slots.get_child(1).text and "EMPTY" in slots.get_child(2).text, "equipment overview updates only the equipped slot")
	p = scroll.global_position + Vector2(140, 170)
	touch(p, true)
	touch(p, true, 5)
	drag(p - Vector2(0, 100), Vector2(0, -100), 5)
	check(scroll.scroll_vertical == before, "second finger cannot steal scrolling")
	touch(p, false, 5, true)
	drag(p - Vector2(0, 4000), Vector2(0, -4000))
	touch(p - Vector2(0, 4000), false)
	await settle()
	var last = scroll.get_child(0).get_child(19)
	check(scroll.get_global_rect().intersects(last.get_global_rect()), "swiping to bottom reaches final bag slot")
	touch(p, true)
	scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	drag(p - Vector2(0, 100), Vector2(0, -100))
	touch(p, false, 4, true)
	check(scroll.finger == -1, "focus loss cancels active gesture")
	var back = game.modal.find_child("InventoryBack", true, false)
	check(back != null and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(back.get_global_rect()), "Back stays on screen outside scrolling list")
	game.queue_free()
	await settle()
	print("INVENTORY RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
