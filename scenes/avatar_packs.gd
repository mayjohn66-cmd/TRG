# File: res://scenes/avatar_packs.gd
# Class: class_name AvatarPacks
# Role: 웹 빌드의 아바타 애니메이션(감정 프레임·허브 대기 프레임)을 본체와 따로 받아 붙이는 다운로더.
#       본체(index.pck)에는 정지 그림(portrait·icon·fullbody·attack·hit)만 들어 있어 첫 로딩이 가볍다 (76 MiB -> 약 25 MiB).
#       게임은 필요한 아바타부터 avatars/<id>.pck를 한 번에 하나씩 뒤에서 받아 ProjectSettings.load_resource_pack()으로 붙이고 pack_ready를 보낸다.
#       받기 전·실패해도 AvatarSlot은 정지 그림 + 튕김 연출로 대신하므로 게임은 멈추지 않는다.
#       데스크톱·에디터·테스트는 애니메이션이 이미 res://에 있어 is_ready()가 곧바로 참이고 아무것도 받지 않는다.
#       묶음은 tools/export_avatar_packs.py가 내보낸다 (본체 제외 목록은 export_presets.cfg의 exclude_filter).
class_name AvatarPacks
extends Node

## 아바타 묶음 하나를 받아 붙였다 (이제 그 아바타의 감정·대기 애니메이션을 쓸 수 있다).
signal pack_ready(id: StringName)

## 웹 페이지 기준으로 묶음이 있는 폴더 (build/web/avatars/<id>.pck).
const PACK_FOLDER: String = "avatars"
## 받은 묶음을 써 두는 곳. 웹의 /tmp는 메모리 파일 시스템이라 브라우저 저장소(IndexedDB)에 수십 MB를 남기지 않는다.
const CACHE_DIRS: Array[String] = ["/tmp/avatar_packs", "user://avatar_packs"]
## 묶음을 받다가 실패하면 다시 시도하는 횟수 (그 뒤로는 정지 그림으로 계속한다).
const MAX_RETRIES: int = 1

static var _node: AvatarPacks = null

var _queue: Array[StringName] = []
var _loading: StringName = &""
var _tries: Dictionary = {}
var _request: HTTPRequest = null


## 이 아바타의 애니메이션을 지금 쓸 수 있는가 (본체에 들어 있거나 묶음을 이미 붙였다).
static func is_ready(id: StringName) -> bool:
	return ResourceLoader.exists(AvatarSlot.character_path(id) + "/emotion_happy.tres")


## 묶음을 따로 받는 환경인가: 웹 빌드에서만 받는다.
static func downloads_enabled() -> bool:
	return OS.has_feature("web")


## 이 아바타의 묶음을 받아 달라고 줄을 세운다. urgent면 맨 앞에 선다 (내 아바타·지금 판의 아바타).
static func request(id: StringName, urgent: bool = false) -> void:
	if not AvatarCatalog.is_valid(id) or is_ready(id) or not downloads_enabled():
		return
	var node: AvatarPacks = instance()
	if node != null:
		node._enqueue(id, urgent)


## 다운로더 노드 (처음 부를 때 루트에 붙인다). 화면을 옮겨 다녀도 받던 것은 계속 받는다.
static func instance() -> AvatarPacks:
	if is_instance_valid(_node):
		return _node
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_node = AvatarPacks.new()
	_node.name = "AvatarPacks"
	tree.root.add_child.call_deferred(_node)
	return _node


## 묶음이 준비되면 callback(id)을 부른다 (owner가 사라지면 연결도 함께 끊긴다).
static func when_ready(owner: Node, callback: Callable) -> void:
	var node: AvatarPacks = instance()
	if node == null or not is_instance_valid(owner):
		return
	var relay: Callable = func(id: StringName) -> void:
		if is_instance_valid(owner):
			callback.call(id)
	node.pack_ready.connect(relay)
	owner.tree_exiting.connect(func() -> void:
		if is_instance_valid(node) and node.pack_ready.is_connected(relay):
			node.pack_ready.disconnect(relay), CONNECT_ONE_SHOT)


## 묶음 주소: 페이지 주소 기준 avatars/<id>.pck (?v=버전으로 배포마다 브라우저 캐시를 새로 받는다).
static func pack_url(base: String, id: StringName, version: String) -> String:
	var root: String = base if base.ends_with("/") else base.get_base_dir() + "/"
	return "%s%s/%s.pck?v=%s" % [root, PACK_FOLDER, id, version.uri_encode()]


func _enqueue(id: StringName, urgent: bool) -> void:
	if id == _loading or int(_tries.get(id, 0)) > MAX_RETRIES:
		return
	if _queue.has(id):
		if not urgent:
			return
		_queue.erase(id)
	if urgent:
		_queue.push_front(id)
	else:
		_queue.append(id)
	_pump.call_deferred()


func _pump() -> void:
	if _loading != &"" or _queue.is_empty():
		return
	if not is_inside_tree():
		_pump.call_deferred()
		return
	var id: StringName = _queue.pop_front()
	if is_ready(id):
		pack_ready.emit(id)
		_pump.call_deferred()
		return
	_loading = id
	_tries[id] = int(_tries.get(id, 0)) + 1
	if _request == null:
		_request = HTTPRequest.new()
		_request.name = "PackRequest"
		_request.request_completed.connect(_on_completed)
		add_child(_request)
	# 웹의 HTTPRequest는 download_file로 파일을 쓰지 않는다 (상태 200인데 파일이 없다): 본문을 받아 직접 파일로 쓴다.
	var base: String = str(JavaScriptBridge.eval("window.location.href", true)) if OS.has_feature("web") else ""
	if _request.request(pack_url(base.get_slice("?", 0).get_slice("#", 0), id, GameSession.version())) != OK:
		_finish(false)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ok: bool = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and not body.is_empty():
		var path: String = _write_pack(_loading, body)
		ok = path != "" and ProjectSettings.load_resource_pack(path, false) and is_ready(_loading)
	_finish(ok)


## 받은 묶음을 파일로 쓴다 (load_resource_pack은 파일 경로만 받는다). 실패하면 빈 문자열.
static func _write_pack(id: StringName, bytes: PackedByteArray) -> String:
	for folder: String in CACHE_DIRS:
		DirAccess.make_dir_recursive_absolute(folder)
		var path: String = "%s/%s.pck" % [folder, id]
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(bytes)
		file.close()
		if FileAccess.file_exists(path):
			return path
	return ""


func _finish(ok: bool) -> void:
	var id: StringName = _loading
	_loading = &""
	if ok:
		print("AvatarPacks: %s 애니메이션 묶음을 붙였다" % id)
		pack_ready.emit(id)
	elif int(_tries.get(id, 0)) <= MAX_RETRIES:
		_queue.append(id)  # 한 번 더 (맨 뒤에서)
	else:
		push_warning("아바타 묶음을 받지 못했다: %s (정지 그림으로 계속)" % id)
	_pump.call_deferred()
