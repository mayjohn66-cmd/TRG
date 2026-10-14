# File: res://core_engine/rules/laws/law_cheek_equality.gd
# Class: class_name LawCheekEquality
# Role: LAW_03 볼따구 평등법 - 눈금 6 이상 이동 후 꼴찌 말과 위치 강제 교환
class_name LawCheekEquality
extends LawResource


func _init() -> void:
	law_id = "LAW_03"
	law_name = "볼따구 평등법"
	description = "눈금 6 이상 이동 후 꼴찌 말과 위치 강제 교환."
	trigger_timing = RuleContext.ON_TURN_END


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.pawn != null and absi(ctx.dice_value) >= 6:
		ctx.effects.append(SwapWithLastPlaceCommand.new(ctx.actor_id, ctx.pawn.entity_id))
	return ctx
