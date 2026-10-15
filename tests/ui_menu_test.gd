# File: res://tests/ui_menu_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 시작 메뉴 흐름 검증 - 닉네임 설정(빈 값·길이 검사) -> [컴퓨터 대전]/[멀티플레이] 선택, 멀티플레이는 준비 중으로 막혀 있고, 닉네임이 게임 화면의 프로필 이름으로 이어지는지 확인한다
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
	var menu: StartMenu = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	menu.change_scene_enabled = false
	root.add_child(menu)
	_expect(menu.step == 1 and menu._name_page.visible and not menu._mode_page.visible, "처음에는 닉네임 설정 화면")
	menu._name_edit.text = "   "
	_expect(not menu.confirm_nickname() and menu._error_label.text != "" and menu.step == 1, "공백만 있으면 통과 못 한다")
	menu._name_edit.text = "열한글자닉네임이에요요"
	_expect(menu._name_edit.text.length() <= GameSession.MAX_NICKNAME_LENGTH, "입력창은 10자까지만 받는다")
	menu._name_edit.text = "  에르핀  "
	_expect(menu.confirm_nickname() and menu.step == 2, "정상 닉네임은 모드 선택으로 넘어간다")
	_expect(GameSession.nickname == "에르핀" and menu._hello_label.text.contains("에르핀"), "앞뒤 공백을 뺀 닉네임이 저장된다")
	_expect(menu._mode_page.visible and not menu._name_page.visible, "모드 선택 화면만 보인다")
	_expect(not menu._ai_button.disabled and menu._multi_button.disabled and menu._multi_button.text.contains("준비 중"), "컴퓨터 대전은 열려 있고 멀티플레이는 준비 중")
	menu._back_button.pressed.emit()
	_expect(menu.step == 1 and menu._name_edit.text.strip_edges() == "에르핀", "닉네임 변경으로 돌아가면 입력창에 남아 있다")
	menu.confirm_nickname()
	menu._ai_button.pressed.emit()
	_expect(GameSession.mode == GameSession.MODE_AI, "컴퓨터 대전 모드로 세션이 정해진다")
	menu.queue_free()
	# 게임 화면: 내 프로필은 닉네임, 봇은 "컴퓨터 n"
	var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	board._refresh_all()
	_expect((board._profiles[1]["name"] as Label).text == "에르핀", "내 프로필 이름은 닉네임 (%s)" % (board._profiles[1]["name"] as Label).text)
	_expect((board._profiles[2]["name"] as Label).text == "컴퓨터 2" and (board._profiles[4]["name"] as Label).text == "컴퓨터 4", "봇 이름은 컴퓨터 n")
	board._mode_toggle.pressed.emit()
	_expect((board._profiles[1]["name"] as Label).text == "플레이어 1", "4P 수동 조작에서는 플레이어 n")
	if _failures.is_empty():
		print("UI_MENU_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_MENU_FAIL: " + message)
		quit(1)
