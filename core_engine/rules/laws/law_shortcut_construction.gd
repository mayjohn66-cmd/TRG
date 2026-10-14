# File: res://core_engine/rules/laws/law_shortcut_construction.gd
# Class: class_name LawShortcutConstruction
# Role: LAW_01 지름길 공사 중 - 코너(5, 10번) 대각선 지름길 진입 불가 (비숍의 통과 진입도 봉인)
class_name LawShortcutConstruction
extends LawResource


func _init() -> void:
	law_id = "LAW_01"
	law_name = "지름길 공사 중"
	description = "코너(5, 10번) 대각선 지름길 진입 불가."
	trigger_timing = RuleContext.ON_MOVE_CALC


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.allow_shortcut = false
	return ctx
