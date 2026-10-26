# File: res://scenes/fire_level_picker.gd
# Class: class_name FireLevelPicker
# Role: 놀이터 난이도 고르기 = 불닭 매운맛 지표 Fire Level 1~5. 위에는 표정이 바뀌는 사도 얼굴 + 1~5칸 불꽃 게이지(칸을 누르면 그 단계),
#       가운데에는 실제 3D 그릇 안에 담긴 볶음면: 소스가 떨어지면 면에 색이 입혀지고, 단계가 높아질수록 김이 강해진다.
#       얼굴은 굵은 선의 표정 아이콘. 한 개의 반응 시계만 써서 연속 선택에도 모션이 쌓이지 않고, 숨긴 화면은 애니메이션을 멈춘다.
#       아래에는 단계 설명(흐르는 글). 글은 원문 한국어로 두고 화면에서 번역된다. AI 수치는 BotTemper.LEVELS가 맡는다.
class_name FireLevelPicker
extends VBoxContainer

signal level_chosen(level: int)

## 단계별 소스 색은 3D 면발·소스와 같은 팔레트를 쓴다.
const SAUCE: Dictionary = preload("res://scenes/ramen_bowl_view.gd").COLORS
## 게이지 칸 색 (1칸부터 차오른다).
const CELL: Dictionary = {1: Color("ffd36b"), 2: Color("ffa04a"), 3: Color("f2552c"), 4: Color("b3123a"), 5: Color("ff0033")}
const CELL_EMPTY: Color = Color("dcdbe8")
## 단계 설명: 이름·수치 없이 어떤 느낌인지만 (수치는 BotTemper.LEVELS).
const NOTES: Dictionary = {
	1: "입문 추천! 특수 승리 없이 말 4개 완주로만 승부합니다",
	2: "가볍게 즐기기 좋아요. 내가 앞서 나갈 때만 견제해요",
	3: "봐주기 없는 정정당당한 승부! 1등을 먼저 노려요",
	4: "컴퓨터가 카드·함정·필살기를 아낌없이 써요",
	5: "공식 억까 모드! 컴퓨터들이 나만 집요하게 노려요",
}
const CELL_SIZE: Vector2 = Vector2(88, 80)
const BOWL_SIZE: Vector2 = Vector2(540, 154)
const RECORD_HEIGHT: float = 30.0

var level: int = BotTemper.DEFAULT_LEVEL
var _face: FireFace = null
var _cells: Dictionary = {}
## 단계별 정복 표시 (황금 왕관 / 회색 자물쇠)와 고른 단계의 전적 줄.
var _crowns: Dictionary = {}
var _record_icon: MetaIcon = null
var _record_label: Label = null
var _conquer_label: Label = null
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
		var crown: MetaIcon = MetaIcon.create(&"lock", Vector2(20, 17))
		crown.name = "Crown"
		crown.position = Vector2(CELL_SIZE.x - 25.0, 5.0)
		cell.add_child(crown)
		_crowns[step] = crown
	# 고른 단계의 전적: [왕관] 클리어! 최고: N라운드 · 정복 M/5 / [자물쇠] 미정복 (영구 기록 PlayerSave)
	var record := HBoxContainer.new()
	record.name = "DifficultyRecord"
	record.alignment = BoxContainer.ALIGNMENT_CENTER
	record.add_theme_constant_override("separation", 6)
	record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record.custom_minimum_size = Vector2(0, RECORD_HEIGHT)  # 글꼴(언어)마다 줄 높이가 달라도 칸 높이는 그대로
	add_child(record)
	_record_icon = MetaIcon.create(&"lock", Vector2(22, 19))
	_record_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	record.add_child(_record_icon)
	_record_label = Label.new()
	_record_label.name = "RecordText"
	_record_label.add_theme_font_size_override("font_size", 16)
	_record_label.add_theme_color_override("font_color", Color("6b3d05"))
	_record_label.custom_minimum_size = Vector2(0, RECORD_HEIGHT)
	_record_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record.add_child(_record_label)
	_conquer_label = Label.new()
	_conquer_label.name = "ConquerCount"
	_conquer_label.add_theme_font_size_override("font_size", 14)
	_conquer_label.add_theme_color_override("font_color", Color("8a6a3a"))
	_conquer_label.custom_minimum_size = Vector2(0, RECORD_HEIGHT)
	_conquer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record.add_child(_conquer_label)
	_bowl = RamenBowl.new()
	_bowl.name = "RamenBowl"
	_bowl.custom_minimum_size = BOWL_SIZE
	_bowl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bowl)
	_note = MarqueeLabel.create("", 17, LobbyTheme.BLUE, Vector2(540, 26), HORIZONTAL_ALIGNMENT_CENTER, "DifficultyNote")
	add_child(_note)


## 그릇의 3D 셰이더를 미리 컴파일한다 (화면에 보이기 전에 한 번 그린다).
func prewarm() -> void:
	if _bowl != null:
		_bowl.prewarm()


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
	refresh_records()


## 영구 기록의 정복 표시를 다시 그린다 (판이 끝나 메뉴로 돌아오면 새 기록이 보인다).
func refresh_records() -> void:
	var conquered: int = 0
	for step: int in _crowns:
		var cleared: bool = PlayerSave.buldak_cleared(step)
		(_crowns[step] as MetaIcon).set_kind(&"crown" if cleared else &"lock")
		if cleared:
			conquered += 1
	if _record_label == null:
		return
	var record: Dictionary = PlayerSave.buldak_record(level)
	var cleared_now: bool = int(record.get("clears", 0)) > 0
	_record_icon.set_kind(&"crown" if cleared_now else &"lock")
	# 원문 한국어를 넣으면 화면에서 번역된다 (언어를 바꿔도 따라 바뀐다)
	var best: int = int(record.get("best_round", 0))
	if not cleared_now:
		_record_label.text = "미정복"
	elif best > 0:
		_record_label.text = "클리어! 최고: %d라운드" % best
	else:
		_record_label.text = "클리어!"  # 짧은 코드·링크로 옮긴 기록에는 최단 라운드가 없다"
	_conquer_label.text = "· 정복 %d/5" % conquered


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


## 실제 3D 그릇·면발. 기존 선택·소스 시간 API는 동일하게 유지한다.
class RamenBowl:
	extends "res://scenes/ramen_bowl_view.gd"
