# File: res://core_engine/data/l10n.gd
# Class: class_name L10n
# Role: 다국어(KO / EN / JA) 창구. 게임 코드는 지금처럼 한국어 문구를 만들고, 화면에 나갈 때 t()가 현재 언어로 바꾼다.
#       - 영어 사전: content_trickcal/data/translations.csv(ko, en, 코드 문구) + 밸런스 표의 *_en 열(증강·카드·판정 도구) + ui_strings.csv의 en 열.
#       - 형식 문구("%d라운드 시작!" 같은 틀)는 원문 틀을 정규식으로 바꿔 숫자·이름을 뽑아낸 뒤 영어 틀에 다시 끼운다 (이름 같은 인자도 다시 번역).
#       - 줄 단위·BBCode 태그 단위로 나눠서도 찾으므로 여러 문구를 이어 붙인 글도 번역된다.
#       - install()이 TranslationServer에 이 사전을 붙여 Label·Button·툴팁 등 자동 번역 노드는 글자를 바꿀 때마다 저절로 번역되고,
#         언어를 바꾸면 모든 노드가 즉시 다시 번역된다 (원문은 늘 한국어라 KR ↔ EN을 몇 번 오가도 어긋나지 않는다).
#       번역이 없으면 한국어 그대로(폴백)라 게임은 항상 돈다. 문구는 시뮬레이션에 쓰지 않아 참가자마다 언어가 달라도 온라인 판은 어긋나지 않는다.
class_name L10n
extends RefCounted

const UI_STRINGS_PATH: String = "res://content_trickcal/data/ui_strings.csv"
const TRANSLATIONS_PATH: String = "res://content_trickcal/data/translations.csv"
## 밸런스 표의 번역 열: 표 경로 → 문구 열들 (<열>_en이 영어).
const DATA_TABLES: Dictionary = {
	"res://content_trickcal/data/augments_table.csv": ["title", "subtitle", "desc", "spec_preview"],
	"res://content_trickcal/data/cards_table.csv": ["name", "parody_quote", "desc"],
	"res://content_trickcal/data/dice_table.csv": ["name", "desc", "spec_table"],
}
const DEFAULT_LANG: String = "ko"
## 지원 언어 (설정 화면 목록 순서).
const LANGUAGES: Array[String] = ["ko", "en", "ja"]
const LANGUAGE_LABELS: Dictionary = {"ko": "KR", "en": "EN", "ja": "JA"}
## 일본어 화면에서 기본 글꼴로 쓰는 글꼴 (ONE 모바일 POP체는 한자 칸이 비어 있어 일본어 문장이 □로 빠진다).
const JA_FONT_PATH: String = "res://assets/fonts/MochiyPopOne-Regular.ttf"
const THEME_FONT_PATHS: Array[String] = ["res://assets/fonts/game_ui_font.tres", "res://assets/fonts/game_small_font.tres"]
const HANGUL_PATTERN: String = "[가-힣ㄱ-ㆎ]"
## 원문 틀의 자리표시자: %s %d %.1f %02d %% 와 밸런스 표의 {p1}.
const SPEC_PATTERN: String = "%(?:%|[-+0 #]*\\d*(?:\\.\\d+)?[sdfixXc])|\\{p\\d\\}"
## 이 BBCode 태그 사이 글자는 따로 번역한다.
const BBCODE_TAG_PATTERN: String = "\\[/?(?:b|i|u|s|code|center|right|left|fill|indent|ul|ol|url|color|bgcolor|fgcolor|font|font_size|outline_size|outline_color|wave|shake|rainbow|pulse|tornado|fade|img|hint)(?:=[^\\]]*)?\\]"
## 짧은 문구를 이어 붙인 글을 나눌 구분자 (긴 것부터).
const SEPARATORS: Array[String] = [" : ", "  ·  ", " · ", " / ", ", ", "  ", " → ", " ↔ ", "] ", " - ", ": "]
const MAX_DEPTH: int = 10
## 앞 조각이 문장 끝 기호를 가진 채로 나누는 구분자.
const KEEP_LEFT_SEPARATORS: Array[String] = ["! ", ". "]
## 앞뒤에 다른 글이 붙은 채로 찾는 틀은 고정 글자가 이만큼 이상일 때만 (짧은 틀이 문장 속에서 엉뚱하게 걸리지 않게).
const LOOSE_MIN_LITERAL: int = 6
## 글자 하나짜리 화면 라벨(판정 도구·증강 종류 아이콘 글자)의 영어. 문장 속 같은 글자는 낱말로 번역한다 (마 → Horse).
const GLYPHS_EN: Dictionary = {
	"윷": "Y", "룰": "R", "친": "C", "탄": "G", "화": "H", "마": "M", "타": "T", "야": "Y", "핀": "P",
	"법": "C", "초": "H", "보": "S",
	"토": "To", "용": "DK", "금": "NK", "비": "B", "카": "MC", "배": "Sh", "흑": "Bk", "백": "Wt",
	"각": "Ka", "계": "Ke", "루": "Lu", "깃": "Ms", "나": "N", "룩": "R",
}
## 문장 속 글자 하나짜리 기물 이름.
const SINGLE_WORDS_EN: Dictionary = {
	"폰": "Pawn", "퀸": "Queen", "킹": "King", "포": "Cannon", "차": "Chariot", "마": "Horse", "상": "Elephant",
	"광": "Gwang", "띠": "Ribbon", "피": "Junk", "말": "Pieces",
}

## 지금 언어. 설정(user://settings.cfg)에 저장되며 GameSession.load_settings가 되살린다.
static var current_lang: String = DEFAULT_LANG
## 언어가 바뀌면 부를 함수들 (상단 토글·설정 화면이 글자를 다시 그린다). 주인 노드가 사라진 함수는 알아서 빠진다.
static var _listeners: Array[Callable] = []
static var _ui: Dictionary = {}
static var _loaded: bool = false
static var _dict: Dictionary = {}  ## 한국어 원문 → 영어
static var _templates: Array = []  ## [{"regex", "anchor", "specs", "en"}] (구체적인 틀이 앞)
static var _fragments: Array = []  ## 마지막 수단: 글 속 한국어 조각을 바꿀 [원문, 영어] (긴 것부터)
static var _cache: Dictionary = {}
static var _dict_loaded: bool = false
static var _hangul: RegEx = null
static var _bbcode: RegEx = null
static var _peel_pattern: RegEx = null
static var _tag_dict: Dictionary = {}  ## BBCode 태그를 뺀 원문 → [원문, 영어]
static var _translation: Translation = null
static var _base_fonts: Dictionary = {}  ## 글꼴 경로 → [원래 base_font, 원래 fallbacks]


## 언어를 바꾼다. 모르는 언어 코드면 무시하고 false. 화면 노드는 TranslationServer를 통해 바로 다시 번역된다.
static func set_language(lang: String) -> bool:
	var code: String = lang.strip_edges().to_lower()
	if not LANGUAGES.has(code):
		return false
	current_lang = code
	_cache.clear()
	_apply()
	return true


## 처음 실행이라 저장된 언어가 없을 때: 기기 언어가 한국어면 KR, 아니면 EN.
## 환경 변수 TRG_LANG(ko/en/ja)이 있으면 그것을, 테스트 러너(-s 스크립트로 띄운 SceneTree)는 늘 한국어로 시작한다.
static func detect_os_language() -> String:
	var forced: String = OS.get_environment("TRG_LANG").strip_edges().to_lower()
	if LANGUAGES.has(forced):
		return forced
	var loop: MainLoop = Engine.get_main_loop()
	if loop != null and loop.get_script() != null:
		return DEFAULT_LANG
	return "ko" if OS.get_locale_language().to_lower() == "ko" else "en"


## 상단 [KR / EN] 토글: KR ↔ EN (일본어 화면에서 누르면 KR로).
static func toggle_language() -> String:
	set_language("en" if current_lang == "ko" else "ko")
	return current_lang


## 설정 화면 목록용: 다음 언어로 넘긴다 (ko -> en -> ja -> ko).
static func cycle_language() -> String:
	set_language(LANGUAGES[(LANGUAGES.find(current_lang) + 1) % LANGUAGES.size()])
	return current_lang


static func language_label(lang: String = "") -> String:
	return str(LANGUAGE_LABELS.get(lang if lang != "" else current_lang, "KR"))


## 화면 문구 번역의 중앙 함수: 한국어 원문(완성된 글이든 형식 틀이든)을 현재 언어로. 한국어 화면이거나 번역이 없으면 그대로.
static func t(text: String) -> String:
	if current_lang != "en" or text == "":
		return text
	return translate_text(text, "en")


## t()를 쓴 형식 틀 채우기: L10n.tf("%d라운드 시작!", [3]).
static func tf(template: String, args: Array) -> String:
	return t(template) % args


## 화면 문구 하나. args가 있으면 %로 채운다 (예: tr_ui("turn.other", [이름])). 표에 없는 키는 키 자체를 돌려준다 (빠진 문구가 화면에서 바로 보이게).
## 영어는 한국어 원문을 돌려주고 화면에 나갈 때 번역한다 (ui_strings.csv의 en 열이 사전에 들어 있다). 그래야 이미 만든 버튼도 KR ↔ EN 전환에 바로 바뀐다.
static func tr_ui(key: String, args: Array = []) -> String:
	var row: Dictionary = _table().get(key, {})
	if row.is_empty():
		push_warning("ui_strings.csv: 없는 키 '%s'" % key)
		return key
	var text: String = _cell(row, current_lang if current_lang != "en" else DEFAULT_LANG)
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


## 밸런스 표 한 행의 문구 열. 일본어는 "<열>_ja"가 있으면 그 값을 쓴다.
## 영어는 원문(한국어)을 그대로 두고 화면에 나갈 때 t()가 *_en 열로 바꾼다 (그래야 KR ↔ EN 전환이 이미 만든 글에도 바로 먹는다).
static func pick(row: Dictionary, column: String, lang: String = "") -> String:
	var code: String = lang if lang != "" else current_lang
	if code != DEFAULT_LANG and code != "en":
		var translated: String = str(row.get("%s_%s" % [column, code], ""))
		if translated.strip_edges() != "":
			return translated
	return str(row.get(column, ""))


## 표를 다시 읽는다 (테스트가 표를 바꿨을 때).
static func reload() -> void:
	_loaded = false
	_ui.clear()
	_dict_loaded = false
	_dict.clear()
	_templates.clear()
	_fragments.clear()
	_tag_dict.clear()
	_cache.clear()


## 글 속에 한글이 남았는가 (영어 화면 검사용).
static func has_hangul(text: String) -> bool:
	return _hangul_regex().search(text) != null


## TranslationServer에 사전을 붙이고 현재 언어를 적용한다. 여러 번 불러도 한 번만 붙는다.
## 스크립트로 만든 Translation이 엔진 종료 때까지 TranslationServer에 남아 있으면 GDScript가 먼저 내려간 뒤 지워지며 엔진이 멈춘다(SIGABRT).
## 그래서 씬 트리의 root가 내려갈 때(스크립트가 아직 살아 있을 때) 떼어 낸다.
static func install() -> void:
	if _translation == null:
		_translation = L10nTranslation.new()
		_translation.locale = "en"
		TranslationServer.add_translation(_translation)
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null and not tree.root.tree_exiting.is_connected(uninstall):
			tree.root.tree_exiting.connect(uninstall)
	_apply()


## TranslationServer에서 사전을 뗀다 (게임 종료 때 자동, 테스트용).
static func uninstall() -> void:
	if _translation != null:
		TranslationServer.remove_translation(_translation)
		_translation = null


## 원문 → 지정 언어 (지금은 영어 사전만 있다). 캐시를 쓴다.
static func translate_text(text: String, lang: String = "en") -> String:
	if lang != "en" or text == "" or not has_hangul(text):
		return text
	if _cache.has(text):
		return _cache[text]
	_ensure_dict()
	# BBCode 글([lb]로 [를 적은 액션 로그 등)은 [lb]를 [로 풀어 번역한 뒤 태그가 아닌 [를 다시 [lb]로 적는다
	var escaped: bool = text.contains("[lb]")
	var result: String = _translate(text.replace("[lb]", "[") if escaped else text, 0)
	if escaped:
		result = _escape_brackets(result)
	if _cache.size() > 20000:
		_cache.clear()
	_cache[text] = result
	return result


static func _apply() -> void:
	if _translation != null:
		TranslationServer.set_locale(current_lang)
	_apply_fonts()
	var alive: Array[Callable] = []
	for listener: Callable in _listeners:
		if listener.is_valid():
			alive.append(listener)
	_listeners = alive
	for listener: Callable in alive:
		listener.call()


## 언어가 바뀔 때 부를 함수를 등록한다.
static func on_changed(listener: Callable) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


## 일본어면 전역 글꼴(테마 글꼴)의 기본 글꼴을 Mochiy Pop One으로 바꾸고 원래 글꼴을 대체 글꼴로 돌린다. 다른 언어면 원래대로.
static func _apply_fonts() -> void:
	for path: String in THEME_FONT_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var variation := load(path) as FontVariation
		if variation == null:
			continue
		if not _base_fonts.has(path):
			_base_fonts[path] = [variation.base_font, variation.fallbacks.duplicate()]
		var original: Array = _base_fonts[path]
		if current_lang == "ja" and ResourceLoader.exists(JA_FONT_PATH):
			var ja_font := load(JA_FONT_PATH) as Font
			var chain: Array[Font] = [original[0] as Font]
			for font: Font in original[1]:
				if font != ja_font:
					chain.append(font)
			variation.base_font = ja_font
			variation.fallbacks = chain
		else:
			variation.base_font = original[0]
			variation.fallbacks = original[1]


## 조각 단위로도 결과를 캐시한다 (액션 로그처럼 한 줄씩 늘어나는 긴 글을 매번 처음부터 번역하지 않게). 글자 하나짜리는 위치(라벨 전체인가)에 따라 달라 캐시하지 않는다.
static func _translate(text: String, depth: int) -> String:
	if depth > MAX_DEPTH or not has_hangul(text):
		return text
	if text.length() > 1 and _cache.has(text):
		return _cache[text]
	var result: String = _translate_uncached(text, depth)
	if text.length() > 1:
		_cache[text] = result
	return result


static func _translate_uncached(text: String, depth: int) -> String:
	if text.length() == 1:
		if depth == 0 and GLYPHS_EN.has(text):
			return GLYPHS_EN[text]
		if SINGLE_WORDS_EN.has(text):
			return SINGLE_WORDS_EN[text]
	if _dict.has(text):
		return _dict[text]
	# 0) BBCode 태그를 빼고 같은 원문이면 영어에 입력 쪽 태그를 같은 순서로 다시 끼운다 (도감의 [b] -> [bgcolor] 등)
	var retagged: String = _match_ignoring_tags(text)
	if retagged != "":
		return retagged
	# 1) 여러 줄이면 줄마다 (모든 줄이 번역되면 그것을 쓴다)
	var by_line: String = ""
	if text.contains("\n"):
		var lines: PackedStringArray = text.split("\n")
		var out: PackedStringArray = []
		for line: String in lines:
			out.append(_translate(line, depth + 1))
		by_line = "\n".join(out)
		if not has_hangul(by_line):
			return by_line
	# 2) 액션 로그 한 줄 "[R3] ■ 이름 : 본문": 앞머리와 본문을 따로 (앞머리가 틀의 %s에 빨려 들어가지 않게)
	var colon_at: int = text.find(" : ")
	if colon_at > 0 and not text.contains("\n"):
		var body: String = _translate(text.substr(colon_at + 3), depth + 1)
		var joined_line: String = _translate(text.substr(0, colon_at), depth + 1) + " : " + body
		if not has_hangul(joined_line):
			return joined_line
	# 3) 형식 틀 (BBCode·줄바꿈을 포함한 원문 틀 그대로)
	var templated: String = _match_template(text, depth)
	if templated != "" and not has_hangul(templated):
		return templated
	if by_line != "":
		return by_line
	var best: String = text
	var best_left: int = _hangul_count(text)
	if templated != "" and _hangul_count(templated) < best_left:
		best = templated
		best_left = _hangul_count(templated)
	# 4) BBCode 태그 사이 글자
	if text.contains("["):
		var pieces: Array = _split_bbcode(text)
		if pieces.size() > 1:
			var joined: String = ""
			for piece: Array in pieces:
				joined += piece[0] if bool(piece[1]) else _translate(piece[0], depth + 1)
			if not has_hangul(joined):
				return joined
			if _hangul_count(joined) < best_left:
				best = joined
				best_left = _hangul_count(joined)
	# 5) 앞뒤 공백·괄호·장식 기호를 떼고 다시 ("[4번 말]" -> "4번 말")
	var parts_peeled: Array = _peel(text)
	if not parts_peeled.is_empty():
		var unwrapped: String = str(parts_peeled[0]) + _translate(parts_peeled[1], depth + 1) + str(parts_peeled[2])
		if not has_hangul(unwrapped):
			return unwrapped
		if _hangul_count(unwrapped) < best_left:
			best = unwrapped
			best_left = _hangul_count(unwrapped)
	# 6) 구분자로 나눠서 (모든 조각이 번역되는 구분자를 고르고, 없으면 한글이 가장 적게 남는 것)
	for separator: String in SEPARATORS.slice(0, 1) + KEEP_LEFT_SEPARATORS + SEPARATORS.slice(1) + [" "]:
		if not text.contains(separator):
			continue
		var parts: PackedStringArray = text.split(separator)
		# "! "·". "는 앞 조각이 문장 끝 기호를 가진 채로 번역한다 ("X 선택! Y" -> "X 선택!" + "Y")
		var keep: String = separator.substr(0, 1) if KEEP_LEFT_SEPARATORS.has(separator) else ""
		for index: int in parts.size():
			if keep != "" and index < parts.size() - 1:
				parts[index] = _translate(parts[index] + keep, depth + 1)
			else:
				parts[index] = _translate(parts[index], depth + 1)
		var joined: String = (" " if keep != "" else separator).join(parts)
		var left: int = _hangul_count(joined)
		if left == 0:
			return joined
		if left < best_left and separator != " ":  # 낱말 단위로 쪼갠 결과는 다 번역될 때만 쓴다
			best = joined
			best_left = left
	# 7) 앞뒤에 다른 글이 붙은 형식 틀 ("[R3] ■ 이름 : <틀>")
	var embedded: String = _match_template(text, depth, true)
	if embedded != "" and _hangul_count(embedded) < best_left:
		best = embedded
		best_left = _hangul_count(embedded)
	# 8) 마지막 수단: 아는 한국어 조각을 글 속에서 바꾼다
	return _replace_fragments(best) if best_left > 0 else best


static func _match_ignoring_tags(text: String) -> String:
	var plain: String = _strip_tags(text)
	if not _tag_dict.has(plain):
		return ""
	var entry: Array = _tag_dict[plain]
	var english: String = entry[1]
	var input_tags: Array[String] = _tags_of(text)
	var english_tags: Array[String] = _tags_of(english)
	if input_tags.size() != english_tags.size():
		return _strip_tags(english)
	# 영어의 태그를 입력 쪽 태그로 차례대로 바꾼다
	var out: String = ""
	var index: int = 0
	for piece: Array in _split_bbcode(english):
		if bool(piece[1]):
			out += input_tags[index]
			index += 1
		else:
			out += piece[0]
	return out


static func _strip_tags(text: String) -> String:
	if not text.contains("["):
		return text
	var out: String = ""
	for piece: Array in _split_bbcode(text):
		if not bool(piece[1]):
			out += piece[0]
	return out


static func _tags_of(text: String) -> Array[String]:
	var tags: Array[String] = []
	if text.contains("["):
		for piece: Array in _split_bbcode(text):
			if bool(piece[1]):
				tags.append(piece[0])
	return tags


static func _hangul_count(text: String) -> int:
	return _hangul_regex().search_all(text).size()


## 앞뒤 장식을 뗀다: [머리, 속, 꼬리]. 기호·공백은 그냥 떼고, 괄호·따옴표는 짝이 맞게 감싼 경우만 뗀다. 뗄 게 없으면 [].
static func _peel(text: String) -> Array:
	var found: RegExMatch = _peel_regex().search(text)
	var head: String = found.get_string(1) if found != null else ""
	var inner: String = found.get_string(2) if found != null else text
	var tail: String = found.get_string(3) if found != null else ""
	for pair: String in ["[]", "()", "“”", "「」"]:
		if inner.length() >= 2 and inner.begins_with(pair[0]) and inner.ends_with(pair[1]) and _balanced(inner.substr(1, inner.length() - 2), pair[0], pair[1]):
			head += pair[0]
			tail = pair[1] + tail
			inner = inner.substr(1, inner.length() - 2)
	if inner == "" or inner == text:
		return []
	return [head, inner, tail]


static func _balanced(text: String, open: String, close: String) -> bool:
	var level: int = 0
	for ch: String in text:
		if ch == open:
			level += 1
		elif ch == close:
			level -= 1
			if level < 0:
				return false
	return level == 0


static func _peel_regex() -> RegEx:
	if _peel_pattern == null:
		_peel_pattern = RegEx.create_from_string("^([\\s!?.:·★◆•▲▼~,/-]*)(.*?)([\\s!?.:·★◆•▲▼~,/-]*)$")
	return _peel_pattern


## loose: 틀 앞뒤에 다른 글이 붙어 있어도 찾는다 (붙은 글은 따로 번역).
## 맞는 틀이 여럿이면 한글이 남지 않는 첫 틀을, 없으면 한글이 가장 적게 남는 틀을 쓴다.
static func _match_template(text: String, depth: int, loose: bool = false) -> String:
	var best: String = ""
	var best_left: int = 1 << 30
	for entry: Dictionary in _templates:
		var anchor: String = entry["anchor"]
		if anchor != "" and not text.contains(anchor):
			continue
		if loose and int(entry["weight"]) < LOOSE_MIN_LITERAL:
			continue
		var found: RegExMatch = (entry["loose" if loose else "regex"] as RegEx).search(text)
		if found == null:
			continue
		var head: String = text.substr(0, found.get_start())
		var tail: String = text.substr(found.get_end())
		if loose and head == "" and tail == "":
			continue
		var specs: Array = entry["specs"]
		var english: String = entry["en"]
		var values: Array = []
		var named: Dictionary = {}
		for index: int in specs.size():
			var spec: String = specs[index]
			var raw: String = found.get_string(index + 1)
			if spec.begins_with("{"):
				named[spec] = _translate(raw, depth + 1)
				continue
			var kind: String = spec.right(1)
			if kind == "s":
				values.append(_translate(raw, depth + 1))
			elif kind == "f":
				values.append(raw.to_float())
			else:
				values.append(raw.to_int())
		var result: String = english
		for key: String in named:
			result = result.replace(key, named[key])
		if not values.is_empty():
			result = result % values
		if head != "" or tail != "":
			result = _translate(head, depth + 1) + result + _translate(tail, depth + 1)
		var left: int = _hangul_count(result)
		if left == 0:
			return result
		if left < best_left:
			best = result
			best_left = left
	return best


## BBCode 태그가 아닌 [를 [lb]로.
static func _escape_brackets(text: String) -> String:
	var out: String = ""
	for piece: Array in _split_bbcode(text):
		out += piece[0] if bool(piece[1]) else (piece[0] as String).replace("[", "[lb]")
	return out


## [[글, 태그인가], ...]
static func _split_bbcode(text: String) -> Array:
	if _bbcode == null:
		_bbcode = RegEx.create_from_string(BBCODE_TAG_PATTERN)
	var pieces: Array = []
	var cursor: int = 0
	for found: RegExMatch in _bbcode.search_all(text):
		if found.get_start() > cursor:
			pieces.append([text.substr(cursor, found.get_start() - cursor), false])
		pieces.append([found.get_string(), true])
		cursor = found.get_end()
	if cursor < text.length():
		pieces.append([text.substr(cursor), false])
	return pieces


## 낱말 하나로 떨어져 있는(앞뒤가 한글이 아닌) 아는 조각만 바꾼다. 낱말 속 조각은 건드리지 않는다 (엉뚱한 섞임 글 방지).
static func _replace_fragments(text: String) -> String:
	var result: String = text
	for pair: Array in _fragments:
		if not has_hangul(result):
			break
		var ko: String = pair[0]
		var from: int = result.find(ko)
		while from >= 0:
			var end: int = from + ko.length()
			var before_ok: bool = from == 0 or not has_hangul(result[from - 1])
			var after_ok: bool = end >= result.length() or not has_hangul(result[end])
			if before_ok and after_ok:
				result = result.substr(0, from) + str(pair[1]) + result.substr(end)
				from = result.find(ko, from + str(pair[1]).length())
			else:
				from = result.find(ko, end)
	return result


static func _ensure_dict() -> void:
	if _dict_loaded:
		return
	_dict_loaded = true
	var pairs: Dictionary = {}
	for entry: Dictionary in DataTable.load_file(TRANSLATIONS_PATH):
		_add_pair(pairs, str(entry.get("ko", "")), str(entry.get("en", "")))
	for path: String in DATA_TABLES:
		for row: Dictionary in DataTable.load_file(path):
			for column: String in DATA_TABLES[path]:
				_add_pair(pairs, str(row.get(column, "")), str(row.get(column + "_en", "")))
	for row: Dictionary in _table().values():
		_add_pair(pairs, _cell(row, DEFAULT_LANG), _cell(row, "en"))
	# 화면이 원문을 다듬어 쓰는 경우(줄마다 나누기, "◆ "·"[방어] " 머리표 떼기)도 찾도록 줄 단위·머리표 뗀 짝을 더한다
	var head_regex := RegEx.create_from_string("^(?:[◆•※▶] |\\[[^\\]]+\\] )")
	for ko: String in pairs.keys():
		var english: String = pairs[ko]
		var variants: Array = [[ko, english]]
		var ko_lines: PackedStringArray = ko.split("\n")
		var en_lines: PackedStringArray = english.split("\n")
		if ko_lines.size() > 1 and ko_lines.size() == en_lines.size():
			for index: int in ko_lines.size():
				variants.append([ko_lines[index], en_lines[index]])
		for variant: Array in variants:
			var ko_head: RegExMatch = head_regex.search(variant[0])
			var en_head: RegExMatch = head_regex.search(variant[1])
			_add_pair(pairs, variant[0], variant[1])
			if ko_head != null and en_head != null:
				_add_pair(pairs, (variant[0] as String).substr(ko_head.get_end()), (variant[1] as String).substr(en_head.get_end()))
	var spec_regex := RegEx.create_from_string(SPEC_PATTERN)
	var templates: Array = []
	var fragments: Array = []
	var tag_dict: Dictionary = {}
	for ko: String in pairs:
		if ko.contains("["):
			var plain: String = _strip_tags(ko)
			if plain != ko and not tag_dict.has(plain):
				tag_dict[plain] = [ko, pairs[ko]]
	_tag_dict = tag_dict
	for ko: String in pairs:
		var english: String = pairs[ko]
		var specs: Array = []
		for found: RegExMatch in spec_regex.search_all(ko):
			if found.get_string() != "%%":
				specs.append(found.get_string())
		if specs.is_empty():
			# %%만 있는 원문은 화면에서 %가 하나다
			_dict[ko.replace("%%", "%")] = english.replace("%%", "%")
			if ko.length() >= 2:
				fragments.append([ko, english])
			continue
		_dict[ko] = english  # 형식 틀 자체를 t()로 바꾸는 경우 (L10n.tf)
		var template: Dictionary = _compile_template(ko, english, spec_regex)
		if not template.is_empty():
			templates.append(template)
	# 글자가 많은(구체적인) 틀부터 맞춰 본다
	templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["weight"]) > int(b["weight"]))
	fragments.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as String).length() > (b[0] as String).length())
	_templates = templates
	_fragments = fragments


static func _add_pair(pairs: Dictionary, ko: String, en: String) -> void:
	ko = ko.replace("[lb]", "[")
	en = en.replace("[lb]", "[")
	if ko.strip_edges() == "" or en.strip_edges() == "" or ko == en or pairs.has(ko):
		return
	pairs[ko] = en


static func _compile_template(ko: String, english: String, spec_regex: RegEx) -> Dictionary:
	var pattern: String = "^"
	var specs: Array = []
	var cursor: int = 0
	var literal_chars: int = 0
	var anchor: String = ""
	for found: RegExMatch in spec_regex.search_all(ko):
		var literal: String = ko.substr(cursor, found.get_start() - cursor)
		pattern += _escape(literal)
		literal_chars += literal.length()
		if literal.strip_edges().length() > anchor.length():
			anchor = literal.strip_edges()
		var spec: String = found.get_string()
		var closer: String = ko.substr(found.get_end(), 1)
		if spec == "%%":
			pattern += "%"
		elif spec.begins_with("{") or spec.ends_with("s"):
			# "[%s]"처럼 닫는 대괄호·따옴표 바로 앞의 자리는 그 기호를 넘지 않는다 (여러 항목이 이어진 글에서 한 항목만 잡게). 둥근 괄호는 "(승리 (말 4개 모두 완주))"처럼 겹치므로 제외
			pattern += "([^%s]*?)" % _escape(closer) if "]」”".contains(closer) and closer != "" else "(.*?)"
			specs.append(spec)
		elif spec.ends_with("f"):
			pattern += "(-?[0-9]+(?:\\.[0-9]+)?)"
			specs.append(spec)
		else:
			pattern += "(-?[0-9]+)"
			specs.append(spec)
		cursor = found.get_end()
	var tail: String = ko.substr(cursor)
	pattern += _escape(tail) + "$"
	literal_chars += tail.length()
	if tail.strip_edges().length() > anchor.length():
		anchor = tail.strip_edges()
	if literal_chars == 0:
		return {}
	var regex := RegEx.create_from_string(pattern)
	if not regex.is_valid():
		return {}
	# 느슨한 틀: 글자로 시작·끝나는 쪽은 앞뒤에 다른 글이 붙어도 된다 (자리표시자로 시작·끝나는 쪽은 그대로 고정)
	var body: String = pattern.substr(1, pattern.length() - 2)
	var starts_with_spec: bool = spec_regex.search(ko) != null and spec_regex.search(ko).get_start() == 0
	var ends_with_spec: bool = false
	for found: RegExMatch in spec_regex.search_all(ko):
		ends_with_spec = found.get_end() == ko.length()
	var loose := RegEx.create_from_string(("^" if starts_with_spec else "") + body + ("$" if ends_with_spec else ""))
	# 영어 틀에서 {p1} 같은 이름 자리표시자는 그대로 두고 %는 원문과 같은 순서로 채운다
	return {"regex": regex, "loose": loose, "anchor": anchor, "specs": specs, "en": english, "weight": literal_chars}


static func _escape(literal: String) -> String:
	var out: String = ""
	for ch: String in literal:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\" + ch
		elif ch == "\n":
			out += "\\n"
		else:
			out += ch
	return out


static func _hangul_regex() -> RegEx:
	if _hangul == null:
		_hangul = RegEx.create_from_string(HANGUL_PATTERN)
	return _hangul


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
