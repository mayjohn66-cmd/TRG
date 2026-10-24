# File: res://core_engine/tools/roll_result.gd
# Class: class_name RollResult
# Role: 판정 도구 한 번의 결과. 이동 거리(Step)와 재굴림(Re-roll)/턴 종료/연속 시도 여부를 담는다.
class_name RollResult
extends RefCounted

var tool_id: StringName = &""
## 이동 칸수 (윷의 빽도처럼 음수 가능).
var steps: int = 0
## true면 이 결과로 이동한 뒤(또는 이동 대기열에 쌓은 뒤) 추가 굴림을 한 번 더 한다.
var reroll: bool = false
## true면 이동 없이 즉시 턴 종료 (러시안 룰렛 실탄).
var ends_turn: bool = false
## true면 아직 확정되지 않았고 플레이어가 더 굴리거나(roll) 멈출(stop) 수 있다 (러시안 룰렛 누적).
var can_continue: bool = false
## 연출용 상세 정보 (카드 족보, 릴 결과, 룰렛 눈금 등).
var details: Dictionary = {}


static func make(id: StringName, move_steps: int, extra: Dictionary = {}) -> RollResult:
	var result := RollResult.new()
	result.tool_id = id
	result.steps = move_steps
	result.details = extra
	return result


func to_dict() -> Dictionary:
	return {
		"tool_id": tool_id,
		"steps": steps,
		"reroll": reroll,
		"ends_turn": ends_turn,
		"can_continue": can_continue,
		"details": details,
	}
