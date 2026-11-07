## 결과 1쪽: 검은 페이드 → Result → 4등 → 3등 → 2등 → 1등. 팝아트 얼굴을 테두리 없이 컷에 직접 쓴다.
## 아래 사선 띠 = 승리 이름 (승리 조건), 오른쪽 아래 [Next Page ▶] → 상세 결과표.
## 4등 → 3등 → 2등을 분리된 박자로 공개하고, 검은 여백을 잠시 남긴 뒤 우승자를 공개한다.
## 하나의 시계로 실제 순위 공개·효과음·건너뛰기를 맞춘다.
class_name ResultComicPage
extends Control

signal impact
signal panel_landed(index: int)
signal intro_done
signal next_pressed

## 기본 길이(초, 배율 전).
const FADE_SECONDS: float = 0.42
const RESULT_AT: float = 0.62
const PORTRAIT_CROP = preload("res://scenes/result_portrait_crop.gdshader")
const RESULT_FONT = preload("res://assets/fonts/result/bangers.ttf")
const LEFT_START: float = 3.84
const LEFT_END: float = 4.16
const PANEL_START: float = 1.26
const STAGGER: float = 0.70
const PANEL_LEN: float = 0.26
const STAMP_START: float = 4.18
const STAMP_AT: float = 4.37
const NEXT_START: float = 4.60
const DURATION: float = 4.88
const IMPACT_HOLD: float = 0.06
const REVEAL_ORDER: Array[int] = [3, 2, 1]
## 분할선 굵기(px)와 잉크 색.
const INK := Color("111111")
const LINE_PX: float = 14.0
## 사선 기울기 (정규화 좌표 dy/dx): 오른쪽 칸 경계 / 아래 띠.
const ROW_SLOPE: float = 0.33
const BAND_SLOPE: float = 0.24
## 오른쪽 칸 경계가 가운데 분할선과 만나는 높이 (정규화): Result|2nd, 2nd|3rd, 3rd|4th.
const ROW_EDGES: Array[float] = [0.22, 0.49, 0.64]
const RANK_TAGS: Array[String] = ["1st", "2nd", "3rd", "4th"]

var active: bool = false
var skipping: bool = false
var _audio:=PresentationAudio.new()
var _time: float = 0.0
var _fade_drawn: float = -1.0
var _time_view: float = 0.0
var _pace: float = 1.0
var _impact_fired: bool = false
var _landed: int = 0
var _accent: Color = Color("ffd43b")
var _left: ComicPanel = null
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
var _stamp_base := Vector2.ZERO
var _winner_base := Vector2.ZERO
var _winner_scale := Vector2.ONE
var _victory_base := Vector2.ZERO
var _present_ranks: Array[int] = []


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
	_left.fill = Color("ffe06a")
	_left.streak = Color("e76c42")
	_left.pattern = 1
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
	for index: int in 4:
		var panel := ComicPanel.new()
		panel.name = "ResultHeader" if index == 0 else "RankPanel%d" % (index + 1)
		add_child(panel)
		panels.append(panel)
		if index == 0:
			panel.fill = Color("f9eed6")
			panel.pattern = 5
			var result_title := _make_text("ResultTitle", "Result", 96, 10, Color("fff5d9"))
			result_title.add_theme_font_override("font", RESULT_FONT)
			result_title.add_theme_color_override("font_shadow_color", Color("9b1b5a"))
			result_title.add_theme_constant_override("shadow_offset_x", 6)
			result_title.add_theme_constant_override("shadow_offset_y", 8)
			result_title.add_theme_constant_override("shadow_outline_size", 5)
			panel.add_child(result_title)
			continue
		if index >= entries.size():
			continue
		var entry: Dictionary = entries[index]
		_present_ranks.append(index)
		panel.fill = [Color.WHITE, Color("80ded8"), Color("ff9db4"), Color("bea9ef")][index]
		panel.pattern = index + 1
		var avatar: Control = entry.get("avatar", null)
		if entry.get("face", null) is Texture2D:
			var portrait := TextureRect.new()
			portrait.texture = entry["face"]
			var crop := ShaderMaterial.new()
			crop.shader = PORTRAIT_CROP
			portrait.material = crop
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			avatar = portrait
		if avatar != null:
			avatar.name = "Avatar"
			panel.add_child(avatar)
		var name_label: Label = _make_text("Name", str(entry.get("name", "")), 32, 8)
		name_label.set_meta("full_name", str(entry.get("name", "")))
		panel.add_child(name_label)
		panel.add_child(_make_rank("Tag", RANK_TAGS[mini(int(entry.get("rank", index + 1)), 4) - 1], 40))
	var quoted: bool = condition.begins_with("\"") or condition.begins_with("(")
	condition_label = _make_text("VictoryCondition", (condition if quoted else "(%s)" % condition) if condition != "" else "", 20, 6)
	victory_label = _make_text("VictoryName", victory, 50, 12)
	winner_label = _make_text("WinnerName", str(first.get("name", "")), 64, 14, Color.WHITE, _accent.darkened(0.6))
	winner_label.set_meta("full_name", str(first.get("name", "")))
	stamp = _make_rank("FirstStamp", "1st", 88, Color("ffe26c"))
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
	next_button.mouse_entered.connect(func() -> void: arrow.nudge(1.0))
	next_button.mouse_exited.connect(func() -> void: arrow.nudge(0.0))
	next_button.pressed.connect(func() -> void:
		if not active and _time_view >= DURATION:
			next_pressed.emit())
	add_child(next_button)
	_layout()
	set_time(0.0)


## 등장을 시작한다. pace: 연출 시간 배율 (1.0 = DURATION초).
func play(pace: float = 1.0) -> void:
	skipping=false
	_pace = maxf(pace, 0.1)
	_time = 0.0
	_impact_fired = false
	_landed = 0
	active = true
	visible = true
	_audio.start(self,[PresentationAudio.cue(RESULT_AT,&"result_title")])
	set_time(0.0)
	set_process(true)


## 등장을 건너뛴다 (도장 impact는 한 번 준다).
func skip() -> void:
	if not active:
		return
	skipping=true
	_advance_to(DURATION)
	_finish()
	skipping=false


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		skip()


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time / _pace
	# Hold this page's clock at contact for a few frames; never pause the match clock.
	if t > STAMP_AT:t = maxf(STAMP_AT, t - IMPACT_HOLD)
	_audio.advance(t)
	_advance_to(minf(t, DURATION))
	if t >= DURATION:
		_finish()


## 시계를 t로 옮기며 그 사이의 착지·impact 신호를 순서대로 낸다.
func _advance_to(t: float) -> void:
	while _landed < REVEAL_ORDER.size() and t >= landing_time(REVEAL_ORDER[_landed]):
		var index := REVEAL_ORDER[_landed]
		_landed += 1
		if _present_ranks.has(index):panel_landed.emit(index)
	if not _impact_fired and t >= STAMP_AT:
		_impact_fired = true
		impact.emit()
	set_time(t)


func _finish() -> void:
	_audio.cancel()
	active = false
	set_process(false)
	intro_done.emit()


## 헤더는 먼저, 실제 순위는 4등→3등→2등. 제자리에 닿은 뒤 충분히 머문다.
static func panel_start(index: int) -> float:
	if index == 0:return RESULT_AT # Result is a page header, never a competing rank reveal.
	return PANEL_START + STAGGER * float(3 - index)


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


func _make_rank(node_name: String, text: String, font_size: int, fill: Color = Color("fff5d9")) -> Label:
	var label := _make_text(node_name,text,font_size,0,INK)
	label.add_theme_font_override("font",RESULT_FONT)
	var bubble := RankBubble.new()
	bubble.name = "RankBubble"
	bubble.fill = fill
	bubble.show_behind_parent = true
	label.add_child(bubble)
	return label


func _layout_rank(label: Label) -> void:
	label.size = label.get_combined_minimum_size()
	var padding := Vector2(label.size.y*0.22,label.size.y*0.04)
	var bubble: RankBubble = label.get_node("RankBubble")
	bubble.position = -padding
	bubble.size = label.size + padding*2.0
	bubble.queue_redraw()


## Keep up to ten-character names complete; long lower ranks use two balanced lines.
## Scale the existing font as a block instead of creating arbitrary font-size variants.
func _fit_player_name(label: Label, area: Rect2, two_lines: bool) -> void:
	var full_name := str(label.get_meta("full_name",label.text))
	var font := label.get_theme_font("font")
	var px := label.get_theme_font_size("font_size")
	var text := full_name
	if two_lines and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x > area.size.x:
		var split := maxi(1,full_name.length()/2)
		var best := INF
		for i: int in range(1,full_name.length()):
			var left := font.get_string_size(full_name.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
			var right := font.get_string_size(full_name.substr(i),HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
			if maxf(left,right) < best:best=maxf(left,right);split=i
		text = full_name.left(split).strip_edges()+"\n"+full_name.substr(split).strip_edges()
	label.text = text
	label.size = Vector2.ZERO
	label.reset_size()
	var natural := label.get_combined_minimum_size()
	label.size = natural
	var fit := minf(1.0,minf((area.size.x-12.0)/maxf(natural.x,1.0),(area.size.y-12.0)/maxf(natural.y,1.0)))
	label.scale = Vector2.ONE*fit
	label.pivot_offset = Vector2.ZERO
	label.position = area.position + Vector2(0.0,(area.size.y-natural.y*fit)*0.5)


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
	match index:
		0:return PackedVector2Array([Vector2(0.60,0.015),Vector2(0.985,0.015),Vector2(0.985,0.18),Vector2(0.628,0.215)])
		1:return PackedVector2Array([Vector2(0.628,0.215),Vector2(0.985,0.18),Vector2(0.985,0.415),Vector2(0.59,0.445),Vector2(0.64,0.36)])
		2:return PackedVector2Array([Vector2(0.59,0.445),Vector2(0.985,0.415),Vector2(0.985,0.68),Vector2(0.555,0.64)])
		_:return PackedVector2Array([Vector2(0.555,0.64),Vector2(0.985,0.68),Vector2(0.985,0.91),Vector2(0.59,0.84),Vector2(0.54,0.66)])


static func first_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.015,0.04),Vector2(0.58,0.015),Vector2(0.64,0.36),Vector2(0.54,0.66),Vector2(0.59,0.84),Vector2(0.02,0.73)])


func _scaled(points: PackedVector2Array, view: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in points:
		out.append(point * view)
	return out


## Native label ink bounds, including its hard outline and offset block shadow.
## Bangers' glyph extents for "Result" are normalized against its original em.
func result_title_ink() -> Rect2:
	var title: Label = panels[0].get_node("ResultTitle")
	var px := title.get_theme_font_size("font_size")
	var font := title.get_theme_font("font")
	var width := font.get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x * (2413.0 / 2298.0)
	var top := font.get_ascent(px) - float(px) * 0.737
	return Rect2(Vector2(-10.0,top-10.0),Vector2(width+31.0,float(px)*0.755+33.0))


func result_title_corners() -> PackedVector2Array:
	var title: Label = panels[0].get_node("ResultTitle")
	var ink := result_title_ink()
	var corners := PackedVector2Array()
	for point: Vector2 in [ink.position,Vector2(ink.end.x,ink.position.y),ink.end,Vector2(ink.position.x,ink.end.y)]:
		corners.append(title.get_transform() * point)
	return corners


func _fit_result_title(title: Label, poly: PackedVector2Array, view: Vector2) -> void:
	title.size = title.get_combined_minimum_size()
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var center := Vector2.ZERO
	var area := 0.0
	for i: int in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var cross := a.cross(b)
		area += cross
		center += (a+b)*cross
	center /= 3.0*area
	title.pivot_offset = result_title_ink().get_center()
	title.position = center - title.pivot_offset
	title.rotation = -0.035
	var low := 0.0
	var high := 1.65 * view.y / 768.0
	# Fit every visible ink corner within the actual polygon, not a guessed rectangle.
	for i: int in 18:
		var trial := (low+high)*0.5
		title.scale = Vector2.ONE*trial
		var fits := true
		for point: Vector2 in result_title_corners():
			if not Geometry2D.is_point_in_polygon(point,poly):fits=false
		if fits:low=trial
		else:high=trial
	title.scale = Vector2.ONE*low*0.88


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
		var side: float = view.y * 0.98
		_art.size = Vector2(side, side)
		_art.position = Vector2(view.x * 0.29 - side * 0.5, view.y * 0.025)
	elif _left.get_child_count() > 1:
		var portrait: Control = _left.get_child(1) as Control  # 0번은 부딪힘 테두리
		portrait.position = Vector2(view.x * 0.24, view.y * 0.2)
	for index: int in panels.size():
		var panel: ComicPanel = panels[index]
		panel.size = view
		var poly := _scaled(panel_polygon(index), view)
		panel.polygon = poly
		panel.queue_redraw()
		if index == 0:
			var title: Label = panel.get_node("ResultTitle")
			_fit_result_title(title, poly, view)
			continue
		var center: Vector2 = [Vector2.ZERO,Vector2(0.710,0.320),Vector2(0.690,0.554),Vector2(0.680,0.770)][index] * view
		var side: float = view.y * [0.0,0.52,0.49,0.43][index]
		var anchor := center - Vector2.ONE * side * 0.5
		var edge := poly[1] - poly[0]
		var tilt := atan2(edge.y,edge.x)
		var avatar: Control = panel.get_node_or_null("Avatar")
		if avatar != null:
			avatar.custom_minimum_size = Vector2(side,side)
			avatar.size = Vector2(side,side)
			avatar.position = anchor
			avatar.rotation = 0.0
			avatar.z_index = 1
			if avatar.material is ShaderMaterial:
				var points := poly.duplicate()
				while points.size() < 8:points.append(Vector2.ZERO)
				avatar.material.set_shader_parameter("cut_points", points)
				avatar.material.set_shader_parameter("cut_count", poly.size())
				avatar.material.set_shader_parameter("image_origin", anchor)
				avatar.material.set_shader_parameter("ink_inset", LINE_PX * view.y / 1536.0)
		var label: Label = panel.get_node_or_null("Name")
		if label != null:
			var x: float = [0.0,0.840,0.820,0.810][index]*view.x
			_fit_player_name(label,Rect2(Vector2(x,center.y-view.y*0.055),Vector2(view.x*0.975-x,view.y*0.12)),true)
			label.rotation = tilt
			label.z_index = 2
		var tag: Label = panel.get_node_or_null("Tag")
		if tag != null:
			_layout_rank(tag)
			tag.position = poly[0] + Vector2(view.x * 0.018,view.y * 0.019)
			tag.rotation = tilt
			tag.z_index = 3
	_layout_rank(stamp)
	stamp.position = Vector2(view.x * 0.045, view.y * 0.055)
	_stamp_base = stamp.position
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = -0.1
	if popart_label != null:
		popart_label.position = Vector2(view.x * 0.022, view.y * 0.01 + stamp.size.y * 0.82)
		popart_label.pivot_offset = Vector2(0.0, popart_label.size.y * 0.5)
		popart_label.rotation = -0.07
	_fit_player_name(winner_label,Rect2(Vector2(view.x*0.080,view.y*0.610),Vector2(view.x*0.47,view.y*0.12)),false)
	_winner_scale = winner_label.scale
	winner_label.rotation = atan2(BAND_SLOPE * view.y, view.x) * 0.6
	_winner_base = winner_label.position
	victory_label.position = Vector2(view.x * 0.035, view.y * 0.80)
	victory_label.pivot_offset = Vector2(0.0, victory_label.size.y * 0.5)
	victory_label.rotation = atan2(BAND_SLOPE * view.y, view.x) * 0.5
	_victory_base = victory_label.position
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
	# 1위 칸: 살짝 크게·왼쪽에서 → 제자리
	var settle: float = _ease_out(_ramp(t, LEFT_START, LEFT_END))
	_left.visible = t > LEFT_START
	_left.modulate.a = 1.0
	_left.scale = Vector2.ONE * lerpf(1.11, 1.0, settle)
	_left.position = Vector2((settle - 1.0) * view.x * 0.14, 0.0)
	if _art != null:
		var art_in := _ease_out(_ramp(t, LEFT_START + 0.03, STAMP_START))
		_art.pivot_offset = _art.size * Vector2(0.48, 0.62)
		_art.scale = Vector2.ONE * lerpf(1.075, 1.0, art_in)
	# 오른쪽 패널: 사선 방향(오른쪽 아래 → 제자리)으로 탄성 있게 슬라이드 인
	var travel: Vector2 = Vector2(view.x, ROW_SLOPE * view.y).normalized() * view.x * 0.5
	for index: int in panels.size():
		var start := panel_start(index)
		var p := _ramp(t, start, start + PANEL_LEN)
		var panel: ComicPanel = panels[index]
		panel.visible = t > start and (index == 0 or _present_ranks.has(index))
		panel.position = travel * (1.0 - _ease_back(p))
		var land := landing_time(index)
		panel.contact = sin(PI * _ramp(t, land, land + 0.12)) if index != 0 else 0.0
		panel.queue_redraw()
	# 1st 도장 + 이름: 크게 떨어져 쾅
	var slam: float = _ramp(t, STAMP_START, STAMP_AT)
	stamp.scale = Vector2.ONE * lerpf(2.8, 1.0, _ease_out(slam))
	stamp.modulate.a = clampf(slam * 3.0, 0.0, 1.0)
	var recoil := sin(PI * _ramp(t, STAMP_AT, STAMP_AT + 0.14))
	stamp.scale *= Vector2(1.0 + recoil * 0.07, 1.0 - recoil * 0.06)
	stamp.rotation = -0.10 - (1.0 - _ease_out(slam)) * 0.18
	stamp.position = _stamp_base + Vector2(0, -view.y * 0.09 * (1.0 - _ease_out(slam)))
	var name_in := _ease_out(_ramp(t, STAMP_AT - 0.02, STAMP_AT + 0.16))
	winner_label.scale = _winner_scale
	winner_label.position = _winner_base + Vector2(-view.x * 0.035 * (1.0 - name_in), 0)
	winner_label.modulate.a = clampf(name_in * 2.0, 0.0, 1.0)
	var title_in := _ease_out(_ramp(t, STAMP_AT + 0.015, DURATION))
	victory_label.scale = Vector2.ONE
	victory_label.position = _victory_base + Vector2(-view.x * 0.045 * (1.0 - title_in), 0)
	victory_label.modulate.a = clampf(title_in * 2.0, 0.0, 1.0)
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
	var fade := fade_alpha(t)
	if not is_equal_approx(fade, _fade_drawn):  # 페이드가 끝난 뒤에는 매 프레임 다시 그리지 않는다
		_fade_drawn = fade
		queue_redraw()


## Fade from the actual board into full black; unrevealed cuts have no outlines or fills.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,_view()),Color(0,0,0,fade_alpha(_time_view)))

static func fade_alpha(t: float) -> float:
	return _ease_out(_ramp(t,0.0,FADE_SECONDS))


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


## A single inked speech balloon follows its rank label's entry/rotation/impact.
class RankBubble extends Control:
	var fill := Color("fff5d9")
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var points := PackedVector2Array()
		for degrees: int in range(0,360,15):
			if degrees == 105:
				points.append(Vector2(size.x*0.13,size.y*1.15))
			var angle := deg_to_rad(float(degrees))
			points.append(size*0.5+Vector2(cos(angle)*size.x*0.56,sin(angle)*size.y*0.47))
		for i: int in points.size():points[i].x = size.x-points[i].x
		points.reverse()
		var shadow := PackedVector2Array()
		var width := maxf(2.0,size.y*0.055)
		for point: Vector2 in points:shadow.append(point+Vector2(width,width*1.1))
		draw_colored_polygon(shadow,INK)
		draw_colored_polygon(points,fill)
		points.append(points[0])
		draw_polyline(points,INK,width,true)


## 만화 칸 하나: 흰(또는 색) 바탕 다각형 + 굵은 잉크 테두리. 1위 칸에는 집중선.
class ComicPanel extends Control:
	var polygon: PackedVector2Array = PackedVector2Array()
	var fill: Color = Color.WHITE
	var streak: Color = Color(0, 0, 0, 0)
	var pattern := 0
	## 부딪힘 테두리는 따로 그려서, 움직이는 동안 만화 무늬(점·줄무늬·집중선)를 다시 그리지 않는다.
	var contact := 0.0:
		set(value):
			if is_equal_approx(contact, value):
				return
			contact = value
			if _edge != null:
				_edge.queue_redraw()
	var _edge: Control = null
	var _dots: ArrayMesh = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edge = ContactEdge.new()
		_edge.name = "ContactEdge"
		_edge.panel = self
		add_child(_edge)

	## 반색조 점 전체를 메시 하나로 만든다 (점마다 draw_circle을 부르면 그리기 호출이 천 개가 넘는다).
	func _build_dots(unit: float) -> ArrayMesh:
		var vertices := PackedVector2Array()
		var colors := PackedColorArray()
		var radius := 2.4 * unit
		var alpha := 0.065 if pattern == 5 else (0.18 if pattern != 1 else 0.11)
		var color := Color(ResultComicPage.INK, alpha)
		for row: int in range(0,ceili(size.y/(22.0*unit))):
			for column: int in range(0,ceili(size.x/(22.0*unit))):
				var at := Vector2((float(column)+float(row%2)*0.5)*22.0,float(row)*22.0)*unit
				if pattern == 1 and at.x > size.x*0.16 and at.x < size.x*0.43:continue
				if not Geometry2D.is_point_in_polygon(at,polygon):continue
				for step: int in 8:
					var a0 := TAU * float(step) / 8.0
					var a1 := TAU * float(step + 1) / 8.0
					vertices.append(at)
					vertices.append(at + Vector2.from_angle(a0) * radius)
					vertices.append(at + Vector2.from_angle(a1) * radius)
					colors.append_array([color,color,color])
		if vertices.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

	func _draw() -> void:
		if polygon.size() < 3:
			return
		draw_colored_polygon(polygon, fill)
		var unit := maxf(size.y / 768.0, 0.25)
		if pattern in [1,2,4,5]:
			# Large Ben-Day clusters read as print, not a field of tiny UI decorations.
			_dots = _build_dots(unit)
			if _dots != null:
				draw_mesh(_dots, null)
		if pattern in [3,4]:
			var shade := Color("bd245e") if pattern == 3 else Color("635194")
			for stripe: int in range(-30,60):
				var x := float(stripe)*42.0*unit
				var band := PackedVector2Array([Vector2(x,0),Vector2(x+12.0*unit,0),Vector2(x+size.y*0.5+12.0*unit,size.y),Vector2(x+size.y*0.5,size.y)])
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(band,polygon):draw_colored_polygon(piece,Color(shade,0.22))
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
		draw_polyline(loop, ResultComicPage.INK, ResultComicPage.LINE_PX * size.y / 768.0, true)
		if contact > 0.0:
			# Contact follows this panel edge; it never crosses the winner artwork.
			draw_polyline(loop, Color(ResultComicPage.INK, contact * 0.70), (18.0 + contact * 4.0) * unit, true)


## 칸 가장자리의 부딪힘 강조선. 칸의 무늬와 분리해 이 선만 다시 그린다.
class ContactEdge extends Control:
	var panel: ComicPanel = null
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if panel == null or panel.contact <= 0.0 or panel.polygon.size() < 3:
			return
		# Contact follows this panel edge; it never crosses the winner artwork.
		var unit := maxf(panel.size.y / 768.0, 0.25)
		var loop := PackedVector2Array(panel.polygon)
		loop.append(panel.polygon[0])
		draw_polyline(loop, Color(ResultComicPage.INK, panel.contact * 0.70), (18.0 + panel.contact * 4.0) * unit, true)


## [Next Page ▶]의 삼각형 (글꼴에 없는 기호를 그림으로).
class NextArrow extends Control:
	var _hover := 0.0
	var _tween: Tween
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var shift := Vector2(_hover * 5.0, 0)
		draw_colored_polygon(PackedVector2Array([shift, shift + Vector2(size.x, size.y * 0.5), shift + Vector2(0, size.y)]), Color.WHITE)
	func nudge(value: float) -> void:
		if _tween != null and _tween.is_valid():_tween.kill()
		_tween = create_tween()
		_tween.tween_method(func(x: float) -> void: _hover = x;queue_redraw(), _hover, value, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
