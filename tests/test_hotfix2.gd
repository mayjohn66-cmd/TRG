## 2026-11 주말 제보 핫픽스 2: 닉네임 안전장치 (아이패드에서 키패드가 안 떠도 입장).
extends TestCase


func test_blank_or_null_nicknames_are_never_saved_as_text() -> void:
	for raw: Variant in [null, "", "   ", "null", "NULL", "undefined", "<null>"]:
		check_eq(GameSession.clean_nickname(raw), "", "'%s'는 빈 닉네임으로 본다" % str(raw))
		check(GameSession.validate_nickname(str(raw) if raw != null else "") != "", "'%s'는 그대로 저장되지 않는다" % str(raw))
	check_eq(GameSession.clean_nickname("  에르핀  "), "에르핀", "앞뒤 공백만 뺀다")


func test_random_nickname_is_always_a_valid_name() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 200:
		rng.seed = seed_value
		var name_text: String = GameSession.random_nickname(rng)
		check_eq(GameSession.validate_nickname(name_text), "", "랜덤 닉네임은 바로 통과한다: %s" % name_text)
		check(name_text.length() <= GameSession.MAX_NICKNAME_LENGTH, "최대 %d자" % GameSession.MAX_NICKNAME_LENGTH)
