## 졸업 컷신 (1.01): 특수 승리(법전) 달성과 완주 피니시를 화면 전체 컷신으로 보여 준다.
## 시네마 띠 → 플레이어 색 사선 띠 → 사도 전신 그림(왼쪽) + 법전 그림 또는 체크무늬 깃발(오른쪽) → 큰 도장(특수 승리! / FINISH!) → 이름·순위.
## 시계 하나(set_time)로 모든 요소가 움직여 배속·건너뛰기에서도 어긋나지 않는다. 시뮬레이션·RNG는 건드리지 않는다.
class_name VictoryCutscene
extends Control

signal impact
signal completed

const MODE_LAW: StringName = &"law"
const MODE_FINISH: StringName = &"finish"
## 기본 길이(초). 실제 길이는 play()의 pace를 곱한다.
const DURATION: float = 3.2
const IMPACT_AT: float = 0.62
const LEAVE_AT: float = 2.75
const BAR_RATIO: float = 0.12

var mode: StringName = MODE_LAW
var accent: Color = Color("ffd43b")
var active: bool = false
var _time: float = 0.0
var _length: float = DURATION
var _impact_fired: bool = false
var _actor: TextureRect = null
var _art: TextureRect = null
var _headline: Label = null
var _title: Label = null
var _subtitle: Label = null
var _name_label: Label = null
## set_time이 마지막으로 그린 시각 (_draw가 같은 시각을 쓴다).
var _time_view: float = 0.0


func _init() -> void:
	name = "VictoryCutscene"
	mouse_filter = Control.MOUSE_FILTER_STOP  # 컷신 동안 보드 입력을 막고, 누르면 건너뛴다
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(active)  # 엔진이 _ready에서 _process를 다시 켜므로, play() 전에는 시계가 돌지 않게 끈다


## mode: MODE_LAW / MODE_FINISH. actor: 사도 전신 그림(없으면 생략). art: 법전 그림(완주는 null → 체크무늬 깃발).
## headline: 큰 도장 글자. title: 법전 이름 또는 순위. subtitle: 조건 또는 완주 설명. player_name: 이름 띠.
func setup(cut_mode: StringName, color: Color, actor: Texture2D, art: Texture2D, headline: String, title: String, subtitle: String, player_name: String) -> void:
	mode = cut_mode
	accent = color
	if actor != null:
		_actor = _make_picture("CutsceneActor", actor)
	if art != null:
		_art = _make_picture("CutsceneArt", art)
	_headline = _make_text("CutsceneHeadline", headline, 64, Color.WHITE, 12)
	_name_label = _make_text("CutscenePlayer", player_name, 30, color.lightened(0.35), 6)
	_title = _make_text("CutsceneTitle", title, 40, Color("fff3bf"), 8)
	_subtitle = _make_text("CutsceneSubtitle", subtitle, 22, Color("f1f3f5"), 5)
	_layout()
	set_time(0.0)


## 재생을 시작한다. pace: 연출 시간 배율 (1.0 = DURATION초).
func play(pace: float = 1.0) -> void:
	_length = DURATION * maxf(pace, 0.1)
	_time = 0.0
	_impact_fired = false
	active = true
	visible = true
	set_process(true)


func skip() -> void:
	if not active:
		return
	if not _impact_fired:
		_impact_fired = true
		impact.emit()
	_finish()


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _time / _length > IMPACT_AT / DURATION:
		accept_event()
		skip()


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time / _length * DURATION
	if not _impact_fired and t >= IMPACT_AT:
		_impact_fired = true
		impact.emit()
	set_time(t)
	if t >= DURATION:
		_finish()


func _finish() -> void:
	active = false
	set_process(false)
	visible = false
	completed.emit()


func _make_picture(node_name: String, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _make_text(node_name: String, text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FontSizes.snap(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("15111c"))
	label.add_theme_constant_override("outline_size", outline)
	add_child(label)
	return label


func _view() -> Vector2:
	var view: Vector2 = size
	if view.x < 2.0 or view.y < 2.0:
		view = get_viewport_rect().size
	return view


func _layout() -> void:
	var view: Vector2 = _view()
	var side: float = minf(view.y * 0.62, view.x * 0.36)
	if _actor != null:
		_actor.size = Vector2(side, side)
		_actor.pivot_offset = _actor.size * 0.5
	if _art != null:
		_art.size = Vector2(side * 0.72, side * 0.72)
		_art.pivot_offset = _art.size * 0.5
	for label: Label in [_headline, _name_label, _title, _subtitle]:
		label.size = Vector2(view.x * 0.62, 0.0)
		label.reset_size()
		label.size.x = view.x * 0.62
		label.pivot_offset = label.size * 0.5


## 한 시계로 모든 요소의 위치·투명도를 정한다 (t: 0~DURATION초).
func set_time(t: float) -> void:
	_time_view = t
	var view: Vector2 = _view()
	var leave: float = _ease_in(_ramp(t, LEAVE_AT, DURATION))
	var center: Vector2 = view * 0.5
	if _actor != null:
		var enter: float = _ease_out(_ramp(t, 0.18, 0.55))
		_actor.position = Vector2(lerpf(-_actor.size.x, view.x * 0.04, enter) - leave * view.x * 0.3, center.y - _actor.size.y * 0.5 + view.y * 0.03)
		_actor.modulate.a = enter * (1.0 - leave)
		_actor.scale = Vector2.ONE * (1.0 + 0.04 * sin(_ramp(t, IMPACT_AT, IMPACT_AT + 0.3) * PI))
	if _art != null:
		var pop: float = _ease_back(_ramp(t, 0.32, 0.68))
		_art.position = Vector2(view.x * 0.96 - _art.size.x + (1.0 - pop) * view.x * 0.25 + leave * view.x * 0.3, center.y - _art.size.y * 0.5 - view.y * 0.06)
		_art.rotation = lerpf(0.35, 0.06, pop)
		_art.scale = Vector2.ONE * maxf(pop, 0.01)
		_art.modulate.a = clampf(pop * 2.0, 0.0, 1.0) * (1.0 - leave)
	# 도장: 크게 떨어져 쾅
	var slam: float = _ramp(t, IMPACT_AT - 0.12, IMPACT_AT)
	_headline.position = Vector2(center.x - _headline.size.x * 0.5, center.y - view.y * 0.2 - _headline.size.y * 0.5)
	_headline.scale = Vector2.ONE * lerpf(2.6, 1.0, _ease_out(slam))
	_headline.rotation = -0.07
	_headline.modulate.a = clampf(slam * 3.0, 0.0, 1.0) * (1.0 - leave)
	var info: float = _ease_out(_ramp(t, IMPACT_AT + 0.12, IMPACT_AT + 0.45))
	var drop: float = (1.0 - info) * 24.0
	_name_label.position = Vector2(center.x - _name_label.size.x * 0.5, center.y - view.y * 0.06 + drop)
	_title.position = Vector2(center.x - _title.size.x * 0.5, center.y + view.y * 0.03 + drop)
	_subtitle.position = Vector2(center.x - _subtitle.size.x * 0.5, center.y + view.y * 0.12 + drop)
	for label: Label in [_name_label, _title, _subtitle]:
		label.modulate.a = info * (1.0 - leave)
	queue_redraw()


func _draw() -> void:
	var t: float = _time_view
	var view: Vector2 = _view()
	var leave: float = _ease_in(_ramp(t, LEAVE_AT, DURATION))
	var open: float = _ease_out(_ramp(t, 0.0, 0.25)) * (1.0 - leave)
	# 어둡게 + 시네마 띠
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.03, 0.02, 0.06, 0.62 * open))
	var bar: float = view.y * BAR_RATIO * open
	draw_rect(Rect2(0, 0, view.x, bar), Color("08060c"))
	draw_rect(Rect2(0, view.y - bar, view.x, bar), Color("08060c"))
	# 플레이어 색 사선 띠 (왼쪽에서 쓸고 들어온다)
	var sweep: float = _ease_out(_ramp(t, 0.08, 0.42))
	if sweep > 0.0:
		var band_h: float = view.y * 0.34
		var y: float = view.y * 0.5 - band_h * 0.5
		var slant: float = view.y * 0.12
		var right: float = lerpf(-slant, view.x + slant, sweep)
		var band := Color(accent.darkened(0.35), 0.86 * (1.0 - leave))
		draw_colored_polygon(PackedVector2Array([Vector2(-slant, y), Vector2(right + slant, y), Vector2(right, y + band_h), Vector2(-slant * 2.0, y + band_h)]), band)
		var edge := Color(accent.lightened(0.4), 0.9 * (1.0 - leave))
		draw_line(Vector2(-slant, y - 4.0), Vector2(right + slant, y - 4.0), edge, 3.0, true)
		draw_line(Vector2(-slant * 2.0, y + band_h + 4.0), Vector2(right, y + band_h + 4.0), edge, 3.0, true)
		# 속도선
		var streak: float = sin(clampf(sweep, 0.0, 1.0) * PI) + 0.25 * (1.0 - leave)
		for i: int in 7:
			var sy: float = y + band_h * (0.1 + 0.13 * float(i))
			var length: float = view.x * (0.12 + 0.05 * float(i % 3))
			var sx: float = fposmod(view.x * 0.17 * float(i) + t * view.x * 0.9, view.x + length) - length
			draw_line(Vector2(sx, sy), Vector2(sx + length, sy), Color(1, 1, 1, 0.16 * streak), 2.0, true)
	if mode == MODE_FINISH:
		_draw_checker_flag(view, t, leave)
	elif _art != null and _art.modulate.a > 0.01:
		# 법전 그림 금테
		var frame := Rect2(_art.position - Vector2(8, 8), _art.size + Vector2(16, 16))
		draw_set_transform(frame.get_center(), _art.rotation, _art.scale)
		draw_rect(Rect2(-frame.size * 0.5, frame.size), Color(Color("ffd43b"), _art.modulate.a), false, 6.0)
		draw_set_transform(Vector2.ZERO)
	# 충돌 섬광 + 빛줄기
	var flash: float = 1.0 - _ramp(t, IMPACT_AT, IMPACT_AT + 0.22)
	if t >= IMPACT_AT and flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 0.55 * flash))
	var rays: float = _ramp(t, IMPACT_AT, IMPACT_AT + 0.4) * (1.0 - leave)
	if rays > 0.0:
		var hub: Vector2 = Vector2(view.x * 0.5, view.y * 0.5 - view.y * 0.2)
		for i: int in 12:
			var angle: float = TAU * float(i) / 12.0 + t * 0.6
			var tip: Vector2 = hub + Vector2.from_angle(angle) * view.x * 0.5
			var wing: Vector2 = Vector2.from_angle(angle + PI * 0.5) * 18.0
			draw_colored_polygon(PackedVector2Array([hub, tip + wing, tip - wing]), Color(Color("fff3bf"), 0.07 * rays))


## 완주 피니시: 오른쪽에서 펄럭이는 체크무늬 깃발.
func _draw_checker_flag(view: Vector2, t: float, leave: float) -> void:
	var pop: float = _ease_back(_ramp(t, 0.32, 0.68))
	if pop <= 0.0:
		return
	var cell: float = view.y * 0.045
	var cols: int = 8
	var rows: int = 6
	var origin := Vector2(view.x * 0.95 - cell * cols + (1.0 - pop) * view.x * 0.25 + leave * view.x * 0.3, view.y * 0.5 - cell * rows * 0.5 - view.y * 0.06)
	var alpha: float = clampf(pop * 2.0, 0.0, 1.0) * (1.0 - leave)
	draw_line(origin + Vector2(-6, -cell * 0.5), origin + Vector2(-6, cell * (rows + 4)), Color(Color("dee2e6"), alpha), 7.0, true)
	for r: int in rows:
		for c: int in cols:
			var wave: float = sin(t * 7.0 + float(c) * 0.8) * cell * 0.22 * float(c) / float(cols)
			var p := origin + Vector2(c * cell, r * cell + wave)
			var dark: bool = (r + c) % 2 == 0
			draw_rect(Rect2(p, Vector2(cell + 0.5, cell + 0.5)), Color(Color("111111") if dark else Color("f8f9fa"), alpha))


static func _ramp(t: float, start: float, end: float) -> float:
	return clampf((t - start) / maxf(end - start, 0.001), 0.0, 1.0)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_in(x: float) -> float:
	return x * x


static func _ease_back(x: float) -> float:
	if x <= 0.0:
		return 0.0
	var c1: float = 1.70158
	return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
