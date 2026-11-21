# File: res://core_engine/match_beacon.gd
# Class: class_name MatchBeacon
# Role: 빠른 랜덤 매칭의 공용 대기열(trg_matchmaking_queue_v1) 메시지 규칙. 방장은 3초마다 OPEN_ROOM 비콘(방 코드·현재 인원)을 올리고, 매칭을 찾는 사람은 최근 12초 안의 비콘 중 자리가 남은 방을 고른다
class_name MatchBeacon
extends RefCounted

const QUEUE_TOPIC: String = "trg_matchmaking_queue_v1"
const TYPE_OPEN: String = "OPEN_ROOM"
const TYPE_CLOSED: String = "ROOM_CLOSED"
## 비콘 송출 주기 / 이 시간(초)보다 오래된 비콘은 무시한다 / 매칭 대기 시간(초).
const BEACON_SECONDS: float = 3.0
const FRESH_SECONDS: int = 12
const WAIT_SECONDS: float = 15.0


static func open_message(room_code: String, players: int) -> String:
	return JSON.stringify({"type": TYPE_OPEN, "code": room_code, "players": players})


static func closed_message(room_code: String) -> String:
	return JSON.stringify({"type": TYPE_CLOSED, "code": room_code})


## 비콘 하나를 읽는다. 형식이 아니면 빈 Dictionary.
static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	var data: Dictionary = json.data
	var kind: String = str(data.get("type", ""))
	var code: String = str(data.get("code", ""))
	if (kind != TYPE_OPEN and kind != TYPE_CLOSED) or not RoomCode.is_valid(code):
		return {}
	return {"type": kind, "code": code, "players": clampi(int(data.get("players", 1)), 1, LobbyModel.SEAT_COUNT)}


## 최근 비콘들(오래된 것부터)에서 합류할 방을 고른다. 방마다 마지막 비콘만 보고, 닫혔거나 가득 찬(4명) 방, exclude_code(내 방)는 뺀다.
## 인원이 많은 방(빨리 채워야 하므로)을 먼저, 같으면 코드가 작은 방을 고른다. 없으면 빈 Dictionary.
static func pick_room(messages: Array, exclude_code: String = "") -> Dictionary:
	var latest: Dictionary = {}
	for text: Variant in messages:
		var beacon: Dictionary = parse(str(text))
		if not beacon.is_empty():
			latest[beacon["code"]] = beacon
	var best: Dictionary = {}
	for code: Variant in latest.keys():
		var beacon: Dictionary = latest[code]
		if beacon["type"] != TYPE_OPEN or str(code) == exclude_code or int(beacon["players"]) >= LobbyModel.SEAT_COUNT:
			continue
		if best.is_empty() or int(beacon["players"]) > int(best["players"]) or (int(beacon["players"]) == int(best["players"]) and str(code) < str(best["code"])):
			best = beacon
	return best


## 내 방보다 먼저 합류해야 할 방이 있는가 (동시에 방을 판 두 사람이 서로를 놓치지 않도록, 코드가 더 작은 쪽 방으로 코드가 큰 쪽이 옮긴다).
static func should_yield_to(own_code: String, own_players: int, other: Dictionary) -> bool:
	if other.is_empty():
		return false
	if own_players > 1:
		return false
	return str(other["code"]) < own_code
