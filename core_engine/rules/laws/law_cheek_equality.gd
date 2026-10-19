# File: res://core_engine/rules/laws/law_cheek_equality.gd
# Class: class_name LawCheekEquality
# Role: LAW_03 볼따구 평등법 - 눈금 6 이상 이동 후 꼴찌 말과 위치 강제 교환
class_name LawCheekEquality
extends LawResource

const THRESHOLD: int = 6


## 이 눈금 이상 이동하면 꼴찌와 교환한다 (augments_table.csv AUG_LAW_03 param_1).
static func threshold() -> int:
	return GameData.param("augments", "AUG_LAW_03", 1, THRESHOLD)


func _init() -> void:
	law_id = "LAW_03"
	law_name = "볼따구 평등법"
	description = "눈금 %d+ 이동 후 꼴찌 말과 위치 교환" % threshold()
	trigger_timing = RuleContext.ON_TURN_END


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.pawn != null and absi(ctx.dice_value) >= threshold():
		ctx.effects.append(SwapWithLastPlaceCommand.new(ctx.actor_id, ctx.pawn.entity_id))
	return ctx
