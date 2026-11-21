# File: res://core_engine/signal_broker.gd
# Class: class_name SignalBroker
# Role: 시그널링 메시지를 공개 릴레이(주제 단위 게시/조회)로 주고받는 추상 계층. publish로 올리고 fetch로 해당 주제의 메시지를 올라온 순서대로 가져온다. 구현체: NtfyBroker(실서비스), MemoryBroker(테스트)
class_name SignalBroker
extends Node

## 게시 한 건의 최대 길이. 이보다 길면 릴레이가 첨부파일로 바꿔 버리므로 올리지 않고 실패로 알린다.
const MAX_MESSAGE_LENGTH: int = 3900


## 주제 topic에 text를 올린다. done(ok: bool) 호출.
func publish(_topic: String, _text: String, done: Callable) -> void:
	if done.is_valid():
		done.call(false)


## 주제 topic의 메시지를 오래된 것부터 모두 가져온다. done(ok: bool, messages: Array) 호출 (messages는 String들).
func fetch(_topic: String, done: Callable) -> void:
	if done.is_valid():
		done.call(false, [])


## 여러 주제를 요청 한 번으로 가져온다 (공개 릴레이는 요청 횟수 제한이 있어 묶어서 읽는다). since_seconds > 0이면 그 시간 안에 올라온 메시지만.
## done(ok: bool, by_topic: Dictionary) - 주제 이름 -> 메시지 배열(오래된 것부터).
func fetch_many(topics: Array, since_seconds: int, done: Callable) -> void:
	var result: Dictionary = {}
	for topic: Variant in topics:
		result[str(topic)] = []
	if done.is_valid():
		done.call(false, result)
