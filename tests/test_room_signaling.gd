# File: res://tests/test_room_signaling.gd
# Class: class_name TestRoomSignaling
# Role: 5자리 방 코드 자동 시그널링 검증 - RoomCode(생성/정규화/토픽/포장), MemoryBroker를 낀 RoomSignaling의 방장-참가자 교환·선점·닫힘 처리, ntfy 응답 해석
class_name TestRoomSignaling
extends TestCase

const OFFER: String = "TRG1-offer-sample"


func _offer_code() -> String:
	return LobbyCode.encode(LobbyCode.KIND_OFFER, 2, "v=0\r\ns=x\r\n", [])


func _find(guest: RoomSignaling) -> Dictionary:
	var holder: Dictionary = {}
	guest.find_offers(func(found: Dictionary) -> void: holder.merge(found))
	return holder


func _pair(code: String) -> Array:
	MemoryBroker.reset_all()
	var broker := MemoryBroker.new()
	defer_free(broker)
	return [RoomSignaling.new(broker, code), RoomSignaling.new(broker, code), broker]


func test_generated_codes_are_five_unambiguous_characters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i: int in range(200):
		var code: String = RoomCode.generate(rng)
		check(RoomCode.is_valid(code), "생성한 코드는 유효: %s" % code)
		check(code.length() == 5 and code.find("0") == -1 and code.find("O") == -1 and code.find("1") == -1 and code.find("I") == -1 and code.find("L") == -1, "헷갈리는 글자 없음: %s" % code)


func test_normalize_and_validate_user_input() -> void:
	check_eq(RoomCode.normalize("  7k9m2 \n"), "7K9M2", "소문자·공백 보정")
	check_eq(RoomCode.normalize("7K9-M2"), "7K9M2", "하이픈 제거")
	check(RoomCode.is_valid("7K9M2"), "정상 코드")
	for bad: String in ["", "7K9M", "7K9M23", "7K9M0", "7K9MI", "7k9m2", "7K 9M"]:
		check(not RoomCode.is_valid(bad), "잘못된 코드 거부: '%s'" % bad)


func test_topics_are_separate_per_seat_and_direction() -> void:
	check_eq(RoomCode.offer_topic("7K9M2", 3), "trg_sig_7K9M2_o3", "초대 토픽")
	check_eq(RoomCode.answer_topic("7K9M2", 3), "trg_sig_7K9M2_a3", "응답 토픽")
	check(RoomCode.offer_topic("7K9M2", 2) != RoomCode.offer_topic("7K9M2", 3), "좌석별로 다른 토픽")
	check(RoomCode.offer_topic("7K9M2", 2) != RoomCode.offer_topic("AAAAA", 2), "방별로 다른 토픽")


func test_wrap_unwrap_round_trip() -> void:
	var wrapped: String = RoomCode.wrap("ABC234", "TRG1-xyz")
	var parts: Dictionary = RoomCode.unwrap(wrapped)
	check_eq(parts["nonce"], "ABC234", "표식")
	check_eq(parts["body"], "TRG1-xyz", "본문")
	check_eq(RoomCode.unwrap("no-newline")["nonce"], "", "형식이 아니면 표식 없음")


func test_guest_finds_open_seats_from_host_offers() -> void:
	var pair: Array = _pair("7K9M2")
	var host: RoomSignaling = pair[0]
	var guest: RoomSignaling = pair[1]
	var offer: String = _offer_code()
	host.post_offer(2, "AAAAAA", offer, Callable())
	host.post_offer(4, "CCCCCC", offer, Callable())
	var result: Dictionary = _find(guest)
	check(bool(result["ok"]) and bool(result["saw_room"]), "릴레이에 닿고 방 흔적을 본다")
	var seats: Array = []
	for candidate: Dictionary in result["candidates"]:
		seats.append(candidate["seat"])
	check_eq(seats, [2, 4], "초대가 올라온 좌석만 후보 (오름차순)")
	check_eq(result["candidates"][0]["nonce"], "AAAAAA", "표식 전달")
	check_eq(result["candidates"][0]["offer"], offer, "초대 코드 전달")


func test_unknown_room_has_no_candidates_and_no_trace() -> void:
	var pair: Array = _pair("7K9M2")
	var result: Dictionary = _find(pair[1])
	check(bool(result["ok"]) and not bool(result["saw_room"]) and (result["candidates"] as Array).is_empty(), "없는 방: 후보도 흔적도 없음")


func test_closed_and_taken_seats_are_skipped() -> void:
	var pair: Array = _pair("7K9M2")
	var host: RoomSignaling = pair[0]
	var guest: RoomSignaling = pair[1]
	var offer: String = _offer_code()
	host.post_offer(2, "AAAAAA", offer, Callable())
	host.close_offer(2)                                   # 봇으로 채워 닫힘
	host.post_offer(3, "BBBBBB", offer, Callable())
	guest.post_answer(3, "BBBBBB", "TRG1-someone", Callable())  # 이미 누가 응답함
	host.post_offer(4, "CCCCCC", offer, Callable())
	var result: Dictionary = _find(guest)
	check(bool(result["saw_room"]), "닫힌 자리도 방 흔적으로는 센다")
	check_eq((result["candidates"] as Array).size(), 1, "닫힌 자리·선점된 자리는 건너뜀")
	check_eq(result["candidates"][0]["seat"], 4, "남은 자리는 4번")


func test_reopened_seat_uses_newest_offer() -> void:
	var pair: Array = _pair("7K9M2")
	var host: RoomSignaling = pair[0]
	var guest: RoomSignaling = pair[1]
	host.post_offer(2, "AAAAAA", _offer_code(), Callable())
	guest.post_answer(2, "AAAAAA", "TRG1-first-guest", Callable())  # 옛 초대는 이미 쓰임
	host.post_offer(2, "ZZZZZZ", _offer_code(), Callable())          # 방장이 새 초대를 올림
	var result: Dictionary = _find(guest)
	check_eq((result["candidates"] as Array).size(), 1, "새 초대는 옛 응답과 상관없이 입장 가능")
	check_eq(result["candidates"][0]["nonce"], "ZZZZZZ", "가장 새 초대의 표식")


func test_host_collects_only_matching_new_answers() -> void:
	var pair: Array = _pair("7K9M2")
	var host: RoomSignaling = pair[0]
	var guest: RoomSignaling = pair[1]
	host.post_offer(2, "AAAAAA", _offer_code(), Callable())
	guest.post_answer(2, "OLDOLD", "TRG1-stale", Callable())   # 옛 초대에 대한 응답
	guest.post_answer(2, "AAAAAA", "TRG1-real", Callable())
	var first: Dictionary = {}
	host.collect_answers({2: {"nonce": "AAAAAA", "seen": 0}, 3: {"nonce": "BBBBBB", "seen": 0}}, func(ok: bool, found: Dictionary) -> void: first.merge({"ok": ok, "found": found}))
	check(bool(first["ok"]), "수거 성공")
	check_eq(first["found"][2]["bodies"], ["TRG1-real"], "표식이 맞는 응답만")
	check_eq(first["found"][2]["total"], 2, "읽은 개수")
	check((first["found"][3]["bodies"] as Array).is_empty(), "응답이 없는 좌석은 비어 있다")
	var again: Dictionary = {"found": {}}
	host.collect_answers({2: {"nonce": "AAAAAA", "seen": 2}}, func(_ok: bool, found: Dictionary) -> void: again["found"] = found)
	check((again["found"][2]["bodies"] as Array).is_empty(), "이미 읽은 응답은 다시 주지 않는다")


func test_only_first_answer_wins_the_seat() -> void:
	var pair: Array = _pair("7K9M2")
	var first: RoomSignaling = pair[0]
	var second: RoomSignaling = pair[1]
	first.post_offer(2, "AAAAAA", _offer_code(), Callable())
	first.post_answer(2, "AAAAAA", "TRG1-guest-one", Callable())
	second.post_answer(2, "AAAAAA", "TRG1-guest-two", Callable())
	var won: Dictionary = {"one": false, "two": true}
	first.claim_won(2, "AAAAAA", "TRG1-guest-one", func(value: bool) -> void: won["one"] = value)
	second.claim_won(2, "AAAAAA", "TRG1-guest-two", func(value: bool) -> void: won["two"] = value)
	check(bool(won["one"]) and not bool(won["two"]), "먼저 올린 한 명만 자리를 얻는다")


func test_offline_relay_is_reported_not_silently_empty() -> void:
	var pair: Array = _pair("7K9M2")
	(pair[2] as MemoryBroker).offline = true
	var result: Dictionary = _find(pair[1])
	check(not bool(result["ok"]), "릴레이에 못 닿으면 ok=false")
	var published: Array = [true]
	(pair[0] as RoomSignaling).post_offer(2, "AAAAAA", _offer_code(), func(ok: bool) -> void: published[0] = ok)
	check(not bool(published[0]), "게시 실패를 알린다")


func test_oversized_message_is_refused() -> void:
	var pair: Array = _pair("7K9M2")
	var published: Array = [true]
	(pair[0] as RoomSignaling).post_offer(2, "AAAAAA", "T".repeat(SignalBroker.MAX_MESSAGE_LENGTH), func(ok: bool) -> void: published[0] = ok)
	check(not bool(published[0]), "첨부파일로 바뀔 만큼 긴 메시지는 올리지 않는다")


func test_ntfy_poll_body_parsing() -> void:
	var body: String = '{"id":"a","time":1,"event":"open","topic":"t"}\n{"id":"b","time":2,"event":"message","topic":"t","message":"AAAAAA\\nTRG1-x"}\n\n{"id":"c","time":3,"event":"keepalive","topic":"t"}\n{"id":"d","time":4,"event":"message","topic":"t","message":"second"}\n'
	var messages: Array = NtfyBroker.parse_poll_body(body)
	check_eq(messages, ["AAAAAA\nTRG1-x", "second"], "message 이벤트만 시간순으로, 줄바꿈 복원")
	check(NtfyBroker.parse_poll_body("").is_empty(), "빈 응답")
	check(NtfyBroker.parse_poll_body("not json").is_empty(), "깨진 응답은 무시")
