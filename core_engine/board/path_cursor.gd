# File: res://core_engine/board/path_cursor.gd
# Class: class_name PathCursor
# Role: 경로 계산용 가상 위치 커서(현재 타일 + step_history). 실제 기물을 건드리지 않고 한 칸씩 전/후진 시뮬레이션한다.
class_name PathCursor
extends RefCounted

var tile: int = 0
## 직전까지 거쳐 온 타일들. 마지막 원소가 직전 타일이다 (step_history).
var history: Array[int] = []
var started: bool = false


static func from_entity(entity: BoardEntity, has_started: bool = false) -> PathCursor:
	var cursor := PathCursor.new()
	cursor.tile = entity.tile_index
	cursor.history.assign(entity.step_history)
	cursor.started = has_started
	return cursor


func previous_tile() -> int:
	return history.back() if not history.is_empty() else -1
