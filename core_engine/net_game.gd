# File: res://core_engine/net_game.gd
# Class: class_name NetGame
# Role: 온라인 대전 동기화(락스텝). 모든 참가자가 같은 시드로 같은 규칙 엔진을 돌리고, 방장이 받은 행동에 순서를 매겨 모두에게 똑같이 적용시킨다. 사람/봇/타임아웃 행동이 전부 방장을 거치므로 판은 항상 같다. 화면을 모른다
class_name NetGame
extends Node

## 모든 참가자가 시작 준비를 마쳤다: 이제 각자 manager.start_game(players, seed)을 부르면 된다.
signal started(seed_value: int, players: Array, bots: Array)
## 사람 한 명이 나가 봇이 이어받는다 (방장이 정한 뒤 모두에게 알려진다).
signal seat_taken_over(seat: int)
## 방장 판과 내 판이 어긋났다 (상태 지문 불일치 / 순서 이상).
signal desynced(detail: String)
## 방장과의 연결이 끊겼다.
signal connection_lost(reason: String)
## 상대 화면이 멈췄거나(다른 창·탭·앱으로 이동, 느린 연결) 다시 움직였다. 웹 브라우저는 보이지 않는 탭을 멈추기 때문에 알려 준다.
signal peer_silent(seat: int, silent: bool)

## 다른 좌석이 감정 표현을 했다 (게임 규칙과 무관한 연출 전용 신호). emotion은 EmoteCatalog.EMOTES의 순번이다.
signal emote_received(seat: int, emotion: int)

const ACTION_TAKEOVER: StringName = &"__takeover"
## 감정 표현 번호 범위(EmoteCatalog.EMOTES의 순번 0~7)와, 같은 좌석의 최소 간격(초)을 방장이 지킨다.
const EMOTE_MIN: int = 0
const EMOTE_MAX: int = 7
const EMOTE_COOLDOWN_MSEC: int = 600
## 모두가 준비되기를 기다리는 최대 시간(초). 넘으면 준비 안 된 사람은 봇으로 넘긴다.
const READY_TIMEOUT: float = 15.0
## 제한 시간(자동 굴리기·자동 선택 등)을 사람 속도에 맞게 늘리는 배율.
const TIMER_SCALE: float = 3.0
## 살아 있다는 신호(핑)를 보내는 간격 / 이만큼(초) 소식이 없으면 멈춘 것으로 본다.
const PING_SECONDS: float = 1.0
const SILENT_SECONDS: float = 4.0

var manager: TurnManager = null
var is_host: bool = false
var local_seat: int = 1
var players: Array[int] = []
var humans: Array[int] = []
var bots: Array[int] = []
var seed_value: int = 0
var names: Dictionary = {}
var running: bool = false
var applied_count: int = 0
## 테스트: 좌석 -> NetGame. 비어 있지 않으면 RPC 대신 이 객체들을 직접 부른다.
var test_peers: Dictionary = {}

var _ready_seats: Dictionary = {}
var _ready_wait: float = 0.0
var _seq: int = 0
var _expected_seq: int = 1
var _pending: Array = []   # 방장: 이동 연출 중이라 기다리는 행동 {action, params, sender}
var _queue: Array = []     # 참가자: 받았지만 아직 적용 못 한 항목
var _applying_rejection: Array = []
var _launched: bool = false
var _ping_left: float = 0.0
var _heard: Dictionary = {}    # 좌석 -> 마지막으로 소식을 들은 시각(ms)
var _silent: Dictionary = {}   # 좌석 -> 지금 멈춘 것으로 표시 중인가
var _last_emote_msec: Dictionary = {}  # 좌석 -> 마지막 감정 표현 시각(ms)


## 매니저에 연결한다. 이후 manager.act()/force_timeout()/auto_pick_draft()는 모두 방장을 거쳐 돌아온다.
func setup(target: TurnManager, host: bool, seat: int, seats: Array[int], bot_seats: Array[int], seat_names: Dictionary, seed_for_game: int) -> void:
	manager = target
	is_host = host
	local_seat = seat
	players.assign(seats)
	bots.assign(bot_seats)
	humans = []
	for player_id: int in players:
		if not bots.has(player_id):
			humans.append(player_id)
	names = seat_names.duplicate()
	seed_value = seed_for_game
	manager.lockstep = true
	manager.external_timeouts = true
	manager.timer_scale = TIMER_SCALE
	manager.hotseat_mode = true
	manager.action_interceptor = _on_local_action
	manager.action_rejected.connect(_on_manager_rejected)
	manager.timeout_due.connect(_on_timeout_due)
	if not test_peers.is_empty():
		return
	if multiplayer.has_multiplayer_peer():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.server_disconnected.connect(func() -> void: connection_lost.emit("방장과의 연결이 끊어졌습니다."))


func is_bot(seat: int) -> bool:
	return bots.has(seat)


func display_name(seat: int) -> String:
	if bots.has(seat):
		return "컴퓨터 %d" % seat
	return str(names.get(seat, "플레이어 %d" % seat))


## 화면이 다 만들어졌다: 방장은 모두의 준비를 기다렸다가 시작하고, 참가자는 준비됐다고 방장에게 알린다.
func begin() -> void:
	if is_host:
		_ready_seats[local_seat] = true
		_ready_wait = READY_TIMEOUT
		_try_launch()
	else:
		_send_ready()


func _process(delta: float) -> void:
	if manager == null:
		return
	if is_host and not _launched:
		_ready_wait -= delta
		if _ready_wait <= 0.0:
			_launch(true)
		return
	if not running:
		return
	_tick_presence(delta)
	manager.tick(delta)
	if is_host:
		_drain_pending()
	else:
		_drain_queue()


# ---------------------------------------------------------------------------
# 상대 화면 상태 (핑)
# ---------------------------------------------------------------------------

func _tick_presence(delta: float) -> void:
	_ping_left -= delta
	if _ping_left <= 0.0:
		_ping_left = PING_SECONDS
		_send_ping()
	# 내 화면이 오래 멈췄다 돌아온 첫 프레임(delta가 큼)에는 판단하지 않는다: 밀린 소식이 곧 도착한다.
	if delta > 1.0:
		return
	var now: int = Time.get_ticks_msec()
	for seat: int in _watched_seats():
		var quiet: bool = now - int(_heard.get(seat, now)) > int(SILENT_SECONDS * 1000.0)
		if quiet != bool(_silent.get(seat, false)):
			_silent[seat] = quiet
			peer_silent.emit(seat, quiet)


## 소식을 기다려야 하는 좌석: 방장은 참가자 전원, 참가자는 방장.
func _watched_seats() -> Array[int]:
	if is_host:
		return _remote_seats()
	var host_seat: Array[int] = [1]
	return host_seat


func _on_ping(seat: int) -> void:
	_heard[seat] = Time.get_ticks_msec()


func _send_ping() -> void:
	if not test_peers.is_empty():
		for seat: int in test_peers.keys():
			if seat != local_seat and (is_host or seat == 1):
				(test_peers[seat] as NetGame)._on_ping(local_seat)
	elif _has_remote_peers():
		_rpc_ping.rpc()


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping() -> void:
	_on_ping(multiplayer.get_remote_sender_id())


# ---------------------------------------------------------------------------
# 감정 표현: 규칙과 무관한 연출 신호. 참가자 -> 방장 -> 나머지 참가자로 전달한다 (내 화면은 호출한 쪽이 직접 반응시킨다)
# ---------------------------------------------------------------------------

func send_emote(emotion: int) -> void:
	if not running or emotion < EMOTE_MIN or emotion > EMOTE_MAX:
		return
	if is_host:
		_relay_emote(local_seat, emotion)
	elif not test_peers.is_empty():
		(test_peers[1] as NetGame).emote_from(local_seat, emotion)
	else:
		_rpc_emote.rpc_id(1, emotion)


## 방장: 좌석 sender의 감정 표현을 받아 검사하고 다른 모두에게 퍼뜨린다.
func emote_from(sender: int, emotion: int) -> void:
	if not is_host or not running or not humans.has(sender):
		return
	if emotion < EMOTE_MIN or emotion > EMOTE_MAX:
		return
	_relay_emote(sender, emotion)


func _relay_emote(seat: int, emotion: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - int(_last_emote_msec.get(seat, -100000)) < EMOTE_COOLDOWN_MSEC:
		return
	_last_emote_msec[seat] = now
	if seat != local_seat:
		emote_received.emit(seat, emotion)
	if not test_peers.is_empty():
		for other: int in test_peers.keys():
			if other != local_seat and other != seat:
				(test_peers[other] as NetGame)._on_emote(seat, emotion)
	elif _has_remote_peers():
		for other: int in _remote_seats():
			if other != seat:
				_rpc_emote_out.rpc_id(other, seat, emotion)


func _on_emote(seat: int, emotion: int) -> void:
	if is_host or emotion < EMOTE_MIN or emotion > EMOTE_MAX:
		return
	emote_received.emit(seat, emotion)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_emote(emotion: int) -> void:
	emote_from(multiplayer.get_remote_sender_id(), emotion)


@rpc("authority", "call_remote", "reliable")
func _rpc_emote_out(seat: int, emotion: int) -> void:
	_on_emote(seat, emotion)


# ---------------------------------------------------------------------------
# 시작
# ---------------------------------------------------------------------------

func _try_launch() -> void:
	for seat: int in humans:
		if seat != local_seat and not _ready_seats.has(seat):
			return
	_launch(false)


## 방장: 준비된 사람으로 시작한다. 시간이 다 돼서 시작하면 준비 안 된 사람은 봇으로 넘긴다.
func _launch(forced: bool) -> void:
	if _launched:
		return
	_launched = true
	if forced:
		for seat: int in humans.duplicate():
			if not _ready_seats.has(seat):
				humans.erase(seat)
				bots.append(seat)
	_send_start(seed_value, players, bots)
	_start_local()


func _start_local() -> void:
	var now: int = Time.get_ticks_msec()
	for seat: int in humans:
		_heard[seat] = now
	running = true
	_launched = true
	_expected_seq = 1
	started.emit(seed_value, players, bots)


# ---------------------------------------------------------------------------
# 행동: 모든 입구가 방장으로 모인다
# ---------------------------------------------------------------------------

func _on_local_action(action: StringName, params: Dictionary) -> void:
	if not running:
		return
	if is_host:
		submit_from(local_seat, action, params)
	else:
		_send_submit(action, params)


func _on_timeout_due(serial: int) -> void:
	if is_host and running:
		submit_from(local_seat, TurnManager.ACTION_TIMEOUT, {"serial": serial})


## 방장: 좌석 sender가 보낸 행동 하나를 받는다.
func submit_from(sender: int, action: StringName, params: Dictionary) -> void:
	if not is_host or not running:
		return
	if not _sender_allowed(sender, action, params):
		_reject(sender, int(params.get("player_id", -1)), action, &"not_your_seat")
		return
	_pending.append({"action": action, "params": params.duplicate(true), "sender": sender})
	_drain_pending()


func _sender_allowed(sender: int, action: StringName, params: Dictionary) -> bool:
	var player_id: int = int(params.get("player_id", -1))
	if action == TurnManager.ACTION_TIMEOUT:
		return true
	if action == TurnManager.ACTION_AUTO_DRAFT:
		return player_id == sender or (sender == local_seat and bots.has(player_id))
	if String(action).begins_with("__"):
		return sender == local_seat
	if sender == local_seat:
		return player_id == local_seat or bots.has(player_id)
	return player_id == sender and humans.has(sender)


## 방장: 이동 연출 중이 아니면 쌓인 행동을 순서대로 적용하고 모두에게 보낸다.
func _drain_pending() -> void:
	while not _pending.is_empty() and manager.state != null and manager.current_state != TurnManager.State.PHASE_MOVING_STEP:
		var item: Dictionary = _pending.pop_front()
		_apply_as_host(item["action"], item["params"], int(item["sender"]))


func _apply_as_host(action: StringName, params: Dictionary, sender: int) -> void:
	var serial: int = manager.phase_serial
	_applying_rejection = []
	if action == ACTION_TAKEOVER:
		_apply_takeover(int(params.get("seat", -1)))
	else:
		manager.apply_replicated(action, params)
	if not _applying_rejection.is_empty():
		var info: Array = _applying_rejection
		_applying_rejection = []
		if sender != local_seat:
			_send_reject(sender, int(info[0]), info[1], info[2])
		return
	_seq += 1
	applied_count += 1
	var check: int = 0 if manager.current_state == TurnManager.State.PHASE_MOVING_STEP else manager.state_hash()
	_send_entry({"seq": _seq, "serial": serial, "action": action, "params": params, "check": check})


func _on_manager_rejected(player_id: int, action: StringName, reason: StringName) -> void:
	_applying_rejection = [player_id, action, reason]


func _reject(sender: int, player_id: int, action: StringName, reason: StringName) -> void:
	if sender == local_seat:
		manager.action_rejected.emit(player_id, action, reason)
	else:
		_send_reject(sender, player_id, action, reason)


func _apply_takeover(seat: int) -> void:
	if seat < 1 or bots.has(seat) or not players.has(seat):
		return
	humans.erase(seat)
	bots.append(seat)
	seat_taken_over.emit(seat)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host and running and humans.has(peer_id):
		submit_from(local_seat, ACTION_TAKEOVER, {"seat": peer_id})


# ---------------------------------------------------------------------------
# 참가자: 방장이 정한 순서대로 적용
# ---------------------------------------------------------------------------

func _on_entry(entry: Dictionary) -> void:
	if is_host:
		return
	_queue.append(entry)
	_drain_queue()


func _drain_queue() -> void:
	while not _queue.is_empty() and manager.state != null:
		var entry: Dictionary = _queue[0]
		if manager.current_state == TurnManager.State.PHASE_MOVING_STEP:
			return
		var serial: int = int(entry["serial"])
		if serial > manager.phase_serial:
			return  # 내 판이 아직 그 지점까지 오지 못했다 (연출 중)
		_queue.pop_front()
		if serial < manager.phase_serial or int(entry["seq"]) != _expected_seq:
			desynced.emit("순서 불일치: 항목 %s (serial %d, 내 serial %d)" % [str(entry["seq"]), serial, manager.phase_serial])
			continue
		_expected_seq += 1
		_applying_rejection = []
		var action: StringName = entry["action"]
		if action == ACTION_TAKEOVER:
			_apply_takeover(int((entry["params"] as Dictionary).get("seat", -1)))
		else:
			manager.apply_replicated(action, entry["params"])
		applied_count += 1
		if not _applying_rejection.is_empty():
			desynced.emit("방장은 받아들였지만 내 판에서는 거부됨: %s" % str(_applying_rejection))
			_applying_rejection = []
			continue
		var check: int = int(entry["check"])
		if check != 0 and manager.current_state != TurnManager.State.PHASE_MOVING_STEP and manager.state_hash() != check:
			desynced.emit("상태 지문 불일치 (항목 %d, %s)" % [int(entry["seq"]), String(action)])


# ---------------------------------------------------------------------------
# 전송: 실제로는 RPC, 테스트에서는 직접 호출
# ---------------------------------------------------------------------------

func _remote_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat: int in humans:
		if seat != local_seat:
			seats.append(seat)
	return seats


func _has_remote_peers() -> bool:
	return not test_peers.is_empty() or (multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty())


func _send_ready() -> void:
	if not test_peers.is_empty():
		(test_peers[1] as NetGame)._on_ready(local_seat)
	else:
		_rpc_ready.rpc_id(1)


func _send_start(seed_to_send: int, seats: Array[int], bot_seats: Array[int]) -> void:
	if not test_peers.is_empty():
		for seat: int in test_peers.keys():
			if seat != local_seat:
				(test_peers[seat] as NetGame)._on_start(seed_to_send, seats, bot_seats)
	elif _has_remote_peers():
		_rpc_start.rpc(seed_to_send, seats, bot_seats)


func _send_submit(action: StringName, params: Dictionary) -> void:
	if not test_peers.is_empty():
		(test_peers[1] as NetGame).submit_from(local_seat, action, params)
	else:
		_rpc_submit.rpc_id(1, action, params)


func _send_entry(entry: Dictionary) -> void:
	if not test_peers.is_empty():
		for seat: int in test_peers.keys():
			if seat != local_seat:
				(test_peers[seat] as NetGame)._on_entry(entry.duplicate(true))
	elif _has_remote_peers():
		_rpc_entry.rpc(entry)


func _send_reject(seat: int, player_id: int, action: StringName, reason: StringName) -> void:
	if not test_peers.is_empty():
		(test_peers[seat] as NetGame)._on_reject(player_id, action, reason)
	elif _has_remote_peers():
		_rpc_reject.rpc_id(seat, player_id, action, reason)


func _on_ready(seat: int) -> void:
	if is_host:
		_ready_seats[seat] = true
		if not _launched:
			_try_launch()


func _on_start(seed_to_send: int, seats: Array, bot_seats: Array) -> void:
	if is_host or _launched:
		return
	seed_value = seed_to_send
	players.assign(seats)
	bots.assign(bot_seats)
	humans = []
	for seat: int in players:
		if not bots.has(seat):
			humans.append(seat)
	_start_local()


func _on_reject(player_id: int, action: StringName, reason: StringName) -> void:
	manager.action_rejected.emit(player_id, action, reason)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready() -> void:
	_on_ready(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _rpc_start(seed_to_send: int, seats: Array, bot_seats: Array) -> void:
	_on_start(seed_to_send, seats, bot_seats)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit(action: StringName, params: Dictionary) -> void:
	submit_from(multiplayer.get_remote_sender_id(), action, params)


@rpc("authority", "call_remote", "reliable")
func _rpc_entry(entry: Dictionary) -> void:
	_on_entry(entry)


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(player_id: int, action: StringName, reason: StringName) -> void:
	_on_reject(player_id, action, reason)


## 게임을 떠난다: 연결을 모두 닫고 기본(오프라인) 피어로 되돌린다.
func leave() -> void:
	running = false
	if test_peers.is_empty() and multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
