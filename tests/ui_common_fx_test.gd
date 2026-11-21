## Shared impact/particle/trail helpers only; no match, AI or unrelated stages.
extends SceneTree

class FixtureBoard extends MainBoard:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass

var _board: MainBoard
var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, note: String) -> void:
	_checks += 1
	if not ok: _failures.append(note)

func _active(kind: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in get_nodes_in_group(MainBoard.ONESHOT_FX_GROUP):
		if node.get_meta(FxPool.KIND_META, &"") == kind: found.append(node)
	return found

func _token(pawn: PlayerPawn, foot: Vector2, factor: float = 1.0) -> Node2D:
	var view := Node2D.new()
	view.position = foot
	view.scale = Vector2.ONE * factor
	var bounce := Node2D.new()
	bounce.name = "Bounce"
	view.add_child(bounce)
	var token := PawnToken.new()
	token.name = "Token"
	token.configure(pawn, MainBoard.PLAYER_COLORS[pawn.owner_id])
	bounce.add_child(token)
	_board._pawn_layer.add_child(view)
	return view

func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color("36584c"))
	root.add_child(label)

func _capture(tag: String) -> void:
	var folder := OS.get_environment("COMMON_FX_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(folder.path_join(tag + ".png")) == OK, "Saved " + tag)

func _run() -> void:
	root.size = Vector2i(1120, 680)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("d9e8ae")
	background.size = Vector2(root.size)
	root.add_child(background)
	_label("공통 충격파 · 작은 질감 파편", Vector2(75, 35))
	_label("이동 잔상 · 기물의 실제 윤곽", Vector2(75, 350))
	_board = FixtureBoard.new()
	_board.pacing_enabled = false
	_board.state = GameState.new()
	_board.state.boost_gimmicks = false
	_board.state.setup([1, 2] as Array[int], 421)
	root.add_child(_board)
	_board._pawn_layer = Node2D.new()
	_board._pawn_layer.position = Vector2(30, 80)
	_board._pawn_layer.scale = Vector2(2.5, 2.5)
	_board.add_child(_board._pawn_layer)
	var before_rng := _board.state.rng.state
	var before_clock := Engine.time_scale
	var knight: PlayerPawn = _board.state.get_pawn(11)
	knight.evolve(GameEnums.PawnKind.CHESS, 2)
	var stone: PlayerPawn = _board.state.get_pawn(21)
	stone.evolve(GameEnums.PawnKind.GO, 1)
	_token(knight, Vector2(105, 65), 1.7)
	_token(stone, Vector2(285, 65), 1.7)
	var moving := _token(knight, Vector2(90, 195), 1.7)
	var normal := _token(_board.state.get_pawn(12), Vector2(387, 65), 0.5)
	_expect(MainBoard.COMMON_SHOCKWAVE.get_width() == 512 and MainBoard.COMMON_FLECK.get_width() == 128, "Bounded runtime image sizes")
	var ring_image := MainBoard.COMMON_SHOCKWAVE.get_image()
	_expect(ring_image.get_pixel(ring_image.get_width() / 2, ring_image.get_height() / 2).a < 0.01, "Shockwave leaves the pawn center transparent")
	for at: Vector2 in [Vector2(105, 65), Vector2(285, 65), normal.position]:
		_board._impact_ring(at, Color("ffb940"), 50.0 if at != normal.position else 22.0)
		_board._burst_shards(at, Color("ffb940"), 80)
	for node: Node in _active(&"ring"):
		_expect(node is Sprite2D and node.texture == MainBoard.COMMON_SHOCKWAVE, "Impact uses painted sprite")
		_expect(node.modulate.a <= 0.82 and node.region_enabled, "Painted impact respects tint and cropped bounds")
	for node: CPUParticles2D in _active(&"shards"):
		_expect(node.amount == MainBoard.MAX_BURST_PARTICLES and node.texture == MainBoard.COMMON_FLECK, "Burst cap and real particle texture")
		_expect(node.scale_amount_max * node.texture.get_width() <= 16.1 and node.color_ramp.sample(1.0).a == 0, "Tiny particles fade completely")
	await create_timer(0.10).timeout
	await _capture("common-impact")
	await create_timer(0.85).timeout
	_expect(_active(&"ring").is_empty() and _active(&"shards").is_empty(), "Normal completion returns impact nodes to pool")
	var allocations := _board._fx_pool.created
	_board._impact_ring(Vector2(105, 65), Color.CYAN, 20)
	_board._burst_shards(Vector2(105, 65), Color.CYAN, 4)
	_expect(_board._fx_pool.created == allocations, "Repeated impact reuses pooled nodes")
	_board.sweep_oneshot_fx(true)
	# Sample an actually moving, scaled, jumping and rotated token under a transformed layer.
	var bounce: Node2D = moving.get_node("Bounce")
	bounce.position.y = -4
	bounce.rotation = 0.18
	_board._fx_trail(moving, 0.55, Color("46a9ff"))
	var motion := moving.create_tween()
	motion.tween_property(moving, "position:x", 275.0, 0.55)
	await create_timer(0.17).timeout
	var ghosts := _active(&"trail")
	_expect(ghosts.size() >= 2, "Moving pawn leaves several short silhouette samples")
	var token: PawnToken = moving.get_node("Bounce/Token")
	for ghost: Sprite2D in ghosts:
		_expect(ghost.texture == token.artwork.texture and ghost.region_rect == token.artwork.region, "Ghost uses the pawn's actual artwork")
		_expect((ghost.material as ShaderMaterial).shader == MainBoard.PAWN_SILHOUETTE, "Ghost preserves alpha silhouette without original colors")
		_expect(is_equal_approx(ghost.global_rotation, token.global_rotation) and ghost.global_position.x < token.global_position.x + 15, "Ghost freezes sampled posture behind moving pawn")
		_expect(ghost.z_index <= moving.z_index and ghost.get_index() < moving.get_index(), "Ghost renders behind its source, even for a ground-level pawn")
		_expect(ghost.modulate.a > 0 and ghost.modulate.a <= 0.32, "Silhouette stays subordinate to pawn")
	await _capture("common-trail")
	await create_timer(0.8).timeout
	_expect(_active(&"trail").is_empty(), "Trail expires without a persistent shadow")
	var reuse_before := _board._fx_pool.reused
	_board._pawn_trail_sample(token, Color.CYAN)
	_expect(_board._fx_pool.reused > reuse_before, "Silhouette samples reuse pooled sprites")
	var sample: Sprite2D = _active(&"trail")[0]
	var extent: Vector2 = sample.region_rect.size * sample.scale
	var expected: Vector2 = token.to_global(Vector2(0, -extent.y / (moving.scale.y * bounce.scale.y) * 0.5))
	_expect(sample.global_position.distance_to(expected) < 0.01, "Sample origin matches the actual artwork rectangle after nested transforms")
	_board.sweep_oneshot_fx(true)
	# Reset a running emitter, then move the pawn: no old presentation may emit anew.
	_board._fx_trail(moving, 1.0, Color.CYAN)
	await process_frame
	_board._reset_presentation()
	_board.sweep_oneshot_fx(true)
	moving.position.x += 40
	await create_timer(0.12).timeout
	_expect(_active(&"trail").is_empty(), "Presentation reset stops emission")
	_board._fx_trail(moving, 1.0, Color.CYAN)
	moving.queue_free()
	await create_timer(0.12).timeout
	_expect(_active(&"trail").is_empty(), "Freed source cancels emitter safely")
	_board.instant_roll_for_test = true
	var created := _board._fx_pool.created
	_board._impact_ring(Vector2.ZERO, Color.WHITE, 20)
	_board._burst_shards(Vector2.ZERO, Color.WHITE)
	_board._fx_trail(normal, 0.2, Color.WHITE)
	await process_frame
	_expect(_active(&"ring").is_empty() and _active(&"shards").is_empty() and _active(&"trail").is_empty(), "Effects-off creates no common visuals")
	_expect(_board._fx_pool.created == created, "Effects-off allocates nothing")
	_expect(_board.state.rng.state == before_rng and Engine.time_scale == before_clock, "Common visuals never consume gameplay RNG or change simulation speed")
	_board.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("UI_COMMON_FX_OK: %d checks" % _checks)
		quit(0)
	else:
		for failure: String in _failures: printerr("UI_COMMON_FX_FAIL: " + failure)
		quit(1)
