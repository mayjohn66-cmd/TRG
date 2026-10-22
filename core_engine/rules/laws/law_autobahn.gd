# File: res://core_engine/rules/laws/law_autobahn.gd
# Class: class_name LawAutobahn
# Role: 개인 영구 패시브 예시 - 내 눈금이 짝수이거나 5 이상이면 이동 거리 +3칸. 초증강 아우토반 니트로(SUPER_10)는 [선두 말 코너 질주] 즉시 효과로 바뀌어 드래프트로는 더 이상 얻지 않는다.
#       개인 패시브 파이프라인(RuleBookManager.personal_laws·스냅샷·변조 추적)을 위해 같은 ID로 남겨 둔다
class_name LawAutobahn
extends LawResource

const BOOST_THRESHOLD: int = 5
const BOOST_STEPS: int = 3


## 추가 칸 수 (augments_table.csv의 SUPER_10 행은 이제 니트로 질주라 고정값을 쓴다).
static func boost_steps() -> int:
	return BOOST_STEPS


## 이 눈금 이상이면 홀수라도 가속한다.
static func threshold() -> int:
	return BOOST_THRESHOLD


func _init() -> void:
	law_id = "SUPER_10"
	law_name = "아우토반 니트로"
	description = "내 눈금이 짝수이거나 %d 이상이면 +%d칸" % [threshold(), boost_steps()]
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.dice_value > 0 and (ctx.dice_value % 2 == 0 or ctx.dice_value >= threshold()):
		ctx.dice_value += boost_steps()
	return ctx
