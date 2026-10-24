## The clock and winner belong to DuelArena / DuelRules; this node only presents them.
class_name DuelHalliStage
extends Control

const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const BELL: Texture2D = preload("res://assets/ui/trickcal/slot/SLOT_BELL.png")
const FRUIT: Texture2D = preload("res://assets/ui/trickcal/slot/SLOT_LEMON.png")
const BACK: Texture2D = preload("res://assets/ui/trickcal/judgment_cards/backs/POKER_BACK.png")
const GOLD := Color("ffdc79")
const INK := Color("493951")
const FLIP_LEAD := 0.12
const SETTLE := 0.16

var arena: DuelArena
var bell_button: Button
var frozen_time := -1.0
var result: Dictionary = {}
var strikes: Dictionary = {}
var ring_seat := -1
var ring_age := 10.0
var active := false
var _last_card := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bell_button = Button.new()
	bell_button.name = "HalliBell"
	bell_button.flat = true
	bell_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	bell_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bell_button.tooltip_text = "데스벨 치기! [Space]"
	for style: String in ["normal", "hover", "pressed", "disabled"]:
		bell_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	bell_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	bell_button.button_down.connect(_bell_down)
	add_child(bell_button)
	resized.connect(_layout_bell)
	_layout_bell()

func start() -> void:
	active = true
	frozen_time = -1.0
	result.clear()
	strikes.clear()
	ring_seat = -1
	ring_age = 10.0
	_last_card = -1
	bell_button.disabled = arena.local_seats.size() != 1
	sync_clock()

func cancel() -> void:
	active = false
	if bell_button != null:
		bell_button.disabled = true

func _layout_bell() -> void:
	bell_button.position = Vector2(size.x / 2.0 - 63, 82)
	bell_button.size = Vector2(126, 150)

func _bell_down() -> void:
	if arena.local_seats.size() == 1:
		arena._press(arena.local_seats[0])

func display_time() -> float:
	return frozen_time if frozen_time >= 0.0 else maxf(arena._clock, 0.0)

func visible_counts(at: float = -1.0) -> Vector2i:
	var counts := Vector2i.ZERO
	var cards: Array = arena.setup_data.get("cards", [])
	var interval := float(arena.setup_data.get("interval", DuelRules.HALLI_INTERVAL))
	var time := display_time() if at < 0.0 else at
	for index: int in cards.size():
		if float(index) * interval > time + 0.000001:
			break
		counts[index % 2] = int(cards[index])
	return counts

func sync_clock() -> void:
	if not active:
		return
	var interval := float(arena.setup_data.get("interval", DuelRules.HALLI_INTERVAL))
	var cards: Array = arena.setup_data.get("cards", [])
	var top := mini(int(floor(display_time() / interval)), cards.size() - 1)
	if top > _last_card:
		_last_card = top
		Sfx.play(&"card_throw", -5.0)
	queue_redraw()

func strike(seat: int, milliseconds: int) -> void:
	if strikes.has(seat) or milliseconds < 0:
		return
	strikes[seat] = milliseconds
	var at := float(milliseconds) / 1000.0
	if frozen_time < 0.0 or at < frozen_time:
		frozen_time = at
		ring_seat = seat
		ring_age = 0.0
		Sfx.play(&"card_impact", -5.0)
		Sfx.play(&"halli_bell", 0.0, 0.0)
		arena.board.screen_shake(3.0, 0.12)
	queue_redraw()

func show_result(data: Dictionary, at: float) -> void:
	frozen_time = at
	result = data.duplicate(true)
	var picks: Dictionary = result["picks"]
	var first := -1
	var earliest := 1 << 30
	for seat: int in [arena.challenger, arena.defender]:
		var value := int(picks.get(seat, -1))
		if value >= 0 and value < earliest:
			earliest = value
			first = seat
	if first != -1:
		# Remote/bot timestamps can arrive ahead of their visible card. Ring only now.
		# A local strike has already played and must not ring a second time.
		if not strikes.has(first) or ring_seat != first:
			strikes.erase(first)
			frozen_time = -1.0
			strike(first, earliest)
	else:
		Sfx.play(&"bad", -6.0)
	bell_button.disabled = true
	queue_redraw()

func _process(delta: float) -> void:
	if not active:
		return
	ring_age += delta
	var can_press := arena._step == &"play" and arena.local_seats.size() == 1
	if can_press:
		can_press = not arena._submitted.has(arena.local_seats[0])
	bell_button.disabled = not can_press
	queue_redraw()

func _text(text: String, center: Vector2, px: int, color: Color) -> void:
	text = L10n.t(text)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(FONT, center + Vector2(-width / 2.0, px * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _panel(rect: Rect2, fill: Color, edge: Color, border: int = 2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(14)
	draw_style_box(style, rect)

func _draw() -> void:
	if arena == null or not active:
		return
	var time := display_time()
	var interval := float(arena.setup_data.get("interval", DuelRules.HALLI_INTERVAL))
	var cards: Array = arena.setup_data.get("cards", [])
	var counts := visible_counts()
	_panel(Rect2(0, 0, size.x, size.y), Color("172a30"), Color("38524c"))
	for pile: int in 2:
		var seat := arena.challenger if pile == 0 else arena.defender
		var x := size.x * (0.23 if pile == 0 else 0.77)
		var color: Color = MainBoard.PLAYER_COLORS.get(seat, Color.WHITE)
		var won := not result.is_empty() and int(result["winner"]) == seat
		_text(arena._seat_name(seat), Vector2(x, 25), 20, color.lightened(0.2))
		var top := -1
		for index: int in cards.size():
			if index % 2 == pile and float(index) * interval <= time + 0.000001:
				top = index
		var center := Vector2(x, 155)
		for layer: int in range(3, 0, -1):
			_panel(Rect2(center + Vector2(-75 + layer * 2, -101 + layer * 3), Vector2(150, 202)), Color("ddd3b9"), Color("62675b"), 1)
		var age := time - float(top) * interval if top >= 0 else 10.0
		var flip_scale := lerpf(0.65, 1.0, ease(clampf(age / SETTLE, 0.0, 1.0), 0.4))
		var next := top + 2 if top >= 0 else pile
		# Fold the old/back card before the boundary, but never show the new face early.
		if frozen_time < 0.0 and next < cards.size():
			var remaining := float(next) * interval - time
			if remaining > 0.0 and remaining < FLIP_LEAD:
				flip_scale = lerpf(0.10, 1.0, remaining / FLIP_LEAD)
		var lift := -sin(clampf(age / SETTLE, 0.0, 1.0) * PI) * 8.0
		draw_set_transform(center + Vector2(0, lift), 0.0, Vector2(flip_scale, 1.0))
		if top == -1:
			draw_texture_rect(BACK, Rect2(-75, -101, 150, 202), false)
		else:
			_panel(Rect2(-75, -101, 150, 202), Color("fff8e7"), GOLD if won else Color("d5b77c"), 4 if won else 3)
			var count := counts[pile]
			var points: Array[Vector2] = []
			match count:
				1: points = [Vector2.ZERO]
				2: points = [Vector2(-25, -32), Vector2(25, 32)]
				3: points = [Vector2(0, -43), Vector2(-29, 30), Vector2(29, 30)]
				4: points = [Vector2(-29, -38), Vector2(29, -38), Vector2(-29, 38), Vector2(29, 38)]
			var side := 80.0 if count == 1 else 59.0
			for point: Vector2 in points:
				draw_texture_rect(FRUIT, Rect2(point - Vector2.ONE * side / 2.0, Vector2.ONE * side), false)
			_text(str(count), Vector2(-54, -79), 19, INK)
			_text(str(count), Vector2(54, 79), 19, INK)
		draw_set_transform(Vector2.ZERO)
		var status := ""
		var status_color := Color("c8d9cd")
		if not result.is_empty():
			var pressed := int((result["picks"] as Dictionary).get(seat, -1))
			status = DuelRules.reaction_text(pressed, roundi(DuelRules.reaction_mark(arena.game, arena.setup_data) * 1000.0))
			if won:
				status = "승리!  " + status
				status_color = GOLD
		elif strikes.has(seat):
			status = "종을 쳤다!"
		_text(status, Vector2(x, 280), 20, status_color)
	var bell_center := Vector2(size.x / 2.0, 156)
	draw_circle(bell_center + Vector2(0, 38), 60, Color(0, 0, 0, 0.23))
	var press := sin(clampf(ring_age / 0.13, 0.0, 1.0) * PI)
	var wiggle := sin(ring_age * 48.0) * exp(-ring_age * 6.0) * 0.20
	if ring_age < 0.7:
		var tint: Color = MainBoard.PLAYER_COLORS.get(ring_seat, GOLD)
		for pulse: int in 2:
			var progress := clampf((ring_age - float(pulse) * 0.10) / 0.5, 0.0, 1.0)
			draw_arc(bell_center, 53 + progress * 40, 0, TAU, 64, Color(tint.lightened(0.3), (1.0 - progress) * 0.8), 3, true)
	draw_set_transform(bell_center + Vector2(0, press * 7), wiggle, Vector2(1.0 + press * 0.12, 1.0 - press * 0.15))
	draw_texture_rect(BELL, Rect2(-72, -79, 144, 158), false)
	draw_set_transform(Vector2.ZERO)
	if bell_button.has_focus() and not bell_button.disabled:
		draw_arc(bell_center, 73, 0, TAU, 64, GOLD, 2, true)
	if not result.is_empty():
		var cause: StringName = result["decided_by"]
		var headline := "딩!"
		var tint := GOLD
		if cause == &"foul":
			headline = "너무 빨랐다!"
			tint = Color("ff8b89")
		elif cause == &"nobody":
			headline = "시간 끝!"
		_text(headline, Vector2(size.x / 2.0, 43), 23, tint)
		_text("%d + %d = %d" % [counts.x, counts.y, counts.x + counts.y], Vector2(size.x / 2.0, 259), 20, tint)
