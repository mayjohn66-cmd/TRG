# File: res://scenes/augment_timeline.gd
# Class: class_name AugmentTimeline
# Role: 라운드별 칸을 한 줄에 표시한다. 증강 숫자는 노랑, 템포 업이 시작되는 칸의 테두리는 빨강이다.
class_name AugmentTimeline
extends Control

## 가운데 현재 라운드, 양옆에 지난 두 라운드와 다음 두 라운드.
const CHIP_COUNT := 5
const CURRENT_SLOT := 2
const CHIP_WIDTH := 53.0
const CHIP_HEIGHT := 42.0
const CHIP_GAP := 11.0
const SIDE_MARGIN := 8.0
const CURRENT_SCALE := 1.32
const TRACK_HEIGHT := 57.0
const SLIDE_SECONDS := 0.20
## 몇 번째 드래프트부터 초증강·법전이 섞이는가 (7라운드 = 3번째). AugmentRegistry.DRAFT_FOCUS 주석 참고.
const SUPER_FROM_DRAFT: int = 3

const COLOR_GOLD := Color("ffd951")
const COLOR_EDGE := Color("687589")
const COLOR_TEMPO := Color("ff535e")
const COLOR_CHIP := Color("111827")
const COLOR_CURRENT := Color("28566b")
const COLOR_EMPTY := Color(0.06, 0.09, 0.15, 0.48)
const COLOR_EMPTY_EDGE := Color(0.41, 0.46, 0.54, 0.48)

var rounds: Array[Dictionary] = []
var caption_kind: StringName = &"none"
var caption_rounds: int = 0
var _numbers: Array[Label] = []
var _spare: Label
var _slide: Tween
var _current_round := 0
var _key: String = ""


## 증강(드래프트)이 나오는 라운드인가.
static func is_draft_round(round_number: int) -> bool:
	return GameEnums.is_draft_round(round_number)


## 초증강·법전이 후보에 섞이는 증강 라운드인가 (7라운드부터).
static func is_super_round(round_number: int) -> bool:
	return GameEnums.is_draft_round(round_number) and AugmentRegistry.draft_number(round_number) >= SUPER_FROM_DRAFT


## after 다음(after는 포함하지 않음)에 오는 첫 증강 라운드. cap 안에 없으면 -1.
static func next_draft_after(after: int, cap: int) -> int:
	for round_number: int in range(maxi(after, 0) + 1, cap + 1):
		if GameEnums.is_draft_round(round_number):
			return round_number
	return -1


## 현재 라운드를 가운데 고정한다. 판의 처음과 끝에서는 범위 밖 칸을 비운다.
static func entries(current: int, cap: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in CHIP_COUNT:
		var round_number := current + index - CURRENT_SLOT
		var available := round_number >= 1 and round_number <= cap
		result.append({
			"round": round_number,
			"available": available,
			"current": index == CURRENT_SLOT,
			"draft": available and is_draft_round(round_number),
			"super": available and is_super_round(round_number),
		})
	return result


## 증강 안내의 종류와 남은 라운드. kind: now / soon / later / none.
## pending_now: 지금 라운드가 증강 라운드이고 선택이 아직 끝나지 않았다.
static func caption_for(current: int, pending_now: bool, cap: int) -> Dictionary:
	if pending_now and is_draft_round(current):
		return {"kind": &"now", "rounds": 0}
	var next_round: int = next_draft_after(current, cap)
	if next_round == -1:
		return {"kind": &"none", "rounds": 0}
	var distance: int = next_round - current
	return {"kind": &"soon" if distance == 1 else &"later", "rounds": distance}


## 다음 라운드가 증강 라운드라서 라운드 시작 연출에 사전 예고를 붙여야 하는가.
static func warns_next_round(current: int, cap: int) -> bool:
	return current + 1 <= cap and is_draft_round(current + 1)


func _init() -> void:
	name = "AugmentTimeline"
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	custom_minimum_size = Vector2(CHIP_COUNT * CHIP_WIDTH + (CHIP_COUNT - 1) * CHIP_GAP + SIDE_MARGIN * 2.0, TRACK_HEIGHT)
	size = custom_minimum_size
	# Keep one extra chip for the outgoing edge during a slide.
	for index: int in CHIP_COUNT + 1:
		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 24)
		number.size = Vector2(CHIP_WIDTH, CHIP_HEIGHT)
		number.pivot_offset = number.size * 0.5
		var tile := StyleBoxFlat.new()
		tile.set_corner_radius_all(8)
		number.add_theme_stylebox_override("normal", tile)
		number.hide()
		add_child(number)
		_numbers.append(number)
	_spare = _numbers.pop_back()


## 화면을 현재 상태로 맞춘다 (바뀐 게 없으면 다시 그리지 않는다).
func refresh(current: int, pending_now: bool, cap: int, animate: bool = true) -> void:
	var key: String = "%d:%s:%d:%s:%s" % [current, str(pending_now), cap, L10n.current_lang, str(TempoUp.stage_rounds)]
	if key == _key:
		return
	_key = key
	rounds = entries(current, cap)
	if current != _current_round:
		var advances := animate and _current_round > 0 and current == _current_round + 1 and is_visible_in_tree()
		_reposition(advances)
		_current_round = current
	var caption: Dictionary = caption_for(current, pending_now, cap)
	caption_kind = caption["kind"]
	caption_rounds = int(caption["rounds"])

	for index: int in _numbers.size():
		var number := _numbers[index]
		var entry := rounds[index]
		var available: bool = entry["available"]
		number.show()
		number.text = "%dR" % int(entry["round"]) if available else ""
		number.add_theme_color_override("font_color", COLOR_GOLD if entry["draft"] else Color.WHITE)
		var starts_tempo := available and TempoUp.is_stage_round(int(entry["round"]))
		var tile := number.get_theme_stylebox("normal") as StyleBoxFlat
		tile.bg_color = COLOR_CURRENT if entry["current"] else (COLOR_CHIP if available else COLOR_EMPTY)
		tile.border_color = COLOR_TEMPO if starts_tempo else (COLOR_EDGE if available else COLOR_EMPTY_EDGE)
		tile.set_border_width_all(3 if starts_tempo else 1)

	var notice: String
	match caption_kind:
		&"now":
			notice = L10n.t("이번 라운드 증강!")
		&"soon":
			notice = L10n.t("다음 라운드 증강!")
		&"later":
			notice = L10n.t("다음 증강까지 %d라운드") % caption_rounds
		_:
			notice = L10n.t("남은 증강 없음")
	tooltip_text = notice + "\n" + L10n.t("노란 숫자는 증강 라운드, 붉은 테두리는 템포 업이 시작되는 라운드를 뜻합니다. 7라운드부터 초증강과 법전도 후보에 섞입니다.")


func _chip_position(index: int) -> Vector2:
	return Vector2(SIDE_MARGIN + index * (CHIP_WIDTH + CHIP_GAP), (size.y - CHIP_HEIGHT) * 0.5)


func _reposition(advances: bool) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_spare.hide()
	if not advances:
		for index: int in CHIP_COUNT:
			_numbers[index].position = _chip_position(index)
			_numbers[index].scale = Vector2.ONE * (CURRENT_SCALE if index == CURRENT_SLOT else 1.0)
		return

	var leaving: Label = _numbers.pop_front()
	_numbers.append(_spare)
	_spare = leaving
	_spare.position = _chip_position(0)
	_spare.show()
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_spare, "position", _chip_position(-1), SLIDE_SECONDS)
	for index: int in CHIP_COUNT:
		_numbers[index].position = _chip_position(index + 1)
		_slide.tween_property(_numbers[index], "position", _chip_position(index), SLIDE_SECONDS)
		var target_scale := Vector2.ONE * (CURRENT_SCALE if index == CURRENT_SLOT else 1.0)
		_slide.tween_property(_numbers[index], "scale", target_scale, SLIDE_SECONDS)
	_slide.chain().tween_callback(_spare.hide)
