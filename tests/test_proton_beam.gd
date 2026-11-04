# File: res://tests/test_proton_beam.gd
# Class: class_name TestProtonBeam
# Role: SUM_03 롤링 양성자빔 검증 - 상단 코너 소환(수명 3라운드), 라운드 끝마다 무작위 방향 3~5칸, 지나는 칸의 말(소환자 것까지)·설치물 전부 소각,
#       잡아도 사라지지 않고 3번 움직인 뒤 소멸, 스냅샷 복원, 위험 예고(양방향)
class_name TestProtonBeam
extends TestCase


func _new_manager(seed_value: int = 777) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2], seed_value)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _place(pawn: PlayerPawn, tile: int) -> void:
	pawn.has_left_start = true
	pawn.is_finished = false
	pawn.current_tile_idx = tile


func _summon(manager: TurnManager) -> NeutralNPC:
	var me: int = manager.current_player_id()
	manager.state.hands[me] = [NpcSweep.BEAM_ID]
	manager.act(&"play_card", {"player_id": me, "card_id": NpcSweep.BEAM_ID, "tile": BoardSpec.halfway_tile})
	return manager.state.npcs[0] if not manager.state.npcs.is_empty() else null


func test_card_is_a_summon_played_on_the_top_corner_once() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var card: BaseCard = CardRegistry.get_card(NpcSweep.BEAM_ID)
	check(card is CardProtonBeam, "SUM_03은 롤링 양성자빔")
	check_eq(card.category, GameEnums.CardCategory.SUMMON, "소환 카드")
	check(CardRegistry.default_deck().has(NpcSweep.BEAM_ID), "기본 덱에 들어 있다")
	check(card.is_legal(state, me, {"tile": BoardSpec.halfway_tile}), "상단 코너(반환점)에 소환할 수 있다")
	check(not card.is_legal(state, me, {"tile": 5}), "다른 칸에는 못 낸다")
	var beam: NeutralNPC = _summon(manager)
	check(beam != null and beam.is_beam(), "빛 기둥이 판 위에 내려앉았다")
	check_eq(beam.rounds_left, NpcSweep.BEAM_ROUNDS, "수명 3라운드")
	check_eq(beam.current_tile_idx, BoardSpec.halfway_tile, "상단 코너에 선다")
	check(not card.could_play(state, me), "중립 기물은 하나만: 빔이 있으면 소환 카드를 또 못 낸다")
	_dispose(manager)


func test_burn_sends_every_pawn_home_including_the_summoner_and_clears_installations() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var beam: NeutralNPC = _summon(manager)
	var owner: int = beam.owner_id
	var foe: int = 2 if owner == 1 else 1
	var start: int = beam.current_tile_idx
	var mine: PlayerPawn = state.pawns_of(owner)[0]
	var theirs: PlayerPawn = state.pawns_of(foe)[0]
	_place(mine, start + 1)
	_place(theirs, start + 3)
	state.place_attachment(start + 2, TrapPit.new(foe))
	var far: PlayerPawn = state.pawns_of(foe)[1]
	_place(far, start + 6)
	var run: Dictionary = NpcSweep.burn(state, beam, 1, 4)
	check(not mine.has_left_start, "소환한 사람의 말도 태운다 (무자비)")
	check(not theirs.has_left_start, "적 말을 태운다")
	check(far.has_left_start and far.current_tile_idx == start + 6, "닿지 않은 칸의 말은 그대로")
	check(state.board.get_tile(start + 2).attachments.is_empty(), "지나간 칸의 함정이 사라졌다")
	check_eq(int(run["destroyed"]), 1, "설치물 1개 소각")
	check_eq((run["ejected"] as Array).size(), 2, "말 2개 사출")
	check_eq(beam.current_tile_idx, start + 4, "잡아도 멈추지 않고 4칸 끝까지 미끄러졌다")
	check(state.get_npc(beam.entity_id) != null, "잡아도 사라지지 않는다")
	_dispose(manager)


func test_beam_moves_three_rounds_then_fades_on_its_own() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var beam: NeutralNPC = _summon(manager)
	var beam_id: int = beam.entity_id
	var reports: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"npc_phase_resolved":
			reports.append_array(data["reports"]))
	for round_index: int in 3:
		check(state.get_npc(beam_id) != null, "%d번째 라운드 끝 전에는 판 위에 있다" % (round_index + 1))
		manager._enter_neutral_npc_phase()
	check_eq(reports.size(), 3, "라운드 끝마다 한 번씩 3번 움직였다")
	for report: Dictionary in reports:
		var steps: int = (report["path"] as Array).size()
		check(steps >= NpcSweep.BEAM_MIN and steps <= NpcSweep.BEAM_MAX, "한 번에 3~5칸 (%d칸)" % steps)
		check([1, -1].has(int(report["direction"])), "방향은 정방향 또는 역방향")
	check(not bool(reports[0]["vanished"]) and not bool(reports[1]["vanished"]), "처음 두 번은 남는다")
	check_eq(int(reports[1]["rounds_left"]), 1, "두 번 움직이면 1라운드 남음")
	check(bool(reports[2]["vanished"]), "세 번째 이동 뒤 수명이 다한다")
	check(state.get_npc(beam_id) == null, "3라운드가 지나 스스로 사라졌다")
	_dispose(manager)


func test_direction_and_distance_are_random_but_deterministic() -> void:
	var seen_dirs: Dictionary = {}
	var seen_steps: Dictionary = {}
	var first: Array = []
	for seed_value: int in range(1, 25):
		var manager := _new_manager(seed_value)
		var beam: NeutralNPC = _summon(manager)
		var report: Dictionary = beam.run_ai(manager.state)
		seen_dirs[int(report["direction"])] = true
		seen_steps[(report["path"] as Array).size()] = true
		if seed_value == 3:
			first = [int(report["direction"]), (report["path"] as Array).size()]
		_dispose(manager)
	check(seen_dirs.has(1) and seen_dirs.has(-1), "여러 판에서 양쪽 방향이 다 나온다")
	check(seen_steps.has(3) and seen_steps.has(5), "3칸과 5칸이 다 나온다")
	var again := _new_manager(3)
	var report_again: Dictionary = _summon(again).run_ai(again.state)
	check_eq([int(report_again["direction"]), (report_again["path"] as Array).size()], first, "같은 시드면 같은 방향·칸 수 (온라인 동기화)")
	_dispose(again)


func test_goal_tile_is_passed_without_burning() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var beam: NeutralNPC = _summon(manager)
	beam.current_tile_idx = 2
	var waiting: PlayerPawn = state.pawns_of(1)[0]
	waiting.reset_to_start()
	var run: Dictionary = NpcSweep.burn(state, beam, -1, 4)
	check_eq(beam.current_tile_idx, posmod(2 - 4, BoardSpec.tile_count), "출발선을 지나 계속 미끄러진다")
	check(not waiting.has_left_start and not (run["ejected"] as Array).has(waiting.entity_id), "출발선에서 기다리는 말은 건드리지 않는다")
	_dispose(manager)


func test_snapshot_keeps_the_remaining_lifetime() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var beam: NeutralNPC = _summon(manager)
	beam.rounds_left = 2
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	beam.rounds_left = 0
	snapshot.restore(state)
	check_eq(state.npcs[0].rounds_left, 2, "스냅샷 복원 뒤에도 남은 수명 2")
	check(state.npcs[0].is_beam(), "빛 기둥 그대로")
	_dispose(manager)


func test_danger_preview_marks_both_directions() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var beam: NeutralNPC = _summon(manager)
	var start: int = beam.current_tile_idx
	_place(state.pawns_of(2)[0], start - 2)
	var preview: Dictionary = beam.danger_preview(state)
	var tiles: Array = preview["tiles"]
	check_eq(int(preview["direction"]), 0, "방향을 모른다 (화살표 없음)")
	check(tiles.has(start + 1) and tiles.has(start + 5) and tiles.has(start - 1) and tiles.has(start - 5), "양쪽으로 5칸까지 위험")
	check((preview["catch_tiles"] as Array).has(start - 2), "말이 있는 칸은 잡힐 수 있는 칸")
	check(float(preview["chance"]) > 0.0 and float(preview["chance"]) <= 0.5, "방향이 반반이라 확률은 50% 이하")
	_dispose(manager)

