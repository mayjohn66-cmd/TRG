# File: res://core_engine/tools/base_judgment_tool.gd
# Class: class_name BaseJudgmentTool
# Role: 판정 도구 추상 클래스. 이동 거리(Step)와 재굴림(Re-roll)만을 산출하며, 모든 난수는 호스트의 RNG를 주입받는다.
class_name BaseJudgmentTool
extends RefCounted

var tool_id: StringName = &""
var display_name: String = ""


## 도구를 한 번 굴린다. 서브클래스가 반드시 구현한다.
func roll(_rng: RandomNumberGenerator) -> RollResult:
	push_error("BaseJudgmentTool.roll()은 서브클래스에서 구현해야 합니다: %s" % tool_id)
	return RollResult.make(tool_id, 0)


## 매 턴 TURN_BEGIN에서 호출된다 (할리갈리 카드 공개 등). 기본은 아무것도 하지 않는다.
func on_turn_begin(_rng: RandomNumberGenerator) -> void:
	return


## 연속 시도형 도구(러시안 룰렛)의 중간 상태가 남아 있는가.
func has_pending_state() -> bool:
	return false


## 연속 시도형 도구에서 지금까지의 누적치를 확정한다. 확정할 것이 없으면 null.
func cash_out() -> RollResult:
	return null


## 호스트 RNG로 0..population-1 중 중복 없이 count개를 뽑는다 (부분 Fisher-Yates).
static func sample_distinct(rng: RandomNumberGenerator, population: int, count: int) -> Array[int]:
	var pool: Array[int] = []
	for i: int in population:
		pool.append(i)
	var picked: Array[int] = []
	for i: int in count:
		var j: int = rng.randi_range(i, population - 1)
		var swap: int = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
		picked.append(pool[i])
	return picked
