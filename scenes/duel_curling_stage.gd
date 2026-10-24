class_name DuelCurlingStage
extends Control

signal shot_requested(value: int)
signal settled

const ART: Texture2D = preload("res://assets/ui/trickcal/duel/curling/bottle_cap.png")
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const GOLD := Color("ffdc79")
const MAX_PULL := 136.0

var arena: DuelArena
var world := BottleCapPhysics.new()
var mode: StringName = &"idle"
var shooter := 0
var dragging := false
var power := 0.55
var aim := 0
var result_winner := -1
var impacts := 0
var hold_seconds := 0.0
var _pointer := -2
var _drag_start := Vector2.ZERO
var _accumulator := 0.0
var _rest_time := 0.0
var _shot_ticks := 0
var launch_direction := Vector2.RIGHT
var _sparks: Array[Dictionary] = []
var _falls: Dictionary = {}
var _trails: Array = [[], []]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(cancel_drag)
	get_viewport().size_changed.connect(cancel_drag)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_drag()

func reset_table() -> void:
	world = BottleCapPhysics.new()
	mode = &"rest"
	result_winner = -1
	impacts = 0
	_falls.clear()
	_sparks.clear()
	_trails = [[], []]
	queue_redraw()

func begin_aim(index: int, local: bool) -> void:
	shooter = index
	mode = &"aim" if local else &"waiting"
	power = 0.55
	aim = 0
	cancel_drag()
	queue_redraw()

func cancel_drag() -> void:
	dragging = false
	_pointer = -2
	queue_redraw()

func cancel() -> void:
	var was_sliding := mode == &"slide"
	mode = &"idle"
	cancel_drag()
	if was_sliding:
		settled.emit()

func field_scale() -> float:
	return minf((size.x - 36.0) / 650.0, (size.y - 82.0) / 252.0)

func field_origin() -> Vector2:
	return Vector2((size.x - 650.0 * field_scale()) / 2.0, 42.0)

func to_screen(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * (field_origin() + point * field_scale())

func _model_point(point: Vector2) -> Vector2:
	return (get_global_transform_with_canvas().affine_inverse() * point - field_origin()) / maxf(field_scale(), 0.01)

func handle_input(event: InputEvent) -> bool:
	if mode != &"aim":
		return false
	if event is InputEventKey:
		if not event.pressed:
			return false
		match event.keycode:
			KEY_ESCAPE: cancel_drag()
			KEY_LEFT: aim = posmod(aim - 3, 360)
			KEY_RIGHT: aim = posmod(aim + 3, 360)
			KEY_UP: power = minf(1.0, power + 0.04)
			KEY_DOWN: power = maxf(0.06, power - 0.04)
			KEY_SPACE:
				if not event.echo:
					fire()
			_: return false
		queue_redraw()
		return true
	var id := -1
	var press := false
	var release := false
	var handled := false
	var point := Vector2.ZERO
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_drag()
			return true
		if event.button_index != MOUSE_BUTTON_LEFT or (_pointer >= 0 and dragging):
			return false
		point = event.position
		press = event.pressed
		release = not press
	elif event is InputEventScreenTouch:
		id = event.index
		if dragging and id != _pointer:
			return false
		if event.canceled:
			cancel_drag()
			return true
		point = event.position
		press = event.pressed
		release = not press
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if event is InputEventScreenDrag:
			id = event.index
		if dragging and id == _pointer:
			update_pull(event.position)
			return true
		return false
	else:
		return false
	if press and _model_point(point).distance_to(Vector2(BottleCapPhysics.START) / BottleCapPhysics.SCALE) <= 33.0:
		handled = true
		dragging = true
		_pointer = id
		_drag_start = _model_point(point)
		power = 0.0
		aim = 0
	elif release and dragging and id == _pointer:
		handled = true
		update_pull(point)
		cancel_drag()
		if power >= 0.04:
			fire()
	queue_redraw()
	return handled

func update_pull(point: Vector2) -> void:
	var pull := _drag_start - _model_point(point)
	if pull.length() <= 2.0:
		power = 0.0
		return
	power = clampf(pull.length() / MAX_PULL, 0.0, 1.0)
	aim = posmod(roundi(rad_to_deg(pull.angle())), 360)
	queue_redraw()

func fire() -> void:
	if mode != &"aim" or power < 0.04:
		return
	var value := BottleCapPhysics.encode_direction(roundi(power * power * BottleCapPhysics.POWER_MAX), aim)
	mode = &"waiting"
	cancel_drag()
	shot_requested.emit(value)

func play_shot(index: int, value: int) -> void:
	cancel_drag()
	shooter = index
	world.shoot(index, value)
	launch_direction = Vector2(world.caps[index].vel).normalized()
	_accumulator = 0.0
	_rest_time = 0.0
	_shot_ticks = 0
	hold_seconds = 0.0
	mode = &"slide"
	Sfx.play(&"yut_clack", -5.0, 0.0, 1.4)
	queue_redraw()

func _process(delta: float) -> void:
	if mode == &"idle":
		return
	advance(delta)

func advance(delta: float) -> void:
	for spark: Dictionary in _sparks:
		spark.age = float(spark.age) + delta
	for index: int in _falls.keys():
		_falls[index] = float(_falls[index]) + delta
	if mode == &"slide":
		if hold_seconds > 0.0:
			hold_seconds = maxf(0.0, hold_seconds - delta)
		else:
			_accumulator += delta
			while world.moving() and _accumulator >= 1.0 / BottleCapPhysics.HZ and _shot_ticks < BottleCapPhysics.MAX_TICKS:
				_accumulator -= 1.0 / BottleCapPhysics.HZ
				world.step()
				_shot_ticks += 1
				for event: Dictionary in world.events:
					if event.kind == &"contact":
						impacts += 1
						hold_seconds = 0.045
						_sparks.append({"pos": Vector2(event.pos) / BottleCapPhysics.SCALE, "age": 0.0})
						Sfx.play(&"mahjong_tap", -3.0, 0.0, 1.65)
					elif event.kind == &"rail":
						Sfx.play(&"toy_click", -6.0)
					elif event.kind == &"fall":
						_falls[int(event.index)] = 0.0
						Sfx.play(&"launch", -8.0)
				for index: int in 2:
					if bool(world.caps[index].active) and not bool(world.caps[index].out):
						(_trails[index] as Array).push_front(Vector2(world.caps[index].pos) / BottleCapPhysics.SCALE)
						if (_trails[index] as Array).size() > 12:
							(_trails[index] as Array).pop_back()
				if hold_seconds > 0.0 or not world.moving():
					break
		if not world.moving() or _shot_ticks >= BottleCapPhysics.MAX_TICKS:
			_rest_time += delta
			if _rest_time >= 0.55:
				mode = &"rest"
				settled.emit()
	queue_redraw()

func show_result(winner: int) -> void:
	mode = &"result"
	result_winner = winner
	queue_redraw()

func _text(text: String, point: Vector2, px: int, tint: Color) -> void:
	text = L10n.t(text)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(FONT, point + Vector2(-width / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)

func _draw() -> void:
	if arena == null or mode == &"idle":
		return
	var sc := field_scale()
	var origin := field_origin()
	var bounds := Rect2(origin, Vector2(650, 252) * sc)
	draw_style_box(CardSkin.style(Color("251e30"), Color("76616a"), 2, 14), bounds.grow(8))
	draw_rect(Rect2(origin + Vector2(0, 12) * sc, Vector2(600, 252) * sc), Color("784834"))
	draw_style_box(CardSkin.style(Color("e2b677"), Color("fff1c8"), 3, 12), Rect2(origin, Vector2(600, 252) * sc))
	for plank: int in range(1, 4):
		var y := float(plank) * 63.0
		draw_line(origin + Vector2(6, y) * sc, origin + Vector2(594, y) * sc, Color(0.55, 0.31, 0.15, 0.21), 1, true)
	for stripe: int in 3:
		draw_rect(Rect2(origin + Vector2(474 + stripe * 40, 4) * sc, Vector2(40, 244) * sc), Color(0.4, 0.62, 0.29, 0.06 + float(stripe) * 0.045))
	draw_line(origin + Vector2(600, 0) * sc, origin + Vector2(600, 252) * sc, Color("eb765b"), 5 * sc, true)
	for mark: int in 10:
		var y := 8.0 + float(mark) * 25.0
		draw_line(origin + Vector2(603, y) * sc, origin + Vector2(613, y + 9) * sc, Color("f6bf74"), 3 * sc, true)
	_text("절벽", origin + Vector2(621, -18) * sc, 20, Color("ffb995"))
	for dash: int in 10:
		draw_line(origin + Vector2(72, 8 + dash * 24) * sc, origin + Vector2(72, 19 + dash * 24) * sc, Color(1, 1, 0.9, 0.4), 2 * sc, true)
	for index: int in 2:
		var seat := arena.challenger if index == 0 else arena.defender
		var tint: Color = MainBoard.PLAYER_COLORS.get(seat, Color.WHITE)
		var title := arena._seat_name(seat)
		if result_winner == seat:
			title += " 승리!"
		_text(title, Vector2(size.x * (0.27 if index == 0 else 0.73), 18), 20, GOLD if result_winner == seat else tint.lightened(0.3))
		var trail: Array = _trails[index]
		if mode == &"slide" and world.moving():
			for j: int in range(1, trail.size()):
				draw_line(origin + (trail[j - 1] as Vector2) * sc, origin + (trail[j] as Vector2) * sc, Color(tint, 0.18 * (1.0 - float(j) / 12.0)), 10 * sc, true)
		if bool(world.caps[index].active):
			var body: Dictionary = world.caps[index]
			var point := Vector2(body.pos) / BottleCapPhysics.SCALE
			var fall := clampf(float(_falls.get(index, 0.0)) / 0.5, 0.0, 1.0) if bool(body.out) else 0.0
			point += Vector2(22 * fall, 58 * fall * fall)
			_cap(point, float(body.angle) / 100000.0 + fall * 3.0, tint, sc * (1.0 - fall * 0.8), 1.0 - fall)
		if mode == &"result":
			_text(world.distance_text(index), Vector2(size.x * (0.27 if index == 0 else 0.73), size.y - 17), 19, Color("e5dccc"))
	if mode in [&"aim", &"waiting"]:
		var seat := arena.challenger if shooter == 0 else arena.defender
		_cap(Vector2(BottleCapPhysics.START) / BottleCapPhysics.SCALE, 0.0, MainBoard.PLAYER_COLORS.get(seat, Color.WHITE), sc, 1.0)
		if mode == &"aim":
			_draw_arrow(origin, sc)
	if mode == &"slide" and _shot_ticks < 30 and launch_direction != Vector2.ZERO:
		var from := origin + Vector2(BottleCapPhysics.START) / BottleCapPhysics.SCALE * sc
		var fade := 1.0 - float(_shot_ticks) / 30.0
		var tip := from + launch_direction * 105 * sc
		var normal := launch_direction.orthogonal()
		draw_line(from + launch_direction * 28 * sc, tip - launch_direction * 14 * sc, Color(1.0, 0.91, 0.45, fade), 3 * sc, true)
		draw_colored_polygon(PackedVector2Array([tip, tip - launch_direction * 17 * sc + normal * 8 * sc, tip - launch_direction * 17 * sc - normal * 8 * sc]), Color(1.0, 0.72, 0.25, fade))
	for spark: Dictionary in _sparks:
		var age := float(spark.age)
		if age >= 0.25:
			continue
		var at := origin + (spark.pos as Vector2) * sc
		for ray: int in 8:
			var dir := Vector2.from_angle(float(ray) * TAU / 8.0)
			draw_line(at + dir * (8 + age * 40) * sc, at + dir * (18 + age * 85) * sc, Color(1, 0.95, 0.7, 1.0 - age / 0.25), 2.5 * sc, true)

func _cap(point: Vector2, angle: float, tint: Color, sc: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var at := field_origin() + point * field_scale()
	draw_circle(at + Vector2(2, 4) * sc, 22 * sc, Color(0.20, 0.12, 0.07, alpha * 0.35), true, -1, true)
	draw_arc(at, 25 * sc, 0, TAU, 48, Color(tint, alpha), 3 * sc, true)
	draw_set_transform(at, angle, Vector2.ONE * sc)
	draw_texture_rect(ART, Rect2(-25, -25, 50, 50), false, Color(tint.lightened(0.65), alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_arrow(origin: Vector2, sc: float) -> void:
	var start := origin + Vector2(BottleCapPhysics.START) / BottleCapPhysics.SCALE * sc
	var direction := Vector2.from_angle(deg_to_rad(float(aim)))
	var normal := direction.orthogonal()
	var base := start + direction * 29 * sc
	var tip := start + direction * (78 + power * 108) * sc
	var neck := tip - direction * 19 * sc
	var color := Color("fff06a").lerp(Color("ff6741"), power)
	var cursor := base
	for index: int in 5:
		var length := (3.5 + float(index) * 2.0) * sc
		var half := (2.3 + float(index) * 0.35) * sc
		var end := cursor + direction * length
		draw_colored_polygon(PackedVector2Array([cursor + normal * half, end + normal * half, end - normal * half, cursor - normal * half]), Color("fff06a").lerp(color, float(index) / 5.0))
		cursor = end + direction * 3 * sc
	draw_colored_polygon(PackedVector2Array([cursor + normal * 4 * sc, neck + normal * 4 * sc, neck + normal * 10 * sc, tip, neck - normal * 10 * sc, neck - normal * 4 * sc, cursor - normal * 4 * sc]), color)
	if dragging and power > 0.0:
		draw_line(start - direction * 27 * sc, start - direction * power * MAX_PULL * sc, Color(1, 1, 0.9, 0.6), 2 * sc, true)
