# File: res://core_engine/board/trap_pit.gd
# Class: class_name TrapPit
# Role: TRP_02 함정 속으로(나락) - 눈금 4 이상으로 이동하는 상대 말이 지나가면 바닥이 꺼져 그 자리에 멈추고 2턴간 구속시키는 은신 함정
class_name TrapPit
extends TileAttachment

const MIN_DICE: int = 4
const RESTRAIN_TURNS: int = 2


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_02"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id or absi(ctx.dice_value) < MIN_DICE:
		return false
	ctx.metadata["cutscene_id"] = &"trap_pit"
	pawn.restrained_turns = RESTRAIN_TURNS
	duration_turns = 0
	return true
