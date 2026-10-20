# File: res://core_engine/rules/laws/law_autobahn.gd
# Class: class_name LawAutobahn
# Role: [초증강 SUPER_10] 아우토반 니트로 - 개인 영구 패시브. 내 눈금이 짝수이거나 5 이상이면 이동 거리 +3칸 (옛 법전 교칙 아우토반·짝수 니트로를 합쳤다)
class_name LawAutobahn
extends LawResource

const BOOST_THRESHOLD: int = 5
const BOOST_STEPS: int = 3


## 추가 칸 수 (augments_table.csv SUPER_10 param_1).
static func boost_steps() -> int:
	return GameData.param("augments", "SUPER_10", 1, BOOST_STEPS)


## 이 눈금 이상이면 홀수라도 가속한다 (param_2).
static func threshold() -> int:
	return GameData.param("augments", "SUPER_10", 2, BOOST_THRESHOLD)


func _init() -> void:
	law_id = "SUPER_10"
	law_name = "아우토반 니트로"
	description = "내 눈금이 짝수이거나 %d 이상이면 +%d칸" % [threshold(), boost_steps()]
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.dice_value > 0 and (ctx.dice_value % 2 == 0 or ctx.dice_value >= threshold()):
		ctx.dice_value += boost_steps()
	return ctx
