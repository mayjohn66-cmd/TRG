# File: res://core_engine/entities/player_pawn.gd
# Class: class_name PlayerPawn
# Role: 플레이어 소유 기물(윷말·체스·장기·미니카·바둑돌). 출발/완주/업기 상태와 기물 종류별 이동 예외를 보관한다.
class_name PlayerPawn
extends BoardEntity

var kind: GameEnums.PawnKind = GameEnums.PawnKind.YUT
## 1~4번 기물 슬롯.
var slot: int = 1
var has_left_start: bool = false
var is_finished: bool = false
## ACT_04 발동 조건: 직전 이동이 '출발선(0번)에서의 후퇴'였는가.
var retreated_from_start: bool = false
## 업기: 나를 업고 있는 말(없으면 null) / 내가 업고 있는 말들.
var carrier: PlayerPawn = null
var carried: Array[PlayerPawn] = []


## 비숍 고유 능력: 5번·10번을 멈추지 않고 스쳐 지나가도 지름길로 꺾는다.
func turns_at_corner_when_passing() -> bool:
	return kind == GameEnums.PawnKind.CHESS_BISHOP


func is_on_board() -> bool:
	return not is_finished


## 직접 선택해 움직일 수 있는 말인가 (업혀 있는 말은 업은 말만 움직인다).
func is_selectable() -> bool:
	return not is_finished and carrier == null


## 기물 고유 능력상의 업기 가능 여부. 법전(LAW_02)은 이 판정보다 우선하며 MoveExecutor가 따로 검사한다.
## 윷말은 다른 종류의 기물과도 합체할 수 있고, 그 외 기물은 같은 종류끼리만 업는다.
func can_stack_with(other: PlayerPawn) -> bool:
	if other == self or other.is_finished or is_finished:
		return false
	if other.owner_id != owner_id:
		return false
	return kind == other.kind or kind == GameEnums.PawnKind.YUT or other.kind == GameEnums.PawnKind.YUT


## 나(업은 말)와 내가 업은 모든 말.
func stack_members() -> Array[PlayerPawn]:
	var members: Array[PlayerPawn] = [self]
	members.append_array(carried)
	return members


func reset_to_start() -> void:
	reset_position()
	has_left_start = false
	retreated_from_start = false
	carrier = null
	carried.clear()
