# File: res://core_engine/board/path_cursor.gd
# Class: class_name PathCursor
# Role: 경로 계산용 가상 위치 커서(현재 타일 + step_history 스택). 실제 기물을 건드리지 않고 한 칸씩 전/후진을 시뮬레이션한다
class_name PathCursor
extends RefCounted

var tile: int = 0
## 거쳐 온 타일 스택. 마지막 원소가 현재 타일이고, 그 앞이 직전 타일이다 (BoardEntity.step_history와 같은 규약).
var history: Array[int] = [0]
var started: bool = false


static func from_entity(entity: BoardEntity, has_started: bool = false) -> PathCursor:
	var cursor := PathCursor.new()
	cursor.tile = entity.current_tile_idx
	cursor.history.assign(entity.step_history)
	if cursor.history.is_empty() or cursor.history.back() != cursor.tile:
		cursor.history.assign([cursor.tile])
	cursor.started = has_started
	return cursor


## 직전 타일. 이력이 현재 타일뿐이면 -1.
func previous_tile() -> int:
	return history[history.size() - 2] if history.size() >= 2 else -1
