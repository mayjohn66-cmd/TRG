# File: res://core_engine/commands/crowbar_command.gd
# Class: class_name CrowbarCommand
# Role: ACT_10 빠루 - 내 선두 말 바로 앞 3칸의 적 말을 모두 출발선으로 날리고 그 칸들의 설치물도 뜯어낸다
class_name CrowbarCommand
extends GameCommand

const REACH: int = 3

## 실행 뒤 UI가 읽는다: 휘두른 칸들.
var tiles: Array[int] = []


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "Crowbar"


## 휘두를 칸: 내 선두 말 앞 3칸 (결승 전까지, cards_table.csv ACT_10 param_1).
static func reach_tiles(game: GameState, player_id: int) -> Array[int]:
	var front: PlayerPawn = game.front_pawn_of(player_id)
	var result: Array[int] = []
	if front == null:
		return result
	for tile: int in game.board.calculate_path(front, CardRegistry.param(&"ACT_10", REACH), RuleContext.new()):
		if tile == GameEnums.GOAL_TILE:
			break
		result.append(tile)
	return result


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and not reach_tiles(state, sender_id).is_empty()


func _run() -> void:
	tiles = reach_tiles(state, sender_id)
	for tile_index: int in tiles:
		for enemy: PlayerPawn in state.leaders_at(tile_index):
			if enemy.owner_id != sender_id and enemy.has_left_start:
				state.send_to_start(enemy, sender_id)
		state.board.get_tile(tile_index).clear_attachments()
	state.crowbar_swung.emit(sender_id, tiles)
