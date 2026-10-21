# File: res://core_engine/data/l10n.gd
# Class: class_name L10n
# Role: 다국어(KO / EN / JA) 대비 창구. 화면 문구는 content_trickcal/data/ui_strings.csv(key, ko, en, ja)에서 tr_ui(key)로 꺼내고,
#       밸런스 표(증강·판정 도구·생떼 카드)의 문구 열은 pick(row, "title")처럼 현재 언어 열(title_en / title_ja)을 먼저 찾는다.
#       번역이 비어 있거나 열이 없으면 한국어로 돌아가므로(폴백) 번역을 조금씩 채워 넣어도 게임은 항상 돈다. 문구는 시뮬레이션에 쓰지 않아
#       참가자마다 언어가 달라도 온라인 판은 어긋나지 않는다.
class_name L10n
extends RefCounted

const UI_STRINGS_PATH: String = "res://content_trickcal/data/ui_strings.csv"
const DEFAULT_LANG: String = "ko"
## 지원 언어 (상단 언어 버튼이 이 순서로 돈다).
const LANGUAGES: Array[String] = ["ko", "en", "ja"]
const LANGUAGE_LABELS: Dictionary = {"ko": "KO", "en": "EN", "ja": "JA"}

## 지금 언어. 설정(user://settings.cfg)에 저장되며 GameSession.load_settings가 되살린다.
static var current_lang: String = DEFAULT_LANG
static var _ui: Dictionary = {}
static var _loaded: bool = false


## 언어를 바꾼다. 모르는 언어 코드면 무시하고 false.
static func set_language(lang: String) -> bool:
	var code: String = lang.strip_edges().to_lower()
	if not LANGUAGES.has(code):
		return false
	current_lang = code
	return true


## 언어 버튼: 다음 언어로 넘긴다 (ko -> en -> ja -> ko).
static func cycle_language() -> String:
	current_lang = LANGUAGES[(LANGUAGES.find(current_lang) + 1) % LANGUAGES.size()]
	return current_lang


static func language_label(lang: String = "") -> String:
	return str(LANGUAGE_LABELS.get(lang if lang != "" else current_lang, "KO"))


## 화면 문구 하나. args가 있으면 %로 채운다 (예: tr_ui("turn.other", [이름])). 표에 없는 키는 키 자체를 돌려준다 (빠진 문구가 화면에서 바로 보이게).
static func tr_ui(key: String, args: Array = []) -> String:
	var row: Dictionary = _table().get(key, {})
	if row.is_empty():
		push_warning("ui_strings.csv: 없는 키 '%s'" % key)
		return key
	var text: String = _cell(row, current_lang)
	if text == "":
		text = _cell(row, DEFAULT_LANG)
	if text == "":
		return key
	return text % args if not args.is_empty() else text


## 이 키가 표에 있는가 (테스트·도구용).
static func has_key(key: String) -> bool:
	return _table().has(key)


## 모든 키 (테스트용).
static func keys() -> Array:
	return _table().keys()


## 밸런스 표 한 행의 문구 열: 지금 언어가 한국어가 아니면 "<열>_<언어>"(예: desc_en)가 있고 비어 있지 않을 때 그 값을, 아니면 기본(한국어) 열을 준다.
static func pick(row: Dictionary, column: String, lang: String = "") -> String:
	var code: String = lang if lang != "" else current_lang
	if code != DEFAULT_LANG:
		var translated: String = str(row.get("%s_%s" % [column, code], ""))
		if translated.strip_edges() != "":
			return translated
	return str(row.get(column, ""))


## 표를 다시 읽는다 (테스트가 표를 바꿨을 때).
static func reload() -> void:
	_loaded = false
	_ui.clear()


static func _cell(row: Dictionary, lang: String) -> String:
	return str(row.get(lang, "")).replace("\\n", "\n")


static func _table() -> Dictionary:
	if not _loaded:
		_loaded = true
		for entry: Dictionary in DataTable.load_file(UI_STRINGS_PATH):
			var key: String = str(entry.get("key", "")).strip_edges()
			if key != "":
				_ui[key] = entry
	return _ui
