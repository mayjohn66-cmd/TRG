## Scoped melon rules, real fruit sprite and deterministic rolling sampling.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	BoardSpec.apply(24)
	var probe := TestV11Content.new()
	probe.tree = self
	probe.current_test = "test_weird_melon_eats_traps_and_grows_to_giant"
	probe.test_weird_melon_eats_traps_and_grows_to_giant()
	probe.cleanup()
	probe.current_test = "melon_fruit_and_rolling"
	var pawn := PlayerPawn.new()
	pawn.evolve(GameEnums.PawnKind.ARCADE, 7)
	pawn.owner_id = 1
	var art: Dictionary = PawnArt.sprite(pawn)
	probe.check(not art.is_empty(), "melon image resolves")
	var texture: Texture2D = art.texture
	probe.check(texture.resource_path.ends_with("ODD_MELON_V01.png"), "new fruit image wins")
	probe.check(texture.get_width() <= 256 and texture.get_height() <= 256, "bounded runtime texture")
	probe.check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "true transparent fruit")
	probe.check(PawnArt.candidates(pawn).has(PawnArt.ROOT + "ODD_MELON.png"), "old source remains a fallback")
	probe.check(AugmentArt.load_first(AugmentArt.candidates(AugmentRegistry.get_def(&"EVO_7_7"))) == texture, "augment and pawn share fruit image")
	var token := PawnToken.new()
	token.configure(pawn, Color("e5484d"))
	probe.check(token.is_rolling_melon(), "only melon uses rolling")
	probe.check(token.artwork_rect().size.x <= 26.001 and token.artwork_rect().size.y <= 31.001, "same token body budget")
	var original_radius: float = token.melon_roll_radius()
	probe.check(is_equal_approx(token.melon_roll_center().y, -original_radius), "rotation center is above ground by body radius")
	token.melon_roll_angle = 1.2
	pawn.melon_size = 3
	token.configure(pawn, Color("e5484d"))
	probe.check(is_equal_approx(token.melon_roll_angle, 1.2), "growth/refresh retains roll phase")
	probe.check(is_equal_approx(token.melon_roll_radius(), original_radius * 1.6), "rotation radius follows actual grown size")
	var board := MainBoard.new()
	var view := Node2D.new()
	var bounce := Node2D.new()
	bounce.name = "Bounce"
	view.add_child(bounce)
	bounce.add_child(token)
	# Both screen travel directions use one progress value for translation/spin.
	for direction: float in [1.0, -1.0]:
		for i: int in 11:
			var progress: float = i / 10.0
			board._sample_melon_roll(progress, view, token, Vector2(10, 30), Vector2(70 * direction, 90), 1.0, 0.8, 1.2, direction * 3.0)
			probe.check(view.position.is_equal_approx(Vector2(10, 30).lerp(Vector2(70 * direction, 90), progress)), "fruit stays on ground path")
			probe.check(is_equal_approx(token.melon_roll_angle, fposmod(1.2 + direction * 3.0 * progress, TAU)), "spin matches travel progress")
			probe.check(bounce.position == Vector2.ZERO and bounce.scale == Vector2.ONE and bounce.rotation == 0.0, "base and markers never hop/squash/spin")
	pawn.evolve(GameEnums.PawnKind.ARCADE, 6)
	token.configure(pawn, Color("e5484d"))
	probe.check(not token.is_rolling_melon() and token.melon_roll_angle == 0.0, "changing into Cuee clears fruit rotation")
	view.free()
	board.free()
	for failure: String in probe.failures: printerr("MELON_FAIL ", failure)
	print("MELON_CORE ", probe.assertions, " assertions; ", probe.failures.size(), " failures")
	quit(0 if probe.failures.is_empty() else 1)
