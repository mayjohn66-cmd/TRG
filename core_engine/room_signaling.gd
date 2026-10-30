# File: res://core_engine/room_signaling.gd
# Class: class_name RoomSignaling
# Role: 방 코드 하나에 대한 자동 시그널링 규칙. 방장은 좌석별 초대 코드(offer)를 릴레이에 올리고 참가자의 응답(answer)을 수거하며, 참가자는 방 코드로 열린 초대를 찾아 응답을 올리고 선점 여부를 확인한다. 전송은 SignalBroker가, 화면과 WebRTC는 LobbyService가 맡는다
class_name RoomSignaling
extends RefCounted

var broker: SignalBroker = null
var code: String = ""


func _init(new_broker: SignalBroker = null, room_code: String = "") -> void:
	broker = new_broker
	# 방장·참가자가 언제나 같은 토픽을 쓰도록 대문자·공백 제거로 맞춘다.
	code = RoomCode.normalize(room_code)


# ---------------------------------------------------------------------------
# 방장
# ---------------------------------------------------------------------------

## 좌석 seat의 초대 코드를 올린다. done(ok: bool).
func post_offer(seat: int, nonce: String, offer_code: String, done: Callable) -> void:
	NetTrace.step("signal.post_offer", "topic=%s nonce=%s len=%d" % [RoomCode.offer_topic(code, seat), nonce, offer_code.length()])
	broker.publish(RoomCode.offer_topic(code, seat), RoomCode.wrap(nonce, offer_code), done)


## 좌석 seat의 초대를 닫는다 (봇으로 채움·초대 취소). 참가자는 마지막 메시지가 닫힘 표식이면 건너뛴다.
func close_offer(seat: int) -> void:
	broker.publish(RoomCode.offer_topic(code, seat), RoomCode.wrap(RoomCode.CLOSED_MARK, RoomCode.CLOSED_MARK), Callable())


## 여러 좌석의 응답함을 요청 한 번으로 읽는다. watch: 좌석 -> {"nonce": 지금 올린 초대의 표식, "seen": 이미 읽은 개수}.
## done(ok: bool, found: Dictionary) - 좌석 -> {"bodies": 표식이 맞는 새 응답 코드들, "total": 읽은 개수}.
func collect_answers(watch: Dictionary, done: Callable) -> void:
	var topics: Array = []
	for seat: Variant in watch.keys():
		topics.append(RoomCode.answer_topic(code, int(seat)))
	broker.fetch_many(topics, 0, func(ok: bool, by_topic: Dictionary) -> void:
		var found: Dictionary = {}
		for seat: Variant in watch.keys():
			var entry: Dictionary = watch[seat]
			var messages: Array = by_topic.get(RoomCode.answer_topic(code, int(seat)), [])
			var bodies: Array = []
			if ok:
				for index: int in range(int(entry["seen"]), messages.size()):
					var parts: Dictionary = RoomCode.unwrap(str(messages[index]))
					if str(parts["nonce"]) == str(entry["nonce"]):
						bodies.append(str(parts["body"]))
			found[int(seat)] = {"bodies": bodies, "total": messages.size() if ok else int(entry["seen"])}
		if done.is_valid():
			done.call(ok, found))


# ---------------------------------------------------------------------------
# 참가자
# ---------------------------------------------------------------------------

## 이 방의 입장 가능한 좌석을 찾는다 (요청 2번: 초대함 한 번, 응답함 한 번). done(result): {"ok": 릴레이에 닿았는가, "saw_room": 방 흔적이 있는가, "candidates": [{"seat", "nonce", "offer"}] (좌석 오름차순)}.
func find_offers(done: Callable) -> void:
	var offer_topics: Array = []
	for seat: int in range(2, LobbyModel.SEAT_COUNT + 1):
		offer_topics.append(RoomCode.offer_topic(code, seat))
	NetTrace.step("signal.find_offers", "room=%s topics=%s" % [code, ",".join(PackedStringArray(offer_topics))])
	broker.fetch_many(offer_topics, 0, func(ok: bool, offers: Dictionary) -> void:
		if not ok:
			NetTrace.step("signal.find_offers.failed", "relay unreachable")
			done.call({"ok": false, "saw_room": false, "candidates": []})
			return
		var saw_room: bool = false
		var open: Dictionary = {}
		for seat: int in range(2, LobbyModel.SEAT_COUNT + 1):
			var messages: Array = offers.get(RoomCode.offer_topic(code, seat), [])
			if messages.is_empty():
				continue
			saw_room = true
			var parts: Dictionary = RoomCode.unwrap(str(messages.back()))
			var nonce: String = str(parts["nonce"])
			var offer: String = str(parts["body"])
			if nonce != "" and nonce != RoomCode.CLOSED_MARK and offer.begins_with(LobbyCode.PREFIX):
				open[seat] = {"seat": seat, "nonce": nonce, "offer": offer}
		NetTrace.step("signal.find_offers.open", "saw_room=%s open_seats=%s" % [saw_room, str(open.keys())])
		if open.is_empty():
			done.call({"ok": true, "saw_room": saw_room, "candidates": []})
			return
		var answer_topics: Array = []
		for seat: Variant in open.keys():
			answer_topics.append(RoomCode.answer_topic(code, int(seat)))
		# 이미 누가 응답을 올린 초대는 선점된 것으로 본다.
		broker.fetch_many(answer_topics, 0, func(answer_ok: bool, answers: Dictionary) -> void:
			var candidates: Array = []
			var seats: Array = open.keys()
			seats.sort()
			for seat: Variant in seats:
				var taken: bool = false
				if answer_ok:
					for entry: Variant in answers.get(RoomCode.answer_topic(code, int(seat)), []):
						if str(RoomCode.unwrap(str(entry))["nonce"]) == str((open[seat] as Dictionary)["nonce"]):
							taken = true
							break
				if not taken:
					candidates.append(open[seat])
				else:
					NetTrace.step("signal.find_offers.taken", "seat=%d" % int(seat))
			done.call({"ok": true, "saw_room": saw_room, "candidates": candidates})))


## 응답 코드를 올린다. done(ok: bool).
func post_answer(seat: int, nonce: String, answer_code: String, done: Callable) -> void:
	NetTrace.step("signal.post_answer", "topic=%s nonce=%s len=%d" % [RoomCode.answer_topic(code, seat), nonce, answer_code.length()])
	broker.publish(RoomCode.answer_topic(code, seat), RoomCode.wrap(nonce, answer_code), done)


## 내 응답이 이 초대의 첫 응답인가 (여러 명이 동시에 같은 자리를 노리면 먼저 올라온 한 명만 이긴다). done(won: bool).
func claim_won(seat: int, nonce: String, answer_code: String, done: Callable) -> void:
	broker.fetch(RoomCode.answer_topic(code, seat), func(ok: bool, messages: Array) -> void:
		var won: bool = false
		if ok:
			for entry: Variant in messages:
				var parts: Dictionary = RoomCode.unwrap(str(entry))
				if str(parts["nonce"]) == nonce:
					won = str(parts["body"]) == answer_code
					break
		NetTrace.step("signal.claim", "seat=%d ok=%s answers=%d won=%s" % [seat, ok, messages.size(), won])
		if done.is_valid():
			done.call(won))
