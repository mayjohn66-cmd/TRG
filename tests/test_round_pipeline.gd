# File: res://tests/test_round_pipeline.gd
# Class: class_name TestRoundPipeline
# Role: 한 라운드마다 도는 파이프라인 대조 검사. 봇 네 명이 실제 규칙(드래프트·발판·템포 업 포함)으로 여러 판을 끝까지 두는 동안 라운드마다 순서와 불변식을 확인한다:
#       라운드 시작(템포 업 경고·드래프트) -> 사람마다 턴 1번 이상(휴식·졸업 제외, 차례가 끝날 때마다 특수 승리 판정) -> 라운드 끝 NPC 페이즈(그 뒤 한 번 더 판정) -> 다음 라운드.
class_name TestRoundPipeline
extends TestCase

const State := TurnManager.State

var _log: Array[Dictionary] = []


func _run_game(seed_value: int) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = true
	manager.hotseat_mode = true
	manager.draft_enabled = true
	tree.root.add_child(manager)
	manager.set_process(false)
	_log.clear()
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		_log.append({"kind": kind, "data": data, "round": manager.state.round_number, "phase": manager.current_state}))
	var last_phase: Array = [-1]
	manager.phase_changed.connect(func(new_state: State, player_id: int, _limit: float) -> void:
		if new_state != last_phase[0] and new_state == State.PHASE_TURN_BEGIN:
			_log.append({"kind": &"__turn", "data": {"player": player_id}, "round": manager.state.round_number, "phase": new_state})
		if new_state == State.PHASE_ROUND_START and last_phase[0] != State.PHASE_ROUND_START:
			_log.append({"kind": &"__round_start", "data": {"graduated": manager.state.rankings.duplicate(), "npcs": manager.state.npcs.size()}, "round": manager.state.round_number, "phase": new_state})
			_check_board_invariants(manager)
		last_phase[0] = new_state)
	manager.start_game([1, 2, 3, 4] as Array[int], seed_value)
	var controller := BotController.new()
	controller.manager = manager
	controller.bot_players = [1, 2, 3, 4] as Array[int]
	controller.instant = true
	controller.enabled = true
	controller.rng.seed = seed_value
	var ticks: int = 0
	while not manager.is_game_over and ticks < 80000:
		controller.tick(0.0)
		ticks += 1
	controller.free()
	check(manager.is_game_over, "시드 %d: 판이 끝까지 진행된다 (라운드 %d)" % [seed_value, manager.state.round_number])
	return manager


## 졸업한 사람의 설치물·연대 묶음이 남지 않고, 설치물 남은 턴이 음수가 아니고, 소환 기물은 하나 이하.
func _check_board_invariants(manager: TurnManager) -> void:
	var state: GameState = manager.state
	for tile: TileNode in state.board.tiles:
		for attachment: TileAttachment in tile.attachments:
			check(not state.is_graduated(attachment.owner_id), "R%d: 졸업한 P%d의 설치물(%s)이 남아 있다" % [state.round_number, attachment.owner_id, attachment.attachment_id])
			check(attachment.duration_turns >= -1, "R%d: 설치물 남은 턴이 음수" % state.round_number)
	for pawn_id: Variant in state.bonds.keys():
		var pawn: PlayerPawn = state.get_pawn(int(pawn_id))
		check(pawn != null and not state.is_graduated(pawn.owner_id), "R%d: 졸업한 사람의 연대 묶음이 남아 있다" % state.round_number)
	check(state.npcs.size() <= 1, "R%d: 소환 기물은 한 번에 하나" % state.round_number)


func _check_round_order(manager: TurnManager, seed_value: int) -> void:
	var rounds: Dictionary = {}
	for entry: Dictionary in _log:
		var round_number: int = int(entry["round"])
		if not rounds.has(round_number):
			rounds[round_number] = []
		(rounds[round_number] as Array).append(entry)
	var last_round: int = manager.state.round_number
	for round_number: int in range(1, last_round + 1):
		var events: Array = rounds.get(round_number, [])
		var kinds: Array = events.map(func(e: Dictionary) -> StringName: return e["kind"])
		var tag: String = "시드 %d R%d" % [seed_value, round_number]
		# 라운드 시작: 템포 업 경고는 단계가 오르는 라운드에만, 드래프트보다 먼저
		check_eq(kinds.count(&"tempo_up"), 1 if TempoUp.is_stage_round(round_number) else 0, "%s: 템포 업 경고 횟수" % tag)
		if kinds.has(&"tempo_up") and kinds.has(&"augment_offers"):
			check(kinds.find(&"tempo_up") < kinds.find(&"augment_offers"), "%s: 템포 업 경고가 드래프트보다 먼저" % tag)
		check(kinds.count(&"augment_offers") <= (1 if GameEnums.is_draft_round(round_number) else 0), "%s: 드래프트는 증강 라운드에만 한 번" % tag)
		if round_number == last_round and manager.is_game_over:
			continue  # 게임이 끝난 라운드는 도중에 끊긴다
		# 라운드 끝: NPC 페이즈 한 번
		check_eq(kinds.count(&"npc_phase_resolved"), 1, "%s: 라운드 끝 NPC 페이즈는 한 번" % tag)
		# 턴: 라운드 시작 때 레이스에 남은 사람마다 한 번 이상 (휴식·졸업한 사람 제외)
		var start_entry: Dictionary = {}
		for entry: Dictionary in events:
			if entry["kind"] == &"__round_start":
				start_entry = entry
				break
		var graduated: Array = start_entry.get("data", {}).get("graduated", [])
		var rested: Array = []
		var turns: Dictionary = {}
		for entry: Dictionary in events:
			if entry["kind"] == &"turn_rested":
				rested.append(int(entry["data"]["player_id"]))
			elif entry["kind"] == &"__turn":
				var player: int = int(entry["data"]["player"])
				turns[player] = int(turns.get(player, 0)) + 1
		for player_id: int in [1, 2, 3, 4]:
			if graduated.has(player_id) or rested.has(player_id):
				continue
			var graduated_this_round: bool = manager.state.rankings.has(player_id) and not graduated.has(player_id)
			if graduated_this_round and int(turns.get(player_id, 0)) == 0:
				continue  # 라운드 중 다른 사람 차례에 졸업했다 (완주·연대·결승선 당김)
			check(int(turns.get(player_id, 0)) >= 1, "%s: P%d의 턴이 없다 (%s)" % [tag, player_id, str(turns)])
	# 한 교칙은 한 명만 졸업시킨다 (달성되면 법전에서 사라진다). 마지막 한 명은 꼴찌로 남는다.
	var law_reasons: Array = []
	for reason: Variant in manager.state.rank_reasons.values():
		if LawRegistry.ALL_IDS.has(String(reason)):
			check(not law_reasons.has(reason), "시드 %d: 같은 교칙(%s)으로 두 명이 졸업했다" % [seed_value, reason])
			law_reasons.append(reason)
	check(manager.state.rank_reasons.values().has(VictoryChecker.LAST_PLACE) or manager.state.rankings.size() < 4, "시드 %d: 마지막 한 명은 꼴찌로 남는다 (%s)" % [seed_value, str(manager.state.rank_reasons)])
	# 특수 승리 졸업은 행동이 다 끝난 뒤(차례가 넘어가는 순간 또는 라운드 끝 NPC 페이즈 뒤)에만: 이동 도중·말 선택 도중에는 없다
	var judged: bool = false
	var actor_graduated: bool = false  # 차례인 사람이 이동 중 완주로 졸업하면 그 순간 차례가 끝나 판정한다 (이동 단계 표시 그대로)
	for entry: Dictionary in _log:
		if entry["kind"] == &"special_victory_judgement":
			judged = true
			check(actor_graduated or (entry["phase"] != State.PHASE_MOVING_STEP and entry["phase"] != State.PHASE_SELECT_PAWN), "시드 %d R%d: 특수 승리 판정이 이동 도중에 끼어들었다" % [seed_value, int(entry["round"])])
		elif entry["kind"] == &"player_ranked":
			var reason: StringName = entry["data"]["reason"]
			if reason != VictoryChecker.ALL_HOME and reason != VictoryChecker.LAST_PLACE and reason != VictoryChecker.RACE_ORDER:  # 라운드 상한의 진행 순위 확정은 특수 승리가 아니다
				check(judged, "시드 %d R%d: 특수 승리(%s) 졸업 앞에 판정 이벤트가 있다" % [seed_value, int(entry["round"]), reason])
				check(actor_graduated or (entry["phase"] != State.PHASE_MOVING_STEP and entry["phase"] != State.PHASE_SELECT_PAWN), "시드 %d R%d: 특수 승리(%s)는 행동이 끝난 뒤에 졸업" % [seed_value, int(entry["round"]), reason])
			elif entry["phase"] == State.PHASE_MOVING_STEP:
				actor_graduated = true
		elif entry["kind"] == &"__turn":
			judged = false
			actor_graduated = false


func test_round_pipeline_holds_over_whole_bot_games() -> void:
	var seeds: Array[int] = [11, 22, 33, 44]
	if OS.get_environment("PIPELINE_SEEDS") != "":  # 로컬 정밀 검사: PIPELINE_SEEDS=16 이면 시드 16개
		seeds.clear()
		for index: int in int(OS.get_environment("PIPELINE_SEEDS")):
			seeds.append(1000 + index * 37)
	for seed_value: int in seeds:
		var manager: TurnManager = _run_game(seed_value)
		_check_round_order(manager, seed_value)
		tree.root.remove_child(manager)
		manager.free()
