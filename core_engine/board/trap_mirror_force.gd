# File: res://core_engine/board/trap_mirror_force.gd
# Class: class_name TrapMirrorForce
# Role: TRP_01 성스러운 방어막 거울의 힘 - 상대 말이 밟거나 통과하는 순간 말(업힌 말 포함)을 출발선으로 날리는 은신 함정
class_name TrapMirrorForce
extends TileAttachment


func _init(owner: int = -1) -> void:
	attachment_id = &"TRP_01"
	owner_id = owner


func on_pawn_enter(_state: GameState, pawn: PlayerPawn, _ctx: RuleContext, _is_landing: bool) -> AttachmentEffect:
	if pawn.owner_id == owner_id:
		return null
	var effect := AttachmentEffect.new()
	effect.attachment_id = attachment_id
	effect.owner_id = owner_id
	effect.stop_move = true
	effect.send_to_start = true
	effect.consume = true
	effect.cutscene_id = &"trap_mirror_force"
	return effect
