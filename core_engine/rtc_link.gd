# File: res://core_engine/rtc_link.gd
# Class: class_name RtcLink
# Role: WebRTC 연결 하나(방장<->참가자 1명)의 수동 시그널링. 초대 코드(offer)를 만들고, 초대 코드를 받아 응답 코드(answer)를 만들고, 응답 코드를 받아 연결을 완성한다. ICE 후보는 한꺼번에 모아 코드 하나에 담는다
class_name RtcLink
extends RefCounted

signal code_ready(code: String)
signal failed(message: String)

## 공개 STUN 서버. 같은 공유기 안이 아니어도 대부분의 가정 네트워크에서 직접 연결이 된다 (엄격한 NAT에서는 실패할 수 있다).
const DEFAULT_ICE_SERVERS: Array = [
	{"urls": ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]},
]

## 후보가 이 시간(초) 동안 더 나오지 않으면 모으기를 끝낸다 / 어떤 경우에도 이 시간(초)이 지나면 끝낸다.
var quiet_seconds: float = 0.8
var max_seconds: float = 5.0

## WebRTCPeerConnection 또는 같은 API(초기화·offer·description·candidate)를 가진 대체 객체. 테스트가 가짜를 주입한다.
var connection: RefCounted = null

var _peer_id: int = 0
var _kind: String = ""
var _local_sdp: String = ""
var _candidates: Array = []
var _gather_serial: int = 0
var _gathering: bool = false
var _done: bool = false
var _tree: SceneTree = null


func _init(existing_connection: RefCounted = null) -> void:
	_tree = Engine.get_main_loop() as SceneTree
	connection = existing_connection if existing_connection != null else WebRTCPeerConnection.new()


## 연결 객체를 초기화한다. 성공하면 true.
func setup(ice_servers: Array = DEFAULT_ICE_SERVERS) -> bool:
	var error: Variant = connection.call("initialize", {"iceServers": ice_servers})
	if int(error) != OK:
		_fail("이 환경에서는 WebRTC를 쓸 수 없습니다 (오류 %s). 웹 브라우저 빌드로 실행해 주세요." % str(error))
		return false
	connection.connect("session_description_created", _on_description_created)
	connection.connect("ice_candidate_created", _on_candidate_created)
	return true


## 방장 쪽 1단계: 참가자(peer_id) 몫의 초대 코드를 만든다. 이 호출 전에 멀티플레이 피어에 connection을 add_peer 해 두어야 한다.
func start_offer(peer_id: int) -> void:
	_peer_id = peer_id
	_kind = LobbyCode.KIND_OFFER
	var error: int = int(connection.call("create_offer"))
	if error != OK:
		_fail("초대 코드를 만들지 못했습니다 (오류 %d)." % error)


## 참가자 쪽 1단계: 받은 초대 코드로 응답 코드를 만든다.
func accept_offer(code_text: String) -> void:
	var decoded: Dictionary = LobbyCode.decode(code_text)
	if not bool(decoded["ok"]):
		_fail(str(decoded["error"]))
		return
	if decoded["kind"] != LobbyCode.KIND_OFFER:
		_fail("이 코드는 응답 코드입니다. 방장에게 받은 초대 코드를 붙여 넣어 주세요.")
		return
	_peer_id = int(decoded["peer_id"])
	_kind = LobbyCode.KIND_ANSWER
	var error: int = int(connection.call("set_remote_description", "offer", str(decoded["sdp"])))
	if error != OK:
		_fail("초대 코드를 적용하지 못했습니다 (오류 %d)." % error)
		return
	_apply_remote_candidates(decoded["candidates"])


## 방장 쪽 2단계: 참가자가 보내 준 응답 코드로 연결을 완성한다. 성공하면 true (실제 연결 성립은 멀티플레이 피어 신호로 알 수 있다).
func accept_answer(code_text: String) -> bool:
	var decoded: Dictionary = LobbyCode.decode(code_text)
	if not bool(decoded["ok"]):
		_fail(str(decoded["error"]))
		return false
	if decoded["kind"] != LobbyCode.KIND_ANSWER:
		_fail("이 코드는 초대 코드입니다. 참가자가 만든 응답 코드를 붙여 넣어 주세요.")
		return false
	if int(decoded["peer_id"]) != _peer_id:
		_fail("다른 좌석의 응답 코드입니다 (좌석 %d 코드가 필요합니다)." % _peer_id)
		return false
	var error: int = int(connection.call("set_remote_description", "answer", str(decoded["sdp"])))
	if error != OK:
		_fail("응답 코드를 적용하지 못했습니다 (오류 %d)." % error)
		return false
	_apply_remote_candidates(decoded["candidates"])
	return true


func peer_id() -> int:
	return _peer_id


func close() -> void:
	_done = true
	if connection != null and connection.has_method("close"):
		connection.call("close")


func _apply_remote_candidates(candidates: Array) -> void:
	for entry: Variant in candidates:
		var candidate: Dictionary = entry
		connection.call("add_ice_candidate", str(candidate["media"]), int(candidate["index"]), str(candidate["name"]))


func _on_description_created(type: String, sdp: String) -> void:
	connection.call("set_local_description", type, sdp)
	_local_sdp = sdp
	_gathering = true
	_arm_quiet_timer()
	if _tree != null:
		_tree.create_timer(max_seconds).timeout.connect(_finish_gathering)


func _on_candidate_created(media: String, index: int, name: String) -> void:
	if _done:
		return
	_candidates.append({"media": media, "index": index, "name": name})
	if _gathering:
		_arm_quiet_timer()


func _arm_quiet_timer() -> void:
	_gather_serial += 1
	var serial: int = _gather_serial
	if _tree == null:
		return
	_tree.create_timer(quiet_seconds).timeout.connect(func() -> void:
		if serial == _gather_serial:
			_finish_gathering())


func _finish_gathering() -> void:
	if _done or not _gathering:
		return
	_gathering = false
	_done = true
	if _candidates.is_empty():
		_fail("연결 후보를 찾지 못했습니다. 네트워크 연결을 확인해 주세요.")
		return
	code_ready.emit(LobbyCode.encode(_kind, _peer_id, _local_sdp, _candidates))


func _fail(message: String) -> void:
	failed.emit(message)
