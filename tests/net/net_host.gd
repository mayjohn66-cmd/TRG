# File: res://tests/net/net_host.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: Listen Server 통합 테스트(호스트 프로세스). 실제 WebSocket 연결로 클라이언트를 받아 권위 판정·상태 브로드캐스트·사칭 차단을 검증한다
extends SceneTree

const PORT: int = 24791

var _net: NetworkService
var _manager: TurnManager
var _frames: int = 0
var _started: bool = false
var _done: bool = false
var _acted: bool = false
var _rejections: Array = []


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_net = NetworkService.new()
		_net.name = "Net"
		root.add_child(_net)
		_manager = TurnManager.new()
		_manager.name = "TurnManager"
		root.add_child(_manager)
		_manager.bind_network(_net)
		_manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: _rejections.append([player_id, action, reason]))
		var error: Error = _net.host_game(PORT)
		if error != OK:
			_fail("host_game 실패: %s" % error_string(error))
		print("HOST: 대기 중")
		return false
	if _frames > 60 * 20:
		_fail("시간 초과 (phase=%s, roster=%s)" % [_manager.current_state, _net.peer_to_player])
		return true
	if not _started and _net.connected_player_count() == 2:
		_started = true
		print("HOST: 클라이언트 접속 확인 roster=", _net.peer_to_player)
		_manager.start_game([1, 2] as Array[int], 99)
		_manager.state.tools[1] = ScriptedTool.new([1])
		_manager.state.tools[2] = ScriptedTool.new([2])
	# 클라이언트가 자기 턴이 아닐 때 보낸 roll 요청이 거부된 뒤에야 1번 플레이어가 진행한다.
	if _started and not _acted and _rejections.any(func(r: Array) -> bool: return r[0] == 2 and r[1] == &"roll"):
		_acted = true
		_manager.act(&"proceed", {})
		_manager.act(&"roll", {})
		_manager.act(&"select_pawn", {"pawn_id": 11})
		# 호스트가 2번 말을 조작하려는 사칭: 방장은 1번 좌석이므로 거부되어야 한다.
		_manager.act(&"select_pawn", {"pawn_id": 21, "player_id": 2})
	if _started and not _done and _manager.state != null and _manager.state.get_pawn(21).current_tile_idx == 2:
		_done = true
		var ok: bool = true
		ok = ok and _manager.state.get_pawn(11).current_tile_idx == 1
		ok = ok and _manager.state.current_player == 1 and _manager.state.round_number == 2
		var forged: Array = _rejections.filter(func(r: Array) -> bool: return r[0] == 1 and r[1] == &"select_pawn")
		ok = ok and forged.size() >= 1
		ok = ok and _rejections.any(func(r: Array) -> bool: return r[0] == 2 and r[1] == &"roll" and r[2] == &"wrong_phase")
		print("HOST: 말 위치 11=%d 21=%d round=%d rejections=%s" % [_manager.state.get_pawn(11).current_tile_idx, _manager.state.get_pawn(21).current_tile_idx, _manager.state.round_number, str(_rejections)])
		if ok:
			print("HOST_OK")
			# 클라이언트가 마지막 브로드캐스트를 받을 시간을 준다.
			create_timer(1.0).timeout.connect(func() -> void: quit(0))
		else:
			_fail("검증 실패")
	return false


func _fail(message: String) -> void:
	printerr("HOST_FAIL: " + message)
	quit(1)
