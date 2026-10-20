# File: res://core_engine/rules/laws/law_joint_guarantee.gd
# Class: class_name LawJointGuarantee
# Role: [초증강 SUPER_12] 강제 연대보증 - 개인 영구 패시브. 내 말이 잡히면 잡은 상대의 다른 말 1개(결승에 가장 가까운 말)도 출발선으로 동반 추방하고 나는 카드 1장을 받는다
class_name LawJointGuarantee
extends LawResource


func _init() -> void:
	law_id = "SUPER_12"
	law_name = "강제 연대보증"
	description = "내 말이 잡히면 공격자의 다른 말 1개 동반 처치 + 카드 1장"
	trigger_timing = RuleContext.ON_CAPTURE


## 내 말이 잡히는 순간에만 작동한다 (공격자가 나면 아니다).
func applies_to(ctx: RuleContext) -> bool:
	if ctx.capturer == null or ctx.capturer.owner_id == owner_id:
		return false
	for victim: PlayerPawn in ctx.captured_pawns:
		if victim.owner_id == owner_id:
			return true
	return false


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.capturer == null or ctx.state == null:
		return ctx
	var stack_ids: Array[int] = []
	for member: PlayerPawn in ctx.capturer.stack_members():
		stack_ids.append(member.entity_id)
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in ctx.state.pawns_of(ctx.capturer.owner_id):
		if pawn.is_finished or not pawn.has_left_start or stack_ids.has(pawn.entity_id) or pawn.carrier != null:
			continue
		var distance: int = ctx.state.board.distance_to_goal(pawn.current_tile_idx, pawn.has_left_start)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	if best != null:
		ctx.effects.append(ExpelPawnCommand.new(owner_id, best.entity_id))
	ctx.effects.append(DrawCardsCommand.new(owner_id, 1))
	return ctx
