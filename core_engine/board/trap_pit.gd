# File: res://core_engine/board/trap_pit.gd
# Class: class_name TrapPit
# Role: TRP_02 함정 속으로 (나락) - 눈금 4 이상으로 지나가거나 멈추는 상대 말을 나락으로 떨어뜨려 출발선으로 사출한다
class_name TrapPit
extends TileAttachment

const MIN_DICE: int = 4


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_02"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null or pawn.owner_id == owner_id or absi(ctx.dice_value) < CardRegistry.param(&"TRP_02", MIN_DICE):  # cards_table.csv TRP_02 param_1
		return false
	ctx.metadata["cutscene_id"] = &"trap_pit"
	ctx.state.send_to_start(pawn, owner_id)
	duration_turns = 0
	return true
