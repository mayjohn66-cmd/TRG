# File: res://core_engine/rules/base_law.gd
# Class: class_name LawResource
# Role: 교칙 추상 리소스 (특수 승리 교칙·개인 패시브). 지정한 trigger_timing 시점에 RuleContext를 가로채(intercept) 변조한다
class_name LawResource
extends Resource

@export var law_id: String = ""
@export var law_name: String = ""
@export_multiline var description: String = ""
## 이 교칙이 개입하는 시점 (RuleContext.ON_DICE_ROLL / ON_MOVE_CALC / ON_CAPTURE / ON_TURN_END).
@export var trigger_timing: String = ""
## 같은 시점에 여러 교칙이 걸릴 때의 실행 순서. 값이 작을수록 먼저 실행되고, 같으면 법전에 먼저 들어온 교칙이 먼저 실행된다.
@export var priority: int = 0
## 개인 패시브(초증강)의 주인. -1이면 모두에게 작동하는 법전 교칙이다.
var owner_id: int = -1


## 이 ctx에 개입하는가. 개인 패시브는 기본적으로 주인의 행동에만 작동한다.
func applies_to(ctx: RuleContext) -> bool:
	return owner_id == -1 or ctx.actor_id == owner_id


## 가상 함수: 서브클래스가 재정의해 ctx를 변조한다. 기본은 ctx를 그대로 반환한다.
func intercept(ctx: RuleContext) -> RuleContext:
	return ctx
