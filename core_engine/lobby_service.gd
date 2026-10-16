# File: res://core_engine/lobby_service.gd
# Class: class_name LobbyService
# Role: 멀티플레이 방의 네트워크 계층. WebRTCMultiplayerPeer로 방장(피어 1) - 참가자(피어 = 좌석 번호 2~4) 메시 없는 스타 연결을 만들고, 초대/응답 코드 교환(RtcLink)과 좌석 명단 동기화(LobbyModel)를 맡는다. 화면을 모른다
class_name LobbyService
extends Node

## 방장: 좌석 seat의 초대 코드가 준비되었다.
signal invite_ready(seat: int, code: String)
## 방장: 좌석 seat의 연결 시도가 실패했다 (코드 오류 등). 참가자 쪽에서는 seat = 0.
signal link_failed(seat: int, message: String)
## 참가자: 응답 코드가 준비되었다 (방장에게 보내 줄 코드).
signal answer_ready(code: String)
## 참가자: 방장과 연결되어 명단을 받기 시작했다.
signal joined()
## 참가자: 방에서 나가게 되었다 (연결 끊김·내보내짐).
signal left_room(reason: String)
## 좌석 명단이 바뀌었다 (방장·참가자 모두).
signal roster_changed()

const HOST_PEER_ID: int = 1

var model: LobbyModel = LobbyModel.new()
var is_host: bool = false
var nickname: String = ""

## true면 실제 WebRTC 피어 없이 방장 상태만 만든다 (헤드리스 화면 테스트용).
var offline_for_test: bool = false

var _mp: WebRTCMultiplayerPeer = null
var _links: Dictionary = {}  # 좌석 -> RtcLink
var _in_room: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	model.changed.connect(func() -> void: roster_changed.emit())


func in_room() -> bool:
	return _in_room


## 내 좌석 번호 (방장 1, 참가자는 연결할 때 받은 피어 ID).
func my_seat() -> int:
	if not _in_room:
		return 0
	return HOST_PEER_ID if is_host else multiplayer.get_unique_id()


# ---------------------------------------------------------------------------
# 방장
# ---------------------------------------------------------------------------

func host_room(host_nickname: String) -> bool:
	leave()
	if not offline_for_test:
		_mp = WebRTCMultiplayerPeer.new()
		var error: int = _mp.create_server()
		if error != OK:
			link_failed.emit(0, "방을 만들지 못했습니다 (오류 %d)." % error)
			_mp = null
			return false
		multiplayer.multiplayer_peer = _mp
	is_host = true
	_in_room = true
	nickname = host_nickname
	model.setup_host(host_nickname)
	return true


## 열린 좌석에 초대 코드를 만든다. 코드는 invite_ready로 온다.
func create_invite(seat: int) -> bool:
	if not is_host or not model.invite(seat):
		return false
	var link := RtcLink.new()
	if not link.setup():
		model.cancel_invite(seat)
		return false
	var error: int = _mp.add_peer(link.connection, seat)
	if error != OK:
		model.cancel_invite(seat)
		link_failed.emit(seat, "연결을 준비하지 못했습니다 (오류 %d)." % error)
		return false
	link.code_ready.connect(func(code: String) -> void: invite_ready.emit(seat, code))
	link.failed.connect(func(message: String) -> void: link_failed.emit(seat, message))
	_links[seat] = link
	link.start_offer(seat)
	return true


## 참가자가 보내 준 응답 코드를 적용한다. 연결이 실제로 성립하면 좌석이 사람으로 바뀐다.
func submit_answer(seat: int, code: String) -> bool:
	if not is_host or not _links.has(seat):
		return false
	return (_links[seat] as RtcLink).accept_answer(code)


func cancel_invite(seat: int) -> void:
	if not is_host:
		return
	_drop_link(seat)
	model.cancel_invite(seat)
	_broadcast_roster()


## 참가자를 내보낸다.
func kick(seat: int) -> void:
	if not is_host or model.state_of(seat) != LobbyModel.SeatState.HUMAN:
		return
	_kicked.rpc_id(seat)
	_mp.disconnect_peer(seat)
	_drop_link(seat)
	model.guest_left(seat)
	_broadcast_roster()


func set_bot(seat: int, enabled: bool) -> void:
	if is_host and model.set_bot(seat, enabled):
		_broadcast_roster()


# ---------------------------------------------------------------------------
# 참가자
# ---------------------------------------------------------------------------

## 방장에게 받은 초대 코드로 참가한다. 응답 코드는 answer_ready로 온다.
func join_room(guest_nickname: String, invite_code: String) -> bool:
	leave()
	var decoded: Dictionary = LobbyCode.decode(invite_code)
	if not bool(decoded["ok"]):
		link_failed.emit(0, str(decoded["error"]))
		return false
	if decoded["kind"] != LobbyCode.KIND_OFFER:
		link_failed.emit(0, "이 코드는 응답 코드입니다. 방장에게 받은 초대 코드를 붙여 넣어 주세요.")
		return false
	var seat: int = int(decoded["peer_id"])
	var link := RtcLink.new()
	if not link.setup():
		return false
	_mp = WebRTCMultiplayerPeer.new()
	var error: int = _mp.create_client(seat)
	if error != OK:
		link_failed.emit(0, "접속을 준비하지 못했습니다 (오류 %d)." % error)
		_mp = null
		return false
	multiplayer.multiplayer_peer = _mp
	error = _mp.add_peer(link.connection, HOST_PEER_ID)
	if error != OK:
		link_failed.emit(0, "연결을 준비하지 못했습니다 (오류 %d)." % error)
		leave()
		return false
	is_host = false
	_in_room = true
	nickname = guest_nickname
	link.code_ready.connect(func(code: String) -> void: answer_ready.emit(code))
	link.failed.connect(func(message: String) -> void: link_failed.emit(0, message))
	_links[HOST_PEER_ID] = link
	link.accept_offer(invite_code)
	return true


# ---------------------------------------------------------------------------
# 공통
# ---------------------------------------------------------------------------

func leave() -> void:
	for link: RtcLink in _links.values():
		link.close()
	_links.clear()
	if _mp != null:
		_mp.close()
		_mp = null
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	is_host = false
	_in_room = false
	model.reset()


func _drop_link(seat: int) -> void:
	if _links.has(seat):
		(_links[seat] as RtcLink).close()
		_links.erase(seat)
	if _mp != null and _mp.has_peer(seat):
		_mp.remove_peer(seat)


func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	if model.state_of(peer_id) == LobbyModel.SeatState.INVITED:
		model.guest_joined(peer_id, "플레이어 %d" % peer_id)
		_broadcast_roster()


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host or peer_id < 2:
		return
	_drop_link(peer_id)
	if model.state_of(peer_id) == LobbyModel.SeatState.HUMAN:
		model.guest_left(peer_id)
	elif model.state_of(peer_id) == LobbyModel.SeatState.INVITED:
		model.cancel_invite(peer_id)
	_broadcast_roster()


func _on_connected_to_server() -> void:
	_hello.rpc_id(HOST_PEER_ID, nickname)
	joined.emit()


func _on_server_disconnected() -> void:
	var was_in: bool = _in_room
	leave()
	if was_in:
		left_room.emit("방장과의 연결이 끊어졌습니다.")


func _broadcast_roster() -> void:
	roster_changed.emit()
	if _in_room and is_host and multiplayer.has_multiplayer_peer():
		_roster.rpc(model.to_array())


## 참가자 -> 방장: 닉네임을 알린다.
@rpc("any_peer", "call_remote", "reliable")
func _hello(guest_nickname: String) -> void:
	if not is_host:
		return
	var seat: int = multiplayer.get_remote_sender_id()
	var clean: String = guest_nickname.strip_edges().substr(0, GameSession.MAX_NICKNAME_LENGTH)
	if clean.is_empty():
		clean = "플레이어 %d" % seat
	if model.state_of(seat) == LobbyModel.SeatState.HUMAN:
		model.rename_guest(seat, clean)
	elif model.state_of(seat) == LobbyModel.SeatState.INVITED:
		model.guest_joined(seat, clean)
	_broadcast_roster()


## 방장 -> 참가자: 좌석 명단.
@rpc("authority", "call_remote", "reliable")
func _roster(data: Array) -> void:
	if not is_host:
		model.from_array(data)


@rpc("authority", "call_remote", "reliable")
func _kicked() -> void:
	if not is_host:
		leave()
		left_room.emit("방장이 내보냈습니다.")
