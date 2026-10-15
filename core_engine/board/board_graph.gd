# File: res://core_engine/board/board_graph.gd
# Class: class_name BoardGraph
# Role: 29타일 방향성 그래프. 윷놀이 표준 분기 규칙(22번 통과/정지, 코너 정지 진입, 비숍 예외), step_history 후진, BFS 최단 경로 탐색을 제공한다
class_name BoardGraph
extends Node

var tiles: Array[TileNode] = []
## 각 타일에서 결승(0번)까지의 최단 칸 수 (진행도 비교용).
var _distance_to_goal: Array[int] = []
## 방향을 무시한 인접 타일 목록 (폭발 반경 같은 거리 계산용).
var _undirected: Array[Array] = []

## 후진 시 step_history에 되짚을 이력이 없을 때 쓰는 구조상 직전 타일.
const _DEFAULT_PREVIOUS: Dictionary = {
	0: 19, 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 9,
	11: 10, 12: 11, 13: 12, 14: 13, 15: 14, 16: 15, 17: 16, 18: 17, 19: 18,
	20: 5, 21: 20, 22: 21, 23: 22, 24: 23, 25: 10, 26: 25, 27: 22, 28: 27,
}


func _init() -> void:
	_init_29_tiles()
	_build_distance_table()
	_build_undirected()


## 0~28번 타일과 모든 간선을 초기화한다.
##   외곽  : 0 -> 1 -> ... -> 19 -> 0
##   지름길1: 5 =(shortcut)=> 20 -> 21 -> 22 -> 23 -> 24 -> 15
##   지름길2: 10 =(shortcut)=> 25 -> 26 -> 22 =(shortcut)=> 27 -> 28 -> 0
func _init_29_tiles() -> void:
	tiles.clear()
	for index: int in GameEnums.TILE_COUNT:
		tiles.append(TileNode.new(index))

	# 외곽 트랙 0~19번. 19번의 next_default는 0번이다.
	for index: int in GameEnums.OUTER_TRACK_SIZE:
		tiles[index].next_default = (index + 1) % GameEnums.OUTER_TRACK_SIZE

	# 타일 종류.
	tiles[GameEnums.GOAL_TILE].tile_type = TileNode.TileType.START_GOAL
	for index: int in GameEnums.BAKERY_TILES:
		tiles[index].tile_type = TileNode.TileType.BAKERY
	for index: int in GameEnums.PORTAL_TILES:
		tiles[index].tile_type = TileNode.TileType.PORTAL

	# 대각선 지름길의 기본 진행 방향. 체인의 마지막 타일은 이미 다른 연결을 갖고 있으므로 건드리지 않는다.
	_chain_default([20, 21, 22, 23, 24, GameEnums.CORNER_MERGE])
	_chain_default([25, 26, GameEnums.CENTER_TILE])
	_chain_default([27, GameEnums.LAST_SHORTCUT_TILE, GameEnums.GOAL_TILE])

	# 분기점: 5번 -> 20번, 10번 -> 25번, 중앙 22번 -> 27번(최단 결승 루트).
	tiles[GameEnums.CORNER_SHORTCUT_1].next_shortcut = 20
	tiles[GameEnums.CORNER_SHORTCUT_2].next_shortcut = 25
	tiles[GameEnums.CENTER_TILE].next_shortcut = 27


func _chain_default(route: Array[int]) -> void:
	for i: int in route.size() - 1:
		tiles[route[i]].next_default = route[i + 1]


## 모든 타일이 유효한 next_default를 갖고, 모든 간선이 0~28 범위 안에 있는지 검사한다.
func is_graph_valid() -> bool:
	if tiles.size() != GameEnums.TILE_COUNT:
		return false
	for tile: TileNode in tiles:
		if not is_valid_tile(tile.next_default):
			return false
		if tile.next_shortcut != -1 and not is_valid_tile(tile.next_shortcut):
			return false
	return true


## 구조상 직전 타일(이력이 없을 때의 후진 목적지).
func default_previous(tile: int) -> int:
	return _DEFAULT_PREVIOUS[tile]


## 간선 방향과 무관하게 center에서 radius칸 이내인 모든 타일(자기 자신 포함).
func tiles_within(center: int, radius: int) -> Array[int]:
	var distance: Dictionary = {center: 0}
	var queue: Array[int] = [center]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		if int(distance[current]) >= radius:
			continue
		for neighbor: int in _undirected[current]:
			if not distance.has(neighbor):
				distance[neighbor] = int(distance[current]) + 1
				queue.append(neighbor)
	var result: Array[int] = []
	for tile: int in distance.keys():
		result.append(tile)
	result.sort()
	return result


## 설치물이 놓인 타일 번호. 어느 타일에도 없으면 -1.
func tile_of_attachment(attachment: TileAttachment) -> int:
	for tile: TileNode in tiles:
		if tile.attachments.has(attachment):
			return tile.tile_id
	return -1


func get_tile(index: int) -> TileNode:
	return tiles[index]


func is_valid_tile(index: int) -> bool:
	return index >= 0 and index < GameEnums.TILE_COUNT


# ---------------------------------------------------------------------------
# 전진 / 후진 한 칸 규칙
# ---------------------------------------------------------------------------

## 현재 타일에서 전진 한 칸의 도착 타일.
## first_step: 이 이동의 첫 걸음인가 (= 현재 타일에 '정확히 멈춰 있다가' 출발하는가).
## allow_shortcut: LAW_01 등으로 코너 지름길이 막혀 있지 않은가 (5, 10번에만 적용).
## turns_at_corner_when_passing: 비숍처럼 코너를 스쳐도 지름길로 꺾는 기물인가.
func next_tile_forward(
		current: int,
		previous: int,
		first_step: bool,
		allow_shortcut: bool,
		turns_at_corner_when_passing: bool) -> int:
	var node: TileNode = tiles[current]
	match current:
		GameEnums.CORNER_SHORTCUT_1, GameEnums.CORNER_SHORTCUT_2:
			if allow_shortcut and (first_step or turns_at_corner_when_passing):
				return node.next_shortcut
		GameEnums.CENTER_TILE:
			# 22번에 정확히 멈췄다 출발: 경로와 무관하게 최단 결승 루트(27).
			if first_step:
				return node.next_shortcut
			# 22번을 통과: 진입 방향 유지 (21 -> 23, 26 -> 27).
			if previous == 26:
				return node.next_shortcut
	return node.next_default


## 커서를 전진 한 칸 이동시킨다.
func advance_forward(cursor: PathCursor, first_step: bool, allow_shortcut: bool, turns_at_corner_when_passing: bool) -> void:
	var destination: int = next_tile_forward(
			cursor.tile, cursor.previous_tile(), first_step, allow_shortcut, turns_at_corner_when_passing)
	cursor.history.append(destination)
	cursor.tile = destination
	cursor.started = true


## 커서를 후진 한 칸 이동시킨다. step_history 스택을 한 칸 pop해 온 길을 되짚고, 되짚을 이력이 없으면
## 구조상 직전 타일로 후퇴한다 (출발선 0번 -> 19번). 이력 직전이 28번이면 0번에서 28번으로 후퇴한다.
func advance_backward(cursor: PathCursor) -> void:
	var destination: int
	if cursor.history.size() >= 2:
		cursor.history.pop_back()
		destination = cursor.history.back()
	else:
		destination = _DEFAULT_PREVIOUS[cursor.tile]
		cursor.history = [destination]
	cursor.tile = destination
	cursor.started = true


## 실제 개체를 destination 타일로 한 칸 옮기고 step_history 스택을 갱신한다.
## 전진(간선을 따라감)이면 true, 후진(온 길을 되짚음)이면 false를 반환한다.
## 후진은 스택을 한 칸 pop하고, 되짚을 이력이 없으면(0번 -> 19번 후퇴) 도착 타일로 새로 시작한다.
func commit_step(entity: BoardEntity, destination: int) -> bool:
	var is_forward: bool = tiles[entity.current_tile_idx].neighbors().has(destination)
	if is_forward:
		entity.step_history.append(destination)
	elif entity.step_history.size() >= 2 and entity.step_history[entity.step_history.size() - 2] == destination:
		entity.step_history.pop_back()
	else:
		entity.step_history = [destination]
	entity.current_tile_idx = destination
	return is_forward


## 개체를 온 길로 정확히 한 칸 되돌리고 도착 타일을 반환한다 (포석 무적에 막힌 침입자 등).
func step_back(entity: BoardEntity) -> int:
	var cursor: PathCursor = PathCursor.from_entity(entity, true)
	advance_backward(cursor)
	commit_step(entity, cursor.tile)
	return cursor.tile


## 설치물/도착 판정 없이 순수 경로만 미리 계산한다 (UI 하이라이트·AI 평가용).
## steps > 0: 전진. 시작 타일이 코너(5, 10)이고 ctx.allow_shortcut이면 next_shortcut으로 진입하고,
##            22번에서 출발하면 항상 최단 결승 루트로 나간다. 결승(0번) 도달 시 ctx.exact_goal_required가
##            꺼져 있으면 남은 칸을 버리고, 켜져 있으면 남은 칸만큼 step_history를 되짚어 튕겨 나온다.
## steps < 0: 후진(빽도). step_history를 역추적한다.
## steps는 이미 부호가 확정된 값이다 (전체 역주행 등은 호출 측이 부호에 반영한다).
func calculate_path(entity: BoardEntity, steps: int, ctx: RuleContext) -> Array[int]:
	var path: Array[int] = []
	var pawn: PlayerPawn = entity as PlayerPawn
	var turns_on_pass: bool = pawn != null and pawn.turns_at_corner_when_passing()
	var started: bool = pawn == null or pawn.has_left_start
	var cursor: PathCursor = PathCursor.from_entity(entity, started)
	var forward: bool = steps > 0
	var remaining: int = absi(steps)
	var first: bool = true
	while remaining > 0:
		if forward:
			advance_forward(cursor, first, ctx.allow_shortcut, turns_on_pass)
		else:
			advance_backward(cursor)
		first = false
		remaining -= 1
		path.append(cursor.tile)
		if forward and cursor.tile == GameEnums.GOAL_TILE:
			if remaining > 0 and ctx.exact_goal_required:
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


## start_idx 다음 칸부터 target_entities 중 가장 가까운 개체가 서 있는 타일까지의 BFS 최단 경로
## (카탄의 도적 추격용). 이미 같은 타일에 있거나 도달할 수 없으면 빈 배열이다.
func find_nearest_entity_bfs(start_idx: int, target_entities: Array[BoardEntity]) -> Array[int]:
	var target_tiles: Dictionary = {}
	for target: BoardEntity in target_entities:
		target_tiles[target.current_tile_idx] = true
	var route: Array[int] = []
	if target_tiles.is_empty() or target_tiles.has(start_idx):
		return route
	var parent: Dictionary = {start_idx: -1}
	var queue: Array[int] = [start_idx]
	var head: int = 0
	var found: int = -1
	while head < queue.size() and found == -1:
		var current: int = queue[head]
		head += 1
		for neighbor: int in tiles[current].neighbors():
			if parent.has(neighbor):
				continue
			parent[neighbor] = current
			if target_tiles.has(neighbor):
				found = neighbor
				break
			queue.append(neighbor)
	if found == -1:
		return route
	var node: int = found
	while node != start_idx:
		route.push_front(node)
		node = parent[node]
	return route


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
		for neighbor: int in tiles[current].neighbors():
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


func _build_undirected() -> void:
	_undirected.clear()
	for index: int in GameEnums.TILE_COUNT:
		var neighbors: Array[int] = []
		_undirected.append(neighbors)
	for tile: TileNode in tiles:
		for neighbor: int in tile.neighbors():
			if not _undirected[tile.tile_id].has(neighbor):
				_undirected[tile.tile_id].append(neighbor)
			if not _undirected[neighbor].has(tile.tile_id):
				_undirected[neighbor].append(tile.tile_id)


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
			if _distance_to_goal[candidate.tile_id] == -1 and candidate.neighbors().has(current):
				_distance_to_goal[candidate.tile_id] = _distance_to_goal[current] + 1
				queue.append(candidate.tile_id)
