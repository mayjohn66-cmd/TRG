# File: res://core_engine/rules/laws/law_frog_curse.gd
# Class: class_name LawFrogCurse
# Role: LAW_04 짝수 니트로 부스터(옛 청개구리 저주) - 짝수 눈금이 나오면 이동 거리가 +3칸 증폭된다. 홀수는 그대로 (후퇴는 없다). 내부 ID·클래스 이름은 호환을 위해 유지한다
class_name LawFrogCurse
extends LawResource

const NITRO_BONUS: int = 3


func _init() -> void:
	law_id = "LAW_04"
	law_name = "짝수 니트로 부스터"
	description = "짝수 눈금이 나오면 이동 거리 +3칸 증폭!"
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.dice_value > 0 and ctx.dice_value % 2 == 0:
		ctx.dice_value += NITRO_BONUS
	return ctx
