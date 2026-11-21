# File: res://core_engine/tools/tool_capsule_gacha.gd
# Class: class_name ToolCapsuleGacha
# Role: 캡슐뽑기 (신규 판정 도구) - 코인을 넣고 손잡이를 돌리면 캡슐이 나오고, 캡슐 안의 캐릭터 미니어처가 몇 칸 갈지 정한다. 순수한 운.
#       시크릿(황금 캡슐)이 나오면 8칸에 한 번 더. 연출(코인 넣기 -> 손잡이 돌리기 -> 캡슐 굴러 나옴 -> 열림)은 버튼 한 번에 자동으로 재생된다.
class_name ToolCapsuleGacha
extends BaseJudgmentTool

## [아바타 id, 미니어처 이름(한국어 원문), 등급 키, 등급 이름, 칸수, 가중치(합 100), 캡슐 색]. 평균 약 3.4칸 (+ 시크릿 한 번 더).
const PRIZES: Array = [
	[&"avatar_02", "버터", &"common", "흔함", 2, 35, "ffd43b"],
	[&"avatar_05", "셰이디", &"common", "흔함", 3, 30, "ced4da"],
	[&"avatar_07", "벨리타", &"uncommon", "보통", 4, 20, "ff6b6b"],
	[&"avatar_08", "죠안", &"rare", "희귀", 6, 10, "51cf66"],
	[&"avatar_01", "에르핀", &"secret", "시크릿", 8, 5, "ffe066"],
]
const SECRET_STEPS: int = 8


func _init() -> void:
	tool_id = &"DICE_CAPSULE"
	display_name = "캡슐뽑기"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var pick: int = rng.randi_range(1, 100)
	var acc: int = 0
	for entry: Array in PRIZES:
		acc += int(entry[5])
		if pick <= acc:
			return of_prize(StringName(entry[0]))
	return of_prize(&"avatar_02")


## 미니어처(아바타 id)로 결과를 만든다 (테스트·연출 공용).
static func of_prize(avatar: StringName) -> RollResult:
	var entry: Array = PRIZES[0]
	for candidate: Array in PRIZES:
		if StringName(candidate[0]) == avatar:
			entry = candidate
	var rarity: StringName = StringName(entry[2])
	var result: RollResult = RollResult.make(&"DICE_CAPSULE", int(entry[4]), {
		"avatar": StringName(entry[0]), "name": str(entry[1]), "rarity": rarity, "rarity_name": str(entry[3]),
		"color": str(entry[6]), "secret": rarity == &"secret",
	})
	if rarity == &"secret":
		result.reroll = true  # 황금 캡슐: 8칸 + 한 번 더
	return result


static func caption(details: Dictionary, steps: int) -> String:
	var name: String = str(details.get("name", ""))
	if bool(details.get("secret", false)):
		return "★시크릿 %s 미니어처! %d칸 + 한 번 더" % [name, steps]
	return "%s 미니어처 → %d칸" % [name, steps]
