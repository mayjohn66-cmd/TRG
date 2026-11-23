# File: res://tests/menu_tour.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 메뉴(시작 화면·허브·놀이터 설정·아바타·설정·업데이트 소식·언어·온라인 로비)를 한 바퀴 돈다. 게임 보드와 도감은 열지 않는다.
#       두 가지로 쓴다:
#       1) tools/export_game_pack.py가 이 스크립트를 --verbose로 돌려, 메뉴가 실제로 읽는 리소스를 웹 본체(index.pck)에 남기고 나머지를 게임 묶음(game.pck)으로 보낸다.
#       2) 배포 CI가 게임 묶음을 뺀 본체(--main-pack index.pck)로 돌려, 메뉴만으로는 빠진 리소스가 없는지(로드 실패 0) 확인한다.
extends SceneTree

var _frames: int = 0
var _started: bool = false


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2 and not _started:
		_started = true
		_run()
	return false


func _settle(count: int = 3) -> void:
	for _i: int in count:
		await process_frame


## 무작위로 고르는 그림(로비 배경 4장 등)은 한 번씩 다 보여 준다: 한 번 돌 때 고른 것만 본체에 남으면 다른 배경이 뽑힐 때 빠진다.
func _show_every_random_choice() -> void:
	for node: Node in root.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with("lobby_background.gd"):
			for index: int in (node.get("BACKGROUNDS") as Array).size():
				node.call("select_background", index)
	await _settle(2)


func _close_popups(parent: Node) -> void:
	for name: String in ["Popup", "SettingsPopup", "UpdateNotesPopup"]:
		var popup: Node = parent.find_child(name, true, false)
		if popup != null:
			popup.queue_free()
	await _settle(2)


func _run() -> void:
	var saved_lang: String = L10n.current_lang
	# 한 바퀴 도는 동안 보드·난이도·아바타를 바꿔 저장하므로 끝나면 되돌린다 (로컬에서 돌린 뒤 다른 테스트가 바뀐 설정으로 돌지 않게)
	var saved_board: StringName = GameSession.board_id()
	var saved_level: int = GameSession.bot_difficulty()
	var saved_avatar: StringName = GameSession.avatar_id
	GameSession.nickname = ""
	var menu: StartMenu = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	menu.change_scene_enabled = false
	root.add_child(menu)
	await _settle(4)
	await _show_every_random_choice()
	menu._name_edit.text = "투어"
	menu.confirm_nickname()
	await _settle()
	menu._show_updates()
	await _settle()
	await _close_popups(menu)
	menu._show_settings()
	await _settle()
	await _close_popups(menu)
	menu.open_training()
	await _settle()
	for board: Dictionary in BoardCatalog.available():
		menu._on_board_picked(board["id"])
		await _settle(2)
	for level: int in range(1, 6):
		menu.set_difficulty(level)
		await _settle(1)
	menu._show_step(2)
	menu.open_avatar()
	await _settle()
	for id: StringName in AvatarCatalog.ids():
		menu.select_avatar(id)
		await _settle(2)
	menu._show_step(2)
	for lang: String in ["en", "ja", "ko"]:
		L10n.set_language(lang)
		await _settle(2)
	menu.queue_free()
	await _settle()
	# 온라인 로비 (네트워크 없이): 방 선택 화면 -> 방 만들기
	GameSession.nickname = "투어"
	var lobby: Lobby = (load("res://scenes/lobby.tscn") as PackedScene).instantiate()
	lobby.change_scene_enabled = false
	root.add_child(lobby)
	lobby.service.offline_for_test = true
	await _settle(4)
	await _show_every_random_choice()
	lobby.start_hosting()
	await _settle(4)
	lobby.queue_free()
	await _settle()
	L10n.set_language(saved_lang)
	GameSession.set_board(saved_board)
	GameSession.set_bot_difficulty(saved_level)
	GameSession.avatar_id = saved_avatar
	GameSession.save_settings()
	# 헤드리스는 소리를 내지 않아 위에서 소리 파일을 읽지 않는다: 메뉴가 쓰는 소리가 본체에 있는지 따로 본다
	# (효과음 전부·로비 음악·아바타 고르기 대사. 게임 묶음으로 빠지면 메뉴에서 소리가 안 난다)
	var missing: Array[String] = []
	for event: StringName in Sfx.EVENTS:
		for path: String in Sfx._files_for(event):
			if not ResourceLoader.exists(path):
				missing.append(path)
	var lobby_track: String = "%s/%s.ogg" % [Sfx.BGM_DIR, Sfx.LOBBY_TRACK]
	if not ResourceLoader.exists(lobby_track):
		missing.append(lobby_track)
	for id: StringName in AvatarCatalog.ids():
		var voice: String = AvatarCatalog.select_voice_path(id)
		if voice == "" and FileAccess.file_exists(AvatarSlot.character_path(id) + "/select_voice.ogg.import"):
			missing.append(String(id) + "/select_voice.ogg")
	for path: String in missing:
		printerr("MENU_TOUR_FAIL: 메뉴 소리가 본체에 없다: " + path)
	if not missing.is_empty():
		quit(1)
		return
	print("MENU_TOUR_OK")
	quit(0)
