# File: res://core_engine/rules/laws/law_runaway_train.gd
# Class: class_name LawRunawayTrain
# Role: LAW_05 폭주 기관차 - 말을 잡으면 추가 턴 대신 즉시 앞으로 3칸 돌진
class_name LawRunawayTrain
extends LawResource


func _init() -> void:
	law_id = "LAW_05"
	law_name = "폭주 기관차"
	description = "적 처치 시 재굴림 대신 +3칸 돌진"
	trigger_timing = RuleContext.ON_CAPTURE


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.capture_extra_turn = false
	ctx.capture_charge_steps = 3
	return ctx
