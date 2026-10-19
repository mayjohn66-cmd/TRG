class_name TestCaptureCutin
extends TestCase


func test_every_avatar_has_two_distinct_combat_poses() -> void:
	for avatar: StringName in AvatarCatalog.ids():
		check(AvatarCombatArt.has_pose(avatar, &"attack"), "%s attack image" % avatar)
		check(AvatarCombatArt.has_pose(avatar, &"hit"), "%s hit image" % avatar)
		var attack: Texture2D = AvatarCombatArt.texture(avatar, &"attack")
		var hit: Texture2D = AvatarCombatArt.texture(avatar, &"hit")
		check(attack != null and hit != null and attack != hit, "%s distinct loaded poses" % avatar)
		check(attack.get_width() >= 1024 and hit.get_width() >= 1024, "%s full-resolution sources" % avatar)
	check(AvatarCombatArt.texture(&"avatar_01", &"unknown") == null, "unknown pose is rejected")


func test_capture_signal_is_once_per_stack_and_before_reset() -> void:
	var state := make_state()
	place(state, 11, 1)
	place(state, 21, 2)
	place(state, 22, 2)
	state.stack_pawns(state.get_pawn(21), state.get_pawn(22))
	var captures: Array = []
	state.pawn_captured.connect(func(a: int, b: int) -> void: captures.append([a, b, state.get_pawn(b).current_tile_idx]))
	var report: MoveReport = move(state, 11, 1)
	check_eq(captures, [[11, 21, 2]], "one pre-reset event for the entire captured stack")
	check_eq(report.captured_pawn_ids, int_array([21, 22]), "both stack members still captured")
	state.send_to_start(state.get_pawn(12), 2)
	check_eq(captures.size(), 1, "generic trap/recall reset does not fake a pawn capture")


func test_immune_capture_emits_no_presentation_event() -> void:
	var state := make_state()
	place(state, 11, 1)
	var enemy: PlayerPawn = place(state, 21, 2)
	enemy.evolve(GameEnums.PawnKind.GO, 2)
	var captures: Array = []
	state.pawn_captured.connect(func(a: int, b: int) -> void: captures.append([a,b]))
	move(state, 11, 1)
	check(captures.is_empty(), "white-stone immunity never plays a capture")
	check_eq(enemy.current_tile_idx, 2, "immune stone stays put")


func test_visual_queue_hit_once_cancel_and_time_scale_unchanged() -> void:
	var cutin := CaptureCutin.new()
	tree.root.add_child(cutin)
	defer_free(cutin)
	var hits: Array = []
	cutin.impact.connect(func() -> void: hits.append(true))
	var original_time_scale: float = Engine.time_scale
	check(cutin.enqueue(&"avatar_03", &"avatar_08", 1, 2), "first pair queues")
	check_eq(cutin.attacker_avatar, &"avatar_03", "selected attacker identity")
	check_eq(cutin.defender_avatar, &"avatar_08", "selected defender identity")
	check(not cutin.enqueue(&"avatar_03", &"avatar_08", 1, 2), "stack duplicates suppressed")
	check(not cutin.enqueue(&"avatar_03", &"avatar_03", 1, 1), "self-return suppressed")
	cutin._process(0.12)
	cutin._process(0.05)
	check_eq(hits.size(), 1, "impact emitted once across the held pose")
	check(cutin.enqueue(&"avatar_03", &"avatar_06", 1, 3), "different opponent queues")
	cutin._process(0.34)
	check_eq(cutin.defender_avatar, &"avatar_06", "next opponent uses its own hit pose")
	cutin.cancel()
	check(not cutin.busy() and not cutin.visible, "cancel removes overlay and queue")
	check_eq(Engine.time_scale, original_time_scale, "visual hit stop does not change simulation time")


func test_half_second_without_stale_overlay() -> void:
	var cutin := CaptureCutin.new()
	tree.root.add_child(cutin)
	defer_free(cutin)
	cutin.enqueue(&"avatar_07", &"avatar_04", 3, 4)
	cutin._process(0.499)
	check(cutin.active, "still showing before half second")
	cutin._process(0.002)
	check(not cutin.active and not cutin.visible and not cutin.busy(), "clears at half second")
