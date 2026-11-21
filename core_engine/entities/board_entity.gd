# File: res://core_engine/entities/board_entity.gd
# Class: class_name BoardEntity
# Role: 보드 위를 움직이는 모든 객체(플레이어 기물·중립 NPC)의 공통 부모 노드. 현재 타일과 빽도 역추적용 step_history 스택을 보관한다
class_name BoardEntity
extends Node2D

## step_history 최대 길이 (후진·낙하는 최근 몇 칸만 쓴다).
const MAX_STEP_HISTORY: int = 64

var entity_id: int = 0
## 소유 플레이어 ID. 중립 NPC는 소환자 ID(없으면 -1).
var owner_id: int = -1
var current_tile_idx: int = 0
## 거쳐 온 타일 스택. 마지막 원소가 현재 타일이며, 후진(빽도)은 이 스택을 역추적한다.
var step_history: Array[int] = [0]


func reset_position() -> void:
	place_at(GameEnums.GOAL_TILE)


## 지나온 타일 이력에 한 칸을 더한다. 후진은 최근 몇 칸만 되짚으므로 오래된 이력은 버려 판이 길어져도 커지지 않게 한다
## (매 턴 스냅샷이 이력을 복사하므로 무한히 쌓이면 메모리가 계속 는다).
func push_step(tile: int) -> void:
	step_history.append(tile)
	if step_history.size() > MAX_STEP_HISTORY:
		step_history = step_history.slice(step_history.size() - MAX_STEP_HISTORY)


## 이력을 비우고 해당 타일에 새로 놓는다 (출발선 복귀·워프·소환).
func place_at(tile: int) -> void:
	current_tile_idx = tile
	step_history = [tile]
