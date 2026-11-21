# File: res://tests/test_vending.gd
# Class: class_name TestVending
# Role: 모나티엄 도시 보드 - 편의점(빵집 자리 카드)·자판기(옷장 자리, 워프 없음, 음료수 랜덤 버프) 검증
class_name TestVending
extends TestCase

const THEME_SCRIPT = preload("res://scenes/law_victory_theme.gd")


func _monatium_state() -> GameState:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.match_rules = {"board": "monatium"}
	state.setup([1, 2] as Array[int], 12345)
	return state


func _restore(count: int, shop: bool, id: StringName) -> void:
	BoardSpec.apply(count, shop)
	BoardCatalog.current_id = id


func test_monatium_layout_swaps_wardrobes_for_vending_machines() -> void:
	var classic: Dictionary = BoardSpec.layout_for(32, false)
	var city: Dictionary = BoardSpec.layout_for(32, true)
	check_eq(city["bakery_tiles"], classic["bakery_tiles"], "편의점은 빵집과 같은 자리")
	check((city["portal_tiles"] as Array).is_empty() and (city["portal_warp_targets"] as Dictionary).is_empty(), "옷장과 워프가 없다")
	check_eq(city["vending_tiles"], classic["portal_tiles"], "자판기는 옷장 자리 (12·22번)")
	check((classic["vending_tiles"] as Array).is_empty(), "에르핀 왕국에는 자판기가 없다")
	check_eq(BoardCatalog.name_of(&"classic"), "에르핀 왕국", "기본 보드 이름")
	check_eq(BoardCatalog.name_of(&"monatium"), "모나티엄 도시", "신규 보드 이름")


func test_vending_stop_gives_a_drink_without_warping() -> void:
	var saved_count: int = BoardSpec.tile_count
	var saved_shop: bool = BoardSpec.convenience
	var saved_id: StringName = BoardCatalog.current_id
	var seen: Dictionary = {}
	for seed_value: int in 40:
		var state := _monatium_state()
		state.rng.seed = seed_value
		check(BoardSpec.vending_tiles.has(12) and state.board.get_tile(12).tile_type == TileNode.TileType.VENDING, "12번은 자판기 칸")
		place(state, 11, 10, [9])
		var report: MoveReport = move(state, 11, 2)  # 11 -> 12 (자판기)
		check(not report.warped, "자판기는 워프하지 않는다")
		check(report.vending_drink != &"", "딱 멈추면 음료수가 나온다")
		seen[report.vending_drink] = true
		var pawn: PlayerPawn = state.get_pawn(11)
		match report.vending_drink:
			&"energy":
				check_eq(int(state.corner_buff.get(1, 0)), 3, "에너지 드링크: 다음 굴림 +3")
				check_eq(pawn.current_tile_idx, 12, "제자리")
			&"coffee":
				check_eq(int(state.corner_buff.get(1, 0)), 2, "아메리카노: 다음 굴림 +2")
			&"ion":
				check(pawn.ward, "이온음료: 방어막")
			&"milk":
				check(report.drawn_card != &"" or (state.hands[1] as Array).size() >= state.hand_limit(1), "우유: 카드 1장")
			&"soda":
				check_eq(pawn.current_tile_idx, 14, "탄산음료: +2칸 전진")
	check_eq(seen.size(), VendingDrinks.DRINKS.size(), "40번 중 다섯 종류가 모두 나온다")
	_restore(saved_count, saved_shop, saved_id)


func test_passing_a_vending_machine_does_nothing_and_store_still_gives_a_card() -> void:
	var saved_count: int = BoardSpec.tile_count
	var saved_shop: bool = BoardSpec.convenience
	var saved_id: StringName = BoardCatalog.current_id
	var state := _monatium_state()
	place(state, 11, 10, [9])
	var report: MoveReport = move(state, 11, 4)  # 12를 지나 14
	check_eq(report.vending_drink, &"", "지나가기만 하면 음료수가 없다")
	var shop: int = BoardSpec.bakery_tiles[0]
	place(state, 12, shop - 1, [shop - 2])
	var hand_before: int = (state.hands[2] as Array).size()
	var shop_report: MoveReport = move(state, 12, 1)
	check(shop_report.drawn_card != &"" or (state.hands[2] as Array).size() > hand_before, "편의점도 딱 멈추면 카드 1장")
	check(BoardSpec.is_special_tile(12), "자판기 칸에는 일반 함정을 깔 수 없다")
	_restore(saved_count, saved_shop, saved_id)


func test_each_board_has_its_own_skin_palette_and_surface() -> void:
	var saved_count: int = BoardSpec.tile_count
	var saved_shop: bool = BoardSpec.convenience
	var saved_id: StringName = BoardCatalog.current_id
	BoardSpec.apply(32, false)
	var classic_fill: Color = BoardSkin.palette().dash_inner
	var classic_surface: Texture2D = BoardSkin.surface_texture()
	BoardSpec.apply(32, true)
	check(BoardSkin.palette().dash_inner != classic_fill, "도시 보드는 부스터 발판 색이 다르다")
	check(BoardSkin.surface_texture() != classic_surface, "도시 보드는 판 바닥 그림이 다르다")
	check_eq(BoardSkin.definition(12).kind, "vending", "12번 칸은 자판기 종류")
	check_eq(BoardSkin.definition(5).kind, "store", "5번 칸은 편의점 종류")
	_restore(saved_count, saved_shop, saved_id)


func test_monatium_swaps_the_bakery_law_into_wara_monatium_25() -> void:
	var saved_count: int = BoardSpec.tile_count
	var saved_shop: bool = BoardSpec.convenience
	var saved_id: StringName = BoardCatalog.current_id
	BoardSpec.apply(32, false)
	AugmentRegistry.apply_board_variants()
	var classic_law := VictoryLaw.new("LAW_02")
	check_eq(classic_law.law_name, "봉인된 에르핀의 식권", "에르핀 왕국의 이름")
	check(classic_law.condition_text().contains("빵집"), "에르핀 왕국의 조건")
	var classic_def: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_02")
	check(classic_def.title.contains("봉인된 에르핀의 식권") or classic_def.title.contains("Erpin") or classic_def.title.contains("エルフィン"), "에르핀 왕국의 선택 카드 제목")
	BoardSpec.apply(32, true)
	AugmentRegistry.apply_board_variants()
	var city_law := VictoryLaw.new("LAW_02")
	check_eq(city_law.law_name, "와라! 모나티엄 25", "모나티엄 도시의 이름")
	check(city_law.condition_text().contains("편의점"), "모나티엄 도시의 조건은 편의점 방문")
	check_eq(city_law.stat_key, VictoryLaw.BAKERY, "기록 키는 그대로 (편의점 방문도 같은 기록)")
	check_eq(city_law.goal(), classic_law.goal(), "목표 수치도 그대로")
	var city_def: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_02")
	check(city_def.title.contains("모나티엄") or city_def.title.contains("Monatium") or city_def.title.contains("モナティウム"), "선택 카드 제목이 바뀐다")
	check(not city_def.desc.contains("빵집") and not city_def.desc.contains("bakery"), "선택 카드 설명에서 빵집이 편의점으로")
	check(THEME_SCRIPT.variant("LAW_02") and THEME_SCRIPT.of("LAW_02")["headline"] == "MONATIUM DAYS", "승리 문구는 MONATIUM DAYS")
	check(not THEME_SCRIPT.variant("LAW_01"), "다른 법전은 그대로")
	var city_cues := PresentationAudio.victory_plan("LAW_02", 0.0, -1.0, false)
	check_eq(city_cues.filter(func(entry: Dictionary) -> bool: return entry.event == &"monatium_cash_drop").size(), 6, "one bundle per store visit")
	check(city_cues.any(func(entry: Dictionary) -> bool: return entry.event == &"monatium_cash_reward"), "city finale has its own cash cue")
	BoardSpec.apply(32, false)
	var classic_cues := PresentationAudio.victory_plan("LAW_02", 0.0, -1.0, false)
	check(classic_cues.any(func(entry: Dictionary) -> bool: return entry.event == &"ticket_join"), "classic finale still uses ticket cues")
	check_eq(THEME_SCRIPT.of("LAW_02")["headline"], "SWEET VICTORY", "에르핀 왕국에서는 원래 문구")
	AugmentRegistry.apply_board_variants()
	_restore(saved_count, saved_shop, saved_id)
	AugmentRegistry.apply_board_variants()
