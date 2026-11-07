# File: res://core_engine/network_service.gd
# Class: class_name NetworkService
# Role: Listen Server(방장 겸 서버) 네트워크 계층. WebSocket/주입형(WebRTC 등) 피어로 접속하고 피어 ID -> 플레이어 좌석(1~4)을 관리한다.
class_name NetworkService
extends Node

signal roster_changed(peer_to_player: Dictionary)
signal host_started(port: int)
signal join_started(url: String)
signal connection_failed_reported()
signal network_error(message: String)

const DEFAULT_PORT: int = 24680
const MAX_PLAYERS: int = 4
const HOST_PEER_ID: int = 1

## 호스트 기준 피어 ID -> 플레이어 좌석 번호. 방 생성자(호스트)는 항상 1번이다.
var peer_to_player: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)


## 방장이 서버와 클라이언트를 겸하는 Listen Server를 연다. 브라우저(HTML5) 빌드는 서버 소켓을 열 수 없다.
func host_game(port: int = DEFAULT_PORT) -> Error:
	if OS.has_feature("web"):
		network_error.emit("웹 빌드는 직접 호스트할 수 없습니다. WebRTC 피어를 use_peer()로 주입하세요.")
		return ERR_UNAVAILABLE
	var peer := WebSocketMultiplayerPeer.new()
	var error: Error = peer.create_server(port)
	if error != OK:
		network_error.emit("서버 생성 실패: %s" % error_string(error))
		return error
	use_peer(peer)
	host_started.emit(port)
	return OK


func join_game(url: String) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var error: Error = peer.create_client(url)
	if error != OK:
		network_error.emit("접속 실패: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	join_started.emit(url)
	return OK


## 이미 만들어진 피어(WebRTCMultiplayerPeer, ENet, 테스트용 피어 등)를 그대로 사용한다.
func use_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	if multiplayer.is_server():
		peer_to_player.clear()
		peer_to_player[HOST_PEER_ID] = 1
		roster_changed.emit(peer_to_player)


func disconnect_game() -> void:
	multiplayer.multiplayer_peer = null
	peer_to_player.clear()
	roster_changed.emit(peer_to_player)


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func player_for_peer(peer_id: int) -> int:
	return int(peer_to_player.get(peer_id, -1))


func connected_player_count() -> int:
	return peer_to_player.size()


func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	if peer_to_player.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	peer_to_player[peer_id] = _first_free_seat()
	_broadcast_roster()


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	peer_to_player.erase(peer_id)
	_broadcast_roster()


func _on_connection_failed() -> void:
	connection_failed_reported.emit()


func _first_free_seat() -> int:
	for seat: int in range(1, MAX_PLAYERS + 1):
		if not peer_to_player.values().has(seat):
			return seat
	return -1


func _broadcast_roster() -> void:
	roster_changed.emit(peer_to_player)
	_rpc_roster.rpc(peer_to_player)


@rpc("authority", "call_remote", "reliable")
func _rpc_roster(roster: Dictionary) -> void:
	peer_to_player = roster
	roster_changed.emit(peer_to_player)
