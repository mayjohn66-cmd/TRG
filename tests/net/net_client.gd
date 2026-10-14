# File: res://tests/net/net_client.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: Listen Server 통합 테스트(클라이언트 프로세스). 호스트 상태를 미러링하고 자기 턴에 @rpc로 행동을 요청한다
extends SceneTree

const URL: String = "ws://127.0.0.1:24791"

var _net: NetworkService
var _manager: TurnManager
var _frames: int = 0
var _sent: bool = false
var _illegal_sent: bool = false
var _roll_events: Array = []


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
		_manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
			if kind == &"roll_resolved":
				_roll_events.append(data))
		var error: Error = _net.join_game(URL)
		if error != OK:
			_fail("join_game 실패: %s" % error_string(error))
		return false
	if _frames > 60 * 20:
		_fail("시간 초과")
		return true
	var state: GameState = _manager.state
	if state == null:
		return false
	# 상대 턴에 행동을 보내 본다 (호스트가 거부해야 한다).
	if not _illegal_sent and _manager.phase == GameEnums.Phase.TURN_BEGIN and state.current_player == 1:
		_illegal_sent = true
		_manager.act(&"roll", {})
	# 내 턴이 오면 진행한다.
	if not _sent and state.current_player == 2 and _manager.phase == GameEnums.Phase.TURN_BEGIN and state.get_pawn(11).current_tile_idx == 1:
		_sent = true
		print("CLIENT: 내 턴, 미러 상태 11번 말=", state.get_pawn(11).current_tile_idx)
		_manager.act(&"proceed", {})
		_manager.act(&"roll", {})
		_manager.act(&"select_pawn", {"pawn_id": 21})
	if _sent and state.get_pawn(21).current_tile_idx == 2 and state.round_number == 2:
		var mine: Array = _roll_events.filter(func(e: Dictionary) -> bool: return e["player_id"] == 2)
		if mine.size() == 1 and mine[0]["result"]["steps"] == 2:
			print("CLIENT_OK")
			quit(0)
		else:
			_fail("roll 이벤트 불일치: %s" % str(_roll_events))
	return false


func _fail(message: String) -> void:
	printerr("CLIENT_FAIL: " + message)
	quit(1)
