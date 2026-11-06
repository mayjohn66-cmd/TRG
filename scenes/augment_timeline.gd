# File: res://scenes/augment_timeline.gd
# Class: class_name AugmentTimeline
# Role: 화면 위쪽 가운데의 [증강 타임라인]. 지금 라운드부터 앞으로 몇 개 라운드를 칩으로 늘어놓고 증강이 나오는 라운드(1·4·7·10…)를 금색 선물 상자로,
#       초증강·법전까지 섞이는 라운드(7라운드부터)를 별 표시로 보여 준다. 왼쪽 글은 [이번 라운드 증강!] / [다음 라운드 증강!] / [다음 증강까지 N라운드].
#       2026-11 유저 제보: "증강이 언제 나오는지 알려주면 좋겠음". 그림은 모두 도형으로 직접 그린다 (이모지는 글꼴에 없어 깨진다).
#       계산(어느 라운드가 증강인가, 문구 종류)은 정적 함수라 화면 없이 테스트한다.
class_name AugmentTimeline
extends Control

## 보여 줄 칩 수: 지금 라운드 + 앞으로 5개 라운드.
const CHIP_COUNT: int = 6
const CHIP_SIZE: Vector2 = Vector2(50.0, 34.0)
const CHIP_GAP: float = 14.0
const CAPTION_WIDTH: float = 190.0
## 몇 번째 드래프트부터 초증강·법전이 섞이는가 (7라운드 = 3번째). AugmentRegistry.DRAFT_FOCUS 주석 참고.
const SUPER_FROM_DRAFT: int = 3

const COLOR_GOLD: Color = Color("ffd43b")
const COLOR_WARN: Color = Color("ffa94d")
const COLOR_SUPER: Color = Color("ff6b9d")

var rounds: Array[Dictionary] = []
var caption_kind: StringName = &"none"
var caption_rounds: int = 0
var _caption: Label = null
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


## 지금 라운드부터 count개 칩의 정보 (cap을 넘는 라운드는 뺀다).
static func entries(current: int, cap: int, count: int = CHIP_COUNT) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offset: int in count:
		var round_number: int = current + offset
		if round_number > cap:
			break
		result.append({"round": round_number, "current": offset == 0, "draft": is_draft_round(round_number), "super": is_super_round(round_number)})
	return result


## 왼쪽 글의 종류와 남은 라운드. kind: now(이번 라운드 증강, 아직 안 골랐다) / soon(다음 라운드가 증강) / later(N라운드 뒤) / none(남은 증강 없음).
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
	custom_minimum_size = Vector2(CAPTION_WIDTH + (CHIP_SIZE.x + CHIP_GAP) * CHIP_COUNT, CHIP_SIZE.y + 6.0)
	size = custom_minimum_size
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.position = Vector2(0.0, 0.0)
	_caption.size = Vector2(CAPTION_WIDTH - 8.0, size.y)
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caption.add_theme_font_size_override("font_size", FontSizes.snap(MobileSupport.text_px(14, 18)))
	_caption.add_theme_color_override("font_outline_color", Color("0d1018"))
	_caption.add_theme_constant_override("outline_size", 4)
	add_child(_caption)


## 화면을 현재 상태로 맞춘다 (바뀐 게 없으면 다시 그리지 않는다).
func refresh(current: int, pending_now: bool, cap: int) -> void:
	var key: String = "%d:%s:%d:%s" % [current, str(pending_now), cap, L10n.current_lang]
	if key == _key:
		return
	_key = key
	rounds = entries(current, cap)
	var caption: Dictionary = caption_for(current, pending_now, cap)
	caption_kind = caption["kind"]
	caption_rounds = int(caption["rounds"])
	match caption_kind:
		&"now":
			_caption.text = L10n.t("이번 라운드 증강!")
			_caption.add_theme_color_override("font_color", COLOR_GOLD)
		&"soon":
			_caption.text = L10n.t("다음 라운드 증강!")
			_caption.add_theme_color_override("font_color", COLOR_WARN)
		&"later":
			_caption.text = L10n.t("다음 증강까지 %d라운드") % caption_rounds
			_caption.add_theme_color_override("font_color", Color("e9ecef"))
		_:
			_caption.text = L10n.t("남은 증강 없음")
			_caption.add_theme_color_override("font_color", Color("868e96"))
	tooltip_text = L10n.t("증강은 1라운드와 그 뒤 3라운드마다(4·7·10…) 나옵니다. 별 표시는 초증강·법전까지 섞이는 라운드(7라운드부터)입니다.")
	queue_redraw()


func _chip_rect(index: int) -> Rect2:
	return Rect2(Vector2(CAPTION_WIDTH + float(index) * (CHIP_SIZE.x + CHIP_GAP), 3.0), CHIP_SIZE)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	for index: int in rounds.size():
		var entry: Dictionary = rounds[index]
		var box: Rect2 = _chip_rect(index)
		var is_current: bool = bool(entry["current"])
		var is_draft: bool = bool(entry["draft"])
		var is_super: bool = bool(entry["super"])
		# 칩 사이 화살표
		if index > 0:
			var arrow_x: float = box.position.x - CHIP_GAP * 0.5
			var arrow_y: float = box.position.y + box.size.y * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(arrow_x - 3.0, arrow_y - 5.0), Vector2(arrow_x + 4.0, arrow_y), Vector2(arrow_x - 3.0, arrow_y + 5.0)]), Color(1, 1, 1, 0.35))
		var fill: Color = Color("141a2a")
		var border: Color = Color("4c566a")
		var width: int = 2
		if is_draft:
			fill = Color("4a3d12")
			border = COLOR_SUPER if is_super else COLOR_GOLD
			width = 3
		if is_current:
			fill = fill.lightened(0.12)
			border = Color.WHITE if not is_draft else border.lightened(0.35)
			width = 4
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = border
		style.set_border_width_all(width)
		style.set_corner_radius_all(8)
		if is_current:
			style.shadow_color = Color(border.r, border.g, border.b, 0.55)
			style.shadow_size = 6
		draw_style_box(style, box)
		var number: String = str(int(entry["round"])) + "R"
		var number_color: Color = Color("ffffff") if is_current else (COLOR_GOLD if is_draft else Color("adb5bd"))
		if is_draft:
			_draw_gift(box.position + Vector2(box.size.x * 0.5, 11.0), is_current)
			draw_string_outline(font, box.position + Vector2(0.0, box.size.y - 4.0), number, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, 3, Color("0d1018"))
			draw_string(font, box.position + Vector2(0.0, box.size.y - 4.0), number, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, number_color)
		else:
			draw_string_outline(font, box.position + Vector2(0.0, box.size.y * 0.5 + 6.0), number, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, 3, Color("0d1018"))
			draw_string(font, box.position + Vector2(0.0, box.size.y * 0.5 + 6.0), number, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, number_color)
		if is_super:
			_draw_star(box.position + Vector2(box.size.x - 6.0, 6.0), 6.5)


## 작은 선물 상자 (몸통·뚜껑·리본·매듭).
func _draw_gift(center: Vector2, big: bool) -> void:
	var scale_factor: float = 1.15 if big else 1.0
	var body := Rect2(center + Vector2(-8.0, -1.0) * scale_factor, Vector2(16.0, 9.0) * scale_factor)
	var lid := Rect2(center + Vector2(-9.0, -5.0) * scale_factor, Vector2(18.0, 5.0) * scale_factor)
	draw_rect(body, Color("e03131"))
	draw_rect(lid, Color("ff6b6b"))
	draw_rect(Rect2(Vector2(center.x - 1.5 * scale_factor, lid.position.y), Vector2(3.0 * scale_factor, body.end.y - lid.position.y)), Color("fff3bf"))
	draw_colored_polygon(PackedVector2Array([Vector2(center.x, lid.position.y), Vector2(center.x - 5.0 * scale_factor, lid.position.y - 4.0 * scale_factor), Vector2(center.x - 1.0, lid.position.y - 0.5)]), Color("fff3bf"))
	draw_colored_polygon(PackedVector2Array([Vector2(center.x, lid.position.y), Vector2(center.x + 5.0 * scale_factor, lid.position.y - 4.0 * scale_factor), Vector2(center.x + 1.0, lid.position.y - 0.5)]), Color("fff3bf"))


func _draw_star(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for index: int in 10:
		var angle: float = -PI / 2.0 + TAU * float(index) / 10.0
		var length: float = radius if index % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	draw_colored_polygon(points, COLOR_SUPER)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("3b0d1d"), 1.2, true)
