# File: res://tests/fake_rtc_connection.gd
# Class: class_name FakeRtcConnection
# Role: 테스트용 가짜 WebRTC 연결. WebRTCPeerConnection과 같은 이름의 메서드·신호를 가지며 SDP/후보를 정해 둔 값으로 만들어 준다 (헤드리스에는 실제 WebRTC가 없다)
class_name FakeRtcConnection
extends RefCounted

signal session_description_created(type: String, sdp: String)
signal ice_candidate_created(media: String, index: int, name: String)

var initialized: bool = false
var local: Array = []
var remote: Array = []
var added_candidates: Array = []
var candidate_names: Array[String] = ["candidate:1 1 UDP 2122252543 192.168.0.5 50000 typ host", "candidate:2 1 UDP 1686052607 1.2.3.4 50001 typ srflx"]
var initialize_result: int = OK
var tag: String = "fake"


func initialize(_config: Dictionary = {}) -> int:
	initialized = initialize_result == OK
	return initialize_result


func create_offer() -> int:
	session_description_created.emit("offer", "v=0\r\ns=%s-offer\r\n" % tag)
	return OK


func set_local_description(type: String, sdp: String) -> int:
	local = [type, sdp]
	for index: int in candidate_names.size():
		ice_candidate_created.emit("0", index, candidate_names[index])
	return OK


func set_remote_description(type: String, sdp: String) -> int:
	remote = [type, sdp]
	if type == "offer":
		session_description_created.emit("answer", "v=0\r\ns=%s-answer\r\n" % tag)
	return OK


func add_ice_candidate(media: String, index: int, name: String) -> int:
	added_candidates.append([media, index, name])
	return OK


func close() -> void:
	initialized = false
