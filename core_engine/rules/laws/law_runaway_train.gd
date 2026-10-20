# File: res://core_engine/rules/laws/law_runaway_train.gd
# Class: class_name LawRunawayTrain
# Role: [초증강 SUPER_11] 폭주 기관차 - 개인 영구 패시브. 내 말이 적을 잡으면 그 자리에서 +4칸 더 돌진한다 (추가 턴 능력은 그대로)
class_name LawRunawayTrain
extends LawResource

const CHARGE_STEPS: int = 4


## 처치 뒤 돌진 칸 수 (augments_table.csv SUPER_11 param_1).
static func charge_steps() -> int:
	return GameData.param("augments", "SUPER_11", 1, CHARGE_STEPS)


func _init() -> void:
	law_id = "SUPER_11"
	law_name = "폭주 기관차"
	description = "내 말이 적을 처치하면 +%d칸 돌진" % charge_steps()
	trigger_timing = RuleContext.ON_CAPTURE


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.capture_charge_steps = maxi(ctx.capture_charge_steps, charge_steps())
	return ctx
