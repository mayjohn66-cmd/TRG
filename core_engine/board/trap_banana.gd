# File: res://core_engine/board/trap_banana.gd
# Class: class_name TrapBanana
# Role: TRP_06 바나나 껍질 - 밟은 상대 말이 앞으로 +3칸 미끄러지고(도착 판정은 이어서), 설치자가 그 주인의 손패 1장을 빼앗는다
class_name TrapBanana
extends TileAttachment

const SLIDE_STEPS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_06"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null or pawn.owner_id == owner_id:
		return false
	var state: GameState = ctx.state
	ctx.metadata["cutscene_id"] = &"trap_banana"
	MoveExecutor.fling(state, pawn, CardRegistry.param(&"TRP_06", SLIDE_STEPS))
	var stolen: StringName = state.steal_random_card(pawn.owner_id, state.rng)
	if stolen != &"" and not state.give_card(owner_id, stolen):
		(state.hands[pawn.owner_id] as Array).append(stolen)  # 설치자의 손패가 가득 차면 돌려준다
	duration_turns = 0
	return true
