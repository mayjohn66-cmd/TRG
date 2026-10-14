# File: res://core_engine/rules/laws/law_speed_camera.gd
# Class: class_name LawSpeedCamera
# Role: LAW_06 과속 단속 카메라 - 눈금 4 초과 시 강제로 1로 고정 (부호 유지)
class_name LawSpeedCamera
extends LawResource


func _init() -> void:
	law_id = "LAW_06"
	law_name = "과속 단속 카메라"
	description = "눈금 4 초과 시 강제로 1로 고정."
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	if absi(ctx.dice_value) > 4:
		ctx.dice_value = signi(ctx.dice_value)
	return ctx
