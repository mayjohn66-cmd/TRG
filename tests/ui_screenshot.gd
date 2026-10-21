# File: res://tests/ui_screenshot.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 가상 디스플레이(xvfb)에서 프로토타입 화면의 장면(draft/tilepick/evolved/gameover/debug)을 PNG로 저장한다. 사람 눈으로 레이아웃을 확인하기 위한 도구
extends SceneTree

var _board: MainBoard = null
var _frames: int = 0
var _banner_frame: int = -1
var _rolled: bool = false
var _shot: String = OS.get_environment("SHOT") if OS.get_environment("SHOT") != "" else "draft"


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var scene: PackedScene = load("res://scenes/main_board.tscn")
		_board = scene.instantiate()
		root.add_child(_board)
		_board.manager.step_delay_sec = 0.0
		return false
	if _frames == 3:
		_setup_scene()
		return false
	if _shot == "banner":
		if not _rolled and not _board._ui_busy() and not _board._roll_button.disabled:
			_rolled = true
			_board._on_roll_pressed()
		if _banner_frame == -1 and _board._select_banner.visible:
			_banner_frame = _frames
			_board._on_select_card_hover(1, true)
		if _banner_frame != -1 and _frames == _banner_frame + 10:
			_banner_frame = -2
		if _banner_frame != -2 and _frames < 600:
			return false
		_banner_frame = -2
	var shot_frame: int = 8 if _shot == "pick" else (20 if _shot in ["react", "classics", "traps", "log", "logx", "counterzoom", "book", "tempo", "emote", "emotepick", "result", "settings", "popupsettings", "feedback", "resultfeedback"] else (int(OS.get_environment("DUEL_FRAME")) if _shot == "duel" and OS.get_environment("DUEL_FRAME") != "" else (150 if _shot == "duel" else 12)))
	if OS.get_environment("SHOT_FRAME") != "":
		shot_frame = int(OS.get_environment("SHOT_FRAME"))
	if (_shot != "banner" and _frames == shot_frame) or (_shot == "banner" and _banner_frame == -2):
		var path: String = "/tmp/trg_shot_%s.png" % _shot
		var image: Image = root.get_texture().get_image()
		image.save_png(path)
		print("SCREENSHOT ", path, " ", image.get_size())
		quit(0)
	return false


func _finish_draft() -> void:
	_board._on_draft_auto_pressed()


func _setup_scene() -> void:
	var state: GameState = _board.state
	match _shot:
		"draft":
			# DRAFT_IDS=AUG_LAW_01,SUPER_01,UTIL_01 처럼 정하면 그 증강들을 내 선택지로 보여 준다
			if OS.get_environment("DRAFT_IDS") != "":
				var ids: Array[StringName] = []
				for id: String in OS.get_environment("DRAFT_IDS").split(","):
					ids.append(StringName(id))
				_board.manager._draft_offers[_board.local_player_id] = ids
				_board._close_opening()
				_board._intro_pending = false
				_board._close_draft_overlay()
				_board._refresh_draft_overlay()
		"duel":
			# ⚔️ 데스매치 결투장: DUEL_GAME 종목을 핫시트로 열어 미니게임 화면을 찍는다
			_board._close_opening()
			_finish_draft()
			_board.ai_mode = false
			_board._bot.set_enabled(false)
			var duel_game: int = int(OS.get_environment("DUEL_GAME")) if OS.get_environment("DUEL_GAME") != "" else 0
			_board.manager.duel_game_override = duel_game
			var me: int = _board.manager.current_player_id()
			var foe: int = 2 if me != 2 else 1
			for pair: Array in [[me * 10 + 1, 5], [foe * 10 + 1, 14]]:
				state.get_pawn(pair[0]).has_left_start = true
				state.get_pawn(pair[0]).current_tile_idx = pair[1]
			_board._announcer.cancel()
			state.give_card(me, &"ACT_09")
			_board._duel_drop_target = foe
			_board._on_card_pressed(me, &"ACT_09")
			if _board._duel_arena != null:
				_board._duel_arena.open()
		"result":
			# 특수 승리로 끝난 판의 결과 화면
			_board._close_opening()
			_finish_draft()
			_board._announcer.cancel()
			var spots: Dictionary = {11: 6, 12: 14, 21: 3, 31: 25, 32: 20, 41: 9}
			for pawn_id: int in spots:
				state.get_pawn(pawn_id).has_left_start = true
				state.get_pawn(pawn_id).current_tile_idx = spots[pawn_id]
			state.get_pawn(13).is_finished = true
			var manager: TurnManager = _board.manager
			manager._graduate(1, &"LAW_08")
			manager._graduate(3, &"LAW_01")
			manager._graduate(4, &"LAW_04")
			manager._graduate(2, VictoryChecker.LAST_PLACE)
			manager._end_game()
			_board._announcer.cancel()
			_board._reset_presentation()
		"emote", "emotepick":
			# 감정 표현: 이모트 판(emotepick) 또는 내 말풍선 + 상대 말풍선(emote)
			_board._close_opening()
			_finish_draft()
			_board._announcer.cancel()
			if _shot == "emotepick":
				_board._emote_button.pressed.emit()
			else:
				_board._on_emote_pressed(1)
				for seat: int in [2, 3, 4]:
					_board._show_emote(seat, [2, 6, 3][seat - 2])
		"tempo":
			# ⏩ 템포 업 경고 + 당겨진 결승선 체크무늬
			_board._close_opening()
			state.round_number = 31
			_board._announced_round = 31  # 이미 지난 라운드 배너는 건너뛴다
			_board._announcer.cancel()
			_board.manager._emit_event(&"tempo_up", {"round": 31, "level": 3, "lines": TempoUp.effect_lines(3)})
			_board._refresh_all()
		"evolved":
			_finish_draft()
			for pair: Array in [[11, GameEnums.PawnKind.CHESS], [12, GameEnums.PawnKind.CHESS], [13, GameEnums.PawnKind.CHESS], [14, GameEnums.PawnKind.CHESS], [21, GameEnums.PawnKind.JANGGI], [22, GameEnums.PawnKind.JANGGI], [23, GameEnums.PawnKind.JANGGI], [24, GameEnums.PawnKind.JANGGI], [31, GameEnums.PawnKind.MONOPOLY], [41, GameEnums.PawnKind.GO], [42, GameEnums.PawnKind.GO]]:
				state.evolve_pawn(state.get_pawn(pair[0]), pair[1])
			var spots: Dictionary = {11: 4, 12: 5, 13: 9, 21: 12, 22: 20, 31: 22, 41: 27, 42: 27}
			for pawn_id: int in spots:
				var pawn: PlayerPawn = state.get_pawn(pawn_id)
				pawn.place_at(spots[pawn_id])
				pawn.has_left_start = true
			state.get_pawn(23).restrained_turns = 2
			state.get_pawn(23).blocked_this_turn = true
			state.get_pawn(32).is_imprisoned = true
			state.place_attachment(9, TrapPit.new(2))
			state.place_attachment(2, Hotel.new(3))
			state.place_attachment(15, TrapIsland.new(1))
			PlaceMineFieldCommand.new(4, 17).bind_state(state)
			var mine: PlaceMineFieldCommand = PlaceMineFieldCommand.new(4, 17)
			mine.bind_state(state)
			mine.execute()
			state.spawn_npc(10, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
			state.give_card(1, &"TRP_02")
			state.give_card(1, &"SUM_01")
			state.give_card(2, &"CNT_01")
			state.give_card(3, &"TRP_C01")
			state.give_card(4, &"TRP_03")
			state.give_card(4, &"SUM_02")
			state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
			state.rulebook.enqueue_law(LawRegistry.create("LAW_08"))
			_board._refresh_all()
		"tip":
			_finish_draft()
			for pair: Array in [[11, GameEnums.PawnKind.CHESS], [12, GameEnums.PawnKind.CHESS], [21, GameEnums.PawnKind.JANGGI]]:
				state.evolve_pawn(state.get_pawn(pair[0]), pair[1])
			_board._refresh_all()
			_board._fill_pawn_tip(11)
			_board._tip_panel.visible = true
			_board._tip_panel.reset_size()
			_board._tip_panel.position = Vector2(700, 380)
		"drag":
			_finish_draft()
			_board.instant_roll_for_test = true
			_board._announcer.cancel()
			state.give_card(1, &"TRP_02")
			state.give_card(1, &"CNT_03")
			_board._refresh_all()
			_board._card_press(1, &"TRP_02", Vector2(700, 700), Vector2(700, 640))
			_board._card_move(Vector2(640, 380))
		"skill":
			_finish_draft()
			_board.instant_roll_for_test = true
			_board._announcer.cancel()
			for entry: Array in [[11, GameEnums.PawnKind.GO, 1], [12, GameEnums.PawnKind.JANGGI, 2], [13, GameEnums.PawnKind.CHESS, 4], [14, GameEnums.PawnKind.MONOPOLY, 2]]:
				state.give_unit(state.get_pawn(entry[0]), entry[1], [entry[2]] as Array[int])
				state.get_pawn(entry[0]).has_left_start = true
			state.get_pawn(11).place_at(1)
			state.get_pawn(12).place_at(6)
			state.get_pawn(12).skill_used = true
			state.get_pawn(21).place_at(3)
			state.get_pawn(21).has_left_start = true
			state.get_pawn(22).place_at(5)
			state.get_pawn(22).has_left_start = true
			_board._refresh_all()
			_board._begin_aim(state.get_pawn(11))
			_board._aim_origin = Vector2(600, 400)
			_board._aim_dragging = true
			_board._aim_update(Vector2(600, 520))
		"life":
			_finish_draft()
			_board._announcer.cancel()
			state.tools[1] = ToolRegistry.create(&"LIFE_ROULETTE")
			_board._refresh_all()
		"dice":
			_finish_draft()
			_board._announcer.cancel()
			_board._refresh_all()
		"tilepick":
			_finish_draft()
			_board.state.give_card(1, &"TRP_03")
			_board.state.give_card(1, &"TRP_C01")
			_board._refresh_all()
			_board._on_card_pressed(1, &"TRP_C01")
		"interrupt":
			_finish_draft()
			_board.state.give_card(2, &"CNT_03")
			_board.state.tools[1] = ScriptedTool.new([3])
			_board._on_roll_pressed()
		"select":
			_finish_draft()
			for pawn_id: int in [11, 12, 13]:
				var pawn: PlayerPawn = state.get_pawn(pawn_id)
				pawn.place_at(4)
				pawn.has_left_start = true
			state.stack_pawns(state.get_pawn(11), state.get_pawn(12))
			state.stack_pawns(state.get_pawn(11), state.get_pawn(13))
			state.place_attachment(8, Hotel.new(2))
			state.get_pawn(14).place_at(14)
			state.get_pawn(14).has_left_start = true
			state.tools[1] = ScriptedTool.new([4])
			_board._on_roll_pressed()
			_board._preview_pawn(11)
		"round":
			_finish_draft()
			state.give_card(1, &"TRP_02")
			state.give_card(1, &"SUM_01")
			state.give_card(1, &"CNT_01")
			state.give_card(1, &"CNT_03")
			_board._refresh_all()
		"classics":
			_finish_draft()
			_board._announcer.cancel()
			_board.instant_roll_for_test = true
			for entry: Array in [[11, 1, 8, true], [12, 2, 4, false], [13, 3, 14, true], [14, 4, 18, false]]:
				var pawn: PlayerPawn = state.get_pawn(entry[0])
				pawn.evolve(GameEnums.PawnKind.SHOGI, entry[1])
				pawn.place_at(entry[2])
				pawn.has_left_start = true
				pawn.promoted = entry[3]
			state.place_attachment(6, TrapDomino.new(2))
			var hwatu := ToolHwatu.new()
			hwatu.forced_draws = [1, 5]
			state.tools[1] = hwatu
			_board._refresh_all()
			_board._act(&"proceed")
			_board._act(&"roll")
			_board._refresh_all()
		"log", "logx":
			# 액션 로그: 평소에는 최근 4줄만 작게, logx는 펼친 전체 내역
			_finish_draft()
			_board._announcer.cancel()
			_board.instant_roll_for_test = true
			_board._action_log.add_entry("[color=#ffd43b]──── 3라운드 ────[/color]")
			_board._record(2, "🎲 %s 굴림 ➔ [lb]5 5 5 2 2] 풀하우스 → 7칸 이동 확정" % _board._bq("야추 다이스"))
			_board._record(2, "🔥 리벤지 부스터 ➔ 눈금 7칸 + 🔥4칸 = 총 11칸 전진!")
			_board._record(3, "🃏 %s 사용! (14번 타일)" % _board._bq("사장님의 빠루"))
			_board._record(3, "🪤 은신 함정 설치!")
			_board._record(1, "🛡️ 방어 %s 발동! ➔ 컴퓨터 2의 말에게 잡힘을(를) 받아침" % _board._bq("거울의 힘"))
			_board._record(1, "⚔️ %s의 %s 처치!" % [_board._log_who(2), _board._bq("1번 말")])
			_board._record(4, "🪤 %s 밟음! (9번 타일, %s)" % [_board._bq("바나나 껍질"), _board._bq("2번 말")])
			_board._record(1, "♟️ %s 필살기 사용!" % _board._bq("비숍 - 피앙케토"))
			_board._record(2, "⚡ %s 선택!" % _board._bq("초증강 - 공산주의 재분배"), "증강")
			_board._record(-1, "[color=#ffe066][lb]📜 법전] 투기장의 지배자 등록![/color]")
			if _shot == "logx":
				_board._action_log.set_expanded(true)
		"counterzoom":
			# 방어 카드 확대: 발동 시점·방법이 피격 팝업으로 안내되고 평소에는 사용 불가로 보인다
			_finish_draft()
			_board._announcer.cancel()
			_board.instant_roll_for_test = true
			state.give_card(1, &"CNT_02")
			_board._refresh_all()
			_board._open_zoom(1, &"CNT_02")
		"book":
			# 규칙 도감: BOOK=장 번호, ENTRY=항목 번호
			_board.instant_roll_for_test = true  # 오프닝 인트로를 건너뛴다
			_finish_draft()
			_board._announcer.cancel()
			var book: Rulebook = Rulebook.open(_board)
			book.show_spread(int(OS.get_environment("BOOK")) if OS.get_environment("BOOK") != "" else 4, int(OS.get_environment("ENTRY")) if OS.get_environment("ENTRY") != "" else -1)
		"feedback":
			# 피드백 창 (상단 버튼으로 연 상태)
			_board.instant_roll_for_test = true
			_finish_draft()
			_board._announcer.cancel()
			var modal: FeedbackModal = _board._open_feedback("상단 버튼")
			modal.set_message("3라운드에 변이 물약을 골랐는데 말 그림이 그대로였어요")
		"resultfeedback":
			_board.instant_roll_for_test = true
			_finish_draft()
			_board._announcer.cancel()
			_board._show_result_overlay()
		"settings", "popupsettings":
			# 설정: settings = 게임 메뉴의 [게임 설정], popupsettings = 시작 화면·로비의 설정 팝업
			_board.instant_roll_for_test = true
			_finish_draft()
			_board._announcer.cancel()
			if _shot == "settings":
				_board._open_menu()
				_board._show_menu_page(&"settings")
			else:
				LobbyTheme.show_settings(_board)
		"traps":
			# 함정 칸 그림: 내 함정(지뢰·바나나)은 그림, 상대 함정은 물음표, 코너 함정은 공개, 옷장은 청록
			_finish_draft()
			_board._announcer.cancel()
			_board.instant_roll_for_test = true
			state.place_attachment(3, TrapMine.new(1))
			state.place_attachment(5, TrapBanana.new(1))
			state.place_attachment(8, TrapPit.new(2))
			state.place_attachment(BoardSpec.bonus_corner_tiles[0], TrapToll.new(3))
			state.place_attachment(15, TrapSpike.new(4))
			_board._refresh_all()
		"react":
			_finish_draft()
			_board._announcer.cancel()
			_board.instant_roll_for_test = true
			state.give_card(1, &"CNT_03")
			state.give_card(1, &"CNT_04")
			var victim: PlayerPawn = state.get_pawn(11)
			victim.has_left_start = true
			victim.current_tile_idx = 9
			state.begin_attack({"kind": &"card", "card_id": &"ACT_02", "attacker": 2})
			state.send_to_start(victim, 2)
			state.end_attack()
			_board.manager._open_counter_offer(&"turn_begin")
			_board._refresh_all()
		"lawtip":
			_finish_draft()
			_board._announcer.cancel()
			state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
			state.rulebook.enqueue_law(LawRegistry.create("LAW_06"))
			state.law_stats[2] = {VictoryLaw.KILLS: 5, VictoryLaw.EJECTED: 3}
			state.law_stats[3] = {VictoryLaw.KILLS: 2}
			_board._refresh_all()
			_board._fill_law_tip(0)
			_board._tip_panel.visible = true
			_board._tip_panel.reset_size()
			_board._tip_panel.position = Vector2(260, 260)
		"pick":
			_board._draft_cards[1].pressed.emit()
		"rules":
			_finish_draft()
			_board._announcer.cancel()
			state.tools[1] = ToolRegistry.create(StringName(OS.get_environment("TOOL") if OS.get_environment("TOOL") != "" else "HOLDEM"))
			_board._refresh_all()
		"cardhover":
			_finish_draft()
			_board._announcer.cancel()
			state.give_card(1, &"TRP_02")
			state.give_card(1, &"SUM_01")
			state.give_card(1, &"CNT_01")
			_board._refresh_all()
			_board._announcer.cancel()
			var hovered: PanelContainer = null
			for child: Node in _board._dock.get_children():
				if child is PanelContainer and not child.is_queued_for_deletion():
					hovered = child
					break
			_board._on_card_hover(hovered, _board._card_frame_style(GameEnums.CardCategory.TRAP, true), true)
		"pawnchoice":
			_board._close_opening()
			_board._intro_pending = false
			state.get_pawn(12).place_at(5)
			state.get_pawn(12).has_left_start = true
			state.get_pawn(13).is_finished = true
			var def: AugmentDef = AugmentRegistry.get_def(&"EVO_2_1")
			_board._on_augment_chosen(1, 0, def)
		"banner":
			_finish_draft()
			_board.instant_roll_for_test = true
			for entry: Array in [[11, GameEnums.PawnKind.CHESS, 2], [12, GameEnums.PawnKind.JANGGI, 2], [13, GameEnums.PawnKind.GO, 1]]:
				state.give_unit(state.get_pawn(entry[0]), entry[1], [entry[2]] as Array[int])
			state.get_pawn(11).place_at(2)
			state.get_pawn(11).has_left_start = true
			state.get_pawn(12).place_at(4)
			state.get_pawn(12).has_left_start = true
			state.get_pawn(13).place_at(14)
			state.get_pawn(13).has_left_start = true
			state.get_pawn(21).place_at(6)
			state.get_pawn(21).has_left_start = true
			state.get_pawn(14).is_finished = true
			state.tools[1] = ScriptedTool.new([4])
			_board._on_roll_pressed()
		"roulette":
			_finish_draft()
			state.tools[1] = ToolRegistry.create(&"REVOLVER")
			for card_id: StringName in [&"CNT_03", &"ACT_02", &"ACT_03", &"CNT_01", &"ACT_06", &"TRP_02", &"TRP_02"]:
				state.give_card(3, card_id)
				state.give_card(1, card_id)
			state.finish_stack(state.get_pawn(21))
			state.finish_stack(state.get_pawn(22))
			state.finish_stack(state.get_pawn(41))
			for pawn_id: int in [11, 12, 13]:
				var pawn: PlayerPawn = state.get_pawn(pawn_id)
				pawn.place_at(7)
				pawn.has_left_start = true
			state.stack_pawns(state.get_pawn(11), state.get_pawn(12))
			state.stack_pawns(state.get_pawn(11), state.get_pawn(13))
			state.place_attachment(8, Hotel.new(2))
			state.place_attachment(3, TrapPit.new(2))
			state.place_attachment(10, Hotel.new(3))
			_board._refresh_all()
			_board._on_roll_pressed()
		"stack":
			_finish_draft()
			for player_id: int in [1, 2, 3, 4]:
				(state.hands[player_id] as Array).clear()
			state.evolve_pawn(state.get_pawn(11), GameEnums.PawnKind.YUT)
			state.evolve_pawn(state.get_pawn(12), GameEnums.PawnKind.CHESS)
			state.get_pawn(12).place_at(4)
			state.get_pawn(12).has_left_start = true
			state.get_pawn(11).place_at(2)
			state.get_pawn(11).has_left_start = true
			state.tools[1] = ScriptedTool.new([2])
			_board.instant_roll_for_test = true
			_board._on_roll_pressed()
			_board._act(&"select_pawn", {"pawn_id": 11})
		"reverse":
			_finish_draft()
			_board.manager.reverse_turn_order()
			_board._refresh_all()
		"debug":
			_finish_draft()
			_board._on_debug_toggle_pressed()
		"gameover":
			_finish_draft()
			for pawn: PlayerPawn in _board.state.pawns_of(2):
				_board.state.finish_stack(pawn)
			_board.manager._check_victory(null)
