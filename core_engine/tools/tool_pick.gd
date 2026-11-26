# File: res://core_engine/tools/tool_pick.gd
# Class: class_name ToolPick
# Role: 판정 도구 "터치로 고르기" (1.3.1, 일본어 건의 "ヨットやブラックジャックのように、一部のダイス道具もタッチで選べるように").
#       뒷면으로 놓인 카드·패·막대·쿠키 등 N개 중 K개를 내가 직접 고른다. 뒷면은 굴릴 때 엔진이 섞어 둔 것과 같아서
#       어느 것을 고르든 확률은 그대로다 (결과는 평소처럼 GameState.rng로 정한다). 고른 자리는 결과에 "picked"로 실어
#       화면이 그 자리를 뒤집어 보여 준다 (타로는 뒤집히는 카드 자리 "flipped"도 고른 자리로).
#       봇·시간 초과·고르기 없이 굴리면 지금처럼 자동이다.
class_name ToolPick
extends RefCounted

## 도구 -> {count: 놓이는 뒷면 수, choose: 고를 수}
const SPECS: Dictionary = {
	&"DICE_TAROT": {"count": 5, "choose": 1},
	&"DICE_HWATU": {"count": 3, "choose": 2},  # 1.3.1: 3장 받고 2장 뒤집기
}
## 1.3.1: 홀덤은 받은 5장을 교환(ToolHoldem), 마작·오미쿠지·쿠키·아이스크림·캡슐은 굴린 뒤 손으로 꺼내는 장면(ToolHandGate·캡슐 레버)으로 바꿨다.


static func supports(tool_id: StringName) -> bool:
	return SPECS.has(tool_id)


static func count_of(tool_id: StringName) -> int:
	return int((SPECS.get(tool_id, {}) as Dictionary).get("count", 0))


static func choose_of(tool_id: StringName) -> int:
	return int((SPECS.get(tool_id, {}) as Dictionary).get("choose", 0))


## 굴림 행동의 pick 인자를 검사한다: 정확히 choose개, 서로 다른 0 ~ count-1 정수. 아니면 빈 배열 (고르기 없음으로 본다).
static func sanitize(tool_id: StringName, raw: Variant) -> Array[int]:
	var picks: Array[int] = []
	if not supports(tool_id) or not (raw is Array):
		return picks
	var count: int = count_of(tool_id)
	for value: Variant in raw:
		if not (value is int or value is float):
			return [] as Array[int]
		var index: int = int(value)
		if index < 0 or index >= count or picks.has(index):
			return [] as Array[int]
		picks.append(index)
	if picks.size() != choose_of(tool_id):
		return [] as Array[int]
	return picks


## 굴림 결과에 고른 자리를 싣는다 (확률·눈금은 바꾸지 않는다).
static func apply(result: RollResult, picks: Array[int]) -> void:
	if result == null or picks.is_empty():
		return
	result.details["picked"] = picks.duplicate()
	if result.tool_id == &"DICE_TAROT" and result.details.has("flipped"):
		result.details["flipped"] = picks[0]
