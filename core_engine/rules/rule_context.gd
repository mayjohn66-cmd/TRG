# File: res://core_engine/rules/rule_context.gd
# Class: class_name RuleContext
# Role: 인터셉터 파이프라인 페이로드. 법전 교칙들이 눈금·이동 플래그·후속 효과를 순서대로 변조하며 통과시킨다.
class_name RuleContext
extends RefCounted

var state: GameState = null
var player_id: int = -1
var pawn: PlayerPawn = null

## 판정 도구가 낸 원본 눈금(부호 포함) / 법전 통과 후 최종 이동 칸수(부호 포함).
var raw_roll: int = 0
var steps: int = 0
## +1: 정방향, -1: 우노 리버스 등으로 전체 역주행 중.
var direction: int = 1

var shortcuts_enabled: bool = true
var stacking_allowed: bool = true
var goal_bounce: bool = false

## CAPTURE 스테이지에서 채워지는 잡기 정보.
var capturer: PlayerPawn = null
var captured_pawns: Array[PlayerPawn] = []
var capture_extra_turn: bool = true
var capture_charge_steps: int = 0
## 돌진(LAW_05) 이동 안에서 다시 돌진이 연쇄되지 않도록 하는 깊이.
var charge_depth: int = 0

## 법전이 요청한 후속 커맨드. MoveExecutor가 이동 완료 후 순서대로 실행한다.
var effects: Array[GameCommand] = []


## 같은 이동 플래그를 물려받는 후속 이동(돌진 등)용 컨텍스트를 만든다.
func make_follow_up(follow_steps: int) -> RuleContext:
	var follow := RuleContext.new()
	follow.state = state
	follow.player_id = player_id
	follow.pawn = pawn
	follow.raw_roll = follow_steps
	follow.steps = follow_steps
	follow.direction = 1
	follow.shortcuts_enabled = shortcuts_enabled
	follow.stacking_allowed = stacking_allowed
	follow.goal_bounce = goal_bounce
	follow.charge_depth = charge_depth + 1
	return follow
