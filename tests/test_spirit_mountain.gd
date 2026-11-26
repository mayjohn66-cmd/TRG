# File: res://tests/test_spirit_mountain.gd
# Class: class_name TestSpiritMountain
# Role: 정령산 보드 (1.3) - 빵집·옷장 자리 6곳이 정령 칸, 판 시작·매 라운드 정령을 무작위 재배치(결정적, 땅은 22·30번 중 한 곳: 1.3.1),
#       불(딱 멈추면 1칸 뒤로)·물(카드 1장)·바람(1칸 앞으로)·땅(지나가기만 해도 정지), 스냅샷, 정령산 순례(LAW_02판) 기록.
class_name TestSpiritMountain
extends TestCase


func _spirit_state(seed_value: int = 12345) -> GameState:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.match_rules = {"board": "spirit_mountain"}
	state.setup([1, 2] as Array[int], seed_value)
	return state


func _saved() -> Array:
	return [BoardSpec.tile_count, BoardSpec.board_id, BoardCatalog.current_id]


func _restore(saved: Array) -> void:
	var def: Dictionary = BoardCatalog.def_of(saved[1])
	BoardSpec.apply(int(saved[0]), def["portal"], def["shop"], saved[1])
	BoardCatalog.current_id = saved[2]
	AugmentRegistry.apply_board_variants()


## 정령 칸 하나에 원하는 정령을 앉힌다 (그 칸 번호를 돌려준다).
func _put(state: GameState, spirit: StringName, index: int = 0) -> int:
	var tile: int = BoardSpec.spirit_tiles[index]
	state.spirits[tile] = spirit
	return tile


func test_layout_puts_spirits_on_bakery_and_wardrobe_spots() -> void:
	var classic: Dictionary = BoardSpec.layout_for(32)
	var mountain: Dictionary = BoardCatalog.layout_of(&"spirit_mountain")
	var expected: Array = (classic["bakery_tiles"] as Array) + (classic["portal_tiles"] as Array)
	expected.sort()
	check_eq(mountain["spirit_tiles"], expected, "정령 칸 6곳 = 빵집 4곳 + 옷장 2곳 자리")
	check((mountain["bakery_tiles"] as Array).is_empty() and (mountain["portal_tiles"] as Array).is_empty(), "빵집·옷장은 없다 (그 자리가 정령 칸)")
	check((mountain["portal_warp_targets"] as Dictionary).is_empty(), "워프 없음")
	check((classic["spirit_tiles"] as Array).is_empty(), "다른 보드에는 정령 칸이 없다")


func test_spirits_are_placed_evenly_and_deterministically() -> void:
	var saved: Array = _saved()
	var state := _spirit_state(4242)
	check_eq(BoardSpec.board_id, &"spirit_mountain", "정령산을 적용한다")
	check_eq(state.spirits.size(), 6, "정령 칸 6곳 모두에 정령")
	var counts: Dictionary = {}
	for tile: int in BoardSpec.spirit_tiles:
		check(state.board.get_tile(tile).tile_type == TileNode.TileType.SPIRIT, "%d번은 정령 칸" % tile)
		var spirit: StringName = MountainSpirits.at(state, tile)
		counts[spirit] = int(counts.get(spirit, 0)) + 1
	check_eq(counts.size(), 4, "네 종류가 모두 깃든다 (%s)" % str(counts))
	check_eq(int(counts.get(MountainSpirits.EARTH, 0)), 1, "땅 정령은 언제나 한 곳")
	for spirit: StringName in counts:
		check(int(counts[spirit]) >= 1 and int(counts[spirit]) <= 2, "종류마다 1~2곳 (고르게): %s %d" % [spirit, counts[spirit]])
	var again := _spirit_state(4242)
	check_eq(again.spirits, state.spirits, "같은 시드면 같은 배치 (온라인 참가자 모두 같은 결과)")
	var arrangements: Dictionary = {}
	for seed_value: int in range(1, 30):
		arrangements[str(_spirit_state(seed_value).spirits)] = true
	check(arrangements.size() > 5, "시드마다 배치가 달라진다 (%d가지)" % arrangements.size())
	_restore(saved)


func test_earth_spirit_only_settles_on_the_two_tiles_nearest_the_goal() -> void:
	# 1.3.1 제보: 출발 직후 칸에 땅이 깃들면 모두가 매 턴 막혔다 -> 땅은 32칸 판의 22·30번 중 한 곳에만
	var saved: Array = _saved()
	_spirit_state(1)
	check_eq(MountainSpirits.earth_spots(), [22, 30] as Array[int], "땅 자리는 22·30번")
	var seen: Dictionary = {}
	for seed_value: int in range(1, 60):
		var state := _spirit_state(seed_value)
		for tile: int in state.spirits:
			if state.spirits[tile] == MountainSpirits.EARTH:
				check(tile == 22 or tile == 30, "땅 정령은 22·30번에만 (시드 %d: %d번)" % [seed_value, tile])
				seen[tile] = true
	check_eq(seen.size(), 2, "두 칸 모두 나올 수 있다")
	_restore(saved)


func test_spirits_reshuffle_every_round() -> void:
	var saved: Array = _saved()
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	manager.match_rules = {"board": "spirit_mountain"}
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 777)
	var shifted: Array[int] = [0]
	manager.state.spirits_shifted.connect(func() -> void: shifted[0] += 1)
	var first: Dictionary = manager.state.spirits.duplicate()
	check_eq(first.size(), 6, "판 시작에 정령을 놓는다")
	var changed: bool = false
	for round_number: int in range(2, 12):
		manager.state.round_number = round_number
		manager._enter_round_start()
		changed = changed or manager.state.spirits != first
	check_eq(shifted[0], 10, "매 라운드 다시 놓는다 (%d번)" % shifted[0])
	check(changed, "다시 놓으면 배치가 바뀐다")
	tree.root.remove_child(manager)
	manager.free()
	_restore(saved)


func test_fire_water_wind_trigger_on_exact_stop() -> void:
	var saved: Array = _saved()
	var state := _spirit_state()
	var tile: int = _put(state, MountainSpirits.FIRE, 1)
	place(state, 11, tile - 2, [tile - 3])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.spirit, MountainSpirits.FIRE, "불 정령을 받는다")
	check_eq(state.get_pawn(11).current_tile_idx, tile - 1, "불: 1칸 뒤로")
	_put(state, MountainSpirits.WATER, 1)
	place(state, 11, tile - 2, [tile - 3])
	var hand_before: int = (state.hands[1] as Array).size()
	report = move(state, 11, 2)
	check_eq(report.spirit, MountainSpirits.WATER, "물 정령을 받는다")
	check((state.hands[1] as Array).size() == hand_before + 1, "물: 카드 1장")
	check_eq(state.get_pawn(11).current_tile_idx, tile, "물: 제자리")
	_put(state, MountainSpirits.WIND, 1)
	place(state, 11, tile - 2, [tile - 3])
	report = move(state, 11, 2)
	check_eq(report.spirit, MountainSpirits.WIND, "바람 정령을 받는다")
	check_eq(state.get_pawn(11).current_tile_idx, tile + 1, "바람: 1칸 앞으로")
	# 불·물·바람은 지나가기만 하면 아무 일도 없다
	for spirit: StringName in [MountainSpirits.FIRE, MountainSpirits.WATER, MountainSpirits.WIND]:
		_put(state, spirit, 1)
		place(state, 11, tile - 1, [tile - 2])
		report = move(state, 11, 3)
		check_eq(report.spirit, &"", "%s 정령은 지나가면 효과 없음" % spirit)
		check_eq(state.get_pawn(11).current_tile_idx, tile + 2, "%s 정령을 지나 그대로 간다" % spirit)
	_restore(saved)


func test_earth_stops_passing_pawns_and_counts_pilgrimage() -> void:
	var saved: Array = _saved()
	var state := _spirit_state()
	var tile: int = _put(state, MountainSpirits.EARTH, 1)
	place(state, 11, tile - 2, [tile - 3])
	var visits_before: int = state.stat(1, VictoryLaw.BAKERY)
	var report: MoveReport = move(state, 11, 5)
	check_eq(report.spirit, MountainSpirits.EARTH, "땅 정령을 받는다")
	check(report.stopped_early, "지나가던 이동이 멈춘다")
	check_eq(state.get_pawn(11).current_tile_idx, tile, "땅: 지나가기만 해도 그 칸에서 정지")
	check_eq(state.stat(1, VictoryLaw.BAKERY), visits_before + 1, "정령 칸에 멈춘 것도 순례 기록 (빵집 방문 기록)")
	place(state, 11, tile - 1, [tile - 2])
	report = move(state, 11, 1)
	check_eq(report.spirit, MountainSpirits.EARTH, "땅 정령에 딱 멈춰도 받는다 (그냥 멈춤)")
	check_eq(state.get_pawn(11).current_tile_idx, tile, "그 칸에 그대로")
	check(BoardSpec.is_special_tile(tile), "정령 칸에는 일반 함정을 깔 수 없다")
	_restore(saved)


func test_spirits_survive_a_turn_snapshot() -> void:
	var saved: Array = _saved()
	var state := _spirit_state()
	var before: Dictionary = state.spirits.duplicate()
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.spirits = {}
	snapshot.restore(state, true)  # 정령은 라운드 시작에만 바뀌므로 판 전체를 맞출 때(meta) 되돌린다
	check_eq(state.spirits, before, "되감기·온라인 동기화 스냅샷에 정령 배치가 들어 있다")
	_restore(saved)


func test_pilgrimage_variant_replaces_the_bakery_law() -> void:
	var saved: Array = _saved()
	_spirit_state()
	AugmentRegistry.apply_board_variants()
	var law := VictoryLaw.new("LAW_02")
	check_eq(law.law_name, "정령산 순례", "빵집이 없는 정령산에서는 LAW_02가 정령산 순례")
	check(law.condition_text().contains("정령 칸"), "조건: 정령 칸에 멈춤")
	check(AugmentRegistry.get_def(&"AUG_LAW_02").title.contains("정령산 순례"), "선택 카드 제목도 바뀐다")
	check(not AugmentRegistry.get_def(&"AUG_LAW_02").desc.contains("빵집"), "선택 카드 설명에서 빵집이 정령 칸으로")
	_restore(saved)
	check_eq(VictoryLaw.new("LAW_02").law_name, "봉인된 에르핀의 식권", "되돌리면 원래 이름")
