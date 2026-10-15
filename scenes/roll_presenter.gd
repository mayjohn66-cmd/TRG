# File: res://scenes/roll_presenter.gd
# Class: class_name RollPresenter
# Role: 판정 도구 결과 연출기. 엔진이 이미 확정한 결과(RollResult.to_dict())를 받아 주사위 셔플·윷 던지기·룰렛 감속 회전·슬롯 3릴 순차 정지·홀덤 카드 플립으로 보여 준다. 연출만 담당하며 결과는 절대 바꾸지 않는다
class_name RollPresenter
extends PanelContainer

## 연출이 끝났다 (취소 포함). play()는 이 시그널을 await 한다.
signal finished

const SUPPORTED: Array[StringName] = [&"D6", &"CHINCHIRO", &"YUT", &"LIFE_ROULETTE", &"SLOT_777", &"HOLDEM"]
const YUT_NAMES: Dictionary = {-1: "빽도", 1: "도", 2: "개", 3: "걸", 4: "윷", 5: "모"}
const SLOT_SYMBOLS: Array[String] = ["체리", "레몬", "종", "BAR", "다이아", "7"]
const SUITS: Array[String] = ["♣", "♦", "♥", "♠"]
const RANKS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
## 연출 시간(초).
const DIE_SHUFFLE: float = 0.5
const DIE_PUNCH: float = 0.25
const ROULETTE_SPIN: float = 1.2
const SLOT_STOPS: Array[float] = [0.4, 0.8, 1.2]
const CARD_FLIP_INTERVAL: float = 0.15
const CARD_FLIP_TIME: float = 0.12
const HOLD_TIME: float = 0.35

## true면 모든 연출을 0초로 건너뛴다 (헤드리스 테스트·ui_smoke 자동 진행).
var instant: bool = false
## 연출이 끝난 뒤 화면에 남은 최종 표시 문자열 (테스트가 엔진 결과와 대조한다).
var last_display: String = ""
var active: bool = false
## 연출 패널이 가운데 정렬될 화면 좌표 (창 비율에 따라 MainBoard가 갱신한다).
var center: Vector2 = Vector2(683.0, 308.0)

var _mode: StringName = &""
var _t: float = 0.0
var _total: float = 0.0
var _result: Dictionary = {}
var _power: float = 0.5
var _rng := RandomNumberGenerator.new()
var _root: VBoxContainer = null
var _title: Label = null
var _stage: Control = null
var _die: PanelContainer = null
var _die_label: Label = null
var _sticks: Array[PanelContainer] = []
var _wheel: WheelView = null
var _wheel_label: Label = null
var _reels: Array[PanelContainer] = []
var _reel_labels: Array[Label] = []
var _reel_stopped: Array[bool] = [false, false, false]
var _cards: Array[PanelContainer] = []
var _card_labels: Array[Label] = []
var _card_faces: Array[String] = []
var _card_flipped: Array[bool] = []
var _last_tick: int = -1
var _settled: bool = false
var _final_face: int = 0


## 룰렛 원판. angle(라디안)만큼 돌아간 상태로 1~10 눈금을 그린다 (위쪽 바늘 자리가 현재 눈금).
class WheelView extends Control:
	var angle: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(190, 190)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 4.0
		var font: Font = get_theme_default_font()
		for index: int in 10:
			var mid: float = -PI / 2.0 + index * TAU / 10.0 - angle
			var from_angle: float = mid - TAU / 20.0
			var to_angle: float = mid + TAU / 20.0
			var points := PackedVector2Array([center])
			for step: int in 9:
				var theta: float = lerpf(from_angle, to_angle, step / 8.0)
				points.append(center + Vector2(cos(theta), sin(theta)) * radius)
			var color: Color = Color("e8590c") if index == 6 else (Color("1c7ed6") if index % 2 == 0 else Color("364fc7"))
			draw_colored_polygon(points, color)
			var label_pos: Vector2 = center + Vector2(cos(mid), sin(mid)) * radius * 0.72
			var text: String = str(index + 1)
			var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			draw_string(font, label_pos - Vector2(text_size.x / 2.0, -6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f8f9fa"))
		draw_arc(center, radius, 0.0, TAU, 64, Color("f1f3f5"), 3.0)
		# 고정 바늘 (위쪽)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-9, -radius - 6), center + Vector2(9, -radius - 6), center + Vector2(0, -radius + 14)]), Color("ffd43b"))


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101626")
	style.border_color = Color("ffd43b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 22
	add_theme_stylebox_override("panel", style)


static func supports(tool_id: StringName) -> bool:
	return SUPPORTED.has(tool_id)


## 결과 연출을 재생한다. 끝나면(또는 cancel()되면) 돌아온다. instant면 아무것도 그리지 않고 바로 돌아온다.
## power: 0~1 파워 게이지 값 - 셔플 속도·회전 수·펀치 크기 같은 '연출'에만 쓰이고 결과(눈금)에는 영향이 없다.
func play(tool_id: StringName, result: Dictionary, power: float = 0.5) -> void:
	cancel()
	if instant or not supports(tool_id):
		last_display = _final_text(tool_id, result)
		return
	_power = clampf(power, 0.0, 1.0)
	_result = result
	_mode = tool_id
	_t = 0.0
	_last_tick = -1
	_settled = false
	_build(tool_id)
	_position_center()
	active = true
	visible = true
	await finished


## 진행 중인 연출을 즉시 끝내고 숨긴다 (새 게임 등).
func cancel() -> void:
	if not active:
		visible = false
		return
	active = false
	visible = false
	finished.emit()


## 화면 정중앙(보드 한가운데)으로 위치를 맞춘다.
func _position_center() -> void:
	reset_size()
	position = center - size / 2.0


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	_update(_t)
	if _t >= _total:
		active = false
		visible = false
		finished.emit()


# ---------------------------------------------------------------------------
# 화면 구성
# ---------------------------------------------------------------------------

func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_sticks.clear()
	_reels.clear()
	_reel_labels.clear()
	_cards.clear()
	_card_labels.clear()
	_card_faces.clear()
	_card_flipped.clear()
	_reel_stopped = [false, false, false]
	_die = null
	_wheel = null


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(bg: Color, border: Color, radius: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = min_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _build(tool_id: StringName) -> void:
	_clear()
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_title = _label("", 14, Color("adb5bd"))
	_root.add_child(_title)
	_stage = CenterContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	match tool_id:
		&"D6", &"CHINCHIRO":
			_title.text = "기본 주사위" if tool_id == &"D6" else "지하노역장 친치로"
			_total = DIE_SHUFFLE + DIE_PUNCH + HOLD_TIME
			_die = _box(Color("f8f9fa"), Color("adb5bd"), 22, Vector2(128, 128))
			_die_label = _label("?", 78, Color("212529"))
			_die.add_child(_die_label)
			_stage.add_child(_die)
		&"YUT":
			_title.text = "전통 박달나무 윷"
			_total = DIE_SHUFFLE + DIE_PUNCH + HOLD_TIME
			var sticks := HBoxContainer.new()
			sticks.add_theme_constant_override("separation", 10)
			sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(sticks)
			for index: int in 4:
				var stick: PanelContainer = _box(Color("5c3b1e"), Color("2b1a0b"), 10, Vector2(30, 100))
				sticks.add_child(stick)
				_sticks.append(stick)
			_die_label = _label("?", 44, Color("ffe8cc"))
			_root.add_child(_die_label)
		&"LIFE_ROULETTE":
			_title.text = "인생게임 회전 룰렛"
			_total = ROULETTE_SPIN + HOLD_TIME + 0.15
			_wheel = WheelView.new()
			_stage.add_child(_wheel)
			_wheel_label = _label("?", 44, Color("ffd43b"))
			_root.add_child(_wheel_label)
			_final_face = int((_result["details"] as Dictionary).get("face", _result.get("steps", 1)))
		&"SLOT_777":
			_title.text = "777 슬롯머신"
			_total = SLOT_STOPS[2] + HOLD_TIME + 0.15
			var reels := HBoxContainer.new()
			reels.add_theme_constant_override("separation", 12)
			reels.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(reels)
			for index: int in 3:
				var reel: PanelContainer = _box(Color("f8f9fa"), Color("c92a2a"), 14, Vector2(96, 110))
				var reel_label: Label = _label("?", 26, Color("212529"))
				reel.add_child(reel_label)
				reels.add_child(reel)
				_reels.append(reel)
				_reel_labels.append(reel_label)
			_die_label = _label("[ ? ] [ ? ] [ ? ]", 16, Color("adb5bd"))
			_root.add_child(_die_label)
		&"HOLDEM":
			_title.text = "텍사스 홀덤 딜러"
			_total = CARD_FLIP_INTERVAL * 4 + CARD_FLIP_TIME + HOLD_TIME + 0.2
			var cards := HBoxContainer.new()
			cards.add_theme_constant_override("separation", 8)
			cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(cards)
			var drawn: Array = (_result["details"] as Dictionary).get("cards", [])
			for index: int in 5:
				var card: PanelContainer = _box(Color("364fc7"), Color("dbe4ff"), 10, Vector2(68, 96))
				var card_label: Label = _label("?", 28, Color("f8f9fa"))
				card.add_child(card_label)
				cards.add_child(card)
				_cards.append(card)
				_card_labels.append(card_label)
				_card_flipped.append(false)
				_card_faces.append(card_text(int(drawn[index])) if index < drawn.size() else "?")
	pivot_offset = Vector2.ZERO


## 카드 번호(0~51)의 표시 문자열: 문양 + 숫자 (예: ♠A).
static func card_text(card: int) -> String:
	return "%s%s" % [SUITS[card / 13], RANKS[card % 13]]


# ---------------------------------------------------------------------------
# 시간 경과에 따른 갱신
# ---------------------------------------------------------------------------

func _update(t: float) -> void:
	match _mode:
		&"D6", &"CHINCHIRO", &"YUT": _update_die(t)
		&"LIFE_ROULETTE": _update_wheel(t)
		&"SLOT_777": _update_slot(t)
		&"HOLDEM": _update_cards(t)


func _ease_out(x: float) -> float:
	var inv: float = 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - inv * inv * inv


## 눈금 숫자가 빠르게 바뀌며 구르다가 쾅! 하고 최종 눈금이 찍힌다.
func _update_die(t: float) -> void:
	var steps: int = int(_result.get("steps", 1))
	var face: int = int((_result["details"] as Dictionary).get("face", steps))
	var is_yut: bool = _mode == &"YUT"
	if t < DIE_SHUFFLE:
		var rate: float = lerpf(18.0, 42.0, _power)
		var tick: int = int(t * rate)
		if tick != _last_tick:
			_last_tick = tick
			if is_yut:
				var names: Array = YUT_NAMES.values()
				_die_label.text = str(names[_rng.randi_range(0, names.size() - 1)])
				for stick: PanelContainer in _sticks:
					_set_stick(stick, _rng.randi_range(0, 1) == 0, false)
			else:
				_die_label.text = str(_rng.randi_range(1, 6)) if _mode == &"D6" else str(ToolChinchiro.FACES[_rng.randi_range(0, 5)])
		var spins: float = 1.0 + floorf(_power * 3.0)
		var progress: float = _ease_out(t / DIE_SHUFFLE)
		if is_yut:
			for index: int in _sticks.size():
				_sticks[index].pivot_offset = _sticks[index].size / 2.0
				_sticks[index].rotation = sin(t * 14.0 + index) * 0.35
		else:
			_die.pivot_offset = _die.size / 2.0
			_die.rotation = progress * TAU * spins
		return
	if not _settled:
		_settled = true
		if is_yut:
			_die_label.text = str(YUT_NAMES.get(face, str(face)))
			_apply_yut_final(face)
			last_display = _die_label.text
		else:
			_die_label.text = str(steps)
			last_display = str(steps)
			_die.rotation = 0.0
	var punch: float = clampf((t - DIE_SHUFFLE) / DIE_PUNCH, 0.0, 1.0)
	var scale_value: float = 1.0 + (0.35 + 0.35 * _power) * pow(1.0 - punch, 2.0)
	var target: Control = _die if _die != null else _die_label
	target.pivot_offset = target.size / 2.0
	target.scale = Vector2(scale_value, scale_value)
	if is_yut:
		_die_label.add_theme_color_override("font_color", Color("ffd43b") if punch < 1.0 else Color("ffe8cc"))


func _set_stick(stick: PanelContainer, flat: bool, final: bool) -> void:
	var style: StyleBoxFlat = stick.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color("f1d9a8") if flat else Color("5c3b1e")
	if final:
		style.border_color = Color("ffd43b")
	stick.add_theme_stylebox_override("panel", style)


## 도~윷은 평평한 면의 수, 모는 전부 둥근 면, 빽도는 한 개만 뒤집힌 표식으로 그린다.
func _apply_yut_final(face: int) -> void:
	var flats: int = face if face >= 1 and face <= 4 else (1 if face == -1 else 0)
	for index: int in _sticks.size():
		_sticks[index].rotation = 0.0
		_set_stick(_sticks[index], index < flats, true)


## 원판이 처음엔 엄청 빠르게 돌다가 EASE_OUT 곡선으로 1.2초 동안 감속하며 최종 눈금에 딱 멈춘다.
func _update_wheel(t: float) -> void:
	var total_ticks: float = 40.0 + float(_final_face - 1)
	var progress: float = _ease_out(t / ROULETTE_SPIN)
	var k: float = total_ticks * progress
	_wheel.angle = k * TAU / 10.0
	_wheel.queue_redraw()
	_wheel_label.text = str((int(roundf(k)) % 10) + 1)
	if t >= ROULETTE_SPIN and not _settled:
		_settled = true
		_wheel.angle = total_ticks * TAU / 10.0
		_wheel.queue_redraw()
		_wheel_label.text = str(_final_face)
		last_display = str(_final_face)
	if _settled:
		var punch: float = clampf((t - ROULETTE_SPIN) / 0.2, 0.0, 1.0)
		var scale_value: float = 1.0 + 0.4 * pow(1.0 - punch, 2.0)
		_wheel_label.pivot_offset = _wheel_label.size / 2.0
		_wheel_label.scale = Vector2(scale_value, scale_value)


## 세 릴이 동시에 돌다가 0.4 -> 0.8 -> 1.2초에 차례로 철컥! 하고 멈춘다.
func _update_slot(t: float) -> void:
	var reels: Array = (_result["details"] as Dictionary).get("reels", [0, 0, 0])
	var shown: Array[String] = []
	for index: int in 3:
		var stop_time: float = SLOT_STOPS[index]
		if t < stop_time:
			var symbol: int = (int(t * 24.0) + index * 2) % SLOT_SYMBOLS.size()
			_reel_labels[index].text = SLOT_SYMBOLS[symbol]
			shown.append("?")
		else:
			var final_symbol: String = SLOT_SYMBOLS[int(reels[index]) % SLOT_SYMBOLS.size()]
			_reel_labels[index].text = final_symbol
			shown.append(final_symbol)
			var punch: float = clampf((t - stop_time) / 0.18, 0.0, 1.0)
			var scale_value: float = 1.0 + 0.3 * pow(1.0 - punch, 2.0)
			_reels[index].pivot_offset = _reels[index].size / 2.0
			_reels[index].scale = Vector2(scale_value, scale_value)
			if not _reel_stopped[index]:
				_reel_stopped[index] = true
				_reels[index].add_theme_stylebox_override("panel", _stopped_style())
	_die_label.text = "[ %s ] [ %s ] [ %s ]" % [shown[0], shown[1], shown[2]]
	if t >= SLOT_STOPS[2]:
		last_display = "|".join(PackedStringArray([SLOT_SYMBOLS[int(reels[0])], SLOT_SYMBOLS[int(reels[1])], SLOT_SYMBOLS[int(reels[2])]]))


func _stopped_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff3bf")
	style.border_color = Color("ffd43b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(4)
	return style


## 카드 5장이 0.15초 간격으로 한 장씩 뒷면에서 앞면으로 뒤집힌다 (가로로 눌렸다 펴지는 플립).
func _update_cards(t: float) -> void:
	for index: int in 5:
		var start: float = index * CARD_FLIP_INTERVAL
		var card: PanelContainer = _cards[index]
		card.pivot_offset = card.size / 2.0
		if t < start:
			card.scale.x = 1.0
			continue
		var phase: float = clampf((t - start) / CARD_FLIP_TIME, 0.0, 1.0)
		if phase < 0.5:
			card.scale.x = 1.0 - phase * 2.0
		else:
			if not _card_flipped[index]:
				_card_flipped[index] = true
				_card_labels[index].text = _card_faces[index]
				var red: bool = _card_faces[index].begins_with("♥") or _card_faces[index].begins_with("♦")
				_card_labels[index].add_theme_color_override("font_color", Color("e03131") if red else Color("212529"))
				var style := StyleBoxFlat.new()
				style.bg_color = Color("f8f9fa")
				style.border_color = Color("adb5bd")
				style.set_border_width_all(3)
				style.set_corner_radius_all(10)
				style.set_content_margin_all(4)
				card.add_theme_stylebox_override("panel", style)
			card.scale.x = (phase - 0.5) * 2.0
	if t >= CARD_FLIP_INTERVAL * 4 + CARD_FLIP_TIME:
		last_display = " ".join(PackedStringArray(_card_faces))


## 연출을 건너뛰었을 때 last_display에 담을 최종 표시 문자열.
func _final_text(tool_id: StringName, result: Dictionary) -> String:
	var details: Dictionary = result.get("details", {})
	match tool_id:
		&"D6", &"CHINCHIRO": return str(int(result.get("steps", 0)))
		&"YUT": return str(YUT_NAMES.get(int(details.get("face", result.get("steps", 0))), "?"))
		&"LIFE_ROULETTE": return str(int(details.get("face", result.get("steps", 0))))
		&"SLOT_777":
			var reels: Array = details.get("reels", [0, 0, 0])
			return "|".join(PackedStringArray([SLOT_SYMBOLS[int(reels[0])], SLOT_SYMBOLS[int(reels[1])], SLOT_SYMBOLS[int(reels[2])]]))
		&"HOLDEM":
			var faces: Array[String] = []
			for card: Variant in details.get("cards", []):
				faces.append(card_text(int(card)))
			return " ".join(PackedStringArray(faces))
	return ""
