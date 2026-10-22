# File: res://tests/test_data_tables.gd
# Class: class_name TestDataTables
# Role: content_trickcal/data/*.csv 밸런스 표의 파싱 무결성과, 표를 고치면 드래프트·로직이 실제로 바뀌는지(enabled·weight·min_round·param·dice·cards)를 검사한다
class_name TestDataTables
extends TestCase

const FLAGS: Array[String] = ["TRUE", "FALSE"]
const TIERS: Array[String] = ["NORMAL", "GOLD", "PRISMA", "HOLO"]
const CATEGORIES: Array[String] = ["PAWN", "DICE", "LAW", "CARD", "CHAOS", "UTIL", "RULE"]


func cleanup() -> void:
	GameData.reload()
	AugmentRegistry.reload()
	super()


func _file_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


## 증강 표의 한 행을 바꿔 주입한다 (CSV를 고친 것과 같은 효과).
func _edit_augment(id: String, changes: Dictionary) -> void:
	var rows: Array = (GameData.table("augments") as Dictionary).values().duplicate(true)
	for row: Dictionary in rows:
		if str(row["id"]) == id:
			row.merge(changes, true)
	GameData.override_table("augments", rows)
	AugmentRegistry.reload()


func _edit_rows(table_name: String, id: String, changes: Dictionary) -> void:
	var rows: Array = (GameData.table(table_name) as Dictionary).values().duplicate(true)
	for row: Dictionary in rows:
		if str(row["id"]) == id:
			row.merge(changes, true)
	GameData.override_table(table_name, rows)


# --- 파서 ------------------------------------------------------------------------------

func test_csv_parser_handles_quotes_commas_newlines_and_bom() -> void:
	var text: String = "﻿id,desc,n\r\nA,\"안녕, \"\"세계\"\"\",3\r\n\r\nB,줄\\n바꿈,\n\"C\",\"진짜\n줄바꿈\",+5\n"
	var rows: Array[Dictionary] = DataTable.parse(text)
	check_eq(rows.size(), 3, "빈 줄은 건너뛴다")
	check_eq(rows[0]["id"], "A", "BOM이 헤더를 망치지 않는다")
	check_eq(rows[0]["desc"], "안녕, \"세계\"", "쉼표·큰따옴표 이스케이프")
	check_eq(rows[1]["desc"], "줄\n바꿈", "글자 그대로의 \\n은 줄바꿈이 된다")
	check_eq(rows[1]["n"], "", "빈 칸")
	check_eq(rows[2]["desc"], "진짜\n줄바꿈", "따옴표 안의 진짜 줄바꿈")
	check_eq(DataTable.to_int(rows[2]["n"], 0), 5, "+5는 5")
	check_eq(DataTable.to_int("", 9), 9, "빈 값은 기본값")
	check(DataTable.to_bool("true", false) and not DataTable.to_bool("FALSE", true) and DataTable.to_bool("???", true), "TRUE/FALSE 읽기")


# --- 표 무결성 -----------------------------------------------------------------------------

func test_the_three_tables_exist_with_the_agreed_headers() -> void:
	check_eq(DataTable.header_of(_file_text(GameData.AUGMENTS_PATH)), GameData.AUGMENT_COLUMNS, "augments_table.csv 헤더")
	check_eq(DataTable.header_of(_file_text(GameData.DICE_PATH)), GameData.DICE_COLUMNS, "dice_table.csv 헤더")
	check_eq(DataTable.header_of(_file_text(GameData.CARDS_PATH)), GameData.CARD_COLUMNS, "cards_table.csv 헤더")


func test_every_augment_is_in_the_table_exactly_once_with_valid_fields() -> void:
	var rows: Array[Dictionary] = DataTable.load_file(GameData.AUGMENTS_PATH)
	var seen: Dictionary = {}
	for row: Dictionary in rows:
		var id: String = str(row["id"])
		check(not seen.has(id), "%s: id가 겹치지 않는다" % id)
		seen[id] = true
		check(FLAGS.has(str(row["enabled"]).to_upper()), "%s: enabled는 TRUE/FALSE" % id)
		check(CATEGORIES.has(str(row["category"])), "%s: category 값 (%s)" % [id, row["category"]])
		check(TIERS.has(str(row["tier"])), "%s: tier 값 (%s)" % [id, row["tier"]])
		check(str(row["weight"]).is_valid_int() and int(row["weight"]) >= 0, "%s: weight는 0 이상 정수" % id)
		check(str(row["min_round"]).is_valid_int() and int(row["min_round"]) >= 1, "%s: min_round는 1 이상 정수" % id)
		if not id.begins_with("RULE_"):
			check(str(row["title"]) != "" and str(row["desc"]) != "", "%s: title·desc가 있다" % id)
	for def: AugmentDef in AugmentRegistry.all():
		check(seen.has(str(def.augment_id)), "%s: 코드의 증강이 표에 빠지지 않았다" % def.augment_id)
	check_eq(AugmentRegistry.all().size(), 62, "증강 62종 (기물 24 + 도구 12 + 교칙 8 + 카드 3 + 초증강 12 + 범용 3)")
	for rule_id: String in ["RULE_REVENGE_BOOST", "RULE_DASH_PAD", "RULE_LEAPFROG"]:
		check(seen.has(rule_id), "%s 규칙 수치 행" % rule_id)


func test_every_tool_and_card_is_in_its_table() -> void:
	var dice_rows: Dictionary = GameData.table("dice")
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		check(dice_rows.has(str(tool_id)), "dice_table.csv에 %s가 있다" % tool_id)
	var card_rows: Dictionary = GameData.table("cards")
	for card_id: StringName in CardRegistry.DECK_COMPOSITION.keys():
		check(card_rows.has(str(card_id)), "cards_table.csv에 %s가 있다" % card_id)
		check(["COUNTER", "INSTANT", "TRAP", "TRAP_CORNER", "SUMMON"].has(str(card_rows[str(card_id)]["type"])), "%s: type 값" % card_id)


func test_table_text_matches_the_built_in_defaults_for_every_augment() -> void:
	# CSV를 한 글자도 안 고쳤다면 선택 카드 설명은 코드 기본 문구와 같아야 한다 (표를 만들 때 문구가 어긋나지 않았는지).
	var state: GameState = make_state(2, 5)
	for def: AugmentDef in AugmentRegistry.all():
		if def.category == GameEnums.AugmentCategory.CARD_PACKAGE and def.augment_id != &"CARD_PACKAGE":
			continue  # 표에만 있는 카드 패키지(방어·공병 보급)는 코드 기본 문구가 없다
		var from_table: String = def.describe(state, 1)
		def.desc = ""
		var built_in: String = def.describe(state, 1)
		check_eq(from_table, built_in, "%s: 표 설명 = 코드 기본 설명" % def.augment_id)


func test_defaults_from_the_table_keep_the_original_numbers() -> void:
	check_eq(SuperAugments.flip_chance(), 50, "판 뒤집기 50%")
	check_eq(SuperAugments.devil_bonus(), 3, "악마의 계약 +3")
	check_eq(SuperAugments.minefield_count(), 2, "지뢰 2곳")
	check_eq(SuperAugments.raid_summon_cards(), 1, "도적단 소환 카드 1장")
	check_eq(SuperAugments.raid_steal_each(), 1, "도적단 1인당 1장")
	check_eq(SuperAugments.bakery_cards(), 3, "빵집 털이 카드 3장")
	check_eq(SuperAugments.sniper_advance(), 4, "저격수 +4")
	check_eq(SuperAugments.gambler_multiplier(), 2, "도박사 x2")
	check_eq(SuperAugments.gambler_overheat_at(), 1, "도박사 과열 눈금 1")
	check_eq(GameData.revenge_bonus(), 4, "리벤지 +4")
	check_eq(GameData.dash_steps(), 3, "발판 +3")
	check_eq(GameData.leapfrog_max(), 3, "점프 최대 +3")
	check_eq((LawRegistry.create("LAW_01") as VictoryLaw).goal(), 6, "투기장 6처치")
	check_eq((LawRegistry.create("LAW_04") as VictoryLaw).goal(), 16, "한방 16칸")


# --- enabled / weight / min_round ------------------------------------------------------------

func test_disabling_an_augment_in_the_table_removes_it_from_every_draft() -> void:
	_edit_augment("CARD_PACKAGE", {"enabled": "FALSE"})
	for seed_value: int in 40:
		var state: GameState = make_state(2, seed_value + 1)
		for offered: StringName in AugmentRegistry.generate_offers(state, 1, 5):
			check(offered != &"CARD_PACKAGE", "꺼진 증강은 제시되지 않는다 (시드 %d)" % seed_value)
	_edit_augment("CARD_PACKAGE", {"enabled": "TRUE"})
	var found: bool = false
	for seed_value: int in 60:
		var state2: GameState = make_state(2, seed_value + 1)
		found = found or AugmentRegistry.generate_offers(state2, 1, 5).has(&"CARD_PACKAGE")
	check(found, "켜면 다시 나온다")

func test_disabled_super_augment_and_law_are_not_available() -> void:
	_edit_augment("SUPER_01", {"enabled": "FALSE"})
	check(not AugmentRegistry.get_def(&"SUPER_01").is_available(make_state(2, 3), 1), "꺼진 초증강은 선택 불가")
	_edit_augment("AUG_LAW_07", {"enabled": "FALSE"})
	var state: GameState = make_state(2, 3)
	state.round_number = 5
	check(not AugmentRegistry.get_def(&"AUG_LAW_07").is_available(state, 1), "꺼진 교칙은 선택 불가")


func test_weight_zero_excludes_and_weights_steer_the_draft() -> void:
	var rows: Array = (GameData.table("augments") as Dictionary).values().duplicate(true)
	for row: Dictionary in rows:
		row["weight"] = "100" if ["TOOL_YUT", "AUG_LAW_04", "CARD_PACKAGE"].has(str(row["id"])) else "0"
	GameData.override_table("augments", rows)
	AugmentRegistry.reload()
	for seed_value: int in 20:
		var names: Array[String] = []
		var weighted_state: GameState = make_state(2, seed_value + 1)
		weighted_state.round_number = 3  # 특수 승리 교칙은 3라운드부터
		for offered: StringName in AugmentRegistry.generate_offers(weighted_state, 1):
			names.append(str(offered))
		names.sort()
		check_eq(names, ["AUG_LAW_04", "CARD_PACKAGE", "TOOL_YUT"] as Array[String], "가중치가 0이 아닌 3종만 나온다 (시드 %d)" % seed_value)
	# 한 계열 안에서는 가중치 비율로 고른다: 윷 도구 가중치만 크게 하면 도구 계열에서는 윷만 나온다
	_edit_augment("TOOL_YUT", {"weight": "100"})
	var heavy: Array = (GameData.table("augments") as Dictionary).values().duplicate(true)
	for row: Dictionary in heavy:
		if str(row["category"]) == "DICE":
			row["weight"] = "1000" if str(row["id"]) == "TOOL_HOLDEM" else "1"
		elif str(row["category"]) != "DICE":
			row["weight"] = "0"
	GameData.override_table("augments", heavy)
	AugmentRegistry.reload()
	var holdem: int = 0
	for seed_value: int in 60:
		var offered: Array[StringName] = AugmentRegistry.generate_offers(make_state(2, seed_value + 100), 1, 1)
		if offered.size() == 1 and offered[0] == &"TOOL_HOLDEM":
			holdem += 1
	check(holdem >= 55, "가중치 1000 대 1: 거의 항상 홀덤 (%d/60)" % holdem)


func test_min_round_hides_an_augment_until_its_round() -> void:
	_edit_augment("AUG_LAW_01", {"min_round": "5"})
	var state: GameState = make_state(2, 7)
	var def: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_01")
	state.round_number = 4
	check(not def.is_available(state, 1), "4라운드에는 아직 안 나온다")
	state.round_number = 5
	check(def.is_available(state, 1), "5라운드부터 나온다")


func test_tier_title_subtitle_and_placeholders_come_from_the_row() -> void:
	_edit_augment("SUPER_04", {"tier": "gold", "title": "[초증강] 지뢰 {p1}발", "subtitle": "특별 증강", "param_1": "9", "desc": "◆ 함정 {p1}곳"})
	var def: AugmentDef = AugmentRegistry.get_def(&"SUPER_04")
	check_eq(def.tier, "GOLD", "tier는 대문자로")
	check_eq(def.title, "[초증강] 지뢰 9발", "title의 {p1}")
	check_eq(def.subtitle, "특별 증강", "subtitle")
	check_eq(def.describe(make_state(2, 3), 1), "◆ 함정 9곳", "desc의 {p1}")
	check_eq(SuperAugments.minefield_count(), 9, "같은 값이 실제 지뢰 개수")


func test_a_new_table_row_adds_a_second_card_package() -> void:
	var rows: Array = (GameData.table("augments") as Dictionary).values().duplicate(true)
	rows.append({"id": "CARD_PACKAGE_BIG", "enabled": "TRUE", "category": "CARD", "tier": "GOLD", "weight": "100", "min_round": "1", "title": "[카드 패키지] 생떼 카드 {p1}장", "subtitle": "생떼 카드 패키지", "desc": "◆ 무작위 생떼 카드 {p1}장 획득", "spec_preview": "", "param_1": "4", "param_2": "", "target_ref": "CARD_PACKAGE", "icon_file": ""})
	GameData.override_table("augments", rows)
	AugmentRegistry.reload()
	var def: AugmentDef = AugmentRegistry.get_def(&"CARD_PACKAGE_BIG")
	check(def != null and def.category == GameEnums.AugmentCategory.CARD_PACKAGE, "표에만 있는 행이 새 증강이 된다")
	var state: GameState = make_state(2, 21)
	var result: Dictionary = def.apply(state, 1)
	check(bool(result["ok"]) and (state.hands[1] as Array).size() == 4, "param_1=4장을 실제로 준다")


# --- 수치(param)가 실제 로직을 바꾼다 ---------------------------------------------------------------

func test_super_augment_params_change_the_game_logic() -> void:
	_edit_augment("SUPER_03", {"param_1": "6"})
	var state: GameState = make_state(2, 9)
	state.get_pawn(12).is_finished = true
	var result: Dictionary = SuperAugments.apply(&"SUPER_03", state, 1)
	check(bool(result["ok"]), "악마의 계약 적용")
	check_eq(int(state.permanent_roll_bonus.get(1, 0)), 6, "영구 가속이 표의 6")
	_edit_augment("SUPER_09", {"param_1": "7"})
	check_eq(SuperAugments.sniper_advance(), 7, "저격수 전진 칸수")
	_edit_augment("SUPER_08", {"param_1": "1"})
	var state2: GameState = make_state(2, 10)
	for pawn: PlayerPawn in state2.pawns_of(1):
		pawn.has_left_start = true  # 출격할 대기 말이 없으면 카드만 받는다
		pawn.current_tile_idx = 2
	check(bool(SuperAugments.apply(&"SUPER_08", state2, 1)["ok"]) and (state2.hands[1] as Array).size() == 1, "빵집 털이 카드 1장")


func test_law_params_change_the_dice_rules() -> void:
	_edit_augment("AUG_LAW_01", {"param_1": "2"})
	var arena: VictoryLaw = LawRegistry.create("LAW_01")
	check_eq(arena.goal(), 2, "표의 목표 처치 수")
	check(arena.description.contains("2회"), "법전 문구도 2로 바뀐다")


func test_rule_rows_change_revenge_dash_and_leapfrog() -> void:
	_edit_augment("RULE_REVENGE_BOOST", {"param_1": "6"})
	var state: GameState = make_state(2, 3)
	state.boost_gimmicks = true
	var pawn: PlayerPawn = state.get_pawn(11)
	pawn.revenge_boost = true
	var report: MoveReport = MoveExecutor.forced_advance(state, pawn, 2)
	check_eq(report.revenge_bonus, 6, "리벤지 부스터 +6")
	check_eq(pawn.current_tile_idx, 8, "2 + 6칸")
	_edit_augment("RULE_REVENGE_BOOST", {"enabled": "FALSE"})
	var state2: GameState = make_state(2, 4)
	state2.boost_gimmicks = true
	var pawn2: PlayerPawn = state2.get_pawn(11)
	pawn2.revenge_boost = true
	check_eq(MoveExecutor.forced_advance(state2, pawn2, 2).revenge_bonus, 0, "꺼 두면 보너스 없음")
	check_eq(pawn2.current_tile_idx, 2, "눈금 그대로")
	_edit_augment("RULE_DASH_PAD", {"param_1": "2"})
	var state3: GameState = make_state(2, 5)
	state3.boost_gimmicks = true
	var dash_tile: int = BoardSpec.dash_tiles[1]
	var pawn3: PlayerPawn = place(state3, 11, dash_tile - 2, [dash_tile - 3])
	MoveExecutor.forced_advance(state3, pawn3, 2)
	check_eq(pawn3.current_tile_idx, dash_tile + 2, "발판 +2칸")
	_edit_augment("RULE_LEAPFROG", {"param_1": "2", "param_2": "4"})
	check_eq(GameData.leapfrog_per_pawn(), 2, "말 하나당 +2")
	check_eq(GameData.leapfrog_max(), 4, "최대 +4")


# --- 판정 도구 / 카드 -------------------------------------------------------------------------------

func test_dice_table_clamps_and_jackpot_overrides_apply_to_rolls() -> void:
	_edit_rows("dice", "DICE_YACHT", {"jackpot_step": "20"})
	var yacht: RollResult = RollResult.make(&"DICE_YACHT", 12)
	ToolRegistry.adjust_result(yacht)
	check_eq(yacht.steps, 20, "야추 잭팟 12 -> 20")
	var other: RollResult = RollResult.make(&"DICE_YACHT", 9)
	ToolRegistry.adjust_result(other)
	check_eq(other.steps, 9, "잭팟이 아닌 결과는 그대로")
	_edit_rows("dice", "D6", {"max_step": "4", "min_step": "2"})
	var high: RollResult = RollResult.make(&"D6", 6)
	ToolRegistry.adjust_result(high)
	var low: RollResult = RollResult.make(&"D6", 1)
	ToolRegistry.adjust_result(low)
	check_eq(high.steps, 4, "max_step 4로 깎는다")
	check_eq(low.steps, 2, "min_step 2로 올린다")
	var fail: RollResult = RollResult.make(&"D6", 0)
	ToolRegistry.adjust_result(fail)
	check_eq(fail.steps, 0, "0칸(실패)은 건드리지 않는다")


func test_dice_table_controls_names_spec_text_and_swap_availability() -> void:
	_edit_rows("dice", "YUT", {"name": "윷 (수정)", "spec_table": "눈금표: 내가 고친 표"})
	check_eq(ToolRegistry.create(&"YUT").display_name, "윷 (수정)", "도구 이름")
	check(ToolRegistry.table_line(&"YUT").contains("내가 고친 표"), "족보표 문구")
	_edit_rows("dice", "HOLDEM", {"enabled": "FALSE"})
	AugmentRegistry.reload()
	var state: GameState = make_state(2, 3)
	check(not AugmentRegistry.get_def(&"TOOL_HOLDEM").is_available(state, 1), "꺼진 도구는 교체 증강에서 빠진다")
	check(AugmentRegistry.get_def(&"TOOL_YUT").is_available(state, 1), "다른 도구는 그대로")


func test_cards_table_controls_deck_copies_names_and_numbers() -> void:
	var base_size: int = CardRegistry.default_deck().size()
	_edit_rows("cards", "ACT_02", {"enabled": "FALSE"})
	check(not CardRegistry.default_deck().has(&"ACT_02") and not CardRegistry.all_ids().has(&"ACT_02"), "꺼진 카드는 덱·카드 패키지 풀에서 빠진다")
	check_eq(CardRegistry.default_deck().size(), base_size - 2, "덱 장수 2장 감소")
	_edit_rows("cards", "ACT_02", {"enabled": "TRUE", "param_2": "5"})
	check_eq(CardRegistry.default_deck().size(), base_size + 3, "param_2 = 덱 장수 (2 -> 5)")
	_edit_rows("cards", "CNT_03", {"name": "내 우노 리버스"})
	check_eq(CardRegistry.get_card(&"CNT_03").display_name, "내 우노 리버스", "카드 이름")
	_edit_rows("cards", "ACT_04", {"param_1": "9"})
	var state: GameState = make_state(2, 3)
	var command: RocketBoosterCommand = RocketBoosterCommand.new(1)
	command.bind_state(state)
	command._run()
	check_eq(state.roll_bonus, 9, "로켓 +9")
	_edit_rows("cards", "TRP_05", {"param_1": "3"})
	check_eq(TrapDomino.chain_radius(), 3, "도미노 연쇄 반경 3")
	_edit_rows("cards", "ACT_09", {"param_1": "6"})
	check_eq(DuelRules.winner_advance(), 6, "결투 승자 +6")
	_edit_rows("cards", "ACT_03", {"param_1": "7"})
	check_eq(PenaltyBombCommand.advance_steps(), 7, "우노 +4 폭탄의 이동 보너스")
	check(MainBoard.card_summary(&"ACT_03").contains("+7칸"), "카드 설명에도 7이 반영된다")


func test_missing_or_empty_table_falls_back_to_code_defaults() -> void:
	GameData.override_table("augments", [] as Array[Dictionary])
	GameData.override_table("dice", [] as Array[Dictionary])
	GameData.override_table("cards", [] as Array[Dictionary])
	AugmentRegistry.reload()
	check_eq(AugmentRegistry.all().size(), 60, "표가 비어도 증강 60종이 코드 기본값으로 만들어진다 (표에만 있는 카드 패키지 2종 제외)")
	check_eq(GameData.revenge_bonus(), 4, "규칙 수치 기본값")
	check_eq(SuperAugments.minefield_count(), 2, "초증강 수치 기본값")
	check(CardRegistry.default_deck().size() > 0, "카드 덱 기본값")
	check(AugmentRegistry.get_def(&"SUPER_01").tier == "PRISMA", "초증강 기본 테두리")
