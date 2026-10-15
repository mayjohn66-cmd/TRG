# File: res://core_engine/victory_checker.gd
# Class: class_name VictoryChecker
# Role: PHASE_RESOLUTION의 승리 판정. 일반 승리(4개 말 완주)와 기물 4세트 특수 승리 5종(천하제일 4업·체크메이트·장군멍군·부동산 독점·대마 불사)을 검사한다
class_name VictoryChecker
extends RefCounted

const ALL_HOME: StringName = &"all_home"
const YUT_FOUR_STACK: StringName = &"yut_four_stack"
const CHECKMATE: StringName = &"checkmate"
const JANGGUN_MUNGUN: StringName = &"janggun_mungun"
const REAL_ESTATE: StringName = &"real_estate"
const DAEMA_BULSA: StringName = &"daema_bulsa"

const CHAIN_CAPTURES_NEEDED: int = 3
const HOTELS_NEEDED: int = 6


static func reason_text(reason: StringName) -> String:
	match reason:
		ALL_HOME: return "일반 승리 (말 4개 모두 완주)"
		YUT_FOUR_STACK: return "천하제일 4업 승리 (윷 4세트)"
		CHECKMATE: return "체크메이트 승리 (체스 4세트)"
		JANGGUN_MUNGUN: return "장군멍군 승리 (장기 4세트)"
		REAL_ESTATE: return "부동산 독점 승리 (모노폴리 4세트)"
		DAEMA_BULSA: return "대마 불사 승리 (바둑 4세트)"
	return String(reason)


## 모든 플레이어를 검사한다 (현재 턴 플레이어가 먼저). 승자가 있으면 {"winner": int, "reason": StringName}, 없으면 {}.
## report: 방금 끝난 이동 보고서(없으면 null) / capture_chain: 현재 플레이어가 이번 턴 연속으로 잡은 말 수.
static func evaluate(state: GameState, player_order: Array[int], current_player: int, report: MoveReport, capture_chain: int) -> Dictionary:
	var order: Array[int] = [current_player]
	for player_id: int in player_order:
		if player_id != current_player:
			order.append(player_id)
	for player_id: int in order:
		var is_current: bool = player_id == current_player
		var reason: StringName = player_reason(state, player_order, player_id, report if is_current else null, capture_chain if is_current else 0)
		if reason != &"":
			return {"winner": player_id, "reason": reason}
	return {}


static func player_reason(state: GameState, player_order: Array[int], player_id: int, report: MoveReport, capture_chain: int) -> StringName:
	if _all_home(state, player_id):
		return ALL_HOME
	if report != null and report.special_victory == YUT_FOUR_STACK and state.set_count(player_id, GameEnums.PawnKind.YUT) == GameEnums.PAWNS_PER_PLAYER:
		return YUT_FOUR_STACK
	if _is_full_set(state, player_id, GameEnums.PawnKind.CHESS) and is_checkmate(state, player_order, player_id):
		return CHECKMATE
	if _is_full_set(state, player_id, GameEnums.PawnKind.JANGGI) and capture_chain >= CHAIN_CAPTURES_NEEDED:
		return JANGGUN_MUNGUN
	if _is_full_set(state, player_id, GameEnums.PawnKind.MONOPOLY) and hotel_count(state, player_id) >= HOTELS_NEEDED:
		return REAL_ESTATE
	if _is_full_set(state, player_id, GameEnums.PawnKind.GO) and holds_all_corners(state, player_id):
		return DAEMA_BULSA
	return &""


static func _all_home(state: GameState, player_id: int) -> bool:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.is_finished:
			return false
	return true


static func _is_full_set(state: GameState, player_id: int, kind: GameEnums.PawnKind) -> bool:
	return state.set_count(player_id, kind) == GameEnums.PAWNS_PER_PLAYER


## 결승까지 남은 거리의 합이 가장 작은(= 가장 앞선) 상대 플레이어. 완주한 말은 0으로 센다.
static func leader_player(state: GameState, player_order: Array[int], excluding: int) -> int:
	var best: int = -1
	var best_total: int = 1 << 30
	for player_id: int in player_order:
		if player_id == excluding:
			continue
		var total: int = 0
		for pawn: PlayerPawn in state.pawns_of(player_id):
			total += 0 if pawn.is_finished else state.pawn_progress_distance(pawn)
		if total < best_total:
			best_total = total
			best = player_id
	return best


## 체크메이트: 1등 유저의 말 하나를 내 체스 말들이 바로 앞 타일과 바로 뒤 타일에서 동시에 포위한다.
static func is_checkmate(state: GameState, player_order: Array[int], challenger: int) -> bool:
	var leader: int = leader_player(state, player_order, challenger)
	if leader == -1:
		return false
	for target: PlayerPawn in state.pawns_of(leader):
		if target.is_finished or not target.has_left_start or target.carrier != null or target.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		var behind: int = state.board.default_previous(target.current_tile_idx)
		if target.step_history.size() >= 2:
			behind = target.step_history[target.step_history.size() - 2]
		if not _has_chess_pawn(state, challenger, behind):
			continue
		for ahead: int in state.board.get_tile(target.current_tile_idx).neighbors():
			if _has_chess_pawn(state, challenger, ahead):
				return true
	return false


static func _has_chess_pawn(state: GameState, player_id: int, tile: int) -> bool:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.kind == GameEnums.PawnKind.CHESS and not pawn.is_finished and pawn.current_tile_idx == tile:
			return true
	return false


static func hotel_count(state: GameState, player_id: int) -> int:
	var count: int = 0
	for tile: TileNode in state.board.tiles:
		for attachment: TileAttachment in tile.attachments:
			if attachment.attachment_id == "HOTEL" and attachment.owner_id == player_id:
				count += 1
	return count


## 대마 불사: 보드판 네 모서리(0, 5, 10, 15번)를 내 바둑돌이 하나씩 동시에 차지한다.
static func holds_all_corners(state: GameState, player_id: int) -> bool:
	for corner: int in GameEnums.CORNER_TILES:
		var held: bool = false
		for pawn: PlayerPawn in state.pawns_of(player_id):
			if pawn.kind == GameEnums.PawnKind.GO and not pawn.is_finished and pawn.current_tile_idx == corner:
				held = true
		if not held:
			return false
	return true
