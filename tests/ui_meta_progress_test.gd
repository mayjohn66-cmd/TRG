# File: res://tests/ui_meta_progress_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 영구 기록 표시 검사 - 놀이터 난이도 왕관·전적, 허브 [법전 수집 N/8]·#태그, 도감 [달성 완료 ★] 도장·기록 코드 불러오기,
#       결과 화면 [내 우승 기록 복사하기] 글 (한국어·영어). 실행: godot --headless --path . -s res://tests/ui_meta_progress_test.gd
extends SceneTree

const SAVE_PATH: String = "user://test_meta_progress.json"

var _failures: Array[String] = []
var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	PlayerSave.storage_path = SAVE_PATH
	PlayerSave.use_browser = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	PlayerSave.reset_cache()
	L10n.install()
	L10n.set_language("ko")
	PlayerSave.set_value("player_tag", "MP23")
	PlayerSave.set_value("nickname", "기록왕")
	PlayerSave.mark_law("LAW_04")
	PlayerSave.record_buldak(4, 18)
	GameSession.reload_from_save()
	# 1) 시작 메뉴: 허브의 #태그·법전 수집, 놀이터 난이도 왕관
	var menu: StartMenu = load("res://scenes/start_menu.tscn").instantiate()
	menu.change_scene_enabled = false
	root.add_child(menu)
	for i: int in 3:
		await process_frame
	var pill: Button = menu.find_child("LawCollection", true, false)
	_expect(pill != null and pill.text == "법전 수집 1/8", "허브 [법전 수집 1/8] (%s)" % (pill.text if pill != null else "없음"))
	var tag: Label = menu.find_child("ProfileTag", true, false)
	_expect(tag != null and tag.text == "#MP23", "허브에 저장된 #태그 (%s)" % (tag.text if tag != null else "없음"))
	var picker: FireLevelPicker = menu._fire_picker
	_expect((picker._crowns[4] as MetaIcon).kind == &"crown", "Lv.4 정복: 황금 왕관")
	_expect((picker._crowns[5] as MetaIcon).kind == &"lock", "Lv.5 미정복: 자물쇠")
	picker.set_level(4, false)
	_expect(picker._record_label.text == "클리어! 최고: 18라운드", "고른 단계 전적 (%s)" % picker._record_label.text)
	_expect(picker._conquer_label.text == "· 정복 1/5", "정복 수 (%s)" % picker._conquer_label.text)
	picker.set_level(5, false)
	_expect(picker._record_label.text == "미정복", "미정복 단계 (%s)" % picker._record_label.text)
	# 2) 도감: 법전 장의 도장, 기록 코드 불러오기
	var book: Rulebook = menu._open_rulebook(Rulebook.LAW_SPREAD)
	for i: int in 3:
		await process_frame
	var stamps: Array[Node] = book.find_children("ClearedStamp", "", true, false)
	_expect(stamps.size() == 1, "달성한 법전 1개에만 [달성 완료 ★] 도장 (%d)" % stamps.size())
	var badge: Button = book.find_child("LawCollection", true, false)
	_expect(badge != null and badge.text == "법전 1/8", "도감 [법전 1/8]")
	_expect(book.find_child("CopyShareLink", true, false) != null and book.find_child("ShortCodeField", true, false) != null, "큼직한 [내 기록 전용 링크 복사] + 짧은 코드 입력 칸")
	book._copy_share_link()
	var link: String = PlayerSave.share_url()
	_expect(link == PlayerSave.SHARE_BASE_URL + "?s=MP23-0808&n=%s" % "기록왕".uri_encode(), "이어하기 링크: ?s=짧은코드&n=닉네임 (%s)" % link)
	_expect((book.find_child("SaveNotice", true, false) as Label).text.contains("MP23-0808"), "복사 안내에 짧은 코드가 보인다")
	_expect(not book.apply_save_code("ABCD-ZZ"), "잘못된 코드는 거절")
	_expect(book.apply_save_code("모바일교주#ZX97-8100"), "짧은 코드(닉네임#태그-비트)를 불러온다")
	for i: int in 2:
		await process_frame
	_expect(GameSession.player_tag() == "ZX97" and GameSession.nickname == "모바일교주", "불러온 #태그·닉네임 (%s %s)" % [GameSession.player_tag(), GameSession.nickname])
	_expect(badge.text == "법전 3/8", "합친 법전 3/8 (%s)" % badge.text)
	_expect(book.find_children("ClearedStamp", "", true, false).size() == 3, "도장 3개로 다시 그린다")
	_expect(tag.text == "#ZX97" and pill.text == "법전 수집 3/8", "허브도 바로 바뀐다 (%s, %s)" % [tag.text, pill.text])
	book.close()
	menu.queue_free()
	await process_frame
	# 3) 결과 화면 기록 복사 글
	var board: MainBoard = load("res://scenes/main_board.tscn").instantiate()
	root.add_child(board)
	for i: int in 3:
		await process_frame
	board.ai_mode = true
	var me: int = board.local_player_id
	board.state.rankings.assign([me])
	board.state.rank_reasons[me] = &"LAW_04"
	board.state.round_number = 18
	L10n.set_language("ko")  # 앞선 검사가 저장한 언어 설정(예: ja)과 상관없이 한국어로 본다
	var text: String = board.brag_text(me)
	_expect(text.contains("1위 졸업") and text.contains("18라운드") and text.contains("특수 승리") and text.contains("\n"), "기록 글: 순위·라운드·졸업 방식·두 줄 (%s)" % text)
	_expect(text.contains("Lv."), "놀이터 난이도가 들어간다")
	L10n.set_language("en")
	var english: String = board.brag_text(me)
	_expect(not L10n.has_hangul(english), "영어 기록 글에 한글이 남지 않는다 (%s)" % english)
	L10n.set_language("ko")
	board.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _failures.is_empty():
		print("UI_META_PROGRESS_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_META_PROGRESS_FAIL: " + message)
		quit(1)
