# File: res://core_engine/entities/board_entity.gd
# Class: class_name BoardEntity
# Role: 보드 위를 움직이는 모든 객체(플레이어 기물·중립 NPC)의 공통 부모 노드. 현재 타일과 빽도 역추적용 step_history 스택을 보관한다
class_name BoardEntity
extends Node2D

var entity_id: int = 0
## 소유 플레이어 ID. 중립 NPC는 소환자 ID(없으면 -1).
var owner_id: int = -1
var current_tile_idx: int = 0
## 거쳐 온 타일 스택. 마지막 원소가 현재 타일이며, 후진(빽도)은 이 스택을 역추적한다.
var step_history: Array[int] = [0]


func reset_position() -> void:
	place_at(GameEnums.GOAL_TILE)


## 이력을 비우고 해당 타일에 새로 놓는다 (출발선 복귀·워프·소환).
func place_at(tile: int) -> void:
	current_tile_idx = tile
	step_history = [tile]
