# File: res://tests/e2e/web_lobby_e2e.gd
# Class: (씬 스크립트, class_name 없음)
# Role: 브라우저 여러 개(방장/참가자)로 방 코드 자동 시그널링 + 실제 WebRTC 로비 연결을 검증하는 웹 전용 테스트 씬. 릴레이 주소는 ?relay=, 역할은 ?role= 로 받고 상태는 window.__ 변수로 알린다 (tests/e2e/run_web_lobby_e2e.mjs가 조종)
extends Control

var service: LobbyService = null
var _role: String = ""
var _callbacks: Array = []


func _ready() -> void:
	name = "Lobby"
	service = LobbyService.new()
	service.name = "LobbyService"
	add_child(service)
	var relay: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('relay')"))
	if relay.begins_with("http"):
		(service.broker as NtfyBroker).server = relay
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
