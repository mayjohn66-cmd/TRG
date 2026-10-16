# File: res://core_engine/quick_match.gd
# Class: class_name QuickMatch
# Role: 빠른 랜덤 매칭 진행기. 공용 대기열에서 최근 12초 안의 열린 방을 찾아 자동 입장하고, 없으면 내가 방장이 되어 3초마다 비콘을 올리며 기다린다. 15초 안에 4명이 안 차거나 [지금 시작]을 누르면 빈자리를 AI 봇으로 채워 시작 신호를 보낸다. 화면을 모른다
class_name QuickMatch
extends Node

signal state_changed(state: int)
## 시작해도 된다 (빈자리는 이미 봇으로 채웠다). 사람 수는 service.model.human_count()로 안다.
signal start_requested()
## 매칭이 실패/취소로 끝났다.
signal failed(message: String)

enum State { IDLE, SEARCHING, JOINING, HOSTING, GUEST, STARTING }

var service: LobbyService = null
var state: State = State.IDLE
## 대기 시작 후 흐른 시간(초).
var elapsed: float = 0.0
var wait_seconds: float = MatchBeacon.WAIT_SECONDS
var beacon_seconds: float = MatchBeacon.BEACON_SECONDS
## false면 _process로 시간이 흐르지 않는다 (테스트가 tick을 직접 부른다).
var auto_tick: bool = true

var _beacon_left: float = 0.0
var _serial: int = 0
var _candidates_tried: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	set_process(auto_tick)


func _process(delta: float) -> void:
	tick(delta)


func is_active() -> bool:
	return state != State.IDLE


## 남은 대기 시간(초, 올림). 방장 대기 중에만 의미가 있다.
func seconds_left() -> int:
	return maxi(0, ceili(wait_seconds - elapsed))


## [빠른 랜덤 매칭]: 대기열을 찾아 본다.
func start() -> void:
	stop()
	_serial += 1
	elapsed = 0.0
	_candidates_tried.clear()
	_set_state(State.SEARCHING)
	_search_and_join()


## 취소: 비콘을 닫고 방에서 나간다.
func stop() -> void:
	_serial += 1
	_busy = false
	if state == State.HOSTING or state == State.STARTING:
		_publish_closed()
	if state != State.IDLE:
		service.leave()
	_set_state(State.IDLE)


## [지금 바로 시작]: 기다리지 않고 빈자리를 AI로 채워 시작한다 (방장만).
func start_now() -> void:
	if state == State.HOSTING:
		_begin_start()


func tick(delta: float) -> void:
	if state == State.IDLE:
		return
	elapsed += delta
	if state != State.HOSTING:
		return
	if service.model.human_count() >= LobbyModel.SEAT_COUNT or seconds_left() == 0:
		_begin_start()
		return
	_beacon_left -= delta
	if _beacon_left <= 0.0:
		_beacon_left = beacon_seconds
		_publish_beacon()
		_check_merge()


func _set_state(value: State) -> void:
	if state != value:
		state = value
		state_changed.emit(int(state))


# --- 찾기 / 합류 -----------------------------------------------------------

func _search_and_join() -> void:
	var serial: int = _serial
	service.broker.fetch_many([MatchBeacon.QUEUE_TOPIC], MatchBeacon.FRESH_SECONDS, func(ok: bool, by_topic: Dictionary) -> void:
		if serial != _serial or state != State.SEARCHING:
			return
		var messages: Array = by_topic.get(MatchBeacon.QUEUE_TOPIC, []) if ok else []
		var pick: Dictionary = _pick_untried(messages)
		if pick.is_empty():
			_become_host()
		else:
			_join(str(pick["code"])))


func _pick_untried(messages: Array) -> Dictionary:
	var filtered: Array = []
	for text: Variant in messages:
		var beacon: Dictionary = MatchBeacon.parse(str(text))
		if beacon.is_empty() or _candidates_tried.has(beacon["code"]):
			continue
		filtered.append(text)
	return MatchBeacon.pick_room(filtered)


func _join(code: String) -> void:
	_candidates_tried[code] = true
	_set_state(State.JOINING)
	_connect_service()
	if not service.join_by_room_code(GameSession.display_nickname(), code):
		_set_state(State.SEARCHING)
		_become_host()


func _connect_service() -> void:
	if not service.joined.is_connected(_on_service_joined):
		service.joined.connect(_on_service_joined)
		service.join_failed.connect(_on_service_join_failed)


func _on_service_joined() -> void:
	if state == State.JOINING:
		_set_state(State.GUEST)


## 그 방에 못 들어갔다 (이미 찼거나 닫힘·연결 실패): 다른 방을 찾아 보고 없으면 내가 방장이 된다.
func _on_service_join_failed(_message: String) -> void:
	if state == State.JOINING:
		_set_state(State.SEARCHING)
		_search_and_join()


# --- 방장 ------------------------------------------------------------------

func _become_host() -> void:
	if not service.host_room(GameSession.display_nickname()):
		_set_state(State.IDLE)
		failed.emit("방을 만들 수 없습니다. 웹 브라우저에서 열어 주세요.")
		return
	_set_state(State.HOSTING)
	_beacon_left = 0.0  # 바로 첫 비콘을 올린다


func _publish_beacon() -> void:
	service.broker.publish(MatchBeacon.QUEUE_TOPIC, MatchBeacon.open_message(service.room_code, service.model.human_count()), Callable())


func _publish_closed() -> void:
	if service.room_code != "":
		service.broker.publish(MatchBeacon.QUEUE_TOPIC, MatchBeacon.closed_message(service.room_code), Callable())


## 동시에 방을 판 다른 사람이 있으면 코드가 큰 쪽이 작은 쪽으로 옮긴다.
func _check_merge() -> void:
	if _busy or service.model.human_count() > 1:
		return
	_busy = true
	var serial: int = _serial
	service.broker.fetch_many([MatchBeacon.QUEUE_TOPIC], MatchBeacon.FRESH_SECONDS, func(ok: bool, by_topic: Dictionary) -> void:
		_busy = false
		if serial != _serial or state != State.HOSTING or not ok:
			return
		var other: Dictionary = MatchBeacon.pick_room(by_topic.get(MatchBeacon.QUEUE_TOPIC, []), service.room_code)
		if MatchBeacon.should_yield_to(service.room_code, service.model.human_count(), other) and not _candidates_tried.has(other["code"]):
			_publish_closed()
			service.leave()
			_set_state(State.SEARCHING)
			_join(str(other["code"])))


## 대기가 끝났다: 열린 자리를 AI 봇으로 채우고 시작 신호를 보낸다.
func _begin_start() -> void:
	_set_state(State.STARTING)
	_publish_closed()
	service.fill_with_bots()
	start_requested.emit()
