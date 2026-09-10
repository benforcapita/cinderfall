extends ScrollContainer
# Handle raw touch before GUI buttons so a swipe can never become an equip.
# Keep native mouse-wheel/scrollbar behavior and gameplay pointer settings.
var finger = -1
var origin = Vector2.ZERO
var initial_scroll = 0
var swiping = false
var tapped: Button

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		cancel_gesture()
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index
			origin = event.position
			initial_scroll = scroll_vertical
			swiping = false
			tapped = null
			for child in get_child(0).get_children():
				if child is Button and not child.disabled and child.get_global_rect().has_point(origin):
					tapped = child
			get_viewport().set_input_as_handled()
		elif event.index == finger:
			get_viewport().set_input_as_handled()
			if not event.pressed:
				var button = tapped
				var activate = not event.canceled and not swiping and origin.distance_to(event.position) <= 12 and get_global_rect().has_point(event.position)
				cancel_gesture()
				if activate and is_instance_valid(button) and button.get_global_rect().has_point(event.position):
					button.pressed.emit()
		elif finger != -1 and get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		if event.position.distance_to(origin) > 12:
			swiping = true
		if swiping:
			scroll_vertical = initial_scroll + roundi(origin.y - event.position.y)
		get_viewport().set_input_as_handled()

func cancel_gesture() -> void:
	finger = -1
	tapped = null
	swiping = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		cancel_gesture()
