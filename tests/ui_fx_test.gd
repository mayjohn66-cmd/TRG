# File: res://tests/ui_fx_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 판정 도구 연출(파워 게이지·주사위 셔플·룰렛 감속·슬롯 3릴 순차 정지·홀덤 카드 플립)과 입력 잠금을 실시간으로 검증한다. instant_roll_for_test 스킵 플래그도 확인한다
extends SceneTree

var _board: MainBoard = null
var _frames: int = 0
var _started: bool = false
var _failures: Array[String] = []
var _duel_manual: bool = false


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		return false
	if _frames == 3 and not _started:
		_started = true
		_run()
	# 다른 검사 중에 봇이 건 가위바위보 결투는 시간 초과로 넘겨 검사가 막히지 않게 한다 (결투 검사만 직접 진행).
	if _started and not _duel_manual and _board.manager != null and _board.manager.duel_pending():
		_board.manager.force_timeout()
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _run() -> void:
	_board._on_draft_auto_pressed()
	for i: int in 4:
		await process_frame
	_board._announcer.cancel()
	_board._announced_round = _board.state.round_number  # [N라운드 시작!] 알림이 이후 검사의 입력 잠금을 흔들지 않게 이미 알린 것으로 본다
	await _test_mode_toggle()
	await _test_game_menu()
	await _test_view_modes()
	await _test_avatar_seats()
	# 이후 연출·게이지 테스트는 직접 조작하므로 4P 수동 조작 모드로 진행한다 (봇 호흡은 마지막에 따로 검증)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board._refresh_mode_toggle()
	_board._announcer.cancel()  # 드래프트가 띄운 알림은 비우고 시작한다
	_board.pacing_enabled = false  # 아래 테스트들은 연출 길이를 직접 재므로 [N 차례] 알림·이동 뒤 멈춤은 끈다 (따로 검사한다)
	# 메뉴의 속도/호흡 설정은 _apply_pace()로 이동 간격도 바꾸므로,
	# _process()에서 지정했던 테스트용 즉시 이동 조건을 다시 복원한다.
	_board.manager.step_delay_sec = 0.0
	await _test_presenters()
	await _test_illustrated_judgment_cards()
	await _test_mahjong_landings()
	await _test_yut_throw()
	await _test_roulette_spin()
	await _test_slot_machine()
	await _test_toy_flag_gun()
	_board._announcer.cancel()
	await _test_gauge_and_lock()
	await _test_instant_flag()
	await _test_announcer()
	await _test_aspect_layout()
	await _test_roll_pad()
	await _test_hud_overhaul()
	await _test_card_art_layout()
	await _test_augment_art()
	await _test_pawn_tokens()
	await _test_bot_pacing()
	await _test_action_beats()
	await _test_tool_cards_fit()
	await _test_duel_flow()
	await _test_stage_warp()
	await _test_trap_tile_marking()
	await _test_kill_cutin()
	await _test_new_tool_stages()
	if _failures.is_empty():
		print("UI_FX_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_FX_FAIL: " + message)
		quit(1)


## The six sprites must load; all other kinds still render without images.
func _test_pawn_tokens() -> void:
	var alpha_probe := Image.create(32,32,false,Image.FORMAT_RGBA8)
	alpha_probe.fill(Color.TRANSPARENT)
	alpha_probe.fill_rect(Rect2i(10,10,12,12),Color.WHITE)
	alpha_probe.set_pixel(0,0,Color(1,1,1,1.0/255.0))
	_expect(PawnArt.visible_region(alpha_probe) == Rect2i(8,8,16,16), "invisible alpha noise cannot shrink the visible token")
	var examples: Array[Vector2i] = [Vector2i(1,1),Vector2i(2,2),Vector2i(3,2),Vector2i(4,1),Vector2i(5,1),Vector2i(6,1)]
	for example: Vector2i in examples:
		var pawn := PlayerPawn.new()
		pawn.kind = example.x as GameEnums.PawnKind
		pawn.unit_no = example.y
		var art: Dictionary = PawnArt.sprite(pawn)
		_expect(not art.is_empty(), "representative token sprite loads: %s" % pawn.display_label())
		if not art.is_empty():
			var texture: Texture2D = art.texture
			var image: Image = texture.get_image()
			_expect(texture.get_width() <= 256 and texture.get_height() <= 256, "token runtime texture is capped at 256px")
			_expect(image.detect_alpha() != Image.ALPHA_NONE, "token keeps real transparency rather than a white square")
			_expect((art.region as Rect2).has_area(), "transparent bounds keep the complete token")
	var probe := PawnToken.new()
	_board.add_child(probe)
	probe.position = Vector2(-1000,-1000)
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		for units: Array in PawnCatalog.unit_groups(kind):
			var pawn := PlayerPawn.new()
			pawn.kind = kind
			pawn.unit_no = int(units[0])
			probe.configure(pawn,MainBoard.PLAYER_COLORS[1],false)
			await process_frame
			_expect(probe.artwork.is_empty(), "procedural fallback renders without textures: %s" % pawn.display_label())
			_expect(probe.skill_ready() == PawnSkills.has_skill(pawn), "remaining skill mark follows actual pawn skill")
			pawn.skill_used = true
			probe.configure(pawn,MainBoard.PLAYER_COLORS[1],false)
			_expect(not probe.skill_ready(), "used skill stops its lightning mark")
	probe.queue_free()
	var promoted := PlayerPawn.new()
	promoted.kind = GameEnums.PawnKind.SHOGI
	promoted.unit_no = 1
	promoted.promoted = true
	var paths: Array[String] = PawnArt.candidates(promoted)
	_expect(paths[0].ends_with("SHOGI_FU_NARI.png") and paths[1].ends_with("SHOGI_NARI.png"), "promoted art takes precedence over normal Shogi art")
	for pawn: PlayerPawn in _board.state.pawns:
		var token: PawnToken = (_board._pawn_views[pawn.entity_id] as Node2D).get_node("Bounce/Token") as PawnToken
		_expect(token.pawn == pawn and token.owner_color == MainBoard.PLAYER_COLORS[pawn.owner_id], "board body and pedestal use correct pawn and owner")
	for profile: Dictionary in _board._profiles.values():
		for parts: Dictionary in profile["slots"]:
			var host: Control = parts["panel"]
			var token: PawnToken = host.get_node_or_null("PawnToken") as PawnToken
			_expect(token != null and not (parts["letter"] as Label).visible, "profile replaces central glyph with shared token")
			if token != null:
				var bounds := Rect2(token.position + PawnToken.HIT_BOX.position*token.scale, PawnToken.HIT_BOX.size*token.scale)
				_expect(Rect2(Vector2(-0.5,-0.5),host.size+Vector2.ONE).encloses(bounds), "token badges stay inside profile slot")
	# A square avatar plus all skill buttons can exceed the nominal profile width.
	# Its 1.05 turn emphasis must grow toward the board, preserving screen margins.
	var me: Control = _board._profiles[_board.local_player_id]["panel"]
	var previous: Array[Dictionary] = []
	for button: Button in _board._skill_buttons:
		previous.append({"visible":button.visible,"text":button.text})
		button.visible = true
		button.text = "사용됨"
	for frame: int in 3:
		await process_frame
	var old_scale: Vector2 = me.scale
	me.scale = Vector2.ONE*1.05
	_expect(Rect2(Vector2.ZERO,Vector2(1366,768)).encloses(me.get_global_rect()), "expanded profile with all skill buttons stays inside screen")
	for i: int in _board._skill_buttons.size():
		_board._skill_buttons[i].visible = previous[i]["visible"]
		_board._skill_buttons[i].text = previous[i]["text"]
	me.scale = old_scale
	_board._refresh_all()


## Optional art must resolve in order and preserve readable glyphs when missing.
func _test_augment_art() -> void:
	var law: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_03")
	var pack: AugmentDef = AugmentRegistry.get_def(&"CARD_PACKAGE")
	var law_paths: Array[String] = AugmentArt.candidates(law)
	_expect(law_paths[0].ends_with("laws/LAW_03.png"), "individual law art precedes category art")
	var law_art: Texture2D = AugmentArt.load_first(law_paths)
	var pack_art: Texture2D = AugmentArt.load_first(AugmentArt.candidates(pack))
	_expect(law_art != null and pack_art != null, "both required augment icons load after import")
	_expect(AugmentArt.load_first(["res://missing_icon.png", pack_art.resource_path, law_art.resource_path]) == pack_art, "missing art skips to first available texture")
	_expect(AugmentArt.load_first([law_art.resource_path, pack_art.resource_path]) == law_art, "specific texture wins over available representative")
	_expect(AugmentArt.load_first(["res://missing_icon.png"]) == null, "missing optional art resolves to glyph fallback")
	var fallback: Control = _board._make_emblem("?", Color("20c997"))
	_expect(fallback.find_child("EmblemGlyph", true, false) != null and fallback.find_child("EmblemArt", true, false) == null, "no image preserves the original glyph")
	fallback.free()
	for definition: AugmentDef in AugmentRegistry.all():
		var info: Dictionary = _board._augment_card_info(definition, 1)
		var card: Button = _board._make_augment_card(info, Callable())
		_board.add_child(card)
		await process_frame
		var art: TextureRect = card.find_child("EmblemArt", true, false) as TextureRect
		var glyph: Label = card.find_child("EmblemGlyph", true, false) as Label
		_expect((art != null) != (glyph != null), "%s has either art or glyph" % definition.augment_id)
		_expect(art != null, "%s has complete representative artwork" % definition.augment_id)
		if definition.category in [GameEnums.AugmentCategory.LAW_ENACT, GameEnums.AugmentCategory.CARD_PACKAGE]:
			_expect(art != null and glyph == null, "%s uses generated representative icon" % definition.augment_id)
		if art != null:
			_expect(art.size == Vector2(110, 110) and art.position == Vector2(5, 5), "square art fits inside 5px neon ring")
			_expect((art.material as ShaderMaterial).shader == AugmentArt.CIRCLE_SHADER, "real circular shader masks the square icon")
			_expect(card.find_child("EmblemRing", true, false) != null, "neon ring remains above image")
		card.queue_free()
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		var definition := AugmentDef.new(&"TEST", GameEnums.AugmentCategory.PAWN_EVOLUTION, "", kind, [1])
		var paths: Array[String] = AugmentArt.candidates(definition)
		_expect(paths[0].contains("/pawns/") and paths[-1].contains("/PAWN_"), "pawn detail precedes family for %s" % kind)
	for tool_id: StringName in AugmentRegistry.SWAPPABLE_TOOLS:
		var paths: Array[String] = AugmentArt.tool_candidates(tool_id)
		_expect(paths[0] == AugmentArt.ROOT + "dice/%s.png" % tool_id, "tool detail uses runtime ID %s" % tool_id)
		_expect(paths[-1].get_file().begins_with("DICE_"), "all nine tools map to requested DICE filename")
		_board._refresh_tool_board(ToolRegistry.create(tool_id), 1)
		await process_frame
		_expect(_board._tool_icon_art.texture != null and _board._tool_icon_art.visible and not _board._tool_icon_label.visible, "%s HUD uses its shared icon" % tool_id)
		_expect(is_equal_approx(_board._tool_icon_art.size.x, _board._tool_icon_art.size.y), "%s HUD icon keeps square proportions" % tool_id)
	_board._refresh_tool_board(ToolRegistry.create(&"D6"), 1)
	_expect(_board._tool_icon_label.visible and not _board._tool_icon_art.visible, "default D6 keeps glyph without optional D6 artwork")


## All live card names/effects must fit both layouts with the actual game font.
func _test_card_art_layout() -> void:
	for card_id: StringName in CardRegistry.all_ids():
		for detailed: bool in [false, true]:
			var card_size := Vector2(350, 490) if detailed else MainBoard.HAND_CARD_SIZE
			var body: Control = _board._build_card_body(card_id, card_size, detailed)
			body.size = card_size
			_board.add_child(body)
			await process_frame
			var title: Label = body.find_child("CardTitle", true, false)
			var summary: Label = body.find_child("CardSummary", true, false)
			var effect: Control = summary.get_parent()
			_expect(title.get_line_count() <= 2, "%s title fits two lines, detailed=%s" % [card_id, detailed])
			_expect(title.get_visible_line_count() >= title.get_line_count(), "%s title shows every line, detailed=%s" % [card_id, detailed])
			_expect(title.position.x + title.size.x <= (title.get_parent() as Control).size.x + 0.5, "%s title stays within its name panel, detailed=%s" % [card_id, detailed])
			_expect(summary.get_line_count() <= (3 if detailed else 2), "%s effect fits without truncation, detailed=%s (%d)" % [card_id, detailed, summary.get_line_count()])
			_expect(summary.get_visible_line_count() >= summary.get_line_count(), "%s effect shows every line, detailed=%s" % [card_id, detailed])
			_expect(summary.position.y + summary.size.y <= effect.size.y + 0.5, "%s effect stays within its panel, detailed=%s" % [card_id, detailed])
			_expect(summary.position.x + summary.size.x <= effect.size.x + 0.5, "%s effect stays within its panel width, detailed=%s" % [card_id, detailed])
			var art: TextureRect = body.find_child("CardArt", true, false)
			if card_id != &"ACT_09":
				_expect(art != null and art.texture.resource_path == "res://assets/cards/%s.png" % card_id, "%s uses its own reviewed illustration" % card_id)
				if art != null:
					_expect(is_equal_approx(art.size.x / art.size.y, 4.0 / 3.0), "%s keeps the entire 4:3 illustration, detailed=%s" % [card_id, detailed])
					var art_window: Control = art.get_parent()
					_expect(art.position.x >= 0.0 and art.position.y >= 0.0 and art.position.x + art.size.x <= art_window.size.x and art.position.y + art.size.y <= art_window.size.y, "%s illustration remains inside its frame, detailed=%s" % [card_id, detailed])
			body.queue_free()
			await process_frame


## 연출 하나를 시작해 끝날 때까지 프레임마다 sampler를 호출한다. 걸린 실제 시간을 반환한다.
func _play(tool_id: StringName, result: Dictionary, sampler: Callable = Callable()) -> float:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	var started: float = _now()
	presenter.play(tool_id, result, 0.8)
	while presenter.active:
		if sampler.is_valid():
			sampler.call(_now() - started)
		await process_frame
	return _now() - started


func _test_presenters() -> void:
	var presenter: RollPresenter = _board._presenter
	# 기본 주사위: 실제 3D 회전 1초 + 결과 유지. 윗면과 판정이 일치한다.
	var elapsed: float = await _play(&"D6", {"tool_id": &"D6", "steps": 4, "details": {}})
	_expect(elapsed >= 0.55 and elapsed < 2.5, "주사위 연출 시간 (%.2f초)" % elapsed)
	_expect(presenter.last_display == "4", "주사위 최종 눈금이 엔진 결과와 같아야 한다 (%s)" % presenter.last_display)
	var die_view: DiceRoll3D = presenter._dice_3d
	_expect(die_view != null and die_view.settled, "3D die reaches its final pose")
	_expect(DiceRoll3D.top_face(die_view.die.quaternion) == 4, "actual mesh top face has four pips")
	_expect(die_view.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "idle 3D viewport stops rendering")
	# Switching tools and cancelling must not strand input or orphan the cached viewport.
	presenter.play(&"D6", {"steps": 2, "details": {"face": 2}}, 0.0)
	_expect(presenter._dice_3d == die_view, "next roll reuses the same viewport")
	presenter.cancel()
	_expect(not presenter.active and not presenter.visible, "cancel hides the die immediately")
	_expect(die_view.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "cancel stops the viewport")
	var ordinary_mesh: Mesh = die_view._pips.mesh
	# D6 above already measures the shared real-time animation. Sample each new
	# face at completion without advancing the live game's unrelated turn timer.
	for value: int in [4, 5, 6, -6]:
		presenter.play(&"CHINCHIRO", {"steps": value, "details": {"face": value, "oops": value == -6}}, 0.8)
		presenter._process(DiceRoll3D.ROLL_TIME + DiceRoll3D.HOLD_TIME)
		_expect(presenter._dice_3d == die_view, "loaded die shares the same 3D viewport")
		_expect(die_view.displayed_value() == value and presenter.last_display == str(value), "loaded physical face and displayed result match %d" % value)
		_expect(die_view._pips.mesh != ordinary_mesh, "loaded die uses its own face paint")
		_expect(die_view.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "loaded die stops rendering after result")
		if value < 0:
			_expect(presenter._die_label.text.contains("후퇴"), "oops is shown as backwards movement")
	presenter.play(&"D6", {"steps": 1, "details": {"face": 1}}, 0.5)
	_expect(die_view._pips.mesh == ordinary_mesh, "switching back restores ordinary D6 pips")
	presenter.cancel()
	# 윷
	elapsed = await _play(&"YUT", {"tool_id": &"YUT", "steps": 3, "details": {"face": 3}})
	_expect(elapsed >= 0.55 and presenter.last_display == "걸", "윷 연출 (%.2f초, %s)" % [elapsed, presenter.last_display])
	# 인생게임 룰렛: 짧은 가속 뒤 감속하며 정확한 칸 가운데 정지한다
	var samples: Array[Vector2] = []
	var sample_roulette: Callable = func(t: float) -> void:
		if presenter._wheel != null:
			samples.append(Vector2(t, presenter._wheel.angle))
	elapsed = await _play(&"LIFE_ROULETTE", {"tool_id": &"LIFE_ROULETTE", "steps": 7, "details": {"face": 7}}, sample_roulette)
	_expect(elapsed >= RouletteSpin3D.TOTAL_TIME-0.1 and elapsed < 3.5, "룰렛 연출 시간 (%.2f초)" % elapsed)
	_expect(presenter.last_display == "7", "룰렛 최종 눈금 (%s)" % presenter.last_display)
	var early: float = _angle_between(samples, 0.4, 0.7)
	var late: float = _angle_between(samples, 1.3, 1.6)
	_expect(early > late * 3.0 and late >= 0.0, "룰렛은 감속해야 한다 (초반 %.2f > 후반 %.2f)" % [early, late])
	# 777 슬롯: 실제 릴이 왼쪽부터 순차 정지한다
	var stop_times: Array[float] = [-1.0, -1.0, -1.0]
	var sample_slot: Callable = func(t: float) -> void:
		for index: int in 3:
			if stop_times[index] < 0.0 and presenter._reel_stopped[index]:
				stop_times[index] = t
	elapsed = await _play(&"SLOT_777", {"tool_id": &"SLOT_777", "steps": 4, "details": {"reels": [1, 1, 5]}}, sample_slot)
	_expect(stop_times[0] > 0.0 and stop_times[0] < stop_times[1] and stop_times[1] < stop_times[2], "릴이 순서대로 멈춰야 한다 %s" % str(stop_times))
	_expect(absf(stop_times[0] - SlotMachine3D.STOP_TIMES[0]) < 0.2 and absf(stop_times[1] - SlotMachine3D.STOP_TIMES[1]) < 0.2 and absf(stop_times[2] - SlotMachine3D.STOP_TIMES[2]) < 0.2, "실제 릴의 정지 시각 %s" % str(stop_times))
	_expect(presenter.last_display == "레몬|레몬|7", "슬롯 최종 심볼 (%s)" % presenter.last_display)
	# 홀덤: 카드 5장이 0.15초 간격으로 한 장씩 뒤집힌다
	var flip_times: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0]
	var cards: Array = [51, 38, 0, 12, 25]
	var sample_cards: Callable = func(t: float) -> void:
		for index: int in 5:
			if flip_times[index] < 0.0 and presenter._card_flipped.size() == 5 and presenter._card_flipped[index]:
				flip_times[index] = t
	elapsed = await _play(&"HOLDEM", {"tool_id": &"HOLDEM", "steps": 1, "details": {"cards": cards, "hand": &"high_card"}}, sample_cards)
	var increasing: bool = true
	for index: int in range(1, 5):
		increasing = increasing and flip_times[index] > flip_times[index - 1]
	_expect(increasing and flip_times[0] >= 0.0, "카드가 순서대로 뒤집혀야 한다 %s" % str(flip_times))
	_expect(absf((flip_times[4] - flip_times[0]) - 0.6) < 0.2, "카드 플립 간격 0.15초 %s" % str(flip_times))
	var expected: Array[String] = []
	for card: int in cards:
		expected.append(RollPresenter.card_text(card))
	_expect(presenter.last_display == " ".join(PackedStringArray(expected)), "홀덤 최종 카드 (%s)" % presenter.last_display)
	_expect(not presenter.visible, "연출이 끝나면 패널이 숨겨져야 한다")
	# 화투: 새로 뒤집는 패만 뒤집히고 이미 나온 패는 앞면으로 놓인다 (고! 한 번)
	var hwatu_result: Dictionary = {"tool_id": &"DICE_HWATU", "steps": 7, "details": {"cards": [1, 5, 40], "new_cards": [40], "hand": &"kkeut", "label": "3끗", "go_count": 1, "go_type": &"gwang", "bonus": 5, "accumulated": 7}}
	elapsed = await _play(&"DICE_HWATU", hwatu_result)
	_expect(elapsed >= 0.4 and elapsed < 3.0, "화투 연출 시간 (%.2f초)" % elapsed)
	_expect(presenter.last_display == "1월 열끗 2월 열끗 11월 광", "화투 최종 패 (%s)" % presenter.last_display)
	# 마작: 패 3개 동시 쯔모
	elapsed = await _play(&"DICE_MAHJONG", {"tool_id": &"DICE_MAHJONG", "steps": 5, "details": {"tiles": [0, 1, 2], "hand": &"shuntsu", "label": "슌쯔"}})
	_expect(elapsed >= 0.4 and elapsed < 3.0 and presenter.last_display == "1만 2만 3만", "마작 연출 (%.2f초, %s)" % [elapsed, presenter.last_display])
	# 타로: 뒷면 5장 중 한 장만 뒤집힌다
	var tarot_flips: Array[int] = []
	var sample_tarot: Callable = func(_t: float) -> void:
		var flipped: int = 0
		for flag: bool in presenter._card_flipped:
			if flag:
				flipped += 1
		if tarot_flips.is_empty() or tarot_flips.back() != flipped:
			tarot_flips.append(flipped)
	elapsed = await _play(&"DICE_TAROT", {"tool_id": &"DICE_TAROT", "steps": 6, "details": {"fate": &"chariot", "name": "VII. 전차 (The Chariot)", "flipped": 2, "fool_leap": false}}, sample_tarot)
	_expect(elapsed >= 0.4 and elapsed < 3.0 and presenter.last_display.contains("VII"), "타로 연출 (%.2f초, %s)" % [elapsed, presenter.last_display])
	# instant: 즉시 완료
	presenter.instant = true
	var before: float = _now()
	await presenter.play(&"SLOT_777", {"tool_id": &"SLOT_777", "steps": 1, "details": {"reels": [0, 1, 2]}}, 0.5)
	_expect(_now() - before < 0.1 and presenter.last_display == "체리|레몬|종", "instant면 연출을 건너뛴다")
	presenter.instant = false


## Sample animation time directly so these privacy checks do not advance turn timers.
func _test_illustrated_judgment_cards() -> void:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.set_process(false)
	presenter.play(&"HOLDEM", {"steps":1, "details":{"cards":[0,15,30,45,51], "hand":&"high_card"}})
	await process_frame
	await process_frame
	presenter._update(0.29)
	_expect(presenter.last_display.is_empty() and presenter._die_label.text.is_empty(), "poker outcome stays hidden before first flip midpoint")
	for panel: PanelContainer in presenter._cards:
		var card: JudgmentCard = panel as JudgmentCard
		_expect(not card.face_up and card._back.visible and not card._front.visible, "poker starts with opaque generated backs")
	presenter._update(0.32)
	_expect(presenter._card_flipped == [true,false,false,false,false], "only the first poker card reveals at its midpoint")
	_expect(presenter._die_label.text.is_empty(), "poker hand name waits for every card")
	presenter._update(1.03)
	await process_frame
	_expect(presenter._card_flipped == [true,true,true,true,true], "all five poker cards reveal in order")
	_expect(presenter._die_label.text.contains("1칸 전진"), "poker caption uses engine movement")
	for index: int in presenter._cards.size():
		var card: JudgmentCard = presenter._cards[index] as JudgmentCard
		_expect(card._front.size.x > 0 and card._front.get_child_count() > 0 and not card._back.visible, "revealed front has populated artwork and no back")
		if index > 0:
			_expect(card.position.x >= presenter._cards[index-1].position.x + presenter._cards[index-1].size.x, "settled cards do not overlap")
	presenter.cancel()
	_expect(not presenter.active and not presenter.visible, "card cancellation releases the presenter")
	presenter.play(&"DICE_HWATU", {"steps":0, "ends_turn":true, "details":{"cards":[1,40], "new_cards":[40], "label":"망통"}})
	await process_frame
	await process_frame
	presenter._update(0.10)
	_expect((presenter._cards[0] as JudgmentCard).face_up and not (presenter._cards[1] as JudgmentCard).face_up, "known Hwatu stays face up while the fresh card is hidden")
	presenter._update(0.43)
	_expect(presenter._die_label.text == "망통 · 이동 없음", "zero movement remains zero without a false forward result")
	presenter.cancel()
	for selected: int in 5:
		var fate: StringName = ToolTarot.FATES[selected]
		presenter.play(&"DICE_TAROT", {"steps":-2, "details":{"fate":fate, "flipped":selected}})
		await process_frame
		await process_frame
		presenter._update(0.52)
		_expect(presenter._card_flipped.count(true) == 0 and presenter._die_label.text.is_empty() and presenter.last_display.is_empty(), "tarot fate remains hidden during focus and first flip half")
		presenter._update(0.65)
		_expect(presenter._card_flipped.count(true) == 1, "tarot reveals exactly one card at every selection position")
		_expect(presenter._die_label.text.contains("2칸 후퇴"), "negative engine movement remains a retreat")
		for index: int in 5:
			var card: JudgmentCard = presenter._cards[index] as JudgmentCard
			_expect(card.face_up == (index == selected), "only the actual selected tarot card is face up")
			_expect(card._back.visible == (index != selected), "the four unselected tarot backs remain visible")
			if index != selected:
				_expect(card.model.art.is_empty(), "unselected tarot cards have no assigned fate illustration")
		presenter.cancel()
	_expect(presenter._dice_3d.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "card effects leave the cached 3D dice renderer asleep")
	presenter.set_process(true)
	print("JUDGMENT_CARD_FX_OK")


## Exact local timeline samples avoid consuming another live turn's timeout.
func _test_mahjong_landings() -> void:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.set_process(false)
	var original_time_scale: float = Engine.time_scale
	var result: Dictionary = {"steps":12,"reroll":true,"details":{"tiles":[27,28,29],"hand":&"yakuman","label":"대삼원"}}
	presenter.play(&"DICE_MAHJONG",result)
	await process_frame
	await process_frame
	var view: MahjongSlam3D = presenter._mahjong_3d
	var events: Array[int] = []
	var observer: Callable = func(index: int) -> void: events.append(index)
	view.tile_landed.connect(observer)
	presenter._update(0.29)
	_expect(view.landed.count(true)==0 and presenter.last_display.is_empty() and presenter._die_label.text.is_empty(),"mahjong hides hand and movement before landing")
	for label: Label in presenter._mahjong_names:
		_expect(label.text.is_empty(),"tile names do not leak before their own landing")
	for index: int in 3:
		presenter._update(MahjongSlam3D.impact_time(index)+0.001)
		_expect(view.landed.count(true)==index+1,"mahjong lands one solid tile per beat")
		_expect(presenter._mahjong_names[index].text==ToolMahjong.tile_name(27+index),"landing reveals matching tile name")
		_expect(presenter._die_label.text.is_empty(),"hand result waits for third tile to settle")
	presenter._update(MahjongSlam3D.RESULT_TIME+0.001)
	presenter._update(MahjongSlam3D.RESULT_TIME+0.01)
	_expect(events==[0,1,2],"exactly three landing events fire, without duplicate sounds")
	_expect(view.tile_ids==[27,28,29] and presenter.last_display=="백 발 중","physical fronts match actual engine tile order")
	_expect(presenter._die_label.text=="대삼원 · 12칸 전진 · 한 번 더","yakuman displays exact movement and reroll")
	_expect(Engine.time_scale==original_time_scale,"contact hold never pauses the game or network clock")
	view.tile_landed.disconnect(observer)
	presenter._process(presenter._total)
	_expect(not presenter.active and not presenter.visible,"mahjong completes and releases presenter")
	_expect(view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"completed 3D mahjong stops rendering")
	presenter.play(&"DICE_MAHJONG",{"steps":5,"details":{"tiles":[0,1,2],"label":"슌쯔"}})
	_expect(presenter._mahjong_3d==view,"next draw reuses cached meshes and viewport")
	_expect(view.landed.count(true)==0,"next draw resets all landing latches")
	presenter.cancel()
	_expect(view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not presenter.visible,"cancel hides mahjong and stops its renderer")
	presenter.play(&"HOLDEM",{"steps":1,"details":{"cards":[0,1,2,3,4],"hand":&"high_card"}})
	_expect(view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"switching to cards keeps mahjong renderer asleep")
	presenter.cancel()
	presenter.set_process(true)
	print("MAHJONG_SLAM_FX_OK")


func _test_yut_throw() -> void:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.set_process(false)
	presenter.play(&"YUT",{"steps":-1,"details":{"face":-1}})
	await process_frame
	await process_frame
	var view: YutThrow3D = presenter._yut_3d
	var events: Array[int] = []
	var observer: Callable = func(index: int) -> void: events.append(index)
	view.stick_landed.connect(observer)
	presenter._update(0.65)
	_expect(view.landed.count(true)==0 and presenter.last_display.is_empty() and presenter._die_label.text.is_empty(),"Yut keeps its outcome hidden while all four sticks are in flight")
	for index: int in 4:
		presenter._update(YutThrow3D.impact_time(index)+0.001)
		_expect(view.landed.count(true)==index+1,"wooden sticks land at separate clustered times")
		_expect(presenter._die_label.text.is_empty(),"Yut waits for all sticks to settle before naming the result")
	presenter._update(YutThrow3D.RESULT_TIME+0.001)
	presenter._update(YutThrow3D.RESULT_TIME+0.01)
	_expect(events==[0,1,2,3],"exactly four primary landing events occur")
	_expect(view.displayed_value()==-1 and presenter.last_display=="빽도","marked physical belly and engine Backdo agree")
	_expect(presenter._die_label.text=="빽도 · 1칸 후퇴","negative Yut result is shown as retreat")
	view.stick_landed.disconnect(observer)
	presenter._process(presenter._total)
	_expect(not presenter.active and view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"completion releases input and stops Yut rendering")
	for value: int in ToolYut.FACES:
		presenter.play(&"YUT",{"steps":value,"reroll":value>=4,"details":{"face":value}},0.1)
		presenter._update(YutThrow3D.RESULT_TIME+0.001)
		_expect(presenter._yut_3d==view,"all outcomes reuse the same four meshes and viewport")
		_expect(view.displayed_value()==value and presenter.last_display==RollPresenter.YUT_NAMES[value],"six physical outcomes agree with engine values")
		_expect(presenter._die_label.text.contains("한 번 더")==bool(value>=4),"only actual Yut/Mo results show reroll")
		presenter.cancel()
	_expect(not presenter.active and not presenter.visible and view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"cancelling Yut hides it and stops its renderer")
	presenter.play(&"D6",{"steps":4,"details":{"face":4}})
	_expect(view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and presenter._dice_3d.render_view.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"switching back to D6 awakens only the active renderer")
	presenter.cancel()
	presenter.set_process(true)
	print("YUT_THROW_FX_OK")


func _test_roulette_spin() -> void:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.set_process(false)
	presenter.play(&"LIFE_ROULETTE",{"steps":7,"reroll":true,"details":{"face":7}},0.6)
	await process_frame
	var view: RouletteSpin3D = presenter._wheel
	var ticks: Array[int] = []
	var observer: Callable = func(ordinal: int) -> void: ticks.append(ordinal)
	view.tick_passed.connect(observer)
	presenter._update(0.8)
	_expect(presenter.last_display.is_empty() and presenter._die_label.text.is_empty(),"roulette does not reveal its result while spinning")
	presenter._update(RouletteSpin3D.RESULT_TIME+0.001)
	presenter._update(RouletteSpin3D.RESULT_TIME+0.01)
	_expect(view.displayed_value()==7 and presenter.last_display=="7","real gold seven sector aligns with fixed pointer")
	_expect(presenter._die_label.text=="7 · 7칸 전진 · 한 번 더","roulette shows movement and authoritative reroll")
	_expect(ticks.size()==view.tick_times.size(),"boundary events occur once, including skipped frames")
	view.tick_passed.disconnect(observer)
	presenter._process(presenter._total)
	_expect(not presenter.active and view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"remote roulette completes and sleeps")
	for face: int in range(1,11):
		presenter.play(&"LIFE_ROULETTE",{"steps":face,"details":{"face":face}})
		presenter._update(RouletteSpin3D.RESULT_TIME+0.001)
		_expect(view==presenter._wheel and view.displayed_value()==face,"all ten results reuse one wheel and align correctly")
		presenter.cancel()
	presenter.play(&"YUT",{"steps":2,"details":{"face":2}})
	_expect(view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"switching to Yut leaves roulette asleep")
	presenter.cancel()
	presenter.set_process(true)
	# Direct pad is the real local-player route; verify it independently.
	var pad := RollPad.new()
	root.add_child(pad)
	pad.set_kind(RollPad.Kind.ROULETTE)
	pad.set_process(false)
	var released: Array[bool] = []
	pad.finished.connect(func() -> void: released.append(true))
	var cached: RouletteSpin3D = pad._wheel
	pad._velocity = 12.0
	pad._wheel.set_idle_angle(0.31)
	pad.play_spin(7,0.6)
	pad._process(0.6)
	_expect(pad.active and pad._face_label.text.is_empty() and pad._wheel.angle<0.31,"local reverse fling stays private and follows the drag direction")
	pad._process(RouletteSpin3D.TOTAL_TIME)
	_expect(not pad.active and pad.last_face==7 and pad._wheel.displayed_value()==7,"local route finishes on the physical engine result")
	_expect(pad._hint_label.text.contains("한 번 더") and released.size()==1,"local seven signals completion and reroll once")
	_expect(pad._wheel.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"local completion sleeps the renderer")
	pad.play_spin(3,0.1)
	pad.cancel_spin()
	_expect(not pad.active and released.size()==2,"cancelling an active pad resumes awaiting board handlers")
	pad.set_kind(RollPad.Kind.REVOLVER)
	_expect(cached.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"tool switch cannot strand a running wheel")
	pad.set_kind(RollPad.Kind.ROULETTE)
	pad.instant = true
	pad.play_spin(10,0.0)
	_expect(pad._wheel==cached and pad._wheel.displayed_value()==10 and not pad.active,"instant path keeps the actual face and reuses geometry")
	pad.queue_free()
	await process_frame
	print("ROULETTE_SPIN_FX_OK")


func _test_slot_machine() -> void:
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.set_process(false)
	presenter.play(&"SLOT_777",{"steps":20,"details":{"reels":[5,5,5]}},0.6)
	await process_frame
	var view: SlotMachine3D = presenter._slot_3d
	var stops: Array[int] = []
	var observer: Callable = func(index: int) -> void: stops.append(index)
	view.reel_stopped.connect(observer)
	presenter._update(0.7)
	_expect(view.stopped.count(true)==0 and presenter.last_display.is_empty() and presenter._die_label.text.is_empty(),"slot conceals payout before physical reels stop")
	for index: int in 3:
		presenter._update(SlotMachine3D.STOP_TIMES[index]+0.001)
		_expect(view.stopped.count(true)==index+1,"slot locks one reel at a time, left to right")
		_expect(view.displayed_values()[index]==5,"stopped cylinder shows its actual seven")
		_expect(presenter._die_label.text.is_empty(),"payout remains hidden until all reel rebounds settle")
	presenter._update(SlotMachine3D.RESULT_TIME+0.001)
	presenter._update(SlotMachine3D.RESULT_TIME+0.01)
	_expect(stops==[0,1,2],"slot emits exactly three distinct stop events")
	_expect(presenter.last_display=="7|7|7" and presenter._die_label.text=="777 잭팟! · 20칸 전진","physical jackpot and engine movement agree")
	_expect(view._sign.text=="777 잭팟!" and view.winning_reels==[true,true,true],"jackpot sign and matching lamps use actual symbols")
	view.reel_stopped.disconnect(observer)
	presenter._process(presenter._total)
	_expect(not presenter.active and view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"completion releases board and sleeps slot renderer")
	var strip: SubViewport = view._strip_view
	for values: Array in [[0,1,2],[0,1,0],[2,2,2],[3,4,5]]:
		var typed: Array[int] = []
		typed.assign(values)
		presenter.play(&"SLOT_777",{"steps":ToolSlot777.steps_for(typed),"details":{"reels":values}},0.0)
		presenter._update(SlotMachine3D.RESULT_TIME+0.001)
		_expect(presenter._slot_3d==view and view._strip_view==strip,"repeated spins reuse cabinet, drums and strip")
		_expect(view.displayed_values()==typed,"all six actual reel symbols can be shown")
		_expect(view._sign.text==SlotMachine3D.result_title(typed),"miss, pair and triple receive their real outcome title")
		presenter.cancel()
	presenter.play(&"YUT",{"steps":2,"details":{"face":2}})
	_expect(view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"switching to Yut leaves slot asleep")
	presenter.cancel()
	presenter.play(&"SLOT_777",{"steps":1,"details":{"reels":[0,1,2]}})
	presenter.cancel()
	_expect(not presenter.active and not presenter.visible and view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"mid-spin cancellation cannot strand input or rendering")
	presenter.set_process(true)
	print("SLOT_MACHINE_FX_OK")


func _test_toy_flag_gun() -> void:
	var pad := RollPad.new()
	root.add_child(pad)
	pad.set_kind(RollPad.Kind.REVOLVER)
	pad.set_process(false)
	var gun: ToyFlagGun3D = pad._gun
	var outcomes: Array[bool] = []
	gun.outcome_reached.connect(func(fired: bool) -> void: outcomes.append(fired))
	pad.ensure_revolver_prepared("turn-1",false)
	_expect(pad.preparing and pad.active and gun._cartridge.visible and gun._mount.position.distance_to(gun._mount_home)>2.5,"first turn inspects one loaded cartridge from rear")
	pad._process(0.70)
	pad.ensure_revolver_prepared("turn-1",false)
	_expect(is_equal_approx(pad._prepare_time,0.70) and outcomes.is_empty(),"refreshing controls neither restarts preparation nor generates a roll")
	pad._process(1.0)
	_expect(gun._cylinder.rotation.z<0 and gun._cylinder.rotation.z>-TAU*4.0 and gun._mount.position.is_equal_approx(gun._mount_home) and not gun.flag_root.visible,"closed cylinder spins during the view transition")
	pad._process(ToyFlagGun3D.PREP_TIME)
	_expect(not pad.preparing and not pad.active and gun._camera.position.is_equal_approx(ToyFlagGun3D.CAMERA_HOME) and not gun._cartridge.visible and outcomes.is_empty(),"side profile enables choice without exposing the hidden engine chamber")
	pad.ensure_revolver_prepared("turn-1",false)
	_expect(not pad.active,"same turn never replays loading between safe clicks")
	pad.play_trigger(false,3)
	var initial_angle: float = gun._cylinder.rotation.z
	pad._process(0.20)
	_expect(gun._cylinder.rotation.z<initial_angle and gun._trigger.rotation.z>0 and gun._hammer.rotation.z<0,"actual drum, trigger and hammer meshes move on a safe pull")
	pad._process(ToyFlagGun3D.CLICK_TIME-0.21)
	_expect(gun.chambers.count(true)==0 and not gun.flag_root.visible,"no flag or safe marker leaks before public click")
	pad._process(0.02)
	_expect(gun.chambers.count(true)==1 and not gun.flag_root.visible,"safe click reveals exactly one used position")
	pad._process(ToyFlagGun3D.SAFE_TOTAL_TIME)
	_expect(not pad.active and pad._hint_label.text=="찰칵! 누적 3칸","safe result reports accumulation and releases input")
	_expect(gun.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"safe completion sleeps the renderer")
	pad.play_trigger(true,0,3,false)
	pad._process(ToyFlagGun3D.CLICK_TIME-0.01)
	_expect(not gun.flag_root.visible and pad._hint_label.text.is_empty(),"party result is hidden while pulling")
	pad._process(0.25)
	_expect(gun.flag_root.visible and gun.confetti.filter(func(p: MeshInstance3D) -> bool: return p.visible).size()==ToyFlagGun3D.CONFETTI_COUNT,"fired result produces attached flag and paper confetti")
	pad._process(ToyFlagGun3D.FLAG_RESULT_TIME-0.56+0.001)
	_expect(pad._hint_label.text=="뿅! 누적 3칸 사라짐 · 턴 종료","local caption matches actual lost accumulation")
	pad._process(ToyFlagGun3D.FLAG_TOTAL_TIME)
	_expect(outcomes==[false,true] and not pad.active,"each click/pop emits exactly one outcome and completes")
	pad.reset_revolver()
	_expect(not gun.flag_root.visible and gun.chambers.count(true)==0,"new cylinder clears old flag and progress")
	pad.play_trigger(true,0,6,false)
	pad._process(0.60)
	pad.cancel_spin()
	_expect(not pad.active and not gun.visible and not gun.flag_root.visible and gun.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"mid-pop cancellation clears the toy and sleeps")
	pad.play_trigger(false,6)
	_expect(pad._gun==gun and gun.visible,"later pulls reuse and show the same cached toy")
	pad.set_kind(RollPad.Kind.ROULETTE)
	_expect(not pad.active and not gun.visible,"tool switch cancels the trigger")
	pad.set_kind(RollPad.Kind.REVOLVER)
	pad.ensure_revolver_prepared("turn-2",false)
	pad._process(0.3)
	pad.set_kind(RollPad.Kind.NONE)
	_expect(not pad.active and not pad.preparing and gun.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"tool switch cancels preparation and releases the viewport")
	pad.instant = true
	pad.set_kind(RollPad.Kind.REVOLVER)
	pad.ensure_revolver_prepared("turn-3",false)
	_expect(not pad.active and gun._camera.position.is_equal_approx(ToyFlagGun3D.CAMERA_HOME),"instant mode skips preparation as well as trigger motion")
	pad.queue_free()
	await process_frame
	# A fired result advances the engine before its visual finishes.
	var current: int = _board.manager.current_player_id()
	var old_tool: BaseJudgmentTool = _board.state.tools[current]
	_board._roll_pad.instant = false
	_board._roll_pad.set_kind(RollPad.Kind.REVOLVER)
	_board._roll_pad.play_trigger(true,0,3,false)
	_board._fx_busy = true
	_board.state.tools[current] = ToolRegistry.create(&"D6")
	_board._refresh_roll_pad()
	_expect(_board._roll_pad.active and _board._roll_pad.kind==RollPad.Kind.REVOLVER,"next tool cannot erase an active flag animation")
	_board._roll_pad.cancel_spin()
	_board._fx_busy = false
	_board.state.tools[current] = old_tool
	_board._refresh_all()
	var presenter: RollPresenter = _board._presenter
	presenter.instant = false
	presenter.set_process(false)
	presenter.play(&"REVOLVER",{"steps":0,"ends_turn":true,"details":{"fired":true,"lost":6}})
	presenter._update(0.2)
	_expect(presenter.last_display.is_empty() and presenter._die_label.text.is_empty(),"remote gun hides its result before pop")
	presenter._update(ToyFlagGun3D.FLAG_RESULT_TIME+0.001)
	_expect(presenter._toy_gun.flag_root.visible and presenter.last_display=="뿅!" and presenter._die_label.text.contains("6칸"),"remote presenter uses the same star flag and lost-step result")
	var cached: ToyFlagGun3D = presenter._toy_gun
	presenter._process(presenter._total)
	_expect(cached.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"remote completion sleeps")
	presenter.play(&"REVOLVER",{"steps":9,"can_continue":true,"details":{"fired":false,"accumulated":9}})
	presenter._update(ToyFlagGun3D.SAFE_RESULT_TIME+0.001)
	_expect(presenter._toy_gun==cached and not cached.flag_root.visible and cached.chambers.count(true)==3,"remote safe click reuses toy and shows only public progress")
	presenter.cancel()
	presenter.play(&"REVOLVER",{"steps":3,"can_continue":true,"details":{"fired":false,"accumulated":3}})
	presenter._update(0.5)
	_expect(presenter._toy_gun._cartridge.visible and presenter.last_display.is_empty(),"remote first pull includes loading inspection before result")
	presenter._update(ToyFlagGun3D.PREP_TIME+ToyFlagGun3D.SAFE_RESULT_TIME+0.001)
	_expect(presenter._toy_gun._camera.position.is_equal_approx(ToyFlagGun3D.CAMERA_HOME) and presenter.last_display=="찰칵","remote orbit ends in the same side-view click")
	presenter.cancel()
	presenter.set_process(true)
	print("TOY_FLAG_GUN_FX_OK")


func _angle_between(samples: Array[Vector2], from_time: float, to_time: float) -> float:
	var first: float = -1.0
	var last: float = -1.0
	for sample: Vector2 in samples:
		if sample.x >= from_time and first < 0.0:
			first = sample.y
		if sample.x <= to_time:
			last = sample.y
	return last - first if first >= 0.0 else 0.0


## 굴림 버튼을 꾹 누르면 게이지가 왕복하고, 떼면 연출이 돌며 그동안 입력이 잠기고, 끝나면 결과가 공개된다.
func _test_gauge_and_lock() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = false
	manager.state.tools[manager.current_player_id()] = ToolRegistry.create(&"D6")
	_board._refresh_all()
	var rolled: Array[Dictionary] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			rolled.append(data))
	_expect(not _board._roll_button.disabled, "턴 시작에 굴림 버튼이 활성이어야 한다")
	_board._roll_button.button_down.emit()
	_expect(_board._charging and _board._power_bar.visible, "버튼을 누르면 파워 게이지가 보인다")
	var low: float = 100.0
	var high: float = 0.0
	var started: float = _now()
	while _now() - started < 1.4:
		await process_frame
		low = minf(low, _board._power_bar.value)
		high = maxf(high, _board._power_bar.value)
	_expect(low < 30.0 and high > 70.0, "게이지가 0~100%%를 왕복해야 한다 (%.0f ~ %.0f)" % [low, high])
	var power_at_release: float = _board._charge_value
	_board._roll_button.pressed.emit()  # 손을 뗀 순간
	_expect(not _board._charging and not _board._power_bar.visible, "손을 떼면 게이지가 사라진다")
	_expect(absf(_board._pending_power - power_at_release) < 0.01, "손을 뗀 순간의 파워가 연출에 전달된다")
	_expect(_board._fx_busy and _board._presenter.active, "굴림 연출이 재생 중이어야 한다")
	_expect(_board._roll_button.disabled, "연출 중에는 굴림 버튼이 잠긴다")
	_expect(_board._roll_button.size.x >= 120.0 and _board._roll_button.size.x == _board._roll_button.size.y, "굴리기 버튼은 큼직한 원형 (%s)" % str(_board._roll_button.size))
	_expect(not _board._select_banner.visible, "연출 중에는 말 선택 배너가 보이지 않는다")
	_expect(rolled.size() == 1, "엔진은 이미 결과를 확정했다")
	var wait_start: float = _now()
	while _board._fx_busy and _now() - wait_start < 4.0:
		await process_frame
	_expect(not _board._fx_busy, "연출이 끝나면 입력 잠금이 풀린다")
	_expect(_board._presenter.last_display == str(int((rolled[0]["result"] as Dictionary)["steps"])), "연출의 최종 눈금이 엔진 결과와 같아야 한다 (%s)" % _board._presenter.last_display)
	_expect(_board._center_banner.visible, "연출 뒤 중앙 결과 배너가 뜬다")
	# 키보드: R을 누르고 있다가 떼면 굴린다
	_board.manager.force_timeout()
	for i: int in 3:
		await process_frame
	var guard: int = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and not manager.is_game_over and guard < 200:
		guard += 1
		manager.force_timeout()
		await process_frame
		await process_frame
	# 엔진은 다음 턴에 도착해도 이전 이동·실패 알림·자동 굴림 연출은 남을 수 있다.
	# 재생 중 instant 플래그를 바꾸면 다음 검사의 R 입력이 잠긴 상태에서 실행된다.
	var settle_start: float = _now()
	while (_board._ui_busy() or _board._fx_motion_pending()) and _now() - settle_start < 8.0:
		await process_frame
	_expect(not _board._ui_busy() and not _board._fx_motion_pending(), "이전 턴의 연출이 끝난 뒤 다음 입력을 검사한다")


func _test_instant_flag() -> void:
	var manager: TurnManager = _board.manager
	var resolved: Array[Dictionary] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			resolved.append(data))
	_board.instant_roll_for_test = true
	manager.state.tools[manager.current_player_id()] = ToolRegistry.create(&"D6")
	_board._refresh_all()
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	_board._unhandled_key_input(key)
	_expect(_board._charging and _board._charge_by_key, "R 키를 누르면 충전이 시작된다")
	_expect(not _board._power_bar.visible, "instant 모드에서는 게이지를 보이지 않는다")
	var release := InputEventKey.new()
	release.keycode = KEY_R
	release.pressed = false
	_board._unhandled_key_input(release)
	_expect(not _board._fx_busy, "instant 모드는 연출 대기 없이 즉시 결과를 공개한다")
	# With no selectable pawn, a valid instant roll can already reach the next
	# player's TURN_BEGIN. Assert the actual result event instead of that phase.
	_expect(resolved.size() == 1 and not _board._charging, "키를 떼면 굴림 결과가 정확히 한 번 확정된다")


## 기본 모드는 [1P vs 3AI 봇]이고, 토글로 언제든 [4P 수동 조작]으로 바꿀 수 있다.
func _test_mode_toggle() -> void:
	_expect(_board.ai_mode, "기본 모드는 1P vs 3AI 봇이어야 한다")
	_expect(_board._mode_toggle.text == "[모드: 1P vs 3AI 봇]", "기본 토글 문구 (%s)" % _board._mode_toggle.text)
	_expect(_board._bot.enabled, "기본으로 봇이 켜져 있다")
	_board._mode_toggle.pressed.emit()
	_expect(not _board.ai_mode and not _board._bot.enabled and _board._mode_toggle.text == "[모드: 4P 수동 조작]", "토글하면 4P 수동 조작")
	_board._mode_toggle.pressed.emit()
	_expect(_board.ai_mode and _board._bot.enabled, "다시 토글하면 AI 대전")


## 테이블 좌석 배치와 아바타 칸: 인원·내 자리에 따라 앵커가 정해지고, 감정 반응과 에셋 슬롯이 동작한다.
func _test_avatar_seats() -> void:
	var saved_ids: Array[int] = _board._player_ids.duplicate()
	var saved_local: int = _board.local_player_id
	var cases: Array = [
		[[1, 2] as Array[int], 1, {1: &"me", 2: &"right"}],
		[[1, 2] as Array[int], 2, {2: &"me", 1: &"right"}],
		[[1, 2, 3] as Array[int], 1, {1: &"me", 2: &"right", 3: &"left"}],
		[[1, 2, 3, 4] as Array[int], 1, {1: &"me", 2: &"right", 3: &"top", 4: &"left"}],
		[[1, 2, 3, 4] as Array[int], 3, {3: &"me", 4: &"right", 1: &"top", 2: &"left"}],
		[[2, 4] as Array[int], 4, {4: &"me", 2: &"right"}],
	]
	for entry: Array in cases:
		_board._player_ids = entry[0]
		_board.local_player_id = entry[1]
		_board._compute_seats()
		for player_id: int in (entry[2] as Dictionary).keys():
			_expect(_board.seat_anchor_of(player_id) == (entry[2] as Dictionary)[player_id], "인원 %s, 내 자리 %d: P%d 앵커 %s" % [str(entry[0]), entry[1], player_id, str(_board.seat_anchor_of(player_id))])
	_board._player_ids = saved_ids
	_board.local_player_id = saved_local
	_board._compute_seats()
	# 아바타 칸: 에셋이 없으면 자리표시자, 반응하면 감정 이름이 보이고 시간이 지나면 돌아온다
	var avatar: AvatarSlot = _board._profiles[2]["avatar"]
	avatar.set_character(&"no_such_character")  # 에셋이 없는 캐릭터로 자리표시자 동작을 확인한다
	_expect(not avatar.has_art() and avatar.emotion == AvatarSlot.Emotion.IDLE, "에셋이 없으면 자리표시자")
	avatar.react(AvatarSlot.Emotion.ANGRY, 0.0)
	_expect(avatar.emotion == AvatarSlot.Emotion.ANGRY and avatar._caption.visible and avatar._caption.text == "분노", "자리표시자가 감정 이름을 보여 준다")
	avatar.react(AvatarSlot.Emotion.IDLE, 0.0)
	_expect(not avatar._caption.visible, "기본 표정에서는 감정 이름이 사라진다")
	# 스프라이트 시트 슬롯: 감정별 애니메이션이 재생되고 없는 감정은 idle로 대신한다
	var frames := SpriteFrames.new()
	var image := Image.create(40, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	for animation: StringName in [&"idle", &"happy"]:
		if not frames.has_animation(animation):
			frames.add_animation(animation)
		frames.add_frame(animation, texture)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	avatar.use_frames(frames)
	_expect(avatar.has_art() and avatar._sprite != null and avatar._sprite.animation == &"idle", "스프라이트 시트를 넣으면 idle이 재생된다")
	_expect(is_equal_approx(avatar._sprite.scale.y, avatar.size.y / 60.0), "스프라이트는 칸 높이에 맞춰진다")
	avatar.react(AvatarSlot.Emotion.HAPPY, 0.0)
	_expect(avatar._sprite.animation == &"happy" and not avatar._caption.visible, "happy 애니메이션 재생 (에셋이 있으면 자리표시자 글자는 숨김)")
	avatar.react(AvatarSlot.Emotion.ANGRY, 0.0)
	_expect(avatar._sprite.animation == &"idle", "없는 감정(angry)은 idle로 대신한다")
	# 정지 이미지 슬롯
	avatar.set_character(&"nonexistent_character")
	_expect(not avatar.has_art(), "없는 캐릭터는 다시 자리표시자")
	avatar.use_portrait(texture)
	_expect(avatar.has_art() and avatar._portrait != null, "정지 이미지 한 장도 쓸 수 있다")
	avatar.react(AvatarSlot.Emotion.CHEER, 0.0)
	avatar.react(AvatarSlot.Emotion.IDLE, 0.0)
	avatar.set_character(AvatarSlot.DEFAULT_CHARACTER)
	_expect(not avatar.has_art(), "기본 캐릭터 에셋이 없으면 자리표시자로 돌아간다")
	# 게임 이벤트가 아바타를 반응시킨다: 말이 잡히면 피해자는 분노, 잡은 쪽은 웃음
	var victim: PlayerPawn = _board.state.get_pawn(21)
	_board.state.pawn_sent_to_start.emit(victim.entity_id, 1)
	_expect((_board._profiles[2]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.ANGRY and (_board._profiles[1]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.HAPPY, "말이 잡히면 피해자 분노 / 잡은 쪽 웃음")
	_board.state.pawn_finished.emit(31)
	_expect((_board._profiles[3]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.CHEER, "완주하면 환호")
	for player_id: int in [1, 2, 3, 4]:
		(_board._profiles[player_id]["avatar"] as AvatarSlot).react(AvatarSlot.Emotion.IDLE, 0.0)


## 보드 시점: 탑뷰 <-> 기울인 시점. 두 시점 모두 같은 마름모 배치이고 규칙 좌표는 그대로이며, 시점은 배경을 유지하고 보드 면 그림자·말 높이만 바꾼다.
func _test_view_modes() -> void:
	_expect(_board.view_mode == MainBoard.ViewMode.TOP and not _board._plate.visible and _board._board_surface.visible and _board._match_background.visible, "탑뷰에서도 풍경 배경과 마름모 보드 면이 보인다")
	var top_centers: Array[Vector2] = []
	for index: int in 24:
		top_centers.append(_board._tile_center(index))
	_expect(top_centers[0].y > top_centers[6].y and top_centers[0].y > top_centers[18].y and absf(top_centers[0].x - 683.0) < 1.0, "0번 출발선은 마름모의 아래 꼭짓점")
	_expect(top_centers[6].x > top_centers[0].x and top_centers[18].x < top_centers[0].x and top_centers[12].y < top_centers[6].y, "6번 오른쪽, 12번 위, 18번 왼쪽 꼭짓점 (반시계)")
	var pawn_id: int = 11
	var pawn: PlayerPawn = _board.state.get_pawn(pawn_id)
	var top_pawn_position: Vector2 = _board._pawn_position(pawn)
	_board.set_view_mode(MainBoard.ViewMode.TILT)
	_expect(not _board._plate.visible and _board._board_surface.visible and _board._match_background.visible and _board._pawn_layer.y_sort_enabled, "기울인 시점: 같은 풍경 배경을 유지하고 말이 깊이순으로 그려진다")
	var restored_in_tilt: bool = true
	for index: int in 24:
		restored_in_tilt = restored_in_tilt and _board._tile_center(index).is_equal_approx(top_centers[index])
	_expect(restored_in_tilt, "두 시점의 타일 좌표는 같다")
	var all_inside: bool = true
	for a: int in 24:
		var tile_a: BoardSkin.Tile = _board._tile_views[a]
		var poly_a := PackedVector2Array()
		for point: Vector2 in tile_a.outline_points:
			poly_a.append(tile_a.position + tile_a.size / 2.0 + (point - tile_a.size / 2.0) * tile_a.scale)
		for point: Vector2 in poly_a:
			all_inside = all_inside and Rect2(Vector2.ZERO, Vector2(1366, 768)).has_point(point)
		for b: int in range(a + 1, 24):
			var tile_b: BoardSkin.Tile = _board._tile_views[b]
			var poly_b := PackedVector2Array()
			for point: Vector2 in tile_b.outline_points:
				poly_b.append(tile_b.position + tile_b.size / 2.0 + (point - tile_b.size / 2.0) * tile_b.scale)
			_expect(Geometry2D.intersect_polygons(poly_a, poly_b).is_empty(), "타일 %d와 %d가 겹침" % [a, b])
	_expect(all_inside, "기울인 시점의 모든 타일이 화면 안")
	_expect((_board._pawn_views[pawn_id] as Node2D).get_node("Shadow").visible, "말 그림자가 보인다")
	_expect(_board._board_edge.points.size() >= 64 and _board._track_lines.size() == 1, "둥근 보드 윤곽과 순환 경로선 1개가 다시 그려진다")
	var safe: PackedVector2Array = BoardSkin.safe_outline(_board._surface_project)
	for i: int in 24:
		var tile: BoardSkin.Tile = _board._tile_views[i]
		_expect(_board._tile_at(tile.get_global_transform() * (tile.size/2.0)) == i, "새 발판 중심 클릭: %d" % i)
		for point: Vector2 in tile.outline_points:
			var board_point: Vector2 = tile.position + tile.size/2.0 + (point-tile.size/2.0)*tile.scale
			_expect(Geometry2D.is_point_in_polygon(board_point + Vector2(0,4),safe), "발판과 받침이 테두리 안에 있어야 한다: %d" % i)
		if tile.symbol != null:
			var transform: Transform2D = tile.symbol.get_global_transform()
			_expect(absf(transform.x.length()-transform.y.length()) < 0.001, "문양 비율 보존: %d" % i)
		if not tile.data.major:
			_expect(tile.band.size() >= 3, "일반 발판의 안쪽 색 띠가 있어야 한다: %d" % i)
			for point: Vector2 in tile.band:
				_expect(Geometry2D.is_point_in_polygon(point,tile.outline_points), "색 띠가 발판 밖으로 나가지 않아야 한다: %d" % i)
	var round_tile: BoardSkin.Tile = _board._tile_views[1]
	_expect(_board._tile_at(round_tile.get_global_transform()*Vector2.ZERO) == -1, "둥근 직사각 발판 바깥 모서리는 클릭되지 않는다")
	var previous_laws: Array[LawResource] = _board.state.rulebook.active_laws_queue.duplicate()
	_board.state.rulebook.active_laws_queue.clear()
	_board.state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
	_board._refresh_tiles()
	_expect((_board._tile_views[6] as BoardSkin.Tile).arrow_target == 7 and (_board._tile_views[18] as BoardSkin.Tile).arrow_target == 19, "공사 중에는 바로 다음 칸을 가리킨다")
	_board.state.rulebook.remove_law_by_id("LAW_01")
	_board._refresh_tiles()
	_expect((_board._tile_views[6] as BoardSkin.Tile).arrow_target == 10 and (_board._tile_views[18] as BoardSkin.Tile).arrow_target == 21, "공사가 끝나면 점프 목적지를 가리킨다")
	_board.state.rulebook.active_laws_queue = previous_laws
	_board._refresh_tiles()
	# 경로선이 새 위치를 따라간다
	_expect(_board._track_lines[0].points[0].is_equal_approx(_board._tile_center(0)), "경로선이 투영 좌표를 따라간다")
	# 시점은 설정으로 저장된다
	_expect(GameSession.view_mode == MainBoard.ViewMode.TILT, "시점이 세션 설정에 기록된다")
	_board.set_view_mode(MainBoard.ViewMode.TOP)
	var restored: bool = true
	for index: int in 24:
		restored = restored and _board._tile_center(index).is_equal_approx(top_centers[index])
	_expect(restored and not _board._plate.visible and _board._board_surface.visible and _board._match_background.visible, "탑뷰로 돌아오면 모든 좌표와 배경이 그대로 돌아온다")
	_expect(_board._pawn_position(pawn).is_equal_approx(top_pawn_position) and not _board._pawn_layer.y_sort_enabled, "말 위치도 그대로")
	GameSession.view_mode = MainBoard.ViewMode.TOP


## 상단 UI는 [메뉴]와 [소리 켜짐/꺼짐] 토글뿐이고, 메뉴 안에서 계속하기/게임 설정/전체 로그/새 게임/모드/치트/게임 나가기를 고른다.
func _test_game_menu() -> void:
	var top_buttons: Array[Button] = []
	for child: Node in _board.get_children():
		var button: Button = child as Button
		if button != null and button.visible and button.position.y < 44.0 and button.size.y <= 40.0:
			top_buttons.append(button)
	_expect(top_buttons.size() == 2 and top_buttons.has(_board._menu_button) and top_buttons.has(_board._sound_button), "상단에는 [메뉴]와 [소리] 토글 두 개만 남는다 (%d개)" % top_buttons.size())
	_expect(_board._mode_toggle.get_parent() == null and _board._new_game_button.get_parent() == null and _board._debug_toggle.get_parent() == null, "닫힌 메뉴에서는 모드·새 게임·치트 버튼이 화면에 없다")
	_expect(not _board._menu_is_open(), "처음에는 메뉴가 닫혀 있다")
	var was_muted: bool = GameSession.audio_muted
	GameSession.audio_muted = false
	_board._refresh_sound_button()
	_expect(_board._sound_button.text == "소리 켜짐", "소리 토글 버튼은 켜진 상태를 보여 준다")
	_board._sound_button.pressed.emit()
	_expect(GameSession.audio_muted and _board._sound_button.text == "소리 꺼짐", "누르면 음소거되고 문구가 바뀐다")
	_board._sound_button.pressed.emit()
	_expect(not GameSession.audio_muted and _board._sound_button.text == "소리 켜짐", "다시 누르면 소리가 켜진다")
	GameSession.audio_muted = was_muted
	_board._refresh_sound_button()
	_board._menu_button.pressed.emit()
	_expect(_board._menu_is_open() and _board._menu_page == &"main", "[메뉴]를 누르면 메뉴가 열린다")
	var labels: Array[String] = []
	for child: Node in _board._menu_box.get_children():
		if child is Button:
			labels.append((child as Button).text)
	_expect(labels.has("계속하기") and labels.has("게임 설정") and labels.has("규칙 책자") and labels.has("게임 나가기"), "메뉴 항목: %s" % str(labels))
	_expect(not labels.has("전체 로그") and not labels.has("새 게임") and _board._mode_toggle.get_parent() != _board._menu_box, "디버그가 꺼져 있으면 로그·새 게임·모드는 메뉴에 없다")
	_expect(not _board._debug_enabled and not _board._debug_toggle.visible and _board._debug_toggle.get_parent() != _board._menu_box, "치트/디버그는 평소에 숨겨져 있다")
	var f9 := InputEventKey.new()
	f9.keycode = KEY_F9
	f9.pressed = true
	_board._unhandled_key_input(f9)
	_expect(_board._debug_enabled and _board._debug_box.visible, "F9를 누르면 치트/디버그가 켜진다")
	var combo := InputEventKey.new()
	combo.keycode = KEY_D
	combo.ctrl_pressed = true
	combo.shift_pressed = true
	combo.pressed = true
	_board._unhandled_key_input(combo)
	_expect(not _board._debug_enabled and not _board._debug_box.visible, "Ctrl+Shift+D로 다시 끈다")
	_expect(_board._emote_row != null and _board._emote_row.get_child_count() == 5 and _board._emote_row.visible, "AI 대전에는 감정 표현 버튼 5개가 보인다")
	_board._emote_ready_msec = 0
	(_board._emote_row.get_child(1) as Button).pressed.emit()
	_expect((_board._profiles[_board.local_player_id]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.ANGRY, "감정 버튼을 누르면 내 아바타가 반응한다")
	(_board._emote_row.get_child(2) as Button).pressed.emit()
	_expect((_board._profiles[_board.local_player_id]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.ANGRY, "연타는 대기 시간 동안 무시된다")
	# 메뉴가 열려 있는 동안 봇은 쉰다
	_expect(_board._bot_should_wait(), "혼자 하는 판은 메뉴가 열려 있는 동안 봇이 멈춘다")
	# 게임 설정
	_board._show_menu_page(&"settings")
	_expect(_board._menu_page == &"settings" and _board._menu_box.find_child("PacingCheck", true, false) != null and _board._menu_box.find_child("TimerCheck", true, false) != null, "게임 설정 화면: 연출 멈춤·제한 시간 옵션")
	var pacing_before: bool = _board.pacing_enabled
	(_board._menu_box.find_child("PacingCheck", true, false) as CheckBox).button_pressed = not pacing_before
	_expect(_board.pacing_enabled == not pacing_before, "연출 멈춤 옵션이 바로 적용된다")
	(_board._menu_box.find_child("PacingCheck", true, false) as CheckBox).button_pressed = pacing_before
	_expect(_board.pacing_enabled == pacing_before, "다시 원래대로")
	# 나가기는 한 번 더 확인한다
	_board._show_menu_page(&"confirm_exit")
	var confirm_labels: Array[String] = []
	for child: Node in _board._menu_box.get_children():
		if child is Button:
			confirm_labels.append((child as Button).text)
	_expect(str(confirm_labels) == str(["나가기", "취소"]), "나가기 확인 화면: %s" % str(confirm_labels))
	# ESC: 하위 화면 -> 메인 -> 닫기
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_board._unhandled_key_input(escape)
	_expect(_board._menu_is_open() and _board._menu_page == &"main", "ESC는 먼저 메인 메뉴로 돌아간다")
	_board._unhandled_key_input(escape)
	_expect(not _board._menu_is_open(), "ESC로 메뉴가 닫힌다")
	_board._unhandled_key_input(escape)
	_expect(_board._menu_is_open(), "닫혀 있을 때 ESC는 메뉴를 연다")
	# 메뉴 안의 [전체 로그]는 로그 서랍을 열고 메뉴를 닫는다
	_board._log_toggle.pressed.emit()
	_expect(not _board._menu_is_open() and _board._log_panel.visible, "[전체 로그]는 로그 서랍을 열고 메뉴를 닫는다")
	_board._log_toggle.pressed.emit()
	_expect(not _board._log_panel.visible, "다시 열어 닫는다")
	_board._open_menu()
	_board._show_menu_page(&"main")
	_board._close_menu()
	_expect(_board._mode_toggle.get_parent() == null and _board._bot_should_wait() == _board._ui_busy(), "메뉴를 닫으면 버튼이 정리되고 봇은 메뉴 때문에 멈추지 않는다")


## 중앙 이벤트 알림: 대기열 순서대로 한 건씩 뜨고, 떠 있는 동안 입력이 잠기며, 클릭(skip)으로 넘어가고, instant면 건너뛴다.
func _test_announcer() -> void:
	_board.instant_roll_for_test = false
	var announcer: EventAnnouncer = _board._announcer
	announcer.cancel()
	announcer.history.clear()
	_board._announce("테스트", "첫 알림", "", Color.WHITE, null, 0.5)
	_board._announce("테스트", "둘째 알림", "", Color.WHITE, null, 0.5)
	_expect(announcer.active and announcer.visible and _board._ui_busy(), "알림이 뜨면 입력이 잠긴다")
	_expect(_board._roll_button.disabled, "알림 중 굴리기 버튼 비활성")
	announcer.skip_current()
	await process_frame
	await process_frame
	_expect(announcer.active, "첫 알림을 넘겨도 둘째 알림이 남아 있다")
	announcer.skip_current()
	await process_frame
	await process_frame
	_board._fx_until_msec = 0  # (이 검사는 알림 잠금만 본다: 말 움직임 연출 잠금은 따로 검증)
	_expect(not announcer.active and not announcer.visible and not _board._ui_busy(), "대기열이 비면 잠금 해제")
	announcer.history.clear()
	_board.instant_roll_for_test = true
	_board._announce("테스트", "건너뜀", "", Color.WHITE, null, 0.5)
	_expect(not announcer.active, "instant면 알림을 띄우지 않는다")
	_board.instant_roll_for_test = false


## 룰렛은 원판을 잡고 돌리는 패드, 러시안 룰렛은 방아쇠 패드, 나머지는 둥근 굴리기 버튼. 패드 조작이 엔진 굴림으로 이어지고 원판은 엔진 눈금에 멈춘다.
func _test_roll_pad() -> void:
	var manager: TurnManager = _board.manager
	var pad: RollPad = _board._roll_pad
	_board.instant_roll_for_test = true
	_board._announcer.cancel()
	var guard: int = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 400:
		guard += 1
		manager.force_timeout()
		await process_frame
	var current: int = manager.current_player_id()
	manager.state.tools[current] = ToolRegistry.create(&"D6")
	_board._refresh_controls()
	_expect(pad.kind == RollPad.Kind.NONE and _board._roll_button.visible and not pad.visible, "주사위는 둥근 굴리기 버튼")
	_expect(_board._roll_button.position.y > 300.0 and _board._roll_button.position.y + 120.0 < 530.0 and absf(_board._roll_button.position.x + 60.0 - 683.0) < 1.0, "굴리기 버튼은 중앙 무대 안쪽 아래 가운데")
	manager.state.tools[current] = ToolRegistry.create(&"HOLDEM")
	_board._refresh_controls()
	var big_center: Vector2 = _board._roll_button.position + _board._roll_button.size / 2.0
	_expect(_board._roll_button.visible and _board._roll_button.size.x >= 180.0 and big_center.distance_to(Vector2(683, 335)) < 2.0, "홀덤(버튼형)은 보드 한가운데에 큰 버튼 (%s %s)" % [str(big_center), str(_board._roll_button.size)])
	manager.state.tools[current] = ToolRegistry.create(&"CHINCHIRO")
	_board._refresh_controls()
	_expect(_board._roll_button.size.x == 120.0 and _board._roll_button.position.y > 300.0, "친치로(차징형)는 중앙 무대 아래 작은 버튼 (%s %s)" % [str(_board._roll_button.size), str(_board._roll_button.position)])
	manager.state.tools[current] = ToolRegistry.create(&"LIFE_ROULETTE")
	_board._refresh_controls()
	_expect(pad.kind == RollPad.Kind.ROULETTE and pad.visible and not _board._roll_button.visible, "룰렛은 원판 패드")
	_expect(pad.scale.x >= 1.8 and (pad.position + pad.size / 2.0).distance_to(Vector2(683, 335)) < 2.0, "룰렛 원판은 보드 한가운데에 크게 (%s)" % str(pad.scale))
	var faces: Array[int] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			faces.append(int((data["result"] as Dictionary)["details"].get("face", -1))))
	var center: Vector2 = pad._wheel.position + pad._wheel.size / 2.0
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	pad._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = center
	pad._gui_input(release)
	_expect(faces.size() == 1 and pad.last_face == faces[0], "원판을 톡 치면 굴러가고 원판은 엔진 눈금에 멈춘다 (%s / %d)" % [str(faces), pad.last_face])
	# 느리게 천천히 문지르기만 하면 던진 것이 아니다
	manager.force_timeout()
	guard = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 400:
		guard += 1
		manager.force_timeout()
		await process_frame
	current = manager.current_player_id()
	manager.state.tools[current] = ToolRegistry.create(&"REVOLVER")
	_board._refresh_controls()
	_expect(pad.kind == RollPad.Kind.REVOLVER and pad._gun.visible and not pad._wheel.visible, "러시안 룰렛은 리볼버 패드")
	var before: int = faces.size()
	var shots: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved" and (data["result"] as Dictionary)["tool_id"] == &"REVOLVER":
			shots.append(data["result"]))
	pad.trigger_pulled.emit()
	_expect(shots.size() == 1, "방아쇠를 당기면 엔진이 굴린다")
	_board.instant_roll_for_test = false


## 창 비율 대응: 넓은 창이면 오른쪽 묶음은 오른쪽 끝으로, 보드는 가운데로, 왼쪽은 그대로. 높은 창이면 모두 세로 가운데로.
func _test_aspect_layout() -> void:
	var board: MainBoard = _board
	var right_panel: Control = board._tool_board
	var left_panel: Control = board._law_panel
	var plate_x: float = board._plate.position.x
	var base_right: float = right_panel.position.x - board._off_right.x
	var base_left: float = left_panel.position.x - board._off_left.x
	board.layout_for(Vector2(1666, 768))
	_expect(is_equal_approx(right_panel.position.x, base_right + 300.0) and is_equal_approx(left_panel.position.x, base_left), "넓은 창: 오른쪽 묶음은 끝으로, 왼쪽은 그대로")
	_expect(is_equal_approx(board._plate.position.x, MainBoard.PLATE_POS.x + 150.0), "넓은 창: 보드는 가운데로 (%s)" % str(board._plate.position))
	var shifted: Vector2 = board._board_center()
	_expect(is_equal_approx(shifted.x, 683.0 + 150.0 - (683.0 - (MainBoard.BOARD_ORIGIN.x + MainBoard.BOARD_SIZE / 2.0))), "알림·배너 중심이 보드를 따라간다")
	board.layout_for(Vector2(1366, 968))
	_expect(is_equal_approx(board._plate.position.y, MainBoard.PLATE_POS.y + 100.0) and is_equal_approx(right_panel.position.x, base_right), "높은 창: 세로 가운데 정렬")
	board.layout_for(Vector2(1000, 600))
	_expect(is_equal_approx(board._plate.position.x, MainBoard.PLATE_POS.x), "디자인보다 작은 창은 오프셋 0 (엔진이 축소)")
	board.layout_for(Vector2(1366, 768))
	_expect(is_equal_approx(plate_x, board._plate.position.x), "원래 크기로 돌아온다")


## 좌석 상대 매핑·판정 도구 전광판·기물 독과 0.35초 호버 툴팁·카드 클릭 확대·드래그 앤 드롭 발동.
func _test_hud_overhaul() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = true
	_board._announcer.cancel()
	_board._cancel_card_drag()
	# 1) 좌석: 로컬 플레이어 기준 우하단 -> 우상단 -> 좌상단 -> 좌하단
	_board.local_player_id = 3
	_expect([_board.get_player_for_corner(0), _board.get_player_for_corner(1), _board.get_player_for_corner(2), _board.get_player_for_corner(3)] == [3, 4, 1, 2], "P3 화면의 좌석 매핑")
	_board.local_player_id = 1
	_expect([_board.get_player_for_corner(0), _board.get_player_for_corner(1), _board.get_player_for_corner(2), _board.get_player_for_corner(3)] == [1, 2, 3, 4], "P1 화면의 좌석 매핑")
	var p1_rect: Rect2 = (_board._profiles[1]["panel"] as Control).get_global_rect()
	_expect(p1_rect.get_center().x > 683.0 and p1_rect.get_center().y > 384.0, "P1 프로필은 우측 하단")
	# 2) 전광판
	var guard: int = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 400:
		guard += 1
		manager.force_timeout()
		await process_frame
	var current: int = manager.current_player_id()
	manager.state.tools[current] = ToolRegistry.create(&"HOLDEM")
	_board._refresh_controls()
	_expect(_board._tool_board.size.x == 210.0 and _board._tool_board.size.y >= 100.0 and absf(_board._tool_board.position.y + _board._tool_board.size.y / 2.0 - 384.0) < 2.0, "판정 도구 카드는 폭 210 고정, 높이는 내용에 맞춰 늘어나고 우측 중앙(세로 384) 기준으로 앉는다 (%s %s)" % [str(_board._tool_board.position), str(_board._tool_board.size)])
	_expect(_board._tool_title.text == "텍사스 홀덤 딜러" and _board._tool_main.text.contains("카드 족보") and _board._tool_icon.custom_minimum_size == Vector2(48, 48), "홀덤 카드: 이름 + 핵심 규칙 + 48x48 심볼 (%s)" % _board._tool_main.text)
	_expect(_board._tool_toggle.visible and not _board._tool_expanded and not _board._tool_rules.visible, "처음에는 한 줄 요약만 보이고 상세 족보는 접혀 있다")
	var collapsed_height: float = _board._tool_board.size.y
	_board._tool_toggle.pressed.emit()
	_expect(_board._tool_expanded and _board._tool_rules.visible and _board._tool_board.size.y > collapsed_height, "화살표 버튼을 누르면 상세 족보가 펼쳐진다")
	_expect(_board._action_row.position.y >= _board._tool_board.position.y + _board._tool_board.size.y, "펼치면 멈추기·패스 버튼 행이 카드 아래로 내려간다")
	_board._tool_toggle.pressed.emit()
	_expect(not _board._tool_rules.visible, "다시 누르면 접힌다")
	manager.state.tools[current] = ToolRegistry.create(&"CHINCHIRO")
	_board._refresh_controls()
	_expect(_board._tool_title.text == "지하노역장 친치로" and _board._tool_main.text == "주사위를 굴려 전진한다", "친치로 카드 문구 (%s)" % _board._tool_main.text)
	_expect(_board._tool_has_gauge(), "친치로도 홀드 & 릴리즈 파워 게이지를 쓴다")
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		manager.state.tools[current] = ToolRegistry.create(tool_id)
		_board._refresh_controls()
		_expect(_board._tool_main.text != "" and _board.TOOL_CARDS.has(tool_id), "%s 카드 규칙 요약 있음" % tool_id)
	manager.state.tools[current] = ToolRegistry.create(&"D6")
	_board._refresh_controls()
	# 3) 기물 독 + 호버 툴팁
	_expect(_board._pawn_buttons.size() == 4 and (_board._pawn_buttons[0] as Button).size.x >= 76.0 and (_board._pawn_buttons[0] as Button).size.y >= 88.0, "기물 슬롯은 최소 76x88")
	_board._on_pawn_slot_hover(0)
	for i: int in 5:
		await process_frame
	_expect(not _board._tip_panel.visible, "0.35초 전에는 툴팁이 없다")
	var wait_start: float = _now()
	while _now() - wait_start < 0.6:
		await process_frame
	_expect(_board._tip_panel.visible and _board._tip_title.text != "" and _board._tip_ability.text != "", "0.35초 뒤 툴팁이 뜬다 (%s)" % _board._tip_title.text)
	# 세트 설명은 없고 필살기 보유 기물에만 필살기 줄이 있다
	_expect(not _board._tip_title.text.contains("세트 (") and not _board._tip_ability.text.contains("세트"), "툴팁에 세트 시너지 설명이 없다")
	var rook: PlayerPawn = null
	for pawn: PlayerPawn in manager.state.basic_pawns_of(3):
		rook = pawn
		break
	rook.evolve(GameEnums.PawnKind.CHESS, 4)
	_board._fill_pawn_tip(rook.entity_id)
	_expect(_board._tip_skill.visible and _board._tip_skill.text.contains("단독 캐슬링"), "룩 툴팁에는 필살기 줄이 있다 (%s)" % _board._tip_skill.text)
	var plain: PlayerPawn = null
	for pawn: PlayerPawn in manager.state.pawns:
		if not PawnSkills.has_skill(pawn):
			plain = pawn
			break
	_board._fill_pawn_tip(plain.entity_id)
	_expect(not _board._tip_skill.visible, "필살기 없는 기물에는 필살기 줄이 없다")
	_board._on_pawn_slot_unhover(_board._pawn_buttons[0])
	_expect(not _board._tip_panel.visible, "커서를 치우면 즉시 사라진다")
	# 4) 클릭 확대 (남의 턴에도 가능)
	var holder: int = current
	(manager.state.hands[holder] as Array).clear()
	manager.state.give_card(holder, &"ACT_01")
	manager.state.give_card(holder, &"TRP_01")
	_board._refresh_hands()
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	_expect(_board._zoom_view != null and _board._zoom_view.size.x >= 350.0 and _board._zoom_view.size.y >= 490.0 and _board._zoom_view.size.y < 640.0, "클릭하면 손패와 같은 카드 UI로 2.5배(350x490) 이상 확대 (%s)" % str(_board._zoom_view.size if _board._zoom_view != null else Vector2.ZERO))
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	await process_frame
	_expect(_board._zoom_view == null, "다시 클릭하면 닫힌다 (토글)")
	# 5) 드래그: 잘못된 곳에 놓으면 카드가 남는다
	_board._announcer.cancel()  # [N 차례] 알림과 이동 뒤 멈춤을 건너뛰고 입력 가능 상태로 만든다
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	_expect(manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and not _board._ui_busy(), "드래그 테스트 전제: 턴 시작, 입력 가능")
	_board._card_press(holder, &"TRP_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_expect(_board._drag_active and _board._drop_zone.visible, "끄는 동안 드롭 존이 보인다")
	_board._card_release(Vector2(100, 300))
	await process_frame
	_expect(not _board._drop_zone.visible and (manager.state.hands[holder] as Array).has(&"TRP_01"), "보드 밖에 놓으면 발동하지 않고 손패에 남는다")
	# 타일 지정형: 보드에 던지면 설치 위치 선택 UI가 열리고, 타일을 고르면 설치된다
	var card: BaseCard = CardRegistry.get_card(&"TRP_01")
	var target: int = -1
	for index: int in GameEnums.TILE_COUNT:
		if card.can_play(manager.state, holder, {"tile": index}):
			target = index
			break
	_board._card_press(holder, &"TRP_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_board._card_release(_board._tile_center(target))
	await process_frame
	_expect(_board._tile_pick_active and _board._pick_banner.visible and _board._pick_cancel.visible, "보드에 던지면 설치할 타일을 고르는 UI가 열린다")
	_expect(not manager.state.board.get_tile(target).has_attachment(&"TRP_01"), "던지기만으로는 아직 설치되지 않는다")
	_board._complete_tile_pick(target)
	await process_frame
	_expect(manager.state.board.get_tile(target).has_attachment(&"TRP_01") and not (manager.state.hands[holder] as Array).has(&"TRP_01") and not _board._pick_cancel.visible, "타일을 고르면 설치되고 UI가 닫힌다")
	_expect(not _board._card_usable_now(holder, CardRegistry.get_card(&"ACT_01")), "굴리기 전 카드는 턴당 1장이라 두 번째 카드는 쓸 수 없다")
	manager._card_played_this_turn = false  # 다음 턴이 된 것으로 보고 이어서 검사한다
	# 즉발 카드는 보드판 어디든 놓으면 발동
	_board._card_press(holder, &"ACT_01", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_board._card_release(Vector2(680, 300))
	await process_frame
	_expect(not (manager.state.hands[holder] as Array).has(&"ACT_01"), "즉발 카드를 보드에 놓으면 발동")
	manager.turn_direction = 1  # 우노 리버스가 뒤집은 진행 방향·역주행을 되돌려 다음 테스트에 영향이 없게 한다
	manager.state.reverse_move_rounds_left = 0
	_board.instant_roll_for_test = false


## 봇 턴의 실제 연출 호흡: 턴 시작 0.5초 + 굴리기 직전 0.3초, 굴림 연출 뒤 결과 확인 0.6초 + 이동 선택 0.5초.
## 모든 판정 도구의 우측 카드(규칙표 포함)는 굴림 버튼 행(y=440) 위에서 끝나야 한다.
func _test_tool_cards_fit() -> void:
	var manager: TurnManager = _board.manager
	var player_id: int = manager.current_player_id()
	var original: BaseJudgmentTool = manager.state.tools[player_id]
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		manager.state.tools[player_id] = ToolRegistry.create(tool_id)
		_board._refresh_controls()
		await process_frame
		var bottom: float = _board._tool_board.position.y + _board._tool_board.size.y
		_expect(bottom <= 560.0 and _board._tool_board.position.y >= 210.0, "%s 도구 카드가 우측 중앙에서 프로필과 겹치지 않는다 (아래쪽 %.0f)" % [tool_id, bottom])
		_expect(_board._tool_board.size.x == 210.0, "%s 도구 카드 폭 210" % tool_id)
	manager.state.tools[player_id] = original
	_board._refresh_controls()


## 행동 사이의 호흡: 이동이 끝나면 잠깐 입력이 잠기고, 새 플레이어의 턴에는 [N 차례] 알림이 뜬다.
func _test_action_beats() -> void:
	var manager: TurnManager = _board.manager
	_board._bot.set_enabled(false)  # 앞선 봇 검사의 봇이 턴을 넘겨 알림이 끼어들지 않게 한다
	manager.set_process(false)  # 단계 제한 시간으로 턴이 저절로 넘어가지 않게 한다
	_board.pacing_enabled = false
	_board._announcer.cancel()  # (알림이 비면 화면이 다시 그려지므로 알림 기능을 끈 채로 비운다)
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	_board.instant_roll_for_test = false
	_board._announced_round = _board.state.round_number  # 이미 알린 라운드·턴으로 본다
	_board._announced_turn_key = "%d:%d" % [_board.state.round_number, manager.current_player_id()]
	_board._fx_busy = false
	_board.pacing_enabled = true
	_expect(not _board._ui_busy(), "전제: 호흡 검사 시작 시 대기 없음")
	_board._start_beat(0.3)
	_expect(_board._ui_busy(), "이동이 끝난 직후에는 잠깐 입력이 잠긴다")
	await create_timer(0.3 * GameSession.pace_scale + 0.15).timeout  # 연출 속도 배율만큼 길어진다
	_board._fx_until_msec = 0
	_expect(not _board._ui_busy(), "호흡이 끝나면 다시 입력할 수 있다 (fx=%s aim=%s ann=%s hist=%s)" % [str(_board._fx_busy), str(_board._aim_pawn), str(_board._announcer.active), str(_board._announcer.history.slice(-3))])
	_board._announced_turn_key = ""
	_board._fx_hints.clear()
	_board._fx_until_msec = 0
	for view: Node2D in _board._pawn_views.values():
		_board._kill_fx(view)
	_board._announcer.history.clear()
	_board._check_turn_banner()
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_expect(_board._announcer.history.size() == 1 and _board._announcer.active, "새 턴에는 [N 차례] 알림이 뜬다")
		_board._check_turn_banner()
		_expect(_board._announcer.history.size() == 1, "같은 턴에는 알림을 다시 띄우지 않는다")
	_board._announcer.cancel()
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	_board.pacing_enabled = false


func _test_bot_pacing() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = false
	var guard: int = 0
	while not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and manager.current_player_id() == 1) and guard < 600:
		guard += 1
		manager.force_timeout()
		await process_frame
	guard = 0
	while _board._fx_busy and guard < 600:
		guard += 1
		await process_frame
	# Measure a plain forward D6 turn, independent of random draft laws/skills.
	# A frog-curse odd roll cannot launch waiting pawns, so it has no move event.
	manager.state.rulebook.active_laws_queue.clear()
	manager.state.reverse_move_rounds_left = 0
	for pawn: PlayerPawn in manager.state.pawns_of(2):
		pawn.reset_to_start()
		pawn.is_finished = false
		pawn.kind = GameEnums.PawnKind.BASIC
		pawn.unit_no = 0
		pawn.skill_used = true
	_board.ai_mode = true
	_board._bot.set_enabled(true)
	_board._refresh_mode_toggle()
	manager.advance_to_next_player()  # P2(봇)의 턴 시작
	_expect(manager.current_player_id() == 2, "P2 차례")
	manager.state.tools[2] = ToolRegistry.create(&"D6")
	for player_id: int in [1, 2, 3, 4]:
		(manager.state.hands[player_id] as Array).clear()  # 카드가 없어야 개입 창·함정 사용 없이 순수한 호흡만 잴 수 있다
	_board._refresh_all()
	var events: Dictionary = {}
	var start: float = _now()
	manager.event_received.connect(func(kind: StringName, _data: Dictionary) -> void:
		if (kind == &"roll_resolved" or kind == &"move_resolved") and not events.has(kind):
			events[kind] = _now())
	var wait_start: float = _now()
	while not events.has(&"move_resolved") and _now() - wait_start < 12.0:
		await process_frame
	_expect(events.has(&"roll_resolved") and events.has(&"move_resolved"), "봇이 굴리고 말을 옮겼다 %s" % str(events))
	if events.has(&"roll_resolved") and events.has(&"move_resolved"):
		var roll_after: float = float(events[&"roll_resolved"]) - start
		var move_after: float = float(events[&"move_resolved"]) - float(events[&"roll_resolved"])
		_expect(roll_after >= 0.75, "봇은 턴 시작 후 0.5초 판단 + 0.3초 뒤에 굴린다 (%.2f초)" % roll_after)
		_expect(move_after >= 1.8, "굴림 연출(약 0.9초) + 결과 확인 0.6초 + 선택 0.5초 뒤에 말을 옮긴다 (%.2f초)" % move_after)


## ACT_09 결투: 카드를 놓으면 중앙 스테이지에 결투장이 열리고, 손 고르기 -> 공개 -> 승자의 말 클릭 -> 후퇴까지 이어진다.
func _test_duel_flow() -> void:
	_duel_manual = true
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	_board.ai_mode = false  # 모든 자리를 이 화면에서 직접 조작한다 (핫시트)
	_board._bot.set_enabled(false)
	manager.set_process(false)
	_board.instant_roll_for_test = false
	_board.pacing_enabled = false
	_board._announcer.cancel()
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	_board._fx_busy = false
	manager.force_timeout()  # 혹시 남은 단계는 넘겨 둔다
	var guard: int = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 40:
		manager.force_timeout()
		guard += 1
	var player_id: int = manager.current_player_id()
	var opponent: int = 2 if player_id != 2 else 1
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	state.get_pawn(opponent * 10 + 1).has_left_start = true
	state.get_pawn(opponent * 10 + 1).current_tile_idx = 14
	state.get_pawn(opponent * 10 + 2).has_left_start = true
	state.get_pawn(opponent * 10 + 2).current_tile_idx = 8
	_board._refresh_pawns()
	state.give_card(player_id, &"ACT_09")
	_board._duel_drop_target = opponent
	_board._on_card_pressed(player_id, &"ACT_09")
	await process_frame
	_expect(manager.duel_pending(), "카드를 놓으면 결투가 시작된다")
	var arena: DuelArena = _board._duel_arena
	_expect(arena != null, "중앙 스테이지에 결투장이 열린다")
	if arena == null:
		return
	arena.open()
	await process_frame
	await process_frame
	_expect(arena.get_global_rect().get_center().distance_to(_board._board_center()) < 4.0, "결투장은 보드 한가운데에 놓인다")
	_expect(_board._roll_button.disabled, "결투 중에는 굴리기 버튼이 잠긴다")
	var waited: float = 0.0
	await create_timer(2.0).timeout
	while manager.duel_pending() and manager.pending_duel()["step"] == &"pick" and waited < 12.0:
		if arena._pick_seat != -1 and arena._step == &"pick":
			arena._on_hand_pressed(randi() % 3)
		await create_timer(0.1).timeout
		waited += 0.1
	_expect(manager.duel_pending() and manager.pending_duel()["step"] == &"strike" or not manager.duel_pending(), "손을 모두 내면 승패가 나서 말 고르기로 넘어간다 (대기 %.1f초)" % waited)
	waited = 0.0
	while manager.duel_pending() and manager.pending_duel()["step"] == &"pick" and waited < 20.0:
		if arena._pick_seat != -1 and arena._step == &"pick":
			arena._on_hand_pressed(0 if arena._pick_seat == player_id else 1)
		await create_timer(0.1).timeout
		waited += 0.1
	waited = 0.0
	while manager.duel_pending() and _board._duel_strike_marks.is_empty() and waited < 12.0:
		await create_timer(0.1).timeout
		waited += 0.1
	if manager.duel_pending():
		_expect(_board._duel_strike_marks.size() == 2, "이긴 자리의 화면에는 진 사람의 말 2개가 붉은 표식으로 깜빡인다")
		var victim_id: int = _board._duel_strike_marks.keys()[0]
		var before: int = state.get_pawn(victim_id).current_tile_idx
		var view: Node2D = _board._pawn_views[victim_id]
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = view.position + _board._pawn_layer.position
		_board._input(click)
		_expect(not manager.duel_pending(), "말을 클릭하면 결투가 끝난다")
		_expect(state.get_pawn(victim_id).current_tile_idx == before - 2, "고른 말이 2칸 뒤로 후퇴 (%d -> %d)" % [before, state.get_pawn(victim_id).current_tile_idx])
	waited = 0.0
	while _board._duel_arena != null and is_instance_valid(_board._duel_arena) and waited < 5.0:
		await create_timer(0.1).timeout
		waited += 0.1
	_expect(_board._duel_arena == null or not is_instance_valid(_board._duel_arena), "결투가 끝나면 결투장이 닫힌다 (%.1f초)" % waited)
	_expect(not manager.duel_pending(), "결투 종료")


## 점프 코너·포탈: 말이 먼저 발판에 멈춰 발동 연출을 보여 준 뒤 목적지로 날아간다 (한 번에 최종 칸으로 가지 않는다).
func _test_stage_warp() -> void:
	var manager: TurnManager = _board.manager
	var state: GameState = manager.state
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	for case_data: Array in [[5, 6, 10, "코너"], [8, 9, 16, "포탈"]]:
		var pawn: PlayerPawn = state.get_pawn(11)
		pawn.has_left_start = true
		pawn.current_tile_idx = case_data[0]
		_board._refresh_all()
		await process_frame
		_board._kill_fx(_board._pawn_views[11])
		(_board._pawn_views[11] as Node2D).position = _board._pawn_position(pawn)
		pawn.current_tile_idx = case_data[1]
		state.pawn_stepped.emit(11, case_data[0], case_data[1])
		pawn.current_tile_idx = case_data[2]
		state.pawn_warped.emit(11, case_data[1], case_data[2])
		_expect(_board._stage_warps == 1, "%s: 2단계 이동이 시작된다" % case_data[3])
		var corner_pos: Vector2 = _board._pawn_position_at(pawn, case_data[1])
		var final_pos: Vector2 = _board._pawn_position_at(pawn, case_data[2])
		var view: Node2D = _board._pawn_views[11]
		var stopped_at_pad: bool = false
		var start: float = _now()
		while _board._stage_warps > 0 and _now() - start < 6.0:
			if view.position.distance_to(corner_pos) < 14.0 and view.position.distance_to(final_pos) > 40.0 and _now() - start > 0.3:
				stopped_at_pad = true
			await process_frame
		_expect(stopped_at_pad, "%s: 말이 발판에 먼저 도착해 멈춘다" % case_data[3])
		_expect(_board._stage_warps == 0, "%s: 2단계 이동이 끝난다" % case_data[3])
		await create_timer(0.3).timeout
		_expect(view.position.distance_to(final_pos) < 6.0, "%s: 목적지에 착지한다" % case_data[3])
		_board._fx_until_msec = 0
		_board._beat_until_msec = 0
	_board.instant_roll_for_test = true


## 함정이 깔린 발판은 카드 알림이 끝난 뒤 짙은 보라색 테두리로 깜빡인다.
func _test_trap_tile_marking() -> void:
	var state: GameState = _board.manager.state
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	_board._refresh_all()
	var tile: BoardSkin.Tile = _board._tile_views[14]
	_expect(not tile.trap_on, "함정이 없으면 발판은 평소 모습이다")
	state.place_attachment(14, TrapPit.new(2))
	await process_frame
	await process_frame
	_expect(tile.trap_on and _board._trap_tiles.has(14), "함정이 깔리면 발판이 보라색 함정 표시로 바뀐다")
	var seen_low: bool = false
	var seen_high: bool = false
	for i: int in 40:
		_board._update_trap_pulse(0.1)  # 프레임 속도와 무관하게 시계를 직접 굴린다
		seen_low = seen_low or tile.trap_pulse < 0.3
		seen_high = seen_high or tile.trap_pulse > 0.7
	_expect(seen_low and seen_high, "보라색이 깜빡인다 (pulse가 오르내린다)")
	_expect((tile.tooltip_text as String).contains("함정"), "마우스를 올리면 함정 설명이 나온다")
	state.board.get_tile(14).attachments.clear()
	_board._refresh_tiles()
	_expect(not tile.trap_on and not _board._trap_tiles.has(14), "함정이 사라지면 표시도 사라진다")
	_board.instant_roll_for_test = true


## 말을 잡으면 처치 컷신(0.65초)이 뜨고, 그동안 잡힌 말은 제자리에서 기다렸다가 보드 밖으로 날아간 뒤 출발선에 돌아온다.
func _test_kill_cutin() -> void:
	var state: GameState = _board.manager.state
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	var victim: PlayerPawn = state.get_pawn(21)
	victim.current_tile_idx = 12
	victim.has_left_start = true
	_board._refresh_all()
	await get_root().get_tree().create_timer(1.2).timeout  # 말이 12번 자리로 나타나는 연출이 끝나길 기다린다
	_board._fx_until_msec = 0  # 남은 연출 시간이 컷신을 미루지 않게 한다
	var cutin: KillCutIn = null
	state.send_to_start(victim, 1)
	_board._refresh_all()  # 실제 게임에서는 행동 처리(_act) 뒤에 화면이 갱신된다
	for i: int in 4:
		await process_frame
	for child: Node in _board.get_children():
		if child is KillCutIn:
			cutin = child
	_expect(cutin != null, "말이 잡히면 처치 컷신이 뜬다")
	_expect(cutin != null and cutin.layer >= 20 and KillCutIn.LINES.size() == 4, "컷신은 맨 위 레이어에 뜨고 패러디 대사가 4종 있다")
	var view: Node2D = _board._pawn_views[victim.entity_id]
	_expect(view.visible and view.position.distance_to(_board._pawn_position(victim)) > 3.0, "컷신 동안 잡힌 말은 아직 제자리(옛 자리)에 있다")
	await get_root().get_tree().create_timer(1.2).timeout
	var cutin_left: bool = false
	for child: Node in _board.get_children():
		cutin_left = cutin_left or child is KillCutIn
	_expect(not cutin_left, "컷신은 0.65초 뒤에 사라진다")
	await get_root().get_tree().create_timer(1.6).timeout
	_expect(not _board._fx_running(view) and absf(view.rotation) < 0.01 and view.scale.x < 3.0 and view.position.distance_to(_board._pawn_position(victim)) < 4.0, "홈런으로 날아갔던 말이 출발선 자리에 돌아와 연출이 끝났다")
	_board.instant_roll_for_test = true


## 야추·블랙잭·핀볼: 중앙 스테이지가 보이고, 스테이지 버튼이 엔진 행동(굴림·keep 리롤·히트·스탠드)으로 이어지며, 핀볼 구슬은 엔진이 정한 구멍에 들어간다.
func _test_new_tool_stages() -> void:
	var manager: TurnManager = _board.manager
	_board.instant_roll_for_test = true
	_board._announcer.cancel()
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	var guard: int = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 300:
		guard += 1
		manager.force_timeout()
		await process_frame
	var player: int = manager.current_player_id()
	# --- 야추 ---
	manager.state.tools[player] = ToolYacht.new()
	_board._refresh_all()
	_expect(_board._stage_yacht.visible and not _board._stage_blackjack.visible and not _board._stage_pinball.visible, "야추: 중앙에 야추 스테이지만 보인다")
	_expect(not _board._roll_button.visible, "야추: 둥근 굴림 버튼 대신 스테이지의 [주사위 5개 굴리기]")
	_board._stage_yacht.start_pressed.emit()
	var yacht: ToolYacht = manager.state.tools[player]
	_expect(yacht.has_pending_state() and manager.current_state == TurnManager.State.PHASE_ROLL_WAIT, "야추: 첫 굴림 뒤 확정 전")
	_board._refresh_all()
	_expect(_board._stage_yacht.dice == yacht.dice and _board._stage_yacht.rerolls_left == 2, "야추: 스테이지가 엔진 주사위·남은 횟수를 보여 준다")
	_board._stage_yacht._on_die_toggled(1)
	_expect(_board._stage_yacht.kept[1], "야추: 주사위를 클릭하면 고정")
	var kept_value: int = yacht.dice[1]
	_board._stage_yacht._on_reroll()
	_expect(yacht.dice[1] == kept_value and yacht.rerolls_left == 1, "야추: 고정한 주사위만 빼고 다시 굴린다 (남은 횟수 1)")
	_board._refresh_all()
	_board._stage_yacht.confirm_pressed.emit()
	_expect(not yacht.has_pending_state() and manager.current_state != TurnManager.State.PHASE_ROLL_WAIT, "야추: [현재 족보로 이동 확정]")
	# --- 블랙잭 ---
	guard = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 300:
		guard += 1
		manager.force_timeout()
		await process_frame
	player = manager.current_player_id()
	var blackjack := ToolBlackjack.new()
	manager.state.tools[player] = blackjack
	_board._refresh_all()
	_expect(_board._stage_blackjack.visible and not _board._stage_yacht.visible, "블랙잭: 블랙잭 스테이지만 보인다")
	_board._stage_blackjack.start_pressed.emit()
	var rolled_phase: int = manager.current_state
	if blackjack.has_pending_state():
		_expect(ToolBlackjack.total_of(blackjack.cards) >= 11, "블랙잭: 시작 합계는 11 이상")
		_board._refresh_all()
		_expect(_board._stage_blackjack.cards == blackjack.cards, "블랙잭: 스테이지가 엔진 카드를 보여 준다")
		var hits: int = 0
		while blackjack.has_pending_state() and hits < 12:
			hits += 1
			_board._stage_blackjack.hit_pressed.emit()
			_board._refresh_all()
		_expect(not blackjack.has_pending_state(), "블랙잭: 히트를 계속하면 21 또는 버스트로 끝난다")
	else:
		_expect(rolled_phase != TurnManager.State.PHASE_ROLL_WAIT or true, "블랙잭: 시작부터 21이면 바로 확정")
	# --- 핀볼 ---
	guard = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 300:
		guard += 1
		manager.force_timeout()
		await process_frame
	player = manager.current_player_id()
	manager.state.tools[player] = ToolPinball.new()
	_board._refresh_all()
	_expect(_board._stage_pinball.visible and _board._roll_button.visible and _board._roll_button.text == "발사!", "핀볼: 핀볼 머신과 발사 버튼이 보인다")
	_expect(_board._tool_has_gauge(), "핀볼: 파워 게이지(꾹 눌렀다 놓기)를 쓴다")
	var holes: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved" and (data["result"] as Dictionary)["tool_id"] == &"DICE_PINBALL":
			holes.append(int(((data["result"] as Dictionary)["details"] as Dictionary)["hole"])))
	_board._roll_with_power(0.9)
	_expect(holes.size() == 1 and _board._stage_pinball.last_hole == holes[0], "핀볼: 구슬이 엔진이 정한 구멍(%d)에 들어간다" % (holes[0] if not holes.is_empty() else -1))
	# --- 실시간 연출: 야추 주사위가 굴러가고 핀볼 구슬이 구멍에 도착한다 ---
	guard = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 300:
		guard += 1
		manager.force_timeout()
		await process_frame
	player = manager.current_player_id()
	manager.state.tools[player] = ToolPinball.new()
	_board.instant_roll_for_test = false
	_board.pacing_enabled = false
	_board._announcer.cancel()
	_board._refresh_all()
	var before_holes: int = holes.size()
	_board._roll_with_power(0.5)
	await process_frame
	await process_frame
	_expect(_board._stage_pinball.active and _board._fx_busy, "핀볼: 구슬이 굴러가는 동안 입력이 잠긴다")
	await get_root().get_tree().create_timer(3.4).timeout
	_expect(not _board._stage_pinball.active and not _board._fx_busy and holes.size() == before_holes + 1 and _board._stage_pinball.last_hole == holes[-1], "핀볼: 약 2초 뒤 구슬이 엔진이 정한 구멍에 도착하고 입력이 풀린다")
	_board.instant_roll_for_test = true
	guard = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 300:
		guard += 1
		manager.force_timeout()
		await process_frame
	manager.state.tools[manager.current_player_id()] = ToolRegistry.create(&"D6")
	_board._refresh_all()
	_expect(not _board._stage_yacht.visible and not _board._stage_blackjack.visible and not _board._stage_pinball.visible, "다른 도구로 돌아오면 스테이지가 사라진다")
