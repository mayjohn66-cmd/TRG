# File: res://tests/test_match_rules.gd
# Class: class_name TestMatchRules
# Role: 매치 규칙(MatchRules): 난이도 기본값(Lv.1~3 함정 공개·Lv.1 입문 드래프트), 방 규칙(초증강 빈도·법전 끄기·스피드전)이
#       드래프트 가중치·템포 업·리벤지 부스터·법전 자동 등록에 실제로 반영되는지, 밖에서 온 값은 안전하게 고쳐지는지 검사한다.
class_name TestMatchRules
extends TestCase


func _state(rules: Dictionary, round_number: int = 7) -> GameState:
	var state := GameState.new()
	state.match_rules = rules
	state.setup([1, 2, 3, 4] as Array[int], 31)
	state.round_number = round_number
	return state


func _offer_categories(state: GameState, drafts: int = 120) -> Dictionary:
	var seen: Dictionary = {}
	for i: int in drafts:
		for offer: StringName in AugmentRegistry.generate_offers(state, 1):
			var category: int = AugmentRegistry.get_def(offer).category
			seen[category] = int(seen.get(category, 0)) + 1
	return seen


func test_difficulty_defaults_and_sanitize() -> void:
	for level: int in [1, 2, 3]:
		check(MatchRules.for_difficulty(level)["trap_reveal"], "Lv.%d 함정 공개" % level)
	for level: int in [4, 5]:
		check(not MatchRules.for_difficulty(level)["trap_reveal"], "Lv.%d 함정 비공개" % level)
	check(MatchRules.for_difficulty(1)["draft_easy"] and not MatchRules.for_difficulty(2)["draft_easy"], "입문 드래프트는 Lv.1만")
	var dirty: Dictionary = MatchRules.sanitize({"super_freq": 7, "speed": "warp", "hack": true, "laws": 0})
	check_eq(dirty["super_freq"], 1, "모르는 빈도는 기본")
	check_eq(dirty["speed"], MatchRules.SPEED_NORMAL, "모르는 속도는 기본")
	check(not dirty.has("hack") and not dirty["laws"], "모르는 키는 버리고 아는 키는 읽는다")


func test_super_frequency_and_law_toggle_shape_the_draft() -> void:
	var off: Dictionary = _offer_categories(_state({"super_freq": 0, "laws": false}))
	check(not off.has(GameEnums.AugmentCategory.SUPER_GAMBLE), "초증강 끄기: 드래프트에 초증강이 없다")
	check(not off.has(GameEnums.AugmentCategory.LAW_ENACT), "법전 끄기: 드래프트에 법전이 없다")
	var normal: Dictionary = _offer_categories(_state({}))
	var festival: Dictionary = _offer_categories(_state({"super_freq": 3}))
	check(int(festival.get(GameEnums.AugmentCategory.SUPER_GAMBLE, 0)) > int(normal.get(GameEnums.AugmentCategory.SUPER_GAMBLE, 0)), "대축제: 초증강이 더 자주 (%d > %d)" % [int(festival.get(GameEnums.AugmentCategory.SUPER_GAMBLE, 0)), int(normal.get(GameEnums.AugmentCategory.SUPER_GAMBLE, 0))])


func test_easy_draft_lowers_complex_supers_only_for_level_one() -> void:
	var redistribute: AugmentDef = AugmentRegistry.get_def(&"SUPER_02")
	var sniper: AugmentDef = AugmentRegistry.get_def(&"SUPER_09")
	var easy: GameState = _state(MatchRules.for_difficulty(1))
	var normal: GameState = _state(MatchRules.for_difficulty(2))
	check(AugmentRegistry.effective_weight(redistribute, easy) < AugmentRegistry.effective_weight(redistribute, normal) * 0.3, "Lv.1: 공산주의 재분배는 크게 줄어든다")
	check(AugmentRegistry.effective_weight(sniper, easy) < AugmentRegistry.effective_weight(sniper, normal), "Lv.1: 다른 초증강도 조금 줄어든다")
	var evolution: AugmentDef = AugmentRegistry.get_def(&"EVO_2_2")
	check(AugmentRegistry.effective_weight(evolution, easy) > AugmentRegistry.effective_weight(evolution, normal), "Lv.1: 기물 진화는 더 자주")


func test_speed_match_moves_tempo_up_and_boosts_revenge() -> void:
	var fast: GameState = _state({"speed": "speed"}, 4)
	check_eq(TempoUp.level(4), 1, "스피드전: 4라운드에 템포 업 1단계")
	check_eq(TempoUp.level(12), 3, "스피드전: 12라운드에 3단계")
	var pawn: PlayerPawn = fast.get_pawn(11)
	var fast_bonus: int = MoveExecutor.revenge_bonus_of(pawn, fast)
	var normal: GameState = _state({}, 4)
	check_eq(TempoUp.level(4), 0, "기본 템포는 판마다 다시 8라운드")
	check_eq(fast_bonus, MoveExecutor.revenge_bonus_of(normal.get_pawn(11), normal) + MatchRules.SPEED_REVENGE_EXTRA + (TempoUp.REVENGE_BONUS[1] - GameData.revenge_bonus()), "스피드전 리벤지 부스터 = 1단계 값 + 2칸")


func test_laws_off_skips_the_tempo_law_and_minefield_mines_are_public() -> void:
	var manager := TurnManager.new()
	manager.match_rules = {"laws": false}
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 5)
	manager._enact_random_law()
	check(manager.state.rulebook.law_ids().is_empty(), "법전 끄기: 템포 업 2단계도 법전을 올리지 않는다")
	SuperAugments.apply(SuperAugments.MINEFIELD, manager.state, 1)
	var mines: int = 0
	for index: int in BoardSpec.tile_count:
		for attachment: TileAttachment in manager.state.board.get_tile(index).attachments:
			if attachment.attachment_id == "TRP_03":
				mines += 1
				check(attachment.always_revealed, "광란의 지뢰밭 지뢰는 비공개 규칙에서도 정체가 보인다")
	check(mines > 0, "지뢰가 깔렸다")
	tree.root.remove_child(manager)
	manager.free()


func test_summary_lists_only_changed_rules() -> void:
	check_eq(MatchRules.summary(MatchRules.defaults()), "", "모두 기본이면 알릴 것이 없다")
	check_eq(MatchRules.summary({"trap_reveal": false, "super_freq": 3, "laws": false, "speed": "speed"}), "함정 비공개 · 초증강 대축제 · 법전 끄기 · 스피드전", "바뀐 규칙만 순서대로")


func test_presets_match_and_label_friendly_rooms() -> void:
	var classic: Dictionary = MatchRules.sanitize(MatchRules.preset_values(MatchRules.PRESET_CLASSIC))
	check(not classic["laws"] and classic["trap_reveal"] and classic["super_freq"] == 0, "클래식 완주전: 법전 끔 · 함정 공개 · 초증강 끔")
	check_eq(MatchRules.preset_of(classic), MatchRules.PRESET_CLASSIC, "클래식 값이면 클래식 프리셋")
	check_eq(MatchRules.preset_of(MatchRules.defaults()), MatchRules.PRESET_STANDARD, "기본값은 오리지널 표준")
	var mind: Dictionary = MatchRules.sanitize(MatchRules.preset_values(MatchRules.PRESET_MIND))
	check(mind["laws"] and not mind["trap_reveal"] and mind["super_freq"] == 2, "심리전: 함정 비공개 · 초증강 2배")
	check_eq(MatchRules.preset_of(MatchRules.sanitize({"trap_reveal": false})), &"", "어느 프리셋과도 다르면 빈 키")
	check_eq(MatchRules.sanitize({"bot_level": 4})["bot_level"], 4, "빈자리 컴퓨터 Lv.4")
	check_eq(MatchRules.sanitize({"bot_level": 9})["bot_level"], BotTemper.DEFAULT_LEVEL, "모르는 난이도는 기본")
	check_eq(MatchTelemetry.rules_label(classic), "클래식 완주전", "통계: 친선 [클래식 완주전]")
	check_eq(MatchTelemetry.rules_label(MatchRules.sanitize({"laws": false, "trap_reveal": false})), "법전OFF/함정비공개", "통계: 친선 [법전OFF/함정비공개]")
	check_eq(MatchTelemetry.rules_label(MatchRules.sanitize({"bot_level": 3}), true), "오리지널 표준/봇Lv.3", "빈자리 컴퓨터가 있으면 난이도")
	var state := GameState.new()
	state.match_rules = mind
	check_eq(MatchRules.weight_factor(state, AugmentRegistry.get_def(&"SUPER_09")), 2.0, "축제: 초증강 가중치 2배")
