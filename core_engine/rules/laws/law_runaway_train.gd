# File: res://core_engine/rules/laws/law_runaway_train.gd
# Class: class_name LawRunawayTrain
# Role: LAW_05 폭주 기관차 - 말을 잡으면 추가 턴 대신 즉시 앞으로 3칸 돌진
class_name LawRunawayTrain
extends BaseLaw


func _init() -> void:
	law_id = &"LAW_05"
	display_name = "폭주 기관차"
	description = "말 잡을 시 추가 턴 대신 즉시 앞으로 3칸 돌진."


func apply(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	if stage == GameEnums.HookStage.CAPTURE:
		ctx.capture_extra_turn = false
		ctx.capture_charge_steps = 3
