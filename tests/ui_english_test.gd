# File: res://tests/ui_english_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 번역 화면 검사 (로비·메뉴). 시작 화면의 모든 단계(이름·모드·놀이터·아바타), 규칙 도감 전 장·전 항목, 설정, 피드백 창, 친선 로비를 영어(UI_LANG=ja면 일본어)로 띄워
#       화면에 그려지는 글자(자동 번역을 거친 글자)에 한글이 남았는지 본다. 상단 [🌐 언어 ▾] 버튼이 양쪽 띠에 있고 한국어 / ENGLISH / 日本語 목록에서 고르면 바로 바뀌는지도 확인한다.
#       게임 판 안(증강 드래프트·굴림·결과창)은 SMOKE_LANG=en|ja ui_smoke.gd가 한 판을 돌며 같은 검사를 한다.
extends SceneTree

var _failures: Array[String] = []
var _leaks: Dictionary = {}
var _lang: String = "en"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("UI_LANG") == "ja":
		_lang = "ja"
	L10n.install()
	L10n.set_language(_lang)
	var menu: Control = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _frames(3)
	L10n.set_language(_lang)  # 시작 화면이 저장된 설정을 읽어도 검사 언어로 본다
	await _frames(2)
	_check(menu.find_child("LanguageToggle", true, false) != null, "시작 화면 위 띠에 언어 버튼")
	for step: int in [1, 2, 3, 4]:
		menu.call("_show_step", step)
		await _frames(2)
		_scan("시작 화면 %d단계" % step, root)
	# 규칙 도감: 모든 장과 장마다 모든 항목
	var book: Rulebook = Rulebook.open(menu)
	await _frames(2)
	for spread: int in book.spread_count():
		book.show_spread(spread)
		await _frames(1)
		_scan("규칙 도감 %d장" % spread, book)
		for entry: int in book.entry_count():
			book.show_entry(entry)
			await _frames(1)
			_scan("규칙 도감 %d장 %d번" % [spread, entry], book)
	book.close()
	await _frames(1)
	LobbyTheme.show_settings(menu)
	await _frames(2)
	_scan("설정", root)
	# 언어 버튼: 누르면 한국어 / ENGLISH / 日本語 목록이 열리고, 고르면 바로 그 언어
	var toggle: LanguageToggle = menu.find_child("LanguageToggle", true, false)
	if toggle != null:
		var rules: Button = menu.find_child("RulesButton", true, false)
		var popup: PopupMenu = toggle.find_child("LanguageMenu", true, false)
		toggle.pressed.emit()
		await _frames(1)
		_check(popup != null and popup.visible, "언어 버튼을 누르면 목록이 열린다")
		if popup != null:
			var names: Array[String] = []
			for index: int in popup.item_count:
				names.append(popup.get_item_text(index))
			_check(names == ["한국어", "ENGLISH", "日本語"], "목록: %s" % str(names))
			_check(popup.is_item_checked(L10n.LANGUAGES.find(_lang)), "지금 언어에 체크")
			var expected: Dictionary = {"ko": "규칙", "en": "Rules", "ja": "ルール"}
			for lang: String in ["ko", "ja", "en", _lang]:
				popup.id_pressed.emit(L10n.LANGUAGES.find(lang))
				await _frames(1)
				_check(L10n.current_lang == lang and rules.atr(rules.text) == expected[lang], "%s 고르면 바로 바뀐다 (%s)" % [lang, rules.atr(rules.text)])
				_check(toggle.text == L10n.language_name(lang), "버튼 글자도 %s" % toggle.text)
			popup.hide()
	menu.queue_free()
	await _frames(2)
	var feedback := FeedbackModal.new()
	root.add_child(feedback)
	await _frames(2)
	_scan("피드백 창", feedback)
	feedback.queue_free()
	var lobby: Control = (load("res://scenes/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	await _frames(3)
	_check(lobby.find_child("LanguageToggle", true, false) != null, "친선 로비 위 띠에 언어 버튼")
	_scan("친선 로비", lobby)
	lobby.queue_free()
	await _frames(2)
	var keys: Array = _leaks.keys()
	keys.sort()
	for key: Variant in keys:
		print("  HANGUL ", key)
	_check(keys.is_empty(), "%s 화면(로비·메뉴)에 한글이 남지 않는다 (%d곳)" % [_lang, keys.size()])
	L10n.set_language("ko")
	if _failures.is_empty():
		print("UI_ENGLISH_OK")
		quit(0)
	else:
		for failure: String in _failures:
			print("UI_ENGLISH_FAIL: " + failure)
		quit(1)


func _scan(where: String, node: Node) -> void:
	var found: Dictionary = HangulScan.scan(node)
	for key: Variant in found:
		_leaks["[%s] %s" % [where, key]] = true


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame
