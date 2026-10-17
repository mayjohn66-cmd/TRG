# File: res://scenes/opening_sequence.gd
# Class: class_name OpeningSequence
# Role: 게임 시작 직후 1라운드 증강 선택 전에 재생하는 3단계 오프닝(중앙 VS 대진표 -> 각자 프로필 자리로 날아가기 -> [레이스 시작!] 타이틀 약 1초). 클릭하면 건너뛰며, 끝나면 finished를 보낸다. 연출만 담당한다
class_name OpeningSequence
extends Control

signal finished

const STEP_VS: float = 1.7
const STEP_FLY: float = 0.7
const STEP_TITLE: float = 1.05
const CARD_SIZE: Vector2 = Vector2(190, 250)

var _board: MainBoard = null
var _tween: Tween = null
var _done: bool = false
var _dim: ColorRect = null
var _vs_root: Control = null
var _cards: Dictionary = {}
var _skip_hint: Label = null
## 연출 속도 배율(설정의 연출 속도, 1~1.4배): 대진표와 날아가기 시간에만 곱한다. 타이틀은 항상 약 1초.
var _k: float = 1.0


func setup(board: MainBoard) -> void:
	_board = board
	z_index = 80
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## 대진표 -> 날아가기 -> 타이틀 순서로 약 4초. 클릭하면 즉시 건너뛴다.
func start() -> void:
	_k = clampf(_board._pace(), 1.0, 1.4)
	_dim = ColorRect.new()
	_dim.color = Color(0.078, 0.094, 0.141, 0.95)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_build_vs()
	_tween = create_tween()
	_tween.tween_interval(STEP_VS * _k)
	_tween.tween_callback(_step_fly)
	_tween.tween_interval(STEP_FLY * _k)
	_tween.tween_callback(_step_title)
	_tween.tween_interval(STEP_TITLE)
	_tween.tween_callback(_finish)


func _process(_delta: float) -> void:
	# 테스트가 즉시 모드로 바꾸면 곧바로 끝낸다.
	if _board != null and _board.instant_roll_for_test:
		_finish()


func _on_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		_finish()


# --- Step 1: 중앙 대진표(VS) ----------------------------------------------------

func _build_vs() -> void:
	var screen: Vector2 = get_viewport_rect().size
	_vs_root = Control.new()
	_vs_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vs_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vs_root)
	var ids: Array[int] = _board._player_ids
	var count: int = ids.size()
	var gap: float = 64.0
	var total_width: float = count * CARD_SIZE.x + (count - 1) * gap
	var left: float = (screen.x - total_width) / 2.0
	var top: float = (screen.y - CARD_SIZE.y) / 2.0 - 20.0
	for index: int in count:
		var player_id: int = ids[index]
		var card: Control = _make_vs_card(player_id)
		var home: Vector2 = Vector2(left + index * (CARD_SIZE.x + gap), top)
		# 좌석별로 사방에서 중앙으로 미끄러져 들어온다 (아래/오른쪽/위/왼쪽 순)
		var from_offset: Vector2 = [Vector2(0, 520), Vector2(620, 0), Vector2(0, -420), Vector2(-620, 0)][index % 4]
		card.position = home + from_offset
		card.modulate.a = 0.0
		_vs_root.add_child(card)
		_cards[player_id] = card
		var slide: Tween = card.create_tween().set_parallel(true)
		slide.tween_property(card, "position", home, 0.55 * _k).set_delay(0.1 * index * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slide.tween_property(card, "modulate:a", 1.0, 0.25 * _k).set_delay(0.1 * index * _k)
		if index < count - 1:
			var versus: Label = _board._make_label("VS", 30, Color("ff8787"))
			versus.add_theme_constant_override("outline_size", 7)
			versus.add_theme_color_override("font_outline_color", Color("3a0f0f"))
			versus.position = home + Vector2(CARD_SIZE.x + gap / 2.0 - 22.0, CARD_SIZE.y / 2.0 - 20.0)
			versus.modulate.a = 0.0
			_vs_root.add_child(versus)
			versus.create_tween().tween_property(versus, "modulate:a", 1.0, 0.3 * _k).set_delay((0.45 + 0.1 * index) * _k)
	_skip_hint = _board._make_label("클릭하면 건너뜁니다", 13, Color("868e96"))
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.position = Vector2(0, 700)
	_skip_hint.size = Vector2(screen.x, 20)
	_vs_root.add_child(_skip_hint)


func _make_vs_card(player_id: int) -> Control:
	var color: Color = MainBoard.PLAYER_COLORS[player_id]
	var card := Panel.new()
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _board._style(Color("1b2236"), color, 4, 16, 18, 0))
	var seat: Label = _board._make_label("P%d" % player_id, 20, color.lightened(0.3))
	seat.position = Vector2(12, 8)
	card.add_child(seat)
	var avatar := AvatarSlot.new()
	avatar.setup(player_id, color, Vector2(104, 104))
	avatar.set_character(_board._avatar_for(player_id))
	avatar.position = Vector2((CARD_SIZE.x - 104.0) / 2.0, 36)
	card.add_child(avatar)
	var name_label: Label = _board._make_label(_board._player_name(player_id), 20, Color("f1f3f5"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 152)
	name_label.size = Vector2(CARD_SIZE.x, 28)
	name_label.clip_text = true
	card.add_child(name_label)
	var role: String = "나" if player_id == _board.local_player_id else ("AI" if _board._bot.is_bot(player_id) else "참가자")
	var badge: Label = _board._make_label(role, 16, Color("2b2100") if role != "AI" else Color("f1f3f5"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _board._style(Color("ffd43b") if role == "나" else (Color("495057") if role == "AI" else Color("4dabf7")), Color(0, 0, 0, 0), 0, 12, 0, 2))
	badge.position = Vector2((CARD_SIZE.x - 70.0) / 2.0, 196)
	badge.size = Vector2(70, 26)
	card.add_child(badge)
	return card


# --- Step 2: 프로필이 각자 자리로 날아간다 ------------------------------------------

func _step_fly() -> void:
	if _done:
		return
	_skip_hint.queue_free()
	var fade: Tween = create_tween()
	fade.tween_property(_dim, "color:a", 0.0, STEP_FLY * _k)
	for player_id: int in _cards:
		var card: Control = _cards[player_id]
		var panel: Control = _board._profiles[player_id]["panel"]
		var rect: Rect2 = panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
		var target_scale: float = minf(rect.size.x / CARD_SIZE.x, rect.size.y / CARD_SIZE.y)
		card.pivot_offset = CARD_SIZE / 2.0
		var fly: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		fly.tween_property(card, "position", rect.get_center() - CARD_SIZE / 2.0, STEP_FLY * _k)
		fly.tween_property(card, "scale", Vector2.ONE * target_scale, STEP_FLY * _k)
		fly.tween_property(card, "modulate:a", 0.0, 0.2 * _k).set_delay((STEP_FLY - 0.25) * _k)
	for versus: Node in _vs_root.get_children():
		if versus is Label and (versus as Label).text == "VS":
			versus.create_tween().tween_property(versus, "modulate:a", 0.0, 0.2 * _k)


# --- Step 3: [레이스 시작!] 타이틀 ---------------------------------------------------

func _step_title() -> void:
	if _done:
		return
	Sfx.play(&"game_start")
	# 창이 디자인 크기(1366x768)보다 넓어도 띠가 끊기지 않게 실제 화면 폭 전체를 덮는다.
	var screen: Vector2 = get_viewport_rect().size
	var ribbon := Panel.new()
	ribbon.position = Vector2(0, screen.y / 2.0 - 84.0)
	ribbon.size = Vector2(screen.x, 120)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_theme_stylebox_override("panel", _board._style(Color(0.1, 0.07, 0.02, 0.94), Color("ffd43b"), 5, 0, 30, 0))
	var title: Label = _board._make_label("레이스 시작!", 60, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("5c4300"))
	title.position = Vector2(0, 4)
	title.size = Vector2(screen.x, 80)
	ribbon.add_child(title)
	# 이모지는 글꼴에 없어 깃발 글자는 뺀다.
	var subtitle: Label = _board._make_label("GAME START! - 초증강 엘리아스 마블 개막!", 22, Color("fff3bf"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 84)
	subtitle.size = Vector2(screen.x, 30)
	ribbon.add_child(subtitle)
	ribbon.pivot_offset = ribbon.size / 2.0
	ribbon.scale = Vector2(1.0, 2.6)
	ribbon.modulate.a = 0.0
	add_child(ribbon)
	var slam: Tween = ribbon.create_tween().set_parallel(true)
	slam.tween_property(ribbon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(ribbon, "modulate:a", 1.0, 0.1)
	slam.chain().tween_callback(func() -> void:
		_board.screen_shake(8.0, 0.25)
		_board._impact_ring(screen / 2.0, Color("ffe066"), 90.0))
	slam.chain().tween_interval(STEP_TITLE - 0.5)
	slam.chain().tween_property(ribbon, "modulate:a", 0.0, 0.25)
	slam.chain().tween_callback(ribbon.queue_free)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
