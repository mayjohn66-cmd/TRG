# File: res://core_engine/room_signaling.gd
# Class: class_name RoomSignaling
# Role: 방 코드 하나에 대한 자동 시그널링 규칙. 방장은 좌석별 초대 코드(offer)를 릴레이에 올리고 참가자의 응답(answer)을 수거하며, 참가자는 방 코드로 열린 초대를 찾아 응답을 올리고 선점 여부를 확인한다. 전송은 SignalBroker가, 화면과 WebRTC는 LobbyService가 맡는다
class_name RoomSignaling
extends RefCounted

var broker: SignalBroker = null
var code: String = ""


func _init(new_broker: SignalBroker = null, room_code: String = "") -> void:
	broker = new_broker
	code = room_code


# ---------------------------------------------------------------------------
# 방장
# ---------------------------------------------------------------------------

## 좌석 seat의 초대 코드를 올린다. done(ok: bool).
func post_offer(seat: int, nonce: String, offer_code: String, done: Callable) -> void:
	broker.publish(RoomCode.offer_topic(code, seat), RoomCode.wrap(nonce, offer_code), done)


## 좌석 seat의 초대를 닫는다 (봇으로 채움·초대 취소). 참가자는 마지막 메시지가 닫힘 표식이면 건너뛴다.
func close_offer(seat: int) -> void:
	broker.publish(RoomCode.offer_topic(code, seat), RoomCode.wrap(RoomCode.CLOSED_MARK, RoomCode.CLOSED_MARK), Callable())


## 좌석 seat의 응답함에서 seen번째 이후 새 메시지 중 nonce가 맞는 응답 코드들을 가져온다. done(ok: bool, bodies: Array, total: int).
func collect_answers(seat: int, nonce: String, seen: int, done: Callable) -> void:
	broker.fetch(RoomCode.answer_topic(code, seat), func(ok: bool, messages: Array) -> void:
		var bodies: Array = []
		if ok:
			for index: int in range(seen, messages.size()):
				var parts: Dictionary = RoomCode.unwrap(str(messages[index]))
				if str(parts["nonce"]) == nonce:
					bodies.append(str(parts["body"]))
		if done.is_valid():
			done.call(ok, bodies, messages.size() if ok else seen))


# ---------------------------------------------------------------------------
# 참가자
# ---------------------------------------------------------------------------

## 이 방의 입장 가능한 좌석을 찾는다. done(result): {"ok": 릴레이에 닿았는가, "saw_room": 방 흔적이 있는가, "candidates": [{"seat", "nonce", "offer"}] (좌석 오름차순)}.
func find_offers(done: Callable) -> void:
	var state: Dictionary = {"pending": LobbyModel.SEAT_COUNT - 1, "any_ok": false, "saw_room": false, "found": {}}
	for seat: int in range(2, LobbyModel.SEAT_COUNT + 1):
		_probe_seat(seat, state, done)


func _probe_seat(seat: int, state: Dictionary, done: Callable) -> void:
	broker.fetch(RoomCode.offer_topic(code, seat), func(ok: bool, messages: Array) -> void:
		if not ok or messages.is_empty():
			_seat_probed(state, ok, false, done)
			return
		var parts: Dictionary = RoomCode.unwrap(str(messages.back()))
		var nonce: String = str(parts["nonce"])
		var offer: String = str(parts["body"])
		if nonce == "" or nonce == RoomCode.CLOSED_MARK or not offer.begins_with(LobbyCode.PREFIX):
			_seat_probed(state, true, true, done)
			return
		# 이미 누가 응답을 올린 초대는 선점된 것으로 본다.
		broker.fetch(RoomCode.answer_topic(code, seat), func(answer_ok: bool, answers: Array) -> void:
			if answer_ok:
				var taken: bool = false
				for entry: Variant in answers:
					if str(RoomCode.unwrap(str(entry))["nonce"]) == nonce:
						taken = true
						break
				if not taken:
					(state["found"] as Dictionary)[seat] = {"seat": seat, "nonce": nonce, "offer": offer}
			_seat_probed(state, true, true, done)))


func _seat_probed(state: Dictionary, ok: bool, saw: bool, done: Callable) -> void:
	state["any_ok"] = bool(state["any_ok"]) or ok
	state["saw_room"] = bool(state["saw_room"]) or saw
	state["pending"] = int(state["pending"]) - 1
	if int(state["pending"]) > 0 or not done.is_valid():
		return
	var found: Dictionary = state["found"]
	var seats: Array = found.keys()
	seats.sort()
	var candidates: Array = []
	for seat: Variant in seats:
		candidates.append(found[seat])
	done.call({"ok": state["any_ok"], "saw_room": state["saw_room"], "candidates": candidates})


## 응답 코드를 올린다. done(ok: bool).
func post_answer(seat: int, nonce: String, answer_code: String, done: Callable) -> void:
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
		if done.is_valid():
			done.call(won))
