extends TestCase

func test_packed_shots_roundtrip_and_reject_invalid_values() -> void:
	for aim: int in range(-BottleCapPhysics.AIM_MAX, BottleCapPhysics.AIM_MAX + 1):
		for power: int in [0, 1, 525, 999, 1150]:
			var packed := BottleCapPhysics.encode(power, aim)
			check(BottleCapPhysics.valid(packed), "A quantized shot is accepted")
			check_eq(BottleCapPhysics.decode(packed), Vector2i(power, aim), "Power and direction survive network packing")
	for value: int in [-100, -1, 1151, 9999, 66399, 9999999]:
		check(not BottleCapPhysics.valid(value), "Malformed shot cannot enter the physics world")
	check_eq(BottleCapPhysics.isqrt(1000000000000), 1000000, "Integer square root does not use platform float rounding")
	check_eq(BottleCapPhysics.isqrt(15), 3, "Integer root floors non-squares")

func test_friction_decelerates_without_teleport_and_stops_at_rest() -> void:
	var world := BottleCapPhysics.new()
	world.shoot(0, BottleCapPhysics.encode(750))
	check_eq(world.caps[0].pos, BottleCapPhysics.START, "A shot starts at the launch point")
	var last_speed := 1 << 30
	var ticks := 0
	while world.moving() and ticks < BottleCapPhysics.MAX_TICKS:
		var old_position: Vector2i = world.caps[0].pos
		world.step()
		var velocity: Vector2i = world.caps[0].vel
		check(velocity.length_squared() < last_speed or velocity == Vector2i.ZERO, "Sliding friction removes energy every tick")
		last_speed = velocity.length_squared()
		check((world.caps[0].pos as Vector2i).x >= old_position.x, "A straight cap never snaps backwards")
		ticks += 1
	check(not world.moving() and not bool(world.caps[0].out), "A modest shot stops on the table")
	var stop: Vector2i = world.caps[0].pos
	world.step()
	check_eq(world.caps[0].pos, stop, "A stopped cap stays still")

func test_contact_transfers_momentum_and_can_push_the_opponent_off() -> void:
	var world := BottleCapPhysics.new()
	world.shoot(0, BottleCapPhysics.encode(850))
	world.settle()
	var first_stop: Vector2i = world.caps[0].pos
	world.shoot(1, BottleCapPhysics.encode(1100))
	var saw_transfer := false
	for tick: int in BottleCapPhysics.MAX_TICKS:
		world.step()
		if world.contacts > 0:
			saw_transfer = saw_transfer or (world.caps[0].pos as Vector2i).x > first_stop.x
		if not world.moving():
			break
	check(world.contacts > 0 and saw_transfer, "A real collision moves the first cap")
	check(bool(world.caps[0].out) and not bool(world.caps[1].out), "The stronger second shot ejects the first and remains on the table")
	check_eq(int(world.result()["index"]), 1, "The actual surviving cap wins, rather than comparing shot power")
	var fallen: Vector2i = world.caps[0].pos
	world.step()
	check_eq(world.caps[0].pos, fallen, "A fallen cap cannot re-enter or collide")

func test_glancing_collisions_deflect_and_rails_rebound() -> void:
	var world := BottleCapPhysics.new()
	world.shoot(0, BottleCapPhysics.encode(800))
	world.settle()
	world.shoot(1, BottleCapPhysics.encode(1050, 3))
	var deflected := false
	for tick: int in BottleCapPhysics.MAX_TICKS:
		world.step()
		deflected = deflected or (world.contacts > 0 and (world.caps[0].vel as Vector2i).y != 0)
		if not world.moving():
			break
	check(deflected, "An offset impact transfers lateral momentum")
	world = BottleCapPhysics.new()
	world.shoot(0, BottleCapPhysics.encode(1150, 24))
	var reflected := false
	for tick: int in BottleCapPhysics.MAX_TICKS:
		world.step()
		for event: Dictionary in world.events:
			reflected = reflected or (event.kind == &"rail" and (world.caps[0].vel as Vector2i).y < 0)
		if not world.moving():
			break
	check(reflected, "A side rail reverses the lateral velocity with energy loss")

func test_fixed_steps_replay_identically_and_match_duel_authority() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4462
	for sample: int in 80:
		var a := BottleCapPhysics.encode(rng.randi_range(0, 1150), rng.randi_range(-24, 24))
		var b := BottleCapPhysics.encode(rng.randi_range(0, 1150), rng.randi_range(-24, 24))
		var first := BottleCapPhysics.simulate(a, b)
		var replay := BottleCapPhysics.new()
		for pair: Vector2i in [Vector2i(0, a), Vector2i(1, b)]:
			replay.shoot(pair.x, pair.y)
			while replay.moving():
				replay.step()
		check_eq(first.caps, replay.caps, "The recorded inputs recreate every integer position, velocity and spin")
		var result := DuelRules.resolve(DuelRules.Game.CURLING, {"physics": true}, 3, 7, {3: a, 7: b})
		check_eq(result["winner"], 3 if int(first.result()["index"]) == 0 else 7, "The engine winner is the replay winner")
	var timeout_world := BottleCapPhysics.simulate(1150, 1150)
	check_eq(timeout_world.result()["decided_by"], &"both_fell", "Both missed turns retain the challenger fallback after two falls")

func test_full_circle_directions_and_legacy_compatibility() -> void:
	for heading: int in 360:
		var packed := BottleCapPhysics.encode_direction(850, heading)
		check(BottleCapPhysics.valid(packed), "Every full-circle direction is a legal network input")
		check_eq(BottleCapPhysics.decode(packed), Vector2i(850, heading), "Heading round trips exactly")
		var world := BottleCapPhysics.new()
		world.shoot(0, packed)
		world.settle()
		var replay := BottleCapPhysics.new()
		replay.shoot(0, packed)
		replay.settle()
		check_eq(world.caps, replay.caps, "Full-circle shots replay deterministically")
	for pair: Array in [[0, Vector2i(1000000, 0)], [90, Vector2i(0, 1000000)], [180, Vector2i(-1000000, 0)], [270, Vector2i(0, -1000000)]]:
		check_eq(BottleCapPhysics.direction(pair[0]), pair[1], "Cardinal impulse points in the chosen direction")
	check_eq(BottleCapPhysics.encode_direction(850, -90), BottleCapPhysics.encode_direction(850, 270), "Negative headings wrap")
	check(not BottleCapPhysics.valid(BottleCapPhysics.DIRECTION_BASE + 360 * 1151), "Packed headings beyond 359 are rejected")
	check_eq(BottleCapPhysics.decode(850), Vector2i(850, 0), "Original straight shot remains unchanged")
	check_eq(DuelRules.DRAW_PREP_TIME, ToyFlagGun3D.PREP_TIME, "Engine reserves the entire revolver loading sequence")
