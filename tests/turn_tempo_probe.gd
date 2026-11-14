# File: res://tests/turn_tempo_probe.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 턴 진행 템포 계측기. 연출을 켠 실제 판(봇 4명, 연출 속도 그대로)을 PROBE_SECONDS초 동안 돌리며, 매 프레임 "지금 무엇을 기다리는가"를 분류해
#       이유별·단계별 누적 시간, 가장 길었던 연속 대기, 턴 길이, 이동 칸 수 대비 이동 시간을 출력한다. 렉(프레임 드랍)이 아니라 await 대기 누적을 찾는 용도.
#       실행: PROBE_SECONDS=180 godot --headless --path . -s res://tests/turn_tempo_probe.gd
#       PROBE_SPEED=3이면 배속 3x로 잰다. PROBE_MAX_TURN이 있으면 평균 턴 길이(초)가 그보다 길면 실패로 끝난다.
extends SceneTree

var board: MainBoard
var frames: int = 0
var started_msec: int = 0
var last_msec: int = 0
var by_reason: Dictionary = {}
var by_phase: Dictionary = {}
var spans: Dictionary = {}  # reason -> [시작 msec, 문맥]
var longest: Array = []  # [길이, 이유, 문맥]
var turn_started: int = -1
var turn_lengths: Array[float] = []
var moves: Array = []  # [칸 수, 초]
var move_started: int = -1
var last_event: String = ""
var current_reason: String = ""


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		GameSession.avatar_id = &"avatar_01"
		board = load("res://scenes/main_board.tscn").instantiate()
		root.add_child(board)
		board.ai_mode = true
		board._bot.bot_players.append(board.local_player_id)
		board._bot.wait_for_human_windows = false
		board._bot.set_enabled(true)
		if OS.get_environment("PROBE_SPEED") != "":
			GameSession.game_speed = int(OS.get_environment("PROBE_SPEED"))
			board._apply_game_speed()
		board.manager.event_received.connect(_on_event)
		board.manager.phase_changed.connect(_on_phase)
		started_msec = Time.get_ticks_msec()
		last_msec = started_msec
		return false
	var now: int = Time.get_ticks_msec()
	var dt: float = (now - last_msec) / 1000.0
	last_msec = now
	var reason: String = _reason(now)
	by_reason[reason] = float(by_reason.get(reason, 0.0)) + dt
	var phase: String = TurnManager.State.keys()[board.manager.current_state]
	by_phase[phase] = float(by_phase.get(phase, 0.0)) + dt
	if reason != current_reason:
		if current_reason != "" and spans.has(current_reason):
			var span: Array = spans[current_reason]
			longest.append([(now - int(span[0])) / 1000.0, current_reason, str(span[1])])
		spans[reason] = [now, "%s / 직전 이벤트 %s" % [phase, last_event]]
		current_reason = reason
	var limit: float = float(OS.get_environment("PROBE_SECONDS")) if OS.get_environment("PROBE_SECONDS") != "" else 150.0
	if board.manager.is_game_over or (now - started_msec) / 1000.0 > limit:
		_report()
		return true
	return false


func _reason(now: int) -> String:
	var bot: BotController = board._bot
	if board.manager.duel_pending():
		return "결투"
	if board._capture_cutin != null and board._capture_cutin.busy():
		return "처치 컷인"
	if board._draft_overlay != null:
		return "증강 선택 창"
	if board._announcer != null and board._announcer.holding():
		return "중앙 알림 카드 (%s)" % str(board._announcer._current.get("tag", "?"))
	if board._presentation_active():
		var label: String = board.presentation_label
		if label == "<anonymous lambda>":
			if board._fx_busy:
				label = "굴림 연출(_fx_busy) 끝 기다림"
			elif board._capture_cutin != null and board._capture_cutin.busy():
				label = "처치 컷인"
			elif board._announcer != null and board._announcer.active:
				label = "알림 카드 표시 중"
			elif now < board._fx_until_msec:
				label = "연출 시간 잠금(_fx_until)"
			else:
				label = "기타 람다"
		return "연출 큐: %s" % label
	if board.manager.current_state == TurnManager.State.PHASE_MOVING_STEP:
		return "엔진 걸음 대기 (step_delay)"
	if board._fx_busy:
		return "굴림 연출 (_fx_busy)"
	if now < board._beat_until_msec:
		return "호흡 (_start_beat)"
	if now < board._fx_until_msec:
		return "연출 시간 잠금 (_fx_until)"
	if bot._wait > 0.0:
		return "봇 생각 시간 (%s)" % TurnManager.State.keys()[board.manager.current_state]
	return "기타 (%s)" % TurnManager.State.keys()[board.manager.current_state]


func _on_event(kind: StringName, data: Dictionary) -> void:
	last_event = String(kind)
	var now: int = Time.get_ticks_msec()
	if kind == &"roll_resolved":
		move_started = now
	elif kind == &"move_resolved" and move_started != -1:
		var steps: int = (data.get("path", []) as Array).size()
		moves.append([steps, (now - move_started) / 1000.0])
		move_started = -1


func _on_phase(new_state: TurnManager.State, _player: int, _limit: float) -> void:
	if new_state == TurnManager.State.PHASE_TURN_BEGIN:
		var now: int = Time.get_ticks_msec()
		if turn_started != -1:
			turn_lengths.append((now - turn_started) / 1000.0)
		turn_started = now


func _report() -> void:
	var total: float = (Time.get_ticks_msec() - started_msec) / 1000.0
	print("PROBE total %.1fs round %d turns %d" % [total, board.state.round_number, turn_lengths.size()])
	var reasons: Array = by_reason.keys()
	reasons.sort_custom(func(a: String, b: String) -> bool: return float(by_reason[a]) > float(by_reason[b]))
	print("-- 이유별 누적 (초, 비율)")
	for key: String in reasons:
		print("  %6.1f  %4.1f%%  %s" % [by_reason[key], 100.0 * float(by_reason[key]) / total, key])
	var phases: Array = by_phase.keys()
	phases.sort_custom(func(a: String, b: String) -> bool: return float(by_phase[a]) > float(by_phase[b]))
	print("-- 단계별 누적")
	for key: String in phases:
		print("  %6.1f  %s" % [by_phase[key], key])
	longest.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("-- 가장 긴 연속 대기 10개")
	for entry: Array in longest.slice(0, 10):
		print("  %5.2fs  %s  [%s]" % [entry[0], entry[1], entry[2]])
	var avg: float = 0.0
	for length: float in turn_lengths:
		avg += length
	avg = avg / maxf(turn_lengths.size(), 1)
	var sorted_turns: Array[float] = turn_lengths.duplicate()
	sorted_turns.sort()
	print("-- 턴 길이: 평균 %.2fs, 최장 %.2fs" % [avg, sorted_turns.back() if not sorted_turns.is_empty() else 0.0])
	var long_moves: Array = moves.filter(func(m: Array) -> bool: return int(m[0]) >= 8)
	print("-- 이동: %d번, 8칸 이상 %d번" % [moves.size(), long_moves.size()])
	for entry: Array in long_moves.slice(0, 6):
		print("  %d칸 -> 굴림 결과부터 이동 끝까지 %.2fs" % [entry[0], entry[1]])
	var max_turn: float = float(OS.get_environment("PROBE_MAX_TURN")) if OS.get_environment("PROBE_MAX_TURN") != "" else 0.0
	if max_turn > 0.0 and avg > max_turn:
		printerr("PROBE_FAIL: 평균 턴 %.2fs > %.2fs" % [avg, max_turn])
		quit(1)
		return
	print("PROBE_OK")
	quit(0)
