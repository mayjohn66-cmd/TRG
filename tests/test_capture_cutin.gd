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
	cutin._process(CaptureCutin.IMPACT_AT + 0.01)
	cutin._process(0.05)
	check_eq(hits.size(), 1, "impact emitted once across the held pose")
	check(cutin.enqueue(&"avatar_03", &"avatar_06", 1, 3), "different opponent queues")
	cutin._process(CaptureCutin.DURATION)
	check_eq(cutin.defender_avatar, &"avatar_06", "next opponent uses its own hit pose")
	cutin.cancel()
	check(not cutin.busy() and not cutin.visible, "cancel removes overlay and queue")
	check_eq(Engine.time_scale, original_time_scale, "visual hit stop does not change simulation time")


func test_full_duration_without_stale_overlay() -> void:
	var cutin := CaptureCutin.new()
	tree.root.add_child(cutin)
	defer_free(cutin)
	cutin.enqueue(&"avatar_07", &"avatar_04", 3, 4)
	cutin._process(CaptureCutin.DURATION - 0.001)
	check(cutin.active, "still showing before the end of the slow-motion sequence")
	cutin._process(0.002)
	check(not cutin.active and not cutin.visible and not cutin.busy(), "clears at the end of the complete sequence")


func test_impact_hold_and_slow_recoil_preserve_direction_and_speed_contrast() -> void:
	var held_a: Dictionary = CaptureCutin.motion_at(CaptureCutin.IMPACT_AT + 0.01)
	var held_b: Dictionary = CaptureCutin.motion_at(CaptureCutin.HOLD_UNTIL - 0.01)
	check_eq(held_a, held_b, "both actors and zoom are motionless throughout the impact hold")
	var strike_a: Dictionary = CaptureCutin.motion_at(0.10)
	var strike_b: Dictionary = CaptureCutin.motion_at(0.13)
	var slow_a: Dictionary = CaptureCutin.motion_at(0.36)
	var slow_b: Dictionary = CaptureCutin.motion_at(0.50)
	var strike_speed: float = (float(strike_b["attack"]) - float(strike_a["attack"])) / 0.03
	var slow_speed: float = (float(slow_b["hit"]) - float(slow_a["hit"])) / 0.14
	check(slow_speed > 0.0 and strike_speed > slow_speed * 4.0, "fast rightward strike visibly contrasts with slow rightward recoil")
	var released: Dictionary = CaptureCutin.motion_at(CaptureCutin.DURATION - 0.02)
	check(float(released["hit"]) > float(slow_b["hit"]) * 3.0, "release accelerates the victim out of the held impact")
	check(CaptureCutin.DURATION < 1.1, "the emphasis remains under a little over one second")
	check(ResourceLoader.exists(CaptureCutin.INK_PATH), "the hand-painted transparent impact asset is present")
	check_eq(CaptureCutin.impact_kind(&"avatar_05"), &"slash", "Shady gets a scythe slash")
	check_eq(CaptureCutin.impact_kind(&"avatar_06"), &"pierce", "Daya gets a crystal-blade streak")
	check_eq(CaptureCutin.impact_kind(&"avatar_01"), &"blunt", "Erpin gets a punch shock ring")
