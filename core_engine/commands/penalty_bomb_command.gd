# File: res://core_engine/commands/penalty_bomb_command.gd
# Class: class_name PenaltyBombCommand
# Role: ACT_03 우노 +4 실행 - 진행 방향의 다음 플레이어의 선두 말 하나를 즉시 출발선(0번)으로 장외 사출시키고, 내 선두 말 하나를 앞으로 +4칸 날려 보낸다
class_name PenaltyBombCommand
extends GameCommand

const ADVANCE_STEPS: int = 4


## 내 말이 전진하는 칸 수 (cards_table.csv ACT_03 param_1).
static func advance_steps() -> int:
	return CardRegistry.param(&"ACT_03", ADVANCE_STEPS)

## 실행 뒤 UI가 읽는다: 내 말이 실제로 전진한 말 ID(없으면 -1).
var boosted_pawn_id: int = -1


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
	state.send_to_start(target, sender_id)
	state.bomb_resolved.emit(sender_id, victim, target.entity_id, from_tile, GameEnums.GOAL_TILE)
	# 내 말 하나를 +4칸 전진: 보드 위 선두 말 (없으면 아직 출발 안 한 말 하나)
	var mine: PlayerPawn = state.front_pawn_of(sender_id)
	if mine == null:
		for candidate: PlayerPawn in state.pawns_of(sender_id):
			if candidate.is_selectable():
				mine = candidate
				break
	if mine != null:
		boosted_pawn_id = mine.entity_id
		MoveExecutor.forced_advance(state, mine, advance_steps())
