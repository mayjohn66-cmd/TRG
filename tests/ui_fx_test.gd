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
	# 다른 검사 중에 봇이 건 결투는 시간 초과로 넘겨 검사가 막히지 않게 한다 (결투 검사만 직접 진행).
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
	await _test_npc_danger_preview()
	await _test_event_order()
	await _test_presentation_queue()
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
					# Native PNGs can differ by a few pixels; retain their actual aspect without stretching.
					var source_aspect: float = float(art.texture.get_width()) / float(art.texture.get_height())
					_expect(absf(source_aspect - 4.0 / 3.0) < 0.01, "%s illustration remains approximately 4:3" % card_id)
					_expect(is_equal_approx(art.size.x / art.size.y, source_aspect), "%s preserves the entire source illustration without distortion, detailed=%s" % [card_id, detailed])
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
		presenter.play(&"CHINCHIRO", {"steps": maxi(value, 0), "details": {"face": value, "oops": value == -6}}, 0.8)
		presenter._process(DiceRoll3D.ROLL_TIME + DiceRoll3D.HOLD_TIME)
		_expect(presenter._dice_3d == die_view, "loaded die shares the same 3D viewport")
		_expect(die_view.displayed_value() == value and presenter.last_display == str(maxi(value, 0)), "loaded physical face and displayed result match %d" % value)
		_expect(die_view._pips.mesh != ordinary_mesh, "loaded die uses its own face paint")
		_expect(die_view.render_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "loaded die stops rendering after result")
		if value < 0:
			_expect(presenter._die_label.text.contains("0칸") and not presenter._die_label.text.contains("후퇴"), "oops is shown as a zero-tile failure, never a retreat")
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
	elapsed = await _play(&"DICE_TAROT", {"tool_id": &"DICE_TAROT", "steps": 6, "details": {"fate": &"chariot", "name": "VII. 전차 (The Chariot)", "flipped": 2}}, sample_tarot)
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
		presenter.play(&"DICE_TAROT", {"steps":0, "details":{"fate":fate, "flipped":selected}})
		await process_frame
		await process_frame
		presenter._update(0.52)
		_expect(presenter._card_flipped.count(true) == 0 and presenter._die_label.text.is_empty() and presenter.last_display.is_empty(), "tarot fate remains hidden during focus and first flip half")
		presenter._update(0.65)
		_expect(presenter._card_flipped.count(true) == 1, "tarot reveals exactly one card at every selection position")
		_expect(presenter._die_label.text.contains("이동 없음"), "zero engine movement is shown as no movement")
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
	presenter.play(&"YUT",{"steps":0,"ends_turn":true,"details":{"face":0,"nak":true}})
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
	_expect(view.displayed_value()==0 and presenter.last_display=="낙","marked stick off the mat and engine 낙 agree")
	_expect(presenter._die_label.text=="낙 · 0칸, 턴 종료","낙 is shown as 0 steps and the turn ends")
	view.stick_landed.disconnect(observer)
	presenter._process(presenter._total)
	_expect(not presenter.active and view.render_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"completion releases input and stops Yut rendering")
	for value: int in ToolYut.FACES:
		presenter.play(&"YUT",{"steps":value,"ends_turn":value==0,"reroll":value>=4,"details":{"face":value}},0.1)
		presenter._update(YutThrow3D.RESULT_TIME+0.001)
		_expect(presenter._yut_3d==view,"all outcomes reuse the same four meshes and viewport")
		_expect(view.displayed_value()==value and presenter.last_display==RollPresenter.YUT_NAMES[value],"six physical outcomes agree with engine values")
		_expect(presenter._die_label.text.contains("한 번 더")==bool(value>=4),"only Yut/Mo results show reroll")
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


## 굴림 버튼을 한 번만 눌러도 바로 연출이 돌며 그동안 입력이 잠기고, 끝나면 결과가 공개된다.
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
	_expect(not _board.has_method("_begin_charge"), "누르고 있는 차징 조작은 없다 (원클릭)")
	_board._roll_button.pressed.emit()  # 한 번 클릭하면 바로 굴러간다
	_expect(absf(_board._pending_power - MainBoard.ONE_CLICK_POWER) < 0.01, "원클릭 굴림은 고정 연출 세기를 쓴다")
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
	# 키보드: R을 한 번 누르면 굴린다
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
	_expect(not _board._fx_busy, "instant 모드는 연출 대기 없이 즉시 결과를 공개한다 (R 키 한 번 = 바로 굴림)")
	# With no selectable pawn, a valid instant roll can already reach the next
	# player's TURN_BEGIN. Assert the actual result event instead of that phase.
	_expect(resolved.size() == 1, "R 키를 한 번 누르면 굴림 결과가 정확히 한 번 확정된다 (떼는 입력은 무시)")


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
	_expect(is_equal_approx(avatar._sprite.scale.y, avatar.art_height() / 60.0) and avatar.art_height() > avatar.size.y, "스프라이트는 칸보다 조금 크게(들썩여도 가장자리가 안 보이게) 맞춰진다")
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
	# 게임 이벤트는 아바타 표정을 바꾸지 않는다: 표정은 플레이어가 고른 감정 표현(이모트)으로만 바뀐다.
	for player_id: int in [1, 2, 3, 4]:
		(_board._profiles[player_id]["avatar"] as AvatarSlot).react(AvatarSlot.Emotion.IDLE, 0.0)
	var victim: PlayerPawn = _board.state.get_pawn(21)
	_board.state.pawn_sent_to_start.emit(victim.entity_id, 1)
	_board.state.pawn_finished.emit(31)
	var changed: bool = false
	for i: int in 60:  # 3초 동안 연출 큐가 돌아도
		for player_id: int in [1, 2, 3]:
			changed = changed or (_board._profiles[player_id]["avatar"] as AvatarSlot).emotion != AvatarSlot.Emotion.IDLE
		await create_timer(0.05).timeout
	_expect(not changed, "말이 잡히거나 완주해도 아바타 표정은 그대로다")
	for player_id: int in [1, 2, 3, 4]:
		(_board._profiles[player_id]["avatar"] as AvatarSlot).react(AvatarSlot.Emotion.IDLE, 0.0)


## 보드 시점: 탑뷰 <-> 기울인 시점. 두 시점 모두 같은 마름모 배치이고 규칙 좌표는 그대로이며, 시점은 배경을 유지하고 보드 면 그림자·말 높이만 바꾼다.
func _test_view_modes() -> void:
	_expect(_board.view_mode == MainBoard.ViewMode.TOP and not _board._plate.visible and _board._board_surface.visible and _board._match_background.visible, "탑뷰에서도 풍경 배경과 마름모 보드 면이 보인다")
	var top_centers: Array[Vector2] = []
	for index: int in BoardSpec.tile_count:
		top_centers.append(_board._tile_center(index))
	var side: int = BoardSpec.side
	_expect(top_centers[0].y > top_centers[side].y and top_centers[0].y > top_centers[side * 3].y and absf(top_centers[0].x - 683.0) < 1.0, "0번 출발선은 마름모의 아래 꼭짓점")
	_expect(top_centers[side].x > top_centers[0].x and top_centers[side * 3].x < top_centers[0].x and top_centers[side * 2].y < top_centers[side].y, "한 변 번호는 오른쪽, 두 변은 위, 세 변은 왼쪽 꼭짓점 (반시계)")
	var pawn_id: int = 11
	var pawn: PlayerPawn = _board.state.get_pawn(pawn_id)
	var top_pawn_position: Vector2 = _board._pawn_position(pawn)
	_board.set_view_mode(MainBoard.ViewMode.TILT)
	_expect(not _board._plate.visible and _board._board_surface.visible and _board._match_background.visible and _board._pawn_layer.y_sort_enabled, "기울인 시점: 같은 풍경 배경을 유지하고 말이 깊이순으로 그려진다")
	var restored_in_tilt: bool = true
	for index: int in BoardSpec.tile_count:
		restored_in_tilt = restored_in_tilt and _board._tile_center(index).is_equal_approx(top_centers[index])
	_expect(restored_in_tilt, "두 시점의 타일 좌표는 같다")
	var all_inside: bool = true
	for a: int in BoardSpec.tile_count:
		var tile_a: BoardSkin.Tile = _board._tile_views[a]
		var poly_a := PackedVector2Array()
		for point: Vector2 in tile_a.outline_points:
			poly_a.append(tile_a.position + tile_a.size / 2.0 + (point - tile_a.size / 2.0) * tile_a.scale)
		for point: Vector2 in poly_a:
			all_inside = all_inside and Rect2(Vector2.ZERO, Vector2(1366, 768)).has_point(point)
		for b: int in range(a + 1, BoardSpec.tile_count):
			var tile_b: BoardSkin.Tile = _board._tile_views[b]
			var poly_b := PackedVector2Array()
			for point: Vector2 in tile_b.outline_points:
				poly_b.append(tile_b.position + tile_b.size / 2.0 + (point - tile_b.size / 2.0) * tile_b.scale)
			_expect(Geometry2D.intersect_polygons(poly_a, poly_b).is_empty(), "타일 %d와 %d가 겹침" % [a, b])
	_expect(all_inside, "기울인 시점의 모든 타일이 화면 안")
	_expect((_board._pawn_views[pawn_id] as Node2D).get_node("Shadow").visible, "말 그림자가 보인다")
	_expect(_board._board_edge.points.size() >= 64 and _board._track_lines.size() == 1, "둥근 보드 윤곽과 순환 경로선 1개가 다시 그려진다")
	var safe: PackedVector2Array = BoardSkin.safe_outline(_board._surface_project)
	for i: int in BoardSpec.tile_count:
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
	_expect(BoardSpec.jump_corner_targets.is_empty(), "코너 점프대는 삭제되었다")
	# 경로선이 새 위치를 따라간다
	_expect(_board._track_lines[0].points[0].is_equal_approx(_board._tile_center(0)), "경로선이 투영 좌표를 따라간다")
	# 시점은 설정으로 저장된다
	_expect(GameSession.view_mode == MainBoard.ViewMode.TILT, "시점이 세션 설정에 기록된다")
	_board.set_view_mode(MainBoard.ViewMode.TOP)
	var restored: bool = true
	for index: int in BoardSpec.tile_count:
		restored = restored and _board._tile_center(index).is_equal_approx(top_centers[index])
	_expect(restored and not _board._plate.visible and _board._board_surface.visible and _board._match_background.visible, "탑뷰로 돌아오면 모든 좌표와 배경이 그대로 돌아온다")
	_expect(_board._pawn_position(pawn).is_equal_approx(top_pawn_position) and not _board._pawn_layer.y_sort_enabled, "말 위치도 그대로")
	GameSession.view_mode = MainBoard.ViewMode.TOP


## 상단 UI는 왼쪽 [피드백 / 버그 제보]와 오른쪽 [배속]·[메뉴]뿐이고 (소리·언어는 설정), 메뉴 안에서 계속하기/게임 설정/전체 로그/새 게임/모드/치트/게임 나가기를 고른다.
func _test_game_menu() -> void:
	var top_buttons: Array[Button] = []
	for child: Node in _board.get_children():
		var button: Button = child as Button
		if button != null and button.visible and button.position.y < 44.0 and button.size.y <= 40.0:
			top_buttons.append(button)
	_expect(top_buttons.size() == 3 and top_buttons.has(_board._menu_button) and top_buttons.has(_board._feedback_button) and top_buttons.has(_board._speed_button), "상단에는 왼쪽 [피드백]·오른쪽 [배속]·[메뉴] 세 개만 남는다 (%d개)" % top_buttons.size())
	# [배속]: 1x -> 2x -> 3x -> 1x, Engine.time_scale에 걸린다
	var speed_before: int = GameSession.game_speed
	GameSession.game_speed = 1
	_board._apply_game_speed()
	_board._speed_button.pressed.emit()
	_expect(GameSession.game_speed == 2 and is_equal_approx(Engine.time_scale, 2.0) and _board._speed_button.text == "배속 2x", "배속 버튼: 2x (%s)" % _board._speed_button.text)
	_board._speed_button.pressed.emit()
	_expect(GameSession.game_speed == 3 and is_equal_approx(Engine.time_scale, 3.0), "배속 버튼: 3x")
	_board._speed_button.pressed.emit()
	_expect(GameSession.game_speed == 1 and is_equal_approx(Engine.time_scale, 1.0), "배속 버튼: 다시 1x")
	GameSession.game_speed = speed_before
	_board._apply_game_speed()
	Engine.time_scale = 1.0
	_expect(_board._feedback_button.position.x < 200.0 and _board._menu_button.position.x > 1000.0, "피드백은 왼쪽 위, 메뉴는 오른쪽 위")
	_expect(_board._mode_toggle.get_parent() == null and _board._new_game_button.get_parent() == null and _board._debug_toggle.get_parent() == null, "닫힌 메뉴에서는 모드·새 게임·치트 버튼이 화면에 없다")
	_expect(not _board._menu_is_open(), "처음에는 메뉴가 닫혀 있다")
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
	_expect(_board._emote_row != null and _board._emote_row.visible and _board._emote_button != null and not _board._emote_picker.visible, "AI 대전에는 [감정 표현] 버튼 하나만 보이고 이모트 판은 접혀 있다")
	_board._emote_ready_msec = 0
	_board._emote_button.pressed.emit()
	_expect(_board._emote_picker.visible and _board._emote_picker.find_children("Emote*", "Button", true, false).size() == EmoteCatalog.count(), "버튼을 누르면 이모트 %d종이 펼쳐진다" % EmoteCatalog.count())
	(_board._emote_picker.find_child("Emote2", true, false) as Button).pressed.emit()
	var bubble: EmoteBubble = _board._emote_bubbles.get(_board.local_player_id)
	_expect(not _board._emote_picker.visible and bubble != null and is_instance_valid(bubble) and bubble.emote_id == 2, "이모트를 고르면 판이 닫히고 내 프로필에 말풍선이 뜬다")
	_expect((_board._profiles[_board.local_player_id]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.ANGRY, "말풍선과 함께 아바타 표정이 바뀐다 (억까 → 분노)")
	if bubble != null:
		var avatar_rect: Rect2 = _board.get_global_transform().affine_inverse() * (_board._profiles[_board.local_player_id]["avatar"] as Control).get_global_rect()
		_expect(bubble.position.y + bubble.size.y <= avatar_rect.position.y + 4.0, "아래쪽 내 프로필의 말풍선은 아바타 위로 뜬다 (%.0f <= %.0f)" % [bubble.position.y + bubble.size.y, avatar_rect.position.y])
	_board._emote_button.pressed.emit()
	(_board._emote_picker.find_child("Emote4", true, false) as Button).pressed.emit()
	_expect(_board._emote_bubbles.get(_board.local_player_id) == bubble and (_board._profiles[_board.local_player_id]["avatar"] as AvatarSlot).emotion == AvatarSlot.Emotion.ANGRY, "연타는 대기 시간 동안 무시된다")
	var other: int = 2 if _board.local_player_id != 2 else 1
	_board._on_net_emote(other, 6)
	var their: EmoteBubble = _board._emote_bubbles.get(other)
	_expect(their != null and is_instance_valid(their) and their.emote_id == 6, "온라인 상대의 이모트도 그 사람 프로필에 말풍선으로 뜬다")
	if their != null:
		var their_rect: Rect2 = _board.get_global_transform().affine_inverse() * (_board._profiles[other]["avatar"] as Control).get_global_rect()
		var below: bool = their_rect.get_center().y < _board._board_center().y
		_expect(their.position.y >= their_rect.end.y - 4.0 if below else their.position.y + their.size.y <= their_rect.position.y + 4.0, "상대 말풍선은 아바타에서 화면 안쪽으로 뜬다")
	_board._emote_button.pressed.emit()
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(20, 20)
	_board._input(outside)
	_expect(not _board._emote_picker.visible, "이모트 판 밖을 누르면 닫힌다")
	for player_id: int in _board._emote_bubbles.keys():
		var shown: Variant = _board._emote_bubbles[player_id]
		if shown != null and is_instance_valid(shown):
			(shown as Node).queue_free()
		if _board._profiles.has(player_id):
			(_board._profiles[player_id]["avatar"] as AvatarSlot).react(AvatarSlot.Emotion.IDLE, 0.0)
	# 메뉴가 열려 있는 동안 봇은 쉰다
	_expect(_board._bot_should_wait(), "혼자 하는 판은 메뉴가 열려 있는 동안 봇이 멈춘다")
	# 게임 설정
	_board._show_menu_page(&"settings")
	_expect(_board._menu_page == &"settings" and _board._menu_box.find_child("PacingCheck", true, false) == null and _board._menu_box.find_child("TimerCheck", true, false) != null and _board._menu_box.find_child("ShakeSwitch", true, false) != null and _board._menu_box.find_child("MasterVolume", true, false) != null and _board._menu_box.find_child("ResetSettings", true, false) != null, "게임 설정 화면: 화면·소리·제한 시간·기본값 (연출 멈춤 없음)")
	var shake_before: bool = GameSession.screen_shake
	(_board._menu_box.find_child("ShakeSwitch", true, false) as CheckButton).button_pressed = not shake_before
	_expect(GameSession.screen_shake == not shake_before, "화면 흔들림 스위치가 바로 적용된다")
	(_board._menu_box.find_child("MasterMute", true, false) as Button).button_pressed = true
	_expect(GameSession.audio_muted, "전체 음소거 = 위쪽 소리 버튼과 같은 값")
	(_board._menu_box.find_child("ResetSettings", true, false) as Button).pressed.emit()
	_expect(GameSession.screen_shake and not GameSession.audio_muted and _board._menu_page == &"settings", "기본값으로: 설정이 처음 값으로 돌아간다")
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
	# 굴림이 시작되면 안 막는 배너(차례·라운드)는 걷히고, 줄 서 있던 안 막는 배너는 버려진다. 막는 알림은 남는다
	_board._announce_soft("라운드", "3라운드 시작!", "", Color.WHITE, null, 2.0)
	_board._announce_soft("안내", "컴퓨터 2 차례", "", Color.WHITE, null, 2.0)
	_expect(announcer.active and str(announcer._current.get("headline", "")) == "3라운드 시작!", "안 막는 배너가 떠 있고 다음 배너가 줄 서 있다")
	var shown: Array[String] = []
	var on_start: Callable = func(_serial: int) -> void: shown.append(str(announcer._current.get("headline", "")))
	announcer.entry_started.connect(on_start)
	announcer.dismiss_soft()
	for _i: int in 30:
		await process_frame
	announcer.entry_started.disconnect(on_start)
	_expect(not announcer.active and not announcer.visible and shown.is_empty(), "굴림 시작 시 안 막는 배너는 걷히고 줄 선 배너는 뜨지 않는다 (%s)" % str(shown))
	_board._announce_soft("안내", "컴퓨터 3 차례", "", Color.WHITE, null, 2.0)
	_board._announce("테스트", "막는 알림", "", Color.WHITE, null, 2.0)
	announcer.dismiss_soft()
	for _i: int in 30:
		await process_frame
	_expect(announcer.holding() and str(announcer._current.get("headline", "")) == "막는 알림", "막는 알림은 그대로 남는다")
	announcer.cancel()
	announcer.history.clear()
	_board.instant_roll_for_test = true
	_board._announce("테스트", "건너뜀", "", Color.WHITE, null, 0.5)
	_expect(not announcer.active, "instant면 알림을 띄우지 않는다")
	_board.instant_roll_for_test = false


## 룰렛은 원판을 한 번 누르면 도는 패드, 러시안 룰렛은 방아쇠 패드, 나머지는 둥근 굴리기 버튼. 패드 조작이 엔진 굴림으로 이어지고 원판은 엔진 눈금에 멈춘다.
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
	_expect(faces.size() == 1 and pad.last_face == faces[0], "원판을 한 번 누르면 굴러가고 원판은 엔진 눈금에 멈춘다 (%s / %d)" % [str(faces), pad.last_face])
	# 원클릭: 원판을 한 번 누르는 것만으로 굴러갔다 (누른 채 돌릴 필요 없음). 이어서 리볼버로 넘어간다.
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
	if _board._center_banner != null:
		_board._center_banner.hide()
	pad.trigger_pulled.emit()
	_expect(shots.size() == 1, "방아쇠를 당기면 엔진이 굴린다")
	if shots.size() == 1 and bool((shots[0] as Dictionary).get("can_continue", false)):
		_expect(_board._center_banner == null or not _board._center_banner.visible, "살아남은 방아쇠마다 칸수 배너를 띄우지 않는다 (최종 결과 뒤 한 번만)")
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
	manager.state.give_card(holder, &"ACT_04")
	manager.state.give_card(holder, &"TRP_07")
	_board._refresh_hands()
	_board._card_press(holder, &"ACT_04", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	_expect(_board._zoom_view != null and _board._zoom_view.size.x >= 350.0 and _board._zoom_view.size.y >= 490.0 and _board._zoom_view.size.y < 640.0, "클릭하면 손패와 같은 카드 UI로 2.5배(350x490) 이상 확대 (%s)" % str(_board._zoom_view.size if _board._zoom_view != null else Vector2.ZERO))
	_board._card_press(holder, &"ACT_04", Vector2(700, 700), Vector2(700, 640))
	_board._card_release(Vector2(701, 700))
	await process_frame
	_expect(_board._zoom_view == null, "다시 클릭하면 닫힌다 (토글)")
	# 5) 드래그: 잘못된 곳에 놓으면 카드가 남는다
	_board._announcer.cancel()  # [N 차례] 알림과 이동 뒤 멈춤을 건너뛰고 입력 가능 상태로 만든다
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	_expect(manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and not _board._ui_busy(), "드래그 테스트 전제: 턴 시작, 입력 가능")
	_board._card_press(holder, &"TRP_07", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_expect(_board._drag_active and _board._drop_zone.visible, "끄는 동안 드롭 존이 보인다")
	_board._card_release(Vector2(100, 300))
	await process_frame
	_expect(not _board._drop_zone.visible and (manager.state.hands[holder] as Array).has(&"TRP_07"), "보드 밖에 놓으면 발동하지 않고 손패에 남는다")
	# 타일 지정형: 보드에 던지면 설치 위치 선택 UI가 열리고, 타일을 고르면 설치된다
	var card: BaseCard = CardRegistry.get_card(&"TRP_07")
	var target: int = -1
	for index: int in BoardSpec.tile_count:
		if card.can_play(manager.state, holder, {"tile": index}):
			target = index
			break
	_board._card_press(holder, &"TRP_07", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_board._card_release(_board._tile_center(target))
	await process_frame
	_expect(_board._tile_pick_active and _board._pick_banner.visible and _board._pick_cancel.visible, "보드에 던지면 설치할 타일을 고르는 UI가 열린다")
	_expect(not manager.state.board.get_tile(target).has_attachment(&"TRP_07"), "던지기만으로는 아직 설치되지 않는다")
	_board._complete_tile_pick(target)
	await process_frame
	_expect(manager.state.board.get_tile(target).has_attachment(&"TRP_07") and not (manager.state.hands[holder] as Array).has(&"TRP_07") and not _board._pick_cancel.visible, "타일을 고르면 설치되고 UI가 닫힌다")
	_expect(not _board._card_usable_now(holder, CardRegistry.get_card(&"ACT_04")), "굴리기 전 카드는 턴당 1장이라 두 번째 카드는 쓸 수 없다")
	manager._card_played_this_turn = false  # 다음 턴이 된 것으로 보고 이어서 검사한다
	# 즉발 카드는 보드판 어디든 놓으면 발동
	_board._card_press(holder, &"ACT_04", Vector2(700, 700), Vector2(700, 640))
	_board._card_move(Vector2(720, 600))
	_board._card_release(Vector2(680, 300))
	await process_frame
	_expect(not (manager.state.hands[holder] as Array).has(&"ACT_04"), "즉발 카드를 보드에 놓으면 발동")
	manager.state.roll_bonus = 0  # 로켓 보너스가 다음 테스트에 영향이 없게 한다
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
	_board._reset_presentation()  # 앞선 검사가 남긴 연출 큐를 비운다
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
		_expect(roll_after >= 0.45 and roll_after < 1.5, "봇은 턴 시작 후 0.3초 판단 + 0.2초 뒤에 굴린다 (%.2f초)" % roll_after)
		_expect(move_after >= 0.45 and move_after < 4.0, "굴림 연출 + 결과 확인 0.3초 + 선택 0.2초 뒤에 말을 옮기고, 이동은 0.75초 안에 끝난다 (%.2f초)" % move_after)


## ACT_09 결투: 카드를 놓으면 중앙 스테이지에 결투장이 열리고, 손 고르기 -> 공개 -> 승자의 말 클릭 -> 후퇴까지 이어진다.
func _test_duel_flow() -> void:
	_duel_manual = true
	var manager: TurnManager = _board.manager
	_board.ai_mode = false  # 모든 자리를 이 화면에서 직접 조작한다 (핫시트)
	_board._bot.set_enabled(false)
	manager.set_process(false)
	_board.instant_roll_for_test = false
	_board.pacing_enabled = false
	var orphans_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for game: int in DuelRules.GAME_COUNT:
		await _play_one_duel(game)
	await process_frame
	await process_frame
	_expect(root.find_child("DuelArenaModal", true, false) == null, "결투가 끝나면 결투장 모달이 트리에 남지 않는다 (queue_free)")
	var orphans_after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_expect(orphans_after <= orphans_before + 2, "결투 6판 뒤 고아 노드가 늘지 않는다 (%d -> %d)" % [orphans_before, orphans_after])
	manager.duel_game_override = -1


## 종목 하나를 핫시트로 끝까지: 화면의 입력 함수로 두 자리 모두 값을 낸다.
func _play_one_duel(game: int) -> void:
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	_board._announcer.cancel()
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	_board._fx_busy = false
	var guard: int = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 40:
		manager.force_timeout()
		guard += 1
	manager.duel_game_override = game
	manager._card_played_this_turn = false  # 검사용: 같은 턴에 종목마다 결투 카드를 다시 낸다
	var player_id: int = manager.current_player_id()
	var opponent: int = 2 if player_id != 2 else 1
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	for pair: Array in [[player_id * 10 + 1, 5], [opponent * 10 + 1, 14], [opponent * 10 + 2, 8]]:
		state.get_pawn(pair[0]).has_left_start = true
		state.get_pawn(pair[0]).current_tile_idx = pair[1]
	_board._refresh_pawns()
	state.give_card(player_id, &"ACT_09")
	_board._duel_drop_target = opponent
	_board._on_card_pressed(player_id, &"ACT_09")
	await process_frame
	var title: String = DuelRules.game_name(game)
	_expect(manager.duel_pending() and int(manager.pending_duel()["game"]) == game, "%s: 카드를 놓으면 결투가 시작된다" % title)
	var arena: DuelArena = _board._duel_arena
	_expect(arena != null, "%s: 중앙 스테이지에 결투장이 열린다" % title)
	if arena == null:
		return
	arena.open()
	await process_frame
	await process_frame
	_expect(arena.get_global_rect().get_center().distance_to(_board._board_center()) < 4.0, "%s: 결투장은 보드 한가운데" % title)
	_expect(_board._roll_button.disabled, "%s: 결투 중에는 굴리기 버튼이 잠긴다" % title)
	var waited: float = 0.0
	var saw_hold: bool = false
	while manager.duel_pending() and waited < 20.0:
		if arena._step == &"rules" and arena._intro_elapsed > 0.2:
			arena._confirm_intro()
		if arena._step == &"play":
			match game:
				DuelRules.Game.RPS, DuelRules.Game.ECARD:
					if arena._pick_seat != -1:
						arena._choose(randi() % (3 if game == DuelRules.Game.RPS else 2))
				DuelRules.Game.CURLING:
					if arena._pick_seat != -1 and arena._clock > 0.6:
						arena._curling_stop()
				DuelRules.Game.HALLI, DuelRules.Game.QUICKDRAW:
					if arena._clock >= DuelRules.reaction_mark(game, arena.setup_data) + 0.1:
						arena._press(arena.challenger)
						arena._press(arena.defender)
				DuelRules.Game.BARREL:
					for hole: int in DuelRules.BARREL_HOLES:
						if not arena._opened_holes.has(hole):
							arena._pick_hole(hole)
							break
		if arena.holds_board():
			saw_hold = saw_hold or _board._fx_holding()
		await create_timer(0.05).timeout
		waited += 0.05
	_expect(not manager.duel_pending(), "%s: 입력만으로 결투가 끝난다 (%.1f초)" % [title, waited])
	_expect(saw_hold, "%s: 승패 공개가 끝나기 전에는 보드 연출이 기다린다" % title)
	var loser_front_gone: bool = not state.get_pawn(opponent * 10 + 1).has_left_start or not state.get_pawn(player_id * 10 + 1).has_left_start
	_expect(loser_front_gone, "%s: 패자의 선두 말이 출발선으로" % title)
	waited = 0.0
	while is_instance_valid(arena) and waited < 8.0:
		await create_timer(0.1).timeout
		waited += 0.1
	_expect(not is_instance_valid(arena) and _board._duel_arena == null, "%s: 결투가 끝나면 결투장이 닫히고 해제된다 (%.1f초)" % [title, waited])


## 점프 코너·포탈: 말이 먼저 발판에 멈춰 발동 연출을 보여 준 뒤 목적지로 날아간다 (한 번에 최종 칸으로 가지 않는다).
func _test_stage_warp() -> void:
	_board._reset_presentation()  # 앞선 검사가 남긴 연출 큐를 비운다
	var manager: TurnManager = _board.manager
	var state: GameState = manager.state
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	_board._beat_until_msec = 0
	_board._fx_until_msec = 0
	var warp_portal: int = int(BoardSpec.portal_warp_targets.keys()[0])
	for case_data: Array in [[warp_portal - 1, warp_portal, int(BoardSpec.portal_warp_targets[warp_portal]), "포탈"]]:
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
		var started_at: float = _now()
		while _board._stage_warps == 0 and _now() - started_at < 2.0:
			await process_frame  # 앞선 걸음이 연출 큐에서 끝나야 워프 연출이 시작된다
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
	_board._reset_presentation()  # 앞선 검사가 남긴 연출 큐를 비운다
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
	var shown_icon: Texture2D = tile.trap_icon
	var expected_icon: String = "TRP_02" if _board.ai_mode and _board.local_player_id == 2 else "HIDDEN"
	_expect(shown_icon != null and shown_icon.resource_path.ends_with("%s.png" % expected_icon), "함정 칸에 함정 그림이 붙는다 (모르는 함정은 물음표: %s)" % (shown_icon.resource_path if shown_icon != null else "없음"))
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


## 말을 잡으면 아바타 공격·피격 슬로모션(약 1초)가 뜨고, 그동안 잡힌 말은 제자리에서 기다렸다가 보드 밖으로 날아간 뒤 출발선에 돌아온다.
func _test_kill_cutin() -> void:
	_board._reset_presentation()  # 앞선 검사가 남긴 연출 큐를 비운다
	var state: GameState = _board.manager.state
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	var victim: PlayerPawn = state.get_pawn(21)
	victim.current_tile_idx = 12
	victim.has_left_start = true
	_board._refresh_all()
	await get_root().get_tree().create_timer(1.2).timeout  # 말이 12번 자리로 나타나는 연출이 끝나길 기다린다
	_board._fx_until_msec = 0  # 남은 연출 시간이 컷신을 미루지 않게 한다
	state.pawn_captured.emit(11, victim.entity_id)
	state.send_to_start(victim, 1)
	_board._refresh_all()  # 실제 게임에서는 행동 처리(_act) 뒤에 화면이 갱신된다
	for i: int in 4:
		await process_frame
	var cutin: CaptureCutin = _board._capture_cutin
	_expect(cutin != null and cutin.active, "말이 잡히면 두 아바타 포즈가 뜬다")
	_expect(cutin.attacker_avatar == _board._avatar_for(1) and cutin.defender_avatar == _board._avatar_for(2), "실제 공격자와 피격자의 선택 아바타를 사용한다")
	var view: Node2D = _board._pawn_views[victim.entity_id]
	_expect(view.visible and view.position.distance_to(_board._pawn_position(victim)) > 3.0, "컷신 동안 잡힌 말은 아직 제자리(옛 자리)에 있다")
	await get_root().get_tree().create_timer(1.2).timeout
	_expect(not cutin.active, "아바타 포즈는 슬로모션 종료 뒤에 사라진다")
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
	await get_root().get_tree().create_timer(5.2).timeout
	_expect(not _board._stage_pinball.active and not _board._fx_busy and holes.size() == before_holes + 1 and _board._stage_pinball.last_hole == holes[-1], "핀볼: 물리 낙하 후 엔진이 정한 구멍에 도착하고 입력이 풀린다")
	_board.instant_roll_for_test = true
	guard = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 300:
		guard += 1
		manager.force_timeout()
		await process_frame
	manager.state.tools[manager.current_player_id()] = ToolRegistry.create(&"D6")
	_board._refresh_all()
	_expect(not _board._stage_yacht.visible and not _board._stage_blackjack.visible and not _board._stage_pinball.visible, "다른 도구로 돌아오면 스테이지가 사라진다")


## 중립 NPC 위험 예고: 붉은 타일·경고 그림·진행 화살표, 위험 문구와 호버 툴팁.
func _test_npc_danger_preview() -> void:
	var manager: TurnManager = _board.manager
	var state: GameState = manager.state
	_board.instant_roll_for_test = true
	_board._announcer.cancel()
	state.clear_npcs()
	var mine: PlayerPawn = state.get_pawn(_board._dock_owner() * 10 + 1)
	mine.has_left_start = true
	mine.current_tile_idx = 2
	for other: PlayerPawn in state.pawns:
		if other != mine and not other.is_finished:
			other.reset_to_start()  # 앞선 테스트가 남긴 말이 NPC를 멈춰 세우지 않게 한다
	_board._refresh_all()
	_expect(_board._npc_danger.is_empty() and not _board._danger_label.visible, "NPC가 없으면 위험 예고도 경고도 없다")
	var ghost: NeutralNPC = state.spawn_npc(12, GameEnums.NpcBehavior.PATROL_REVERSE, 1, &"SUM_02")
	_board._refresh_all()
	_expect(_board._npc_danger.has(11) and _board._npc_danger.has(10) and _board._npc_danger.has(9), "팩맨이 지나갈 칸(11·10·9번…)이 위험 구간으로 표시된다")
	var danger_tile: BoardSkin.Tile = _board._tile_views[10]
	_expect(danger_tile.danger_level == 2 and danger_tile.danger_dir != Vector2.ZERO, "위험 타일은 경고(level 2)와 진행 방향을 가진다")
	_expect(danger_tile.warning_mark.visible and danger_tile.warning_flow.visible, "위험 타일의 경고 이미지와 화살표가 표시된다")
	_expect(danger_tile.warning_mark.z_index == 0 and danger_tile.warning_flow.z_index == 0, "보드 경고가 상위 UI 팝업을 뚫고 표시되지 않는다")
	_expect(danger_tile.warning_flow.transform.x.normalized().dot(danger_tile.danger_dir.normalized()) > 0.999, "화살표가 타일 평면에서 실제 NPC 진행 방향을 가리킨다")
	_expect(danger_tile.symbol == null or not danger_tile.symbol.visible, "위험 칸의 바닥 심볼은 경고 그림과 겹치지 않는다")
	_expect(not _board._danger_label.visible, "내 말이 위험 구간 밖이면 경고 문구가 없다")
	mine.current_tile_idx = 10
	_board._refresh_all()
	_expect(_board._danger_label.visible and _board._danger_label.text.contains("위험") and _board._danger_label.text.contains("NPC에게 잡힙니다"), "내 말이 위험 타일에 서면 [위험! 라운드 종료 시 NPC에게 잡힙니다!]")
	mine.current_tile_idx = 2
	_board._refresh_all()
	_expect(not _board._danger_label.visible, "벗어나면 경고가 사라진다")
	# 이동 미리보기(호버)가 위험 타일에 닿을 때
	_board._hover_danger_tile = 9
	_board._refresh_danger_label()
	_expect(_board._danger_label.visible, "미리보기 도착 타일이 위험하면 경고")
	_board._hover_danger_tile = 3
	_board._refresh_danger_label()
	_expect(not _board._danger_label.visible, "안전한 타일이면 경고 없음")
	_board._hover_danger_tile = -1
	# 도적떼: 가장 가까운 말까지의 경로
	var robber: NeutralNPC = state.spawn_npc(20, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	for other: PlayerPawn in state.pawns:
		if other != mine and not other.is_finished:
			other.reset_to_start()  # 앞선 테스트가 남긴 말이 도적의 추격 대상이 되지 않게 한다
	mine.current_tile_idx = 23
	_board._refresh_all()
	_expect(_board._npc_danger.has(21) and _board._npc_danger.has(22) and _board._npc_danger.has(23), "도적떼가 가는 길이 표시된다 (21~23번)")
	_expect(not _board._npc_danger.has(24), "말을 만난 칸에서 멈추므로 그 뒤는 표시하지 않는다")
	# NPC 툴팁과 라벨
	_board._fill_npc_tip(robber.entity_id)
	_expect(_board._tip_title.text.contains("사료스탕스") and _board._tip_title.text.contains("▶") and _board._tip_ability.text.contains("3~6") and _board._tip_ability.text.contains("소멸합니다"), "도적 툴팁: 방향과 설명 (%s)" % _board._tip_title.text)
	_board._fill_npc_tip(ghost.entity_id)
	_expect(_board._tip_title.text.contains("와구와구 유령") and _board._tip_title.text.contains("◀") and _board._tip_ability.text.contains("역방향") and _board._tip_ability.text.contains("3~6"), "팩맨 툴팁: 역방향 3~6칸 전진")
	_expect(not _board._announce_gate_text_for_tests().contains("한 칸"), "NPC 이동 안내 문구가 실제 규칙을 말한다")
	state.clear_npcs()
	mine.has_left_start = false
	mine.current_tile_idx = 0
	_board._refresh_all()
	_expect(_board._npc_danger.is_empty(), "NPC가 사라지면 위험 예고도 사라진다")
	_expect(not danger_tile.warning_mark.visible and not danger_tile.warning_flow.visible, "위험 해제 시 경고 이미지와 화살표가 사라진다")
	_expect(danger_tile.symbol == null or danger_tile.symbol.visible == not danger_tile.trap_on, "위험 해제 시 원래 바닥 심볼 표시가 복원된다")


## 바뀐 기물·카드·초증강의 연출 순서: 소환 기물은 달린 뒤에 말이 날아가고, 도미노는 [도미노 연쇄!]가 먼저, 드래프트 효과는 증강 공개 뒤.
func _test_event_order() -> void:
	var manager: TurnManager = _board.manager
	var state: GameState = manager.state
	_board._reset_presentation()
	_board.instant_roll_for_test = false
	_board.pacing_enabled = false
	_board._announcer.cancel()
	_board._bot.set_enabled(false)
	manager.set_process(false)
	var guard: int = 0
	while manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and guard < 40:
		manager.force_timeout()
		guard += 1
	state.clear_npcs()
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	_board._refresh_all()
	# 1) 소환: 사료스탕스가 달리는 동안 잡힐 말은 아직 보드에 있고, 달리기가 끝난 뒤에 사출된다
	var victim: PlayerPawn = state.get_pawn(21)
	victim.has_left_start = true
	victim.current_tile_idx = BoardSpec.side + 2
	_board._refresh_pawns()
	await process_frame
	var history_before: int = _board._announcer.history.size()
	var command := SweepCommand.new(1, BoardSpec.side, &"SUM_01")
	command.state = state
	command.execute()
	_expect(not victim.has_left_start, "엔진에서는 바로 잡힌다")
	var saw_runner: bool = false
	var victim_seen_while_running: bool = false
	var waited: float = 0.0
	while waited < 8.0 and (_board._presentation_active() or _board._announcer.active):
		var runner: Node = _board._pawn_layer.find_child("NpcRunner", false, false)
		if runner != null:
			saw_runner = true
			victim_seen_while_running = victim_seen_while_running or (_board._pawn_views[21] as Node2D).visible
		await create_timer(0.05).timeout
		waited += 0.05
	_expect(saw_runner, "소환 기물이 길을 따라 달리는 모습이 보인다")
	_expect(victim_seen_while_running, "기물이 달리는 동안 잡힐 말은 아직 보드 위에 있다 (사출은 그 뒤)")
	var headlines: Array = _board._announcer.history.slice(history_before)
	_expect(headlines.any(func(h: String) -> bool: return h.contains("사료스탕스 출동")), "[사료스탕스 출동!] 알림 (%s)" % str(headlines))
	_expect(_board._pawn_layer.find_child("NpcRunner", false, false) == null, "달리기 연출 노드는 끝나면 사라진다")
	# 2) 도미노: [도미노 연쇄!]가 연쇄로 터지는 함정보다 먼저, 도미노 자신의 [발동!]은 다시 뜨지 않는다
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	state.place_attachment(6, TrapDomino.new(2))
	state.place_attachment(7, TrapPit.new(2))
	var mover: PlayerPawn = state.get_pawn(11)
	for test_pawn: PlayerPawn in [mover, state.get_pawn(12)]:
		test_pawn.kind = GameEnums.PawnKind.BASIC  # 앞선 검사의 드래프트가 함정을 뛰어넘는 기물로 진화시켰을 수 있다
		test_pawn.promoted = false
		test_pawn.shield = false
	mover.has_left_start = true
	mover.current_tile_idx = 4
	var standing: PlayerPawn = state.get_pawn(12)
	standing.has_left_start = true
	standing.current_tile_idx = 7
	_board._refresh_all()
	history_before = _board._announcer.history.size()
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.pawn = mover
	ctx.dice_value = 3
	MoveExecutor.execute(state, mover, ctx)
	waited = 0.0
	while waited < 8.0 and (_board._presentation_active() or _board._announcer.active):
		await create_timer(0.05).timeout
		waited += 0.05
	headlines = _board._announcer.history.slice(history_before)
	var domino_at: int = headlines.find("도미노 연쇄!")
	var pit_at: int = -1
	for index: int in headlines.size():
		if str(headlines[index]).contains("[발동!]") and str(headlines[index]).contains(_board._attachment_name("TRP_02")):
			pit_at = index
	_expect(domino_at != -1 and (pit_at == -1 or domino_at < pit_at), "[도미노 연쇄!]가 연쇄 함정보다 먼저 (%s)" % str(headlines))
	_expect(not headlines.any(func(h: String) -> bool: return h.contains("[발동!]") and h.contains("도미노")), "도미노 자신의 [발동!] 알림은 다시 뜨지 않는다")
	# 3) 처치는 말이 도착하자마자: 같은 이동의 빵집·점프 배지보다 컷인·사출이 먼저 나온다
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	var bakery: int = BoardSpec.bakery_tiles[0]
	var hunter: PlayerPawn = state.get_pawn(11)
	hunter.kind = GameEnums.PawnKind.BASIC
	hunter.has_left_start = true
	hunter.current_tile_idx = bakery - 2
	var prey: PlayerPawn = state.get_pawn(21)
	prey.kind = GameEnums.PawnKind.BASIC
	prey.shield = false
	prey.has_left_start = true
	prey.current_tile_idx = bakery
	_board._refresh_all()
	await create_timer(0.3).timeout
	var kill_ctx := RuleContext.new()
	kill_ctx.state = state
	kill_ctx.pawn = hunter
	kill_ctx.dice_value = 2
	MoveExecutor.execute(state, hunter, kill_ctx)
	var arrived_at: int = -1
	var cutin_at: int = -1
	waited = 0.0
	while waited < 8.0 and cutin_at == -1:
		var hunter_view: Node2D = _board._pawn_views[11]
		# 도착 판정은 그 말이 서는 자리(사람별 칸 안 위치) 기준이다 (칸 중심은 사람에 따라 30px 넘게 떨어질 수 있다)
		if arrived_at == -1 and hunter_view.position.distance_to(_board._pawn_position_at(hunter, bakery)) < 14.0:
			arrived_at = Time.get_ticks_msec()
		if _board._capture_cutin.active:
			cutin_at = Time.get_ticks_msec()
		await process_frame
		waited += 0.016
	_expect(arrived_at != -1 and cutin_at != -1 and cutin_at - arrived_at < 600, "처치 컷인은 말이 도착하고 곧바로 나온다 (%d ms)" % (cutin_at - arrived_at))
	waited = 0.0
	while waited < 8.0 and (_board._presentation_active() or _board._announcer.active):
		await create_timer(0.05).timeout
		waited += 0.05
	# 4) 라운드 마지막 턴의 처치처럼 드래프트가 열리기 전에 일어난 일은, 같은 프레임에 엔진이 다음 라운드 드래프트를 열어도
	#    미루지 않고 바로 재생한다 (드래프트 창은 그 연출이 끝난 뒤에 열린다): 증강 선택 -> 처치 -> 다음 라운드로 보이던 버그
	var before_draft: Array = []
	manager.current_state = TurnManager.State.PHASE_RESOLUTION
	_board._enqueue_late(func() -> void: before_draft.append(true))
	manager.current_state = TurnManager.State.PHASE_ROUND_START
	_board._on_event(&"augment_offers", {"round": state.round_number, "offers": {}})
	_expect(_board._draft_open and _board._presentation_active(), "드래프트가 열리기 직전의 처치 연출은 큐에 들어가 드래프트 창을 기다리게 한다")
	waited = 0.0
	while before_draft.is_empty() and waited < 4.0:
		await create_timer(0.05).timeout
		waited += 0.05
	_expect(not before_draft.is_empty() and _board._draft_deferred.is_empty(), "드래프트 전의 처치 연출은 증강 공개 뒤로 밀리지 않는다")
	# 5) 드래프트 창이 열린 뒤에 생긴 효과 연출(고른 증강의 효과)은 증강 공개 뒤로 미룬다
	var ran: Array = []
	_board.enqueue_step(func() -> void: ran.append(true))
	_expect(ran.is_empty() and _board._draft_deferred.size() == 1 and _board._fx_holding(), "드래프트 중의 효과 연출은 미뤄 두고 말 그림도 움직이지 않는다")
	manager.current_state = TurnManager.State.PHASE_TURN_BEGIN
	_board._on_phase_changed(TurnManager.State.PHASE_TURN_BEGIN, 1, 0.0)
	waited = 0.0
	while ran.is_empty() and waited < 6.0:
		await create_timer(0.05).timeout
		waited += 0.05
	_expect(not ran.is_empty() and _board._draft_deferred.is_empty(), "드래프트가 끝나면 미룬 연출이 재생된다")
	state.clear_npcs()
	for tile: int in [6, 7]:
		for attachment: TileAttachment in state.board.get_tile(tile).attachments.duplicate():
			state.board.get_tile(tile).remove_attachment(attachment)


## 단일 연출 큐: 여러 연출이 한꺼번에 방송돼도 한 번에 하나씩 순서대로만 재생된다.
func _test_presentation_queue() -> void:
	var state: GameState = _board.manager.state
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	_board._fx_until_msec = 0
	var guard: int = 0
	while _board._presentation_active() and guard < 600:
		guard += 1
		await process_frame
	# 1) 단계는 앞 단계가 끝난 뒤에야 시작한다
	var log: Array[String] = []
	_board.enqueue_step(func() -> void:
		log.append("a start")
		await create_timer(0.15).timeout
		log.append("a end"))
	_board.enqueue_step(func() -> void:
		log.append("b start")
		await create_timer(0.1).timeout
		log.append("b end"))
	_board.enqueue_step(func() -> void: log.append("c"))
	_expect(_board._ui_busy() and _board._presentation_active(), "큐가 일하는 동안은 입력·봇·다음 턴이 기다린다")
	_expect(log == ["a start"], "첫 단계는 바로 시작하고 나머지는 줄을 선다 (%s)" % str(log))
	guard = 0
	while _board._presentation_active() and guard < 600:
		guard += 1
		await process_frame
	_expect(log == ["a start", "a end", "b start", "b end", "c"], "앞 연출이 끝난 뒤에 다음 연출이 시작된다 (%s)" % str(log))
	# 2) 엔진이 한 번에 방송한 여러 걸음(발판 가속)도 한 칸씩 차례로 뛴다
	var pawn: PlayerPawn = state.get_pawn(11)
	pawn.has_left_start = true
	pawn.current_tile_idx = 2
	pawn.step_history = [1, 2]
	_board._refresh_all()
	await process_frame
	_board._fx_until_msec = 0
	var view: Node2D = _board._pawn_views[11]
	var visited: Array[int] = []
	for tile: int in [3, 4, 5, 6]:
		var before: int = pawn.current_tile_idx
		pawn.current_tile_idx = tile
		state.pawn_stepped.emit(11, before, tile)
	guard = 0
	while _board._presentation_active() and guard < 900:
		guard += 1
		if view.has_meta("land_tile"):
			var landing: int = int(view.get_meta("land_tile"))
			if visited.is_empty() or visited[-1] != landing:
				visited.append(landing)
		await process_frame
	_expect(visited == [3, 4, 5, 6], "한꺼번에 방송된 4걸음이 3 -> 4 -> 5 -> 6번 순서로 하나씩 착지한다 (%s)" % str(visited))
	_expect(view.position.distance_to(_board._pawn_position(pawn)) < 4.0, "큐가 끝나면 말은 최종 위치에 서 있다")
	# 3) 배너는 말이 움직이는 동안 먼저 뜨지 않고 큐 순서를 지킨다
	pawn.current_tile_idx = 8
	state.pawn_stepped.emit(11, 6, 8)
	_board._announce("테스트", "[큐 배너]", "말 이동 뒤에 떠야 한다", Color.WHITE, null, 0.3)
	_expect(not _board._announcer.active, "이동 큐가 재생 중이면 배너는 그 뒤에 줄을 선다")
	guard = 0
	while _board._presentation_active() and guard < 900:
		guard += 1
		await process_frame
	_expect(not _board._presentation_active(), "큐가 모두 비워진다")
	# 4) 처치 연출은 같은 행동의 이동 연출이 모두 끝난 뒤(큐 맨 뒤)에 재생된다
	var order: Array[String] = []
	pawn.current_tile_idx = 9
	state.pawn_stepped.emit(11, 8, 9)
	_board._enqueue_late(func() -> void:
		order.append("late: landed" if view.position.distance_to(_board._pawn_position(pawn)) < 4.0 and not _board._fx_running(view) else "late: early")
		await process_frame)
	pawn.current_tile_idx = 10
	state.pawn_stepped.emit(11, 9, 10)
	_expect(_board._presentation_active(), "후순위 단계가 대기 중이면 큐는 활성 상태다")
	guard = 0
	while _board._presentation_active() and guard < 900:
		guard += 1
		await process_frame
	_expect(order == ["late: landed"], "처치 컷신·사출은 마지막 칸에 착지한 직후에 시작한다 (%s)" % str(order))
	# 5) 굴림 뒤에는 최종 칸수를 보여 주는 단계가 이동보다 먼저 선다
	var summary_data: Dictionary = {"player_id": 1, "result": {"steps": 3, "ends_turn": false, "can_continue": false}}
	_board._enqueue_roll_summary(summary_data)
	_board._fx_busy = true
	state.pawn_stepped.emit(11, 10, 11)
	pawn.current_tile_idx = 11
	_expect(_board._presentation_active(), "굴림 요약 단계가 큐에 선다")
	for _i: int in 5:
		await process_frame
	_expect(int(view.get_meta("land_tile", -1)) != 11, "주사위 연출(_fx_busy)이 끝나기 전에는 말이 이동하지 않는다")
	_board._fx_busy = false
	guard = 0
	while _board._presentation_active() and guard < 900:
		guard += 1
		await process_frame
	_expect(not _board._presentation_active(), "굴림 요약 뒤에 이동이 이어지고 큐가 비워진다")
	# 6) 🔥 리벤지 부스터: 장전된 대기 말은 슬롯이 불꽃으로 빛나고, 출격하면 0 -> 4번은 로켓 한 번, 그 뒤는 한 칸씩
	var rocket: PlayerPawn = state.get_pawn(12)
	rocket.reset_to_start()
	rocket.revenge_boost = true
	_board._refresh_all()
	var slot_panel: Control = (_board._profiles[1]["slots"] as Array)[1]["panel"]
	var glow: Control = slot_panel.get_node_or_null("RevengeGlow")
	_expect(glow != null and glow.visible and (glow.get_node("RevengeBadge") as Label).text.contains("+4"), "장전된 대기 말 슬롯에 불꽃 테두리와 [🔥출격 +4] 뱃지")
	guard = 0
	while _board._presentation_active() and guard < 600:
		guard += 1
		await process_frame
	var rocket_view: Node2D = _board._pawn_views[12]
	var landings: Array[int] = []
	rocket.revenge_boost = false
	state.revenge_boost_fired.emit(12, 2, 4, 6)
	_expect(_board._rocket_target.get(12, -1) == 4, "로켓은 출발선 + 4번 칸에 내려앉는다")
	rocket.has_left_start = true
	for tile: int in [1, 2, 3, 4, 5, 6]:
		var before: int = rocket.current_tile_idx
		rocket.current_tile_idx = tile
		state.pawn_stepped.emit(12, before, tile)
	guard = 0
	while _board._presentation_active() and guard < 900:
		guard += 1
		if rocket_view.has_meta("land_tile") and _board._fx_running(rocket_view):
			var landing_tile: int = int(rocket_view.get_meta("land_tile"))
			if landings.is_empty() or landings[-1] != landing_tile:
				landings.append(landing_tile)
		await process_frame
	_expect(landings == [4, 5, 6], "1~3번은 건너뛰고 4번에 로켓 착지 뒤 5 -> 6번 한 칸씩 (%s)" % str(landings))
	_board._refresh_all()
	_expect(glow == null or not glow.visible, "출격하면 불꽃 테두리가 꺼진다")
	# 7) 빵집: 카드를 받으면 카드 뒷면이 프로필로 날아간다 (글자 없음). 손패가 가득 차면 카드가 튕겨 나가며 부서진다
	var bakery: int = BoardSpec.bakery_tiles[0]
	var badge_texts: Array[String] = []
	var watcher: Callable = func(node: Node) -> void:
		if node.has_meta("hand_card_fx"):
			badge_texts.append(str(node.get_meta("hand_card_fx")))
		elif node is Label and (node as Label).text.contains("빵집"):
			badge_texts.append((node as Label).text)
	_board.child_entered_tree.connect(watcher)
	var baker: PlayerPawn = state.get_pawn(13)
	baker.has_left_start = true
	baker.current_tile_idx = bakery
	state.hands[1].clear()
	_board._enqueue_bakery_for_test({"pawn_id": 13, "path": [bakery], "canceled": false, "drawn_card": &"TRP_03"})
	guard = 0
	while _board._presentation_active() and guard < 600:
		guard += 1
		await process_frame
	_expect(str(badge_texts) == str(["drawn"]), "빵집에 멈춰 카드를 받으면 카드 뒷면이 프로필로 날아간다 (글자 배지 없음) (%s)" % str(badge_texts))
	_expect(not badge_texts.any(func(text: String) -> bool: return text.contains(_board._card_name(&"TRP_03"))), "빵집 알림은 어떤 카드인지 알려 주지 않는다 (%s)" % str(badge_texts))
	badge_texts.clear()
	for i: int in GameEnums.MAX_HAND_SIZE:
		state.hands[1].append(&"TRP_03")
	_board._enqueue_bakery_for_test({"pawn_id": 13, "path": [bakery], "canceled": false, "drawn_card": &""})
	guard = 0
	while _board._presentation_active() and guard < 600:
		guard += 1
		await process_frame
	_expect(str(badge_texts) == str(["rejected"]), "손패가 가득 차면 카드가 튕겨 나가며 부서진다 (%s)" % str(badge_texts))
	_board.child_entered_tree.disconnect(watcher)
	state.hands[1].clear()
	# 8) 장외 홈런 뒤 말은 내려앉는 연출 없이 출발선 자리에 조용히 돌아와 있다
	var victim: PlayerPawn = state.get_pawn(14)
	victim.has_left_start = true
	victim.current_tile_idx = 3
	_board._refresh_all()
	await process_frame
	var victim_view: Node2D = _board._pawn_views[14]
	victim.reset_to_start()
	_board._set_hint(14, {"homerun": true, "arc": 110.0, "spin": 2.0 * TAU, "dur": 0.45})
	_board._settle_pawn_view(victim_view, victim, true)
	var saw_drop: bool = false
	guard = 0
	while _board._fx_running(victim_view) and guard < 600:
		guard += 1
		if victim_view.modulate.a < 0.99 or bool(victim_view.get_meta("land_thud", false)):
			saw_drop = true
		await process_frame
	_expect(not saw_drop, "홈런 뒤 낙하·착지 연출이 없다")
	_expect(victim_view.position.distance_to(_board._pawn_position(victim)) < 4.0, "홈런이 끝나면 말은 출발선 자리에 있다")
	# 9) 최종 순위 발표: 줄이 처음엔 숨어 있다가 꼴찌부터 차례로 나타나고, 1등이 마지막이다
	for pawn_done: PlayerPawn in state.pawns_of(2):
		pawn_done.is_finished = true
	state.winner = 2
	_board._show_result_overlay()
	var ranking: Node = _board._result_overlay.find_child("RankingList", true, false)
	_expect(ranking != null and ranking.get_child_count() == _board._player_ids.size(), "순위 줄이 참가자 수만큼 있다")
	var podium: Node = _board._result_overlay.find_child("Podium", true, false)
	var podium_ranks: Array[int] = []
	if podium != null:
		for column: Node in podium.get_children():
			podium_ranks.append(int(column.get_meta("rank")))
	_expect(str(podium_ranks) == str([2, 1, 3, 4]), "시상대는 2위·1위·3위·4위 순으로 선다 (%s)" % str(podium_ranks))
	if podium != null and podium.get_child_count() == 4:
		var first_block: Control = podium.get_child(1).find_child("Block", true, false)
		var fourth_block: Control = podium.get_child(3).find_child("Block", true, false)
		_expect(first_block.custom_minimum_size.y > fourth_block.custom_minimum_size.y, "1위 단상이 가장 높다")
	var reveal_order: Array[int] = []
	guard = 0
	while reveal_order.size() < ranking.get_child_count() and guard < 900:
		guard += 1
		for row: Node in ranking.get_children():
			var rank_no: int = int(row.get_meta("rank"))
			if (row as Control).modulate.a > 0.5 and not reveal_order.has(rank_no):
				reveal_order.append(rank_no)
		await process_frame
	var expected_order: Array[int] = []
	for rank_no: int in range(ranking.get_child_count(), 0, -1):
		expected_order.append(rank_no)
	_expect(reveal_order == expected_order, "꼴찌부터 1등까지 차례로 공개된다 (%s)" % str(reveal_order))
	_board._close_result_overlay()
	for pawn_done: PlayerPawn in state.pawns_of(2):
		pawn_done.is_finished = false
	state.winner = -1
	_board._announcer.cancel()
	_board._fx_until_msec = 0
	_board.instant_roll_for_test = true
	print("PRESENTATION_QUEUE_OK")
