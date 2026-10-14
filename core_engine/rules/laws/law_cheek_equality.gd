# File: res://core_engine/rules/laws/law_cheek_equality.gd
# Class: class_name LawCheekEquality
# Role: LAW_03 볼따구 평등법 - 눈금 6 이상 이동 후 꼴찌 말과 위치 강제 교환
class_name LawCheekEquality
extends BaseLaw


func _init() -> void:
	law_id = &"LAW_03"
	display_name = "볼따구 평등법"
	description = "눈금 6 이상 이동 후 꼴찌 말과 위치 강제 교환."


func apply(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	if stage != GameEnums.HookStage.MOVE_COMPLETE or ctx.pawn == null:
		return
	if absi(ctx.steps) >= 6:
		ctx.effects.append(SwapWithLastPlaceCommand.new(ctx.player_id, ctx.pawn.id))
