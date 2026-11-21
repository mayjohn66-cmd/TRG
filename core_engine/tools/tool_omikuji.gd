# File: res://core_engine/tools/tool_omikuji.gd
# Class: class_name ToolOmikuji
# Role: 오미쿠지 뽑기통 (TRPG 확장) - 통을 흔들어 점괘 막대를 뽑는다. 점괘마다 이동 칸수가 정해져 있고 대길은 한 번 더 굴리며, 대흉은 이동 없이 턴이 끝난다
class_name ToolOmikuji
extends BaseJudgmentTool

## [키, 이름, 칸수, 가중치(합 100)]. 대길 = 한 번 더, 대흉 = 0칸 + 턴 종료.
const FORTUNES: Array = [
	[&"great", "대길", 8, 8],
	[&"mid", "중길", 6, 17],
	[&"small", "소길", 4, 25],
	[&"good", "길", 3, 25],
	[&"late", "말길", 2, 15],
	[&"bad", "흉", 1, 5],
	[&"worst", "대흉", 0, 5],
]
const GREAT_STEPS: int = 8


func _init() -> void:
	tool_id = &"DICE_OMIKUJI"
	display_name = "오미쿠지 뽑기통"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var pick: int = rng.randi_range(1, 100)
	var acc: int = 0
	for entry: Array in FORTUNES:
		acc += int(entry[3])
		if pick <= acc:
			return of_fortune(StringName(entry[0]), rng.randi_range(1, 99))
	return of_fortune(&"good", 1)


## 점괘 키로 결과를 만든다 (테스트·연출 공용). ticket은 막대에 적힌 번호(연출용).
static func of_fortune(key: StringName, ticket: int = 1) -> RollResult:
	var name_ko: String = "길"
	var steps: int = 3
	for entry: Array in FORTUNES:
		if StringName(entry[0]) == key:
			name_ko = str(entry[1])
			steps = int(entry[2])
	var result: RollResult = RollResult.make(&"DICE_OMIKUJI", steps, {"fortune": key, "label": name_ko, "ticket": ticket})
	if key == &"great":
		result.reroll = true
	elif key == &"worst":
		result.ends_turn = true
	return result


static func caption(details: Dictionary, steps: int) -> String:
	var key: StringName = StringName(details.get("fortune", &"good"))
	var label: String = str(details.get("label", "길"))
	if key == &"great":
		return "★%s! %d칸 + 한 번 더" % [label, steps]
	if key == &"worst":
		return "%s… 0칸, 턴 종료" % label
	return "%s → %d칸" % [label, steps]
