# File: res://core_engine/rules/laws/law_autobahn.gd
# Class: class_name LawAutobahn
# Role: LAW_06 아우토반 무제한 과속 - 눈금 5 이상이 나오면 이동 거리가 깎이는 대신 +3칸 부스터가 붙는다 (옛 과속 단속 카메라의 '큰 눈금을 1로 고정'은 주사위의 도파민을 깎아서 폐기). 너무 빨라 코너 점프대나 빵집을 그냥 지나칠 수 있는 하이템포 교칙
class_name LawAutobahn
extends LawResource

const BOOST_THRESHOLD: int = 5
const BOOST_STEPS: int = 3


## 이 눈금 이상이면 가속한다 (augments_table.csv AUG_LAW_06 param_2).
static func threshold() -> int:
	return GameData.param("augments", "AUG_LAW_06", 2, BOOST_THRESHOLD)


## 추가 칸 수 (param_1).
static func boost_steps() -> int:
	return GameData.param("augments", "AUG_LAW_06", 1, BOOST_STEPS)


func _init() -> void:
	law_id = "LAW_06"
	law_name = "아우토반 무제한 과속"
	description = "눈금 %d 이상 굴림 시 +%d칸 추가 가속!" % [threshold(), boost_steps()]
	trigger_timing = RuleContext.ON_DICE_ROLL


func intercept(ctx: RuleContext) -> RuleContext:
	if ctx.dice_value >= threshold():
		ctx.dice_value += boost_steps()
	return ctx
