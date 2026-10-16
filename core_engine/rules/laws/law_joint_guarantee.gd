# File: res://core_engine/rules/laws/law_joint_guarantee.gd
# Class: class_name LawJointGuarantee
# Role: LAW_07 강제 연대보증 - 내 말이 잡힐 때 잡은 상대의 다른 말 1개(결승에 가장 가까운 말)도 출발선으로 동반 추방
class_name LawJointGuarantee
extends LawResource


func _init() -> void:
	law_id = "LAW_07"
	law_name = "강제 연대보증"
	description = "피격 시 상대 다른 말 1개 동반 처치"
	trigger_timing = RuleContext.ON_CAPTURE


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.capturer == null or ctx.state == null:
		return ctx
	var stack_ids: Array[int] = []
	for member: PlayerPawn in ctx.capturer.stack_members():
		stack_ids.append(member.entity_id)
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in ctx.state.pawns_of(ctx.capturer.owner_id):
		if pawn.is_finished or not pawn.has_left_start or stack_ids.has(pawn.entity_id):
			continue
		var distance: int = ctx.state.board.distance_to_goal(pawn.current_tile_idx, pawn.has_left_start)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	if best != null:
		ctx.effects.append(ExpelPawnCommand.new(ctx.actor_id, best.entity_id))
	return ctx
