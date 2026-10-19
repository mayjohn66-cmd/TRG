# File: res://core_engine/entities/player_pawn.gd
# Class: class_name PlayerPawn
# Role: 플레이어 소유 기물(윷말·체스·장기·미니카·바둑돌). 출발/완주/업기 상태와 기물 종류별 이동 예외를 보관한다.
class_name PlayerPawn
extends BoardEntity

## 기물 세트와 세트 안에서의 호기(1~4). 진화하지 않은 기본 말은 BASIC / 0이다.
var kind: GameEnums.PawnKind = GameEnums.PawnKind.BASIC
var unit_no: int = 0
## 1~4번 기물 슬롯.
var slot: int = 1
var has_left_start: bool = false
var is_finished: bool = false
## 출발선(0번)에서 뒤로 물러난 뒤 아직 0번을 다시 지나가지 않은 말. 역주행 상태가 아니면 이 말은 완주할 수 없다 (한 바퀴를 더 돌아야 함).
var retreated_run: bool = false
## 🔥 리벤지 부스터: 보드 위에서 출발선으로 사출된 말이 다음에 출발할 때 눈금에 +4칸이 붙는다 (1회 출발 시 소모).
var revenge_boost: bool = false
## 업기: 나를 업고 있는 말(없으면 null) / 내가 업고 있는 말들.
var carrier: PlayerPawn = null
var carried: Array[PlayerPawn] = []
## TRP_02 나락: 앞으로 이 말을 움직일 수 없는 내 턴의 수. 내 턴이 시작될 때마다 1씩 줄고, 그 턴에는 선택할 수 없다.
var restrained_turns: int = 0
var blocked_this_turn: bool = false
## TRP_04 무인도: 짝수 눈금이 나올 때까지 갇혀 움직이지 못한다.
var is_imprisoned: bool = false
## 쇼기 나리(成り) 승급 상태: 반환점(BoardSpec.halfway_tile) 이상을 밟으면 영구히 켜진다 (잡혀서 출발선으로 가도 유지된다). 이동할 때마다 +1칸.
var promoted: bool = false
## 1회용 고유 필살기를 이미 썼는가 (게임당 기물별 1회, 잡혀서 출발선으로 가도 되살아나지 않는다).
var skill_used: bool = false


## 이 말의 세부 기물 (호기에서 정해지며, 승진한 체스 퀸은 5번째 호기다).
func sub_type() -> GameEnums.PawnSubType:
	return PawnCatalog.sub_type_of(kind, unit_no)


## 체스 비숍·쇼기 각행의 고유 능력: 출발선 외 코너(BoardSpec.bonus_corner_tiles)를 스치거나 멈추면 이동 거리 +2칸.
func gets_corner_bonus() -> bool:
	var sub: GameEnums.PawnSubType = sub_type()
	return sub == GameEnums.PawnSubType.CHESS_BISHOP or sub == GameEnums.PawnSubType.SHOGI_KAKU


## 체스 나이트(와 퀸)의 고유 능력: 중간 칸의 설치물(함정·호텔)을 무시하고 도착 칸만 판정한다 (나이트 점프).
func jumps_over_attachments() -> bool:
	var sub: GameEnums.PawnSubType = sub_type()
	return sub == GameEnums.PawnSubType.CHESS_KNIGHT or sub == GameEnums.PawnSubType.CHESS_QUEEN


## 기본 말이 세트의 다음 호기로 영구 진화한다.
func evolve(new_kind: GameEnums.PawnKind, new_unit_no: int) -> void:
	kind = new_kind
	unit_no = new_unit_no


func display_label() -> String:
	return PawnCatalog.name_of_pawn(kind, unit_no, promoted)


## 보드·카드에 보이는 한 글자 라벨 (나리 승급한 쇼기 기물은 승급 글자).
func letter() -> String:
	return PawnCatalog.letter_of_pawn(kind, unit_no, promoted)


## 쇼기 기물 하나가 나리 승급했는가 (승급 이동 보너스 판정용).
func is_promoted_shogi() -> bool:
	return promoted and kind == GameEnums.PawnKind.SHOGI


func is_on_board() -> bool:
	return not is_finished


## 지금 완주 처리가 가능한가: 출발선에서 후퇴한 말은 역주행 상태가 아닌 한 0번을 한 번 더 지나가야 한다.
func can_finish(state: GameState) -> bool:
	return not retreated_run or (state != null and state.reverse_move_rounds_left > 0)


## 직접 선택해 움직일 수 있는 말인가 (업혀 있는 말은 업은 말만 움직인다).
func is_selectable() -> bool:
	return not is_finished and carrier == null and not blocked_this_turn


## 윷놀이 기물(YUT)의 고유 능력 [선택적 업기]: 업기는 두 말 중 하나가 내 윷놀이 기물일 때만 가능하다
## (상대가 다른 종류의 기물이어도 된다). 일반 기물끼리는 같은 타일에 각각 따로 공존한다.
## 법전(LAW_02)은 이 판정보다 우선하며 MoveExecutor가 따로 검사한다.
func can_stack_with(other: PlayerPawn) -> bool:
	if other == self or other.is_finished or is_finished:
		return false
	if other.owner_id != owner_id:
		return false
	return kind == GameEnums.PawnKind.YUT or other.kind == GameEnums.PawnKind.YUT


## 나(업은 말)와 내가 업은 모든 말.
func stack_members() -> Array[PlayerPawn]:
	var members: Array[PlayerPawn] = [self]
	members.append_array(carried)
	return members


func reset_to_start() -> void:
	reset_position()
	has_left_start = false
	retreated_run = false
	is_imprisoned = false
	restrained_turns = 0
	blocked_this_turn = false
	carrier = null
	carried.clear()
