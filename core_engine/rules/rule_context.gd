# File: res://core_engine/rules/rule_context.gd
# Class: class_name RuleContext
# Role: 인터셉터 파이프라인 페이로드. 법전의 교칙들이 눈금·이동 허용 플래그·경로를 순서대로 변조하며 통과시키는 데이터 객체
class_name RuleContext
extends RefCounted

## trigger_timing에 쓰는 표준 값.
const ON_DICE_ROLL: String = "ON_DICE_ROLL"
const ON_MOVE_CALC: String = "ON_MOVE_CALC"
const ON_CAPTURE: String = "ON_CAPTURE"
const ON_TURN_END: String = "ON_TURN_END"

## 지금 파이프라인이 실행 중인 시점. RuleBookManager.process_context()가 이 값과 일치하는 교칙만 호출한다.
var trigger_timing: String = ""
## 행동 주체 플레이어 ID.
var actor_id: int = -1
## 원본 및 변조된 이동 칸수 (윷의 빽도·청개구리 저주처럼 음수 가능).
var dice_value: int = 0
## 코너 지름길 진입 허용 여부 (LAW_01).
var allow_shortcut: bool = true
## 아군 말 업기 허용 여부 (LAW_02).
var allow_stacking: bool = true
## true면 결승선을 넘는 눈금은 남은 만큼 뒤로 튕겨 나온다 (LAW_08).
var exact_goal_required: bool = false
## 이번 이동에서 밟은 타일 인덱스들 (MoveExecutor가 한 칸씩 채운다).
var path_nodes: Array[int] = []
## true로 만들면 해당 시점의 동작(굴림 확정 / 이동 / 잡기)이 취소된다. 시점 처리가 끝나면 호출 측이 초기화한다.
var is_canceled: bool = false
## 교칙·콘텐츠 계층이 자유롭게 주고받는 부가 데이터.
var metadata: Dictionary = {}

# --- 엔진 확장 필드: 이동 실행기와 후속 효과가 사용한다 ---
var state: GameState = null
var pawn: PlayerPawn = null
## 판정 도구가 낸 원본 눈금 (법전 통과 전).
var raw_roll: int = 0
## +1: 정방향, -1: 우노 리버스 등으로 전체 역주행 중.
var direction: int = 1
var capturer: PlayerPawn = null
var captured_pawns: Array[PlayerPawn] = []
var capture_extra_turn: bool = true
var capture_charge_steps: int = 0
## 돌진(LAW_05) 이동 안에서 돌진이 연쇄되지 않도록 하는 깊이.
var charge_depth: int = 0
## 교칙이 요청한 후속 커맨드. MoveExecutor가 이동 정산 뒤 순서대로 실행한다.
var effects: Array[GameCommand] = []


## 같은 이동 플래그를 물려받는 후속 이동(돌진 등)용 컨텍스트를 만든다.
func make_follow_up(follow_steps: int) -> RuleContext:
	var follow := RuleContext.new()
	follow.state = state
	follow.actor_id = actor_id
	follow.pawn = pawn
	follow.raw_roll = follow_steps
	follow.dice_value = follow_steps
	follow.direction = 1
	follow.allow_shortcut = allow_shortcut
	follow.allow_stacking = allow_stacking
	follow.exact_goal_required = exact_goal_required
	follow.charge_depth = charge_depth + 1
	return follow
