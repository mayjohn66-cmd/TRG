# File: res://core_engine/lobby_code.gd
# Class: class_name LobbyCode
# Role: WebRTC 연결 정보(SDP + ICE 후보)를 사람이 복사해 주고받을 수 있는 짧은 초대/응답 코드로 바꾸고 되돌린다. 시그널링 서버 없이 직접 연결하기 위한 수동 시그널링 형식
class_name LobbyCode
extends RefCounted

const PREFIX: String = "TRG1-"
const KIND_OFFER: String = "offer"
const KIND_ANSWER: String = "answer"
const MAX_DECODED_BYTES: int = 65536


## 코드를 만든다. kind: KIND_OFFER(방장 -> 참가자) / KIND_ANSWER(참가자 -> 방장), peer_id: 이 연결에서 참가자가 쓸 피어 ID(= 좌석 번호),
## candidates: 문자열 ICE 후보들 ({"media": String, "index": int, "name": String}).
static func encode(kind: String, peer_id: int, sdp: String, candidates: Array) -> String:
	var payload: Dictionary = {"k": kind, "p": peer_id, "s": sdp, "c": candidates}
	var raw: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var framed := PackedByteArray()
	framed.resize(4)
	framed.encode_u32(0, raw.size())
	framed.append_array(packed)
	var text: String = Marshalls.raw_to_base64(framed)
	return PREFIX + text.replace("+", "-").replace("/", "_").replace("=", "")


## 코드를 읽는다. 반환: {"ok": bool, "error": String, "kind": String, "peer_id": int, "sdp": String, "candidates": Array}
static func decode(text: String) -> Dictionary:
	var cleaned: String = text.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "").replace("\t", "")
	if not cleaned.begins_with(PREFIX):
		return _fail("올바른 코드가 아닙니다. 복사한 코드 전체를 붙여 넣어 주세요.")
	var body: String = cleaned.substr(PREFIX.length()).replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	var framed: PackedByteArray = Marshalls.base64_to_raw(body)
	if framed.size() <= 4:
		return _fail("코드가 너무 짧습니다. 끝까지 복사했는지 확인해 주세요.")
	var raw_size: int = framed.decode_u32(0)
	if raw_size <= 0 or raw_size > MAX_DECODED_BYTES:
		return _fail("코드가 손상되었습니다.")
	var raw: PackedByteArray = framed.slice(4).decompress(raw_size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != raw_size:
		return _fail("코드가 손상되었습니다. 다시 복사해 주세요.")
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return _fail("코드를 읽을 수 없습니다.")
	var data: Dictionary = parsed
	var kind: String = str(data.get("k", ""))
	if kind != KIND_OFFER and kind != KIND_ANSWER:
		return _fail("코드 종류를 알 수 없습니다.")
	var peer_id: int = int(data.get("p", 0))
	if peer_id < 1 or peer_id > 4:
		return _fail("코드의 좌석 번호가 올바르지 않습니다.")
	var sdp: String = str(data.get("s", ""))
	if not sdp.begins_with("v=0"):
		return _fail("연결 정보가 올바르지 않습니다.")
	var candidates: Array = []
	var raw_candidates: Variant = data.get("c", [])
	if raw_candidates is Array:
		for entry: Variant in raw_candidates:
			if entry is Dictionary and (entry as Dictionary).has("name"):
				candidates.append({"media": str((entry as Dictionary).get("media", "0")), "index": int((entry as Dictionary).get("index", 0)), "name": str((entry as Dictionary)["name"])})
	return {"ok": true, "error": "", "kind": kind, "peer_id": peer_id, "sdp": sdp, "candidates": candidates}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "kind": "", "peer_id": 0, "sdp": "", "candidates": []}
