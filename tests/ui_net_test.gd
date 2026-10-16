# File: res://tests/ui_net_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 온라인 대전 화면 검증(헤드리스, 가짜 전송). 메인 보드 두 개(방장 P1 / 참가자 P2)를 한 프로세스에 띄워 NetGame으로 연결하고 자동 플레이로 한 판을 끝까지 돌려 두 화면이 같은 판을 보는지, 2인 대전 화면(없는 자리 숨김·내 자리 우하단)이 맞는지 확인한다. 인자 SEATS=2|3 로 인원을 바꾼다
extends SceneTree

const MAX_FRAMES: int = 60000

var _boards: Array[MainBoard] = []
var _frames: int = 0
var _failures: Array[String] = []
var _desyncs: Array[String] = []
var _seats: Array[int] = [1, 2]
var _bots: Array[int] = []
var _checked: bool = false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var count: int = int(OS.get_environment("SEATS")) if OS.get_environment("SEATS") != "" else 2
		_seats = []
		for seat: int in range(1, count + 1):
			_seats.append(seat)
		if OS.get_environment("BOTS") != "":
			for seat: String in OS.get_environment("BOTS").split(","):
				_bots.append(int(seat))
		_build()
		return false
	if _frames == 3 and not _checked:
		_checked = true
		_check_screens()
	if _boards[0].state != null and _boards[0].manager.is_game_over:
		for _i: int in range(3):
			pass
		if _frames % 5 == 0:
			return _finish()
	if _frames > MAX_FRAMES:
		_failures.append("시간 초과: 판이 끝나지 않음 (라운드 %d)" % (_boards[0].state.round_number if _boards[0].state != null else -1))
		return _finish()
	return false


func _build() -> void:
	GameSession.net_autoplay = true
	var human_seats: Array[int] = []
	for seat: int in _seats:
		if not _bots.has(seat):
			human_seats.append(seat)
	var names: Dictionary = {1: "방장", 2: "친구", 3: "셋째", 4: "넷째"}
	for seat: int in human_seats:
		GameSession.set_net(seat == human_seats[0], seat, {"players": _seats, "bots": _bots, "names": names, "seed": 4321})
		var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
		root.add_child(board)
		board.manager.step_delay_sec = 0.0
		board.instant_roll_for_test = true
		board.pacing_enabled = false
		_boards.append(board)
	var peers: Dictionary = {}
	for board: MainBoard in _boards:
		peers[board.local_player_id] = board.net
	for board: MainBoard in _boards:
		board.net.test_peers = peers
		board.net.desynced.connect(func(detail: String) -> void: _desyncs.append(detail))


func _check_screens() -> void:
	for board: MainBoard in _boards:
		_expect(board.state != null and board.state.pawns.size() == _seats.size() * 4, "말 개수 = 인원 x 4 (%d)" % (board.state.pawns.size() if board.state != null else -1))
		_expect(board._pawn_views.size() == _seats.size() * 4, "말 그림도 인원 x 4")
		for seat: int in MainBoard.PLAYER_IDS:
			var panel: Control = board._profiles[seat]["panel"]
			_expect(panel.visible == _seats.has(seat), "자리 %d 프로필 표시 여부 (보임=%s)" % [seat, str(panel.visible)])
		_expect(board.corner_of_player(board.local_player_id) == 0, "내 자리는 우하단")
		_expect(not board._mode_toggle.visible and not board._new_game_button.visible and not board._debug_toggle.visible, "온라인에서는 새 게임/모드/치트 버튼이 없다")
		_expect(board.manager.lockstep and board.manager.external_timeouts, "락스텝 + 외부 타임아웃")
	_expect(_boards[0].manager.player_order == _seats, "플레이 순서는 참여 좌석만")


func _finish() -> bool:
	var first: MainBoard = _boards[0]
	_expect(first.manager.is_game_over, "판이 끝났다")
	for board: MainBoard in _boards:
		_expect(board.manager.is_game_over and board.state.winner == first.state.winner, "모든 화면의 승자가 같다 (%d vs %d)" % [board.state.winner, first.state.winner])
		_expect(board.manager.state_hash() == first.manager.state_hash(), "모든 화면의 최종 상태 지문이 같다")
		_expect(board._result_overlay != null, "결과 창이 떴다")
	_expect(_desyncs.is_empty(), "동기화 오류 없음: %s" % str(_desyncs))
	_expect(first.net.applied_count > 100, "충분한 행동이 오갔다 (%d)" % first.net.applied_count)
	if _failures.is_empty():
		print("UI_NET_OK seats=%s round=%d winner=%d actions=%d" % [str(_seats), first.state.round_number, first.state.winner, first.net.applied_count])
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_NET_FAIL: " + message)
		quit(1)
	return true
