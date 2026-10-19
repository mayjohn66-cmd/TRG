# File: res://scenes/duel_arena.gd
# Class: class_name DuelArena
# Role: ACT_09 가위바위보 결투장. 보드 한가운데 오픈 스테이지에 열려 손 고르기(5초) -> "가위... 바위... 보!" 공개 -> 승패(무승부 재대결) -> 승자의 말 고르기 안내를 보여 준다. 엔진 이벤트를 큐로 받아 차례로 연출만 하며 승패는 엔진이 정한다
class_name DuelArena
extends PanelContainer

## 로컬 플레이어가 손을 골랐다 (MainBoard가 duel_pick 행동으로 보낸다).
signal hand_chosen(player_id: int, hand: int)
## 시간이 다 됐다: step은 &"pick"(seat이 무작위로 낸다) 또는 &"strike"(가장 앞선 말을 민다).
signal timed_out(step: StringName, seat: int)
## 이긴 사람이 말을 고를 차례다: is_local이면 화면이 보드 위 말 선택을 연다.
signal strike_started(winner: int, candidates: Array, is_local: bool)
signal strike_ended
signal closed

const SIZE: Vector2 = Vector2(404.0, 300.0)
const HAND_NAMES: Array[String] = ["바위", "가위", "보"]
const SKIN: Color = Color("f8d9a8")
const SKIN_EDGE: Color = Color("8a5a2b")

var board: MainBoard = null
var challenger: int = -1
var defender: int = -1
## 이 화면에서 직접 손을 고를 수 있는 좌석 (AI 대전은 내 자리, 핫시트는 모든 자리).
var local_seats: Array[int] = []
## 공개 연출이 재생 중이다 (봇은 이 동안 기다린다).
var animating: bool = false

var _queue: Array[Dictionary] = []
var _running: bool = false
var _opened: bool = false
var _step: StringName = &"idle"
var _pick_seat: int = -1
var _picked: Dictionary = {}
var _timer_left: float = 0.0
var _timer_total: float = 1.0
var _timer_step: StringName = &""
var _roll_clock: float = 0.0
var _closing: bool = false

var _title: Label = null
var _message: Label = null
var _icons: Dictionary = {}
var _chips: Dictionary = {}
var _hands_row: HBoxContainer = null
var _button_row: HBoxContainer = null
var _bar: ProgressBar = null


func setup(owner_board: MainBoard, challenger_id: int, defender_id: int, seats: Array[int]) -> void:
	board = owner_board
	challenger = challenger_id
	defender = defender_id
	local_seats = seats.duplicate()
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SIZE
	add_theme_stylebox_override("panel", board._style(Color(0.063, 0.086, 0.14, 0.97), Color("ffd43b"), 5, 22, 26, 14))
	visible = false
	_build()


## 알림 카드가 끝난 뒤 결투장을 연다. 그때까지 도착한 이벤트는 큐에 쌓였다가 차례로 재생된다.
func open() -> void:
	if _opened:
		return
	_opened = true
	visible = true
	_place()
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	pivot_offset = size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pump()
	# 컨테이너가 크기를 정한 다음 프레임에 한 번 더 가운데로 맞춘다.
	await get_tree().process_frame
	if is_inside_tree() and not _closing:
		_place()


func push_event(kind: StringName, data: Dictionary) -> void:
	_queue.append({"kind": kind, "data": data})
	if _opened:
		_pump()


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = board._make_label("[ 1:1 결투! %s vs %s ]" % [board._player_name(challenger), board._player_name(defender)], 22, Color("ffd43b"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 5)
	_title.add_theme_color_override("font_outline_color", Color("3b2a00"))
	column.add_child(_title)
	_hands_row = HBoxContainer.new()
	_hands_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hands_row.add_theme_constant_override("separation", 10)
	column.add_child(_hands_row)
	for player_id: int in [challenger, defender]:
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 4)
		side.custom_minimum_size = Vector2(170, 0)
		var chip: Label = board._make_label("%s%s" % [board._player_name(player_id), " (신청)" if player_id == challenger else ""], 16, board.PLAYER_COLORS[player_id])
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_child(chip)
		var icon := HandIcon.new()
		icon.custom_minimum_size = Vector2(110, 92)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mirror = player_id == defender
		icon.tint = board.PLAYER_COLORS[player_id]
		side.add_child(icon)
		var state_label: Label = board._make_label("", 14, Color("ced4da"))
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		side.add_child(state_label)
		_hands_row.add_child(side)
		_icons[player_id] = icon
		_chips[player_id] = state_label
		if player_id == challenger:
			var versus: Label = board._make_label("VS", 26, Color("ff8787"))
			versus.add_theme_constant_override("outline_size", 6)
			versus.add_theme_color_override("font_outline_color", Color("2b0a0a"))
			versus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_hands_row.add_child(versus)
	_message = board._make_label("", 18, Color.WHITE)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(SIZE.x - 40.0, 30.0)
	_message.add_theme_constant_override("outline_size", 5)
	_message.add_theme_color_override("font_outline_color", Color("0b0e16"))
	column.add_child(_message)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(SIZE.x - 60.0, 10.0)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.visible = false
	_bar.add_theme_stylebox_override("background", board._style(Color("0b0e16"), Color("5c6b94"), 2, 8, 0, 0))
	_bar.add_theme_stylebox_override("fill", board._style(Color("fcc419"), Color("fff3bf"), 2, 6, 0, 0))
	column.add_child(_bar)
	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 10)
	_button_row.visible = false
	column.add_child(_button_row)
	for hand: int in 3:
		var button: Button = board._make_button("%s" % HAND_NAMES[hand], _on_hand_pressed.bind(hand), 22, Color("3b4766"), 12)
		button.name = "Hand%d" % hand
		button.custom_minimum_size = Vector2(116, 58)
		button.icon = null
		_button_row.add_child(button)


func _place() -> void:
	reset_size()
	position = board._board_center() - size / 2.0
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	if not _opened or _closing:
		return
	_roll_clock += delta
	# 아직 안 낸 쪽은 손 모양이 빠르게 돌아가며 고민하는 모습을 보여 준다.
	if _step == &"pick" and not animating:
		var frame: int = int(_roll_clock * 10.0) % 3
		for player_id: int in [challenger, defender]:
			if not _picked.has(player_id) and not _is_hidden_for_local(player_id):
				(_icons[player_id] as HandIcon).set_hand(frame)
	if _timer_left > 0.0:
		_timer_left -= delta
		_bar.value = clampf(_timer_left / _timer_total, 0.0, 1.0)
		if _timer_left <= 0.0:
			_timer_left = 0.0
			_bar.visible = false
			timed_out.emit(_timer_step, _pick_seat)


## 내가 고르는 중인 자리의 손 모양은 비밀이라 돌리지 않고 물음표로 둔다.
func _is_hidden_for_local(player_id: int) -> bool:
	return player_id == _pick_seat


func _start_timer(seconds: float, step: StringName) -> void:
	_timer_total = maxf(seconds, 0.1)
	_timer_left = seconds
	_timer_step = step
	_bar.max_value = 1.0
	_bar.value = 1.0
	_bar.visible = true


func _stop_timer() -> void:
	_timer_left = 0.0
	_bar.visible = false


func _say(text: String, color: Color = Color.WHITE) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * board._pace()).timeout


# ---------------------------------------------------------------------------
# 이벤트 재생 큐
# ---------------------------------------------------------------------------

func _pump() -> void:
	if _running or _closing:
		return
	_running = true
	while not _queue.is_empty() and not _closing:
		var item: Dictionary = _queue.pop_front()
		await _play(item["kind"], item["data"])
		if not is_inside_tree():
			return
	_running = false


func _play(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"duel_started":
			_say("결투 신청! %s → %s" % [board._player_name(challenger), board._player_name(defender)], Color("ffe066"))
			Sfx.play(&"card_impact")
			await _wait(0.9)
			_begin_pick()
		&"duel_pick_in":
			var player_id: int = int(data["player_id"])
			_picked[player_id] = true
			_refresh_chips()
		&"duel_revealed":
			await _play_reveal(data)
		&"duel_strike_wait":
			_play_strike_wait(data)
		&"duel_resolved":
			await _play_resolved(data)


## 이번 판에서 직접 고를 차례인 로컬 좌석을 찾아 버튼을 연다. 없으면(컴퓨터끼리 / 상대만 남음) 중계·대기 상태다.
func _begin_pick() -> void:
	_step = &"pick"
	_pick_seat = -1
	for seat: int in [challenger, defender]:
		if local_seats.has(seat) and not _picked.has(seat):
			_pick_seat = seat
			break
	for player_id: int in [challenger, defender]:
		(_icons[player_id] as HandIcon).set_hand(-1 if _picked.has(player_id) or player_id == _pick_seat else 0)
	_refresh_chips()
	if _pick_seat != -1:
		_button_row.visible = true
		var multiple: bool = local_seats.has(challenger) and local_seats.has(defender)
		_say("%s, 손을 고르세요!" % board._player_name(_pick_seat) if multiple else "가위바위보! 손을 고르세요", Color.WHITE)
		_start_timer(DuelRules.TIME_PICK * board.manager.timer_scale, &"pick")
	else:
		_button_row.visible = false
		var both_computers: bool = not local_seats.has(challenger) and not local_seats.has(defender)
		_say("컴퓨터끼리 결투 중..." if both_computers else "상대가 고민하는 중...", Color("ced4da"))
		_stop_timer()


func _refresh_chips() -> void:
	for player_id: int in [challenger, defender]:
		(_chips[player_id] as Label).text = "선택 완료!" if _picked.has(player_id) else ("고르는 중" if player_id == _pick_seat else "고민 중...")


func _on_hand_pressed(hand: int) -> void:
	if _pick_seat == -1 or _step != &"pick":
		return
	var seat: int = _pick_seat
	_picked[seat] = true
	_pick_seat = -1
	_button_row.visible = false
	_stop_timer()
	Sfx.play(&"ui_click")
	hand_chosen.emit(seat, hand)
	_refresh_chips()
	# 핫시트라면 다음 자리가 이어서 고른다 (상대가 보지 못하게 손은 가려져 있다).
	if _step == &"pick" and not _queue_has(&"duel_revealed"):
		await get_tree().create_timer(0.25).timeout
		if is_inside_tree() and _step == &"pick" and not animating:
			_begin_pick()


func _queue_has(kind: StringName) -> bool:
	for item: Dictionary in _queue:
		if item["kind"] == kind:
			return true
	return false


## "가위... 바위... 보!" 박자 뒤에 양쪽 손이 중앙에서 부딪히며 승패가 드러난다.
func _play_reveal(data: Dictionary) -> void:
	animating = true
	_step = &"reveal"
	_stop_timer()
	_button_row.visible = false
	var picks: Dictionary = data["picks"]
	var winner: int = int(data["winner"])
	for player_id: int in [challenger, defender]:
		(_icons[player_id] as HandIcon).set_hand(-1)
		(_chips[player_id] as Label).text = ""
	for beat: String in ["가위...", "바위...", "보!"]:
		_say(beat, Color("ffe066"))
		_shake_icons()
		Sfx.play(&"hop")
		await _wait(0.38)
		if not is_inside_tree():
			return
	for player_id: int in [challenger, defender]:
		var icon: HandIcon = _icons[player_id]
		icon.set_hand(int(picks[player_id]))
		icon.pivot_offset = icon.size / 2.0
		icon.scale = Vector2(1.5, 1.5)
		var pop: Tween = create_tween()
		pop.tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		(_chips[player_id] as Label).text = HAND_NAMES[int(picks[player_id])]
	var center: Vector2 = global_position + size / 2.0
	board.screen_shake(7.0, 0.25)
	board._impact_ring(center, Color("ffe066"), 60.0)
	Sfx.play(&"slam")
	await _wait(0.5)
	if not is_inside_tree():
		return
	if winner == -1:
		_say("무승부! 재대결!", Color("ffe066"))
		await _wait(1.0)
		_picked.clear()
		animating = false
		_begin_pick()
		return
	var loser: int = defender if winner == challenger else challenger
	(_chips[winner] as Label).add_theme_color_override("font_color", Color("ffe066"))
	if data["decided_by"] == &"draws":
		_say("연속 무승부! %s 판정승!" % board._player_name(winner), Color("ffe066"))
	else:
		_say("%s 승리!" % board._player_name(winner), Color("ffe066"))
	(_icons[loser] as HandIcon).modulate = Color(1, 1, 1, 0.45)
	await _wait(0.9)
	animating = false


func _shake_icons() -> void:
	for player_id: int in [challenger, defender]:
		var icon: HandIcon = _icons[player_id]
		icon.pivot_offset = icon.size / 2.0
		icon.rotation = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(icon, "rotation", -0.22 if player_id == challenger else 0.22, 0.12)
		tween.tween_property(icon, "rotation", 0.0, 0.2)


## 승자가 진 사람의 말을 고를 차례. 손 그림은 접어 보드 위의 붉게 깜빡이는 말이 잘 보이게 한다.
func _play_strike_wait(data: Dictionary) -> void:
	_step = &"strike"
	var winner: int = int(data["winner"])
	var loser: int = int(data["loser"])
	_compact()
	var local_winner: bool = local_seats.has(winner)
	if local_winner:
		_say("결투 승리! 출발선으로 날려 버릴 상대방의 말을 클릭하세요! (내 말은 +%d칸 전진)" % DuelRules.winner_advance(), Color("8ce99a"))
		_start_timer(DuelRules.TIME_STRIKE * board.manager.timer_scale, &"strike")
		_pick_seat = winner
	elif local_seats.has(loser):
		_say("결투 패배! 상대가 내 말을 출발선으로 날려 버립니다!", Color("ff8787"))
	else:
		_say("%s 승리! 날려 버릴 말을 고르는 중..." % board._player_name(winner), Color("ffe066"))
	strike_started.emit(winner, data["candidates"], local_winner)


## 손 그림을 접어 메시지 줄만 남기고 패널을 줄인다 (보드 위의 말이 잘 보이게).
func _compact() -> void:
	_hands_row.visible = false
	_button_row.visible = false
	custom_minimum_size = Vector2(SIZE.x, 120.0)
	reset_size()
	_place()


func _play_resolved(data: Dictionary) -> void:
	var winner: int = int(data["winner"])
	var loser: int = int(data["loser"])
	_stop_timer()
	if _step != &"strike":
		# 말이 하나뿐이거나 없어서 고르는 단계 없이 바로 끝난 경우의 결과 안내
		_compact()
	_step = &"result"
	strike_ended.emit()
	if int(data["pawn_id"]) == -1:
		_say("날려 버릴 말이 없어 결투가 끝났습니다", Color("ced4da"))
	elif local_seats.has(winner):
		_say("결투 승리! 상대 말을 장외 사출, 내 말은 +%d칸 전진!" % DuelRules.winner_advance(), Color("8ce99a"))
	elif local_seats.has(loser):
		_say("결투 패배! 내 말이 출발선으로 날아갔습니다!", Color("ff8787"))
	else:
		_say("%s의 말이 출발선으로 날아갔습니다" % board._player_name(loser), Color("ffe066"))
	await _wait(1.3)
	close_now()


func close_now() -> void:
	if _closing:
		return
	_closing = true
	animating = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.25)
	tween.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


## 손 모양을 코드로 그리는 아이콘 (폰트에 이모지가 없어서 직접 그린다). hand: 0 바위 / 1 가위 / 2 보 / -1 물음표
class HandIcon extends Control:
	var hand: int = -1
	var mirror: bool = false
	var tint: Color = Color.WHITE

	func set_hand(value: int) -> void:
		if value != hand:
			hand = value
			queue_redraw()

	func _capsule(a: Vector2, b: Vector2, width: float) -> void:
		draw_line(a, b, SKIN_EDGE, width + 5.0, true)
		draw_circle(a, (width + 5.0) / 2.0, SKIN_EDGE)
		draw_circle(b, (width + 5.0) / 2.0, SKIN_EDGE)
		draw_line(a, b, SKIN, width, true)
		draw_circle(a, width / 2.0, SKIN)
		draw_circle(b, width / 2.0, SKIN)

	func _palm(rect: Rect2) -> void:
		var edge := StyleBoxFlat.new()
		edge.bg_color = SKIN_EDGE
		edge.set_corner_radius_all(14)
		draw_style_box(edge, rect.grow(3.0))
		var fill := StyleBoxFlat.new()
		fill.bg_color = SKIN
		fill.set_corner_radius_all(12)
		draw_style_box(fill, rect)

	func _draw() -> void:
		var origin: Vector2 = size / 2.0
		var k: float = minf(size.x, size.y) / 120.0
		draw_set_transform(origin, 0.0, Vector2((-1.0 if mirror else 1.0) * k, k))
		draw_circle(Vector2.ZERO, 52.0, Color(tint.r, tint.g, tint.b, 0.22))
		match hand:
			0:
				_palm(Rect2(-30, -6, 60, 44))
				for x: float in [-23.0, -8.0, 8.0, 23.0]:
					_capsule(Vector2(x, -10), Vector2(x, -10), 15.0)
				_capsule(Vector2(-34, 12), Vector2(-26, 4), 14.0)
			1:
				_palm(Rect2(-26, 6, 52, 40))
				_capsule(Vector2(-8, 8), Vector2(-24, -42), 14.0)
				_capsule(Vector2(8, 8), Vector2(24, -42), 14.0)
				_capsule(Vector2(-16, 12), Vector2(-16, 12), 13.0)
				_capsule(Vector2(30, 24), Vector2(24, 18), 13.0)
			2:
				_palm(Rect2(-28, 4, 56, 42))
				for index: int in 4:
					var x: float = -21.0 + index * 14.0
					_capsule(Vector2(x, 6), Vector2(x * 1.15, -40.0 + absf(x) * 0.2), 12.0)
				_capsule(Vector2(-30, 24), Vector2(-46, 2), 12.0)
			_:
				_palm(Rect2(-30, -30, 60, 60))
				draw_string(ThemeDB.fallback_font, Vector2(-14, 18), "?", HORIZONTAL_ALIGNMENT_CENTER, 28.0, 56, Color("8a5a2b"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
