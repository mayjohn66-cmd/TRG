# File: res://core_engine/rules/laws/law_frog_curse.gd
# Class: class_name LawFrogCurse
# Role: LAW_04 청개구리 저주 - 짝수 눈금은 전진, 홀수 눈금은 후퇴
class_name LawFrogCurse
extends BaseLaw


func _init() -> void:
	law_id = &"LAW_04"
	display_name = "청개구리 저주"
	description = "짝수 눈금은 전진, 홀수 눈금은 후퇴."


func apply(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	if stage != GameEnums.HookStage.ROLL_MODIFY:
		return
	var magnitude: int = absi(ctx.steps)
	ctx.steps = magnitude if magnitude % 2 == 0 else -magnitude
