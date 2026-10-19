# File: res://core_engine/commands/tower_command.gd
# Class: class_name TowerCommand
# Role: ACT_07 XVI. 무너지는 탑 - 말이 가장 많이 모인 타일(없으면 가장 앞선 적 말의 타일)에 벼락을 내려, 그 타일의 모든 말을 업기 해제하고 앞쪽 1~2칸 타일로 뿔뿔이 흩어 놓는다. 스냅샷으로 undo 가능
class_name TowerCommand
extends GameCommand

## 실행 뒤 UI가 읽는다: 벼락이 친 타일과 흩어진 말들 {"pawn_id", "from", "to"}.
var struck_tile: int = -1
var scattered: Array[Dictionary] = []


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "Tower"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and TarotEffects.tower_target(state, sender_id) != -1


func _run() -> void:
	struck_tile = TarotEffects.tower_target(state, sender_id)
	scattered.clear()
	var victims: Array[PlayerPawn] = []
	for pawn: PlayerPawn in TarotEffects.field_pawns(state):
		if pawn.current_tile_idx == struck_tile:
			victims.append(pawn)
	# 업기 해제: 업은 말과 업힌 말이 모두 따로 선다.
	for pawn: PlayerPawn in victims:
		pawn.carrier = null
		pawn.carried.clear()
	var tiles: Array[int] = TarotEffects.tower_scatter_tiles(state, struck_tile)
	if tiles.is_empty():
		return
	for pawn: PlayerPawn in victims:
		var destination: int = tiles[state.rng.randi_range(0, tiles.size() - 1)]
		var from_tile: int = pawn.current_tile_idx
		pawn.place_at(destination)
		scattered.append({"pawn_id": pawn.entity_id, "from": from_tile, "to": destination})
		state.pawn_warped.emit(pawn.entity_id, from_tile, destination)
	state.tower_struck.emit(struck_tile, scattered)
