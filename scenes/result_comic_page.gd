## 결과 1쪽 (1.01): 1~4위를 만화 컷으로 보여 준다. 왼쪽 큰 칸 = 1위(사도 전신·1st 도장·이름), 오른쪽 사선 칸 = Result · 2nd · 3rd · 4th,
## 아래 사선 띠 = 승리 이름 (승리 조건), 오른쪽 아래 [Next Page ▶] → 상세 결과표.
## 등장 (빠르고 경쾌하게, 기본 1초 남짓):
##   검은 사선 분할선이 화면을 가로지르며 먼저 그어진다 → 왼쪽 1위 칸이 자리를 잡는다 →
##   Result · 2nd · 3rd · 4th 패널이 STAGGER(0.08초) 간격으로 오른쪽에서 사선을 따라 탄성 있게(overshoot) 탁! 탁! 탁! 들어온다 →
##   마지막에 1st 도장과 승리 이름이 찍히며 impact (보드가 0.15초 화면 흔들림을 준다).
## 시계 하나(set_time)로 모든 요소가 움직여 배속·건너뛰기·테스트에서도 어긋나지 않는다. 누르면 등장을 건너뛴다.
class_name ResultComicPage
extends Control

signal impact
signal panel_landed(index: int)
signal intro_done
signal next_pressed

## 기본 길이(초, 배율 전).
const LINES_END: float = 0.18
const LEFT_START: float = 0.12
const LEFT_END: float = 0.30
const PANEL_START: float = 0.20
const STAGGER: float = 0.08
const PANEL_LEN: float = 0.26
const STAMP_START: float = 0.66
const STAMP_AT: float = 0.78
const NEXT_START: float = 0.84
const DURATION: float = 1.0
## 분할선 굵기(px)와 잉크 색.
const INK := Color("111111")
const LINE_PX: float = 14.0
## 사선 기울기 (정규화 좌표 dy/dx): 오른쪽 칸 경계 / 아래 띠.
const ROW_SLOPE: float = 0.33
const BAND_SLOPE: float = 0.24
## 오른쪽 칸 경계가 가운데 분할선과 만나는 높이 (정규화): Result|2nd, 2nd|3rd, 3rd|4th.
const ROW_EDGES: Array[float] = [0.10, 0.37, 0.61]
const RANK_TAGS: Array[String] = ["1st", "2nd", "3rd", "4th"]

var active: bool = false
var _time: float = 0.0
var _time_view: float = 0.0
var _pace: float = 1.0
var _impact_fired: bool = false
var _landed: int = 0
var _accent: Color = Color("ffd43b")
var _left: ComicPanel = null
var _lines: ComicLines = null
## 오른쪽 패널: [Result, 2nd, 3rd, 4th] (없는 순위는 빈 칸).
var panels: Array[ComicPanel] = []
var stamp: Label = null
var winner_label: Label = null
var victory_label: Label = null
var condition_label: Label = null
## 법전별 팝아트 타이틀 (좌상단, 예: "HURRICANE\nFORCE!!"). 없으면 null.
var popart_label: Label = null
var next_button: Button = null
var _art: TextureRect = null


func _init() -> void:
	name = "ResultComicPage"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(active)
	_relayout.call_deferred()  # 트리에 붙은 뒤 글자 크기로 다시 잰다
	resized.connect(_relayout)


func _relayout() -> void:
	_layout()
	set_time(_time_view)


## entries: 순위 순서의 [{rank, name, color, avatar: Control(정사각 초상), art: Texture2D(1위 전신, 없어도 됨)}].
## victory: 승리 이름, condition: (승리 조건).
## popart_title: 좌상단에 크게 찍는 팝아트 타이틀 (줄바꿈 \n으로 두 줄). 비워 두면 없다. condition이 따옴표로 시작하면 괄호로 다시 감싸지 않는다.
func setup(entries: Array[Dictionary], victory: String, condition: String, popart_title: String = "") -> void:
	var first: Dictionary = entries[0] if not entries.is_empty() else {}
	_accent = first.get("color", Color("ffd43b"))
	_left = ComicPanel.new()
	_left.name = "FirstPanel"
	_left.fill = _accent.lightened(0.72)
	_left.streak = _accent.lightened(0.45)
	_left.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # 사도 그림을 1위 칸 모양으로 자른다
	add_child(_left)
	var art: Texture2D = first.get("art", null)
	if art != null:
		_art = TextureRect.new()
		_art.name = "FirstArt"
		_art.texture = art
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_left.add_child(_art)
	elif first.get("avatar", null) is Control:
		_left.add_child(first["avatar"])
	_lines = ComicLines.new()
	_lines.name = "ComicLines"
	add_child(_lines)
	for index: int in 4:
		var panel := ComicPanel.new()
		panel.name = "ResultHeader" if index == 0 else "RankPanel%d" % (index + 1)
		add_child(panel)
		panels.append(panel)
		if index == 0:
			panel.add_child(_make_text("ResultTitle", "Result", 46, 10))
			continue
		if index >= entries.size():
			continue
		var entry: Dictionary = entries[index]
		var avatar: Control = entry.get("avatar", null)
		if avatar != null:
			avatar.name = "Avatar"
			panel.add_child(avatar)
		var name_label: Label = _make_text("Name", str(entry.get("name", "")), 34, 10)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(name_label)
		panel.add_child(_make_text("Tag", RANK_TAGS[mini(int(entry.get("rank", index + 1)), 4) - 1], 30, 9))
	var quoted: bool = condition.begins_with("\"") or condition.begins_with("(")
	condition_label = _make_text("VictoryCondition", (condition if quoted else "(%s)" % condition) if condition != "" else "", 20, 6)
	victory_label = _make_text("VictoryName", victory, 50, 12)
	winner_label = _make_text("WinnerName", str(first.get("name", "")), 64, 14, Color.WHITE, _accent.darkened(0.6))
	stamp = _make_text("FirstStamp", "1st", 88, 16)
	for label: Label in [condition_label, victory_label, winner_label, stamp]:
		add_child(label)
	if popart_title != "":
		# 팝아트 타이틀: 굵은 노랑 글자 + 두꺼운 잉크 테두리, 살짝 기울여 1st 도장 아래에 쾅 찍힌다
		popart_label = _make_text("PopArtTitle", popart_title, 54, 14, Color("ffe14d"), INK)
		popart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		popart_label.add_theme_constant_override("line_spacing", -8)
		popart_label.add_theme_color_override("font_shadow_color", Color("e03131"))
		popart_label.add_theme_constant_override("shadow_offset_x", 5)
		popart_label.add_theme_constant_override("shadow_offset_y", 5)
		add_child(popart_label)
	next_button = Button.new()
	next_button.name = "NextPageButton"
	next_button.text = "Next Page  "
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.add_theme_font_size_override("font_size", FontSizes.snap(24))
	for state_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		next_button.add_theme_color_override(state_name, Color.WHITE)
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = INK if style_name != "hover" else Color("343a40")
		box.skew = Vector2(0.18, 0.0)
		box.content_margin_left = 26
		box.content_margin_right = 46
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		next_button.add_theme_stylebox_override(style_name, box)
	var arrow := NextArrow.new()
	arrow.name = "Arrow"
	next_button.add_child(arrow)
	next_button.pressed.connect(func() -> void:
		if not active and _time_view >= DURATION:
			next_pressed.emit())
	add_child(next_button)
	_layout()
	set_time(0.0)


## 등장을 시작한다. pace: 연출 시간 배율 (1.0 = DURATION초).
func play(pace: float = 1.0) -> void:
	_pace = maxf(pace, 0.1)
	_time = 0.0
	_impact_fired = false
	_landed = 0
	active = true
	visible = true
	set_process(true)


## 등장을 건너뛴다 (도장 impact는 한 번 준다).
func skip() -> void:
	if not active:
		return
	_advance_to(DURATION)
	_finish()


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		skip()


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time / _pace
	_advance_to(minf(t, DURATION))
	if t >= DURATION:
		_finish()


## 시계를 t로 옮기며 그 사이의 착지·impact 신호를 순서대로 낸다.
func _advance_to(t: float) -> void:
	while _landed < panels.size() and t >= landing_time(_landed):
		_landed += 1
		panel_landed.emit(_landed - 1)
	if not _impact_fired and t >= STAMP_AT:
		_impact_fired = true
		impact.emit()
	set_time(t)


func _finish() -> void:
	active = false
	set_process(false)
	intro_done.emit()


## i번째 오른쪽 패널(0 = Result)이 들어오기 시작하는 시각 / 처음 제자리에 닿는 시각(overshoot 직전).
static func panel_start(index: int) -> float:
	return PANEL_START + STAGGER * float(index)


static func landing_time(index: int) -> float:
	return panel_start(index) + PANEL_LEN * 0.55


func _make_text(node_name: String, text: String, font_size: int, outline: int, color: Color = Color.WHITE, outline_color: Color = INK) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING  # 크기는 글자에 맞춘다 (이름 칸만 _layout에서 폭을 정하고 줄임표)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FontSizes.snap(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline)
	return label


func _view() -> Vector2:
	var view: Vector2 = size
	if view.x < 2.0 or view.y < 2.0:
		view = get_viewport_rect().size if is_inside_tree() else Vector2(1366, 768)  # 붙기 전(setup)에는 기준 화면
	return view


# ---- 기하: 정규화 좌표(0~1)로 정하고 화면 크기를 곱한다 ----

## 가운데 분할선의 x (정규화 높이 y에서): 위 0.68 → 아래로 갈수록 왼쪽.
static func divider_x(y: float) -> float:
	return 0.68 - 0.1667 * y


## 아래 띠 선의 y (정규화 x에서).
static func band_y(x: float) -> float:
	return 0.725 + BAND_SLOPE * x


## 가운데 분할선과 아래 띠 선이 만나는 점.
static func divider_foot() -> Vector2:
	var y: float = (0.725 + BAND_SLOPE * 0.68) / (1.0 + BAND_SLOPE * 0.1667)
	return Vector2(divider_x(y), y)


## i번째 오른쪽 칸 경계선 (가운데 분할선 → 오른쪽 끝)의 두 점 (정규화).
static func row_edge(index: int) -> PackedVector2Array:
	var y0: float = ROW_EDGES[index]
	var x0: float = divider_x(y0)
	return PackedVector2Array([Vector2(x0, y0), Vector2(1.0, y0 + ROW_SLOPE * (1.0 - x0))])


## 오른쪽 i번째 칸(0 = Result)의 다각형 (정규화, 시계 방향).
static func panel_polygon(index: int) -> PackedVector2Array:
	var top: PackedVector2Array = PackedVector2Array([Vector2(divider_x(0.0), 0.0), Vector2(1.0, 0.0)]) if index == 0 else row_edge(index - 1)
	var bottom: PackedVector2Array = row_edge(index) if index < ROW_EDGES.size() else PackedVector2Array([divider_foot(), Vector2(1.0, band_y(1.0))])
	return PackedVector2Array([top[0], top[1], bottom[1], bottom[0]])


static func first_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(divider_x(0.0), 0.0), divider_foot(), Vector2(0.0, band_y(0.0))])


func _scaled(points: PackedVector2Array, view: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in points:
		out.append(point * view)
	return out


func _layout() -> void:
	if _left == null:
		return
	var view: Vector2 = _view()
	for label: Label in [stamp, victory_label, condition_label, popart_label]:
		if label != null:
			label.size = label.get_combined_minimum_size()
	_left.size = view
	_left.polygon = _scaled(first_polygon(), view)
	_left.pivot_offset = Vector2(view.x * 0.3, view.y * 0.4)
	if _art != null:
		var side: float = view.y * 0.86
		_art.size = Vector2(side, side)
		_art.position = Vector2(view.x * 0.30 - side * 0.5, view.y * 0.04)
	elif _left.get_child_count() > 0:
		var portrait: Control = _left.get_child(0) as Control
		portrait.position = Vector2(view.x * 0.24, view.y * 0.2)
	_lines.size = view
	var foot: Vector2 = divider_foot()
	_lines.segments = [_scaled(PackedVector2Array([Vector2(divider_x(-0.05), -0.05), foot]), view),
		_scaled(PackedVector2Array([Vector2(-0.02, band_y(-0.02)), Vector2(1.02, band_y(1.02))]), view)]
	for index: int in panels.size():
		var panel: ComicPanel = panels[index]
		panel.size = view
		var poly: PackedVector2Array = _scaled(panel_polygon(index), view)
		panel.polygon = poly
		var top_left: Vector2 = poly[0]
		var bottom_left: Vector2 = poly[3]
		var height: float = bottom_left.y - top_left.y
		var tilt: float = atan2(ROW_SLOPE * view.y, view.x) * 0.5
		if index == 0:
			var title: Label = panel.get_node("ResultTitle")
			title.size = title.get_combined_minimum_size()
			title.position = Vector2(view.x * 0.80, view.y * 0.02)
			title.rotation = tilt
			continue
		var avatar: Control = panel.get_node_or_null("Avatar")
		var side: float = clampf(height * 0.52, 56.0, 120.0)
		var anchor := Vector2(top_left.x + view.x * 0.035, top_left.y + height * 0.28)
		if avatar != null:
			avatar.custom_minimum_size = Vector2(side, side)
			avatar.size = Vector2(side, side)
			avatar.position = anchor
			avatar.rotation = tilt
		var label: Label = panel.get_node_or_null("Name")
		if label != null:
			label.size = Vector2(view.x - anchor.x - side - 48.0, side)
			label.position = anchor + Vector2(side + 22.0, side * 0.15)
			label.rotation = tilt
		var tag: Label = panel.get_node_or_null("Tag")
		if tag != null:
			tag.size = tag.get_combined_minimum_size()
			tag.position = anchor + Vector2(-tag.size.x * 0.35, -tag.size.y * 0.65)
			tag.rotation = -0.12
	stamp.position = Vector2(view.x * 0.02, view.y * 0.01)
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = -0.1
	if popart_label != null:
		popart_label.position = Vector2(view.x * 0.022, view.y * 0.01 + stamp.size.y * 0.82)
		popart_label.pivot_offset = Vector2(0.0, popart_label.size.y * 0.5)
		popart_label.rotation = -0.07
	winner_label.size = Vector2(view.x * 0.44, 0.0)
	winner_label.reset_size()
	winner_label.size.x = view.x * 0.44
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	winner_label.position = Vector2(foot.x * view.x - winner_label.size.x - view.x * 0.03, foot.y * view.y - view.y * 0.06 - winner_label.size.y - 10.0)
	winner_label.pivot_offset = Vector2(winner_label.size.x, winner_label.size.y * 0.5)
	winner_label.rotation = atan2(BAND_SLOPE * view.y, view.x) * 0.6
	victory_label.position = Vector2(view.x * 0.02, band_y(0.02) * view.y + 16.0)
	victory_label.pivot_offset = Vector2(0.0, victory_label.size.y * 0.5)
	victory_label.rotation = atan2(BAND_SLOPE * view.y, view.x) * 0.5
	condition_label.position = victory_label.position + Vector2(10.0, victory_label.size.y + 2.0).rotated(victory_label.rotation)
	condition_label.rotation = victory_label.rotation
	next_button.size = next_button.get_combined_minimum_size()
	next_button.position = Vector2(view.x - next_button.size.x - 14.0, view.y - next_button.size.y - 10.0)
	next_button.rotation = 0.06
	var arrow: Control = next_button.get_node("Arrow")
	arrow.size = Vector2(22, 24)
	arrow.position = Vector2(next_button.size.x - 38.0, (next_button.size.y - 24.0) * 0.5)


## 한 시계로 모든 요소를 놓는다 (t: 0~DURATION초, 배율 전).
func set_time(t: float) -> void:
	_time_view = t
	if _left == null:
		return
	var view: Vector2 = _view()
	_lines.progress = _ease_out(_ramp(t, 0.0, LINES_END))
	_lines.queue_redraw()
	# 1위 칸: 살짝 크게·왼쪽에서 → 제자리
	var settle: float = _ease_out(_ramp(t, LEFT_START, LEFT_END))
	_left.modulate.a = settle
	_left.scale = Vector2.ONE * lerpf(1.08, 1.0, settle)
	_left.position = Vector2((settle - 1.0) * view.x * 0.06, 0.0)
	# 오른쪽 패널: 사선 방향(오른쪽 아래 → 제자리)으로 탄성 있게 슬라이드 인
	var travel: Vector2 = Vector2(view.x, ROW_SLOPE * view.y).normalized() * view.x * 0.5
	for index: int in panels.size():
		var p: float = _ramp(t, panel_start(index), panel_start(index) + PANEL_LEN)
		var panel: ComicPanel = panels[index]
		panel.position = travel * (1.0 - _ease_back(p))
		panel.visible = p > 0.0
	# 1st 도장 + 이름: 크게 떨어져 쾅
	var slam: float = _ramp(t, STAMP_START, STAMP_AT)
	stamp.scale = Vector2.ONE * lerpf(2.8, 1.0, _ease_out(slam))
	stamp.modulate.a = clampf(slam * 3.0, 0.0, 1.0)
	var name_pop: float = _ease_back(_ramp(t, STAMP_AT - 0.04, STAMP_AT + 0.14))
	for label: Label in [winner_label, victory_label]:
		label.scale = Vector2.ONE * maxf(lerpf(1.7, 1.0, name_pop), 0.01) if name_pop > 0.0 else Vector2.ONE * 1.7
		label.modulate.a = clampf(_ramp(t, STAMP_AT - 0.04, STAMP_AT + 0.02), 0.0, 1.0)
	condition_label.modulate.a = _ramp(t, STAMP_AT, STAMP_AT + 0.1)
	if popart_label != null:
		# 팝아트 타이틀은 1st 도장 바로 뒤에 더 크게 떨어져 쾅 (도장과 같은 박자에 이어서)
		var title_pop: float = _ease_back(_ramp(t, STAMP_AT + 0.02, STAMP_AT + 0.2))
		popart_label.scale = Vector2.ONE * (maxf(lerpf(2.2, 1.0, title_pop), 0.01) if title_pop > 0.0 else 2.2)
		popart_label.modulate.a = clampf(_ramp(t, STAMP_AT + 0.02, STAMP_AT + 0.08), 0.0, 1.0)
	var next_in: float = _ease_back(_ramp(t, NEXT_START, DURATION))
	next_button.modulate.a = clampf(next_in * 2.0, 0.0, 1.0)
	next_button.position.x = view.x - next_button.size.x - 14.0 + (1.0 - next_in) * 260.0
	next_button.disabled = t < DURATION
	queue_redraw()


## 흰 종이 (가장 아래 층): 컷신 뒤 화면이 하얗게 번쩍 바뀌며 분할선이 그어진다.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _view()), Color(Color("fbfbf7"), _ramp(_time_view, 0.0, 0.06)))


static func _ramp(t: float, start: float, end: float) -> float:
	return clampf((t - start) / maxf(end - start, 0.001), 0.0, 1.0)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


## cubic-bezier overshoot (easeOutBack): 제자리를 살짝 지나쳤다가 돌아온다.
static func _ease_back(x: float) -> float:
	if x <= 0.0:
		return 0.0
	var c1: float = 2.2
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## 만화 칸 하나: 흰(또는 색) 바탕 다각형 + 굵은 잉크 테두리. 1위 칸에는 집중선.
class ComicPanel extends Control:
	var polygon: PackedVector2Array = PackedVector2Array()
	var fill: Color = Color.WHITE
	var streak: Color = Color(0, 0, 0, 0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if polygon.size() < 3:
			return
		draw_colored_polygon(polygon, fill)
		if streak.a > 0.0:
			var hub: Vector2 = Vector2.ZERO
			for point: Vector2 in polygon:
				hub += point
			hub /= float(polygon.size())
			for i: int in 28:
				var angle: float = TAU * float(i) / 28.0
				var tip: Vector2 = hub + Vector2.from_angle(angle) * 1400.0
				var wing: Vector2 = Vector2.from_angle(angle + PI * 0.5) * 26.0
				var ray := PackedVector2Array([hub + Vector2.from_angle(angle) * 160.0, tip + wing, tip - wing])
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(ray, polygon):  # 칸 밖으로 삐져나가지 않게
					draw_colored_polygon(piece, Color(streak, 0.55))
		var loop := PackedVector2Array(polygon)
		loop.append(polygon[0])
		draw_polyline(loop, ResultComicPage.INK, ResultComicPage.LINE_PX * 0.7, true)


## 가운데 분할선·아래 띠 선 (progress만큼 화면을 가로질러 그어진다).
class ComicLines extends Control:
	var segments: Array = []
	var progress: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for segment: PackedVector2Array in segments:
			if progress <= 0.0:
				break
			var tip: Vector2 = segment[0].lerp(segment[1], progress)
			draw_line(segment[0], tip, ResultComicPage.INK, ResultComicPage.LINE_PX, true)


## [Next Page ▶]의 삼각형 (글꼴에 없는 기호를 그림으로).
class NextArrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, size.y * 0.5), Vector2(0, size.y)]), Color.WHITE)
