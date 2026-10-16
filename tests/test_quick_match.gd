# File: res://tests/test_quick_match.gd
# Class: class_name TestQuickMatch
# Role: 빠른 랜덤 매칭 검증 - MatchBeacon(비콘 형식·신선도·방 고르기·합류 양보 규칙)과 QuickMatch(찾기 -> 합류/방장 전환 -> 15초 뒤 AI 채우고 시작, 지금 시작, 취소, 동시 개설 병합). 가짜 릴레이(MemoryBroker)와 오프라인 서비스를 쓴다
class_name TestQuickMatch
extends TestCase


func _beacon(code: String, players: int) -> String:
	return MatchBeacon.open_message(code, players)


# --- MatchBeacon -----------------------------------------------------------

func test_beacon_message_round_trip() -> void:
	var parsed: Dictionary = MatchBeacon.parse(MatchBeacon.open_message("7K9M2", 2))
	check_eq(parsed["type"], "OPEN_ROOM", "종류")
	check_eq(parsed["code"], "7K9M2", "방 코드")
	check_eq(parsed["players"], 2, "현재 인원")
	var raw: Variant = JSON.parse_string(MatchBeacon.open_message("7K9M2", 2))
	check(raw is Dictionary and (raw as Dictionary).has("type") and (raw as Dictionary).has("code") and (raw as Dictionary).has("players"), "명세의 type/code/players 필드")
	check_eq(MatchBeacon.parse(MatchBeacon.closed_message("7K9M2"))["type"], "ROOM_CLOSED", "닫힘 비콘")


func test_beacon_parse_rejects_garbage() -> void:
	for bad: String in ["", "hello", "[]", '{"type":"OPEN_ROOM"}', '{"type":"OPEN_ROOM","code":"bad","players":1}', '{"type":"X","code":"7K9M2"}']:
		check(MatchBeacon.parse(bad).is_empty(), "잘못된 비콘 무시: %s" % bad)
	check_eq(MatchBeacon.parse('{"type":"OPEN_ROOM","code":"7K9M2","players":99}')["players"], 4, "인원은 범위 안으로")


func test_pick_room_prefers_fuller_then_smaller_code_and_skips_unusable() -> void:
	check(MatchBeacon.pick_room([]).is_empty(), "비콘이 없으면 없음")
	check_eq(MatchBeacon.pick_room([_beacon("BBBBB", 1), _beacon("AAAAA", 1)])["code"], "AAAAA", "같은 인원이면 코드가 작은 방")
	check_eq(MatchBeacon.pick_room([_beacon("AAAAA", 1), _beacon("BBBBB", 3)])["code"], "BBBBB", "인원이 많은 방 먼저")
	check(MatchBeacon.pick_room([_beacon("AAAAA", 4)]).is_empty(), "가득 찬 방은 제외")
	check(MatchBeacon.pick_room([_beacon("AAAAA", 1), MatchBeacon.closed_message("AAAAA")]).is_empty(), "나중에 닫힌 방은 제외")
	check_eq(MatchBeacon.pick_room([MatchBeacon.closed_message("AAAAA"), _beacon("AAAAA", 2)])["code"], "AAAAA", "닫힘 뒤에 다시 열린 방은 유효")
	check_eq(MatchBeacon.pick_room([_beacon("AAAAA", 1), _beacon("AAAAA", 3)])["players"], 3, "방마다 마지막 비콘 기준")
	check(MatchBeacon.pick_room([_beacon("AAAAA", 2)], "AAAAA").is_empty(), "내 방은 제외")


func test_yield_rule_moves_only_the_larger_code_and_only_when_alone() -> void:
	var other: Dictionary = MatchBeacon.parse(_beacon("AAAAA", 1))
	check(MatchBeacon.should_yield_to("BBBBB", 1, other), "코드가 큰 쪽이 옮긴다")
	check(not MatchBeacon.should_yield_to("AAAAA", 1, MatchBeacon.parse(_beacon("BBBBB", 1))), "코드가 작은 쪽은 남는다 (서로 옮겨 다니지 않는다)")
	check(not MatchBeacon.should_yield_to("BBBBB", 2, other), "이미 사람이 들어온 방은 옮기지 않는다")
	check(not MatchBeacon.should_yield_to("BBBBB", 1, {}), "합류할 방이 없으면 그대로")


# --- MemoryBroker 신선도 ---------------------------------------------------

func test_fetch_many_filters_by_freshness() -> void:
	MemoryBroker.reset_all()
	var broker := MemoryBroker.new()
	defer_free(broker)
	MemoryBroker.inject("q", "old", 20.0)
	MemoryBroker.inject("q", "fresh", 3.0)
	var got: Dictionary = {}
	broker.fetch_many(["q", "other"], 12, func(_ok: bool, by_topic: Dictionary) -> void: got.merge(by_topic))
	check_eq(got["q"], ["fresh"], "12초보다 오래된 메시지는 빠진다")
	check_eq(got["other"], [], "없는 주제는 빈 배열")


# --- QuickMatch ------------------------------------------------------------

func _make_quick() -> Dictionary:
	MemoryBroker.reset_all()
	var broker := MemoryBroker.new()
	var service := LobbyService.new()
	service.offline_for_test = true
	service.broker = broker
	service.connect_timeout_seconds = 0.2
	tree.root.add_child(service)
	defer_free(service)
	var quick := QuickMatch.new()
	quick.service = service
	quick.auto_tick = false
	service.add_child(quick)
	GameSession.nickname = "테스터"
	return {"service": service, "quick": quick, "broker": broker}


func _queue_messages() -> Array:
	return MemoryBroker.boxes.get(MatchBeacon.QUEUE_TOPIC, [])


func test_no_open_room_makes_me_host_and_beacons_every_three_seconds() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var service: LobbyService = parts["service"]
	quick.start()
	check_eq(quick.state, QuickMatch.State.HOSTING, "열린 방이 없으면 내가 P1(방장)")
	check(service.is_host and RoomCode.is_valid(service.room_code), "5자리 방 코드가 있는 공개 방")
	quick.tick(0.1)
	check_eq(_queue_messages().size(), 1, "곧바로 첫 비콘")
	var beacon: Dictionary = MatchBeacon.parse(str(_queue_messages()[0]))
	check(beacon["type"] == "OPEN_ROOM" and beacon["code"] == service.room_code and beacon["players"] == 1, "비콘: OPEN_ROOM + 내 방 코드 + 인원 1")
	quick.tick(2.0)
	check_eq(_queue_messages().size(), 1, "3초가 되기 전에는 다시 올리지 않는다")
	quick.tick(1.5)
	check_eq(_queue_messages().size(), 2, "3초마다 비콘")


func test_stale_beacon_is_ignored() -> void:
	var parts: Dictionary = _make_quick()
	MemoryBroker.inject(MatchBeacon.QUEUE_TOPIC, _beacon("ABCDE", 2), 20.0)  # 12초보다 오래됨
	(parts["quick"] as QuickMatch).start()
	check_eq((parts["quick"] as QuickMatch).state, QuickMatch.State.HOSTING, "오래된 비콘은 무시하고 내가 방장")


func test_fresh_beacon_triggers_join_attempt_then_falls_back_to_hosting() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var service: LobbyService = parts["service"]
	var progress: Array = []
	service.join_progress.connect(func(message: String) -> void: progress.append(message))
	MemoryBroker.inject(MatchBeacon.QUEUE_TOPIC, _beacon("ABCDE", 2), 2.0)
	# 그 방의 초대가 릴레이에 있다고 가정하지만 이 헤드리스 환경에는 WebRTC가 없어서 합류에 실패한다
	RoomSignaling.new(parts["broker"], "ABCDE").post_offer(2, "AAAAAA", LobbyCode.encode(LobbyCode.KIND_OFFER, 2, "v=0\r\ns=x\r\n", []), Callable())
	quick.start()
	check(progress.has("방을 찾는 중..."), "신선한 비콘의 방 코드로 자동 입장을 시도한다")
	check_eq(quick.state, QuickMatch.State.HOSTING, "합류에 실패하면 같은 방을 다시 시도하지 않고 내가 방장")
	check(service.is_host and service.room_code != "ABCDE", "새 공개 방을 만든다")


func test_timeout_fills_open_seats_with_bots_and_requests_start() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var service: LobbyService = parts["service"]
	var fired: Array = [0]
	quick.start_requested.connect(func() -> void: fired[0] += 1)
	quick.start()
	var code: String = service.room_code
	quick.tick(14.0)
	check_eq(quick.state, QuickMatch.State.HOSTING, "14초까지는 계속 기다린다")
	check_eq(quick.seconds_left(), 1, "남은 시간")
	quick.tick(1.0)
	check_eq(quick.state, QuickMatch.State.STARTING, "15초가 지나면 시작 단계")
	check_eq(fired[0], 1, "시작 신호 한 번")
	for seat: int in range(2, 5):
		check_eq(service.model.state_of(seat), LobbyModel.SeatState.BOT, "빈자리 %d는 AI 봇" % seat)
	check_eq(service.model.state_of(1), LobbyModel.SeatState.HUMAN, "실제 유저는 그대로")
	var last: Dictionary = MatchBeacon.parse(str(_queue_messages().back()))
	check(last["type"] == "ROOM_CLOSED" and last["code"] == code, "시작하면 대기열에 닫힘 비콘")
	quick.tick(5.0)
	check_eq(fired[0], 1, "시작 신호는 한 번만")


func test_start_now_skips_the_countdown() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var fired: Array = [0]
	quick.start_requested.connect(func() -> void: fired[0] += 1)
	quick.start()
	quick.tick(2.0)
	quick.start_now()
	check(quick.state == QuickMatch.State.STARTING and fired[0] == 1, "[지금 바로 시작]은 기다리지 않는다")
	check_eq((parts["service"] as LobbyService).model.state_of(4), LobbyModel.SeatState.BOT, "빈자리를 AI로 채움")


func test_full_room_starts_immediately() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var service: LobbyService = parts["service"]
	quick.start()
	service.model.guest_joined(2, "A")
	service.model.guest_joined(3, "B")
	service.model.guest_joined(4, "C")
	quick.tick(0.1)
	check_eq(quick.state, QuickMatch.State.STARTING, "4명이 차면 기다리지 않고 시작")
	check_eq(service.model.human_count(), 4, "실제 유저 4명 유지")


func test_cancel_closes_beacon_and_leaves() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var service: LobbyService = parts["service"]
	quick.start()
	quick.tick(0.1)
	var code: String = service.room_code
	quick.stop()
	check_eq(quick.state, QuickMatch.State.IDLE, "취소하면 대기 종료")
	check(not service.in_room(), "방에서 나간다")
	var last: Dictionary = MatchBeacon.parse(str(_queue_messages().back()))
	check(last["type"] == "ROOM_CLOSED" and last["code"] == code, "취소하면 닫힘 비콘")
	quick.tick(30.0)
	check_eq(quick.state, QuickMatch.State.IDLE, "취소 뒤에는 시간이 흘러도 시작하지 않는다")


func test_simultaneous_hosts_merge_into_smaller_code() -> void:
	var parts: Dictionary = _make_quick()
	var quick: QuickMatch = parts["quick"]
	var service: LobbyService = parts["service"]
	quick.start()
	quick.tick(0.1)
	var mine: String = service.room_code
	# 나보다 코드가 작은 다른 방이 막 열렸다
	var other: String = "22222"
	check(other < mine or mine == "22222", "테스트 전제: 상대 코드가 더 작다")
	MemoryBroker.inject(MatchBeacon.QUEUE_TOPIC, _beacon(other, 1), 1.0)
	quick.tick(3.1)
	var closed: bool = false
	for text: Variant in _queue_messages():
		var beacon: Dictionary = MatchBeacon.parse(str(text))
		if beacon.get("type", "") == "ROOM_CLOSED" and beacon.get("code", "") == mine:
			closed = true
	check(closed, "합류하러 가는 쪽은 자기 방의 닫힘 비콘을 남긴다")
