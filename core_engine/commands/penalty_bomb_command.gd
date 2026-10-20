# File: res://core_engine/commands/penalty_bomb_command.gd
# Class: class_name PenaltyBombCommand
# Role: ACT_03 우노 +4 폭탄 실행 - 진행 방향의 다음 플레이어에게 폭탄을 넘겨 선두 말 하나를 출발선(0번)으로 장외 사출시키고(방어 카드로 막을 수 있다), 내 이번 이동에 +4칸을 더한다
class_name PenaltyBombCommand
extends GameCommand

const ADVANCE_STEPS: int = 4


## 내 말이 전진하는 칸 수 (cards_table.csv ACT_03 param_1).
static func advance_steps() -> int:
	return CardRegistry.param(&"ACT_03", ADVANCE_STEPS)

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
	# 내 이번 이동 +4칸 (다음 굴림 결과에 더한다)
	state.roll_bonus += advance_steps()
