## Only SUPER_01: use the real augment/draft queue for both authoritative outcomes.
extends "res://tests/ui_super_fx_test.gd"

var desired_success := true
var saw_coin := false
var saw_result := false
var rng_at_toss := 0
var waiting_positions: Dictionary = {}
var shots: Dictionary = {}

func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	for outcome: bool in [true,false]:
		desired_success = outcome
		saw_coin = false
		saw_result = false
		shots.clear()
		await _check(SuperAugments.FLIP)
		_expect(saw_coin and saw_result,"Both the 3D toss and its readable result appear")
	if _failures.is_empty():
		print("UI_FLIP_OK: success and failure")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("UI_FLIP_FAIL: "+failure)
		quit(1)

func _stage(effect: StringName) -> void:
	super._stage(effect)
	_board.ai_mode = false
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	# Choose fixtures through the engine's own random sequence, never in the renderer.
	for seed_value: int in range(1,1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		probe.randi_range(0,2)
		if (probe.randi_range(0,99)<SuperAugments.flip_chance())==desired_success:
			_board.state.rng.seed = seed_value
			break
	waiting_positions.clear()
	for pawn: PlayerPawn in _board.state.pawns_of(1):
		waiting_positions[pawn.entity_id] = (_board._pawn_views[pawn.entity_id] as Node2D).position

func _process(_delta: float) -> bool:
	if _board==null or not is_instance_valid(_board):
		return false
	var bolt: Sprite2D = _board._pawn_layer.get_node_or_null("PaintedLightning") as Sprite2D
	if bolt!=null:
		_expect(bolt.texture==PaintedFx.LIGHTNING,"Failure uses a branched painted lightning strike")
		capture("lightning")
	if desired_success and not shots.has("launch"):
		for node: Node in get_nodes_in_group(MainBoard.ONESHOT_FX_GROUP):
			if node.get_meta(FxPool.KIND_META,&"")==&"rocket_flame":
				capture("launch")
				break
	var coin: Node2D = _board._pawn_layer.get_node_or_null("FateCoin3D")
	if coin==null:
		return false
	if not saw_coin:
		saw_coin = true
		rng_at_toss = _board.state.rng.state
		_expect(coin.rotor.get_node_or_null("GoldFace")!=null and coin.rotor.get_node_or_null("RedFace")!=null,"Coin has distinct real front/back faces")
	if not coin.settled:
		for id: int in waiting_positions:
			_expect((_board._pawn_views[id] as Node2D).position.is_equal_approx(waiting_positions[id]),"Target does not move before the coin result")
	if coin.progress>0.40 and coin.progress<0.65:
		capture("toss")
	if coin.settled and not saw_result:
		saw_result = true
		_expect(coin.success==desired_success,"Visible coin outcome matches the engine result")
		_expect(_board.state.rng.state==rng_at_toss,"Presentation does not consume gameplay RNG")
		_expect(coin.caption.text==("완주!" if desired_success else "출발선 추방"),"Result is readable before pawn movement")
		capture("result")
	return false

func capture(label: String) -> void:
	var folder := OS.get_environment("FLIP_CAPTURE_DIR")
	if folder=="" or shots.has(label):
		return
	shots[label] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(("success_" if desired_success else "failure_")+label+".png"))
