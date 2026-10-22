# File: res://tests/ui_menu_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 시작 메뉴 흐름 검증 - 닉네임 설정(빈 값·길이 검사) -> [컴퓨터 대전]/[멀티플레이] 선택, 멀티플레이는 로비로 열려 있고, 닉네임이 게임 화면의 프로필 이름으로 이어지는지 확인한다
extends SceneTree

var _frames: int = 0
var _failures: Array[String] = []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_run()
	return false


func _run() -> void:
	GameSession.avatar_id = AvatarCatalog.DEFAULT_ID  # 이전 실행이 저장한 아바타가 남아 있어도 같은 조건에서 시작한다
	GameSession.save_settings()
	var menu: StartMenu = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	menu.change_scene_enabled = false
	root.add_child(menu)
	_expect(menu.step == 1 and menu._name_page.visible and not menu._mode_page.visible and not menu._back_button.visible, "처음에는 타이틀(교주의 이름) 화면")
	menu._name_edit.text = "   "
	_expect(not menu.confirm_nickname() and menu._error_label.text != "" and menu.step == 1, "공백만 있으면 통과 못 한다")
	menu._name_edit.text = "열한글자닉네임이에요요"
	_expect(menu._name_edit.text.length() <= GameSession.MAX_NICKNAME_LENGTH, "입력창은 10자까지만 받는다")
	menu._name_edit.text = "  에르핀  "
	_expect(menu.confirm_nickname() and menu.step == 2, "정상 닉네임은 모드 선택으로 넘어간다")
	_expect(GameSession.nickname == "에르핀" and menu._hello_label.text.contains("에르핀"), "앞뒤 공백을 뺀 닉네임이 저장되고 아래 띠에 보인다")
	_expect(menu._mode_page.visible and not menu._name_page.visible and menu._back_button.visible, "모드 선택 화면만 보인다")
	var titles: Array[String] = []
	for card: Button in [menu._ai_button, menu._multi_button, menu._quick_button]:
		titles.append((card.find_child("CardTitle", true, false) as Label).text)
		_expect(card.custom_minimum_size.y >= 110 and card.custom_minimum_size.x >= 500, "모드 카드는 큼직하다")
	_expect(str(titles) == str(["놀이터", "친선 줘팸터", "익명 줘팸터"]), "모드 카드 세 장: %s" % str(titles))
	# 마을 허브(원본 로비 느낌): 프로필 띠 · 팁 띠 · 둥근 규칙/설정 버튼 · 캐릭터들
	for node_name: String in ["ProfileCapsule", "TipBar", "HubRules", "HubSettings", "RenameButton", "AvatarButton", "ModeColumn"]:
		_expect(menu.find_child(node_name, true, false) != null, "허브 요소: %s" % node_name)
	_expect((menu.find_child("ProfileName", true, false) as Label).text == "에르핀", "왼쪽에 아바타 아래 내 닉네임")
	_expect(not (menu._top["bar"] as Control).visible and not (menu._bottom["bar"] as Control).visible, "허브에서는 청록 띠를 숨긴다")
	var tip_label: Label = menu.find_child("TipText", true, false)
	var first_tip: String = tip_label.text
	(menu.find_child("TipNext", true, false) as Button).pressed.emit()
	_expect(tip_label.text != first_tip and GameTips.TIPS.has(tip_label.text), "팁 띠의 [>>]로 다음 팁")
	menu.find_child("HubSettings", true, false).pressed.emit()
	_expect(menu.find_child("Popup", true, false) != null, "둥근 설정 버튼이 설정 팝업을 연다")
	menu.find_child("Popup", true, false).free()
	menu.find_child("HubRules", true, false).pressed.emit()
	_expect(menu.find_child("Popup", true, false) != null, "둥근 규칙 버튼이 규칙 팝업을 연다")
	menu.find_child("Popup", true, false).free()
	var blinking: int = 0
	for node: Node in menu.find_children("*", "Control", true, false):
		if node is HubKit.Icon and (node as HubKit.Icon).is_processing():
			blinking += 1
	_expect(blinking == 0, "아이콘은 깜빡이지 않는다 (대기 모래시계만 예외): %d개가 매 프레임 돈다" % blinking)
	_expect(menu.find_child("QuickStartAi", true, false) == null, "허브에는 [바로 시작] 버튼이 없다")
	menu.start_ai_game()
	_expect(GameSession.mode == GameSession.MODE_AI and GameSession.ai_opponents == 3 and not GameSession.net_active, "AI 시작은 AI 3명과 대결")
	_expect(menu._top["bar"] != null and menu._bottom["bar"] != null and (menu._top["right"] as Button).text == "규칙" and (menu._bottom["center"] as Button).text == "설정", "위·아래 청록 띠: 규칙 / 설정")
	menu._back_button.pressed.emit()
	_expect(menu.step == 1 and menu._name_edit.text.strip_edges() == "에르핀", "뒤로가기로 이름 화면에 돌아오면 입력창에 남아 있다")
	menu.confirm_nickname()
	# 훈련: AI 인원 선택 후 시작
	menu._ai_button.pressed.emit()
	_expect(menu.step == 3 and menu._train_page.visible and menu._train_label.text == "AI 상대 3명", "훈련 화면: 기본 AI 3명")
	_expect((menu._train_page.find_child("AiPlus", true, false) as Button).disabled, "3명이 최대라 + 버튼은 잠긴다")
	menu.change_ai_count(-1)
	menu.change_ai_count(-5)
	_expect(menu.ai_count == 1 and (menu._train_page.find_child("AiMinus", true, false) as Button).disabled, "AI는 1명까지")
	menu.change_ai_count(1)
	_expect(menu._train_label.text == "AI 상대 2명", "AI 2명으로 조정")
	menu._back_button.pressed.emit()
	_expect(menu.step == 2, "훈련 화면의 뒤로가기는 모드 선택으로")
	menu._ai_button.pressed.emit()
	menu._train_start.pressed.emit()
	_expect(GameSession.mode == GameSession.MODE_AI and GameSession.ai_opponents == 2 and not GameSession.net_active, "훈련 시작: 컴퓨터 대전, AI 2명")
	# 비밀 결투 / 랜덤 결투는 로비 씬으로 (목적만 전달)
	menu._multi_button.pressed.emit()
	_expect(GameSession.mode == GameSession.MODE_MULTIPLAYER and GameSession.lobby_intent == &"secret", "비밀 결투 -> 로비(방 코드 입력)")
	menu._quick_button.pressed.emit()
	_expect(GameSession.lobby_intent == &"quick", "랜덤 결투 -> 로비(빠른 매칭)")
	# 아바타 설정
	menu._show_step(2)
	_expect(menu.find_child("AvatarButton", true, false) != null, "모드 선택 화면에 [아바타 설정] 버튼")
	menu._avatar_button.pressed.emit()
	_expect(menu.step == 4 and menu._avatar_page.visible and menu._avatar_tiles.size() == AvatarCatalog.ids().size(), "아바타 설정 화면: 선택 칸 %d개" % menu._avatar_tiles.size())
	_expect(GameSession.avatar_id == AvatarCatalog.DEFAULT_ID and menu._avatar_name.text == AvatarCatalog.name_of(AvatarCatalog.DEFAULT_ID), "기본 아바타가 미리보기에 보인다")
	(menu._avatar_tiles[&"avatar_03"] as Button).pressed.emit()
	_expect(GameSession.avatar_id == &"avatar_03" and menu._avatar_name.text == "엘레나" and menu._avatar_preview.character_id == &"avatar_03", "아바타를 고르면 저장되고 미리보기가 바뀐다")
	_expect(menu._avatar_preview.emotion == AvatarSlot.Emotion.HAPPY, "고르면 웃음 반응")
	menu._back_button.pressed.emit()
	_expect(menu.step == 2, "아바타 화면의 뒤로가기는 모드 선택으로")
	GameSession.avatar_id = &"not_a_real_avatar"
	_expect(AvatarCatalog.sanitize(GameSession.avatar_id) == AvatarCatalog.DEFAULT_ID, "알 수 없는 아바타 id는 기본으로 보정")
	GameSession.avatar_id = &"avatar_03"
	# 규칙/설정 팝업
	menu._top["right"].pressed.emit()
	_expect(menu.find_child("Popup", true, false) != null, "규칙 팝업이 뜬다")
	var book: Rulebook = menu.find_child("Popup", true, false) as Rulebook
	_expect(book != null and book.spread == 0 and book.spread_count() == 10 and book._prev.disabled and not book._next.disabled, "규칙은 10장짜리 규칙 도감의 첫 장으로 열린다")
	book._next.pressed.emit()
	_expect(book.spread == 1 and not book._prev.disabled, "다음 쪽으로 넘어간다")
	for tab_index: int in 10:
		book.show_spread(tab_index)
		_expect(book._left_holder.get_child_count() >= 3 and book._right_holder.get_child_count() >= 1, "펼침면 %d에 내용이 있다" % tab_index)
	_expect(book._next.disabled and book._page_label.text == "10 / 10", "마지막 장에서는 다음 쪽이 잠긴다")
	var all_text: String = ""
	book.show_spread(6)
	for node: Node in book.find_children("*", "Label", true, false):
		all_text += (node as Label).text
	for node: Node in book.find_children("*", "RichTextLabel", true, false):
		all_text += (node as RichTextLabel).text
	_expect(all_text.contains("일기토 데스매치") and all_text.contains("운명의 수레바퀴"), "카드 쪽에 실제 카드 이름이 코드에서 읽혀 온다")
	book.show_spread(7)
	_expect(book.find_children("*", "Label", true, false).any(func(node: Node) -> bool: return (node as Label).text.contains("투기장의 지배자")), "법전 쪽에 실제 특수 승리 교칙 8종이 나온다")
	_expect(not book.find_children("*", "Label", true, false).any(func(node: Node) -> bool: return (node as Label).text == "?"), "제목 옆 ? 표시는 없다")
	_expect(not (book._content["entries"] as Array).any(func(data: Dictionary) -> bool: return str(data.get("augment", "")).begins_with("SUPER")), "초증강은 법전 장에서 빠졌다")
	var package_kinds: Array = [GameEnums.AugmentCategory.CARD_PACKAGE, GameEnums.AugmentCategory.UTILITY]
	_expect(not (book._content["entries"] as Array).any(func(data: Dictionary) -> bool: return data.has("augment") and package_kinds.has(AugmentRegistry.get_def(StringName(data["augment"])).category)), "카드 패키지·범용 보급은 법전 장에서 빠졌다")
	book.show_spread(8)
	var general_count: int = AugmentRegistry.all().filter(func(d: AugmentDef) -> bool: return package_kinds.has(d.category)).size()
	_expect(book._notebook_title.text == "카드 패키지와 범용 보급" and book.entry_count() == general_count and general_count > 0 and book._list_buttons[8].visible, "범용 장: 카드 패키지·범용 보급 %d종" % general_count)
	book.show_spread(9)
	_expect(book._notebook_title.text == "하이리스크 하이리턴" and book.entry_count() == SuperAugments.ALL_IDS.size() and book._list_buttons[9].visible and book._list_buttons[4].visible, "초증강 장: 하이리스크 하이리턴 설명 + 초증강 %d종 (도감 묶음)" % SuperAugments.ALL_IDS.size())
	book.show_spread(4)
	var swappable: int = AugmentRegistry.all().filter(func(d: AugmentDef) -> bool: return d.category == GameEnums.AugmentCategory.TOOL_SWAP).size()
	_expect(book.entry == -1 and book._notebook_title.text == "굴리는 도구" and book._tiles.size() == book.entry_count() and book.entry_count() == swappable, "도구 장: 처음엔 전체 설명, 오른쪽엔 증강 카드 %d장 (전체 설명 타일 없음)" % swappable)
	_expect(book._tiles[0].get_child(0) is Button and book._tiles[0].custom_minimum_size.x < MainBoard.AUGMENT_CARD_SIZE.x, "도감 타일은 증강 선택 카드를 줄인 그림")
	(book._tiles[2].get_child(0) as Button).pressed.emit()
	_expect(book.entry == 2 and book._tiles[2].get_meta("marker").visible, "증강 카드를 누르면 왼쪽에 그 도구가 크게 나온다 (%s)" % book._notebook_title.text)
	_expect(book._left_holder.get_child_count() >= 2, "항목 화면: 그림·요약 + 규칙표")
	book.free()
	menu._bottom["center"].pressed.emit()
	var popup: Node = menu.find_child("Popup", true, false)
	_expect(popup != null and popup.find_child("PacingCheck", true, false) == null and popup.find_child("FullscreenSwitch", true, false) != null and popup.find_child("BatterySwitch", true, false) != null and popup.find_child("MasterMute", true, false) != null and popup.find_child("LanguageOption", true, false) != null and popup.find_child("ViewMode", true, false) == null and popup.find_child("PaceOption", true, false) == null and popup.find_child("SfxMute", true, false) != null and popup.find_child("BgmMute", true, false) != null, "설정 팝업: 화면 스위치·전체/효과음/배경음 음소거·언어 (연출 멈춤·속도·시점은 없음)")
	popup.free()
	_expect(MobileSupport.is_portrait(Vector2i(390, 844)) and not MobileSupport.is_portrait(Vector2i(844, 390)), "세로/가로 판정")
	menu._mobile.refresh(Vector2i(390, 844))
	_expect(menu._mobile.overlay.visible, "세로 화면이면 가로 안내가 덮는다")
	menu._mobile.refresh(Vector2i(844, 390))
	_expect(not menu._mobile.overlay.visible, "가로 화면이면 안내가 사라진다")
	menu.queue_free()
	# 이미 이름을 정했다면 게임/로비에서 돌아왔을 때 모드 선택부터 보인다
	var again: StartMenu = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	again.change_scene_enabled = false
	root.add_child(again)
	_expect(again.step == 2 and again._hello_label.text.contains("에르핀"), "이름을 정한 뒤 돌아오면 모드 선택 화면")
	again.queue_free()
	# 게임 화면: 내 프로필은 닉네임, 봇은 "컴퓨터 n"
	var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	board._refresh_all()
	_expect((board._profiles[1]["name"] as Label).text == "에르핀", "내 프로필 이름은 닉네임 (%s)" % (board._profiles[1]["name"] as Label).text)
	_expect((board._profiles[2]["name"] as Label).text == "컴퓨터 2" and (board._profiles[3]["name"] as Label).text == "컴퓨터 3", "봇 이름은 컴퓨터 n")
	_expect(str(board._player_ids) == "[1, 2, 3]" and not (board._profiles[4]["panel"] as Control).visible, "훈련 AI 2명: 참가 3명, P4 자리는 비어 있다")
	_expect(board._bot.is_bot(2) and board._bot.is_bot(3) and not board._bot.is_bot(4), "봇은 P2·P3")
	_expect((board._profiles[1]["avatar"] as AvatarSlot).character_id == &"avatar_03", "내 프로필 아바타는 설정에서 고른 것")
	_expect((board._profiles[2]["avatar"] as AvatarSlot).character_id != &"avatar_03" and (board._profiles[2]["avatar"] as AvatarSlot).character_id != (board._profiles[3]["avatar"] as AvatarSlot).character_id, "컴퓨터 아바타는 내 것·서로와 다르다")
	board._mode_toggle.pressed.emit()
	_expect((board._profiles[1]["name"] as Label).text == "플레이어 1", "4P 수동 조작에서는 플레이어 n")
	if _failures.is_empty():
		print("UI_MENU_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_MENU_FAIL: " + message)
		quit(1)
