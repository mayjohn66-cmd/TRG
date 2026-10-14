# File: res://tests/ui_screenshot.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 가상 디스플레이(xvfb)에서 프로토타입 화면을 몇 턴 진행시킨 뒤 PNG로 저장한다. 사람 눈으로 레이아웃을 확인하기 위한 도구
extends SceneTree

var _board: MainBoard = null
var _frames: int = 0
var _out_path: String = "/tmp/trg_screenshot_%s.png" % (OS.get_environment("SHOT") if OS.get_environment("SHOT") != "" else "default")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		return false
	if _frames == 3:
		for law_id: String in ["LAW_04", "LAW_02", "LAW_08", "LAW_06", "LAW_03"]:
			_board._on_add_law_pressed(law_id)
		_board.state.give_card(1, &"ACT_06")
		_board.state.give_card(2, &"ACT_05")
		_board.state.give_card(2, &"TRP_01")
		_board.state.give_card(3, &"ACT_04")
		_board.state.give_card(4, &"ACT_01")
		_board.state.place_attachment(9, TrapMirrorForce.new(2))
		_board.state.spawn_npc(10, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
		# 몇 개 말을 보드 위로 올려 둔다.
		var spots: Dictionary = {11: 4, 12: 5, 21: 12, 22: 20, 31: 22, 41: 27, 42: 27, 13: 4}
		for pawn_id: int in spots:
			var pawn: PlayerPawn = _board.state.get_pawn(pawn_id)
			pawn.place_at(spots[pawn_id])
			pawn.has_left_start = true
		_board.state.finish_stack(_board.state.get_pawn(14))
		_board.manager._begin_turn()
		_board._refresh_all()
		if OS.get_environment("SHOT") == "select":
			_board.state.tools[1] = ScriptedTool.new([4])
			_board._on_roll_pressed()
			_board._on_skip_pressed()
		elif OS.get_environment("SHOT") == "gameover":
			for pawn: PlayerPawn in _board.state.pawns_of(2):
				_board.state.finish_stack(pawn)
			_board.manager._check_victory(null)
		else:
			_board._on_roll_pressed()
		return false
	if _frames == 8:
		if OS.get_environment("SHOT") == "select":
			_board._preview_pawn(11)
		return false
	if _frames == 14:
		var image: Image = root.get_texture().get_image()
		image.save_png(_out_path)
		print("SCREENSHOT ", _out_path, " ", image.get_size())
		quit(0)
	return false
