# File: res://core_engine/memory_broker.gd
# Class: class_name MemoryBroker
# Role: 메모리에 메시지를 쌓는 가짜 릴레이. 같은 프로세스의 방장/참가자 시그널링을 네트워크 없이 검증하는 테스트용이며, offline이 켜지면 모든 요청이 실패한다
class_name MemoryBroker
extends SignalBroker

## 프로세스 전체가 공유하는 주제별 메시지함 (방장과 참가자 인스턴스가 같은 함을 본다).
static var boxes: Dictionary = {}
## 주제별 메시지를 올린 시각(ms, Time.get_ticks_msec 기준). boxes와 같은 순서.
static var stamps: Dictionary = {}

var offline: bool = false
var published_count: int = 0


static func reset_all() -> void:
	boxes.clear()
	stamps.clear()


## 이미 age_seconds초 전에 올라온 것처럼 메시지를 심는다 (신선도 검사 테스트용).
static func inject(topic: String, text: String, age_seconds: float) -> void:
	if not boxes.has(topic):
		boxes[topic] = []
		stamps[topic] = []
	(boxes[topic] as Array).append(text)
	(stamps[topic] as Array).append(Time.get_ticks_msec() - int(age_seconds * 1000.0))


func publish(topic: String, text: String, done: Callable) -> void:
	if offline or text.length() > MAX_MESSAGE_LENGTH:
		if done.is_valid():
			done.call(false)
		return
	inject(topic, text, 0.0)
	published_count += 1
	if done.is_valid():
		done.call(true)


func fetch(topic: String, done: Callable) -> void:
	if offline:
		if done.is_valid():
			done.call(false, [])
		return
	if done.is_valid():
		done.call(true, (boxes.get(topic, []) as Array).duplicate())


func fetch_many(topics: Array, since_seconds: int, done: Callable) -> void:
	var result: Dictionary = {}
	for topic: Variant in topics:
		result[str(topic)] = []
	if offline:
		if done.is_valid():
			done.call(false, result)
		return
	var now: int = Time.get_ticks_msec()
	for topic: Variant in topics:
		var messages: Array = boxes.get(str(topic), [])
		var times: Array = stamps.get(str(topic), [])
		for index: int in range(messages.size()):
			if since_seconds <= 0 or now - int(times[index]) <= since_seconds * 1000:
				(result[str(topic)] as Array).append(messages[index])
	if done.is_valid():
		done.call(true, result)
