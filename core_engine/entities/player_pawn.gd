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
## ACT_04 발동 조건: 직전 이동이 '출발선(0번)에서의 후퇴'였는가.
var retreated_from_start: bool = false
## 업기: 나를 업고 있는 말(없으면 null) / 내가 업고 있는 말들.
var carrier: PlayerPawn = null
var carried: Array[PlayerPawn] = []
## TRP_02 나락: 앞으로 이 말을 움직일 수 없는 내 턴의 수. 내 턴이 시작될 때마다 1씩 줄고, 그 턴에는 선택할 수 없다.
var restrained_turns: int = 0
var blocked_this_turn: bool = false
## TRP_04 무인도: 짝수 눈금이 나올 때까지 갇혀 움직이지 못한다.
var is_imprisoned: bool = false


## 체스 3호기 비숍의 고유 능력: 5번·10번을 멈추지 않고 스쳐 지나가도 지름길로 꺾는다.
func turns_at_corner_when_passing() -> bool:
	return kind == GameEnums.PawnKind.CHESS and unit_no == 3


## 체스 2호기 나이트의 고유 능력: 중간 칸의 설치물(함정·호텔)을 무시하고 도착 칸만 판정한다 (나이트 점프).
func jumps_over_attachments() -> bool:
	return kind == GameEnums.PawnKind.CHESS and unit_no == 2


## 기본 말이 세트의 다음 호기로 영구 진화한다.
func evolve(new_kind: GameEnums.PawnKind, new_unit_no: int) -> void:
	kind = new_kind
	unit_no = new_unit_no


func display_label() -> String:
	return PawnCatalog.unit_label(kind, unit_no)


func is_on_board() -> bool:
	return not is_finished


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
	retreated_from_start = false
	is_imprisoned = false
	restrained_turns = 0
	blocked_this_turn = false
	carrier = null
	carried.clear()
