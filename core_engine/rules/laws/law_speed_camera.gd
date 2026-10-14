# File: res://core_engine/rules/laws/law_speed_camera.gd
# Class: class_name LawSpeedCamera
# Role: LAW_06 과속 단속 카메라 - 눈금 4 초과 시 강제로 1로 고정 (부호 유지)
class_name LawSpeedCamera
extends BaseLaw


func _init() -> void:
	law_id = &"LAW_06"
	display_name = "과속 단속 카메라"
	description = "눈금 4 초과 시 강제로 1로 고정."


func apply(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	if stage == GameEnums.HookStage.ROLL_MODIFY and absi(ctx.steps) > 4:
		ctx.steps = signi(ctx.steps)
