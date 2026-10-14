# File: res://core_engine/rules/base_law.gd
# Class: class_name LawResource
# Role: 패시브 교칙 추상 리소스. 지정한 trigger_timing 시점에 RuleContext를 가로채(intercept) 변조한다
class_name LawResource
extends Resource

@export var law_id: String = ""
@export var law_name: String = ""
@export_multiline var description: String = ""
## 이 교칙이 개입하는 시점 (RuleContext.ON_DICE_ROLL / ON_MOVE_CALC / ON_CAPTURE / ON_TURN_END).
@export var trigger_timing: String = ""
## 같은 시점에 여러 교칙이 걸릴 때의 실행 순서. 값이 작을수록 먼저 실행되고, 같으면 법전에 먼저 들어온 교칙이 먼저 실행된다.
@export var priority: int = 0


## 가상 함수: 서브클래스가 재정의해 ctx를 변조한다. 기본은 ctx를 그대로 반환한다.
func intercept(ctx: RuleContext) -> RuleContext:
	return ctx
