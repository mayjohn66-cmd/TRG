# File: res://core_engine/rules/laws/law_shortcut_construction.gd
# Class: class_name LawShortcutConstruction
# Role: LAW_01 지름길 공사 중 - 코너(5, 10번) 대각선 지름길 진입 불가 (비숍의 통과 진입도 봉인)
class_name LawShortcutConstruction
extends BaseLaw


func _init() -> void:
	law_id = &"LAW_01"
	display_name = "지름길 공사 중"
	description = "코너(5, 10번) 대각선 지름길 진입 불가."


func apply(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	if stage == GameEnums.HookStage.PATH_PREPARE:
		ctx.shortcuts_enabled = false
