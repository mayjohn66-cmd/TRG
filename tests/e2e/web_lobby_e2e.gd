# File: res://tests/e2e/web_lobby_e2e.gd
# Class: (씬 스크립트, class_name 없음)
# Role: 브라우저 여러 개(방장/참가자)로 방 코드 자동 시그널링 + 실제 WebRTC 로비 연결을 검증하는 웹 전용 테스트 씬. 릴레이 주소는 ?relay=, 역할은 ?role= 로 받고 상태는 window.__ 변수로 알린다 (tests/e2e/run_web_lobby_e2e.mjs가 조종)
extends Control

var service: LobbyService = null
var _role: String = ""
var _callbacks: Array = []


## 게임 화면으로 넘어간 뒤에도 남아서 판 상태를 window.__game으로 알리는 관찰자 (이 씬은 게임 화면으로 바뀌면 사라진다).
class GameReporter extends Node:
	var window: JavaScriptObject = null
	var _tuned: bool = false
	var _desyncs: int = 0
	var _hooked: bool = false

	func _process(_delta: float) -> void:
		var board: MainBoard = get_tree().current_scene as MainBoard
		if board == null or board.manager == null or board.net == null:
			return
		if not _tuned:
			_tuned = true
			board.instant_roll_for_test = true
			board.pacing_enabled = false
			board.manager.step_delay_sec = 0.0
		if not _hooked:
			_hooked = true
			board.net.desynced.connect(func(_detail: String) -> void: _desyncs += 1)
		if board.state == null:
			return
		window.__game = JSON.stringify({"over": board.manager.is_game_over, "winner": board.state.winner, "hash": board.manager.state_hash(), "applied": board.net.applied_count, "round": board.state.round_number, "desyncs": _desyncs, "players": board.manager.player_order, "seat": board.local_player_id})


func _ready() -> void:
	name = "Lobby"
	service = LobbyService.new()
	service.name = "LobbyService"
	add_child(service)
	var relay: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('relay')"))
	if relay.begins_with("http"):
		(service.broker as NtfyBroker).server = relay
	var reporter := GameReporter.new()
	reporter.window = JavaScriptBridge.get_interface("window")
	get_tree().root.add_child.call_deferred(reporter)
	GameSession.net_autoplay = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('autoplay')")) == "1"
	service.game_starting.connect(func(config: Dictionary) -> void:
		GameSession.set_net(service.is_host, service.my_seat(), config)
		get_tree().change_scene_to_file("res://scenes/main_board.tscn"))
	service.poll_seconds = 0.5
	service.claim_check_seconds = 0.6
	_role = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('role')"))
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	service.roster_changed.connect(_publish_roster)
	service.link_failed.connect(func(seat: int, message: String) -> void: window.__error = "%d:%s" % [seat, message])
	service.join_failed.connect(func(message: String) -> void: window.__joinFailed = message)
	service.join_progress.connect(func(message: String) -> void: window.__progress = message)
	if _role == "quick":
		var quick := QuickMatch.new()
		quick.name = "QuickMatch"
		quick.service = service
		add_child(quick)
		quick.state_changed.connect(func(state: int) -> void: window.__quickState = state)
		quick.start_requested.connect(func() -> void: window.__started = true)
		service.joined.connect(func() -> void: window.__joined = true)
		window.__ready = true
		_expose(window, "__quickStart", func(args: Array) -> void:
			GameSession.nickname = str(args[0])
			quick.start())
	elif _role == "host":
		service.room_ready.connect(func(code: String) -> void: window.__roomCode = code)
		var ok: bool = service.host_room("방장")
		window.__ready = ok
		_expose(window, "__fillBot", func(args: Array) -> void: service.set_bot(int(args[0]), true))
		_expose(window, "__beginGame", func(_args: Array) -> void: service.begin_online_game())
	else:
		service.joined.connect(func() -> void: window.__joined = true)
		service.left_room.connect(func(reason: String) -> void: window.__left = reason)
		window.__ready = true
		_expose(window, "__joinRoom", func(args: Array) -> void: service.join_by_room_code(str(args[0]), str(args[1])))


func _expose(window: JavaScriptObject, key: String, handler: Callable) -> void:
	var callback: JavaScriptObject = JavaScriptBridge.create_callback(handler)
	_callbacks.append(callback)  # 참조를 붙들어 두지 않으면 콜백이 사라진다
	window[key] = callback


func _publish_roster() -> void:
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.__roster = JSON.stringify(service.model.to_array())
	window.__mySeat = service.my_seat()
