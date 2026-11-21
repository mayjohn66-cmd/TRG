# File: res://tests/test_capsule_gacha.gd
# Class: class_name TestCapsuleGacha
# Role: 캡슐뽑기(DICE_CAPSULE) - 미니어처 5종의 확률·칸수·등급, 시크릿만 한 번 더, 도구 목록·교체 증강·연출 등록 검증
class_name TestCapsuleGacha
extends TestCase


func test_prize_table_adds_up_with_five_miniatures() -> void:
	var total: int = 0
	var average: float = 0.0
	check_eq(ToolCapsuleGacha.PRIZES.size(), 5, "미니어처는 5종")
	for entry: Array in ToolCapsuleGacha.PRIZES:
		total += int(entry[5])
		average += float(entry[4]) * float(entry[5]) / 100.0
		check(AvatarCatalog.is_valid(StringName(entry[0])), "%s는 실제 아바타" % str(entry[1]))
	check_eq(total, 100, "가중치 합 100")
	check(average > 3.0 and average < 3.9, "평균 칸수가 다른 도구와 비슷하다 (%.2f)" % average)


func test_only_the_secret_capsule_rolls_again() -> void:
	var tool := ToolCapsuleGacha.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 987
	var seen: Dictionary = {}
	for i: int in 3000:
		var result: RollResult = tool.roll(rng)
		var secret: bool = bool(result.details["secret"])
		check_eq(result.reroll, secret, "시크릿만 한 번 더")
		check(not result.ends_turn, "턴 종료는 없다")
		check_eq(secret, result.steps == ToolCapsuleGacha.SECRET_STEPS, "시크릿은 8칸")
		seen[result.details["avatar"]] = true
	check_eq(seen.size(), 5, "3000번 중 미니어처 5종이 모두 나온다")
	var gold: RollResult = ToolCapsuleGacha.of_prize(&"avatar_01")
	check(gold.reroll and gold.steps == 8 and gold.details["rarity"] == &"secret", "에르핀은 황금 캡슐 시크릿")


func test_registered_with_art_tables_and_presenter() -> void:
	check(ToolRegistry.ALL_IDS.has(&"DICE_CAPSULE"), "도구 목록에 있다")
	check(ToolRegistry.create(&"DICE_CAPSULE") is ToolCapsuleGacha, "생성된다")
	check(AugmentRegistry.SWAPPABLE_TOOLS.has(&"DICE_CAPSULE"), "교체 증강으로 고를 수 있다")
	check(AugmentRegistry.get_def(&"TOOL_DICE_CAPSULE") != null, "교체 증강 카드가 있다")
	check_eq(ToolRegistry.create(&"DICE_CAPSULE").display_name, "캡슐뽑기", "표의 이름")
	check(ResourceLoader.exists("res://content_trickcal/illustrations/dice/DICE_CAPSULE.png"), "아이콘 그림이 있다")
	check(RollPresenter.supports(&"DICE_CAPSULE"), "굴림 연출이 있다")
