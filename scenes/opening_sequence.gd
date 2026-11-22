# File: res://scenes/opening_sequence.gd
# Class: class_name OpeningSequence
# Role: 게임 시작 직후 재생하는 만화 컷 오프닝(참가자마다 사선 컷 + 승리 일러스트가 위·아래에서 탁탁탁 들어옴 -> 일직선 [GAME START!] 띠가 왼쪽에서 가로질러 쾅 -> 잠시 뒤 띠 안에 부제 [모든 말을 완주하라!] -> 띠는 오른쪽으로 빠지고 1·3번째 컷은 위로, 2·4번째 컷은 아래로 퇴장). 끝나면 보드가 첫 차례(누구 턴인지) 배너를 띄운다. 클릭하면 건너뛰며, 끝나면 finished를 보낸다. 연출만 담당한다
class_name OpeningSequence
extends Control

signal finished

## 컷이 들어오는 시간(좌석마다 조금씩 늦게), 컷이 자리 잡고 머무는 시간, 띠가 가로지르는 시간, 부제가 뜬 뒤 읽는 시간, 걷히는 시간 (초).
const STEP_BLACKOUT: float = 0.30
const STEP_PANELS: float = 0.34
const PANEL_STAGGER: float = 0.17
const STEP_HOLD: float = 0.52
const STEP_SLASH: float = 0.32
const STEP_SUBTITLE_DELAY: float = 0.5
const SUBTITLE_REVEAL: float = 0.25
const SUBTITLE_HOLD: float = 1.0
const STEP_OUT: float = 0.42
## 컷 사이 경계가 기우는 폭(픽셀).
const SLANT: float = 54.0
## [GAME START!] 띠 높이 (제목 + 부제가 함께 들어간다).
const BAND_HEIGHT: float = 172.0
const COMIC_FONT = preload("res://assets/fonts/result/bangers.ttf")
const NAME_FONT = preload("res://assets/fonts/victory/songmyung.ttf")
const PORTRAIT_INK = preload("res://scenes/opening_portrait_ink.gdshader")
const INK := Color("15131f")
const PAPER := Color("fff3d8")
const SUBTITLE_TEXT: String = "모든 말을 완주하라!"

var _board: MainBoard = null
var _tween: Tween = null
var _done: bool = false
var _page: ComicPage = null
var _root: Control = null
var _skip_button: Button = null
var _voice_token := 0
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
		draw_colored_polygon(poly, tint.darkened(0.30))
		# 하프톤: 아래·바깥쪽일수록 큰 점 (만화 스크린톤)
		var dot: Color = tint.darkened(0.60)
		dot.a = 0.65
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
		# Short broken ink strokes keep some printed texture behind the portraits.
		for index: int in range(4, roundi(size.x), 5):
			var jitter: float = sin(index * 12.91)
			var x: float = float(index) + jitter * 1.8
			var top: float = maxf(0.0, size.y * (1.0 - x / slant)) if not first else 0.0
			var bottom: float = minf(size.y, size.y * (size.x - x) / slant) if not last else size.y
			var y_start: float = lerpf(top, bottom, 0.18 + jitter * 0.12)
			draw_line(Vector2(x, y_start), Vector2(x, lerpf(y_start, bottom, 0.49 + jitter * 0.23)), Color(INK, 0.24), 1.0)

	func _ready() -> void:
		var poly := polygon()
		if art != null:
			var portrait := Node2D.new()
			var ink_material := ShaderMaterial.new()
			ink_material.shader = PORTRAIT_INK
			portrait.material = ink_material
			var scale_cover: float = maxf(size.x / art.get_width(), size.y / art.get_height()) * 1.12
			var extent := art.get_size() * scale_cover
			var origin := (size - extent) * Vector2(0.5, 0.12)
			var uvs := PackedVector2Array()
			var colors := PackedColorArray()
			for point: Vector2 in poly:
				uvs.append((point - origin) / extent)
				colors.append(Color.WHITE)
			portrait.draw.connect(func() -> void: portrait.draw_polygon(poly, colors, uvs, art))
			add_child(portrait)
		var frame := Node2D.new()
		var closed := poly.duplicate()
		closed.append(poly[0])
		frame.draw.connect(func() -> void:
			frame.draw_polyline(closed, INK, 14.0, true)
			frame.draw_polyline(closed, PAPER, 4.0, true))
		add_child(frame)


## The page and the title band are cached canvas draws; only their transforms animate.
class ComicPage extends Control:
	var show_speed_lines: bool = false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		if not show_speed_lines:
			return
		var ink_wash := Color(PAPER, 0.10)
		for index: int in 17:
			var x: float = size.x * float(index) / 16.0
			var top := Vector2(x, 0)
			var bottom := Vector2(size.x - x, size.y)
			var direction := (Vector2(size.x * 0.52, size.y * 0.48) - top).normalized()
			var reverse := (Vector2(size.x * 0.48, size.y * 0.52) - bottom).normalized()
			var length: float = size.y * (0.10 + 0.026 * (index % 4))
			draw_colored_polygon(PackedVector2Array([top - Vector2(5, 0), top + Vector2(5, 0), top + direction * length]), ink_wash)
			draw_colored_polygon(PackedVector2Array([bottom - Vector2(6, 0), bottom + Vector2(6, 0), bottom + reverse * length]), ink_wash)


class StartBand extends Control:
	func _draw() -> void:
		draw_rect(Rect2(8, 10, size.x, size.y), INK)
		draw_rect(Rect2(Vector2.ZERO, size), Color("f9cb51"))
		draw_rect(Rect2(0, 6, size.x, size.y - 12), Color("f5d77e"))
		for x: int in range(12, roundi(size.x), 13):
			var edge: float = absf(float(x) / size.x * 2.0 - 1.0)
			for y: int in range(11, roundi(size.y), 12):
				var radius: float = smoothstep(0.36, 1.0, edge) * (2.2 + 1.4 * absf(float(y) / size.y - 0.5))
				if radius > 0.0:
					draw_circle(Vector2(x + (6 if y % 24 < 12 else 0), y), radius, Color(0.42, 0.17, 0.07, 0.30))
		draw_line(Vector2(0, 3), Vector2(size.x, 3), INK, 6, true)
		draw_line(Vector2(0, size.y - 3), Vector2(size.x, size.y - 3), INK, 6, true)


func setup(board: MainBoard) -> void:
	_board = board
	z_index = 80
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP


## 컷 → 띠 → 부제 순서로 재생하고, 클릭하거나 탭하면 즉시 건너뛴다.
func start() -> void:
	_k = clampf(_board._pace(), 1.0, 1.4)
	_page = ComicPage.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.resized.connect(_page.queue_redraw)
	add_child(_page)
	_page.size = size
	_page.modulate.a = 0.0
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var slash_at: float = (STEP_PANELS + PANEL_STAGGER * (_board._player_ids.size() - 1)) * _k + STEP_HOLD * _k
	_tween = create_tween()
	_tween.tween_property(_page, "modulate:a", 1.0, STEP_BLACKOUT)
	_tween.tween_callback(_build_panels)
	_tween.tween_interval(slash_at)
	_tween.tween_callback(_step_title)
	_tween.tween_interval(STEP_SLASH + STEP_SUBTITLE_DELAY + SUBTITLE_REVEAL + SUBTITLE_HOLD)
	_tween.tween_callback(_wait_for_voice)
	_tween.tween_callback(_step_out)
	_tween.tween_interval(STEP_OUT + 0.16)
	_tween.tween_callback(_finish)


func _process(_delta: float) -> void:
	# 테스트가 즉시 모드로 바꾸면 곧바로 끝낸다.
	if _board != null and _board.instant_roll_for_test:
		_finish()


func _input(event: InputEvent) -> void:
	if _done or _board == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_skip_button) and _skip_button.get_global_rect().has_point(event.position):
			return
		get_viewport().set_input_as_handled()
		_finish()
	elif event is InputEventScreenTouch and event.pressed:
		if is_instance_valid(_skip_button) and _skip_button.get_global_rect().has_point(event.position):
			return
		get_viewport().set_input_as_handled()
		_finish()


# --- Step 1: 참가자 컷 -------------------------------------------------------------

func _build_panels() -> void:
	_page.show_speed_lines = true
	_page.queue_redraw()
	var screen: Vector2 = get_viewport_rect().size
	var ids: Array[int] = _board._player_ids
	var count: int = ids.size()
	var step: float = screen.x / float(count)
	var computer_number: int = 0
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
		panel.size = Vector2(right - left, screen.y)
		var home: Vector2 = Vector2(left, 0.0)
		# 위·아래에서 번갈아 탁탁탁 들어온다
		var from_y: float = -(screen.y + 40.0) if index % 2 == 0 else screen.y + 40.0
		panel.position = home + Vector2(0, from_y)
		_root.add_child(panel)
		_panels.append(panel)
		var display_name: String
		if _board._is_human_seat(player_id):
			display_name = _board._player_name(player_id)
		else:
			computer_number += 1
			display_name = L10n.tf("컴퓨터 %d", [computer_number])
		_add_name_tag(panel, display_name)
		var delay: float = PANEL_STAGGER * index * _k
		var slide: Tween = panel.create_tween()
		slide.tween_interval(delay)
		var overshoot := Vector2(0, 9.0 if index % 2 == 0 else -9.0)
		slide.tween_property(panel, "position", home + overshoot, STEP_PANELS * _k - 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide.tween_callback(func() -> void: Sfx.play(&"card_impact", -16.0, 0.0))
		slide.tween_property(panel, "position", home, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skip_button = _board._make_button(L10n.t("건너뛰기"), _finish, 17, INK)
	_skip_button.position = Vector2(screen.x - 144.0, screen.y - 55.0)
	_skip_button.size = Vector2(126, 38)
	_skip_button.z_index = 1
	_root.add_child(_skip_button)


## 기울어진 컷의 해당 높이에서 좌우 경계를 구해 인물 소개 자막을 가운데에 배치한다.
func _add_name_tag(panel: CutPanel, display_name: String) -> void:
	var tag_height: float = 58.0
	var tag_top: float = panel.size.y - 135.0
	var depth: float = (tag_top + tag_height * 0.5) / panel.size.y
	var corners: PackedVector2Array = panel.polygon()
	var left: float = lerpf(corners[0].x, corners[3].x, depth)
	var right: float = lerpf(corners[1].x, corners[2].x, depth)
	var max_width: float = right - left - 32.0

	var name_label: Label = _board._make_label(display_name, 29, INK)
	var font := FontVariation.new()
	font.base_font = NAME_FONT
	font.fallbacks = [name_label.get_theme_font("font")]
	name_label.add_theme_font_override("font", font)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 한글처럼 전각인 닉네임이 최대 글자 수만큼 들어가는 폭을 확보한다.
	var font_px: int = name_label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var baseline_width: float = GameSession.MAX_NICKNAME_LENGTH * font_px
	var tag_width: float = minf(max_width, maxf(baseline_width, text_width) + 48.0)
	var side_padding: float = 20.0
	var label_width: float = tag_width - side_padding * 2.0
	if text_width > label_width:
		for fitted_px: int in FontSizes.steps(font_px, 18):
			name_label.add_theme_font_size_override("font_size", fitted_px)
			if font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_px).x <= label_width:
				break
	var tag := Control.new()
	tag.name = "OpeningNameCaption"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size = Vector2(tag_width, tag_height)
	tag.position = Vector2((left + right - tag_width) * 0.5, tag_top)
	tag.draw.connect(func() -> void:
		tag.draw_rect(Rect2(Vector2(3, 4), tag.size), INK)
		tag.draw_rect(Rect2(Vector2.ZERO, tag.size), Color("fffdf5"))
		tag.draw_rect(Rect2(Vector2.ZERO, tag.size), INK, false, 2.0)
		tag.draw_rect(Rect2(Vector2(5, 5), tag.size - Vector2(10, 10)), panel.tint, false, 3.0))
	panel.add_child(tag)
	name_label.position = Vector2(side_padding, 0)
	name_label.size = Vector2(label_width, tag_height)
	tag.add_child(name_label)


# --- Step 2: [GAME START!] 띠가 왼쪽에서 가로질러 들어오고, 잠시 뒤 띠 안에 부제 ---------------------

func _step_title() -> void:
	if _done:
		return
	var screen: Vector2 = get_viewport_rect().size
	var band_w: float = screen.x + 80.0
	var band := StartBand.new()
	band.name = "GameStartBand"
	band.size = Vector2(band_w, BAND_HEIGHT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band_home = Vector2(-40.0, screen.y * 0.69 - BAND_HEIGHT * 0.5)
	band.position = _band_home + Vector2(-band_w, 0)
	var title: Label = _board._make_label("GAME START!", clampi(roundi(screen.x * 0.122), 70, 148), PAPER)
	title.add_theme_font_override("font", COMIC_FONT)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", Color("a44229"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", INK)
	title.size = Vector2(band_w, 116)
	title.position = Vector2(0, 1)
	title.pivot_offset = title.size / 2.0
	band.add_child(title)
	# 부제는 띠 안 아래쪽에 잠시 뒤 따로 뜬다 (플레이어가 목표를 읽도록)
	var subtitle: Label = _board._make_label(L10n.t(SUBTITLE_TEXT), 32, INK)
	subtitle.name = "GameStartSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(band_w, 49)
	subtitle.position = Vector2(0, 113)
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
		Sfx.play(&"game_start")
		_voice_token = Sfx.play_voice(AvatarCatalog.voice_path(_board._avatar_for(_board.local_player_id), &"opening"))
		var flash := ColorRect.new()
		flash.color = Color(PAPER, 0.30)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(flash)
		flash.size = size
		var impact := flash.create_tween()
		impact.tween_property(flash, "color:a", 0.0, 0.13)
		impact.tween_callback(flash.queue_free)
		var settle := band.create_tween()
		band.position.x += 12.0
		settle.tween_property(band, "position:x", _band_home.x, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	# 글자는 띠가 멈추는 순간 한 번 쿵 커졌다 자리 잡는다
	title.scale = Vector2.ONE * 1.25
	var stamp: Tween = title.create_tween()
	stamp.tween_interval(STEP_SLASH)
	stamp.tween_property(title, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var reveal: Tween = subtitle.create_tween().set_parallel(true)
	reveal.tween_property(subtitle, "modulate:a", 1.0, SUBTITLE_REVEAL).set_delay(STEP_SLASH + STEP_SUBTITLE_DELAY)
	reveal.tween_property(subtitle, "scale", Vector2.ONE, SUBTITLE_REVEAL).set_delay(STEP_SLASH + STEP_SUBTITLE_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Step 3: 퇴장 — 띠는 들어온 방향 그대로 오른쪽으로 빠지고, 1·3번째 컷은 위로, 2·4번째 컷은 아래로 -------------

func _wait_for_voice() -> void:
	if not Sfx.voice_is_active(_voice_token):
		return
	_tween.pause()
	while not _done and Sfx.voice_is_active(_voice_token):
		await get_tree().process_frame
	if not _done and _tween.is_valid():
		Sfx.stop_voice(_voice_token)
		_tween.play()


func _exit_tree() -> void:
	Sfx.stop_voice(_voice_token)


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
	out.tween_property(_page, "modulate:a", 0.0, 0.18).set_delay(STEP_OUT - 0.06).set_trans(Tween.TRANS_LINEAR)


func _finish() -> void:
	if _done:
		return
	_done = true
	Sfx.stop_voice(_voice_token)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()
	queue_free()
