extends SceneTree

var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func frames(count: int = 3) -> void:
	for i: int in count: await process_frame

func run() -> void:
	L10n.install()
	GameSession.mode = GameSession.MODE_AI
	GameSession.reset_rules()
	var board: MainBoard = load("res://scenes/main_board.tscn").instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await frames(5)
	board._close_opening()
	board._bot.set_enabled(false)
	board._announcer.cancel()
	board.manager.set_process(false)
	board.instant_roll_for_test = false
	var me := board.local_player_id
	var other := 2 if me == 1 else 1
	board._refresh_all()
	await frames()
	board._play_cucumber_eat(me, true)
	board._play_cucumber_eat(me)
	await frames()
	for name: String in ["MintChocolateEat", "CucumberEat"]:
		var own := board.get_node_or_null(name)
		check(own != null and own.busy(), "Own food plays even when the local profile is hidden")
		if own != null:
			var center := board.get_global_transform_with_canvas().affine_inverse() * (board.get_viewport_rect().size * 0.5)
			check((own._mouth + Vector2(0,own._height*0.5)).is_equal_approx(center), "Own food is centered on the screen")
			check(own.get_children().filter(func(node: Node) -> bool: return node is TextureRect).is_empty(), "Own food never creates a portrait")
			check(own.upright_food, "Own food stays upright")
	await create_timer(1.48 * board._motion_pace() + 0.2).timeout
	check(board.get_node_or_null("MintChocolateEat") == null, "Own mint eating finishes and cleans up")
	var avatar: Control = board._profiles[other]["avatar"]
	check(avatar.is_visible_in_tree(), "The other player's existing avatar is visible")
	board._play_cucumber_eat(other)
	board._play_cucumber_eat(other, true)
	await frames()
	var cucumber := board.get_node_or_null("CucumberEat")
	var mint := board.get_node_or_null("MintChocolateEat")
	check(mint != null and mint.busy(), "Mint eating plays at the visible profile")
	if mint != null and cucumber != null:
		check(mint._mouth.is_equal_approx(cucumber._mouth), "Mint and cucumber use the same profile mouth position")
		check(mint.get_children().filter(func(node: Node) -> bool: return node is TextureRect).is_empty(), "Mint creates no duplicate portrait")
		check(mint.upright_food, "The ice cream cone remains upright")
	await create_timer(1.48 * board._motion_pace() + 0.2).timeout
	check(board.get_node_or_null("MintChocolateEat") == null, "Mint eating cleans up after the three bites")
	board._play_cucumber_eat(me, true)
	await frames()
	board._reset_presentation()
	await frames()
	check(board.get_node_or_null("MintChocolateEat") == null, "Reset cancels central food without leaving an overlay")
	board.queue_free()
	await frames()
	for failure: String in failures: printerr("MINT_PROFILE_FAIL ", failure)
	print("MINT_PROFILE_OK" if failures.is_empty() else "MINT_PROFILE_FAIL")
	quit(0 if failures.is_empty() else 1)
