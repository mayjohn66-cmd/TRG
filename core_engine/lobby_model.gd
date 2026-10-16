# File: res://core_engine/lobby_model.gd
# Class: class_name LobbyModel
# Role: 멀티플레이 방의 좌석 4개(열림/초대 중/사람/봇) 상태와 전이 규칙. 네트워크와 화면을 모르는 순수 모델이라 단위 테스트할 수 있고, 방장이 정한 상태를 배열로 직렬화해 참가자에게 동기화한다
class_name LobbyModel
extends RefCounted

signal changed

enum SeatState { OPEN, INVITED, HUMAN, BOT }

const SEAT_COUNT: int = 4
const HOST_SEAT: int = 1

## 인덱스 0..3 = 좌석 1..4. 각 항목: {"state": SeatState, "name": String}
var seats: Array[Dictionary] = []


func _init() -> void:
	reset()


func reset() -> void:
	seats.clear()
	for seat: int in SEAT_COUNT:
		seats.append({"state": SeatState.OPEN, "name": ""})
	changed.emit()


func setup_host(nickname: String) -> void:
	reset()
	seats[0] = {"state": SeatState.HUMAN, "name": nickname}
	changed.emit()


func state_of(seat: int) -> SeatState:
	return seats[seat - 1]["state"]


func name_of(seat: int) -> String:
	return str(seats[seat - 1]["name"])


func _valid_guest_seat(seat: int) -> bool:
	return seat > HOST_SEAT and seat <= SEAT_COUNT


## 열린 좌석에 초대 코드를 만든다 (OPEN -> INVITED).
func invite(seat: int) -> bool:
	if not _valid_guest_seat(seat) or state_of(seat) != SeatState.OPEN:
		return false
	seats[seat - 1] = {"state": SeatState.INVITED, "name": ""}
	changed.emit()
	return true


## 초대를 취소한다 (INVITED -> OPEN).
func cancel_invite(seat: int) -> bool:
	if not _valid_guest_seat(seat) or state_of(seat) != SeatState.INVITED:
		return false
	seats[seat - 1] = {"state": SeatState.OPEN, "name": ""}
	changed.emit()
	return true


## 참가자가 들어왔다 (INVITED 또는 OPEN -> HUMAN).
func guest_joined(seat: int, nickname: String) -> bool:
	if not _valid_guest_seat(seat):
		return false
	var current: SeatState = state_of(seat)
	if current != SeatState.INVITED and current != SeatState.OPEN:
		return false
	seats[seat - 1] = {"state": SeatState.HUMAN, "name": nickname}
	changed.emit()
	return true


## 참가자 이름 갱신 (이미 들어온 사람만).
func rename_guest(seat: int, nickname: String) -> void:
	if _valid_guest_seat(seat) and state_of(seat) == SeatState.HUMAN:
		seats[seat - 1]["name"] = nickname
		changed.emit()


## 참가자가 나갔다 / 내보냈다 (HUMAN -> OPEN).
func guest_left(seat: int) -> bool:
	if not _valid_guest_seat(seat) or state_of(seat) != SeatState.HUMAN:
		return false
	seats[seat - 1] = {"state": SeatState.OPEN, "name": ""}
	changed.emit()
	return true


## 좌석을 컴퓨터(봇)로 채우거나 비운다.
func set_bot(seat: int, enabled: bool) -> bool:
	if not _valid_guest_seat(seat):
		return false
	var current: SeatState = state_of(seat)
	if enabled and current == SeatState.OPEN:
		seats[seat - 1] = {"state": SeatState.BOT, "name": "컴퓨터 %d" % seat}
	elif not enabled and current == SeatState.BOT:
		seats[seat - 1] = {"state": SeatState.OPEN, "name": ""}
	else:
		return false
	changed.emit()
	return true


func fill_open_with_bots() -> void:
	for seat: int in range(2, SEAT_COUNT + 1):
		if state_of(seat) == SeatState.OPEN:
			set_bot(seat, true)


func human_count() -> int:
	var count: int = 0
	for entry: Dictionary in seats:
		if entry["state"] == SeatState.HUMAN:
			count += 1
	return count


func has_pending_invite() -> bool:
	for entry: Dictionary in seats:
		if entry["state"] == SeatState.INVITED:
			return true
	return false


## 시작할 수 있는가: 초대 중인 좌석이 없어야 한다 (열린 좌석은 시작할 때 봇으로 채운다). 사람이 방장 혼자여도 봇과 시작할 수 있다.
func can_start() -> bool:
	return not has_pending_invite()


## 첫 번째 열린 참가자 좌석 (2~4). 없으면 -1.
func first_open_seat() -> int:
	for seat: int in range(2, SEAT_COUNT + 1):
		if state_of(seat) == SeatState.OPEN:
			return seat
	return -1


func to_array() -> Array:
	var result: Array = []
	for entry: Dictionary in seats:
		result.append([int(entry["state"]), str(entry["name"])])
	return result


## 방장이 보낸 배열로 덮어쓴다 (참가자 쪽). 형식이 틀리면 false.
func from_array(data: Array) -> bool:
	if data.size() != SEAT_COUNT:
		return false
	var parsed: Array[Dictionary] = []
	for entry: Variant in data:
		if not (entry is Array) or (entry as Array).size() != 2:
			return false
		var state_value: int = int((entry as Array)[0])
		if state_value < 0 or state_value > SeatState.BOT:
			return false
		parsed.append({"state": state_value, "name": str((entry as Array)[1]).substr(0, GameSession.MAX_NICKNAME_LENGTH + 4)})
	seats = parsed
	changed.emit()
	return true
