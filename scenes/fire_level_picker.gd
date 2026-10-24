# File: res://scenes/fire_level_picker.gd
# Class: class_name FireLevelPicker
# Role: 놀이터 난이도 고르기 = 불닭 매운맛 지표 Fire Level 1~5. 위에는 표정이 바뀌는 사도 얼굴 + 1~5칸 불꽃 게이지(칸을 누르면 그 단계),
#       가운데에는 국물 없는 볶음면: 소스가 떨어지면 면에 색이 입혀지고, 단계가 높아질수록 김·불꽃이 강해진다.
#       얼굴은 굵은 선의 표정 아이콘. 한 개의 반응 시계만 써서 연속 선택에도 모션이 쌓이지 않고, 숨긴 화면은 애니메이션을 멈춘다.
#       아래에는 단계 설명(흐르는 글). 글은 원문 한국어로 두고 화면에서 번역된다. AI 수치는 BotTemper.LEVELS가 맡는다.
class_name FireLevelPicker
extends VBoxContainer

signal level_chosen(level: int)

## 단계별 소스 색.
const SAUCE: Dictionary = {1: Color("f8dc93"), 2: Color("f5a078"), 3: Color("e95d32"), 4: Color("aa382b"), 5: Color("d92329")}
## 게이지 칸 색 (1칸부터 차오른다).
const CELL: Dictionary = {1: Color("ffd36b"), 2: Color("ffa04a"), 3: Color("f2552c"), 4: Color("b3123a"), 5: Color("ff0033")}
const CELL_EMPTY: Color = Color("dcdbe8")
## 단계 설명: 이름·수치 없이 어떤 느낌인지만 (수치는 BotTemper.LEVELS).
const NOTES: Dictionary = {
	1: "입문자 추천 난이도. 컴퓨터가 공격을 잘 안 해요",
	2: "가볍게 즐기기 좋아요. 내가 앞서 나갈 때만 견제해요",
	3: "봐주기 없는 정정당당한 승부! 1등을 먼저 노려요",
	4: "컴퓨터가 카드·함정·필살기를 아낌없이 써요",
	5: "공식 억까 모드! 컴퓨터들이 나만 집요하게 노려요",
}
const CELL_SIZE: Vector2 = Vector2(88, 80)
const BOWL_SIZE: Vector2 = Vector2(540, 116)

var level: int = BotTemper.DEFAULT_LEVEL
var _face: FireFace = null
var _cells: Dictionary = {}
var _bowl: RamenBowl = null
var _note: MarqueeLabel = null


static func create(start_level: int) -> FireLevelPicker:
	var picker := FireLevelPicker.new()
	picker.level = BotTemper.sanitize(start_level)
	picker._build()
	picker.set_level(picker.level, false)
	return picker


func _build() -> void:
	name = "FireLevelPicker"
	add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.name = "FireGaugeRow"
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	_face = FireFace.new()
	_face.name = "FireFace"
	_face.custom_minimum_size = Vector2(64, 64)
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_face)
	var gauge := HBoxContainer.new()
	gauge.name = "DifficultyRow"  # 테스트·화면이 이 이름으로 찾는다 (칸 5개 = 버튼 5개)
	gauge.add_theme_constant_override("separation", 5)
	top.add_child(gauge)
	for step: int in BotTemper.ALL:
		var cell := Button.new()
		cell.name = "Difficulty_%d" % step
		cell.toggle_mode = true
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = CELL_SIZE
		cell.clip_contents = true
		cell.pressed.connect(_on_cell_pressed.bind(step))
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_theme_constant_override("separation", 0)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(stack)
		var flame := FlameIcon.new()
		flame.name = "Flame"
		flame.custom_minimum_size = Vector2(0, 28)
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(flame)
		var number := Label.new()
		number.name = "LevelNumber"
		number.text = "Lv.%d" % step
		number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 15)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(number)
		var title: MarqueeLabel = MarqueeLabel.create(str(BotTemper.NAMES[step]), 14, Color.WHITE, Vector2(CELL_SIZE.x - 8, 22), HORIZONTAL_ALIGNMENT_CENTER, "LevelName")
		title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(title)
		gauge.add_child(cell)
		_cells[step] = cell
	_bowl = RamenBowl.new()
	_bowl.name = "RamenBowl"
	_bowl.custom_minimum_size = BOWL_SIZE
	_bowl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bowl)
	_note = MarqueeLabel.create("", 17, LobbyTheme.BLUE, Vector2(540, 26), HORIZONTAL_ALIGNMENT_CENTER, "DifficultyNote")
	add_child(_note)


func _on_cell_pressed(step: int) -> void:
	set_level(step)
	level_chosen.emit(step)


## 단계를 바꾼다. animate: 소스 투하·표정 튕김 연출 (처음 그릴 때는 끈다).
func set_level(value: int, animate: bool = true) -> void:
	level = BotTemper.sanitize(value)
	for step: int in _cells:
		var cell: Button = _cells[step]
		var lit: bool = step <= level
		var chosen: bool = step == level
		cell.set_pressed_no_signal(chosen)
		var fill: Color = CELL[step] if lit else CELL_EMPTY
		var edge: Color = Color("3a1010") if chosen else fill.darkened(0.25)
		for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var box: StyleBoxFlat = LobbyTheme.style(fill.lightened(0.08) if state_name.begins_with("hover") else fill, edge, 4 if chosen else 2, 14)
			cell.add_theme_stylebox_override(state_name, box)
		var ink: Color = Color("4a2b12") if (lit and step <= 2) else (Color.WHITE if lit else Color("7d7b90"))
		(cell.find_child("LevelNumber", true, false) as Label).add_theme_color_override("font_color", ink)
		((cell.find_child("LevelNameBox", true, false) as MarqueeLabel).label()).add_theme_color_override("font_color", ink)
		(cell.find_child("Flame", true, false) as FlameIcon).setup(lit, step)
	_face.set_level(level, animate)
	_bowl.set_level(level, animate)
	_note.text = str(NOTES[level])


## 작은 크기에서도 읽히는 표정 배지. 얼굴의 실루엣·눈·입은 고정하고 짧은 반응만 더한다.
class FireFace:
	extends Control
	const SKIN: Dictionary = {1: Color("ffe6a1"), 2: Color("ffd08a"), 3: Color("ffae6c"), 4: Color("ff885e"), 5: Color("f55d4e")}
	const INK: Color = Color("542b24")
	var level: int = 1
	var _time: float = 0.0
	var _reaction: float = 1.0

	func set_level(value: int, animate: bool) -> void:
		level = BotTemper.sanitize(value)
		_reaction = 0.0 if animate else 1.0
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())

	func _process(delta: float) -> void:
		_time += delta
		_reaction = minf(1.0, _reaction + delta)
		queue_redraw()  # Lv.1~3도 눈깜빡임·콧김이 실제로 움직인다.

	func _draw() -> void:
		var unit: float = minf(size.x, size.y) / 64.0
		var pop: float = sin(minf(_reaction / 0.42, 1.0) * PI) * exp(-_reaction * 5.0)
		var bob: float = sin(_time * (3.2 if level < 4 else 5.0)) * (0.7 if level < 4 else 1.1)
		var wobble: float = sin(_time * 14.0) * 0.024 if level == 5 else 0.0
		var stretch := Vector2(1.0 + pop * 0.11, 1.0 - pop * 0.09)
		draw_set_transform(size * 0.5 + Vector2(0, bob * unit), wobble, stretch * unit)
		var radius: float = 23.0
		if level == 5:
			for index: int in 3:
				var x: float = float(index - 1) * 15.0
				var base := Vector2(x, -16.0)
				var height: float = 15.0 + sin(_time * 7.0 + index) * 2.0
				draw_colored_polygon(FlameIcon.silhouette(base, 14.0, height), Color("f27c32"))
		# 굵은 외곽선과 단색 면. 캐릭터 일러스트처럼 디테일을 넣지 않는다.
		draw_circle(Vector2(0, 2), radius + 2.0, Color("b8764a"), true, -1.0, true)
		draw_circle(Vector2.ZERO, radius + 1.5, INK, true, -1.0, true)
		draw_circle(Vector2.ZERO, radius - 1.5, SKIN[level], true, -1.0, true)
		draw_arc(Vector2.ZERO, radius - 4.0, PI * 1.12, PI * 1.64, 16, SKIN[level].lightened(0.34), 2.0, true)
		var blink: bool = fmod(_time, 3.8) > 3.64
		var left := Vector2(-8.0, -3.0)
		var right := Vector2(8.0, -3.0)
		var mouth := Vector2(0, 8.0)
		for side: float in [-1.0, 1.0]:
			draw_circle(Vector2(side * 14.0, 5.0), 3.2, Color(0.94, 0.34, 0.3, 0.4))
		match level:
			1:
				for eye: Vector2 in [left, right]:
					if blink:
						_stroke(PackedVector2Array([eye + Vector2(-3, 0), eye + Vector2(3, 0)]), INK)
					else:
						_heart(eye, 4.0 + sin(_time * 3.2) * 0.25)
				_smile(mouth, 5.0)
			2:
				for eye: Vector2 in [left, right]:
					draw_arc(eye + Vector2(0, 2), 3.5, PI * 1.1, PI * 1.9, 12, INK, 2.8, true)
				_smile(mouth, 6.0)
			3:
				_stroke(PackedVector2Array([left + Vector2(-4, -5), left + Vector2(3, -2)]), INK)
				_stroke(PackedVector2Array([right + Vector2(-3, -2), right + Vector2(4, -5)]), INK)
				for eye: Vector2 in [left, right]:
					if blink:
						_stroke(PackedVector2Array([eye + Vector2(-2, 1), eye + Vector2(2, 1)]), INK)
					else:
						draw_circle(eye, 2.0, INK)
				_stroke(PackedVector2Array([mouth + Vector2(-4, 1), mouth + Vector2(4, 1)]), INK)
				for side: float in [-1.0, 1.0]:
					var breath: float = fmod(_time * 0.8 + (0.5 if side < 0 else 0.0), 1.0)
					var puff := Vector2(side * (23.0 + breath * 5.0), 7.0 - breath * 3.0)
					draw_circle(puff, 2.8 + breath * 1.5, Color(0.72, 0.75, 0.77, (1.0 - breath) * 0.7))
			4:
				_squeezed_eye(left, 1.0)
				_squeezed_eye(right, -1.0)
				draw_circle(mouth, 5.0 + sin(_time * 5.0) * 0.4, INK)
				draw_circle(mouth + Vector2(0, 2.5), 2.7, Color("f89593"))
				var drip: float = fmod(_time * 0.65, 1.0)
				_drop(Vector2(23, -8 + drip * 12), 3.0, 1.0 - smoothstep(0.7, 1.0, drip))
			5:
				for eye: Vector2 in [left, right]:
					_stroke(PackedVector2Array([eye + Vector2(-3, -3), eye + Vector2(3, 3)]), INK)
					_stroke(PackedVector2Array([eye + Vector2(-3, 3), eye + Vector2(3, -3)]), INK)
				draw_circle(mouth, 6.5, INK)
				_stroke(PackedVector2Array([mouth + Vector2(-3, 3), mouth + Vector2(3, 3)]), Color("f89593"), 3.5)
				_drop(Vector2(-23, -5 + sin(_time * 5.0) * 2.0), 2.8, 0.9)
		draw_set_transform(Vector2.ZERO)

	func _stroke(points: PackedVector2Array, color: Color, width: float = 2.8) -> void:
		draw_polyline(points, color, width, true)
		draw_circle(points[0], width * 0.5, color)
		draw_circle(points[-1], width * 0.5, color)

	func _smile(at: Vector2, radius: float) -> void:
		draw_arc(at + Vector2(0, -3), radius, PI * 0.12, PI * 0.88, 16, INK, 2.8, true)

	func _squeezed_eye(at: Vector2, side: float) -> void:
		_stroke(PackedVector2Array([at + Vector2(-side * 3, -3), at + Vector2(side * 2, 0), at + Vector2(-side * 3, 3)]), INK)

	func _heart(at: Vector2, unit: float) -> void:
		var color := Color("dc4965")
		draw_circle(at + Vector2(-unit * 0.46, -unit * 0.25), unit * 0.59, color)
		draw_circle(at + Vector2(unit * 0.46, -unit * 0.25), unit * 0.59, color)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-unit, 0), at + Vector2(unit, 0), at + Vector2(0, unit * 1.08)]), color)

	func _drop(at: Vector2, unit: float, opacity: float) -> void:
		var color := Color(0.29, 0.71, 0.85, opacity)
		draw_circle(at, unit, color)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-unit * 0.9, 0), at + Vector2(unit * 0.9, 0), at + Vector2(0, -unit * 2.0)]), color)


## 게이지 칸의 불꽃 (켜진 칸만 색이 있고, 단계가 높을수록 크게 일렁인다).
class FlameIcon:
	extends Control
	var lit: bool = false
	var step: int = 1
	var _time: float = 0.0

	func setup(is_lit: bool, value: int) -> void:
		lit = is_lit
		step = value
		queue_redraw()

	func _process(delta: float) -> void:
		if lit:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		if size.x < 4.0 or size.y < 4.0:
			return
		var base := Vector2(size.x * 0.5, size.y - 2.0)
		var height: float = size.y * (0.6 + 0.08 * step) * (1.0 + (0.08 * sin(_time * 9.0 + step) if lit else 0.0))
		var width: float = height * 0.55
		var outer: Color = Color("ff5a1f") if lit else Color("b9b7c9")
		var inner: Color = Color("ffe066") if lit else Color("e7e6f0")
		draw_colored_polygon(silhouette(base, width, height), outer)
		draw_colored_polygon(silhouette(base, width * 0.55, height * 0.6), inner)

	## 물방울꼴 불꽃: 아래는 둥근 반원, 위는 뾰족한 끝.
	static func silhouette(base: Vector2, width: float, height: float) -> PackedVector2Array:
		var curve := Curve2D.new()
		curve.add_point(Vector2(-0.42, -0.13), Vector2.ZERO, Vector2(-0.18, -0.23))
		curve.add_point(Vector2(-0.13, -0.69), Vector2(-0.09, 0.20), Vector2(0.10, 0.12))
		curve.add_point(Vector2(0.03, -0.53), Vector2(-0.02, -0.03), Vector2(0.12, -0.12))
		curve.add_point(Vector2(0.15, -1.0), Vector2(-0.06, 0.15), Vector2(0.06, 0.23))
		curve.add_point(Vector2(0.47, -0.25), Vector2(0.05, -0.20), Vector2(-0.01, 0.34))
		curve.add_point(Vector2(-0.42, -0.13), Vector2(0.14, 0.23))
		var points := curve.tessellate(3, 4.0)
		points.remove_at(points.size() - 1)  # 끝점 중복은 삼각형 분할을 불안정하게 한다.
		for index: int in points.size():
			points[index] = base + points[index] * Vector2(width, height)
		return points

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())


## 소스가 면에 입혀지는 볶음라면. 김·재료는 그릇 근처에만, 고난도 불꽃은 뒤쪽에만 그린다.
class RamenBowl:
	extends Control
	const BOWL: Color = Color("3c3942")
	const OUTLINE: Color = Color("53433b")
	var level: int = 1
	var sauce: Color = FireLevelPicker.SAUCE[1]
	var pour: float = 0.0
	var _time: float = 0.0
	var _reaction: float = 1.0
	var _shown_sauce: Color = FireLevelPicker.SAUCE[1]
	var _previous_sauce: Color = FireLevelPicker.SAUCE[1]
	var _particles: CPUParticles2D = null
	var _noodles: Array[PackedVector2Array] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_noodles()
		_particles = CPUParticles2D.new()
		_particles.name = "SauceParticles"
		_particles.local_coords = true
		_particles.seed = 52
		_particles.use_fixed_seed = true
		add_child(_particles)

	func set_level(value: int, animate: bool) -> void:
		level = BotTemper.sanitize(value)
		sauce = FireLevelPicker.SAUCE[level]
		_previous_sauce = _shown_sauce
		_reaction = 0.0 if animate else 1.0
		if not animate:
			_shown_sauce = sauce
		pour = 0.0 if animate or level < 5 else 1.0
		_configure_particles()
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		_reaction = minf(1.0, _reaction + delta)
		var span: Vector2 = pour_span()
		pour = span.y - span.x
		_shown_sauce = _previous_sauce.lerp(sauce, smoothstep(0.22, 0.72, _reaction))
		_particles.emitting = is_visible_in_tree() and (level == 5 or _reaction < 0.58)
		queue_redraw()

	## x는 줄기의 뒷끝, y는 앞끝. 둘 다 아래로만 이동한다.
	## 공급을 끊으면 아래 끝을 끌어올리지 않고 위 끝부터 면 쪽으로 떨어뜨린다.
	func pour_span() -> Vector2:
		var front: float = clampf(_reaction / 0.22, 0.0, 1.0)
		var tail: float = 0.0 if level == 5 else clampf((_reaction - 0.52) / 0.22, 0.0, 1.0)
		return Vector2(tail, front)

	func _build_noodles() -> void:
		# 긴 면 한 가닥이 여러 번 되돌아 감긴다. 끝은 아래층에 묻고 위쪽 고리로 덮는다.
		for strand: int in 15:
			var line := PackedVector2Array()
			var phase: float = strand * 1.87
			var rotation_angle: float = strand * 0.79
			for index: int in 145:
				var t: float = float(index) / 144.0
				var angle: float = t * TAU * (2.4 + (strand % 3) * 0.19) + phase
				var u: float = lerpf(-0.64, 0.64, t) + sin(angle) * 0.23 + sin(angle * 2.3 + phase) * 0.024
				var v: float = (strand - 7) * 0.032 + cos(angle) * 0.24 + sin(angle * 3.1) * 0.045
				# 그릇 평면에서 서로 다른 방향으로 얽힌 후 타원 원근을 적용한다.
				var point: Vector2 = Vector2(u, v).rotated(rotation_angle)
				line.append(point * Vector2(109, 31) + Vector2(0, -4))
			_noodles.append(line)

	func shake_offset() -> Vector2:
		if level != 5:
			return Vector2.ZERO
		return Vector2(sin(_time * 17.0) * 0.75, sin(_time * 13.0) * 0.4)

	func _art_scale() -> float:
		return minf(1.0, minf(size.x / 540.0, size.y / 116.0))

	func _rim() -> Rect2:
		var art_scale: float = _art_scale()
		return Rect2(Vector2(size.x * 0.5 - 120.0 * art_scale, 42.0 * art_scale), Vector2(240, 40) * art_scale)

	func _draw() -> void:
		var art_scale: float = _art_scale()
		if art_scale <= 0.0:
			return
		draw_set_transform(Vector2(size.x * 0.5 - 270.0 * art_scale, 0) + shake_offset(), 0.0, Vector2.ONE * art_scale)
		var center := Vector2(270, 62)
		_ellipse(Vector2(270, 111), Vector2(100, 4), Color(0.3, 0.23, 0.2, 0.09))
		# Lv.4는 열기만, Lv.5는 뒤로 작은 불길. 그릇과 얼굴을 가리지 않는다.
		if level == 5:
			for index: int in 7:
				var base := center + Vector2((index - 3) * 25, -5)
				var height: float = 24.0 + sin(_time * 6.0 + index * 1.7) * 7.0
				draw_colored_polygon(FlameIcon.silhouette(base, 22, height), Color("f59a3a"))
				draw_colored_polygon(FlameIcon.silhouette(base, 10, height * 0.6), Color("ffd36b"))
		# 얕은 도자기 그릇. 가장자리 안쪽은 국물 없이 면의 덩어리로 채운다.
		var body := PackedVector2Array([center + Vector2(-120, 0), center + Vector2(120, 0)])
		for index: int in 33:
			var angle: float = float(index) / 32.0 * PI
			body.append(center + Vector2(cos(angle) * 120, sin(angle) * 44))
		draw_colored_polygon(body, OUTLINE)
		var inner := PackedVector2Array([center + Vector2(-116, 1), center + Vector2(116, 1)])
		for index: int in 33:
			var angle: float = float(index) / 32.0 * PI
			inner.append(center + Vector2(cos(angle) * 116, 1 + sin(angle) * 39))
		draw_colored_polygon(inner, BOWL)
		var stripe := PackedVector2Array()
		for index: int in 27:
			var angle: float = PI * 0.12 + PI * 0.76 * float(index) / 26.0
			stripe.append(center + Vector2(cos(angle) * 109, 4 + sin(angle) * 23))
		draw_polyline(stripe, Color("d87560"), 4.0, true)
		_ellipse(center + Vector2(0, 42), Vector2(35, 4), OUTLINE)
		_ellipse(center, Vector2(120, 20), Color("f9ecd2"))
		_ellipse(center + Vector2(0, -2), Vector2(112, 16), _shown_sauce.darkened(0.35))
		_ellipse(center + Vector2(0, -7), Vector2(99, 23), _shown_sauce.darkened(0.15))
		_draw_noodles(center + Vector2(0, -5))
		for index: int in 9:
			var at := center + Vector2(sin(index * 2.1) * 78.0, -9.0 + cos(index * 3.5) * 14.0)
			draw_line(at, at + Vector2(2.5, -1.5), Color("fff0bd"), 1.8, true)
		for index: int in 4:
			var at := center + Vector2(sin(index * 2.3 + 0.3) * 71.0, -9 + cos(index * 1.6) * 12.0)
			draw_line(at, at + Vector2(6, -3), Color("648348"), 3.0, true)
		_draw_steam(center)
		if pour > 0.01:
			_draw_pour(center)
		draw_set_transform(Vector2.ZERO)

	func _draw_noodles(center: Vector2) -> void:
		for strand: int in _noodles.size():
			var line := PackedVector2Array()
			var sheen := PackedVector2Array()
			for point: Vector2 in _noodles[strand]:
				line.append(center + point)
				sheen.append(center + point + Vector2(0, -0.7))
			var noodle: Color = _shown_sauce.lightened(0.12 + (strand % 3) * 0.035)
			draw_polyline(line, _shown_sauce.darkened(0.33), 7.4, true)
			draw_polyline(line, noodle, 5.4, true)
			draw_polyline(sheen, noodle.lightened(0.18), 1.5, true)
			# 끝마저 둥글게 닫아 잘린 사각 조각처럼 보이지 않게 한다.
			for endpoint: Vector2 in [line[0], line[-1]]:
				draw_circle(endpoint, 2.7, noodle, true, -1.0, true)

	func _draw_steam(center: Vector2) -> void:
		for index: int in (2 if level <= 2 else 3):
			var phase: float = fmod(_time * (0.32 + level * 0.045) + index * 0.34, 1.0)
			var line := PackedVector2Array()
			for step: int in 13:
				var t: float = float(step) / 12.0
				var at := center + Vector2((index - 1) * 45.0 + sin(t * TAU + _time * 1.5 + index) * 3.0, -24.0 - phase * 12.0 - t * (13.0 + level * 2.0))
				line.append(at)
			var opacity: float = sin(phase * PI) * (0.2 + level * 0.035)
			draw_polyline(line, Color(0.7, 0.57, 0.46, opacity), 2.4, true)

	func _draw_pour(center: Vector2) -> void:
		var x: float = center.x + 19.0
		var span: Vector2 = pour_span()
		var source_y: float = 4.0
		var hit_y: float = center.y - 9.0
		var top: float = lerpf(source_y, hit_y, span.x)
		var bottom: float = lerpf(source_y, hit_y, span.y)
		var line := PackedVector2Array()
		for index: int in 19:
			var y: float = lerpf(top, bottom, float(index) / 18.0)
			# 아래로 이동하는 잔물결. 위로 흔들리는 긴 면발처럼 보이지 않게 폭을 억제한다.
			line.append(Vector2(x + sin(y * 0.16 - _time * 27.0) * 0.6, y))
		var width: float = 10.0 if level == 5 else 6.0
		draw_polyline(line, sauce.darkened(0.15), width + 1.0, true)
		draw_polyline(line, sauce, width - 1.0, true)
		draw_circle(line[-1], width * 0.5, sauce, true, -1.0, true)
		if span.x > 0.0:
			draw_circle(line[0], width * 0.5, sauce, true, -1.0, true)
		# 소스 안의 짧은 윤기도 아래로만 지나간다.
		for index: int in 3:
			var y: float = source_y + fmod(_time * 150.0 + index * 18.0, hit_y - source_y)
			if y >= top and y + 4.0 <= bottom:
				draw_line(Vector2(x - 1.0, y), Vector2(x - 1.0, y + 4.0), sauce.lightened(0.25), 1.7, true)
		if span.y >= 1.0:
			var spread: float = smoothstep(0.22, 0.5, _reaction)
			_ellipse(Vector2(x, hit_y), Vector2(9.0 + spread * 9.0, 3), Color(sauce, 0.7))
			for side: float in [-1.0, 1.0]:
				var phase: float = fmod(_time * 3.0 + (0.5 if side < 0 else 0.0), 1.0)
				draw_circle(Vector2(x + side * (8.0 + phase * 15.0), hit_y - sin(phase * PI) * 8.0), 1.7 * (1.0 - phase), sauce, true, -1.0, true)

	func _ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index: int in 48:
			var angle: float = TAU * float(index) / 48.0
			points.append(at + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		draw_colored_polygon(points, color)

	func _configure_particles() -> void:
		if _particles == null:
			return
		var rim: Rect2 = _rim()
		var p: CPUParticles2D = _particles
		p.emitting = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.position = Vector2(size.x * 0.5, 24.0 * _art_scale())
		p.emission_rect_extents = Vector2(rim.size.x * 0.28, 1)
		p.amount = 8
		p.lifetime = 0.45
		p.direction = Vector2.DOWN
		p.spread = 12.0
		p.gravity = Vector2(0, 26)
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 15.0
		p.scale_amount_min = 1.4
		p.scale_amount_max = 2.2
		p.angular_velocity_min = -60.0
		p.angular_velocity_max = 60.0
		p.color = Color("fff0bd") if level <= 2 else Color("68804a")
		p.emitting = is_visible_in_tree() and (level == 5 or _reaction < 0.58)
		p.restart()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_configure_particles()
		elif what == NOTIFICATION_VISIBILITY_CHANGED:
			var active: bool = is_visible_in_tree()
			set_process(active)
			if _particles != null:
				_particles.emitting = active and (level == 5 or _reaction < 0.58)
