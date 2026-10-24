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


func test_tr_ui_formats_and_keeps_korean_source_for_english() -> void:
	_with_lang("ko", func() -> void:
		check_eq(L10n.tr_ui("btn.roll"), "굴리기", "한국어")
		check_eq(L10n.tr_ui("turn.other", ["에르핀"]), "에르핀 차례", "인자 채우기"))
	_with_lang("en", func() -> void:
		check_eq(L10n.tr_ui("btn.roll"), "굴리기", "영어 화면도 원문은 한국어 (화면에 나갈 때 번역)")
		check_eq(L10n.t(L10n.tr_ui("btn.roll")), "Roll", "화면 번역은 ui_strings.csv의 en 열")
		check_eq(L10n.t(L10n.tr_ui("turn.other", ["컴퓨터 2"])), "CPU 2's Turn", "형식 문구 + 인자도 번역"))
	check_eq(L10n.tr_ui("no.such.key"), "no.such.key", "없는 키는 키 그대로 (빠진 문구가 바로 보이게)")


func test_unknown_language_is_ignored_and_cycle_wraps() -> void:
	var saved: String = L10n.current_lang
	L10n.set_language("ko")
	check(not L10n.set_language("xx"), "모르는 언어 코드는 무시")
	check_eq(L10n.current_lang, "ko", "그대로 한국어")
	check_eq(L10n.cycle_language(), "en", "ko -> en")
	check_eq(L10n.cycle_language(), "ja", "en -> ja")
	check_eq(L10n.cycle_language(), "ko", "ja -> ko")
	check_eq([L10n.language_name("ko"), L10n.language_name("en"), L10n.language_name("ja")], ["한국어", "ENGLISH", "日本語"], "언어 선택 목록 이름은 각 언어 글자 그대로")
	L10n.set_language(saved)


func test_paper_in_duel_logs_is_translated_without_changing_supply_glyphs() -> void:
	for lang: String in ["en","ja"]:
		_with_lang(lang,func() -> void:
			for left: String in DuelRules.HAND_NAMES:
				for right: String in DuelRules.HAND_NAMES:
					var detail: String = L10n.t("(%s vs %s)"%[left,right])
					check(not L10n.has_hangul(detail),"all rock-paper-scissors pairs translate in %s: %s"%[lang,detail])
			check_eq(L10n.t("(보 vs 바위)"),"(Paper vs Rock)" if lang=="en" else "(パー vs グー)","paper is a word inside duel detail")
			check_eq(L10n.t("보"),"S" if lang=="en" else "補","the standalone supply icon keeps its existing abbreviation"))


func test_test_runner_starts_in_korean_regardless_of_os_locale() -> void:
	check_eq(L10n.detect_os_language(), "ko", "테스트 러너(-s 스크립트)는 기기 언어와 상관없이 한국어로 시작")


func test_pick_keeps_korean_source_and_japanese_translates_on_screen() -> void:
	var row: Dictionary = {"title": "랜덤 변이 물약", "title_en": "Mutation Potion", "title_ja": "変異ポーション"}
	_with_lang("ja", func() -> void:
		check_eq(L10n.pick(row, "title"), "랜덤 변이 물약", "일본어 화면도 원문은 한국어 (언어 전환이 이미 만든 글에도 먹는다)")
		check_eq(L10n.tr_ui("btn.roll"), "굴리기", "화면 문구 원문도 한국어")
		check_eq(L10n.t(L10n.tr_ui("btn.roll")), "振る", "화면 번역은 ui_strings.csv의 ja 열")
		check_eq(L10n.t(GameData.text("cards", "ACT_09", "name")), "一騎討ちデスマッチ", "카드 이름 일본어 (cards_table.csv name_ja)")
		check_eq(L10n.t(GameData.text("dice", "YUT", "name")), "伝統シラカバのユッ", "판정 도구 이름 일본어")
		check_eq(L10n.t("3라운드 시작!"), L10n.t("%d라운드 시작!") % [3], "일본어도 형식 틀에 숫자를 끼운다")
		check(not L10n.has_hangul(L10n.t("3라운드 시작!")), "일본어 틀 결과에 한글이 없다: %s" % L10n.t("3라운드 시작!"))
		check_eq(L10n.t("마"), "麻", "글자 하나짜리 라벨은 일본어 아이콘 글자"))


func test_data_tables_have_english_for_every_korean_text_cell() -> void:
	var counts: Dictionary = {}
	for path: String in L10n.DATA_TABLES:
		var header: Array[String] = DataTable.header_of(FileAccess.get_file_as_string(path))
		check(header.has("desc_en") and header.has("desc_ja"), "%s: 번역 열" % path.get_file())
		for row: Dictionary in DataTable.load_file(path):
			for column: String in L10n.DATA_TABLES[path]:
				var ko: String = str(row.get(column, ""))
				if not L10n.has_hangul(ko):
					continue
				var en: String = str(row.get(column + "_en", ""))
				check(en.strip_edges() != "" and not L10n.has_hangul(en), "%s %s.%s_en이 채워져 있다" % [path.get_file(), row.get("id", "?"), column])
				check(not L10n.has_hangul(str(row.get(column + "_ja", ""))), "%s %s.%s_ja에 한글이 없다" % [path.get_file(), row.get("id", "?"), column])
				counts[path.get_file()] = int(counts.get(path.get_file(), 0)) + 1
	check(int(counts.get("cards_table.csv", 0)) >= 32 * 2, "카드 32종의 이름·설명 영어 (%s)" % str(counts))
	for row: Dictionary in DataTable.load_file(L10n.UI_STRINGS_PATH):
		check(str(row.get("en", "")).strip_edges() != "", "ui_strings.csv %s의 en" % row.get("key", "?"))
		check(not L10n.has_hangul(str(row.get("ja", ""))), "ui_strings.csv %s의 ja에 한글이 없다" % row.get("key", "?"))


func test_loaded_augments_and_cards_show_english_on_screen() -> void:
	_with_lang("en", func() -> void:
		AugmentRegistry.reload()
		check_eq(L10n.t(AugmentRegistry.get_def(&"UTIL_01").title), "[Pawn Reforge] Random Mutation Potion", "증강 제목 영어")
		check_eq(L10n.t(AugmentRegistry.get_def(&"SUPER_11").title), "[Hyper Augment] Runaway Locomotive", "초증강 제목 영어")
		check(not L10n.has_hangul(L10n.t(AugmentRegistry.get_def(&"SUPER_06").desc)), "초증강 설명({p1} 채운 뒤)도 영어: %s" % L10n.t(AugmentRegistry.get_def(&"SUPER_06").desc))
		check_eq(L10n.t(GameData.text("cards", "ACT_09", "name")), "1v1 Deathmatch", "카드 이름 영어")
		check_eq(L10n.t(GameData.text("cards", "ACT_02", "name")), "BANG!", "원래 영어인 카드 이름은 그대로")
		check_eq(L10n.t(GameData.text("dice", "YUT", "name")), "Birchwood Yut Sticks", "판정 도구 이름 영어"))
	AugmentRegistry.reload()
	check_eq(AugmentRegistry.get_def(&"UTIL_01").title, "[기물 재연성] 랜덤 변이 물약", "한국어로 돌아온다")


func test_templates_fill_numbers_and_translate_names() -> void:
	_with_lang("en", func() -> void:
		check_eq(L10n.t("3라운드 시작!"), "Round 3 Start!", "숫자를 뽑아 영어 틀에")
		check_eq(L10n.t("%d라운드 시작!"), "Round %d Start!", "틀 자체도 번역 (L10n.tf)")
		check_eq(L10n.tf("%d라운드 시작!", [7]), "Round 7 Start!", "tf")
		check_eq(L10n.t("말 2번이 [체스:폰] 기물로 바뀌었습니다"), "Pawn 2 became a [Chess: Pawn]", "인자(기물 이름)도 번역")
		check_eq(L10n.t("[color=#ffe066][lb]법전] 투기장의 지배자 등록![/color]"), "[color=#ffe066][lb]Codex] Ruler of the Colosseum enacted![/color]", "BBCode 틀")
		check_eq(L10n.t("◆ 기본 말 1개 → [체스] 폰\n◆ 패시브: 반환점 이상 도달 시 퀸 승급"), "◆ 1 Basic Pawn → [Chess] Pawn\n◆ Passive: Promotes to Queen upon reaching the midpoint+", "여러 줄")
		check_eq(L10n.t("템포 업 Lv.2 · 광기"), "Tempo Up Lv.2 · Frenzy", "구분자로 이은 글")
		check_eq(L10n.t("마"), "M", "글자 하나짜리 라벨은 아이콘 글자")
		check_eq(L10n.t("★ 3위 확정! (승리 (말 4개 모두 완주))"), "★ #3 locked in! (Victory (all 4 pawns finished))", "겹친 괄호")
		check_eq(L10n.t("1번 [윷말]→[쇼기:각행], 3번 [장기:포]→[쇼기:보병]"), "#1 [Yut Token]→[Shogi: Kaku], #3 [Janggi: Cannon]→[Shogi: Fuhyo]", "[%s] 자리는 닫는 괄호를 넘지 않는다")
		check_eq(L10n.t("[color=#868e96][lb]R3][/color] ■ [color=#aaaaaa]컴퓨터 2[/color] : [lb]기본 주사위] 굴림 → 6칸"), "[color=#868e96][lb]R3][/color] ■ [color=#aaaaaa]CPU 2[/color] : [lb]Standard Dice] roll → 6 spaces", "액션 로그 한 줄 ([lb] 이스케이프 유지)")
		check_eq(L10n.t("[lb]방어 보급] 절대 방어 패키지 선택! 생떼 카드 획득: 교단의 칙령"), "Picked [lb]Defense Supply] Absolute Defense Pack! Tantrum Cards gained: Order Decree", "문장 두 개를 이은 글")
		check_eq(L10n.t("플레이어 이름 없음 xyz"), L10n.t("플레이어 이름 없음 xyz"), "모르는 글도 멈추지 않는다"))
	check_eq(L10n.t("3라운드 시작!"), "3라운드 시작!", "한국어 화면은 그대로")


func test_auto_translated_nodes_switch_instantly_both_ways() -> void:
	var saved: String = L10n.current_lang
	L10n.install()
	var label := Label.new()
	label.text = "레이스 시작!"
	L10n.set_language("en")
	check_eq(label.atr(label.text), "Race Start!", "자동 번역 노드: 영어")
	L10n.set_language("ja")
	check(label.atr(label.text) != label.text and not L10n.has_hangul(label.atr(label.text)), "자동 번역 노드: 일본어 (%s)" % label.atr(label.text))
	L10n.set_language("en")
	check_eq(label.atr(label.text), "Race Start!", "일본어 -> 영어")
	L10n.set_language("ko")
	check_eq(label.atr(label.text), "레이스 시작!", "다시 한국어 (원문이 한국어라 몇 번 오가도 그대로)")
	label.free()
	L10n.set_language(saved)


func test_pawn_letters_have_english_and_japanese_versions() -> void:
	var ja_font: Font = load(L10n.JA_FONT_PATH)
	for sub: Variant in PawnCatalog.SUB_LETTERS:
		var letter: String = str(PawnCatalog.SUB_LETTERS_EN.get(sub, ""))
		check(letter != "" and not L10n.has_hangul(letter) and letter.length() <= 2, "말 라벨 %s의 영어 (%s)" % [str(sub), letter])
		var ja: String = str(PawnCatalog.SUB_LETTERS_JA.get(sub, ""))
		check(ja.length() == 1 and not L10n.has_hangul(ja) and (ja_font.has_char(ja.unicode_at(0)) or ja == str(PawnCatalog.SUB_LETTERS[sub])), "말 라벨 %s의 일본어 (%s)" % [str(sub), ja])
	for sub: Variant in PawnCatalog.PROMOTED_LETTERS:
		check(PawnCatalog.PROMOTED_LETTERS_JA.has(sub) and PawnCatalog.PROMOTED_LETTERS_EN.has(sub), "승급 라벨 %s" % str(sub))
	_with_lang("ja", func() -> void: check_eq(PawnCatalog.basic_letter(), "駒", "일본어 기본 말 라벨"))


func test_japanese_swaps_the_theme_font_to_mochiy_pop() -> void:
	var saved: String = L10n.current_lang
	var font := load("res://assets/fonts/game_ui_font.tres") as FontVariation
	var ja_font: Font = load(L10n.JA_FONT_PATH)
	L10n.set_language("ja")
	check(font.base_font == ja_font, "일본어: 테마 글꼴의 기본 글꼴이 Mochiy Pop One")
	check((load("res://assets/fonts/game_small_font.tres") as FontVariation).base_font == ja_font, "일본어: 작은 글꼴도 Mochiy Pop One (리소스가 풀려나도 바뀐 채로)")
	check(not font.fallbacks.is_empty() and font.fallbacks[0].resource_path.ends_with("ONE-Mobile-POP.otf"), "원래 글꼴은 대체 글꼴로")
	L10n.set_language("ko")
	check(font.base_font.resource_path.ends_with("ONE-Mobile-POP.otf"), "한국어: 원래 글꼴")
	check(not font.fallbacks.has(ja_font), "한국어·영어 화면의 대체 글꼴에는 Mochiy를 넣지 않는다 (줄 높이가 달라져 한국어 화면 배치가 바뀐다)")
	var raw := load("res://assets/fonts/ONE-Mobile-POP.otf") as Font
	check(not raw.fallbacks.has(ja_font), "한국어: ONE 모바일 POP체에도 Mochiy 대체 글꼴 없음")
	L10n.set_language("ja")
	check(raw.fallbacks.has(ja_font), "일본어: ONE 모바일 POP체를 바로 쓰는 글자도 Mochiy로 한자를 채운다")
	L10n.set_language("en")
	check(not raw.fallbacks.has(ja_font), "영어로 바꾸면 떼어 낸다")
	for text: String in ["こんにちは", "振り", "漢字"]:
		for code: int in text.to_utf32_buffer().to_int32_array():
			check(ja_font.has_char(code), "Mochiy Pop One에 U+%04X" % code)
	L10n.set_language(saved)


## 코드의 한국어 문자열(로그·개발용 출력 제외)은 영어·일본어 화면에서 모두 번역된다. 새 문구를 넣고 translations.csv에 en·ja를 안 넣으면 여기서 걸린다.
func test_every_korean_literal_in_code_translates_to_english_and_japanese() -> void:
	var skip_files: Array[String] = ["match_telemetry.gd", "net_trace.gd", "sfx.gd", "l10n.gd"]
	var literal: RegEx = RegEx.create_from_string("(?<![&^@])\"((?:[^\"\\\\]|\\\\.)*)\"")
	var skip_line: RegEx = RegEx.create_from_string("\\b(push_warning|push_error|print|printerr|assert)\\(")
	var keep_korean: Array[String] = ["한국어"]
	for lang: String in L10n.TRANSLATED_LANGUAGES:
		_check_literals(lang, skip_files, literal, skip_line, keep_korean)


func _check_literals(lang: String, skip_files: Array[String], literal: RegEx, skip_line: RegEx, keep_korean: Array[String]) -> void:
	var missing: Array[String] = []
	var total: Array[int] = [0]  # 람다 안에서 늘리려고 배열에 담는다
	_with_lang(lang, func() -> void:
		for path: String in _scripts("res://scenes") + _scripts("res://core_engine"):
			if skip_files.has(path.get_file()):
				continue
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				var code: String = line.strip_edges()
				if code.begins_with("#") or code.contains("\"\"\"") or skip_line.search(line) != null:
					continue
				for found: RegExMatch in literal.search_all(line):
					var hash_at: int = line.find("#")
					if hash_at >= 0 and hash_at < found.get_start() and line.count("\"", 0, hash_at) % 2 == 0:
						continue
					var raw: String = found.get_string(1)
					if not L10n.has_hangul(raw) or keep_korean.has(raw):
						continue
					total[0] += 1
					var text: String = raw.replace("\\n", "\n").replace("\\\"", "\"")
					if L10n.has_hangul(L10n.t(text)):
						missing.append("%s: %s" % [path.get_file(), raw]))
	check(total[0] >= 1500, "코드의 한국어 문자열 %d개" % total[0])
	check(missing.is_empty(), "%s 사전에 없는 문자열 %d개: %s" % [lang, missing.size(), "\n".join(missing.slice(0, 40))])


func test_translation_table_keeps_format_specifiers_and_has_no_hangul() -> void:
	var spec: RegEx = RegEx.create_from_string(L10n.SPEC_PATTERN)
	var rows: Array[Dictionary] = DataTable.load_file(L10n.TRANSLATIONS_PATH)
	check(rows.size() >= 1500, "translations.csv %d줄" % rows.size())
	for row: Dictionary in rows:
		var ko: String = str(row.get("ko", ""))
		var a: Array[String] = []
		for found: RegExMatch in spec.search_all(ko):
			if not found.get_string().begins_with("{"):
				a.append(found.get_string())
		for lang: String in L10n.TRANSLATED_LANGUAGES:
			var translated: String = str(row.get(lang, ""))
			check(translated.strip_edges() != "" and not L10n.has_hangul(translated), "%s 번역이 있고 한글이 없다: %s -> %s" % [lang, ko, translated])
			var b: Array[String] = []
			for found: RegExMatch in spec.search_all(translated):
				if not found.get_string().begins_with("{"):
					b.append(found.get_string())
			check_eq(b, a, "%s 자리표시자 순서: %s" % [lang, ko])


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


## 영어 번역(translations.csv en 열)에 게임 글꼴에 없는 글자가 없다 (예: Rosé의 é는 웹에서 □로 깨진다).
func test_english_translations_use_only_glyphs_in_the_game_font() -> void:
	var font: Font = load("res://assets/fonts/game_ui_font.tres")
	var file := FileAccess.open("res://content_trickcal/data/translations.csv", FileAccess.READ)
	check(file != null, "translations.csv")
	if file == null:
		return
	file.get_csv_line()
	var missing: Dictionary = {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2:
			continue
		for index: int in row[1].length():
			var code: int = row[1].unicode_at(index)
			if code > 127 and not (code >= 0xAC00 and code <= 0xD7A3) and not font.has_char(code):
				missing[row[1][index]] = row[0]
	check(missing.is_empty(), "영어 번역에 글꼴에 없는 글자: %s" % str(missing))
