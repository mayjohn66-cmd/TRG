## Focused protection presentation: actual shield consumption, overlapping charges,
## recharge, snapshot restoration and cancelling a disappearing shell.
extends SceneTree

var _failures: Array[String] = []
var _checks: int = 0
var _tokens: Dictionary = {}
var _board: MainBoard
var _state: GameState

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, note: String) -> void:
	_checks += 1
	if not ok: _failures.append(note)

func _label(text: String, position: Vector2, extent: Vector2, px: int = 22) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Color("36584d"))
	root.add_child(label)

func _make_token(pawn: PlayerPawn, foot: Vector2, factor: float, main: bool) -> PawnToken:
	var token := PawnToken.new()
	token.name = "Token"
	token.configure(pawn, MainBoard.PLAYER_COLORS[pawn.owner_id])
	var view := Node2D.new()
	view.position = foot
	view.scale = Vector2.ONE * factor
	var bounce := Node2D.new()
	bounce.name = "Bounce"
	view.add_child(bounce)
	bounce.add_child(token)
	root.add_child(view)
	if main: _board._pawn_views[pawn.entity_id] = view
	if not _tokens.has(pawn.entity_id): _tokens[pawn.entity_id] = []
	(_tokens[pawn.entity_id] as Array).append(token)
	return token

func _sync(pawn_id: int, blocked: bool = false) -> void:
	_board._refresh_pawn_protection(pawn_id, blocked)
	for item: Variant in _tokens.get(pawn_id, []):
		var token: PawnToken = item
		token.configure(_state.get_pawn(pawn_id), MainBoard.PLAYER_COLORS[token.pawn.owner_id])
		if blocked: token.shield_hit()

func _capture(file: String) -> void:
	var folder: String = OS.get_environment("SHIELD_CAPTURE")
	if folder == "": return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(folder.path_join(file)) == OK, "saved " + file)

func _run() -> void:
	root.size = Vector2i(1200, 580)
	root.content_scale_size = Vector2i(1200, 580)
	var background := ColorRect.new()
	background.color = Color("d7e9ac")
	background.size = Vector2(1200, 580)
	root.add_child(background)
	_label("보호막 · 백돌과 증강 보호막 공통 표시", Vector2(0, 20), Vector2(1200, 40), 28)
	_state = GameState.new()
	_state.boost_gimmicks = false
	_state.setup([1, 2] as Array[int], 421)
	_board = MainBoard.new()  # No full game scene; exercise its production token refresh helper.
	_board.state = _state
	var white: PlayerPawn = _state.get_pawn(11)
	white.evolve(GameEnums.PawnKind.GO, 2)
	var ward: PlayerPawn = _state.get_pawn(21)
	ward.evolve(GameEnums.PawnKind.CHESS, 2)
	ward.ward = true
	var plain: PlayerPawn = _state.get_pawn(22)
	plain.evolve(GameEnums.PawnKind.CHESS, 2)
	var doubled: PlayerPawn = _state.get_pawn(12)
	doubled.evolve(GameEnums.PawnKind.GO, 2)
	doubled.ward = true
	var pawns: Array[PlayerPawn] = [white, ward, plain, doubled]
	var titles: Array[String] = ["백돌 · 방어막", "증강 · 보호막", "보호막 없음", "백돌 + 증강 보호막"]
	for index: int in pawns.size():
		var pawn: PlayerPawn = pawns[index]
		pawn.has_left_start = true
		pawn.current_tile_idx = 5 + index * 3
		_label(titles[index], Vector2(index * 300, 92), Vector2(300, 35))
		_make_token(pawn, Vector2(150 + index * 300, 310), 4.0, true)
		_make_token(pawn, Vector2(150 + index * 300, 458), 1.25, false)
	_label("보드에서 보이는 크기", Vector2(0, 500), Vector2(1200, 35), 18)
	_state.shield_broken.connect(func(id: int, _tile: int) -> void: _sync(id, true))
	_state.shield_recharged.connect(func(id: int) -> void: _sync(id))
	for _frame: int in 3: await process_frame
	for pawn: PlayerPawn in pawns:
		var token: PawnToken = _tokens[pawn.entity_id][0]
		_expect(token.has_protection() == (pawn != plain), "initial protection state")
		if pawn == plain:
			_expect(token.get_node_or_null("ProtectionShell") == null, "ordinary pawn has no shell")
		else:
			_expect(token._shield_shell.active and token._shield_shell.visible, "protected pawn is inside glass")
			_expect(not token.is_processing(), "idle protection requires no token CPU animation")
			for layer: ColorRect in token._shield_shell._layers:
				_expect(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "glass does not intercept input")
	var white_token: PawnToken = _tokens[11][0]
	var ward_token: PawnToken = _tokens[21][0]
	var double_token: PawnToken = _tokens[12][0]
	var shell_id: int = ward_token._shield_shell.get_instance_id()
	_expect(white_token._shield_shell._materials[0] != ward_token._shield_shell._materials[0], "per-pawn parameters are isolated")
	var snapshot: TurnSnapshot = TurnSnapshot.capture(_state)
	await _capture("shield-active.png")
	_expect(_state.break_shield(doubled), "first overlapping protection consumed")
	_expect(not doubled.ward and doubled.shield and double_token._shield_shell.active, "remaining white-stone charge keeps shell")
	_expect(_state.break_shield(white) and _state.break_shield(ward), "last charges consumed")
	_expect(not white_token._shield_shell.active and white_token._shield_shell.visible, "shell shatters before hiding")
	await create_timer(0.13).timeout
	await _capture("shield-breaking.png")
	await create_timer(0.30).timeout
	_expect(not white_token._shield_shell.visible and not ward_token._shield_shell.visible, "last charge removes glass")
	_expect(double_token._shield_shell.visible, "other pawn with a remaining charge stays protected")
	_state.recharge_shields()
	var given: Dictionary = UtilityAugments.apply_shield_to(_state, 2, ward.entity_id)
	_sync(ward.entity_id)
	_expect(bool(given["ok"]), "utility ward is granted")
	_expect(white_token._shield_shell.active and ward_token._shield_shell.active, "recharge and new ward appear")
	await create_timer(0.10).timeout
	await _capture("shield-forming.png")
	await create_timer(0.32).timeout
	_expect(is_equal_approx(float(white_token._shield_shell._materials[0].get_shader_parameter("strength")), 1.0), "formation settles at full strength")
	_expect(_state.break_shield(doubled), "second overlapping charge consumed")
	await create_timer(0.38).timeout
	_expect(not double_token._shield_shell.visible, "overlapping shell disappears only after second hit")
	snapshot.restore(_state)
	for pawn: PlayerPawn in pawns: _sync(pawn.entity_id)
	await create_timer(0.38).timeout
	_expect(white_token._shield_shell.active and ward_token._shield_shell.active and double_token._shield_shell.active, "snapshot restores visible protections")
	ward.evolve(GameEnums.PawnKind.CHESS, 3)
	_sync(ward.entity_id)
	_expect(ward_token.has_protection() and ward_token._shield_shell.active, "ward remains through evolution")
	_expect(ward_token._shield_shell.get_instance_id() == shell_id, "refreshes reuse one shell")
	var front: ColorRect = ward_token._shield_shell._layers[1]
	var old_position: Vector2 = front.global_position
	var moving_view: Node2D = _board._pawn_views[ward.entity_id]
	moving_view.position += Vector2(32, -18)
	_expect(front.global_position.is_equal_approx(old_position + Vector2(32, -18)), "glass follows movement and jumping with its pawn")
	_expect(_state.break_shield(white), "start a break transition")
	await create_timer(0.06).timeout
	_state.recharge_shields()
	await create_timer(0.40).timeout
	_expect(white_token._shield_shell.active and white_token._shield_shell.visible, "a new charge cancels stale hiding callback")
	white.is_finished = true
	_sync(white.entity_id)
	_expect(not white_token._shield_shell.visible, "finished pawn has no protection shell")
	white.is_finished = false
	white_token.shield_motion = false
	_sync(white.entity_id)
	_expect(white_token._shield_shell.active and white_token._shield_shell.visible, "motion-off mode still shows protection status")
	doubled.shield = false
	_sync(doubled.entity_id)
	_board._tip_title = Label.new()
	_board._tip_ability = Label.new()
	_board._tip_skill = Label.new()
	_board._tip_rule = ColorRect.new()
	for item: Control in [_board._tip_title, _board._tip_ability, _board._tip_skill, _board._tip_rule]:
		_board.add_child(item)
	_board._fill_pawn_tip(doubled.entity_id)
	_expect(_board._tip_title.text.contains("보호막 있음") and not _board._tip_title.text.contains("방어막 깨짐"), "white stone with surviving ward has an accurate tooltip")
	_expect(L10n.translate_text("보호막 있음", "en") == "Shield active", "English protection status")
	_expect(L10n.translate_text("보호막 있음", "ja") == "バリアあり", "Japanese protection status")
	for failure: String in _failures: printerr("FAIL ", failure)
	_board.free()
	print("PAWN_SHIELD_OK: ", _checks, " checks, ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
