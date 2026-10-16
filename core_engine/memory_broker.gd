# File: res://core_engine/memory_broker.gd
# Class: class_name MemoryBroker
# Role: 메모리에 메시지를 쌓는 가짜 릴레이. 같은 프로세스의 방장/참가자 시그널링을 네트워크 없이 검증하는 테스트용이며, offline이 켜지면 모든 요청이 실패한다
class_name MemoryBroker
extends SignalBroker

## 프로세스 전체가 공유하는 주제별 메시지함 (방장과 참가자 인스턴스가 같은 함을 본다).
static var boxes: Dictionary = {}

var offline: bool = false
var published_count: int = 0


static func reset_all() -> void:
	boxes.clear()


func publish(topic: String, text: String, done: Callable) -> void:
	if offline or text.length() > MAX_MESSAGE_LENGTH:
		if done.is_valid():
			done.call(false)
		return
	if not boxes.has(topic):
		boxes[topic] = []
	(boxes[topic] as Array).append(text)
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
