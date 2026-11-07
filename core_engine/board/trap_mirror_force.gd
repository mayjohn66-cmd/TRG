# File: res://core_engine/board/trap_mirror_force.gd
# Class: class_name TrapMirrorForce
# Role: TRP_01 성스러운 방어막 거울의 힘 - 상대 말이 밟거나 통과하는 순간 말(업힌 말 포함)을 출발선으로 날리고 이동을 중단시키는 은신 함정
class_name TrapMirrorForce
extends TileAttachment


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_01"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id or ctx.state == null:
		return false
	ctx.metadata["cutscene_id"] = &"trap_mirror_force"
	ctx.state.send_to_start(pawn, owner_id)
	duration_turns = 0
	return true
