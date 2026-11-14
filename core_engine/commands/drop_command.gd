# File: res://core_engine/commands/drop_command.gd
# Class: class_name DropCommand
# Role: 쇼기 보병 필살기 [모치고마 낙하] 실행 - 출발선에 대기 중인 내 다른 말 1개를 주사위 없이 보병 바로 뒷칸(또는 앞칸)에 즉시 놓고 도착 처리를 한다. 스냅샷으로 undo 가능
class_name DropCommand
extends GameCommand

var fu_id: int = -1
var partner_id: int = -1
## 낙하 결과(실행 뒤 UI·로그가 읽는다): 도착 타일과 이동 보고서.
var landing_tile: int = -1
var report: MoveReport = null


func _init(acting_player: int = -1, fu_pawn_id: int = -1, partner_pawn_id: int = -1) -> void:
	super()
	sender_id = acting_player
	fu_id = fu_pawn_id
	partner_id = partner_pawn_id
	command_name = "Drop"


func can_execute(_ctx: RuleContext) -> bool:
	if state == null or fu_id == partner_id:
		return false
	var fu: PlayerPawn = state.get_pawn(fu_id)
	var partner: PlayerPawn = state.get_pawn(partner_id)
	if fu == null or partner == null or fu.owner_id != sender_id or partner.owner_id != sender_id:
		return false
	return PawnSkills.is_ready(fu) and PawnSkills.drop_partners(state, fu).has(partner) and PawnSkills.drop_tile(state, fu) != -1


func _run() -> void:
	var fu: PlayerPawn = state.get_pawn(fu_id)
	var partner: PlayerPawn = state.get_pawn(partner_id)
	landing_tile = PawnSkills.drop_tile(state, fu)
	fu.skill_used = true
	partner.has_left_start = true
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = sender_id
	ctx.pawn = partner
	report = MoveReport.new()
	report.pawn_id = partner.entity_id
	MoveExecutor.teleport_to(state, partner, ctx, report, landing_tile)
