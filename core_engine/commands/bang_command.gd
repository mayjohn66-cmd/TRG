# File: res://core_engine/commands/bang_command.gd
# Class: class_name BangCommand
# Role: ACT_02 뱅! 저격 실행 - 고른 상대 플레이어의 선두 말(보드 위에서 결승에 가장 가까운 말) 하나를 2칸 뒤로 보낸다. 회피나 사거리 판정은 없다
class_name BangCommand
extends GameCommand

const RETREAT_STEPS: int = 2

var target_player: int = -1
var target_pawn_id: int = -1


func _init(acting_player: int = -1, victim_player: int = -1) -> void:
	super()
	sender_id = acting_player
	target_player = victim_player
	command_name = "Bang"


## 저격할 수 있는 상대 플레이어들: 보드 위에 나와 있는 말이 하나라도 있는 상대.
static func target_players(game_state: GameState, shooter_id: int) -> Array[int]:
	var result: Array[int] = []
	for pawn: PlayerPawn in game_state.pawns:
		if pawn.owner_id == shooter_id or result.has(pawn.owner_id):
			continue
		if game_state.front_pawn_of(pawn.owner_id) != null:
			result.append(pawn.owner_id)
	return result


## 그 플레이어의 선두 말 (없으면 null).
static func find_target(game_state: GameState, victim_player: int) -> PlayerPawn:
	return game_state.front_pawn_of(victim_player)


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and target_players(state, sender_id).has(target_player)


func _run() -> void:
	var target: PlayerPawn = find_target(state, target_player)
	if target == null:
		return
	target_pawn_id = target.entity_id
	var from_tile: int = target.current_tile_idx
	# 설치물·잡기 판정 없이 조용히 뒤로 민다 (업힌 말은 함께 밀려난다)
	var path: Array[int] = state.board.calculate_path(target, -RETREAT_STEPS, RuleContext.new())
	for destination: int in path:
		state.board.commit_step(target, destination)
		state.sync_stack_position(target)
	state.bang_resolved.emit(sender_id, target_pawn_id, from_tile, target.current_tile_idx)
