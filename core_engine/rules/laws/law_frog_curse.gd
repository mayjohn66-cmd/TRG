# File: res://core_engine/rules/laws/law_frog_curse.gd
# Class: class_name LawFrogCurse
# Role: LAW_04 청개구리 저주 - 짝수 눈금은 전진, 홀수 눈금은 후퇴
class_name LawFrogCurse
extends LawResource


func _init() -> void:
	law_id = "LAW_04"
	law_name = "청개구리 저주"
	description = "짝수 전진 / 홀수 후퇴"
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	var magnitude: int = absi(ctx.dice_value)
	ctx.dice_value = magnitude if magnitude % 2 == 0 else -magnitude
	return ctx
