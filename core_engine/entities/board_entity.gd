# File: res://core_engine/entities/board_entity.gd
# Class: class_name BoardEntity
# Role: 보드 위를 움직이는 모든 객체(플레이어 기물·중립 NPC)의 공통 부모. 위치와 step_history를 보관한다.
class_name BoardEntity
extends RefCounted

var id: int = 0
## 소유 플레이어 ID. 중립 NPC는 소환자 ID(없으면 -1).
var owner_id: int = -1
var tile_index: int = 0
## 직전까지 거쳐 온 타일들 (마지막 원소 = 직전 타일). 후진·22번 분기 판정의 근거.
var step_history: Array[int] = []


func reset_position() -> void:
	tile_index = GameEnums.GOAL_TILE
	step_history.clear()
