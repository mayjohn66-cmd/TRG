# File: res://core_engine/pawn_skills.gd
# Class: class_name PawnSkills
# Role: 기물별 1회용 고유 필살기(바둑 흑돌 알까기 슈팅·장기 차 직선 저격·체스 룩 단독 캐슬링·모노 비행기 직항 워프)의 사용 조건과 결과 계산. 상태를 바꾸지 않는 순수 함수라 UI 미리보기·AI 평가가 그대로 쓴다
class_name PawnSkills
extends RefCounted

## 비행기 직항 워프 목적지: 빵집 4곳과 코너 4곳(5·10·15번, 중앙 22번).
const PLANE_TARGETS: Array[int] = [3, 8, 13, 18, 5, 10, 15, 22]
## 알까기 슈팅: 파워 0~1이 날아가는 거리(보드 한 변 = 1)를 정하고, 지나가는 직선에서 충돌 반경 안의 적은 모두 탈락한다.
const SHOT_MIN_DISTANCE: float = 0.25
const SHOT_MAX_DISTANCE: float = 1.1
const SHOT_HIT_RADIUS: float = 0.075


static func has_skill(pawn: PlayerPawn) -> bool:
	return PawnCatalog.skill_of(pawn.sub_type()) != &""


## 이 기물이 지금 필살기를 쓸 수 있는 상태인가 (필살기 보유·미사용·보드 위에 출발해 있음·구속/감옥/업힘 아님).
static func is_ready(pawn: PlayerPawn) -> bool:
	return has_skill(pawn) and not pawn.skill_used and pawn.has_left_start and not pawn.is_finished \
			and pawn.carrier == null and pawn.current_tile_idx != GameEnums.GOAL_TILE \
			and not pawn.is_imprisoned and not pawn.blocked_this_turn and pawn.restrained_turns <= 0


## 룩 단독 캐슬링으로 위치를 맞바꿀 수 있는 내 다른 기물 (보드 위에 있고 룩과 다른 타일).
static func rook_partners(state: GameState, rook: PlayerPawn) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns_of(rook.owner_id):
		if pawn != rook and pawn.has_left_start and not pawn.is_finished and pawn.carrier == null \
				and pawn.current_tile_idx != GameEnums.GOAL_TILE and pawn.current_tile_idx != rook.current_tile_idx:
			result.append(pawn)
	return result


## 보병 모치고마 낙하로 불러낼 수 있는 내 말: 출발선에서 아직 출발하지 않은 대기 말(업히지 않은 것, 구속·감옥 아님).
static func drop_partners(state: GameState, fu: PlayerPawn) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns_of(fu.owner_id):
		if pawn != fu and not pawn.has_left_start and not pawn.is_finished and pawn.carrier == null \
				and not pawn.is_imprisoned and not pawn.blocked_this_turn and pawn.restrained_turns <= 0:
			result.append(pawn)
	return result


## 낙하 위치: 보병 바로 뒷칸 (온 길의 직전 타일). 뒷칸이 출발선이거나 없으면 앞칸(한 칸 전진한 타일). 둘 다 쓸 수 없으면 -1.
static func drop_tile(state: GameState, fu: PlayerPawn) -> int:
	var back: int = fu.step_history[fu.step_history.size() - 2] if fu.step_history.size() >= 2 else state.board.default_previous(fu.current_tile_idx)
	if back != GameEnums.GOAL_TILE and back != fu.current_tile_idx and state.board.is_valid_tile(back):
		return back
	var ahead: Array[int] = state.board.calculate_path(fu, 1, RuleContext.new())
	if not ahead.is_empty() and ahead[0] != GameEnums.GOAL_TILE:
		return ahead[0]
	return -1


## 비행기가 날아갈 수 있는 타일 (지금 서 있는 타일 제외).
static func plane_targets(pawn: PlayerPawn) -> Array[int]:
	var result: Array[int] = []
	for tile: int in PLANE_TARGETS:
		if tile != pawn.current_tile_idx:
			result.append(tile)
	return result


## 차의 직선 돌진 경로: 전방 경로(결승선 제외)를 따라 가장 앞의 잡을 수 있는 적이 선 타일까지, 적이 없으면 다음 코너 타일(5·10·15·22번)까지.
## 갈 곳이 없으면 빈 배열이다.
static func chariot_path(state: GameState, pawn: PlayerPawn) -> Array[int]:
	var ctx := RuleContext.new()
	var full: Array[int] = state.board.calculate_path(pawn, 40, ctx)
	var route: Array[int] = []
	for tile: int in full:
		if tile == GameEnums.GOAL_TILE:
			break
		route.append(tile)
	if route.is_empty():
		return route
	for index: int in route.size():
		if _has_vulnerable_enemy(state, pawn, route[index]):
			return route.slice(0, index + 1)
	for index: int in route.size():
		if GameEnums.CORNER_TILES.has(route[index]) or route[index] == GameEnums.CENTER_TILE:
			return route.slice(0, index + 1)
	return route


static func _has_vulnerable_enemy(state: GameState, mover: PlayerPawn, tile: int) -> bool:
	for leader: PlayerPawn in state.leaders_at(tile):
		if leader.owner_id != mover.owner_id and leader.has_left_start and not MoveExecutor.is_capture_immune(state, leader):
			return true
	return false


## 알까기 슈팅 결과 계산: angle은 화면 좌표(오른쪽 0, 아래쪽 +)의 라디안, power는 0~1. 반환:
## {"from": 출발 좌표, "to": 도착 좌표(보드 안으로 보정), "landing": 안착할 타일, "hits": 맞은 적 대표 말 ID들}
static func shot_result(state: GameState, pawn: PlayerPawn, angle: float, power: float) -> Dictionary:
	var origin: Vector2 = BoardLayout.tile_norm(pawn.current_tile_idx)
	var distance: float = lerpf(SHOT_MIN_DISTANCE, SHOT_MAX_DISTANCE, clampf(power, 0.0, 1.0))
	var target: Vector2 = origin + Vector2(cos(angle), sin(angle)) * distance
	target = Vector2(clampf(target.x, 0.0, 1.0), clampf(target.y, 0.0, 1.0))
	var hits: Array[int] = []
	for enemy: PlayerPawn in state.pawns:
		if enemy.owner_id == pawn.owner_id or enemy.is_finished or not enemy.has_left_start or enemy.carrier != null:
			continue
		if enemy.current_tile_idx == GameEnums.GOAL_TILE or MoveExecutor.is_capture_immune(state, enemy):
			continue
		if BoardLayout.distance_to_segment(BoardLayout.tile_norm(enemy.current_tile_idx), origin, target) <= SHOT_HIT_RADIUS:
			hits.append(enemy.entity_id)
	return {"from": origin, "to": target, "landing": BoardLayout.nearest_tile(target), "hits": hits}
