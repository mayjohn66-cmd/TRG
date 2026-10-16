# File: res://core_engine/room_code.gd
# Class: class_name RoomCode
# Role: 5자리 방 코드(영문 대문자+숫자)의 생성/정규화/검증과, 공개 릴레이에서 쓰는 시그널링 토픽 이름·메시지 포장 규칙. WebRTC 초대/응답 코드는 이 코드 밑에 숨겨 자동으로 주고받는다
class_name RoomCode
extends RefCounted

## 헷갈리는 글자(0 O 1 I L)는 뺀 31자.
const ALPHABET: String = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const LENGTH: int = 5
const TOPIC_PREFIX: String = "trg_sig_"
## 방장이 자리를 닫았을 때(봇으로 채움·초대 취소) 초대 토픽에 남기는 표식.
const CLOSED_MARK: String = "CLOSED"


static func generate(rng: RandomNumberGenerator) -> String:
	var text: String = ""
	for _i: int in range(LENGTH):
		text += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return text


## 사용자가 친 글자를 코드 형태로 다듬는다 (공백·하이픈 제거, 대문자화, 헷갈리는 글자 보정: O->0 은 없으므로 그대로 둔다).
static func normalize(text: String) -> String:
	return text.strip_edges().to_upper().replace(" ", "").replace("-", "").replace("\n", "").replace("\r", "")


static func is_valid(code: String) -> bool:
	if code.length() != LENGTH:
		return false
	for i: int in range(code.length()):
		if ALPHABET.find(code[i]) == -1:
			return false
	return true


## 방장이 좌석 seat의 초대를 올리는 토픽.
static func offer_topic(code: String, seat: int) -> String:
	return "%s%s_o%d" % [TOPIC_PREFIX, code, seat]


## 참가자가 좌석 seat의 응답을 올리는 토픽.
static func answer_topic(code: String, seat: int) -> String:
	return "%s%s_a%d" % [TOPIC_PREFIX, code, seat]


static func new_nonce(rng: RandomNumberGenerator) -> String:
	var text: String = ""
	for _i: int in range(6):
		text += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return text


## "표식\n본문" 형태로 포장한다. 표식(nonce)은 같은 좌석의 옛 초대/응답과 새것을 구분한다.
static func wrap(nonce: String, body: String) -> String:
	return "%s\n%s" % [nonce, body]


## 포장을 푼다. 반환: {"nonce": String, "body": String}. 형식이 아니면 nonce가 빈 문자열.
static func unwrap(message: String) -> Dictionary:
	var index: int = message.find("\n")
	if index <= 0:
		return {"nonce": "", "body": message}
	return {"nonce": message.substr(0, index), "body": message.substr(index + 1)}
