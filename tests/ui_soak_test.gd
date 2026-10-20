# File: res://tests/ui_soak_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 장시간 연속 플레이 메모리 검사. 네 자리를 모두 봇에게 맡기고 연출을 켠 채(시간 배속) 여러 판을 이어서 SOAK_ROUNDS 라운드 이상 진행하며,
#       라운드마다 노드·고아 노드·오브젝트·Tween 수를 재서 판이 길어져도 늘어나지 않는지(누수 없음) 확인한다.
#       실행: godot --headless --path . -s res://tests/ui_soak_test.gd   (SOAK_ROUNDS=40 처럼 바꿀 수 있다)
extends SceneTree

## 앞 몇 라운드는 캐시(텍스처·폰트·셰이더)가 채워지는 구간이라 기준선에서 뺀다.
const WARMUP_ROUNDS: int = 4
## 기준선보다 이만큼 넘게 늘면 누수로 본다 (그 순간 화면에 떠 있는 연출 몇 개는 허용).
const NODE_SLACK: int = 120
const ORPHAN_SLACK: int = 8
const OBJECT_SLACK: int = 1500
const MAX_SECONDS: float = 1500.0

var _board: MainBoard = null
var _frames: int = 0
var _target_rounds: int = 20
var _rounds_played: int = 0
var _games: int = 0
var _last_round: int = -1
var _samples: Array[Dictionary] = []
var _baseline: Dictionary = {}
var _started_msec: int = 0
var _failures: Array[String] = []


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_target_rounds = int(OS.get_environment("SOAK_ROUNDS")) if OS.get_environment("SOAK_ROUNDS") != "" else 20
		_started_msec = Time.get_ticks_msec()
		GameSession.ai_opponents = 3
		GameSession.pace_scale = 0.5
		Engine.time_scale = 8.0
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		# 연출을 실제로 켠다: 누수는 연출 노드에서 생긴다 (SOAK_INSTANT=1이면 연출 없이 엔진·UI 갱신만 비교용으로 돈다)
		_board.instant_roll_for_test = OS.get_environment("SOAK_INSTANT") == "1"
		_board.pacing_enabled = false  # 행동 사이 호흡(실시간 대기)만 끈다: 연출 노드는 그대로 만들고 지운다
		return false
	if _prewarm_index < PREWARM.size():
		_prewarm_step()
		return false
	if _frames == PREWARM.size() * 2 + 2:
		_setup_bots()
		return false
	var seconds: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	if seconds > MAX_SECONDS:
		_failures.append("시간 초과: %.0f초 동안 %d라운드밖에 못 돌았다" % [seconds, _rounds_played])
		return _finish()
	if _board.manager.is_game_over:
		_games += 1
		_sample("game_over")
		if _rounds_played >= _target_rounds:
			return _finish()
		_board._new_game()  # 다시 하기: 이전 판의 동적 노드·배열이 정리되는지도 함께 본다
		_setup_bots()
		_last_round = -1
		return false
	var round_number: int = _board.state.round_number
	if round_number != _last_round:
		if _last_round != -1:
			_rounds_played += 1
		_last_round = round_number
		_sample("round")
		if _rounds_played >= _target_rounds:
			return _finish()
	return false


## 굴림 3D 연출(주사위·윷·룰렛·리볼버·슬롯·마작)은 그 도구가 처음 나올 때 한 번 만들어 계속 재사용한다.
## 판 중간에 처음 생기는 이 고정 비용을 누수로 오인하지 않도록 시작할 때 모두 한 번씩 만들어 기준선에 넣는다.
const PREWARM: Array = [
	[&"D6", {"steps": 3, "details": {"face": 3}}],
	[&"YUT", {"steps": 2, "details": {"face": 2}}],
	[&"LIFE_ROULETTE", {"steps": 4, "details": {"face": 4}}],
	[&"REVOLVER", {"steps": 3, "can_continue": true, "details": {"fired": false, "accumulated": 3}}],
	[&"SLOT_777", {"steps": 4, "details": {"reels": [0, 1, 2]}}],
	[&"DICE_MAHJONG", {"steps": 3, "details": {"tiles": [1, 2, 3], "label": "연습"}}],
]
var _prewarm_index: int = 0
var _prewarm_playing: bool = false


func _prewarm_step() -> void:
	var presenter: RollPresenter = _board._presenter
	if _prewarm_playing:
		presenter.cancel()
		_prewarm_playing = false
		_prewarm_index += 1
		return
	var entry: Array = PREWARM[_prewarm_index]
	presenter.instant = false  # instant면 play가 아무것도 만들지 않고 돌아간다
	presenter.play(entry[0], entry[1], 0.5)
	_prewarm_playing = true
	if _prewarm_index == 0:
		for kind: RollPad.Kind in [RollPad.Kind.ROULETTE, RollPad.Kind.REVOLVER, RollPad.Kind.NONE]:
			_board._roll_pad.set_kind(kind)  # 굴림 패드의 룰렛 원판·리볼버도 미리 만든다


func _setup_bots() -> void:
	_board.ai_mode = true
	_board._bot.bot_players = [1, 2, 3, 4] as Array[int]
	_board._bot.draft_waits_for_humans = false
	_board._bot.wait_for_human_windows = false
	_board._bot.pace = 0.05  # 봇 생각 시간 단축
	_board._bot.set_enabled(true)


func _sample(kind: String) -> void:
	var sample: Dictionary = {
		"kind": kind,
		"round": _rounds_played,
		"game": _games,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"tweens": get_processed_tweens().size(),
		"memory_mb": snappedf(float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0, 0.1),
		"log_lines": _board._action_log.line_count() if _board.get("_action_log") != null else -1,
		"queue": _board._presentation_queue.size(),
	}
	_samples.append(sample)
	if OS.get_environment("SOAK_ORPHANS") == str(_rounds_played) and kind == "round":
		Node.print_orphan_nodes()  # 진단용: 이 라운드에 메모리에만 남은 노드 목록
	if _baseline.is_empty() and _rounds_played >= WARMUP_ROUNDS and kind == "round":
		_baseline = sample
		_baseline_census = _census()
	print("SOAK %s r=%d g=%d nodes=%d orphans=%d objects=%d resources=%d tweens=%d mem=%.1fMB log=%d queue=%d" % [kind, sample["round"], sample["game"], sample["nodes"], sample["orphans"], sample["objects"], sample["resources"], sample["tweens"], sample["memory_mb"], sample["log_lines"], sample["queue"]])


## 진단용: 트리의 노드를 [부모 이름/클래스]별로 센다. 실패하면 기준선보다 늘어난 묶음을 출력한다.
var _baseline_census: Dictionary = {}


func _census() -> Dictionary:
	var counts: Dictionary = {}
	var stack: Array[Node] = [_board]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var parent: Node = node.get_parent()
		var key: String = "%s/%s" % [parent.name if parent != null else "-", node.get_class()]
		counts[key] = int(counts.get(key, 0)) + 1
		for child: Node in node.get_children():
			stack.append(child)
	return counts


func _print_census_diff() -> void:
	var now: Dictionary = _census()
	var rows: Array = []
	for key: String in now.keys():
		var grown: int = int(now[key]) - int(_baseline_census.get(key, 0))
		if grown > 0:
			rows.append([grown, key])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for row: Array in rows.slice(0, 25):
		print("SOAK_GROWN +%d %s" % [row[0], row[1]])


func _finish() -> bool:
	if _baseline.is_empty():
		_failures.append("기준선을 잡기 전에 끝났다 (%d라운드)" % _rounds_played)
	else:
		# 라운드 경계 표본의 최솟값을 끝부분에서 본다: 그 순간 떠 있는 연출 하나로 오탐하지 않게 마지막 3개 중 가장 작은 값을 쓴다
		var tail: Array[Dictionary] = []
		for sample: Dictionary in _samples:
			if sample["kind"] == "round" and int(sample["round"]) > int(_baseline["round"]):
				tail.append(sample)
		tail = tail.slice(maxi(tail.size() - 3, 0))
		if tail.is_empty():
			_failures.append("기준선 뒤 표본이 없다")
		else:
			var low: Dictionary = {}
			for key: String in ["nodes", "orphans", "objects", "tweens"]:
				low[key] = tail.map(func(sample: Dictionary) -> int: return int(sample[key])).min()
			if int(low["nodes"]) > int(_baseline["nodes"]) + NODE_SLACK:
				_failures.append("노드가 계속 늘어난다: %d -> %d" % [_baseline["nodes"], low["nodes"]])
			if int(low["orphans"]) > int(_baseline["orphans"]) + ORPHAN_SLACK:
				_failures.append("고아 노드가 쌓인다: %d -> %d" % [_baseline["orphans"], low["orphans"]])
			if int(low["objects"]) > int(_baseline["objects"]) + OBJECT_SLACK:
				_failures.append("오브젝트가 계속 늘어난다: %d -> %d" % [_baseline["objects"], low["objects"]])
	if _board.get("_action_log") != null and _board._action_log.line_count() > ActionLogPanel.MAX_LOG_LINES:
		_failures.append("액션 로그가 %d줄을 넘었다 (%d)" % [ActionLogPanel.MAX_LOG_LINES, _board._action_log.line_count()])
	if _rounds_played < _target_rounds:
		_failures.append("%d라운드를 채우지 못했다 (%d)" % [_target_rounds, _rounds_played])
	Engine.time_scale = 1.0
	if not _failures.is_empty() and not _baseline_census.is_empty():
		_print_census_diff()
	for failure: String in _failures:
		print("UI_SOAK_FAIL: ", failure)
	if _failures.is_empty():
		print("UI_SOAK_OK rounds=%d games=%d baseline_nodes=%d end_nodes=%d" % [_rounds_played, _games, _baseline.get("nodes", -1), _samples[-1]["nodes"]])
	quit(0 if _failures.is_empty() else 1)
	return true
