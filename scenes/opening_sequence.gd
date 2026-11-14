# File: res://scenes/opening_sequence.gd
# Class: class_name OpeningSequence
# Role: 게임 시작 직후 재생하는 만화 컷 오프닝(참가자마다 사선 컷 + 승리 일러스트가 위·아래에서 탁탁탁 들어옴 -> 일직선 [GAME START!] 띠가 왼쪽에서 가로질러 쾅 -> 잠시 뒤 띠 안에 부제 [모든 말을 완주하라!] -> 띠는 오른쪽으로 빠지고 1·3번째 컷은 위로, 2·4번째 컷은 아래로 퇴장). 끝나면 보드가 첫 차례(누구 턴인지) 배너를 띄운다. 클릭하면 건너뛰며, 끝나면 finished를 보낸다. 연출만 담당한다
class_name OpeningSequence
extends Control

signal finished

## 컷이 들어오는 시간(좌석마다 조금씩 늦게), 컷이 자리 잡고 머무는 시간, 띠가 가로지르는 시간, 부제가 뜬 뒤 읽는 시간, 걷히는 시간 (초).
const STEP_PANELS: float = 0.55
const PANEL_STAGGER: float = 0.12
const STEP_HOLD: float = 0.45
const STEP_SLASH: float = 0.32
const STEP_SUBTITLE_DELAY: float = 0.5
const STEP_READ: float = 1.1
const STEP_OUT: float = 0.42
## 컷 사이 경계가 기우는 폭(픽셀)과 컷 띠의 높이.
const SLANT: float = 54.0
const BAND_MAX_HEIGHT: float = 560.0
## [GAME START!] 띠 높이 (제목 + 부제가 함께 들어간다).
const BAND_HEIGHT: float = 240.0
const SUBTITLE_TEXT: String = "모든 말을 완주하라!"

var _board: MainBoard = null
var _tween: Tween = null
var _done: bool = false
var _dim: ColorRect = null
var _root: Control = null
var _skip_hint: Label = null
var _panels: Array[CutPanel] = []
var _band: Control = null
var _band_home: Vector2 = Vector2.ZERO
## 연출 속도 배율(설정의 연출 속도, 1~1.4배): 컷 등장·유지 시간에만 곱한다. 띠와 부제는 읽히는 시간을 지키려 그대로 둔다.
var _k: float = 1.0


## 만화 컷 한 장: 사선 평행사변형 안에 자리색 바탕 + 하프톤 점 + 승리 일러스트(꽉 채워 자른 클로즈업)를 그린다.
class CutPanel extends Control:
	var tint: Color = Color.WHITE
	var art: Texture2D = null
	var slant: float = SLANT
	var first: bool = false
	var last: bool = false

	func polygon() -> PackedVector2Array:
		var w: float = size.x
		var h: float = size.y
		var left_top: float = 0.0 if first else slant
		var left_bottom: float = 0.0
		var right_top: float = w
		var right_bottom: float = w if last else w - slant
		return PackedVector2Array([Vector2(left_top, 0), Vector2(right_top, 0), Vector2(right_bottom, h), Vector2(left_bottom, h)])

	func _draw() -> void:
		var poly: PackedVector2Array = polygon()
		draw_colored_polygon(poly, tint.darkened(0.45))
		# 하프톤: 아래·바깥쪽일수록 큰 점 (만화 스크린톤)
		var dot: Color = tint.lightened(0.15)
		dot.a = 0.55
		var step: float = 17.0
		var y: float = step * 0.5
		var row: int = 0
		while y < size.y:
			var x: float = step * 0.5 + (step * 0.5 if row % 2 == 1 else 0.0)
			while x < size.x:
				var p := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(p, poly):
					var radius: float = lerpf(0.6, 5.2, pow(y / size.y, 1.4))
					draw_circle(p, radius, dot)
				x += step
			y += step * 0.866
			row += 1
		if art != null:
			var zoom: float = 1.12
			var scale_cover: float = maxf(size.x / art.get_width(), size.y / art.get_height()) * zoom
			var draw_w: float = art.get_width() * scale_cover
			var draw_h: float = art.get_height() * scale_cover
			var ox: float = (size.x - draw_w) * 0.5
			var oy: float = (size.y - draw_h) * 0.12  # 위쪽(얼굴)을 남기고 아래를 자른다
			var uvs := PackedVector2Array()
			var colors := PackedColorArray()
			for p: Vector2 in poly:
				uvs.append(Vector2((p.x - ox) / draw_w, (p.y - oy) / draw_h))
				colors.append(Color.WHITE)
			draw_polygon(poly, colors, uvs, art)
		# 컷 테두리 (검은 바깥선 + 흰 안선)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color("0d1018"), 9.0, true)
		draw_polyline(closed, Color.WHITE, 4.0, true)


func setup(board: MainBoard) -> void:
	_board = board
	z_index = 80
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## 컷 -> 띠 -> 부제 순서로 약 3.4초. 클릭하면 즉시 건너뛴다.
func start() -> void:
	_k = clampf(_board._pace(), 1.0, 1.4)
	_dim = ColorRect.new()
	_dim.color = Color(0.078, 0.094, 0.141, 0.97)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.size = get_viewport_rect().size
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_panels()
	var slash_at: float = (STEP_PANELS + PANEL_STAGGER * (_board._player_ids.size() - 1)) * _k + STEP_HOLD * _k
	_tween = create_tween()
	_tween.tween_interval(slash_at)
	_tween.tween_callback(_step_title)
	_tween.tween_interval(STEP_SLASH + STEP_SUBTITLE_DELAY + STEP_READ)
	_tween.tween_callback(_step_out)
	_tween.tween_interval(STEP_OUT + 0.16)
	_tween.tween_callback(_finish)


func _process(_delta: float) -> void:
	# 테스트가 즉시 모드로 바꾸면 곧바로 끝낸다.
	if _board != null and _board.instant_roll_for_test:
		_finish()


func _on_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		_finish()


# --- Step 1: 참가자 컷 -------------------------------------------------------------

func _build_panels() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var ids: Array[int] = _board._player_ids
	var count: int = ids.size()
	var band_h: float = minf(BAND_MAX_HEIGHT, screen.y * 0.74)
	var top: float = (screen.y - band_h) / 2.0 - 10.0
	var step: float = screen.x / float(count)
	for index: int in count:
		var player_id: int = ids[index]
		var panel := CutPanel.new()
		panel.first = index == 0
		panel.last = index == count - 1
		panel.tint = MainBoard.PLAYER_COLORS[player_id]
		panel.art = AvatarCombatArt.texture(_board._avatar_for(player_id), &"victory")
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 경계선은 위가 오른쪽, 아래가 왼쪽으로 기운다 (경계 중심 = index * step)
		var left: float = 0.0 if index == 0 else index * step - SLANT / 2.0
		var right: float = screen.x if index == count - 1 else (index + 1) * step + SLANT / 2.0
		panel.size = Vector2(right - left, band_h)
		var home: Vector2 = Vector2(left, top)
		# 위·아래에서 번갈아 탁탁탁 들어온다
		var from_y: float = -(top + band_h + 40.0) if index % 2 == 0 else (screen.y - top + 40.0)
		panel.position = home + Vector2(0, from_y)
		_root.add_child(panel)
		_panels.append(panel)
		_add_name_tag(panel, player_id, index == 0, index == count - 1)
		var delay: float = PANEL_STAGGER * index * _k
		var slide: Tween = panel.create_tween()
		slide.tween_interval(delay)
		slide.tween_property(panel, "position", home, STEP_PANELS * _k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_skip_hint = _board._make_label("클릭하면 건너뜁니다", 13, Color("868e96"))
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.position = Vector2(0, screen.y - 34.0)
	_skip_hint.size = Vector2(screen.x, 20)
	_root.add_child(_skip_hint)


## 컷 아래쪽 이름표: [P1] 이름 + 나/AI/참가자 배지.
func _add_name_tag(panel: CutPanel, player_id: int, is_first: bool, is_last: bool) -> void:
	var color: Color = MainBoard.PLAYER_COLORS[player_id]
	var inset_left: float = 14.0 if is_first else SLANT + 4.0
	var inset_right: float = 14.0 if is_last else SLANT + 4.0
	var tag_w: float = panel.size.x - inset_left - inset_right
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", _board._style(Color(0.05, 0.06, 0.1, 0.88), color, 3, 10, 8, 4))
	tag.size = Vector2(tag_w, 54)
	tag.position = Vector2(inset_left, panel.size.y - 54.0 - 16.0)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	tag.add_child(row)
	var seat: Label = _board._make_label("P%d" % player_id, 20, color.lightened(0.3))
	row.add_child(seat)
	var name_label: Label = _board._make_label(_board._player_name(player_id), 20, Color("f1f3f5"))
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var role: String = "나" if player_id == _board.local_player_id else ("AI" if _board._bot.is_bot(player_id) else "참가자")
	var badge: Label = _board._make_label(role, 14, Color("2b2100") if role != "AI" else Color("f1f3f5"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _board._style(Color("ffd43b") if role == "나" else (Color("495057") if role == "AI" else Color("4dabf7")), Color(0, 0, 0, 0), 0, 12, 6, 2))
	row.add_child(badge)
	panel.add_child(tag)


# --- Step 2: [GAME START!] 띠가 왼쪽에서 가로질러 들어오고, 잠시 뒤 띠 안에 부제 ---------------------

func _step_title() -> void:
	if _done:
		return
	_skip_hint.queue_free()
	Sfx.play(&"game_start")
	var screen: Vector2 = get_viewport_rect().size
	var band_w: float = screen.x + 80.0
	var band := Control.new()
	band.name = "GameStartBand"
	band.size = Vector2(band_w, BAND_HEIGHT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band_home = Vector2(-40.0, (screen.y - BAND_HEIGHT) / 2.0 - 6.0)
	band.position = _band_home + Vector2(-band_w, 0)
	var body := ColorRect.new()
	body.color = Color("101626")
	body.size = band.size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(body)
	for edge_y: float in [0.0, BAND_HEIGHT - 8.0]:
		var edge := ColorRect.new()
		edge.color = Color("ffe066")
		edge.size = Vector2(band_w, 8)
		edge.position = Vector2(0, edge_y)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(edge)
	var title: Label = _board._make_label("GAME START!", 96, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color("3a0f0f"))
	title.size = Vector2(band_w, 140)
	title.position = Vector2(0, 22)
	title.pivot_offset = title.size / 2.0
	band.add_child(title)
	# 부제는 띠 안 아래쪽에 잠시 뒤 따로 뜬다 (플레이어가 목표를 읽도록)
	var subtitle: Label = _board._make_label(SUBTITLE_TEXT, 38, Color("fff3bf"))
	subtitle.name = "GameStartSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(band_w, 60)
	subtitle.position = Vector2(0, 162)
	subtitle.pivot_offset = subtitle.size / 2.0
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.modulate.a = 0.0
	subtitle.scale = Vector2.ONE * 0.9
	band.add_child(subtitle)
	_root.add_child(band)
	_band = band
	var slash: Tween = band.create_tween()
	slash.tween_property(band, "position", _band_home, STEP_SLASH).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	slash.tween_callback(func() -> void:
		_board.screen_shake(9.0, 0.25)
		_board._impact_ring(screen / 2.0, Color("ffe066"), 110.0))
	# 글자는 띠가 멈추는 순간 한 번 쿵 커졌다 자리 잡는다
	title.scale = Vector2.ONE * 1.25
	var stamp: Tween = title.create_tween()
	stamp.tween_interval(STEP_SLASH)
	stamp.tween_property(title, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var reveal: Tween = subtitle.create_tween().set_parallel(true)
	reveal.tween_property(subtitle, "modulate:a", 1.0, 0.22).set_delay(STEP_SLASH + STEP_SUBTITLE_DELAY)
	reveal.tween_property(subtitle, "scale", Vector2.ONE, 0.25).set_delay(STEP_SLASH + STEP_SUBTITLE_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Step 3: 퇴장 — 띠는 들어온 방향 그대로 오른쪽으로 빠지고, 1·3번째 컷은 위로, 2·4번째 컷은 아래로 -------------

func _step_out() -> void:
	if _done:
		return
	var screen: Vector2 = get_viewport_rect().size
	var out: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	if _band != null:
		out.tween_property(_band, "position", _band_home + Vector2(_band.size.x + 40.0, 0), STEP_OUT)
	for index: int in _panels.size():
		var panel: CutPanel = _panels[index]
		var dy: float = -(panel.position.y + panel.size.y + 40.0) if index % 2 == 0 else (screen.y - panel.position.y + 40.0)
		out.tween_property(panel, "position:y", panel.position.y + dy, STEP_OUT).set_delay(0.04 * index)
	out.tween_property(_dim, "color:a", 0.0, STEP_OUT + 0.12).set_trans(Tween.TRANS_LINEAR)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
