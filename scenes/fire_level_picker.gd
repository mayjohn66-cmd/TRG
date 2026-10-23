# File: res://scenes/fire_level_picker.gd
# Class: class_name FireLevelPicker
# Role: 놀이터 난이도 고르기 = 불닭 매운맛 지표 Fire Level 1~5. 위에는 표정이 바뀌는 사도 얼굴 + 1~5칸 불꽃 게이지(칸을 누르면 그 단계),
#       가운데에는 라면 그릇: 단계를 바꾸면 위에서 그 단계 소스가 쏟아지고(Tween) 국물·면발 색이 바로 바뀌며 단계별 파티클(CPUParticles2D)이 날린다.
#       Lv.1 크림 소스 + 치즈 가루, Lv.2 로제 + 반짝이, Lv.3 빨간 액상스프 + 김가루, Lv.4 마라유 + 보라 스파크·산초, Lv.5 핵불닭 용암 소스 폭포 + 화염 + 그릇 상시 떨림.
#       아래에는 단계 설명(흐르는 글). 글은 원문 한국어로 두고 화면에서 번역된다. AI 수치는 BotTemper.LEVELS가 맡는다.
class_name FireLevelPicker
extends VBoxContainer

signal level_chosen(level: int)

## 단계별 소스 색.
const SAUCE: Dictionary = {1: Color("FFD1DC"), 2: Color("FF9E7A"), 3: Color("E62E2D"), 4: Color("9E1B32"), 5: Color("FF0033")}
## 게이지 칸 색 (1칸부터 차오른다).
const CELL: Dictionary = {1: Color("ffd36b"), 2: Color("ffa04a"), 3: Color("f2552c"), 4: Color("b3123a"), 5: Color("ff0033")}
const CELL_EMPTY: Color = Color("dcdbe8")
const NOTES: Dictionary = {
	1: "크림: 컴퓨터가 70% 확률로 내 말을 봐주고, 나를 노리는 공격 카드도 거의 안 써요",
	2: "로제: 가끔(35%) 봐주고, 내가 1등일 때만 견제해요. 평소엔 컴퓨터끼리 싸워요",
	3: "오리지널: 봐주기 없는 공정한 승부! 지금 1등을 가장 먼저 견제해요",
	4: "마라: 봐주기 없이 공격 카드·함정·필살기를 아낌없이 써요 (킬각 최우선)",
	5: "핵불닭: 공식 억까 모드! 컴퓨터 3명이 나를 2배로 집요하게 노려요",
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


## 사도 얼굴 아이콘: 단계별 표정 (😍 → 😊 → 😤 → 🥵 → 🤯). 게임 글꼴에 이모지가 없어 직접 그린다.
class FireFace:
	extends Control
	const SKIN: Dictionary = {1: Color("ffe3b0"), 2: Color("ffd29a"), 3: Color("ffb27a"), 4: Color("ff7b5c"), 5: Color("ff4040")}
	const INK: Color = Color("3a1f12")
	var level: int = 1
	var _bounce: float = 1.0
	var _time: float = 0.0

	func set_level(value: int, animate: bool) -> void:
		level = value
		if animate and is_inside_tree():
			var tween: Tween = create_tween()
			_bounce = 1.3
			tween.tween_property(self, "_bounce", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_callback(queue_redraw)
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		if level >= 4 or _bounce != 1.0:
			queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.4 * _bounce
		if level == 5:
			# 머리 위 폭발
			var burst := PackedVector2Array()
			for index: int in 16:
				var angle: float = -PI + PI * float(index) / 15.0
				var reach: float = radius * (1.55 if index % 2 == 0 else 1.15) * (1.0 + 0.06 * sin(_time * 18.0 + index))
				burst.append(center + Vector2(cos(angle), sin(angle)) * reach)
			burst.append(center + Vector2(radius, 0))
			burst.append(center + Vector2(-radius, 0))
			draw_colored_polygon(burst, Color("ffb000"))
		var shake: Vector2 = Vector2(sin(_time * 50.0), cos(_time * 43.0)) * (1.2 if level == 5 else 0.0)
		center += shake
		draw_circle(center, radius, SKIN[level])
		draw_arc(center, radius, 0, TAU, 40, INK, 2.0, true)
		var eye_l: Vector2 = center + Vector2(-radius * 0.38, -radius * 0.15)
		var eye_r: Vector2 = center + Vector2(radius * 0.38, -radius * 0.15)
		var mouth: Vector2 = center + Vector2(0, radius * 0.38)
		match level:
			1:
				_heart(eye_l, radius * 0.22, Color("ff3e7f"))
				_heart(eye_r, radius * 0.22, Color("ff3e7f"))
				draw_arc(mouth + Vector2(0, -radius * 0.12), radius * 0.3, 0.15 * PI, 0.85 * PI, 12, INK, 2.5, true)
			2:
				draw_arc(eye_l + Vector2(0, radius * 0.08), radius * 0.15, PI * 1.1, PI * 1.9, 8, INK, 2.5, true)
				draw_arc(eye_r + Vector2(0, radius * 0.08), radius * 0.15, PI * 1.1, PI * 1.9, 8, INK, 2.5, true)
				draw_circle(eye_l + Vector2(-radius * 0.08, radius * 0.38), radius * 0.13, Color(1, 0.45, 0.55, 0.6))
				draw_circle(eye_r + Vector2(radius * 0.08, radius * 0.38), radius * 0.13, Color(1, 0.45, 0.55, 0.6))
				draw_arc(mouth + Vector2(0, -radius * 0.15), radius * 0.28, 0.1 * PI, 0.9 * PI, 12, INK, 2.5, true)
			3:
				draw_line(eye_l + Vector2(-radius * 0.2, -radius * 0.28), eye_l + Vector2(radius * 0.18, -radius * 0.12), INK, 3.0, true)
				draw_line(eye_r + Vector2(radius * 0.2, -radius * 0.28), eye_r + Vector2(-radius * 0.18, -radius * 0.12), INK, 3.0, true)
				draw_circle(eye_l, radius * 0.08, INK)
				draw_circle(eye_r, radius * 0.08, INK)
				draw_line(mouth + Vector2(-radius * 0.22, 0), mouth + Vector2(radius * 0.22, 0), INK, 2.5, true)
				var puff: float = 0.5 + 0.5 * sin(_time * 6.0)
				draw_circle(center + Vector2(-radius * 1.08, radius * 0.25), radius * (0.12 + 0.05 * puff), Color(1, 1, 1, 0.85))
				draw_circle(center + Vector2(radius * 1.08, radius * 0.25), radius * (0.12 + 0.05 * (1.0 - puff)), Color(1, 1, 1, 0.85))
			4:
				for eye: Vector2 in [eye_l, eye_r]:
					var flip: float = -1.0 if eye == eye_l else 1.0
					draw_line(eye + Vector2(-radius * 0.14 * flip, -radius * 0.1), eye + Vector2(radius * 0.1 * flip, 0), INK, 2.5, true)
					draw_line(eye + Vector2(radius * 0.1 * flip, 0), eye + Vector2(-radius * 0.14 * flip, radius * 0.1), INK, 2.5, true)
				draw_circle(mouth, radius * 0.22, Color("6b0f0f"))
				draw_circle(mouth + Vector2(0, radius * 0.12), radius * 0.13, Color("ff8fa3"))
				var drip: float = fmod(_time * 0.8, 1.0)
				_drop(center + Vector2(radius * 0.95, -radius * 0.3 + radius * 0.5 * drip), radius * 0.16)
				_drop(center + Vector2(-radius * 0.9, -radius * 0.5 + radius * 0.4 * fmod(drip + 0.5, 1.0)), radius * 0.12)
			5:
				for eye: Vector2 in [eye_l, eye_r]:
					var spiral := PackedVector2Array()
					for step: int in 18:
						var t: float = float(step) / 17.0
						var angle: float = t * TAU * 2.0 + _time * 8.0
						spiral.append(eye + Vector2(cos(angle), sin(angle)) * radius * 0.2 * t)
					draw_polyline(spiral, INK, 2.0, true)
				draw_circle(mouth + Vector2(0, radius * 0.04), radius * 0.28, Color("4a0606"))

	func _heart(at: Vector2, unit: float, color: Color) -> void:
		draw_circle(at + Vector2(-unit * 0.5, -unit * 0.2), unit * 0.55, color)
		draw_circle(at + Vector2(unit * 0.5, -unit * 0.2), unit * 0.55, color)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-unit * 1.02, 0), at + Vector2(unit * 1.02, 0), at + Vector2(0, unit * 1.1)]), color)

	func _drop(at: Vector2, unit: float) -> void:
		draw_circle(at, unit, Color("6cc6ff"))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-unit * 0.9, -unit * 0.3), at + Vector2(unit * 0.9, -unit * 0.3), at + Vector2(0, -unit * 2.0)]), Color("6cc6ff"))


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
		draw_colored_polygon(_flame(base, width, height), outer)
		draw_colored_polygon(_flame(base, width * 0.55, height * 0.6), inner)

	## 물방울꼴 불꽃: 아래는 둥근 반원, 위는 뾰족한 끝.
	func _flame(base: Vector2, width: float, height: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var round_center: Vector2 = base - Vector2(0, width * 0.45)
		for index: int in 13:
			var angle: float = PI * float(index) / 12.0
			points.append(round_center + Vector2(cos(angle) * width * 0.5, sin(angle) * width * 0.45))
		points.append(base + Vector2(0, -height))
		return points


## 라면 그릇: 소스 줄기·국물·면발·파티클·떨림.
class RamenBowl:
	extends Control
	const NOODLE: Color = Color("f3d27a")
	const BOWL: Color = Color("2b2326")
	const BAND: Color = Color("e62e2d")
	var level: int = 1
	var sauce: Color = Color("FFD1DC")
	## 소스 줄기가 내려온 정도 (0 없음 ~ 1 그릇까지).
	var pour: float = 0.0
	var _time: float = 0.0
	var _particles: CPUParticles2D = null
	var _tween: Tween = null

	func _init() -> void:
		clip_contents = false
		_particles = CPUParticles2D.new()
		_particles.name = "SauceParticles"
		_particles.local_coords = true
		add_child(_particles)

	func set_level(value: int, animate: bool) -> void:
		level = value
		sauce = FireLevelPicker.SAUCE[level]  # 국물·면발·줄기 색은 바로 바뀐다
		_configure_particles()
		if _tween != null:
			_tween.kill()
		if animate and is_inside_tree():
			pour = 0.0
			_tween = create_tween()
			_tween.tween_property(self, "pour", 1.0, 0.3).set_ease(Tween.EASE_IN)
			if level < 5:
				_tween.tween_interval(0.25)
				_tween.tween_property(self, "pour", 0.0, 0.3).set_ease(Tween.EASE_OUT)
		else:
			pour = 1.0 if level == 5 else 0.0  # 핵불닭은 소스 폭포가 계속 쏟아진다
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func shake_offset() -> Vector2:
		if level != 5:
			return Vector2.ZERO
		return Vector2(sin(_time * 61.0) * 2.2, cos(_time * 47.0) * 1.4)

	func _rim() -> Rect2:
		var rim_width: float = minf(250.0, size.x * 0.5)
		return Rect2(Vector2(size.x * 0.5 - rim_width * 0.5, size.y - 58.0), Vector2(rim_width, 22.0))

	func _draw() -> void:
		var shake: Vector2 = shake_offset()
		draw_set_transform(shake)
		var rim: Rect2 = _rim()
		var center: Vector2 = rim.get_center()
		# 소스 줄기 (위에서 국물까지)
		if pour > 0.01:
			var stream_width: float = 26.0 if level == 5 else 9.0
			var bottom: float = lerpf(0.0, center.y, pour)
			var x: float = center.x + 14.0
			var wobble: float = sin(_time * 20.0) * (3.0 if level == 5 else 1.0)
			draw_rect(Rect2(Vector2(x - stream_width * 0.5 + wobble, 0), Vector2(stream_width, bottom)), sauce)
			draw_rect(Rect2(Vector2(x - stream_width * 0.18 + wobble, 0), Vector2(stream_width * 0.2, bottom)), sauce.lightened(0.35))
			if pour > 0.95:
				draw_circle(Vector2(x, center.y), stream_width * 0.9 + 3.0 * sin(_time * 25.0), sauce.lightened(0.15))
		# 그릇 몸통 (반타원) + 띠
		var body := PackedVector2Array()
		for index: int in 25:
			var angle: float = PI * float(index) / 24.0
			body.append(center + Vector2(cos(angle) * rim.size.x * 0.5, sin(angle) * 50.0))
		draw_colored_polygon(body, BOWL)
		var band := PackedVector2Array()
		for index: int in 25:
			var angle: float = PI * float(index) / 24.0
			band.append(center + Vector2(cos(angle) * rim.size.x * 0.47, 14.0 + sin(angle) * 18.0))
		draw_polyline(band, BAND, 5.0, true)
		draw_rect(Rect2(center + Vector2(-36, 46), Vector2(72, 8)), BOWL.lightened(0.15))
		# 국물 (타원) + 면발
		_ellipse(center, rim.size * 0.5, BOWL.lightened(0.25))
		_ellipse(center + Vector2(0, 1), rim.size * 0.5 - Vector2(6, 3), sauce.darkened(0.08))
		var noodle: Color = NOODLE.lerp(sauce, 0.55)
		for row: int in 4:
			var line := PackedVector2Array()
			var y: float = center.y - 5.0 + row * 3.5
			for step: int in 21:
				var t: float = float(step) / 20.0
				var x2: float = rim.position.x + 22.0 + t * (rim.size.x - 44.0)
				line.append(Vector2(x2, y + sin(t * TAU * 3.0 + row + _time * (6.0 if level == 5 else 1.5)) * 2.6))
			draw_polyline(line, noodle, 3.0, true)
		draw_set_transform(Vector2.ZERO)

	func _ellipse(at: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index: int in 32:
			var angle: float = TAU * float(index) / 32.0
			points.append(at + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		draw_colored_polygon(points, color)

	## 단계별 파티클: 크림 치즈 가루, 로제 반짝이, 오리지널 김가루, 마라 보라 스파크·산초, 핵불닭 화염.
	func _configure_particles() -> void:
		var rim: Rect2 = _rim() if size.x > 0.0 else Rect2(Vector2(170, 54), Vector2(220, 22))
		var p: CPUParticles2D = _particles
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.color_ramp = null
		p.color_initial_ramp = null
		p.scale_amount_curve = null
		p.direction = Vector2(0, -1)
		p.spread = 30.0
		p.angular_velocity_min = 0.0
		p.angular_velocity_max = 0.0
		match level:
			1:  # 치즈 가루: 위에서 솔솔 뿌려진다
				p.position = Vector2(rim.get_center().x, 6)
				p.emission_rect_extents = Vector2(rim.size.x * 0.35, 2)
				p.amount = 22
				p.lifetime = 1.1
				p.gravity = Vector2(0, 70)
				p.initial_velocity_min = 0.0
				p.initial_velocity_max = 10.0
				p.scale_amount_min = 2.5
				p.scale_amount_max = 4.0
				p.color = Color("ffe27a")
			2:  # 반짝이: 그릇 둘레에서 반짝
				p.position = rim.get_center() + Vector2(0, -16)
				p.emission_rect_extents = Vector2(rim.size.x * 0.6, 24)
				p.amount = 16
				p.lifetime = 0.9
				p.gravity = Vector2.ZERO
				p.initial_velocity_min = 0.0
				p.initial_velocity_max = 6.0
				p.scale_amount_min = 2.0
				p.scale_amount_max = 5.0
				p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 0.95, 0.85, 1), Color(1, 0.8, 0.7, 0)])
			3:  # 김가루: 검푸른 조각이 팔랑팔랑
				p.position = Vector2(rim.get_center().x, 6)
				p.emission_rect_extents = Vector2(rim.size.x * 0.3, 2)
				p.amount = 18
				p.lifetime = 1.2
				p.gravity = Vector2(0, 55)
				p.initial_velocity_min = 5.0
				p.initial_velocity_max = 20.0
				p.spread = 180.0
				p.angular_velocity_min = -200.0
				p.angular_velocity_max = 200.0
				p.scale_amount_min = 3.0
				p.scale_amount_max = 5.0
				p.color = Color("1d3324")
			4:  # 얼얼한 보라 스파크 + 산초 알갱이
				p.position = rim.get_center()
				p.emission_rect_extents = Vector2(rim.size.x * 0.4, 4)
				p.amount = 30
				p.lifetime = 0.7
				p.gravity = Vector2(0, 90)
				p.initial_velocity_min = 50.0
				p.initial_velocity_max = 110.0
				p.spread = 55.0
				p.scale_amount_min = 2.0
				p.scale_amount_max = 4.0
				p.color = Color.WHITE
				p.color_initial_ramp = _ramp([Color("b45cff"), Color("e3b6ff"), Color("6b3b1f")])
			5:  # 타오르는 화염
				p.position = rim.get_center()
				p.emission_rect_extents = Vector2(rim.size.x * 0.42, 4)
				p.amount = 46
				p.lifetime = 0.8
				p.gravity = Vector2(0, -60)
				p.initial_velocity_min = 25.0
				p.initial_velocity_max = 70.0
				p.spread = 20.0
				p.scale_amount_min = 4.0
				p.scale_amount_max = 9.0
				p.color = Color.WHITE
				p.color_ramp = _ramp([Color("fff27a"), Color("ff7a1a"), Color(1, 0, 0.2, 0)])
		p.emitting = true
		p.restart()

	func _ramp(colors: Array) -> Gradient:
		var gradient := Gradient.new()
		var offsets := PackedFloat32Array()
		var points := PackedColorArray()
		for index: int in colors.size():
			offsets.append(float(index) / float(colors.size() - 1))
			points.append(colors[index])
		gradient.offsets = offsets
		gradient.colors = points
		return gradient

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_configure_particles()
