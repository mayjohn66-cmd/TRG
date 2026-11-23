# File: res://scenes/game_pack.gd
# Class: class_name GamePack
# Role: 웹 첫 로딩을 가볍게: 본체(index.pck)에는 메뉴·로비에 필요한 것만 두고, 게임 보드·연출·도감 그림·3D 모델·효과음 등은
#       게임 묶음(game.pck)으로 따로 받아 붙인다 (tools/export_game_pack.py가 나눈다).
#       메뉴가 뜨면 prefetch()로 뒤에서 받기 시작하고, 게임 시작·도감·온라인 게임 입장은 run_when_ready()로 묶음이 붙을 때까지
#       진행 막대를 보여 주며 기다린다. 데스크톱·에디터·테스트·묶음을 나누지 않은 빌드는 모든 리소스가 이미 res://에 있어 곧바로 준비된 것으로 본다.
class_name GamePack
extends Node

## 묶음을 받아 붙였다 (이제 게임 보드를 열 수 있다).
signal pack_ready
## 받는 중 진행 (0~1, 크기를 모르면 -1).
signal progress(ratio: float)
## 받기에 실패했다 (다시 시도 버튼을 보여 준다).
signal failed

## 묶음에 들어 있는지로 준비 여부를 본다: 게임 보드 장면은 메뉴가 읽지 않으므로 늘 게임 묶음에 있다.
const MARKER: String = "res://scenes/main_board.tscn"
const FILE_NAME: String = "game.pck"
## 묶음 안의 UID 목록 (tools/export_game_pack.py가 만든다): 붙인 뒤 엔진에 알려 uid:// 참조가 경고 없이 읽힌다.
const MANIFEST: String = "res://game_pack_manifest.json"
## 웹의 /tmp는 메모리 파일 시스템이라 브라우저 저장소(IndexedDB)에 수십 MB를 남기지 않는다.
const CACHE_DIRS: Array[String] = ["/tmp/game_pack", "user://game_pack"]
const MAX_TRIES: int = 3
## 브라우저 fetch로 받은 묶음을 엔진 파일 시스템에 쓰는 곳 (메모리 파일 시스템).
const JS_PATH: String = "/tmp/game.pck"
## 없는 그림 대신 다른 그림을 골라 기억하는 캐시가 있는 스크립트 (묶음을 붙이면 비운다).
const CACHED_ART_SCRIPTS: Array[String] = ["res://scenes/avatar_combat_art.gd", "res://scenes/judgment_card_art.gd", "res://scenes/mahjong_face.gd"]

static var _node: GamePack = null

var _request: HTTPRequest = null
var _loading: bool = false
var _tries: int = 0
var _last_error: String = ""
## 브라우저 fetch로 받는 중인가 (web/shell.html의 trgFetchPack). 아니면 HTTPRequest로 받는다 (옛 셸).
var _js_job: bool = false
## 진행률 (브라우저 fetch로 받을 때).
var _js_ratio: float = -1.0


## 게임 묶음이 붙어 있는가 (또는 처음부터 다 들어 있는 빌드인가).
static func is_ready() -> bool:
	return ResourceLoader.exists(MARKER)


## 받는 노드 (처음 부를 때 루트에 붙인다). 화면을 옮겨 다녀도 받던 것은 계속 받는다.
static func instance() -> GamePack:
	if is_instance_valid(_node):
		return _node
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_node = GamePack.new()
	_node.name = "GamePack"
	tree.root.add_child.call_deferred(_node)
	return _node


## 메뉴가 뜨면 부른다: 아직 없으면 뒤에서 받기 시작한다.
static func prefetch() -> void:
	if is_ready():
		return
	var node: GamePack = instance()
	if node != null:
		node._start.call_deferred()


## 묶음이 준비되면 action을 부른다. 아직이면 parent 위에 [게임 데이터를 받는 중] 창을 띄우고 기다린다 (준비되면 창을 닫고 부른다).
static func run_when_ready(parent: Node, action: Callable) -> void:
	if is_ready():
		action.call()
		return
	var node: GamePack = instance()
	if node == null or parent == null or not is_instance_valid(parent):
		return
	var overlay := GamePackOverlay.new()
	parent.add_child(overlay)
	overlay.bind(node)
	node.pack_ready.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		if is_instance_valid(parent):
			action.call(), CONNECT_ONE_SHOT)
	node._start.call_deferred()


## 진행률 (0~1, 모르면 -1).
func ratio() -> float:
	if _js_job and _loading:
		return _js_ratio
	if _request == null or not _loading:
		return 1.0 if is_ready() else 0.0
	var total: int = _request.get_body_size()
	return float(_request.get_downloaded_bytes()) / float(total) if total > 0 else -1.0


func last_error() -> String:
	return _last_error


## 다시 시도 (실패 창의 버튼).
func retry() -> void:
	_tries = 0
	_start()


func _process(_delta: float) -> void:
	if not _loading:
		return
	if _js_job:
		_poll_js()
	progress.emit(ratio())


## 브라우저 fetch로 받는 일의 상태를 본다: 다 받았으면 엔진 파일 시스템의 묶음을 붙인다.
func _poll_js() -> void:
	var state: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.trgPacks.game || {})", true)))
	if not (state is Dictionary):
		return
	var job: Dictionary = state
	var total: float = float(job.get("total", -1))
	_js_ratio = float(job.get("loaded", 0)) / total if total > 0.0 else -1.0
	match str(job.get("state", "")):
		"done":
			_js_job = false
			_mount(JS_PATH)
		"error":
			_js_job = false
			_finish(false, str(job.get("error", "fetch failed")))


func _start() -> void:
	if is_ready():
		pack_ready.emit()
		return
	if _loading:
		return
	if not is_inside_tree():
		_start.call_deferred()
		return
	if not OS.has_feature("web"):
		# 웹이 아닌데 묶음이 빠진 빌드 (만들 일 없음): 실행 파일 옆의 game.pck를 붙여 본다
		_mount(OS.get_executable_path().get_base_dir().path_join(FILE_NAME))
		return
	_loading = true
	_tries += 1
	var base: String = str(JavaScriptBridge.eval("window.location.href", true)).get_slice("?", 0).get_slice("#", 0)
	var root: String = base if base.ends_with("/") else base.get_base_dir() + "/"
	# ?v=는 웹 셸의 캐시 가드가 묶음 내용 해시로 바꾼다 (내용이 같으면 다시 받지 않는다)
	var url: String = "%s%s?v=%s" % [root, FILE_NAME, GameSession.version().uri_encode()]
	if bool(JavaScriptBridge.eval("typeof window.trgFetchPack === 'function'", true)):
		# 브라우저 fetch로 받아 엔진 파일 시스템(/tmp)에 바로 쓴다: HTTPRequest는 한 프레임에 조각 하나만 읽어 느리다 (web/shell.html)
		JavaScriptBridge.eval("window.trgPacks.game && window.trgPacks.game.state === 'error' && delete window.trgPacks.game", true)
		JavaScriptBridge.eval("window.trgFetchPack('game', %s, %s)" % [JSON.stringify(url), JSON.stringify(JS_PATH)], true)
		_js_job = true
		return
	_js_job = false
	if _request == null:
		_request = HTTPRequest.new()
		_request.name = "GamePackRequest"
		# 웹 HTTPRequest는 한 프레임에 download_chunk_size만큼만 본문을 읽는다 (기본 64KB): 수십 MB 묶음이 프레임 수에 묶여 수십 초 걸렸다
		_request.download_chunk_size = 4 * 1024 * 1024
		_request.request_completed.connect(_on_completed)
		add_child(_request)
	if _request.request(url) != OK:
		_finish(false, "request failed to start")


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		_finish(false, "download failed (%d/%d)" % [result, code])
		return
	var path: String = _write(body)
	if path == "":
		_finish(false, "could not write the pack")
		return
	_mount(path)


func _mount(path: String) -> void:
	var ok: bool = FileAccess.file_exists(path) and ProjectSettings.load_resource_pack(path, true)
	if ok:
		register_uids()
		refresh_caches()
	_finish(ok and is_ready(), "" if ok else "could not mount the pack")


## 묶음 안 리소스의 UID를 엔진에 알린다 (본체의 UID 목록에는 묶음 리소스가 없다: 없으면 uid:// 참조마다 경고가 찍히고 느려진다).
static func register_uids() -> int:
	if not FileAccess.file_exists(MANIFEST):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (data is Dictionary):
		return 0
	var added: int = 0
	var uids: Dictionary = (data as Dictionary).get("uids", {})
	for text: String in uids:
		var uid: int = ResourceUID.text_to_id(text)
		if uid == ResourceUID.INVALID_ID:
			continue
		if ResourceUID.has_id(uid):
			ResourceUID.set_id(uid, str(uids[text]))
		else:
			ResourceUID.add_id(uid, str(uids[text]))
		added += 1
	return added


## 메뉴에서 "없음"으로 기억해 둔 것을 잊는다 (묶음을 붙인 뒤에는 있다): 그림 캐시의 빈 항목, 효과음 목록,
## 없는 그림 대신 다른 그림을 골라 기억하는 캐시(아바타 전투 그림·판정 카드·마작패).
static func refresh_caches() -> void:
	TextureCache.forget_missing()
	Sfx.rescan()
	# 게임 쪽 그림 캐시: 이름(클래스)으로 쓰면 메뉴에서 그 스크립트와 preload까지 컴파일되므로, 붙인 뒤에 경로로 불러 비운다
	for path: String in CACHED_ART_SCRIPTS:
		var script: GDScript = load(path) as GDScript
		if script != null:
			script.call("clear_cache")


static func _write(bytes: PackedByteArray) -> String:
	for folder: String in CACHE_DIRS:
		DirAccess.make_dir_recursive_absolute(folder)
		var path: String = folder.path_join(FILE_NAME)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(bytes)
		file.close()
		if FileAccess.file_exists(path):
			return path
	return ""


func _finish(ok: bool, error: String) -> void:
	_loading = false
	if ok:
		print("GamePack: game pack mounted")
		pack_ready.emit()
		return
	_last_error = error
	if _tries < MAX_TRIES and OS.has_feature("web"):
		get_tree().create_timer(1.5 * _tries).timeout.connect(_start)
		return
	push_warning("GamePack: game pack unavailable: %s" % error)
	failed.emit()
