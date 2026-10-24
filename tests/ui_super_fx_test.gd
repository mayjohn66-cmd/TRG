# File: res://tests/ui_super_fx_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 초증강 전용 보드 연출 검사. 게임 판을 띄워 첫 증강 드래프트가 열린 뒤, 초증강 11종(SUPER_01~10, 12)을 하나씩 실제 드래프트 경로로 적용하고
#       (엔진 변화 기록 → 연출 단계를 그 선택의 단계들 앞에 끼움 → [선택한 증강] 공개 뒤 재생) 연출이 재생되고 제때 끝나며,
#       끝난 뒤 말 층에 연출 조각이 남지 않는지(누수 없음), 지속 표시(악마의 계약·도박사 불꽃, 연대책임 고리)가 켜지는지 본다.
#       실행: godot --headless --path . -s res://tests/ui_super_fx_test.gd
extends SceneTree

const EFFECTS: Array[StringName] = [&"SUPER_01", &"SUPER_02", &"SUPER_03", &"SUPER_04", &"SUPER_05", &"SUPER_06", &"SUPER_07", &"SUPER_08", &"SUPER_09", &"SUPER_10", &"SUPER_12"]

var _failures: Array[String] = []
var _board: MainBoard = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for effect: StringName in EFFECTS:
		await _check(effect)
	await _check_several_in_one_draft()
	if _failures.is_empty():
		print("UI_SUPER_FX_OK: %d super augments" % EFFECTS.size())
		quit(0)
	else:
		for failure: String in _failures:
			print("UI_SUPER_FX_FAIL: " + failure)
		quit(1)


func _check(effect: StringName) -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard: int = 0
	while (not _board._draft_open or _board._intro_blocks()) and guard < 2400:
		guard += 1
		await process_frame
	if not _board._draft_open:
		_failures.append("%s: 드래프트가 열리지 않았다" % effect)
		await _drop_board()
		return
	_stage(effect)
	var layer_before: int = _live_children(_board._pawn_layer)
	var aug_id: StringName = &""
	for def: AugmentDef in AugmentRegistry.all():
		if def.category == GameEnums.AugmentCategory.SUPER_GAMBLE and def.payload == effect:
			aug_id = def.augment_id
	_board._super_changes.clear()
	# 내가 받는 카드는 한 장씩 앞면을 크게 보여 준 뒤 손패로 들어간다 (묶음이면 빨리 감기): 그만큼 연출 시간 예산을 늘린다
	var local_cards: Array[int] = [0]
	var count_card: Callable = func(player_id: int, _card_id: StringName) -> void:
		if player_id == _board._dock_owner():
			local_cards[0] += 1
	_board.state.card_drawn.connect(count_card)
	var result: Dictionary = SuperAugments.apply(effect, _board.state, 1)
	_expect(bool(result.get("ok", false)), "%s 적용 (%s)" % [effect, result.get("text", "")])
	_board._on_super_picked(1, aug_id)
	_board._pick_serial += 1
	_expect(not _board._draft_deferred.is_empty(), "%s: 연출 단계가 공개 뒤로 미뤄졌다" % effect)
	if effect == &"SUPER_03":
		_expect(_board._flame_colors(1).is_empty(), "악마의 계약 불꽃은 연출 전에 미리 켜지지 않는다")
	await process_frame
	_board._draft_open = false
	var started: int = Time.get_ticks_msec()
	_board._release_draft_deferred()
	while _board._presentation_active() and Time.get_ticks_msec() - started < 14000:
		await process_frame
	var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
	_expect(not _board._presentation_active(), "%s: 연출 큐가 끝난다 (%.2f초)" % [effect, elapsed])
	_board.state.card_drawn.disconnect(count_card)
	var budget: float = 6.0 + 1.0 * float(local_cards[0])
	if effect == &"SUPER_02":
		budget += (load("res://scenes/redistribution_stage.gd") as GDScript).get_constant_map()["TOTAL_TIME"]  # 손패 회수 → 진도 정렬 → 섞기 → 덱 복귀 무대만큼 더
	_expect(elapsed >= 0.6 and elapsed <= budget, "%s: 연출 시간 %.2f초 (예산 %.1f초, 내 카드 %d장)" % [effect, elapsed, budget, local_cards[0]])
	match effect:
		&"SUPER_03":
			_expect(not _board._flame_colors(1).is_empty() and _board._profiles[1]["panel"].get_node_or_null("SuperFlame") != null, "악마의 계약: 프로필에 영구 불꽃 테두리")
		&"SUPER_06":
			_expect(_board._profiles[1]["panel"].get_node_or_null("SuperFlame") != null, "도박사의 영혼: 프로필에 황금 불꽃")
			# 굴림 결과: 배수 임팩트와 과열 연기 (주사위 위)
			_board._gambler_flash[1] = 2
			_board._show_gambler_flash(1)
			_board._gambler_flash[1] = -1
			_board._show_gambler_flash(1)
			_expect(_board._gambler_flash.is_empty(), "도박사 굴림 표시는 한 번 쓰고 지운다")
		&"SUPER_12":
			var rings: int = 0
			for view: Node2D in _board._pawn_views.values():
				if view.get_node_or_null("BondRing") != null:
					rings += 1
			_expect(rings == 2, "연대책임: 묶인 두 말 발밑 고리 (%d)" % rings)
	# 잠깐 뒤 연출 조각이 모두 사라진다 (말 층 노드 수가 처음과 비슷하게 돌아온다)
	var settle: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 1800:
		await process_frame
	var leftover: int = _live_children(_board._pawn_layer) - layer_before
	_expect(leftover <= 3, "%s: 연출 조각이 남지 않는다 (+%d)" % [effect, leftover])
	await _drop_board()


## 말 층의 자식 수 (풀에서 다음 연출을 기다리며 숨어 있는 노드는 빼고 센다).
func _live_children(layer: Node) -> int:
	return layer.get_children().filter(func(node: Node) -> bool: return not (FxPool.is_pooled(node) and not bool(node.get_meta(FxPool.BUSY_META, false)))).size()


## 한 드래프트에서 여럿이 초증강을 고르면: 엔진은 고른 순서대로 적용하고, 연출은 [선택한 증강] 공개 뒤 고른 순서대로 하나씩
## (앞 연출이 끝나야 다음 연출이 시작, 동시에 겹치지 않는다).
func _check_several_in_one_draft() -> void:
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var guard: int = 0
	while (not _board._draft_open or _board._intro_blocks()) and guard < 2400:
		guard += 1
		await process_frame
	if not _board._draft_open:
		_failures.append("여럿 선택: 드래프트가 열리지 않았다")
		await _drop_board()
		return
	_stage(&"SUPER_07")
	var picks: Array = [[2, &"SUPER_07"], [3, &"SUPER_01"], [1, &"SUPER_06"]]
	for pick: Array in picks:
		var aug_id: StringName = &""
		for def: AugmentDef in AugmentRegistry.all():
			if def.category == GameEnums.AugmentCategory.SUPER_GAMBLE and def.payload == pick[1]:
				aug_id = def.augment_id
		_board._super_changes.clear()
		SuperAugments.apply(pick[1], _board.state, int(pick[0]))
		_board._on_super_picked(int(pick[0]), aug_id)
		_board._pick_serial += 1
	await process_frame
	var keys: Array = ["2:SUPER_07", "3:SUPER_01", "1:SUPER_06"]
	_expect(keys.all(func(key: String) -> bool: return _board._super_hidden.has(key)), "여럿 선택: 공개 전에는 어느 초증강 연출도 시작하지 않는다")
	_board._draft_open = false
	var started_at: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	_board._release_draft_deferred()
	while _board._presentation_active() and Time.get_ticks_msec() - t0 < 30000:
		for key: String in keys:
			if not started_at.has(key) and not _board._super_hidden.has(key):
				started_at[key] = Time.get_ticks_msec() - t0
				# 다음 연출이 시작할 때 앞 연출은 끝나 있다: 시작한 초증강은 하나씩만 (아직 시작 안 한 것은 그대로 숨김)
				var waiting: int = keys.filter(func(other: String) -> bool: return _board._super_hidden.has(other)).size()
				_expect(waiting == keys.size() - started_at.size(), "여럿 선택: %s가 시작할 때 뒤 순서 연출은 아직 기다린다" % key)
		await process_frame
	_expect(started_at.size() == keys.size(), "여럿 선택: 세 연출이 모두 나온다 (%s)" % str(started_at))
	if started_at.size() == keys.size():
		_expect(int(started_at[keys[0]]) < int(started_at[keys[1]]) and int(started_at[keys[1]]) < int(started_at[keys[2]]), "여럿 선택: 고른 순서대로 (%s)" % str(started_at))
		_expect(int(started_at[keys[1]]) - int(started_at[keys[0]]) >= 500 and int(started_at[keys[2]]) - int(started_at[keys[1]]) >= 500, "여럿 선택: 앞 연출이 끝난 뒤 다음 연출 (%s)" % str(started_at))
	await _drop_board()


## 보드 위에 말을 흩어 놓는다 (연출에 등장할 말이 있게).
func _stage(effect: StringName) -> void:
	var st: GameState = _board.state
	var places: Dictionary = {1: [6, 13, 21], 2: [9, 17], 3: [3, 26], 4: [11, 30]}
	for player_id: int in places:
		var mine: Array[PlayerPawn] = st.pawns_of(player_id)
		for index: int in (places[player_id] as Array).size():
			mine[index].has_left_start = true
			mine[index].current_tile_idx = int(places[player_id][index])
	if effect == &"SUPER_03":
		st.pawns_of(1)[3].is_finished = true
	if effect == &"SUPER_05":
		for player_id: int in [2, 3, 4]:
			(st.hands[player_id] as Array).append(&"ACT_02")
	for pawn: PlayerPawn in st.pawns:
		var view: Node2D = _board._pawn_views.get(pawn.entity_id)
		if view != null:
			_board._kill_fx(view)
			view.position = _board._pawn_position(pawn)
			view.visible = pawn.has_left_start and not pawn.is_finished
	if _board._draft_overlay != null:
		_board._draft_overlay.visible = false
	_board._announcer.cancel()


func _drop_board() -> void:
	_board.queue_free()
	_board = null
	await process_frame
	await process_frame


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
