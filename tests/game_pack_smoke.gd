# File: tests/game_pack_smoke.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 나눠 내보낸 웹 빌드 검사 — 본체(--main-pack index.pck)만으로는 게임 보드가 없고(묶음을 기다려야 한다),
#       game.pck(GAME_PACK=절대 경로)를 붙이면 UID가 등록되고 게임 보드가 열려 몇 초 돈다. 배포 CI가 [invalid UID]·로드 실패 줄을 함께 막는다.
extends SceneTree

var _failures: Array[String] = []
var _board: Node = null
var _frames: int = 0


func _initialize() -> void:
	if GamePack.is_ready():
		_failures.append("본체만으로 게임 보드가 열린다: 게임 묶음이 나뉘지 않았다")
	var pack: String = OS.get_environment("GAME_PACK")
	if pack == "" or not ProjectSettings.load_resource_pack(pack, true):
		_failures.append("game.pck를 붙이지 못했다: " + pack)
		_finish()
		return
	var uids: int = GamePack.register_uids()
	GamePack.refresh_caches()
	if uids < 100:
		_failures.append("묶음 UID 목록이 너무 적다: %d" % uids)
	if not GamePack.is_ready():
		_failures.append("묶음을 붙였는데도 준비되지 않았다")
		_finish()
		return
	GameSession.mode = GameSession.MODE_AI
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)


func _process(_delta: float) -> bool:
	if _board == null:
		return false
	_frames += 1
	if _frames == 240:
		if not is_instance_valid(_board) or _board.get("manager") == null:
			_failures.append("게임 보드가 돌지 않는다")
		_finish()
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_PACK_SMOKE_OK")
	else:
		for failure: String in _failures:
			printerr("GAME_PACK_SMOKE_FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)
