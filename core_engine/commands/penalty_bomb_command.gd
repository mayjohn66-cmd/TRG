# File: res://core_engine/commands/penalty_bomb_command.gd
# Class: class_name PenaltyBombCommand
# Role: ACT_03 우노 +4 실행 - 진행 방향의 다음 플레이어의 선두 말 하나를 즉시 4칸 뒤로 보낸다 (설치물·잡기 판정 없음)
class_name PenaltyBombCommand
extends GameCommand

const RETREAT_STEPS: int = 4


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "PenaltyBomb"


## 맞을 플레이어: 진행 방향의 다음 플레이어 (없으면 -1).
static func victim_of(game_state: GameState, shooter_id: int) -> int:
	var next_id: int = game_state.next_player_after(shooter_id)
	return next_id if next_id != shooter_id else -1


func can_execute(_ctx: RuleContext) -> bool:
	var victim: int = victim_of(state, sender_id) if state != null else -1
	return victim != -1 and state.front_pawn_of(victim) != null


func _run() -> void:
	var victim: int = victim_of(state, sender_id)
	var target: PlayerPawn = state.front_pawn_of(victim)
	if target == null:
		return
	var from_tile: int = target.current_tile_idx
	var path: Array[int] = state.board.calculate_path(target, -RETREAT_STEPS, RuleContext.new())
	for destination: int in path:
		state.board.commit_step(target, destination)
		state.sync_stack_position(target)
	state.bomb_resolved.emit(sender_id, victim, target.entity_id, from_tile, target.current_tile_idx)
