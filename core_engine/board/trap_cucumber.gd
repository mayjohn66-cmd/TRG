# File: res://core_engine/board/trap_cucumber.gd
# Class: class_name TrapCucumber
# Role: TRP_CUKE 오이 - 적 말이 밟고 멈추면 효과 없이 먹을 수 있는 [오이 카드]를 손패에 넣는다 (1회). 이동은 막지 않는다
class_name TrapCucumber
extends TileAttachment

const CARD_ID: StringName = &"JNK_CUKE"


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_CUKE"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id or ctx.state == null or not bool(ctx.metadata.get("is_landing", false)):
		return false  # 내 오이·지나가기는 아무 일도 없다
	if ctx.state.give_card(pawn.owner_id, CARD_ID):
		ctx.state.cucumber_given.emit(pawn.owner_id, ctx.state.board.tile_of_attachment(self))
	duration_turns = 0
	return false
