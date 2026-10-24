# File: res://core_engine/net_trace.gd
# Class: class_name NetTrace
# Role: 멀티플레이 접속 단계(시그널링·ICE·릴레이 송수신·선점·연결 상태)를 콘솔에 남기는 추적 로그. 웹 빌드에서는 브라우저 개발자 도구 콘솔에 "[NET +초] 단계: 내용"으로 찍힌다
class_name NetTrace
extends RefCounted

## false면 아무것도 찍지 않는다.
static var enabled: bool = true
## 테스트 확인용: 최근 로그 몇 줄을 보관한다.
static var recent: Array[String] = []
const KEEP_LINES: int = 200


static func step(stage: String, detail: String = "") -> void:
	if not enabled:
		return
	var line: String = "[NET +%.3fs] %s%s" % [Time.get_ticks_msec() / 1000.0, stage, (": " + detail) if detail != "" else ""]
	recent.append(line)
	if recent.size() > KEEP_LINES:
		recent.remove_at(0)
	print(line)


## 로그에 이 단계가 찍혔는가 (테스트용).
static func saw(stage: String) -> bool:
	for line: String in recent:
		if line.contains("] " + stage):
			return true
	return false


## ICE 후보 문자열에서 종류(host/srflx/relay/prflx)를 뽑는다.
static func candidate_type(candidate: String) -> String:
	var parts: PackedStringArray = candidate.split(" ", false)
	var index: int = parts.find("typ")
	return parts[index + 1] if index != -1 and index + 1 < parts.size() else "?"
