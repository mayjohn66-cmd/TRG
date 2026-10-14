# File: res://core_engine/rules/laws/law_social_distancing.gd
# Class: class_name LawSocialDistancing
# Role: LAW_02 사회적 거리두기 - 아군 말 업기 전면 금지 (기물 고유 업기 능력보다 우선, 이미 업힌 말은 유지)
class_name LawSocialDistancing
extends LawResource


func _init() -> void:
	law_id = "LAW_02"
	law_name = "사회적 거리두기"
	description = "아군 말 업기(Stack) 전면 금지."
	trigger_timing = RuleContext.ON_MOVE_CALC


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.allow_stacking = false
	return ctx
