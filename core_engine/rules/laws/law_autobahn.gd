# File: res://core_engine/rules/laws/law_autobahn.gd
# Class: class_name LawAutobahn
# Role: LAW_06 아우토반 무제한 과속 - 눈금 5 이상이 나오면 이동 거리가 깎이는 대신 +3칸 부스터가 붙는다 (옛 과속 단속 카메라의 '큰 눈금을 1로 고정'은 주사위의 도파민을 깎아서 폐기). 너무 빨라 코너 점프대나 빵집을 그냥 지나칠 수 있는 하이템포 교칙
class_name LawAutobahn
extends LawResource

const BOOST_THRESHOLD: int = 5
const BOOST_STEPS: int = 3


func _init() -> void:
	law_id = "LAW_06"
	law_name = "아우토반 무제한 과속"
	description = "눈금 5 이상 굴림 시 +3칸 추가 가속!"
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.dice_value >= BOOST_THRESHOLD:
		ctx.dice_value += BOOST_STEPS
	return ctx
