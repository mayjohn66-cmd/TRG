## 선택 언어에 맞춘 타이틀 그림. 이름 입력 화면과 작은 허브 로고가 함께 갱신된다.
extends TextureRect

const PATHS: Dictionary = {
	"ko": "res://web/title-logo.png",
	"en": "res://web/title-logo-en.png",
	"ja": "res://web/title-logo-ja.png",
}
## 영어·일본어 제목은 translations.csv에 둔다 (일본어 한자가 게임 글꼴 검사에 걸리지 않게 코드에는 한국어 원문만).
const TITLE: String = "초증강 엘리아스 마블"


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	L10n.on_changed(_refresh)
	_refresh()


func _refresh() -> void:
	var lang: String = L10n.current_lang if PATHS.has(L10n.current_lang) else "ko"
	texture = TextureCache.fetch(PATHS[lang])
	tooltip_text = L10n.translate_text(TITLE, lang) if lang != "ko" else TITLE
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.trgSetTitleLanguage && window.trgSetTitleLanguage(%s)" % JSON.stringify(lang), true)
