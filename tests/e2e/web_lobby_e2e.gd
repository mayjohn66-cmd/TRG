# File: res://tests/e2e/web_lobby_e2e.gd
# Class: (씬 스크립트, class_name 없음)
# Role: 브라우저 두 개(방장/참가자)로 실제 WebRTC 로비 연결을 검증하는 웹 전용 테스트 씬. 화면 대신 window.__ 변수와 콜백으로 코드를 주고받는다 (tests/e2e/run_web_lobby_e2e.mjs가 조종)
extends Control

var service: LobbyService = null
var _role: String = ""
var _callbacks: Array = []


func _ready() -> void:
	name = "Lobby"
	service = LobbyService.new()
	service.name = "LobbyService"
	add_child(service)
	_role = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('role')"))
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	service.roster_changed.connect(_publish_roster)
	service.link_failed.connect(func(seat: int, message: String) -> void: window.__error = "%d:%s" % [seat, message])
	if _role == "host":
		service.invite_ready.connect(func(_seat: int, code: String) -> void: window.__invite = code)
		var ok: bool = service.host_room("방장")
		window.__ready = ok
		_expose(window, "__makeInvite", func(args: Array) -> void: service.create_invite(int(args[0])))
		_expose(window, "__submitAnswer", func(args: Array) -> void: service.submit_answer(int(args[0]), str(args[1])))
	else:
		service.answer_ready.connect(func(code: String) -> void: window.__answer = code)
		service.joined.connect(func() -> void: window.__joined = true)
		service.left_room.connect(func(reason: String) -> void: window.__left = reason)
		window.__ready = true
		_expose(window, "__join", func(args: Array) -> void: service.join_room("친구", str(args[0])))


func _expose(window: JavaScriptObject, key: String, handler: Callable) -> void:
	var callback: JavaScriptObject = JavaScriptBridge.create_callback(handler)
	_callbacks.append(callback)  # 참조를 붙들어 두지 않으면 콜백이 사라진다
	window[key] = callback


func _publish_roster() -> void:
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.__roster = JSON.stringify(service.model.to_array())
	window.__mySeat = service.my_seat()
