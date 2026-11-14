# File: res://tests/test_law_variant_preview.gd
# Class: class_name TestLawVariantPreview
# Role: 도감에서 다른 보드의 특수 승리(봉인된 에르핀의 식권 <-> 와라! 모나티엄 25)를 미리 볼 때 쓰는 VictoryLaw.preview_board가 지금 보드 설정과 따로 동작하고 끝나면 되돌아오는지 검증
class_name TestLawVariantPreview
extends TestCase


func test_preview_board_overrides_and_restores() -> void:
	var saved: bool = BoardSpec.convenience
	BoardSpec.convenience = false
	check_eq(VictoryLaw.preview_board, -1, "기본은 미리보기 없음")
	check_eq(VictoryLaw.name_of("LAW_02"), "봉인된 에르핀의 식권", "에르핀 왕국: 식권")
	VictoryLaw.preview_board = 1
	check_eq(VictoryLaw.name_of("LAW_02"), "와라! 모나티엄 25", "미리보기 모나티엄: 와라! 모나티엄 25")
	check(VictoryLaw.condition_template("LAW_02").contains("편의점"), "미리보기 모나티엄: 편의점 문구")
	check_eq(VictoryLaw.name_of("LAW_01"), "기물 슬레이어", "바꿔 쓰지 않는 교칙은 그대로")
	BoardSpec.convenience = true
	VictoryLaw.preview_board = 0
	check_eq(VictoryLaw.name_of("LAW_02"), "봉인된 에르핀의 식권", "모나티엄 보드에서도 미리보기 에르핀은 식권")
	VictoryLaw.preview_board = -1
	check_eq(VictoryLaw.name_of("LAW_02"), "와라! 모나티엄 25", "미리보기를 끄면 지금 보드(모나티엄)로")
	BoardSpec.convenience = saved


func test_rulebook_tile_flip_uses_the_other_board_and_restores_state() -> void:
	var saved: bool = BoardSpec.convenience
	BoardSpec.convenience = false
	AugmentRegistry.apply_board_variants()
	var definition: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_02")
	check(Rulebook._has_board_variant(definition), "AUG_LAW_02는 보드마다 바뀌는 특수 승리")
	check(not Rulebook._has_board_variant(AugmentRegistry.get_def(&"AUG_LAW_01")), "다른 교칙은 화살표가 없다")
	var plain: Dictionary = Rulebook._card_info_for_tile(definition, {"augment": &"AUG_LAW_02"})
	var flipped: Dictionary = Rulebook._card_info_for_tile(definition, {"augment": &"AUG_LAW_02", "variant_flipped": true})
	check(str(plain["title"]).contains("식권"), "뒤집기 전: 식권 (%s)" % plain["title"])
	check(str(flipped["title"]).contains("모나티엄"), "뒤집은 뒤: 모나티엄 25 (%s)" % flipped["title"])
	var plain_art: Texture2D = plain.get("art")
	var flipped_art: Texture2D = flipped.get("art")
	check(plain_art != null and plain_art.resource_path.ends_with("/LAW_02.png"), "식권판은 황금 식권 그림")
	check(flipped_art != null and flipped_art.resource_path == AugmentArt.MONATIUM_LAW_ICON, "도시판 미리보기는 편의점 그림")
	check_eq(VictoryLaw.preview_board, -1, "뒤집어 본 뒤 미리보기는 꺼져 있다")
	check(str(Rulebook._card_info_for_tile(definition, {"augment": &"AUG_LAW_02"})["title"]).contains("식권"), "뒤집어 본 뒤에도 지금 보드 문구로 돌아온다")
	BoardSpec.convenience = saved
	AugmentRegistry.apply_board_variants()
