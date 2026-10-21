# File: res://core_engine/data/game_data.gd
# Class: class_name GameData
# Role: content_trickcal/data/*.csv 밸런스 표(증강·판정 도구·생떼 카드)의 단일 조회 창구. 파일이 없거나 값이 비어 있으면 호출한 쪽이 넘긴 코드 기본값을 쓰므로 CSV가 깨져도 게임은 돈다. 모든 참가자가 같은 파일을 읽어야 하므로 게임 중에는 다시 읽지 않는다
class_name GameData
extends RefCounted

const AUGMENTS_PATH: String = "res://content_trickcal/data/augments_table.csv"
const DICE_PATH: String = "res://content_trickcal/data/dice_table.csv"
const CARDS_PATH: String = "res://content_trickcal/data/cards_table.csv"

## 각 표의 열. 끝의 *_en / *_ja는 번역 열이다 (비어 있으면 한국어 열을 쓴다, L10n.pick).
const AUGMENT_COLUMNS: Array[String] = ["id", "enabled", "category", "tier", "weight", "min_round", "title", "subtitle", "desc", "spec_preview", "param_1", "param_2", "target_ref", "icon_file",
	"title_en", "subtitle_en", "desc_en", "spec_preview_en", "title_ja", "subtitle_ja", "desc_ja", "spec_preview_ja"]
const DICE_COLUMNS: Array[String] = ["id", "enabled", "name", "desc", "spec_table", "min_step", "max_step", "jackpot_step", "icon_file",
	"name_en", "desc_en", "spec_table_en", "name_ja", "desc_ja", "spec_table_ja"]
const CARD_COLUMNS: Array[String] = ["id", "enabled", "type", "name", "parody_quote", "desc", "param_1", "param_2", "icon_file",
	"name_en", "parody_quote_en", "desc_en", "name_ja", "parody_quote_ja", "desc_ja"]
## 번역 열이 있는 문구 열 (L10n.pick이 현재 언어 열을 먼저 찾는다).
const LOCALIZED_COLUMNS: Dictionary = {
	"augments": ["title", "subtitle", "desc", "spec_preview"],
	"dice": ["name", "desc", "spec_table"],
	"cards": ["name", "parody_quote", "desc"],
}

## 증강 표의 category 열 -> AugmentCategory.
const CATEGORY_CODES: Dictionary = {
	"PAWN": GameEnums.AugmentCategory.PAWN_EVOLUTION,
	"DICE": GameEnums.AugmentCategory.TOOL_SWAP,
	"LAW": GameEnums.AugmentCategory.LAW_ENACT,
	"CARD": GameEnums.AugmentCategory.CARD_PACKAGE,
	"CHAOS": GameEnums.AugmentCategory.SUPER_GAMBLE,
	"UTIL": GameEnums.AugmentCategory.UTILITY,
}

static var _tables: Dictionary = {}


## 표 이름("augments"/"dice"/"cards") -> {id: 행}. 처음 부를 때 한 번만 읽는다.
static func table(name: String) -> Dictionary:
	if not _tables.has(name):
		var path: String = {"augments": AUGMENTS_PATH, "dice": DICE_PATH, "cards": CARDS_PATH}.get(name, "")
		_tables[name] = _index(DataTable.load_file(path))
	return _tables[name]


## 행을 직접 주입한다 (단위 테스트가 CSV를 고친 것과 같은 효과를 내는 용도). rows가 null이면 파일을 다시 읽는다.
static func override_table(name: String, rows: Variant = null) -> void:
	if rows == null:
		_tables.erase(name)
		return
	_tables[name] = _index(rows)


static func reload() -> void:
	_tables.clear()


static func row(name: String, id: Variant) -> Dictionary:
	return (table(name) as Dictionary).get(str(id), {})


## 행이 없으면 true (표에 없는 항목은 켜진 것으로 본다).
static func enabled(name: String, id: Variant) -> bool:
	var data: Dictionary = row(name, id)
	return DataTable.to_bool(data.get("enabled", "TRUE"), true) if not data.is_empty() else true


## param_1·param_2(index 1·2)를 정수로. 비어 있으면 default. (dice 표는 index 1·2·3 = min_step·max_step·jackpot_step)
static func param(name: String, id: Variant, index: int, default: int) -> int:
	var column: String = "param_%d" % index
	if name == "dice":
		column = ["", "min_step", "max_step", "jackpot_step"][clampi(index, 1, 3)]
	return DataTable.to_int(row(name, id).get(column, ""), default)


## 정수 열 이름으로 읽는다 (dice 표의 min_step·max_step·jackpot_step은 param(..., 1·2·3)으로 부른다).
static func column_int(name: String, id: Variant, column: String, default: int) -> int:
	return DataTable.to_int(row(name, id).get(column, ""), default)


## 텍스트 열. 비어 있으면 default. 문구 열은 현재 언어의 번역 열(예: desc_en)을 먼저 보고, 비어 있으면 한국어 열로 돌아간다.
static func text(name: String, id: Variant, column: String, default: String = "") -> String:
	var data: Dictionary = row(name, id)
	var value: String = L10n.pick(data, column) if (LOCALIZED_COLUMNS.get(name, []) as Array).has(column) else str(data.get(column, ""))
	return value if value.strip_edges() != "" else default


# --- 규칙 수치 (표의 RULE_* 행) -------------------------------------------------------------

static func rule_enabled(rule_id: String) -> bool:
	return enabled("augments", rule_id)


## 리벤지 부스터: 사출됐던 말이 다시 나갈 때 더해지는 칸 수 (꺼 두면 0).
static func revenge_bonus() -> int:
	return maxi(param("augments", "RULE_REVENGE_BOOST", 1, GameEnums.REVENGE_BONUS), 0) if rule_enabled("RULE_REVENGE_BOOST") else 0


## 부스터 발판 추가 전진 칸 수 (꺼 두면 0).
static func dash_steps() -> int:
	return maxi(param("augments", "RULE_DASH_PAD", 1, GameEnums.DASH_STEPS), 0) if rule_enabled("RULE_DASH_PAD") else 0


## 말 밟고 점프하기: 말 하나당 칸 수(param_1)와 한 번에 얻는 최대 칸 수(param_2). 꺼 두면 (0, 0).
static func leapfrog_per_pawn() -> int:
	return maxi(param("augments", "RULE_LEAPFROG", 1, 1), 0) if rule_enabled("RULE_LEAPFROG") else 0


static func leapfrog_max() -> int:
	return maxi(param("augments", "RULE_LEAPFROG", 2, GameEnums.LEAPFROG_MAX), 0) if rule_enabled("RULE_LEAPFROG") else 0


static func _index(rows: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for entry: Variant in rows:
		var data: Dictionary = entry
		var id: String = str(data.get("id", "")).strip_edges()
		if id != "":
			indexed[id] = data
	return indexed
