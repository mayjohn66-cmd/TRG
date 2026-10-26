# File: res://core_engine/board/board_graph.gd
# Class: class_name BoardGraph
# Role: 24타일 사각 순환 트랙(부르마블형). 한 방향 단일 고리 전진, step_history 후진, BFS 최단 경로 탐색을 제공한다
class_name BoardGraph
extends Node

var tiles: Array[TileNode] = []
## 각 타일에서 결승(0번)까지의 최단 칸 수 (진행도 비교용).
var _distance_to_goal: Array[int] = []
## 방향을 무시한 인접 타일 목록 (폭발 반경 같은 거리 계산용).
var _undirected: Array[Array] = []

func _init() -> void:
	_init_24_tiles()
	_build_distance_table()
	_build_undirected()


## 0~(BoardSpec.tile_count-1)번 타일과 단일 순환 간선을 초기화한다 (코너는 BoardSpec.corner_tiles).
func _init_24_tiles() -> void:
	tiles.clear()
	for index: int in BoardSpec.tile_count:
		tiles.append(TileNode.new(index))
	for index: int in BoardSpec.tile_count:
		tiles[index].next_default = (index + 1) % BoardSpec.tile_count
	tiles[GameEnums.GOAL_TILE].tile_type = TileNode.TileType.START_GOAL
	for index: int in BoardSpec.bakery_tiles:
		tiles[index].tile_type = TileNode.TileType.BAKERY
	for index: int in BoardSpec.portal_tiles:
		tiles[index].tile_type = TileNode.TileType.PORTAL


## 모든 타일이 유효한 next_default를 갖고, 모든 간선이 보드 범위(BoardSpec.tile_count) 안에 있는지 검사한다.
func is_graph_valid() -> bool:
	if tiles.size() != BoardSpec.tile_count:
		return false
	for tile: TileNode in tiles:
		if not is_valid_tile(tile.next_default):
			return false
	return true


## 구조상 직전 타일(이력이 없을 때의 후진 목적지).
func default_previous(tile: int) -> int:
	return (tile - 1 + BoardSpec.tile_count) % BoardSpec.tile_count


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
	return index >= 0 and index < BoardSpec.tile_count


# ---------------------------------------------------------------------------
# 전진 / 후진 한 칸 규칙
# ---------------------------------------------------------------------------

## 현재 타일에서 전진 한 칸의 도착 타일 (단일 순환 트랙이라 분기가 없다).
func next_tile_forward(current: int) -> int:
	return tiles[current].next_default


## 커서를 전진 한 칸 이동시킨다.
func advance_forward(cursor: PathCursor) -> void:
	var destination: int = next_tile_forward(cursor.tile)
	cursor.history.append(destination)
	cursor.tile = destination
	cursor.started = true


## 커서를 후진 한 칸 이동시킨다. step_history 스택을 한 칸 pop해 온 길을 되짚고, 되짚을 이력이 없으면
## 구조상 직전 타일로 후퇴한다 (출발선 0번 -> 23번).
func advance_backward(cursor: PathCursor) -> void:
	var destination: int
	if cursor.history.size() >= 2:
		cursor.history.pop_back()
		destination = cursor.history.back()
	else:
		destination = default_previous(cursor.tile)
		cursor.history = [destination]
	cursor.tile = destination
	cursor.started = true


## 실제 개체를 destination 타일로 한 칸 옮기고 step_history 스택을 갱신한다.
## 전진(간선을 따라감)이면 true, 후진(온 길을 되짚음)이면 false를 반환한다.
## 후진은 스택을 한 칸 pop하고, 되짚을 이력이 없으면(0번 -> 23번 후퇴) 도착 타일로 새로 시작한다.
func commit_step(entity: BoardEntity, destination: int) -> bool:
	var is_forward: bool = tiles[entity.current_tile_idx].neighbors().has(destination)
	if is_forward:
		entity.push_step(destination)
	elif entity.step_history.size() >= 2 and entity.step_history[entity.step_history.size() - 2] == destination:
		entity.step_history.pop_back()
	else:
		entity.step_history = [destination]
	var as_pawn: PlayerPawn = entity as PlayerPawn
	if as_pawn != null and not is_forward and entity.current_tile_idx == GameEnums.GOAL_TILE:
		as_pawn.retreated_run = true
	entity.current_tile_idx = destination
	return is_forward


## 개체를 온 길로 정확히 한 칸 되돌리고 도착 타일을 반환한다 (포석 무적에 막힌 침입자 등).
func step_back(entity: BoardEntity) -> int:
	var cursor: PathCursor = PathCursor.from_entity(entity, true)
	advance_backward(cursor)
	commit_step(entity, cursor.tile)
	return cursor.tile


## 설치물/도착 판정 없이 순수 경로만 미리 계산한다 (UI 하이라이트·AI 평가용).
## steps > 0: 전진. 결승(0번) 도달 시 ctx.exact_goal_required가
##            꺼져 있으면 남은 칸을 버리고, 켜져 있으면 눈금이 남을 때 결승선 직전에서 멈춘다.
## steps < 0: 후진(NPC 전용 경로 계산에만 쓰인다. 플레이어 말은 뒤로 가지 않는다).
## steps는 이미 부호가 확정된 값이다 (전체 역주행 등은 호출 측이 부호에 반영한다).
func calculate_path(entity: BoardEntity, steps: int, ctx: RuleContext) -> Array[int]:
	var path: Array[int] = []
	var pawn: PlayerPawn = entity as PlayerPawn
	var started: bool = pawn == null or pawn.has_left_start
	var cursor: PathCursor = PathCursor.from_entity(entity, started)
	var forward: bool = steps > 0
	var remaining: int = absi(steps)
	while remaining > 0:
		if forward:
			advance_forward(cursor)
		else:
			advance_backward(cursor)
		remaining -= 1
		path.append(cursor.tile)
		var at_goal: bool = cursor.tile == GameEnums.GOAL_TILE or (pawn != null and ctx.state != null and TempoUp.in_zone(ctx.state, cursor.tile))  # 당겨진 결승선
		if forward and at_goal and (pawn == null or pawn.can_finish(ctx.state)):
			if remaining > 0 and ctx.exact_goal_required:
				path.pop_back()  # 눈금이 남으면 결승선에 못 들어가고 바로 앞 칸에서 멈춘다
			break
	return path


# ---------------------------------------------------------------------------
# 거리 / BFS
# ---------------------------------------------------------------------------

## 결승까지 남은 최단 칸 수. 출발선에서 아직 출발하지 않은 말은 한 바퀴(BoardSpec.tile_count칸)로 본다.
func distance_to_goal(tile: int, has_left_start: bool) -> int:
	if tile == GameEnums.GOAL_TILE and not has_left_start:
		return BoardSpec.tile_count
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
	for index: int in BoardSpec.tile_count:
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
	_distance_to_goal.resize(BoardSpec.tile_count)
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
