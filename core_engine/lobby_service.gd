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
## 방장: 방 코드가 정해졌다 (친구에게 알려 줄 5자리).
signal room_ready(code: String)
## 방장: 공개 릴레이와의 통신 상태가 바뀌었다 (false면 자동 연결이 막힌 것 - 수동 코드로 대신할 수 있다).
signal relay_status_changed(ok: bool)
## 참가자: 방 코드 입장 진행 안내 ("방을 찾는 중..." 등).
signal join_progress(message: String)
## 참가자: 방 코드 입장에 실패했다.
signal join_failed(message: String)

const HOST_PEER_ID: int = 1

var model: LobbyModel = LobbyModel.new()
var is_host: bool = false
var nickname: String = ""

## true면 실제 WebRTC 피어 없이 방장 상태만 만든다 (헤드리스 화면 테스트용).
var offline_for_test: bool = false

## 방장이 자리마다 초대를 자동으로 올리고 응답을 수거할지 (오프라인 테스트에서는 끈다).
var auto_signaling: bool = true
var broker: SignalBroker = null
var room_code: String = ""
## 방장 응답 수거 주기 / 참가자 선점 확인 대기 / 한 자리에 연결을 기다리는 시간 / 응답을 받고도 연결이 안 된 자리를 새 초대로 바꾸는 시간(초).
var poll_seconds: float = 2.0
var claim_check_seconds: float = 1.2
var connect_timeout_seconds: float = 15.0
var recycle_seconds: float = 25.0
var rng := RandomNumberGenerator.new()

var _mp: WebRTCMultiplayerPeer = null
var _links: Dictionary = {}  # 좌석 -> RtcLink
var _in_room: bool = false
var _signaling: RoomSignaling = null
var _offer_nonce: Dictionary = {}    # 좌석 -> 지금 올려 둔 초대의 표식
var _answer_seen: Dictionary = {}    # 좌석 -> 응답함에서 이미 읽은 개수
var _answered_at: Dictionary = {}    # 좌석 -> 응답을 적용한 시각(ms)
var _poll_left: float = 0.0
var _polling_busy: Dictionary = {}
var _ensuring: bool = false
var _relay_ok: bool = true
# 참가자 자동 입장 상태
var _joining: bool = false
var _join_serial: int = 0
var _join_nickname: String = ""
var _join_candidates: Array = []
var _join_nonce: String = ""
var _join_seat: int = 0
var _join_answer: String = ""


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	if broker == null:
		var ntfy := NtfyBroker.new()
		ntfy.name = "Broker"
		add_child(ntfy)
		broker = ntfy
	elif broker.get_parent() == null:
		add_child(broker)
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
	room_code = RoomCode.generate(rng)
	_signaling = RoomSignaling.new(broker, room_code)
	room_ready.emit(room_code)
	if auto_signaling and not offline_for_test:
		_ensure_invites()
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
	link.code_ready.connect(func(code: String) -> void:
		invite_ready.emit(seat, code)
		if _links.get(seat) == link:
			_publish_offer(seat, code))
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
	_ensure_invites()


## 참가자를 내보낸다.
func kick(seat: int) -> void:
	if not is_host or model.state_of(seat) != LobbyModel.SeatState.HUMAN:
		return
	_kicked.rpc_id(seat)
	_mp.disconnect_peer(seat)
	_drop_link(seat)
	model.guest_left(seat)
	_broadcast_roster()
	_ensure_invites()


func set_bot(seat: int, enabled: bool) -> void:
	if not is_host:
		return
	# 자동 초대가 걸려 있는 자리는 초대를 닫은 뒤 봇으로 채운다.
	if enabled and model.state_of(seat) == LobbyModel.SeatState.INVITED:
		_drop_link(seat)
		model.cancel_invite(seat)
	if model.set_bot(seat, enabled):
		_broadcast_roster()
	_ensure_invites()


# ---------------------------------------------------------------------------
# 방장: 방 코드 자동 시그널링 (공개 릴레이에 초대를 올리고 응답을 수거)
# ---------------------------------------------------------------------------

## 열린 좌석마다 초대를 자동으로 만든다 (사람이 나가거나 봇을 비우면 다시 열려서 새 초대가 된다).
func _ensure_invites() -> void:
	if not is_host or not _in_room or not auto_signaling or offline_for_test or _ensuring:
		return
	_ensuring = true
	for seat: int in range(2, LobbyModel.SEAT_COUNT + 1):
		if model.state_of(seat) == LobbyModel.SeatState.OPEN:
			create_invite(seat)
	_ensuring = false


func _publish_offer(seat: int, offer_code: String) -> void:
	if _signaling == null or not auto_signaling:
		return
	var nonce: String = RoomCode.new_nonce(rng)
	_offer_nonce[seat] = nonce
	_answer_seen[seat] = 0
	_answered_at.erase(seat)
	_signaling.post_offer(seat, nonce, offer_code, func(ok: bool) -> void: _set_relay_ok(ok))


func _set_relay_ok(ok: bool) -> void:
	if ok != _relay_ok:
		_relay_ok = ok
		relay_status_changed.emit(ok)


func _forget_offer(seat: int) -> void:
	if _offer_nonce.has(seat) and _signaling != null:
		_signaling.close_offer(seat)
	_offer_nonce.erase(seat)
	_answer_seen.erase(seat)
	_answered_at.erase(seat)
	_polling_busy.erase(seat)


func _process(delta: float) -> void:
	if not is_host or not _in_room or _signaling == null or _offer_nonce.is_empty():
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = poll_seconds
	poll_answers_now()


## 올라온 응답을 한 번 수거한다 (주기적으로 불리며, 테스트가 직접 부를 수 있다).
func poll_answers_now() -> void:
	for seat: int in _offer_nonce.keys():
		if _polling_busy.has(seat) or model.state_of(seat) != LobbyModel.SeatState.INVITED:
			continue
		if _answered_at.has(seat):
			# 응답을 적용했는데도 오래 연결되지 않으면 새 초대로 바꾼다.
			if Time.get_ticks_msec() - int(_answered_at[seat]) > int(recycle_seconds * 1000.0):
				_drop_link(seat)
				model.cancel_invite(seat)
				_broadcast_roster()
				_ensure_invites()
			continue
		_polling_busy[seat] = true
		var nonce: String = str(_offer_nonce[seat])
		_signaling.collect_answers(seat, nonce, int(_answer_seen.get(seat, 0)), func(ok: bool, bodies: Array, total: int) -> void:
			_polling_busy.erase(seat)
			_set_relay_ok(ok)
			if not ok or str(_offer_nonce.get(seat, "")) != nonce:
				return
			_answer_seen[seat] = total
			for body: Variant in bodies:
				if submit_answer(seat, str(body)):
					_answered_at[seat] = Time.get_ticks_msec()
					break)


# ---------------------------------------------------------------------------
# 참가자
# ---------------------------------------------------------------------------

## 방장에게 받은 초대 코드로 참가한다 (고급: 수동 코드 연결). 응답 코드는 answer_ready로 온다.
func join_room(guest_nickname: String, invite_code: String) -> bool:
	leave()
	return _connect_with_offer(guest_nickname, invite_code)


## 초대 코드로 실제 연결을 시작한다 (수동 입장과 방 코드 자동 입장이 함께 쓴다).
func _connect_with_offer(guest_nickname: String, invite_code: String) -> bool:
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
		_disconnect_all()
		return false
	is_host = false
	_in_room = true
	nickname = guest_nickname
	link.code_ready.connect(func(code: String) -> void:
		answer_ready.emit(code)
		if _joining and _links.get(HOST_PEER_ID) == link:
			_post_join_answer(code))
	link.failed.connect(func(message: String) -> void:
		link_failed.emit(0, message)
		if _joining and _links.get(HOST_PEER_ID) == link:
			_try_next_candidate("연결 정보를 처리하지 못했습니다."))
	_links[HOST_PEER_ID] = link
	link.accept_offer(invite_code)
	return true


# ---------------------------------------------------------------------------
# 참가자: 방 코드만으로 자동 입장
# ---------------------------------------------------------------------------

## 5자리 방 코드로 입장한다. 릴레이에서 방장의 초대를 찾아 응답을 올리고 연결을 기다린다 (진행은 join_progress, 실패는 join_failed, 성공은 joined).
func join_by_room_code(guest_nickname: String, text: String) -> bool:
	leave()
	var code: String = RoomCode.normalize(text)
	if not RoomCode.is_valid(code):
		join_failed.emit("방 코드는 영문 대문자와 숫자 %d자리입니다." % RoomCode.LENGTH)
		return false
	_joining = true
	_join_nickname = guest_nickname
	_signaling = RoomSignaling.new(broker, code)
	var serial: int = _join_serial
	join_progress.emit("방을 찾는 중...")
	_signaling.find_offers(func(result: Dictionary) -> void:
		if serial != _join_serial or not _joining:
			return
		if not bool(result["ok"]):
			_fail_join("중계 서버에 연결하지 못했습니다. 인터넷 연결을 확인하거나 [고급: 수동 코드 연결]을 사용해 주세요.")
		elif (result["candidates"] as Array).is_empty():
			_fail_join("빈 자리가 있는 방을 찾지 못했습니다. 방 코드를 확인하거나 잠시 후 다시 시도해 주세요." if not bool(result["saw_room"]) else "방이 가득 찼거나 닫혔습니다.")
		else:
			_join_candidates = result["candidates"]
			_try_next_candidate(""))
	return true


func _fail_join(message: String) -> void:
	_cancel_join()
	_disconnect_all()
	join_failed.emit(message)


## 후보 자리 하나에 연결을 시도한다. 후보가 없으면 입장 실패.
func _try_next_candidate(reason: String) -> void:
	var code: String = _signaling.code if _signaling != null else ""
	_disconnect_all_keep_join()
	if _join_candidates.is_empty() or code == "":
		_fail_join(reason if reason != "" else "방에 입장하지 못했습니다. 다시 시도해 주세요.")
		return
	var candidate: Dictionary = _join_candidates.pop_front()
	_join_seat = int(candidate["seat"])
	_join_nonce = str(candidate["nonce"])
	_signaling = RoomSignaling.new(broker, code)
	join_progress.emit("방에 연결하는 중...")
	if not _connect_with_offer(_join_nickname, str(candidate["offer"])):
		_try_next_candidate("연결을 준비하지 못했습니다.")


## 방 코드를 지키며 연결만 정리한다.
func _disconnect_all_keep_join() -> void:
	var keep: RoomSignaling = _signaling
	_disconnect_all()
	_signaling = keep


func _post_join_answer(answer_code: String) -> void:
	_join_answer = answer_code
	var serial: int = _join_serial
	_signaling.post_answer(_join_seat, _join_nonce, answer_code, func(ok: bool) -> void:
		if serial != _join_serial or not _joining:
			return
		if not ok:
			_fail_join("중계 서버에 응답을 보내지 못했습니다. 인터넷 연결을 확인하거나 [고급: 수동 코드 연결]을 사용해 주세요.")
			return
		get_tree().create_timer(claim_check_seconds).timeout.connect(func() -> void: _check_claim(serial)))


func _check_claim(serial: int) -> void:
	if serial != _join_serial or not _joining:
		return
	_signaling.claim_won(_join_seat, _join_nonce, _join_answer, func(won: bool) -> void:
		if serial != _join_serial or not _joining:
			return
		if not won:
			_try_next_candidate("다른 사람이 먼저 그 자리에 들어갔습니다.")
			return
		join_progress.emit("방장과 연결하는 중...")
		get_tree().create_timer(connect_timeout_seconds).timeout.connect(func() -> void:
			if serial == _join_serial and _joining:
				_try_next_candidate("방장과 연결되지 않았습니다. 네트워크 환경이 직접 연결을 막고 있을 수 있습니다.")))


# ---------------------------------------------------------------------------
# 공통
# ---------------------------------------------------------------------------

func leave() -> void:
	_cancel_join()
	_disconnect_all()


func _cancel_join() -> void:
	_joining = false
	_join_serial += 1
	_join_candidates.clear()


## 연결만 정리한다 (방 코드 입장 재시도 사이에도 쓴다).
func _disconnect_all() -> void:
	if _signaling != null and is_host:
		for seat: int in _offer_nonce.keys():
			_signaling.close_offer(seat)
	_offer_nonce.clear()
	_answer_seen.clear()
	_answered_at.clear()
	_polling_busy.clear()
	_signaling = null
	room_code = ""
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
	_forget_offer(seat)
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
	_ensure_invites()


func _on_connected_to_server() -> void:
	_joining = false
	_join_serial += 1  # 대기 중인 입장 타이머를 모두 무효로 만든다
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
