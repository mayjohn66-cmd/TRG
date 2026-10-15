# File: res://core_engine/cards/card_backdo_goal.gd
# Class: class_name CardBackdoGoal
# Role: ACT_04 우리 동네 빽도 완주! - 0번에서 후퇴해 19번/28번에 도착한 직후 해당 말을 즉시 완주 처리
class_name CardBackdoGoal
extends BaseCard

const VALID_TILES: Array[int] = [GameEnums.LAST_OUTER_TILE, GameEnums.LAST_SHORTCUT_TILE]


func _init() -> void:
	card_id = &"ACT_04"
	display_name = "우리 동네 빽도 완주!"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.is_finished and pawn.retreated_from_start and VALID_TILES.has(pawn.current_tile_idx):
			return true
	return false


## params: {"pawn_id": int}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	var pawn: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
	if pawn == null or pawn.owner_id != player_id or pawn.is_finished:
		return false
	return pawn.carrier == null and pawn.retreated_from_start and VALID_TILES.has(pawn.current_tile_idx)


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return BackdoGoalCommand.new(player_id, int(params["pawn_id"]))
