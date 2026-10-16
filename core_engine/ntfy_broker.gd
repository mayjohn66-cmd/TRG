# File: res://core_engine/ntfy_broker.gd
# Class: class_name NtfyBroker
# Role: ntfy.sh 같은 가입이 필요 없는 공개 Pub-Sub 서버를 HTTPRequest로 쓰는 릴레이. POST {서버}/{주제}로 올리고 GET {서버}/{주제}/json?poll=1&since=all로 쌓인 메시지를 읽는다. 서버 주소는 바꿀 수 있다
class_name NtfyBroker
extends SignalBroker

const DEFAULT_SERVER: String = "https://ntfy.sh"
const TIMEOUT_SECONDS: float = 8.0

var server: String = DEFAULT_SERVER


func publish(topic: String, text: String, done: Callable) -> void:
	if text.length() > MAX_MESSAGE_LENGTH:
		if done.is_valid():
			done.call(false)
		return
	var request := _new_request()
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		request.queue_free()
		if done.is_valid():
			done.call(result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300))
	var error: int = request.request("%s/%s" % [server, topic], PackedStringArray(["Content-Type: text/plain"]), HTTPClient.METHOD_POST, text)
	if error != OK:
		request.queue_free()
		if done.is_valid():
			done.call(false)


func fetch(topic: String, done: Callable) -> void:
	var request := _new_request()
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			if done.is_valid():
				done.call(false, [])
			return
		if done.is_valid():
			done.call(true, parse_poll_body(body.get_string_from_utf8())))
	var error: int = request.request("%s/%s/json?poll=1&since=all" % [server, topic])
	if error != OK:
		request.queue_free()
		if done.is_valid():
			done.call(false, [])


## 쉼표로 이은 여러 주제를 한 번에 읽는다 (ntfy 다중 구독). 응답의 topic 필드로 나눈다.
func fetch_many(topics: Array, since_seconds: int, done: Callable) -> void:
	var by_topic: Dictionary = {}
	for topic: Variant in topics:
		by_topic[str(topic)] = []
	var request := _new_request()
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			if done.is_valid():
				done.call(false, by_topic)
			return
		for line: String in body.get_string_from_utf8().split("\n", false):
			var json := JSON.new()
			if json.parse(line) != OK or not (json.data is Dictionary):
				continue
			var event: Dictionary = json.data
			var topic_name: String = str(event.get("topic", ""))
			if str(event.get("event", "")) == "message" and by_topic.has(topic_name):
				(by_topic[topic_name] as Array).append(str(event.get("message", "")))
		if done.is_valid():
			done.call(true, by_topic))
	var since: String = "all" if since_seconds <= 0 else "%ds" % since_seconds
	var error: int = request.request("%s/%s/json?poll=1&since=%s" % [server, ",".join(PackedStringArray(topics)), since])
	if error != OK:
		request.queue_free()
		if done.is_valid():
			done.call(false, by_topic)


## ntfy의 줄바꿈 구분 JSON 응답에서 message 이벤트의 본문만 시간순으로 뽑는다.
static func parse_poll_body(text: String) -> Array:
	var messages: Array = []
	for line: String in text.split("\n", false):
		var json := JSON.new()
		if json.parse(line) != OK or not (json.data is Dictionary):
			continue
		var event: Dictionary = json.data
		if str(event.get("event", "")) == "message":
			messages.append(str(event.get("message", "")))
	return messages


func _new_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT_SECONDS
	add_child(request)
	return request
