# File: res://scenes/roll_presenter.gd
# Class: class_name RollPresenter
# Role: 판정 도구 결과 연출기. 확정된 결과를 D6의 실제 3D 굴림·윷 던지기·룰렛 감속·슬롯 순차 정지·카드 플립으로 표시한다. 연출만 담당하며 결과는 절대 바꾸지 않는다
class_name RollPresenter
extends PanelContainer

## 연출이 끝났다 (취소 포함). play()는 이 시그널을 await 한다.
signal finished

const SUPPORTED: Array[StringName] = [&"D6", &"CHINCHIRO", &"YUT", &"LIFE_ROULETTE", &"SLOT_777", &"HOLDEM", &"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT"]
const YUT_NAMES: Dictionary = {-1: "빽도", 1: "도", 2: "개", 3: "걸", 4: "윷", 5: "모"}
const SLOT_SYMBOLS: Array[String] = ["체리", "레몬", "종", "BAR", "다이아", "7"]
const SUITS: Array[String] = ["♣", "♦", "♥", "♠"]
const RANKS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
## 연출 시간(초).
const SLOT_STOPS: Array[float] = [0.4, 0.8, 1.2]
const CARD_FLIP_INTERVAL: float = 0.15
const CARD_FLIP_TIME: float = 0.12
const HOLD_TIME: float = 0.35
const CARD_DEAL_TIME: float = 0.20
const ART_CARD_FLIP_TIME: float = 0.22
const TAROT_FOCUS_TIME: float = 0.22
const CARD_RESULT_HOLD: float = 0.50

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
var _root: VBoxContainer = null
var _title: Label = null
var _stage: Control = null
var _die_label: Label = null
var _wheel: RouletteSpin3D = null
var _reels: Array[PanelContainer] = []
var _reel_labels: Array[Label] = []
var _reel_stopped: Array[bool] = [false, false, false]
var _cards: Array[PanelContainer] = []
var _card_labels: Array[Label] = []
var _card_faces: Array[String] = []
var _card_flipped: Array[bool] = []
## 카드 줄 연출 공통: 뒤집을 카드 표시(이미 앞면인 카드는 false), 앞면 배경색, 카드별 글자색.
var _card_flip_mask: Array[bool] = []
var _card_front: Color = Color("f8f9fa")
var _card_face_colors: Array[Color] = []
var _settled: bool = false
var _final_face: int = 0
var _dice_3d: DiceRoll3D = null
var _default_style: StyleBoxFlat
var _card_home: Array[Vector2] = []
var _card_result_caption: String = ""
var _mahjong_3d: MahjongSlam3D = null
var _mahjong_names: Array[Label] = []
var _yut_3d: YutThrow3D = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101626")
	style.border_color = Color("ffd43b")
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 22
	_default_style = style
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
	if tool_id in [&"HOLDEM", &"DICE_HWATU", &"DICE_TAROT", &"DICE_MAHJONG", &"YUT", &"LIFE_ROULETTE"]:
		last_display = ""
	_mode = tool_id
	_t = 0.0
	_settled = false
	_build(tool_id)
	_position_center()
	active = true
	visible = true
	await finished


## 진행 중인 연출을 즉시 끝내고 숨긴다 (새 게임 등).
func cancel() -> void:
	if _dice_3d != null:
		_dice_3d.stop_rendering()
	if _mahjong_3d != null:
		_mahjong_3d.stop_rendering()
	if _yut_3d != null:
		_yut_3d.stop_rendering()
	if _wheel != null:
		_wheel.stop_rendering()
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
		if _dice_3d != null:
			_dice_3d.stop_rendering()
		if _mahjong_3d != null:
			_mahjong_3d.stop_rendering()
		if _yut_3d != null:
			_yut_3d.stop_rendering()
		if _wheel != null:
			_wheel.stop_rendering()
		finished.emit()


# ---------------------------------------------------------------------------
# 화면 구성
# ---------------------------------------------------------------------------

func _clear() -> void:
	# Keep one viewport/mesh set across rolls; it does not render when idle.
	if _dice_3d != null:
		_dice_3d.stop_rendering()
		_dice_3d.hide()
		if _dice_3d.get_parent() != self:
			_dice_3d.reparent(self)
	if _mahjong_3d != null:
		_mahjong_3d.stop_rendering()
		_mahjong_3d.hide()
		if _mahjong_3d.get_parent() != self:
			_mahjong_3d.reparent(self)
	if _yut_3d != null:
		_yut_3d.stop_rendering()
		_yut_3d.hide()
		if _yut_3d.get_parent() != self:
			_yut_3d.reparent(self)
	if _wheel != null:
		_wheel.stop_rendering()
		_wheel.hide()
		if _wheel.get_parent() != self:
			_wheel.reparent(self)
	for child: Node in get_children():
		if child == _dice_3d or child == _mahjong_3d or child == _yut_3d or child == _wheel:
			continue
		remove_child(child)
		child.queue_free()
	_reels.clear()
	_reel_labels.clear()
	_cards.clear()
	_card_labels.clear()
	_card_faces.clear()
	_card_flipped.clear()
	_card_flip_mask.clear()
	_card_face_colors.clear()
	_card_home.clear()
	_mahjong_names.clear()
	_reel_stopped = [false, false, false]


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
	var illustrated: bool = tool_id in [&"HOLDEM", &"DICE_HWATU", &"DICE_TAROT", &"DICE_MAHJONG", &"YUT", &"LIFE_ROULETTE"]
	add_theme_stylebox_override("panel", UiSkin.panel("panel", 12.0) if illustrated or tool_id in [&"D6", &"CHINCHIRO"] else _default_style)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_title = _label("", 14, Color("adb5bd"))
	if illustrated:
		_title.add_theme_font_size_override("font_size", 18)
		_title.add_theme_color_override("font_color", UiSkin.GREEN)
	_root.add_child(_title)
	_stage = CenterContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	match tool_id:
		&"D6", &"CHINCHIRO":
			_title.text = "기본 주사위" if tool_id == &"D6" else "지하노역장 친치로"
			_title.add_theme_font_size_override("font_size", 18)
			_title.add_theme_color_override("font_color", UiSkin.GREEN)
			_total = DiceRoll3D.ROLL_TIME + DiceRoll3D.HOLD_TIME
			if _dice_3d == null:
				_dice_3d = DiceRoll3D.new()
				_stage.add_child(_dice_3d)
			else:
				_dice_3d.reparent(_stage)
			_dice_3d.show()
			_final_face = int((_result.get("details", {}) as Dictionary).get("face", _result.get("steps", 1)))
			_dice_3d.begin(_final_face, _power, tool_id)
			_die_label = _label("굴리는 중…", 22, UiSkin.INK)
			_root.add_child(_die_label)
		&"YUT":
			_title.text = "전통 박달나무 윷"
			_total = YutThrow3D.TOTAL_TIME
			if _yut_3d == null:
				_yut_3d = YutThrow3D.new()
				_stage.add_child(_yut_3d)
			else:
				_yut_3d.reparent(_stage)
			_yut_3d.show()
			var face: int = int((_result.get("details", {}) as Dictionary).get("face",_result.get("steps",1)))
			_yut_3d.begin(face,_power)
			var caption: String = "%s · %s" % [YUT_NAMES[face],_card_move_text()]
			if bool(_result.get("reroll",false)):
				caption += " · 한 번 더"
			_make_card_result(caption)
		&"LIFE_ROULETTE":
			_title.text = "인생게임 회전 룰렛"
			_total = RouletteSpin3D.TOTAL_TIME
			if _wheel == null:
				_wheel = RouletteSpin3D.new()
				_stage.add_child(_wheel)
			else:
				_wheel.reparent(_stage)
			_wheel.show()
			_final_face = int((_result.get("details",{}) as Dictionary).get("face",_result.get("steps",1)))
			_wheel.begin(_final_face,_power)
			var caption: String = "%d · %s" % [_final_face,_card_move_text()]
			if bool(_result.get("reroll",false)):
				caption += " · 한 번 더"
			_make_card_result(caption)
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
			_build_holdem()
		&"DICE_HWATU": _build_hwatu()
		&"DICE_MAHJONG": _build_mahjong()
		&"DICE_TAROT": _build_tarot()
	pivot_offset = Vector2.ZERO


## 홀덤: 엔진이 뽑은 다섯 장을 순서대로 공개한다.
func _build_holdem() -> void:
	_title.text = "텍사스 홀덤 딜러"
	var details: Dictionary = _result.get("details", {})
	var models: Array[Dictionary] = []
	var mask: Array[bool] = []
	for card: Variant in details.get("cards", []):
		models.append(JudgmentCardArt.poker(int(card)))
		_card_faces.append(card_text(int(card)))
		mask.append(true)
	_build_illustrated_row(models, mask, Vector2(96, 144))
	_make_card_result("%s · %s" % [MainBoard.HAND_NAMES.get(details.get("hand", &"high_card"), "족보"), _card_move_text()])


## 화투: 기존 공개 패는 그대로 두고 새 패만 뒤집는다.
func _build_hwatu() -> void:
	var details: Dictionary = _result["details"]
	var all_cards: Array = details.get("cards", [])
	var fresh: Array = details.get("new_cards", [])
	_title.text = "화투 패"
	var models: Array[Dictionary] = []
	var mask: Array[bool] = []
	for card: Variant in all_cards:
		models.append(JudgmentCardArt.hwatu(int(card)))
		_card_faces.append(ToolHwatu.card_name(int(card)))
		mask.append(fresh.has(card))
	_build_illustrated_row(models, mask, Vector2(104, 148))
	_make_card_result("%s · %s" % [details.get("label", ""), _card_move_text()])


## 마작: 고정된 세 패를 0.24초 간격으로 탁, 탁, 탁 내려놓는다.
func _build_mahjong() -> void:
	var details: Dictionary = _result["details"]
	_title.text = "리치 마작 만리장성"
	_total = MahjongSlam3D.TOTAL_TIME
	if _mahjong_3d == null:
		_mahjong_3d = MahjongSlam3D.new()
		_stage.add_child(_mahjong_3d)
	else:
		_mahjong_3d.reparent(_stage)
	_mahjong_3d.show()
	_mahjong_3d.begin(details.get("tiles", []))
	var names := HBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation",0)
	_root.add_child(names)
	for tile: Variant in details.get("tiles", []):
		_card_faces.append(ToolMahjong.tile_name(int(tile)))
		_card_flipped.append(false)
		var name_label: Label = _label("",16,UiSkin.INK)
		name_label.custom_minimum_size = Vector2(118,24)
		names.add_child(name_label)
		_mahjong_names.append(name_label)
	var caption: String = "%s · %s" % [details.get("label", ""),_card_move_text()]
	if bool(_result.get("reroll",false)):
		caption += " · 한 번 더"
	_make_card_result(caption)


static func _mahjong_color(tile: int) -> Color:
	if tile >= ToolMahjong.HONOR_START:
		return [Color("495057"), Color("2b8a3e"), Color("c92a2a")][tile - ToolMahjong.HONOR_START]
	return [Color("c92a2a"), Color("1c7ed6"), Color("2b8a3e")][tile / 9]


## 타로: 뒷면 카드 5장이 놓이고 그중 한 장만 뒤집혀 운명이 드러난다.
const TAROT_SHORT: Dictionary = {&"fool": "0\n광대", &"chariot": "VII\n전차", &"wheel": "X\n수레바퀴", &"hanged": "XII\n매달린 남자", &"world": "XXI\n세계"}


func _build_tarot() -> void:
	var details: Dictionary = _result["details"]
	_title.text = "점성술사의 타로 덱"
	var flipped: int = int(details.get("flipped", 0))
	var fate: StringName = details.get("fate", &"chariot")
	var models: Array[Dictionary] = []
	var mask: Array[bool] = []
	for index: int in 5:
		models.append(JudgmentCardArt.tarot(fate if index == flipped else &""))
		_card_faces.append(str(TAROT_SHORT[fate]) if index == flipped else "?")
		mask.append(index == flipped)
	_build_illustrated_row(models, mask, Vector2(96, 156), true)
	var text: String = "%s · %s" % [JudgmentCardArt.TAROT[fate][1], _card_move_text()]
	if bool(_result.get("reroll", false)):
		text += " · 한 번 더"
	if details.has("blessing_booked"):
		text += " · 다음 굴림 +%d" % int(details.blessing_booked)
	_make_card_result(text)


func _card_move_text() -> String:
	var steps: int = int(_result.get("steps", 0))
	if steps == 0:
		return "이동 없음"
	return "%d칸 %s" % [absi(steps), "전진" if steps > 0 else "후퇴"]


func _make_card_result(caption: String) -> void:
	_card_result_caption = caption
	_die_label = _label("", 20, UiSkin.INK)
	_root.add_child(_die_label)
	var font: Font = _die_label.get_theme_font("font")
	_die_label.custom_minimum_size = Vector2(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 4.0, 32.0)
	_die_label.modulate.a = 0.0


func _build_illustrated_row(models: Array[Dictionary], mask: Array[bool], card_size: Vector2, hidden_rest: bool = false) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var flips: int = 0
	for index: int in models.size():
		var card := JudgmentCard.new()
		card.configure(models[index], card_size)
		row.add_child(card)
		var already_front: bool = not mask[index] and not hidden_rest
		card.set_face_up(already_front)
		_cards.append(card)
		_card_flipped.append(already_front)
		_card_flip_mask.append(mask[index])
		_card_home.append(Vector2(index * (card_size.x + 8.0), 0.0))
		if mask[index]:
			flips += 1
	var stride: float = CARD_FLIP_INTERVAL * (1.0 if _mode == &"HOLDEM" else 2.0)
	_total = CARD_DEAL_TIME + (TAROT_FOCUS_TIME if hidden_rest else 0.0) + stride * maxi(flips - 1, 0) + ART_CARD_FLIP_TIME + CARD_RESULT_HOLD
	Sfx.play(&"card_throw")


## 카드 줄 한 벌을 만든다. mask가 true인 카드만 뒤집히고 false인 카드는 처음부터 앞면(faces)이다. hidden_rest면 false 카드는 뒷면 그대로 둔다.
func _build_flip_row(faces: Array[String], colors: Array[Color], mask: Array[bool], card_size: Vector2, back: Color, border: Color, font_px: int, hidden_rest: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(row)
	var flips: int = 0
	for index: int in faces.size():
		var flips_now: bool = mask[index]
		var already_front: bool = not flips_now and not hidden_rest
		var card: PanelContainer = _box(_card_front if already_front else back, border, 10, card_size)
		var label: Label = _label(faces[index] if already_front else "?", font_px, colors[index] if already_front else Color("f8f9fa"))
		card.add_child(label)
		row.add_child(card)
		_cards.append(card)
		_card_labels.append(label)
		_card_flipped.append(already_front or hidden_rest and not flips_now)
		_card_faces.append(faces[index])
		_card_flip_mask.append(flips_now)
		_card_face_colors.append(colors[index])
		if flips_now:
			flips += 1
	_total = CARD_FLIP_INTERVAL * maxi(flips - 1, 0) * 2.0 + CARD_FLIP_TIME + HOLD_TIME + 0.35


## 카드 번호(0~51)의 표시 문자열: 문양 + 숫자 (예: ♠A).
static func card_text(card: int) -> String:
	return "%s%s" % [SUITS[card / 13], RANKS[card % 13]]


# ---------------------------------------------------------------------------
# 시간 경과에 따른 갱신
# ---------------------------------------------------------------------------

func _update(t: float) -> void:
	match _mode:
		&"D6", &"CHINCHIRO": _update_3d_die(t)
		&"YUT": _update_yut(t)
		&"LIFE_ROULETTE": _update_wheel(t)
		&"SLOT_777": _update_slot(t)
		&"HOLDEM", &"DICE_HWATU", &"DICE_TAROT": _update_illustrated_cards(t)
		&"DICE_MAHJONG": _update_mahjong(t)


func _update_3d_die(t: float) -> void:
	_dice_3d.apply_time(t)
	if t >= DiceRoll3D.ROLL_TIME and not _settled:
		_settled = true
		var steps: int = int(_result.get("steps", _final_face))
		last_display = str(steps)
		_die_label.text = "삐끗! %d칸 후퇴" % absi(steps) if steps < 0 else "%d칸 전진" % steps
		if steps < 0:
			_die_label.add_theme_color_override("font_color", Color("bf4941"))
		Sfx.play(&"thud")


func _update_yut(t: float) -> void:
	_yut_3d.apply_time(t)
	if _yut_3d.settled:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = str(YUT_NAMES[_yut_3d.result_value])


## The same physical rotor is used by the direct pad and this remote reveal.
func _update_wheel(t: float) -> void:
	_wheel.apply_time(t)
	if _wheel.settled:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = str(_final_face)


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


func _update_illustrated_cards(t: float) -> void:
	var order: int = 0
	var complete: bool = true
	var is_tarot: bool = _mode == &"DICE_TAROT"
	var stride: float = CARD_FLIP_INTERVAL * (1.0 if _mode == &"HOLDEM" else 2.0)
	for index: int in _cards.size():
		var card: JudgmentCard = _cards[index] as JudgmentCard
		var dealing: float = clampf(t / CARD_DEAL_TIME, 0.0, 1.0)
		if _mode == &"DICE_HWATU" and not _card_flip_mask[index]:
			dealing = 1.0
		var remaining: float = pow(1.0 - dealing, 3.0)
		card.position = _card_home[index] + Vector2(((_cards.size() - 1) * 0.5 - index) * card.size.x * 0.7, 18.0) * remaining
		card.pivot_offset = card.size / 2.0
		card.rotation = (index - (_cards.size() - 1) * 0.5) * 0.08 * remaining
		card.modulate.a = clampf(dealing * 2.0, 0.0, 1.0)
		if not _card_flip_mask[index]:
			if is_tarot and t >= CARD_DEAL_TIME:
				card.modulate = Color(0.85, 0.85, 0.85, 1.0)
			continue
		var start: float = CARD_DEAL_TIME + (TAROT_FOCUS_TIME if is_tarot else 0.0) + order * stride
		order += 1
		if is_tarot:
			card.position.y -= 8.0 * clampf((t - CARD_DEAL_TIME) / TAROT_FOCUS_TIME, 0.0, 1.0)
		var phase: float = clampf((t - start) / ART_CARD_FLIP_TIME, 0.0, 1.0)
		card.scale.x = maxf(absf(cos(phase * PI)), 0.015)
		card.position.y -= sin(phase * PI) * 6.0
		if phase >= 0.5 and not _card_flipped[index]:
			_card_flipped[index] = true
			card.set_face_up(true)
			Sfx.play(&"card_pick")
		if phase < 1.0:
			complete = false
	if complete:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = _final_text(_mode, _result)


func _update_mahjong(t: float) -> void:
	_mahjong_3d.apply_time(t)
	for index: int in 3:
		_card_flipped[index] = _mahjong_3d.landed[index]
		if _card_flipped[index]:
			_mahjong_names[index].text = _card_faces[index]
	if t >= MahjongSlam3D.RESULT_TIME:
		_die_label.text = _card_result_caption
		_die_label.modulate.a = 1.0
		last_display = _final_text(_mode,_result)


## Legacy flat flip renderer; current judgment tools use their own presenters.
func _update_cards(t: float) -> void:
	var order: int = 0
	for index: int in _cards.size():
		var card: PanelContainer = _cards[index]
		card.pivot_offset = card.size / 2.0
		if index < _card_flip_mask.size() and not _card_flip_mask[index]:
			continue
		var start: float = order * CARD_FLIP_INTERVAL * (2.0 if _mode != &"HOLDEM" else 1.0)
		order += 1
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
				if index < _card_face_colors.size() and _mode != &"HOLDEM":
					_card_labels[index].add_theme_color_override("font_color", _card_face_colors[index])
				else:
					_card_labels[index].add_theme_color_override("font_color", Color("e03131") if red else Color("212529"))
				var style := StyleBoxFlat.new()
				style.bg_color = _card_front
				style.border_color = Color("adb5bd")
				style.set_border_width_all(3)
				style.set_corner_radius_all(10)
				style.set_content_margin_all(4)
				card.add_theme_stylebox_override("panel", style)
			card.scale.x = (phase - 0.5) * 2.0
	# 족보·결과 이름은 모든 패가 뒤집힌 뒤에야 보인다 (뒤집히기 전에 결과를 미리 알려 주지 않는다).
	var all_flipped: bool = true
	for flipped: bool in _card_flipped:
		all_flipped = all_flipped and flipped
	if all_flipped and _die_label != null and _mode in [&"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT"]:
		_die_label.modulate.a = 1.0
	last_display = " ".join(PackedStringArray(_card_faces)) if _mode == &"HOLDEM" else _final_text(_mode, _result)


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
		&"DICE_HWATU":
			var names: Array[String] = []
			for card: Variant in details.get("cards", []):
				names.append(ToolHwatu.card_name(int(card)))
			return " ".join(PackedStringArray(names))
		&"DICE_MAHJONG":
			var tile_names: Array[String] = []
			for tile: Variant in details.get("tiles", []):
				tile_names.append(ToolMahjong.tile_name(int(tile)))
			return " ".join(PackedStringArray(tile_names))
		&"DICE_TAROT": return str(details.get("name", ""))
	return ""
