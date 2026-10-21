# File: res://tests/test_l10n.gd
# Class: class_name TestL10n
# Role: 다국어 대비 구조 검사 - ui_strings.csv(key, ko, en, ja)와 tr_ui 폴백, 밸런스 표 번역 열(title_en 등) 폴백, 코드가 쓰는 화면 문구 키가 모두 표에 있는지
class_name TestL10n
extends TestCase


func _with_lang(lang: String, body: Callable) -> void:
	var saved: String = L10n.current_lang
	L10n.set_language(lang)
	body.call()
	L10n.set_language(saved)
	AugmentRegistry.reload()


func test_ui_strings_table_has_ko_en_ja_columns_and_korean_for_every_key() -> void:
	var text: String = FileAccess.get_file_as_string(L10n.UI_STRINGS_PATH)
	check_eq(DataTable.header_of(text), ["key", "ko", "en", "ja"] as Array[String], "ui_strings.csv 헤더")
	check(L10n.keys().size() >= 40, "화면 문구 %d개" % L10n.keys().size())
	for key: Variant in L10n.keys():
		var saved: String = L10n.current_lang
		L10n.set_language("ko")
		check(L10n.tr_ui(str(key)) != str(key), "%s: 한국어 문구가 있다" % key)
		L10n.set_language(saved)


func test_tr_ui_formats_and_falls_back_to_korean() -> void:
	_with_lang("ko", func() -> void:
		check_eq(L10n.tr_ui("btn.roll"), "굴리기", "한국어")
		check_eq(L10n.tr_ui("turn.other", ["에르핀"]), "에르핀 차례", "인자 채우기"))
	_with_lang("en", func() -> void:
		check_eq(L10n.tr_ui("btn.roll"), "굴리기", "영어 번역이 비어 있으면 한국어"))
	check_eq(L10n.tr_ui("no.such.key"), "no.such.key", "없는 키는 키 그대로 (빠진 문구가 바로 보이게)")


func test_unknown_language_is_ignored_and_cycle_wraps() -> void:
	var saved: String = L10n.current_lang
	L10n.set_language("ko")
	check(not L10n.set_language("xx"), "모르는 언어 코드는 무시")
	check_eq(L10n.current_lang, "ko", "그대로 한국어")
	check_eq(L10n.cycle_language(), "en", "ko -> en")
	check_eq(L10n.cycle_language(), "ja", "en -> ja")
	check_eq(L10n.cycle_language(), "ko", "ja -> ko")
	L10n.set_language(saved)


func test_pick_prefers_the_translated_column_only_when_filled() -> void:
	var row: Dictionary = {"title": "랜덤 변이 물약", "title_en": "Mutation Potion", "desc": "설명", "desc_en": "  "}
	check_eq(L10n.pick(row, "title", "ko"), "랜덤 변이 물약", "한국어는 기본 열")
	check_eq(L10n.pick(row, "title", "en"), "Mutation Potion", "영어 열이 있으면 영어")
	check_eq(L10n.pick(row, "desc", "en"), "설명", "영어 열이 비어 있으면 한국어")
	check_eq(L10n.pick(row, "title", "ja"), "랜덤 변이 물약", "일본어 열이 없으면 한국어")


func test_three_tables_have_translation_columns_and_loaders_use_them() -> void:
	for path: String in [GameData.AUGMENTS_PATH, GameData.DICE_PATH, GameData.CARDS_PATH]:
		var header: Array[String] = DataTable.header_of(FileAccess.get_file_as_string(path))
		check(header.has("desc_en") and header.has("desc_ja"), "%s: 번역 열" % path.get_file())
	# 표의 번역 열을 채우면 증강 카드·카드 이름이 그 언어로 나온다
	var augments: Array[Dictionary] = DataTable.load_file(GameData.AUGMENTS_PATH)
	for entry: Dictionary in augments:
		if entry["id"] == "UTIL_01":
			entry["title_en"] = "[Reforge] Mutation Potion"
	var cards: Array[Dictionary] = DataTable.load_file(GameData.CARDS_PATH)
	for entry: Dictionary in cards:
		if entry["id"] == "ACT_02":
			entry["name_en"] = "BANG!!"
	GameData.override_table("augments", augments)
	GameData.override_table("cards", cards)
	_with_lang("en", func() -> void:
		AugmentRegistry.reload()
		check_eq(AugmentRegistry.get_def(&"UTIL_01").title, "[Reforge] Mutation Potion", "증강 제목 영어")
		check_eq(AugmentRegistry.get_def(&"UTIL_02").title, "[기물 대개조] 전군 돌연변이", "번역이 없는 증강은 한국어")
		check_eq(GameData.text("cards", "ACT_02", "name"), "BANG!!", "카드 이름 영어")
		check_eq(GameData.text("cards", "ACT_03", "name"), "UDO +4", "번역이 없는 카드는 한국어"))
	GameData.override_table("augments")
	GameData.override_table("cards")
	AugmentRegistry.reload()
	check_eq(AugmentRegistry.get_def(&"UTIL_01").title, "[기물 재연성] 랜덤 변이 물약", "한국어로 돌아온다")


func test_every_tr_ui_key_used_in_code_exists() -> void:
	var regex: RegEx = RegEx.create_from_string("tr_ui\\(\"([a-z0-9_.]+)\"")
	var used: Dictionary = {}
	for path: String in _scripts("res://scenes") + _scripts("res://core_engine"):
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			used[found.get_string(1)] = path
	check(used.size() >= 30, "코드가 쓰는 화면 문구 키 %d개" % used.size())
	for key: String in used:
		check(L10n.has_key(key), "%s의 '%s'가 ui_strings.csv에 있다" % [str(used[key]).get_file(), key])


## 웹 내보내기는 스크립트를 변환하면서 보이지 않는 글자(BOM 등)를 지울 수 있다. 문자열 안에 이런 글자를 직접 적으면
## 에디터에서는 맞고 웹에서만 틀린다 (예: CSV BOM 검사가 begins_with("")가 되어 모든 표의 첫 글자가 잘렸다). 글자 코드로 써야 한다.
func test_scripts_have_no_invisible_characters() -> void:
	var invisible: Array[int] = [0xFEFF, 0x200B, 0x200C, 0x200D, 0x2060]
	for path: String in _scripts("res://scenes") + _scripts("res://core_engine"):
		var text: String = FileAccess.get_file_as_string(path)
		for code: int in invisible:
			check(not text.contains(char(code)), "%s: 보이지 않는 글자 U+%04X를 문자열에 직접 쓰지 않는다" % [path.get_file(), code])


func test_csv_header_first_character_is_kept() -> void:
	var rows: Array[Dictionary] = DataTable.parse("key,ko\nbtn.roll,굴리기\n")
	check(rows.size() == 1 and rows[0].has("key"), "BOM 없는 CSV는 첫 글자를 자르지 않는다 (%s)" % str(rows))
	var with_bom: Array[Dictionary] = DataTable.parse(char(0xFEFF) + "key,ko\nbtn.roll,굴리기\n")
	check(with_bom.size() == 1 and with_bom[0].has("key"), "BOM은 지운다")


func _scripts(folder: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return result
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			result.append(folder.path_join(file))
	for sub: String in dir.get_directories():
		result.append_array(_scripts(folder.path_join(sub)))
	return result
