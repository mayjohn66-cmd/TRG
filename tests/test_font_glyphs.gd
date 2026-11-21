# File: res://tests/test_font_glyphs.gd
# Class: class_name TestFontGlyphs
# Role: 화면에 나오는 문자열(스크립트의 주석 밖·데이터 표)에 게임 글꼴(ONE Mobile POP + 나눔고딕)에 없는 글자가 없는지 검사한다.
#       웹 빌드에는 시스템 이모지 글꼴이 없어 이런 글자는 "0 1F 947" 같은 상자로 깨진다.
class_name TestFontGlyphs
extends TestCase

const SOURCE_DIRS: Array[String] = ["res://scenes", "res://core_engine", "res://core_engine/augments", "res://core_engine/cards", "res://core_engine/commands", "res://core_engine/entities", "res://core_engine/board", "res://core_engine/rules", "res://core_engine/rules/laws", "res://core_engine/tools", "res://core_engine/data", "res://content_trickcal/data"]


func test_every_displayed_character_exists_in_the_game_font() -> void:
	var font: Font = load("res://assets/fonts/game_ui_font.tres")
	var ja_font: Font = load(L10n.JA_FONT_PATH)  # 표의 일본어 열(가나·한자)은 일본어 화면에서 Mochiy Pop One으로 그린다
	var missing: Array[String] = []
	for dir_path: String in SOURCE_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			if not (file_name.ends_with(".gd") or file_name.ends_with(".csv")):
				continue
			var line_no: int = 0
			var in_ja_table: bool = false  # 스크립트의 일본어 전용 표(const ..._JA = {...})는 일본어 화면에서만 Mochiy로 그린다
			for line: String in FileAccess.get_file_as_string(dir_path + "/" + file_name).split("\n"):
				line_no += 1
				var shown: String = line
				if file_name.ends_with(".gd"):
					if line.begins_with("const ") and line.contains("_JA"):
						in_ja_table = not line.strip_edges().ends_with("}")
					elif in_ja_table and line.strip_edges() == "}":
						in_ja_table = false
					if line.strip_edges().begins_with("#"):
						continue
					var hash_at: int = line.find("#")
					if hash_at != -1 and line.substr(0, hash_at).count("\"") % 2 == 0:
						shown = line.substr(0, hash_at)
				for index: int in shown.length():
					var code: int = shown.unicode_at(index)
					if code < 0x2000 or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0xFE00 and code <= 0xFE0F) or code == 0xFEFF:
						continue
					var japanese: bool = (code >= 0x3000 and code <= 0x30FF) or (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0xFF00 and code <= 0xFFEF)
					# 일본어 글자는 Mochiy에 있어야 한다: ONE 모바일 POP체는 한자 자리에 빈 글리프를 두어 has_char가 참이어도 빈칸으로 그린다
					var ja_text: bool = japanese and (file_name.ends_with(".csv") or in_ja_table or line.contains("_JA"))
					if (ja_text and not ja_font.has_char(code)) or (not ja_text and not font.has_char(code)):
						missing.append("%s:%d U+%X" % [file_name, line_no, code])
	check(missing.is_empty(), "게임 글꼴에 없는 글자 %d개: %s" % [missing.size(), ", ".join(PackedStringArray(missing.slice(0, 12)))])
