## Public button events drive this stage. Never inspect the hidden bomb index.
class_name DuelPumpkinStage
extends Control

signal finished

const PUMPKIN: Texture2D = preload("res://assets/ui/trickcal/duel/pumpkin/pumpkin.png")
const ANGRY: Texture2D = preload("res://assets/ui/trickcal/duel/pumpkin/petit-speaki-angry.webp")
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
## Native 30 FPS GIF has 73 frames with a 30/40/30 ms cadence (2.43 s).
const ANGRY_DURATION := 2.43
const ANGRY_FRAMES := 73
const FRAME_TIMES: Array[int] = [30, 40, 30]
const POP_AT := 0.76
const APPEAR_DELAY := 0.12
const APPEAR_TIME := 0.65
const SAFE_TIME := 0.95
const COLORS: Array[Color] = [Color("f49091"), Color("f5bd58"), Color("8dbe82"), Color("72baca"), Color("b49cdb")]
var arena: DuelArena
var buttons: Array[Button] = []
var used: Array[int] = []
var active := false
var elapsed := 0.0
var selected := -1
var bomb := false
var popped := false
var result_text := ""
var _pop_sound := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	for index: int in 5:
		var button := Button.new()
		button.name = "PumpkinButton%d" % index
		button.tooltip_text = "%d번 버튼 [%d]" % [index + 1, index + 1]
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(1, 1, 1, 0.0)
		focus.border_color = Color("fff4b5")
		focus.set_border_width_all(3)
		focus.set_corner_radius_all(18)
		button.add_theme_stylebox_override("focus", focus)
		button.pressed.connect(func() -> void: arena._pick_hole(index))
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		add_child(button)
		buttons.append(button)
	resized.connect(_layout_buttons)
	_layout_buttons()

func _button_at(index: int) -> Vector2:
	return Vector2(64.0 + float(index) * (size.x - 128.0) / 4.0, size.y - 54.0)

func _layout_buttons() -> void:
	for index: int in buttons.size():
		buttons[index].position = _button_at(index) - Vector2(44, 47)
		buttons[index].size = Vector2(88, 94)
	queue_redraw()

func refresh(can_pick: bool) -> void:
	for index: int in buttons.size():
		buttons[index].disabled = not can_pick or used.has(index)
	queue_redraw()

func mark_pending(index: int) -> void:
	selected = index
	refresh(false)

func play_press(index: int, exploded: bool) -> void:
	selected = index
	bomb = exploded
	elapsed = 0.0
	active = true
	_pop_sound = false
	if not used.has(index): used.append(index)
	refresh(false)
	Sfx.play(&"ui_click", -4.0)

func cancel() -> void:
	var was_active := active
	active = false
	refresh(false)
	if was_active: finished.emit()

func show_result(loser: String) -> void:
	result_text = "%s 패배!" % loser
	queue_redraw()

func _process(delta: float) -> void:
	if not visible or not active: return
	elapsed += delta
	if bomb and elapsed >= POP_AT and not _pop_sound:
		_pop_sound = true
		popped = true
		Sfx.play(&"trap", -3.0)
		if is_instance_valid(arena) and is_instance_valid(arena.board):
			arena.board.screen_shake(7.0, 0.20)
	var end: float = POP_AT + APPEAR_DELAY + ANGRY_DURATION + 0.35 if bomb else SAFE_TIME
	if elapsed >= end:
		active = false
		if not bomb: Sfx.play(&"good", -10.0)
		finished.emit()
	queue_redraw()

func _center() -> Vector2:
	return Vector2(size.x / 2.0, 128.0)

func _wire(index: int, t: float) -> Vector2:
	var start := _button_at(index) + Vector2(0, -25)
	var end := _center() + Vector2((index - 2) * 18, 75)
	return start.bezier_interpolate(start + Vector2(0, -68), end + Vector2((index - 2) * 14, 60), end, t)

func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	text = L10n.t(text)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(FONT, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("ece6d5")
	panel.border_color = Color("a4947d")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(20)
	draw_style_box(panel, Rect2(Vector2(4, 4), size - Vector2(8, 8)))
	var center := _center()
	# Five independent wires stay visible all the way to their pumpkin sockets.
	for index: int in 5:
		var points := PackedVector2Array()
		for sample: int in 25: points.append(_wire(index, float(sample) / 24.0))
		draw_polyline(points, Color("72665f"), 8.0, true)
		draw_polyline(points, COLORS[index].darkened(0.15), 4.5, true)
		if active and selected == index and elapsed < 0.43:
			var pulse := _wire(index, clampf(elapsed / 0.40, 0.0, 1.0))
			draw_circle(pulse, 10, Color(1, 0.92, 0.60, 0.25))
			draw_circle(pulse, 5, Color("fff8d7"))
	# Shadow and textured pumpkin use the same shared center throughout the burst.
	draw_set_transform(center + Vector2(0, 79), 0, Vector2(1, 0.18))
	draw_circle(Vector2.ZERO, 92, Color(0.32, 0.25, 0.22, 0.17))
	draw_set_transform(Vector2.ZERO)
	if not popped:
		var stretch := Vector2.ONE
		var angle := 0.0
		if active and elapsed > 0.4:
			var t := elapsed - 0.4
			if bomb:
				stretch = Vector2.ONE * (1.0 + 0.24 * clampf(t / (POP_AT - 0.4), 0, 1))
				angle = sin(t * 65.0) * 0.045
			else:
				stretch = Vector2(1 + sin(t * 15) * 0.035, 1 - sin(t * 15) * 0.035)
				angle = sin(t * 25) * 0.025 * (1 - clampf(t / 0.55, 0, 1))
		draw_set_transform(center, angle, stretch)
		draw_texture_rect(PUMPKIN, Rect2(Vector2(-126, -115), Vector2(252, 230)), false)
		draw_set_transform(Vector2.ZERO)
	else:
		var t := maxf(elapsed - POP_AT, 0.0)
		_draw_burst(center, t)
		var motion_time := maxf(t - APPEAR_DELAY, 0.0)
		var elapsed_ms := int(minf(motion_time, ANGRY_DURATION - 0.001) * 1000.0)
		var frame := 0
		for index: int in ANGRY_FRAMES:
			var duration: int = FRAME_TIMES[index % 3]
			if elapsed_ms < duration: break
			elapsed_ms -= duration
			frame += 1
		frame = mini(frame, ANGRY_FRAMES - 1)
		# Let the first flash clear, then grow gently while fading into the smoke.
		var progress := clampf(motion_time / APPEAR_TIME, 0.0, 1.0)
		var appear := progress * progress * (3.0 - 2.0 * progress)
		var extent := Vector2(232, 232) * lerpf(0.58, 1.0, appear)
		var at := center + Vector2(0, 4 + (1.0 - appear) * 24.0)
		draw_texture_rect_region(ANGRY, Rect2(at - extent / 2.0, extent), Rect2(Vector2((frame % 10) * 256, floori(float(frame) / 10.0) * 256), Vector2(256, 256)), Color(1, 1, 1, appear))
		if t < 0.7:
			_text("펑!", center + Vector2(132, -58), 35, Color("a55537"))
	if not result_text.is_empty(): _text(result_text, Vector2(size.x / 2.0, 247), 25, Color("9b403f"))
	# Depressed switches remain legible and cannot be selected a second time.
	for index: int in 5:
		var at := _button_at(index)
		var pressed := used.has(index) or (selected == index and not active)
		var safe := used.has(index) and not (bomb and index == selected) and (index != selected or not active or elapsed >= 0.64)
		var color := Color("a9bca3") if safe else COLORS[index]
		if popped and index == selected: color = Color("ed6a62")
		if index < buttons.size() and buttons[index].is_hovered() and not buttons[index].disabled: color = color.lightened(0.15)
		draw_set_transform(at, 0, Vector2(1, 0.55))
		draw_circle(Vector2(0, 10), 35, Color("75675f"))
		draw_circle(Vector2.ZERO, 35, Color("fff4cf"))
		draw_circle(Vector2(0, 4 if pressed else -8), 28, color.darkened(0.18))
		draw_circle(Vector2(0, 0 if pressed else -14), 28, color)
		draw_arc(Vector2(0, 0 if pressed else -14), 23, PI * 1.12, PI * 1.85, 16, color.lightened(0.5), 3, true)
		draw_set_transform(Vector2.ZERO)
		_text("×" if safe else str(index + 1), at + Vector2(0, 3 if pressed else -4), 23, Color("64524b"))

func _draw_burst(center: Vector2, t: float) -> void:
	if t > 1.1: return
	var fade := 1.0 - clampf(t / 1.1, 0, 1)
	# Radial wedges carry the original pumpkin artwork rather than unrelated debris.
	var corners: Array[Vector2] = [Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1), Vector2(1,0), Vector2(1,1), Vector2(0,1), Vector2(-1,1), Vector2(-1,0), Vector2(-1,-1)]
	for index: int in 8:
		var direction := (corners[index] + corners[index + 1]).normalized()
		var offset := direction * (t * 190.0) + Vector2(0, t * t * 220)
		var vertices := PackedVector2Array([Vector2.ZERO, corners[index] * Vector2(126,115), corners[index + 1] * Vector2(126,115)])
		var uv := PackedVector2Array([Vector2(0.5,0.5), (corners[index] + Vector2.ONE)/2, (corners[index + 1] + Vector2.ONE)/2])
		draw_set_transform(center + offset, direction.x * t * 1.8)
		draw_polygon(vertices, PackedColorArray([Color(1,1,1,fade)]), uv, PUMPKIN)
	draw_set_transform(Vector2.ZERO)
	for index: int in 10:
		var direction := Vector2.from_angle(float(index) * TAU / 10.0)
		var point := center + direction * (35 + t * 170)
		draw_circle(point, (12 + index % 3 * 4) * fade, Color(1,0.96,0.78,fade * 0.8))
	if t < 0.11: draw_circle(center, 110 + t * 250, Color(1,0.94,0.65,(1-t/0.11)*0.8))
