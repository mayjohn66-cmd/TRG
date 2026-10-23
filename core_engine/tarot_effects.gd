# File: res://core_engine/tarot_effects.gd
# Class: class_name TarotEffects
# Role: 타로 생떼 카드 2종(ACT_07 무너지는 탑 / ACT_08 운명의 수레바퀴)의 대상 선정과 결과 계산. 상태를 바꾸지 않는 순수 함수라 UI 설명·AI 평가가 그대로 쓴다
class_name TarotEffects
extends RefCounted

## 탑이 흩어 놓는 반경: 앞쪽 1~2칸 (말은 뒤로 날아가지 않는다).
const TOWER_RADIUS: int = 2


## 보드 위(출발선·완주 제외)에서 지금 서 있는 말: 출발했고 완주하지 않은 모든 말(업힌 말 포함).
static func field_pawns(state: GameState) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns:
		if pawn.has_left_start and not pawn.is_finished and pawn.current_tile_idx != GameEnums.GOAL_TILE:
			result.append(pawn)
	return result


## 가장 앞선 적 말(결승까지 가장 가까운 대표 말). 없으면 null.
static func leading_enemy(state: GameState, player_id: int) -> PlayerPawn:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in field_pawns(state):
		if pawn.owner_id == player_id or pawn.carrier != null:
			continue
		var distance: int = state.pawn_progress_distance(pawn)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	return best


## 내 가장 뒤처진 보드 위 말(결승까지 가장 먼 대표 말). 없으면 null.
static func trailing_own(state: GameState, player_id: int) -> PlayerPawn:
	var best: PlayerPawn = null
	var best_distance: int = -1
	for pawn: PlayerPawn in field_pawns(state):
		if pawn.owner_id != player_id or pawn.carrier != null:
			continue
		var distance: int = state.pawn_progress_distance(pawn)
		if distance > best_distance:
			best_distance = distance
			best = pawn
	return best


## 출발선에서 기다리는 내 말 하나 (아직 출발하지 않았고 완주하지 않은 말, 슬롯 번호가 가장 낮은 것). 없으면 null.
static func waiting_own(state: GameState, player_id: int) -> PlayerPawn:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.has_left_start and not pawn.is_finished and pawn.carrier == null:
			return pawn
	return null


## 무너지는 탑이 내리치는 타일: 말(업힌 말 포함)이 가장 많이 모인 타일 (동수면 적 말이 많은 쪽, 그다음 결승에 가까운 쪽).
## 어느 타일에도 말이 2개 이상 모여 있지 않으면 가장 앞선 적 말의 타일. 보드 위에 말이 없으면 -1.
static func tower_target(state: GameState, player_id: int) -> int:
	var counts: Dictionary = {}
	var enemy_counts: Dictionary = {}
	for pawn: PlayerPawn in field_pawns(state):
		counts[pawn.current_tile_idx] = int(counts.get(pawn.current_tile_idx, 0)) + 1
		if pawn.owner_id != player_id:
			enemy_counts[pawn.current_tile_idx] = int(enemy_counts.get(pawn.current_tile_idx, 0)) + 1
	var best_tile: int = -1
	for tile: int in counts.keys():
		if int(counts[tile]) < 2:
			continue
		if best_tile == -1 or _tower_better(state, counts, enemy_counts, tile, best_tile):
			best_tile = tile
	if best_tile != -1:
		return best_tile
	var lead: PlayerPawn = leading_enemy(state, player_id)
	return lead.current_tile_idx if lead != null else -1


static func _tower_better(state: GameState, counts: Dictionary, enemy_counts: Dictionary, tile: int, other: int) -> bool:
	if int(counts[tile]) != int(counts[other]):
		return int(counts[tile]) > int(counts[other])
	if int(enemy_counts.get(tile, 0)) != int(enemy_counts.get(other, 0)):
		return int(enemy_counts.get(tile, 0)) > int(enemy_counts.get(other, 0))
	return state.board.distance_to_goal(tile, true) < state.board.distance_to_goal(other, true)


## 탑이 말을 튕겨 낼 수 있는 앞쪽 타일 (앞 1~2칸, 출발선 제외).
static func tower_scatter_tiles(state: GameState, tile: int) -> Array[int]:
	var result: Array[int] = []
	var cursor: int = tile
	for _step: int in TOWER_RADIUS:
		cursor = state.board.next_tile_forward(cursor)
		if cursor == GameEnums.GOAL_TILE:
			break
		result.append(cursor)
	return result
