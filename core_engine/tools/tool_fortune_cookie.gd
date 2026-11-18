# File: res://core_engine/tools/tool_fortune_cookie.gd
# Class: class_name ToolFortuneCookie
# Role: 포츈쿠키 (신규 판정 도구) - 쿠키를 깨면 안에 종이가 들어 있고, 종이를 펼치면 몇 칸 전진할지 적혀 있다. 순수한 운 (한 번 더·턴 종료 같은 부가 효과는 없다).
class_name ToolFortuneCookie
extends BaseJudgmentTool

## [칸수, 가중치(합 100), 종이에 적힌 글(한국어 원문)]. 평균 약 3.7칸 (오미쿠지 3.8칸·주사위 3.5칸과 비슷하다). 8칸이 대박 쿠키.
const PAPERS: Array = [
	[1, 10, "작은 걸음도 걸음이에요"],
	[2, 15, "서두르지 않아도 도착해요"],
	[3, 25, "오늘은 무난한 하루가 될 거예요"],
	[4, 20, "좋은 바람이 뒤에서 불어와요"],
	[5, 15, "뜻밖의 행운이 찾아와요"],
	[6, 10, "지금이 바로 달려 나갈 때!"],
	[8, 5, "대박! 쿠키가 활짝 웃고 있어요"],
]
const JACKPOT_STEPS: int = 8


func _init() -> void:
	tool_id = &"DICE_COOKIE"
	display_name = "포츈쿠키"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var pick: int = rng.randi_range(1, 100)
	var acc: int = 0
	for entry: Array in PAPERS:
		acc += int(entry[1])
		if pick <= acc:
			return of_steps(int(entry[0]), rng.randi_range(1, 99))
	return of_steps(3, 1)


## 칸수로 결과를 만든다 (테스트·연출 공용). lucky는 종이 아래쪽에 적힌 행운의 숫자(연출용).
static func of_steps(steps: int, lucky: int = 7) -> RollResult:
	var message: String = "오늘은 무난한 하루가 될 거예요"
	for entry: Array in PAPERS:
		if int(entry[0]) == steps:
			message = str(entry[2])
	return RollResult.make(&"DICE_COOKIE", steps, {"message": message, "lucky": lucky, "jackpot": steps == JACKPOT_STEPS})


static func caption(details: Dictionary, steps: int) -> String:
	if bool(details.get("jackpot", false)):
		return "★대박 쿠키! %d칸" % steps
	return "쿠키 속 종이 → %d칸" % steps
