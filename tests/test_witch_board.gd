# File: res://tests/test_witch_board.gd
# Class: class_name TestWitchBoard
# Role: 벨라티엔 왕국(마녀 도시) 보드 - 마녀 상점(빵집 자리 카드)·마녀의 가마솥(옷장 자리, 워프 없음, 좋은 물약 3종 + 나쁜 물약 2종)·전용 법전 문구·스킨 검증
class_name TestWitchBoard
extends TestCase


func _witch_state() -> GameState:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.match_rules = {"board": "belatien"}
	state.setup([1, 2] as Array[int], 12345)
	return state


func _saved() -> Array:
	return [BoardSpec.tile_count, BoardSpec.convenience, BoardSpec.witch, BoardCatalog.current_id]


func _restore(saved: Array) -> void:
	BoardSpec.apply(int(saved[0]), bool(saved[1]), bool(saved[2]))
	BoardCatalog.current_id = saved[3]
	AugmentRegistry.apply_board_variants()


func test_belatien_layout_swaps_wardrobes_for_cauldrons() -> void:
	var classic: Dictionary = BoardSpec.layout_for(32, false)
	var witch: Dictionary = BoardSpec.layout_for(32, false, true)
	check_eq(witch["bakery_tiles"], classic["bakery_tiles"], "마녀 상점은 빵집과 같은 자리")
	check((witch["portal_tiles"] as Array).is_empty() and (witch["portal_warp_targets"] as Dictionary).is_empty(), "옷장과 워프가 없다")
	check_eq(witch["cauldron_tiles"], classic["portal_tiles"], "가마솥은 옷장 자리 (12·22번)")
	check((witch["vending_tiles"] as Array).is_empty(), "자판기는 없다")
	check((BoardSpec.layout_for(32, true)["cauldron_tiles"] as Array).is_empty(), "모나티엄 도시에는 가마솥이 없다")
	check_eq(BoardCatalog.name_of(&"belatien"), "벨라티엔 왕국", "보드 이름")
	check(BoardCatalog.is_valid(&"belatien"), "보드 목록에 있다")


func test_cauldron_stop_brews_every_potion_without_warping() -> void:
	var saved: Array = _saved()
	var seen: Dictionary = {}
	var good: int = 0
	for seed_value: int in 60:
		var state := _witch_state()
		state.rng.seed = seed_value
		check(BoardSpec.witch and BoardSpec.cauldron_tiles.has(12) and state.board.get_tile(12).tile_type == TileNode.TileType.CAULDRON, "12번은 가마솥 칸")
		place(state, 11, 10, [9])
		var report: MoveReport = move(state, 11, 2)  # 10 -> 12 (가마솥)
		check(report.cauldron_potion != &"", "딱 멈추면 물약이 끓는다")
		check(not report.warped or report.cauldron_potion == &"boom", "가마솥은 워프하지 않는다 (폭발 물약만 뒤로 날려 보낸다)")
		seen[report.cauldron_potion] = true
		if WitchPotions.is_good(report.cauldron_potion):
			good += 1
		var pawn: PlayerPawn = state.get_pawn(11)
		match report.cauldron_potion:
			&"power":
				check_eq(int(state.corner_buff.get(1, 0)), WitchPotions.POWER_STEPS, "힘의 물약: 다음 굴림 +3")
				check_eq(pawn.current_tile_idx, 12, "제자리")
			&"swift":
				check_eq(pawn.current_tile_idx, 14, "신속의 물약: +2칸 전진")
			&"guard":
				check(pawn.ward, "보호의 물약: 방어막")
			&"frog":
				check_eq(int(state.roll_penalty.get(1, 0)), WitchPotions.FROG_STEPS, "개구리 물약: 다음 굴림 -2")
				check_eq(pawn.current_tile_idx, 12, "제자리")
			&"boom":
				check_eq(pawn.current_tile_idx, 10, "폭발 물약: 뒤로 2칸")
	check_eq(seen.size(), WitchPotions.POTIONS.size(), "60번 중 다섯 종류가 모두 나온다")
	check(good > 0 and good < 60, "좋은 물약과 나쁜 물약이 섞여 나온다 (좋은 것 %d/60)" % good)
	_restore(saved)


func test_passing_a_cauldron_does_nothing_and_witch_shop_gives_a_card() -> void:
	var saved: Array = _saved()
	var state := _witch_state()
	place(state, 11, 10, [9])
	var report: MoveReport = move(state, 11, 4)  # 12를 지나 14
	check_eq(report.cauldron_potion, &"", "지나가기만 하면 물약이 없다")
	var shop: int = BoardSpec.bakery_tiles[0]
	place(state, 12, shop - 1, [shop - 2])
	var hand_before: int = (state.hands[2] as Array).size()
	var shop_report: MoveReport = move(state, 12, 1)
	check(shop_report.drawn_card != &"" or (state.hands[2] as Array).size() > hand_before, "마녀 상점도 딱 멈추면 카드 1장")
	check(BoardSpec.is_special_tile(12), "가마솥 칸에는 일반 함정을 깔 수 없다")
	_restore(saved)


func test_belatien_skin_and_law_variant() -> void:
	var saved: Array = _saved()
	BoardSpec.apply(32, false, false)
	var classic_dash: Color = BoardSkin.palette().dash_inner
	var classic_surface: Texture2D = BoardSkin.surface_texture()
	BoardSpec.apply(32, false, true)
	check(BoardSkin.palette().dash_inner != classic_dash, "벨라티엔 보드는 부스터 발판 색이 다르다")
	check(BoardSkin.palette() == BoardSkin.PALETTE_WITCH, "보라·갈색 판")
	check(BoardSkin.surface_texture() != classic_surface, "벨라티엔 보드는 판 바닥 그림이 다르다")
	check_eq(BoardSkin.definition(12).kind, "cauldron", "12번 칸은 가마솥 종류")
	check_eq(BoardSkin.definition(5).kind, "witch_shop", "5번 칸은 마녀 상점 종류")
	AugmentRegistry.apply_board_variants()
	var law := VictoryLaw.new("LAW_02")
	check_eq(law.law_name, "Bad Carrot", "벨라티엔 왕국의 법전 이름")
	check(law.condition_text().contains("마녀 상점"), "조건은 마녀 상점 방문")
	check_eq(law.stat_key, VictoryLaw.BAKERY, "기록 키는 그대로")
	check(not VictoryLaw.variant_active("LAW_02"), "모나티엄 전용 연출(MONATIUM DAYS)은 켜지지 않는다")
	var def: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_02")
	check(def.title.contains("Bad Carrot"), "선택 카드 제목이 바뀐다 (%s)" % def.title)
	check_eq(MainBoard.law_win_reason("LAW_02", 6), "마녀는 엄청난 것을 훔쳐갔습니다.", "승리 문구는 「마리사는 엄청난 것을 훔쳐갔습니다」 패러디")
	check(load("res://scenes/law_victory_theme.gd").variant("LAW_02") and load("res://scenes/law_victory_theme.gd").of("LAW_02")["headline"] == "BAD CARROT", "승리 연출 제목은 BAD CARROT")
	check(not def.desc.contains("빵집"), "선택 카드 설명에서 빵집이 마녀 상점으로")
	_restore(saved)
	check_eq(VictoryLaw.new("LAW_02").law_name, "봉인된 에르핀의 식권", "되돌리면 원래 이름")
