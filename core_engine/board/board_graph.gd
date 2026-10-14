# File: res://core_engine/board/board_graph.gd
# Class: class_name BoardGraph
# Role: 29타일 방향성 그래프. 윷놀이 표준 분기 규칙(22번 통과/정지, 코너 정지 진입, 비숍 예외)과 BFS 최단 경로 탐색을 제공한다.
class_name BoardGraph
extends RefCounted

var tiles: Array[TileNode] = []
## 각 타일에서 결승(0번)까지의 최단 칸 수 (진행도 비교용). 출발선에 서 있는 미출발 말은 별도 처리.
var _distance_to_goal: Array[int] = []

## 후진 시 step_history가 비어 있을 때 쓰는 구조상 직전 타일.
const _DEFAULT_PREVIOUS: Dictionary = {
	0: 19, 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 9,
	11: 10, 12: 11, 13: 12, 14: 13, 15: 14, 16: 15, 17: 16, 18: 17, 19: 18,
	20: 5, 21: 20, 22: 21, 23: 22, 24: 23, 25: 10, 26: 25, 27: 22, 28: 27,
}


func _init() -> void:
	_build_tiles()
	_build_edges()
	_build_distance_table()


func get_tile(index: int) -> TileNode:
	return tiles[index]


func is_valid_tile(index: int) -> bool:
	return index >= 0 and index < GameEnums.TILE_COUNT


# ---------------------------------------------------------------------------
# 전진 / 후진 한 칸 규칙
# ---------------------------------------------------------------------------

## 현재 타일에서 전진 한 칸의 도착 타일을 반환한다.
## first_step: 이 이동의 첫 걸음인가 (= 현재 타일에 '정확히 멈춰 있다가' 출발하는가).
## shortcuts_enabled: LAW_01 등으로 코너 지름길이 막혀 있지 않은가.
## turns_at_corner_when_passing: 비숍처럼 코너를 스쳐도 지름길로 꺾는 기물인가.
func next_tile_forward(
		current: int,
		previous: int,
		first_step: bool,
		shortcuts_enabled: bool,
		turns_at_corner_when_passing: bool) -> int:
	match current:
		GameEnums.CORNER_SHORTCUT_1:
			if shortcuts_enabled and (first_step or turns_at_corner_when_passing):
				return 20
			return 6
		GameEnums.CORNER_SHORTCUT_2:
			if shortcuts_enabled and (first_step or turns_at_corner_when_passing):
				return 25
			return 11
		GameEnums.LAST_OUTER_TILE:
			return GameEnums.GOAL_TILE
		20:
			return 21
		21:
			return GameEnums.CENTER_TILE
		GameEnums.CENTER_TILE:
			# 22번에 멈췄다가 출발: 무조건 최단 결승 루트.
			if first_step:
				return 27
			# 22번을 통과: 진입 방향 유지 (21 -> 23, 26 -> 27).
			if previous == 21:
				return 23
			return 27
		23:
			return 24
		24:
			return GameEnums.CORNER_MERGE
		25:
			return 26
		26:
			return GameEnums.CENTER_TILE
		27:
			return GameEnums.LAST_SHORTCUT_TILE
		GameEnums.LAST_SHORTCUT_TILE:
			return GameEnums.GOAL_TILE
	return current + 1


## 커서를 전진 한 칸 이동시킨다.
func advance_forward(cursor: PathCursor, first_step: bool, shortcuts_enabled: bool, turns_at_corner_when_passing: bool) -> void:
	var destination: int = next_tile_forward(
			cursor.tile, cursor.previous_tile(), first_step, shortcuts_enabled, turns_at_corner_when_passing)
	cursor.history.append(cursor.tile)
	cursor.tile = destination
	cursor.started = true


## 커서를 후진 한 칸 이동시킨다. step_history가 있으면 온 길을 되짚고, 없으면 구조상 직전 타일
## (0번 -> 19번)으로 후퇴한다. step_history 상 직전 타일이 28번이면 0번에서 28번으로 후퇴한다.
func advance_backward(cursor: PathCursor) -> void:
	var destination: int
	if not cursor.history.is_empty():
		destination = cursor.history.pop_back()
	else:
		destination = _DEFAULT_PREVIOUS[cursor.tile]
	cursor.tile = destination
	cursor.started = true


## 설치물/도착 판정 없이 순수 경로만 미리 계산한다 (UI 하이라이트·AI 평가용).
## 반환: 한 칸씩 밟는 타일 인덱스 순서. ctx.steps 부호와 ctx.direction을 반영하고,
## 결승 도달 시 ctx.goal_bounce가 꺼져 있으면 남은 칸은 버려진다.
func calculate_path(entity: BoardEntity, steps: int, ctx: RuleContext) -> Array[int]:
	var path: Array[int] = []
	var turns_on_pass: bool = entity is PlayerPawn and (entity as PlayerPawn).turns_at_corner_when_passing()
	var started: bool = entity is PlayerPawn and (entity as PlayerPawn).has_left_start
	var cursor: PathCursor = PathCursor.from_entity(entity, started)
	var signed_steps: int = steps * ctx.direction
	var forward: bool = signed_steps > 0
	var remaining: int = absi(signed_steps)
	var first: bool = true
	while remaining > 0:
		if forward:
			advance_forward(cursor, first, ctx.shortcuts_enabled, turns_on_pass)
		else:
			advance_backward(cursor)
		first = false
		remaining -= 1
		path.append(cursor.tile)
		if forward and cursor.tile == GameEnums.GOAL_TILE:
			if remaining > 0 and ctx.goal_bounce:
				forward = false
			else:
				break
	return path


# ---------------------------------------------------------------------------
# 거리 / BFS
# ---------------------------------------------------------------------------

## 결승까지 남은 최단 칸 수. 출발선에서 아직 출발하지 않은 말은 외곽 한 바퀴(20칸)로 본다.
func distance_to_goal(tile: int, has_left_start: bool) -> int:
	if tile == GameEnums.GOAL_TILE and not has_left_start:
		return GameEnums.OUTER_TRACK_SIZE
	return _distance_to_goal[tile]


## from_tile 다음 칸부터 to_tile까지의 BFS 최단 경로. 도달 불가이거나 같은 타일이면 빈 배열.
func shortest_path(from_tile: int, to_tile: int) -> Array[int]:
	var result: Array[int] = []
	if from_tile == to_tile:
		return result
	var parent: Dictionary = {from_tile: -1}
	var queue: Array[int] = [from_tile]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		if current == to_tile:
			break
		for neighbor: int in tiles[current].next_tiles:
			if not parent.has(neighbor):
				parent[neighbor] = current
				queue.append(neighbor)
	if not parent.has(to_tile):
		return result
	var node: int = to_tile
	while node != from_tile:
		result.push_front(node)
		node = parent[node]
	return result


func path_length(from_tile: int, to_tile: int) -> int:
	return shortest_path(from_tile, to_tile).size()


# ---------------------------------------------------------------------------
# 구성
# ---------------------------------------------------------------------------

func _build_tiles() -> void:
	tiles.clear()
	for i: int in GameEnums.TILE_COUNT:
		var tile_type: GameEnums.TileType = GameEnums.TileType.NORMAL
		if i == GameEnums.GOAL_TILE:
			tile_type = GameEnums.TileType.START_GOAL
		elif i == GameEnums.CORNER_SHORTCUT_1 or i == GameEnums.CORNER_SHORTCUT_2 or i == GameEnums.CORNER_MERGE:
			tile_type = GameEnums.TileType.CORNER
		elif GameEnums.BAKERY_TILES.has(i):
			tile_type = GameEnums.TileType.BAKERY
		elif GameEnums.PORTAL_TILES.has(i):
			tile_type = GameEnums.TileType.PORTAL
		elif i == GameEnums.CENTER_TILE:
			tile_type = GameEnums.TileType.CENTER
		elif i >= GameEnums.OUTER_TRACK_SIZE:
			tile_type = GameEnums.TileType.SHORTCUT
		tiles.append(TileNode.new(i, tile_type))


func _build_edges() -> void:
	for i: int in range(0, GameEnums.LAST_OUTER_TILE):
		_connect(i, i + 1)
	_connect(GameEnums.LAST_OUTER_TILE, GameEnums.GOAL_TILE)
	# 지름길 1: 5 -> 20 -> 21 -> 22 -> 23 -> 24 -> 15
	_connect(5, 20)
	_connect(20, 21)
	_connect(21, 22)
	_connect(22, 23)
	_connect(23, 24)
	_connect(24, 15)
	# 지름길 2: 10 -> 25 -> 26 -> 22 -> 27 -> 28 -> 0
	_connect(10, 25)
	_connect(25, 26)
	_connect(26, 22)
	_connect(22, 27)
	_connect(27, 28)
	_connect(28, GameEnums.GOAL_TILE)


func _connect(from_tile: int, to_tile: int) -> void:
	if not tiles[from_tile].next_tiles.has(to_tile):
		tiles[from_tile].next_tiles.append(to_tile)


func _build_distance_table() -> void:
	_distance_to_goal.clear()
	_distance_to_goal.resize(GameEnums.TILE_COUNT)
	_distance_to_goal.fill(-1)
	_distance_to_goal[GameEnums.GOAL_TILE] = 0
	var queue: Array[int] = [GameEnums.GOAL_TILE]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for candidate: TileNode in tiles:
			if _distance_to_goal[candidate.index] == -1 and candidate.next_tiles.has(current):
				_distance_to_goal[candidate.index] = _distance_to_goal[current] + 1
				queue.append(candidate.index)
