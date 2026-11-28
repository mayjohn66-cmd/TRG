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
	check_eq(state.stat(1, VictoryLaw.BAKERY), visits_before + 1, "정령 칸에 멈춘 것도 원기옥 기록 (빵집 방문 기록)")
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


func test_spirit_bomb_variant_replaces_the_bakery_law() -> void:
	var saved: Array = _saved()
	_spirit_state()
	AugmentRegistry.apply_board_variants()
	var law := VictoryLaw.new("LAW_02")
	check_eq(law.law_name, "정령 원기옥", "빵집이 없는 정령산에서는 LAW_02가 정령 원기옥")
	check(law.condition_text().contains("정령 칸"), "조건: 정령 칸에 멈춤")
	check(AugmentRegistry.get_def(&"AUG_LAW_02").title.contains("정령 원기옥"), "선택 카드 제목도 바뀐다")
	check(not AugmentRegistry.get_def(&"AUG_LAW_02").desc.contains("빵집"), "선택 카드 설명에서 빵집이 정령 칸으로")
	_restore(saved)
	check_eq(VictoryLaw.new("LAW_02").law_name, "봉인된 에르핀의 식권", "되돌리면 원래 이름")


## 정령 원기옥 (HANDOFF-015): 전용 아이콘·도입 무대·효과음·만화 제목, 옛 순례·식권 연출이 남지 않는다.
func test_spirit_bomb_stage_icon_and_cues() -> void:
	var saved: Array = _saved()
	_spirit_state()
	AugmentRegistry.apply_board_variants()
	var variant: Dictionary = VictoryLaw.variant("LAW_02")
	check_eq(str(variant.get("result_phrase", "")), "SPIRIT BOMB!", "만화 제목은 SPIRIT BOMB!")
	check_eq(StringName(variant.get("stage", &"")), &"spirit_bomb", "전용 도입 무대")
	check(ResourceLoader.exists(AugmentArt.ROOT + str(variant["icon"])), "전용 아이콘이 있다")
	var icon: Texture2D = load(AugmentArt.ROOT + str(variant["icon"]))
	check(icon.get_width() <= 512 and icon.get_height() <= 512, "아이콘은 512px 이하")
	var prelude := preload("res://scenes/law_victory_prelude.gd")
	check(prelude.board_stage("LAW_02") == preload("res://scenes/spirit_bomb_stage.gd"), "식권 무대 대신 원기옥 무대")
	check(is_equal_approx(prelude.duration_for("LAW_02"), 2.86) and is_equal_approx(prelude.impact_at("LAW_02"), 2.26), "도입 2.86초 · 착탄 2.26초")
	var cues := PresentationAudio.victory_plan("LAW_02", 0.0, -1.0, false)
	var gathers := cues.filter(func(entry: Dictionary) -> bool: return entry.event == &"spirit_orb_gather")
	check_eq(gathers.size(), 6, "빛방울 6묶음마다 차징 톤")
	check(is_equal_approx(float(gathers[0].at), 0.22) and is_equal_approx(float(gathers[5].at), 0.22 + 5 * 0.23), "합류 톤 0.22 + i·0.23초")
	check(cues.any(func(entry: Dictionary) -> bool: return entry.event == &"spirit_bomb_burst" and is_equal_approx(float(entry.at), 2.26)), "착탄 2.26초에 폭발음")
	check(cues.any(func(entry: Dictionary) -> bool: return entry.event == &"dash" and is_equal_approx(float(entry.at), 1.88)), "투하 1.88초에 풍절음")
	check(not cues.any(func(entry: Dictionary) -> bool: return entry.event in [&"ticket_rustle", &"ticket_join"]), "식권 효과음은 없다")
	check(Sfx.SYNTH.has(&"spirit_orb_gather") and Sfx.SYNTH.has(&"spirit_bomb_burst"), "합성음 두 개")
	var geometry: Dictionary = preload("res://scenes/victory_title_geometry_data.gd").DATA
	check(geometry.has("LAW_02:S:0") and geometry["LAW_02:S:0"]["text"] == "SPIRIT" and geometry["LAW_02:S:1"]["text"] == "BOMB!", "제목 윤곽 데이터는 SPIRIT / BOMB!")
	var stamp: String = str(BoardCatalog.SHOP_KINDS[&"spirit"]["visit_stamp"])
	check(stamp.contains("기운") and not stamp.contains("순례"), "정령 칸 도장 문구에 순례가 없다")
	# 무대: 시각만으로 정해진다 (같은 시각 = 같은 원기옥), 합류마다 6단계로 커진다
	var stage_script := preload("res://scenes/spirit_bomb_stage.gd")
	check_eq(stage_script.merged(0.0), 0, "처음엔 합류 없음")
	check_eq(stage_script.merged(stage_script.merge_at(5)), 6, "1.63초에 6묶음 합류")
	check(is_equal_approx(stage_script.merge_at(5), 1.63), "마지막 합류 1.63초")
	var last := 0.0
	for index: int in 6:
		var settled: float = stage_script.orb_radius(stage_script.merge_at(index) + 0.21)
		check(settled > last, "합류 %d번째에 원기옥이 커진다" % (index + 1))
		last = settled
	check(is_equal_approx(last, 136.0), "최대 반지름 136px")
	check_eq(stage_script.drop_progress(1.87), 0.0, "투하 전에는 머리 위")
	check(is_equal_approx(stage_script.drop_progress(2.26), 1.0), "2.26초에 착탄")
	check(stage_script.drop_progress(2.07) < 0.5, "투하는 ease_in (처음이 느리다)")
	var a := stage_script.new() as Control
	var b := stage_script.new() as Control
	a.setup(Vector2(683, 500), Vector2(1366, 768))
	b.setup(Vector2(683, 500), Vector2(1366, 768))
	a.seek(1.95, Vector2(1366, 768))
	b.seek(0.5, Vector2(1366, 768))
	b.seek(1.95, Vector2(1366, 768))
	check(a.orb_center().is_equal_approx(b.orb_center()), "되감아도 같은 위치 (결정론)")
	for view: Vector2 in [Vector2(1366, 768), Vector2(960, 540)]:
		a.setup(Vector2(683, 335), Vector2(1366, 768))
		a.seek(1.84, view)
		var painted_radius: float = stage_script.orb_radius(1.84) * 1.4 * minf(view.x / 1366.0, view.y / 768.0)
		check(a.orb_center().y - painted_radius >= 0.0, "최대 응집의 붓결이 화면 위로 잘리지 않는다")
	a.seek(stage_script.INTRO_SECONDS, Vector2(1366, 768))
	var final_frame := Rect2(a._blast.position, a._blast.size)
	var same_sprite: TextureRect = a._blast
	a.seek(stage_script.INTRO_SECONDS + 1.5, Vector2(1366, 768))
	check(a._blast == same_sprite and a._blast.visible, "폭발 객체가 사라지지 않고 승리 삽화까지 이어진다")
	check(Rect2(a._blast.position, a._blast.size).is_equal_approx(final_frame), "폭발 마지막 구도 그대로 정지 일러스트로 이어진다")
	check(is_equal_approx(float((a._blast.material as ShaderMaterial).get_shader_parameter("printed")), 1.0), "같은 폭발 그림이 인쇄 색상으로 전환된다")
	a.free()
	b.free()
	var preview_before: StringName = VictoryLaw.preview_board
	VictoryLaw.preview_board = &"classic"
	var ticket := preload("res://scenes/victory_symbol_background.gd").new()
	ticket.setup("LAW_02")
	check(not ticket._pattern.textures.has("spirit_bomb"), "기본 보드 식권 승리에는 정령산 배경을 넣지 않는다")
	ticket.free()
	VictoryLaw.preview_board = preview_before
	check(stage_script.BLAST_ART.get_width() <= 768, "전용 폭발 그림 런타임 해상도 제한")
	_restore(saved)
