# File: res://core_engine/commands/castle_command.gd
# Class: class_name CastleCommand
# Role: 체스 룩 필살기 [단독 캐슬링] 실행 - 룩과 내 다른 아군 기물 하나(업은 말 포함)의 타일 위치를 맞바꾸고 필살기를 사용 완료로 표시한다. 스냅샷으로 undo 가능
class_name CastleCommand
extends GameCommand

var rook_id: int = -1
var partner_id: int = -1


func _init(acting_player: int = -1, rook_pawn_id: int = -1, partner_pawn_id: int = -1) -> void:
	super()
	sender_id = acting_player
	rook_id = rook_pawn_id
	partner_id = partner_pawn_id
	command_name = "Castle"


func can_execute(_ctx: RuleContext) -> bool:
	if state == null or rook_id == partner_id:
		return false
	var rook: PlayerPawn = state.get_pawn(rook_id)
	var partner: PlayerPawn = state.get_pawn(partner_id)
	if rook == null or partner == null or rook.owner_id != sender_id or partner.owner_id != sender_id:
		return false
	return PawnSkills.is_ready(rook) and PawnSkills.rook_partners(state, rook).has(partner)


func _run() -> void:
	var rook: PlayerPawn = state.get_pawn(rook_id)
	rook.skill_used = true
	state.swap_stacks(rook, state.get_pawn(partner_id))
	state.pawns_castled.emit(rook_id, partner_id)
