# File: res://scenes/opening_sequence.gd
# Class: class_name OpeningSequence
# Role: 게임 시작 직후 1라운드 증강 선택 전에 재생하는 4단계 오프닝(VS 대진표 -> 보드판 공개와 기물 착지 -> 턴 순서 -> GAME START). 클릭하면 건너뛰며, 끝나면 finished를 보낸다. 연출만 담당한다
class_name OpeningSequence
extends Control

signal finished

const STEP_VS: float = 1.2
const STEP_BOARD: float = 1.1
const STEP_ORDER: float = 0.9
const STEP_START: float = 0.8
const CARD_SIZE: Vector2 = Vector2(190, 250)

var _board: MainBoard = null
var _tween: Tween = null
var _done: bool = false
var _dim: ColorRect = null
var _vs_root: Control = null
var _layer: Node2D = null
var _extras: Array[Node] = []
## 연출 속도 배율(설정의 연출 속도): 모든 시간이 이 배수로 늘어난다 (기본 보통 = 1.7배, 약 6.8초).
var _k: float = 1.0


func setup(board: MainBoard) -> void:
	_board = board
	z_index = 80
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## 기본 4.0초(x 연출 속도 배율, 보통 1.7배 = 약 6.8초): 클릭하면 즉시 건너뛴다.
func start() -> void:
	_k = maxf(_board._pace(), 1.0)
	_dim = ColorRect.new()
	_dim.color = Color(0.078, 0.094, 0.141, 0.95)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_layer = Node2D.new()
	add_child(_layer)
	_build_vs()
	_tween = create_tween()
	_tween.tween_interval(STEP_VS * _k)
	_tween.tween_callback(_step_board)
	_tween.tween_interval(STEP_BOARD * _k)
	_tween.tween_callback(_step_order)
	_tween.tween_interval(STEP_ORDER * _k)
	_tween.tween_callback(_step_start)
	_tween.tween_interval(STEP_START * _k)
	_tween.tween_callback(_finish)


func _process(_delta: float) -> void:
	# 테스트가 즉시 모드로 바꾸면 곧바로 끝낸다.
	if _board != null and _board.instant_roll_for_test:
		_finish()


func _on_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		_finish()


# --- Step 1: 4인 매치업(VS) 로딩 오버레이 ---------------------------------------

func _build_vs() -> void:
	var screen: Vector2 = Vector2(1366, 768)
	_vs_root = Control.new()
	_vs_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vs_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vs_root)
	var title: Label = _board._make_label("보드게임 상자를 엎는 중...", 34, Color("ffe066"))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("5c4300"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 70)
	title.size = Vector2(screen.x, 48)
	_vs_root.add_child(title)
	var ids: Array[int] = _board._player_ids
	var count: int = ids.size()
	var gap: float = 64.0
	var total_width: float = count * CARD_SIZE.x + (count - 1) * gap
	var left: float = (screen.x - total_width) / 2.0
	var top: float = 190.0
	for index: int in count:
		var player_id: int = ids[index]
		var card: Control = _make_vs_card(player_id)
		var home: Vector2 = Vector2(left + index * (CARD_SIZE.x + gap), top)
		# 좌석별로 사방에서 중앙으로 미끄러져 들어온다 (아래/오른쪽/위/왼쪽 순)
		var from_offset: Vector2 = [Vector2(0, 520), Vector2(620, 0), Vector2(0, -420), Vector2(-620, 0)][index % 4]
		card.position = home + from_offset
		card.modulate.a = 0.0
		_vs_root.add_child(card)
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
	# 하단: 준비 게이지(0% -> 100%) + 랜덤 팁 한 줄
	var bar_back := Panel.new()
	bar_back.position = Vector2((screen.x - 460.0) / 2.0, 560)
	bar_back.size = Vector2(460, 18)
	bar_back.add_theme_stylebox_override("panel", _board._style(Color("0b0e17"), Color("3b4660"), 2, 9, 0, 0))
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs_root.add_child(bar_back)
	var fill := Panel.new()
	fill.position = bar_back.position + Vector2(3, 3)
	fill.size = Vector2(0, 12)
	fill.add_theme_stylebox_override("panel", _board._style(Color("fcc419"), Color("ffe680"), 1, 6, 8, 0))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs_root.add_child(fill)
	var percent: Label = _board._make_label("0%", 14, Color("ffd43b"))
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.position = Vector2(0, 584)
	percent.size = Vector2(screen.x, 20)
	_vs_root.add_child(percent)
	var tip: Label = _board._make_label("팁: %s" % GameTips.random_tip(), 17, Color("ced4da"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.position = Vector2(0, 618)
	tip.size = Vector2(screen.x, 26)
	_vs_root.add_child(tip)
	var skip: Label = _board._make_label("클릭하면 건너뜁니다", 13, Color("868e96"))
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.position = Vector2(0, 700)
	skip.size = Vector2(screen.x, 20)
	_vs_root.add_child(skip)
	var load_tween: Tween = fill.create_tween()
	load_tween.tween_method(func(value: float) -> void:
		fill.size.x = 454.0 * value
		percent.text = "%d%%" % int(value * 100.0), 0.0, 1.0, STEP_VS * _k)


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


# --- Step 2: 보드판 공개 + 기물 착지 ---------------------------------------------

func _step_board() -> void:
	if _done:
		return
	var fade: Tween = create_tween().set_parallel(true)
	fade.tween_property(_vs_root, "modulate:a", 0.0, 0.3 * _k)
	fade.tween_property(_dim, "color:a", 0.0, 0.35 * _k)
	# 말들이 위에서 0번 출발선으로 통, 통 떨어져 착지한 뒤 각자의 대기석(프로필 칸)으로 들어간다
	var order: int = 0
	for player_id: int in _board._player_ids:
		for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
			_drop_pawn(player_id, slot, (0.05 + order * 0.035) * _k)
			order += 1


func _drop_pawn(player_id: int, slot: int, delay: float) -> void:
	var pawn: PlayerPawn = _board.state.get_pawn(player_id * 10 + slot)
	if pawn == null:
		return
	var target: Vector2 = _board._pawn_position_at(pawn, GameEnums.GOAL_TILE)
	var color: Color = MainBoard.PLAYER_COLORS[player_id]
	var depth: float = _board._depth_scale(MainBoard.tile_norm(GameEnums.GOAL_TILE).y)
	var ghost := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = _board._circle_points(MainBoard.PAWN_RADIUS * 1.35, 18)
	body.color = color
	ghost.add_child(body)
	var ring := Line2D.new()
	ring.width = 1.5
	ring.default_color = Color("f8f9fa")
	ring.closed = true
	for point: Vector2 in _board._circle_points(MainBoard.PAWN_RADIUS * 1.35, 18):
		ring.add_point(point)
	ghost.add_child(ring)
	var number: Label = _board._make_label(str(slot), 11, Color("111111"))
	number.position = Vector2(-4, -8)
	ghost.add_child(number)
	ghost.position = target + Vector2(0, -420)
	ghost.scale = Vector2.ONE * depth
	ghost.modulate.a = 0.0
	_layer.add_child(ghost)
	var tween: Tween = ghost.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(ghost, "modulate:a", 1.0, 0.05)
	tween.tween_property(ghost, "position", target, 0.4 * _k).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback(func() -> void:
		var squash: Tween = ghost.create_tween()
		squash.tween_interval(0.27 * _k)
		squash.tween_property(ghost, "scale", Vector2(1.3, 0.75) * depth, 0.05 * _k)
		squash.tween_property(ghost, "scale", Vector2.ONE * depth, 0.16 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	tween.tween_callback(func() -> void: _board._tile_glow(GameEnums.GOAL_TILE))
	tween.tween_interval(0.12 * _k)
	# 대기석(프로필의 기물 칸)으로 쏙 들어간다
	var slot_panel: Control = (_board._profiles[player_id]["slots"][slot - 1] as Dictionary)["panel"]
	var slot_center: Vector2 = slot_panel.global_position + slot_panel.size / 2.0
	tween.tween_property(ghost, "position", slot_center, 0.28 * _k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "scale", Vector2.ONE * 0.5, 0.28 * _k)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.28 * _k)
	tween.tween_callback(ghost.queue_free)


# --- Step 3: 턴 순서 결정 --------------------------------------------------------

func _step_order() -> void:
	if _done:
		return
	var order: Array[int] = _turn_order()
	var names: PackedStringArray = []
	for player_id: int in order:
		names.append("P%d" % player_id)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _board._style(Color("101626"), Color("ffe066"), 4, 18, 22, 14))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = _board._make_label("턴 순서 결정!   %s" % "  →  ".join(names), 28, Color("fff3bf"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color("3b2a00"))
	banner.add_child(label)
	add_child(banner)
	banner.reset_size()
	banner.position = Vector2(683.0 - banner.size.x / 2.0, 330.0)
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 0.0
	var pop: Tween = banner.create_tween().set_parallel(true)
	pop.tween_property(banner, "scale", Vector2.ONE, 0.25 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(banner, "modulate:a", 1.0, 0.15 * _k)
	pop.chain().tween_interval((STEP_ORDER - 0.55) * _k)
	pop.tween_property(banner, "modulate:a", 0.0, 0.2 * _k)
	pop.tween_callback(banner.queue_free)
	_extras.append(banner)
	# 모서리 프로필이 순서대로 한 번씩 반짝인다 (진행 방향 각인)
	for index: int in order.size():
		_halo(order[index], 0.2 * index * _k)


func _turn_order() -> Array[int]:
	var order: Array[int] = []
	var ids: Array[int] = _board.manager.player_order
	var first: int = ids.find(_board.manager.current_player_id())
	for step: int in ids.size():
		order.append(ids[(maxi(first, 0) + step) % ids.size()])
	return order


func _halo(player_id: int, delay: float) -> void:
	var panel: Control = _board._profiles[player_id]["panel"]
	var rect: Rect2 = panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
	var halo := Panel.new()
	halo.position = rect.position
	halo.size = rect.size
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.add_theme_stylebox_override("panel", _board._style(Color(1.0, 0.85, 0.25, 0.2), Color("ffe066"), 5, 16, 26, 0))
	halo.modulate.a = 0.0
	add_child(halo)
	var tween: Tween = halo.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(halo, "modulate:a", 1.0, 0.1 * _k)
	tween.tween_property(halo, "modulate:a", 0.0, 0.3 * _k)
	tween.tween_callback(halo.queue_free)
	_extras.append(halo)


# --- Step 4: GAME START! ---------------------------------------------------------

func _step_start() -> void:
	if _done:
		return
	Sfx.play(&"game_start")
	var ribbon := Panel.new()
	ribbon.position = Vector2(0, 300)
	ribbon.size = Vector2(1366, 120)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_theme_stylebox_override("panel", _board._style(Color(0.1, 0.07, 0.02, 0.94), Color("ffd43b"), 5, 0, 30, 0))
	var title: Label = _board._make_label("GAME START!", 56, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("5c4300"))
	title.position = Vector2(0, 6)
	title.size = Vector2(1366, 70)
	ribbon.add_child(title)
	var subtitle: Label = _board._make_label("에르핀의 억지 레이스 개막!", 22, Color("fff3bf"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 78)
	subtitle.size = Vector2(1366, 30)
	ribbon.add_child(subtitle)
	ribbon.pivot_offset = ribbon.size / 2.0
	ribbon.scale = Vector2(1.0, 2.6)
	ribbon.modulate.a = 0.0
	add_child(ribbon)
	_extras.append(ribbon)
	var slam: Tween = ribbon.create_tween().set_parallel(true)
	slam.tween_property(ribbon, "scale", Vector2.ONE, 0.18 * _k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(ribbon, "modulate:a", 1.0, 0.1 * _k)
	slam.chain().tween_callback(func() -> void:
		_board.screen_shake(10.0, 0.3)
		_board._impact_ring(Vector2(683, 360), Color("ffe066"), 90.0)
		_board._burst_shards(Vector2(683, 360), Color("ffd43b"), 20))
	slam.chain().tween_interval((STEP_START - 0.55) * _k + 0.15)
	slam.tween_property(ribbon, "modulate:a", 0.0, 0.25 * _k)
	slam.tween_callback(ribbon.queue_free)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
