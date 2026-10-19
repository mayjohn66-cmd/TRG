# File: res://core_engine/rules/laws/law_runaway_train.gd
# Class: class_name LawRunawayTrain
# Role: LAW_05 폭주 기관차 - 말을 잡으면 추가 턴 대신 즉시 앞으로 3칸 돌진
class_name LawRunawayTrain
extends LawResource

const CHARGE_STEPS: int = 3


## 처치 뒤 돌진 칸 수 (augments_table.csv AUG_LAW_05 param_1).
static func charge_steps() -> int:
	return GameData.param("augments", "AUG_LAW_05", 1, CHARGE_STEPS)


func _init() -> void:
	law_id = "LAW_05"
	law_name = "폭주 기관차"
	description = "적 처치 시 재굴림 대신 +%d칸 돌진" % charge_steps()
	trigger_timing = RuleContext.ON_CAPTURE


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.capture_extra_turn = false
	ctx.capture_charge_steps = charge_steps()
	return ctx
