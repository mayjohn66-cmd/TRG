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
	if (_shot != "banner" and _frames == (8 if _shot == "pick" else (20 if _shot == "react" or _shot == "classics" else 12))) or (_shot == "banner" and _banner_frame == -2):
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
			pass
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
			state.give_card(2, &"ACT_05")
			state.give_card(3, &"TRP_04")
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
			state.give_card(1, &"ACT_01")
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
			_board.state.give_card(1, &"TRP_04")
			_board._refresh_all()
			_board._on_card_pressed(1, &"TRP_04")
		"interrupt":
			_finish_draft()
			_board.state.give_card(2, &"ACT_01")
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
			state.give_card(1, &"ACT_05")
			state.give_card(1, &"ACT_01")
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
		"react":
			_finish_draft()
			_board._announcer.cancel()
			_board.instant_roll_for_test = true
			state.give_card(1, &"ACT_05")
			state.turn_snapshot = TurnSnapshot.capture(state)
			state.hurt_players.append(1)
			_board.manager.current_state = TurnManager.State.PHASE_RESOLUTION
			_board._refresh_all()
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
			state.give_card(1, &"ACT_05")
			_board._refresh_all()
			_board._announcer.cancel()
			var hovered: PanelContainer = null
			for child: Node in _board._dock.get_children():
				if child is PanelContainer and not child.is_queued_for_deletion():
					hovered = child
					break
			_board._on_card_hover(hovered, _board._card_frame_style(GameEnums.CardCategory.TRAP, true), true)
		"pawnchoice":
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
			for card_id: StringName in [&"ACT_01", &"ACT_02", &"ACT_03", &"ACT_05", &"ACT_06", &"TRP_01", &"TRP_02"]:
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
