# File: res://core_engine/board/trap_jump_pad.gd
# Class: class_name TrapJumpPad
# Role: TRP_C01~04 중 TRP_C02 피아식별 점프대 (코너 전용) - 설치자의 말이 밟으면 +5칸 날아가고, 상대 말이 밟으면 출발선으로 사출된다
class_name TrapJumpPad
extends TileAttachment

const JUMP_STEPS: int = 5


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_C02"
	owner_id = owner
	is_hidden_trap = false


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null:
		return false
	ctx.metadata["cutscene_id"] = &"trap_jump_pad"
	if pawn.owner_id == owner_id:
		MoveExecutor.fling(ctx.state, pawn, CardRegistry.param(&"TRP_C02", JUMP_STEPS))
	else:
		ctx.state.send_to_start(pawn, owner_id)
	return true
