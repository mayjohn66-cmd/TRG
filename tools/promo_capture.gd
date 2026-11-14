# File: res://tools/promo_capture.gd
# Role: 홍보 영상용 자동 녹화 - 전원 AI가 두는 한 판을 Godot Movie Maker(--write-movie)로 찍는다. 게임 코드는 건드리지 않는다.
#   godot --path . --rendering-driver opengl3 --write-movie out.avi --fixed-fps 30 -s res://tools/promo_capture.gd -- seconds=40 seed=7
extends SceneTree

var _board: MainBoard = null
var _frames: int = 0
var _limit_frames: int = 1200
var _seed: int = 7


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seconds="):
			_limit_frames = int(float(arg.get_slice("=", 1)) * 30.0)
		elif arg.begins_with("seed="):
			_seed = int(arg.get_slice("=", 1))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
		root.add_child(_board)
		return false
	if _frames == 3:
		_board._bot.bot_players.assign(_board._player_ids)
		_board._bot.wait_for_human_windows = false
		_board._bot.set_enabled(true)
		_board._on_draft_auto_pressed()
		return false
	if _frames > 3 and _frames % 20 == 0 and _board != null:
		# 증강 확인 창이 뜨면 [확인]을 눌러 라운드를 시작한다
		if _board._review_button != null and is_instance_valid(_board._review_button) and not _board._review_button.disabled:
			_board._on_review_confirm()
	if _frames >= _limit_frames:
		quit(0)
	return false
