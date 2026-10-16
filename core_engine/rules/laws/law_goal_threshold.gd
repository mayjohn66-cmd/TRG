# File: res://core_engine/rules/laws/law_goal_threshold.gd
# Class: class_name LawGoalThreshold
# Role: LAW_08 결승선 문턱 높이기 - 결승선 통과 시 눈금이 남으면 남은 만큼 뒤로 튕겨 나옴
class_name LawGoalThreshold
extends LawResource


func _init() -> void:
	law_id = "LAW_08"
	law_name = "결승선 문턱"
	description = "결승선 눈금 초과 시 남은 만큼 반동 후퇴"
	trigger_timing = RuleContext.ON_MOVE_CALC


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.exact_goal_required = true
	return ctx
