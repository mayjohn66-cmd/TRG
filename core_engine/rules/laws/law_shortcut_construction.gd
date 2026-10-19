# File: res://core_engine/rules/laws/law_shortcut_construction.gd
# Class: class_name LawShortcutConstruction
# Role: LAW_01 지름길 공사 중 - 점프 코너(6·18번)와 옷장 포탈 작동 중지
class_name LawShortcutConstruction
extends LawResource


func _init() -> void:
	law_id = "LAW_01"
	law_name = "지름길 공사 중"
	description = "점프 코너·포탈 작동 중지"
	trigger_timing = RuleContext.ON_MOVE_CALC


func intercept(ctx: RuleContext) -> RuleContext:
	ctx.allow_shortcut = false
	return ctx
