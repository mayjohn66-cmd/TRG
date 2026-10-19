# File: res://core_engine/rules/laws/law_goal_threshold.gd
# Class: class_name LawGoalThreshold
# Role: LAW_08 결승선 문턱 높이기 - 결승선은 눈금이 정확히 맞아야 들어간다: 눈금이 남으면 결승선 바로 앞 칸에서 멈춘다 (뒤로 튕기지 않는다)
class_name LawGoalThreshold
extends LawResource


func _init() -> void:
	law_id = "LAW_08"
	law_name = "결승선 문턱"
	description = "결승선은 정확한 눈금으로만 입장! 남으면 바로 앞에서 정지"
	trigger_timing = RuleContext.ON_MOVE_CALC


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.exact_goal_required = true
	return ctx
