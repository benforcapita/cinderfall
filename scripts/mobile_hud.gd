extends Control
signal action(index: int)
signal inventory_requested
signal pause_requested
signal advance_requested
var movement = Vector2.ZERO
var aim = Vector2.ZERO
var held_attack = false
var finger = -1
var aim_finger = -1
var center = Vector2.ZERO
var knob = Vector2.ZERO
var aim_center = Vector2.ZERO
var action_fingers: Dictionary = {}
var attack_rect: Rect2
var skill_rects: Array[Rect2] = []
var health = 1.0
var mana = 1.0
var hp_text = ""
var room_text = ""
var objective = ""
var character_text = ""
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0]
var message = ""
var message_time = 0.0
var boss_ratio = -1.0
var clear = false
var locked = false
var debug_text = ""
var font: Font
var pause_button: Button
var bag_button: Button
var next_button: Button
var cached_style: StyleBoxFlat
var safe_margin = 28.0
const GOLD = Color("e6c18c")
const PALE = Color("e6e9e9")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	pause_button = small_button("II", Vector2(84, 80), pause_requested.emit)
	bag_button = small_button("BAG", Vector2(94, 80), inventory_requested.emit)
	next_button = small_button("ENTER THE GATE  ›", Vector2(290, 80), advance_requested.emit)
	resized.connect(_layout)
	_layout()

func small_button(title: String, dimensions: Vector2, callback: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 20)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("17232b")
	style.border_color = Color("506265")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _layout() -> void:
	# Native safe areas are physical pixels; convert to the logical viewport.
	var window_size = DisplayServer.window_get_size()
	var safe = DisplayServer.get_display_safe_area()
	if OS.has_feature("mobile") and window_size.x > 0 and safe.size.x > 0:
		safe_margin = maxf(28, maxf(safe.position.x, window_size.x - safe.end.x) * size.x / window_size.x + 12)
	center = Vector2(safe_margin + 108, size.y - 137)
	knob = center
	attack_rect = Rect2(Vector2(size.x - safe_margin - 132, size.y - 179), Vector2(112, 112))
	skill_rects.clear()
	for i in range(3):
		skill_rects.append(Rect2(Vector2(size.x - safe_margin - 257 - i * 112, size.y - 130), Vector2(96, 88)))
	pause_button.position = Vector2(size.x - safe_margin - 84, 14)
	bag_button.position = Vector2(size.x - safe_margin - 190, 14)
	next_button.position = Vector2(size.x / 2 - 145, size.y - 220)

func reset_input() -> void:
	finger = -1
	aim_finger = -1
	held_attack = false
	movement = Vector2.ZERO
	aim = Vector2.ZERO
	knob = center
	action_fingers.clear()

func _input(event: InputEvent) -> void:
	if locked or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(center) < 112 and finger == -1:
				finger = event.index
				update_stick(event.position)
			elif attack_rect.has_point(event.position):
				aim_finger = event.index
				aim_center = event.position
				held_attack = true
			elif event.position.y > size.y - 180:
				for i in range(3):
					if skill_rects[i].has_point(event.position):
						action_fingers[event.index] = i + 1
						action.emit(i + 1)
		else:
			if event.index == finger:
				finger = -1
				movement = Vector2.ZERO
				knob = center
			if event.index == aim_finger:
				aim_finger = -1
				held_attack = false
				aim = Vector2.ZERO
			action_fingers.erase(event.index)
	if event is InputEventScreenDrag:
		if event.index == finger:
			update_stick(event.position)
		if event.index == aim_finger:
			aim = (event.position - aim_center).limit_length(65) / 65
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(center) < 110:
				finger = -2
				update_stick(event.position)
			elif attack_rect.has_point(event.position):
				held_attack = true
			else:
				for i in range(3):
					if skill_rects[i].has_point(event.position): action.emit(i + 1)
		else:
			if finger == -2:
				finger = -1
				movement = Vector2.ZERO
				knob = center
			held_attack = false
	if event is InputEventMouseMotion and finger == -2:
		update_stick(event.position)

func update_stick(point: Vector2) -> void:
	var offset = (point - center).limit_length(66)
	knob = center + offset
	movement = offset / 66
	if movement.length() < 0.12: movement = Vector2.ZERO

func notify(text: String) -> void:
	message = text
	message_time = 3.5

func _process(delta: float) -> void:
	message_time = maxf(0, message_time - delta)
	next_button.visible = clear
	bag_button.disabled = not clear
	queue_redraw()

func label_at(text: String, at: Vector2, pixels: int, color: Color = PALE) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

func _draw() -> void:
	if font == null: return
	draw_rect(Rect2(0, 0, size.x, 108), Color(0.035, 0.06, 0.08, 0.92))
	draw_line(Vector2(0, 108), Vector2(size.x, 108), Color("34434a"))
	label_at("C I N D E R F A L L", Vector2(28, 36), 23, GOLD)
	label_at(character_text, Vector2(safe_margin, 62), 19, Color("91a4ac"))
	draw_rect(Rect2(28, 76, 258, 10), Color("342d34"))
	draw_rect(Rect2(28, 76, 258 * clampf(health, 0, 1), 10), Color("d86b62"))
	draw_rect(Rect2(28, 91, 258, 5), Color("253744"))
	draw_rect(Rect2(28, 91, 258 * clampf(mana, 0, 1), 5), Color("71bcd0"))
	label_at(hp_text, Vector2(302, 88), 20)
	label_at(room_text, Vector2(size.x * 0.40, 40), 23, GOLD)
	label_at(objective, Vector2(size.x * 0.40, 70), 17, Color("b0c1c4"))
	if boss_ratio >= 0:
		label_at("THE CINDER WARDEN", Vector2(size.x / 2 - 125, 146), 20, GOLD)
		draw_rect(Rect2(size.x / 2 - 240, 156, 480, 8), Color("382b30"))
		draw_rect(Rect2(size.x / 2 - 240, 156, 480 * boss_ratio, 8), Color("d3775e"))
	draw_circle(center, 89, Color(0.045, 0.085, 0.105, 0.75))
	draw_arc(center, 89, 0, TAU, 64, Color("52666c"), 2, true)
	draw_arc(center, 66, 0, TAU, 48, Color("30464e"), 1, true)
	draw_circle(knob, 34, Color("435e68"))
	draw_arc(knob, 34, 0, TAU, 48, GOLD, 1.5, true)
	label_at("MOVE", center + Vector2(-25, 119), 15, Color("a0b4bc"))
	draw_circle(attack_rect.get_center(), 58, Color("865448") if held_attack else Color("493a36"))
	draw_arc(attack_rect.get_center(), 58, 0, TAU, 64, GOLD, 2, true)
	label_at("SLASH", attack_rect.position + Vector2(20, 63), 22, GOLD)
	label_at("HOLD / AIM", attack_rect.position + Vector2(2, 143), 14, Color("a0b4bc"))
	for i in range(3):
		var rect = skill_rects[i]
		draw_style_box(button_style(), rect)
		label_at(["EMBER", "NOVA", "MEND"][i], rect.position + Vector2(13, 31), 19, GOLD)
		var cd = float(cooldowns[i + 1])
		label_at(("%.1fs" % cd) if cd > 0 else ["18 MP", "28 MP", "25 MP"][i], rect.position + Vector2(18, 63), 17, Color("8ab9c8"))
		if cd > 0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * minf(1, cd / [3.0, 7.0, 11.0][i]))), Color(0, 0, 0, 0.32))
	if message_time > 0:
		var width = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_rect(Rect2(size.x / 2 - width / 2 - 24, 184, width + 48, 48), Color(0.035, 0.06, 0.08, 0.94))
		label_at(message, Vector2(size.x / 2 - width / 2, 216), 22, GOLD)
	if OS.is_debug_build():
		label_at(debug_text, Vector2(28, 131), 13, Color("839ba5"))

func button_style() -> StyleBoxFlat:
	if cached_style != null: return cached_style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.12, 0.15, 0.94)
	style.border_color = Color("52676c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	cached_style = style
	return style
