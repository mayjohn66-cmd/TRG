# File: res://core_engine/rules/base_law.gd
# Class: class_name BaseLaw
# Role: 패시브 교칙 추상 리소스. 스테이지별로 RuleContext를 변조하는 인터셉터 하나를 정의한다.
class_name BaseLaw
extends Resource

@export var law_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""


## 법전 파이프라인이 모든 스테이지에서 호출한다. 자신이 관여하지 않는 스테이지는 그냥 반환한다.
func apply(_stage: GameEnums.HookStage, _ctx: RuleContext) -> void:
	return
