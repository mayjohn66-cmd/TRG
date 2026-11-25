# File: res://tests/test_board_catalog.gd
# Class: class_name TestBoardCatalog
# Role: 보드판은 데이터(BoardCatalog)만으로 만든다 — 새 보드를 BOARDS에 한 줄 더했을 때 빠진 데이터·그림·번역을 바로 잡아 주는 검사,
#       그리고 보드 id·보드별 분기가 다른 코드에 다시 하드코딩되지 않게 막는 검사.
class_name TestBoardCatalog
extends TestCase

const PRELUDE_SCRIPT = preload("res://scenes/law_victory_prelude.gd")
const PREVIEW_DIR: String = "res://assets/ui/trickcal/board_preview/"
const SHOP_KEYS: Array[String] = ["name", "toast", "law_tag", "visit_stamp", "legend", "legend_color", "words", "band", "edge", "ink", "decal", "rulebook"]
const PORTAL_KEYS: Array[String] = ["name", "tiles_key", "warps", "legend", "legend_color", "band", "edge", "ink", "decal", "rulebook"]
const VARIANT_KEYS: Array[String] = ["name", "condition", "card_title", "win_reason", "result_phrase"]
## 승리 제목 무대는 넣으면 넷 다 (아이콘·도입 무대는 없으면 원래 교칙 것을 쓴다)
const THEME_KEYS: Array[String] = ["theme", "paper", "comic_title", "geometry_key"]


func _translated(text: String) -> bool:
	for lang: String in ["en", "ja"]:
		var result: String = L10n.translate_text(text, lang)
		if result == text or L10n.has_hangul(result):
			return false
	return true


func test_every_board_has_complete_data_art_and_translations() -> void:
	var seen: Array[StringName] = []
	for board: Dictionary in BoardCatalog.BOARDS:
		var id: StringName = board["id"]
		check(not seen.has(id), "보드 id는 하나씩: %s" % id)
		seen.append(id)
		for key: String in ["name", "desc", "tiles", "shop", "portal", "surface", "palette"]:
			check(board.has(key), "%s 보드에 %s가 있다" % [id, key])
		check(BoardCatalog.SHOP_KINDS.has(board.get("shop")), "%s 보드의 빵집 자리 칸 종류는 SHOP_KINDS에 있다" % id)
		check(BoardCatalog.PORTAL_KINDS.has(board.get("portal")), "%s 보드의 옷장 자리 칸 종류는 PORTAL_KINDS에 있다" % id)
		check(ResourceLoader.exists(str(board.get("surface", ""))), "%s 보드의 판 바닥 그림이 있다: %s" % [id, board.get("surface")])
		check(ResourceLoader.exists("%s%s.webp" % [PREVIEW_DIR, id]), "%s 보드의 선택 화면 미리보기 그림이 있다 (%s%s.webp)" % [id, PREVIEW_DIR, id])
		for key: String in (board.get("palette", {}) as Dictionary):
			check(BoardSkin.PALETTE_DEFAULT.has(key) or key in ["corner_fill", "half_fill"], "%s 보드의 색 이름 %s는 BoardSkin이 쓰는 이름" % [id, key])
		check(_translated(str(board["name"])), "%s 보드 이름 번역 행 (en·ja): %s" % [id, board["name"]])
		check(_translated(str(board["desc"])), "%s 보드 설명 번역 행 (en·ja)" % id)
		check(_translated("%s 보기" % board["name"]), "도감 보드 넘기기 화살표 문구 번역 행: %s 보기" % board["name"])
		var facts: Array = BoardCatalog.facts_of(id)
		check_eq(facts.size(), 4 + BoardCatalog.board_kinds(id).size(), "%s 보드 특수 칸 요약 (칸 수·코너·반환점·부스터 + 칸 종류마다 한 줄)" % id)
		for fact: Array in facts:
			check(not str(fact[1]).begins_with("0"), "%s 보드 요약에 0곳인 칸이 없다: %s" % [id, fact])
		var layout: Dictionary = BoardCatalog.layout_of(id)
		var portal: Dictionary = BoardCatalog.PORTAL_KINDS.get(board.get("portal"), {})
		check(not (layout.get(str(portal.get("tiles_key", "")), []) as Array).is_empty(), "%s 보드의 옷장 자리 칸이 배치된다" % id)


func test_every_tile_kind_is_complete() -> void:
	for kinds: Dictionary in [BoardCatalog.SHOP_KINDS, BoardCatalog.PORTAL_KINDS]:
		var required: Array[String] = SHOP_KEYS if kinds == BoardCatalog.SHOP_KINDS else PORTAL_KEYS
		for kind_id: StringName in kinds:
			var kind: Dictionary = kinds[kind_id]
			for key: String in required:
				check(kind.has(key), "칸 종류 %s에 %s가 있다" % [kind_id, key])
			check(ResourceLoader.exists(str(kind.get("decal", ""))), "칸 종류 %s의 칸 그림이 있다" % kind_id)
			check(BoardSkin.decal_source(String(kind_id)) != null, "보드 그림이 칸 종류 %s의 그림을 읽는다" % kind_id)
			check(_translated(str(kind.get("name", ""))), "칸 종류 %s 이름 번역 행: %s" % [kind_id, kind.get("name")])
			if kinds == BoardCatalog.SHOP_KINDS:
				for lang: String in ["ko", "en", "ja"]:
					check((kind.get("words", {}) as Dictionary).has(lang), "칸 종류 %s의 카드 문구 낱말(%s)" % [kind_id, lang])


func test_every_law_variant_is_complete() -> void:
	for board: Dictionary in BoardCatalog.BOARDS:
		var variants: Dictionary = board.get("law_variants", {})
		for law_id: String in variants:
			var variant: Dictionary = variants[law_id]
			check(VictoryLaw.DEFS.has(law_id), "%s 보드가 바꿔 쓰는 %s는 있는 교칙" % [board["id"], law_id])
			for key: String in VARIANT_KEYS:
				check(variant.has(key), "%s 보드 %s 판에 %s가 있다" % [board["id"], law_id, key])
			for lang: String in ["ko", "en", "ja"]:
				check((variant.get("card_title", {}) as Dictionary).has(lang), "%s 보드 %s 판 카드 제목(%s)" % [board["id"], law_id, lang])
			if variant.has("icon"):
				check(ResourceLoader.exists(AugmentArt.ROOT + str(variant["icon"])), "%s 보드 %s 판 아이콘 그림이 있다" % [board["id"], law_id])
			if variant.has("stage"):
				check(PRELUDE_SCRIPT.STAGES.has(StringName(str(variant["stage"]))), "%s 보드 %s 판의 승리 무대(stage)가 LawVictoryPrelude.STAGES에 있다" % [board["id"], law_id])
			for key: String in THEME_KEYS:
				check(variant.has("theme") == variant.has(key), "%s 보드 %s 판의 승리 제목 무대는 %s까지 함께 넣는다" % [board["id"], law_id, key])
			# 지금 판의 보드로 켜면 이름·조건·아이콘이 그 판을 따른다
			VictoryLaw.preview_board = board["id"]
			check_eq(VictoryLaw.name_of(law_id), str(variant["name"]), "%s 보드에서 %s 이름" % [board["id"], law_id])
			if variant.has("icon"):
				check(AugmentArt.law_candidates(law_id)[0].ends_with(str(variant["icon"])), "%s 보드에서 %s 아이콘" % [board["id"], law_id])
			VictoryLaw.preview_board = &""


## 보드 id·보드별 분기는 BoardCatalog에만: 다른 코드가 보드 이름으로 갈라지면 새 보드를 만들 때 그곳을 놓친다.
func test_no_board_ids_are_hardcoded_outside_the_catalog() -> void:
	var offenders: PackedStringArray = []
	for folder: String in ["res://scenes", "res://core_engine", "res://core_engine/board", "res://core_engine/rules/laws", "res://core_engine/augments"]:
		for file: String in DirAccess.get_files_at(folder):
			if file.get_extension() != "gd" or file == "board_catalog.gd":
				continue
			var text: String = FileAccess.get_file_as_string("%s/%s" % [folder, file])
			for board: Dictionary in BoardCatalog.BOARDS:
				if board["id"] == BoardCatalog.DEFAULT_ID:
					continue
				if text.contains("&\"%s\"" % board["id"]) or text.contains("== \"%s\"" % board["id"]):
					offenders.append("%s (%s)" % [file, board["id"]])
			for flag: String in ["BoardSpec.convenience", "BoardSpec.witch"]:
				if text.contains(flag):
					offenders.append("%s (%s)" % [file, flag])
	check(offenders.is_empty(), "보드별 분기는 BoardCatalog 데이터로: %s" % ", ".join(offenders))
