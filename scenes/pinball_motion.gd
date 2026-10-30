## Fixed-step downhill ball simulation, sampled for frame-rate independent playback.
## Candidate launch velocities preserve the authoritative pocket without steering mid-fall.
extends RefCounted

const RADIUS: float = 0.115
const FIELD_Y: float = 0.45 + RADIUS
const PARK := Vector3(2.79, 0.4825 + RADIUS, 3.10)
const ARCH_Z: float = -1.55
const ARCH_RADIUS: float = 2.795
const STEP: float = 1.0 / 240.0
const PEG_CLEARANCE: float = 0.252
const POCKET_WIDTH: float = 5.2 / 7.0
# Several physically simulated launches per result; no gameplay RNG is used.
const LAUNCHES: Array = [[10, 37, 46], [9, 51, 53], [17, 22, 44], [5, 6, 15], [146, 184, 209], [16, 47, 139], [328, 493, 510]]
static var _cache: Dictionary = {}


static func peg_centres() -> Array[Vector2]:
	var pegs: Array[Vector2] = []
	for row: int in 6:
		for column: int in (6 if row % 2 == 0 else 5):
			pegs.append(Vector2(-2.30 + column * 0.83 + (0.415 if row % 2 else 0.0), -0.96 + row * 0.66))
	return pegs


static func hole_position(hole: int) -> Vector3:
	return Vector3(-2.88 + (clampi(hole, 0, 6) + 0.5) * POCKET_WIDTH, 0.3275 + RADIUS, 3.62)


static func arch_position(progress: float) -> Vector3:
	var u: float = clampf(progress, 0.0, 1.0)
	return Vector3(cos(-PI * u) * ARCH_RADIUS, lerpf(PARK.y, FIELD_Y, u), ARCH_Z + sin(-PI * u) * ARCH_RADIUS)


static func trajectory(hole: int, bounces: Array) -> Dictionary:
	var variant: int = 0
	for bit: int in bounces:
		variant = (variant * 2 + bit) % 3
	var key: int = hole * 3 + variant
	if _cache.has(key):
		return _cache[key]
	for offset: int in 3:
		var launch: int = LAUNCHES[hole][(variant + offset) % 3]
		var result: Dictionary = simulate(launch)
		if int(result.get("hole", -1)) == hole:
			_cache[key] = result
			return result
	# Validate the result on the running platform, rather than assuming chaotic
	# float arithmetic takes an identical branch on every CPU/browser.
	for launch: int in 2048:
		var result: Dictionary = simulate(launch)
		if int(result.get("hole", -1)) == hole and int(result["hits"]) >= 3 and float(result["duration"]) < 3.0:
			_cache[key] = result
			return result
	assert(false, "No physical pinball launch reaches the required pocket")
	return {}


static func simulate(launch: int) -> Dictionary:
	var position := Vector2(-ARCH_RADIUS, ARCH_Z)
	var velocity := Vector2(float((launch * 37) % 127) / 126.0 * 8.0 - 1.0, 1.4 + float((launch * 23) % 31) / 30.0 * 1.2)
	var height: float = FIELD_Y
	var vertical_speed: float = 0.0
	var pocket: int = -1
	var points := PackedVector3Array([Vector3(position.x, height, position.y)])
	var impacts := PackedFloat32Array()
	var pegs: Array[Vector2] = peg_centres()
	for step: int in 1440:
		if pocket < 0:
			velocity.y += 14.0 * STEP
			velocity.x *= exp(-0.072 * STEP)
		else:
			velocity *= exp(-6.0 * STEP)
		position += velocity * STEP
		if position.x < -2.88:
			position.x = -2.88
			velocity.x = absf(velocity.x) * 0.6
		if position.x > 2.32:
			position.x = 2.32
			velocity.x = -absf(velocity.x) * 0.6
		if pocket < 0:
			for peg: Vector2 in pegs:
				var offset: Vector2 = position - peg
				var distance: float = offset.length()
				if distance < PEG_CLEARANCE:
					var normal: Vector2 = offset / maxf(distance, 0.0001)
					position = peg + normal * PEG_CLEARANCE
					var inward: float = velocity.dot(normal)
					if inward < 0.0:
						velocity -= 1.52 * inward * normal
						impacts.append((step + 1) * STEP)
			# Rounded divider tips catch a ball that lands on the pocket edge.
			for divider: int in 8:
				var tip := Vector2(-2.88 + divider * POCKET_WIDTH, 3.03)
				var offset: Vector2 = position - tip
				var distance: float = offset.length()
				if distance < 0.157:
					var normal: Vector2 = offset / maxf(distance, 0.0001)
					position = tip + normal * 0.157
					var inward: float = velocity.dot(normal)
					if inward < 0.0:
						velocity -= 1.45 * inward * normal
			if position.y >= 3.12:
				pocket = clampi(int((position.x + 2.88) / POCKET_WIDTH), 0, 6)
		else:
			var left: float = -2.88 + pocket * POCKET_WIDTH + 0.157
			var right: float = left + POCKET_WIDTH - 0.314
			if position.x < left:
				position.x = left
				velocity.x = absf(velocity.x) * 0.38
			if position.x > right:
				position.x = right
				velocity.x = -absf(velocity.x) * 0.38
			if position.y > 3.82:
				position.y = 3.82
				velocity.y = -absf(velocity.y) * 0.28
			if position.y < 3.14:
				position.y = 3.14
				velocity.y = absf(velocity.y) * 0.28
			vertical_speed -= 18.0 * STEP
			height += vertical_speed * STEP
			var floor_y: float = hole_position(pocket).y
			if height < floor_y:
				height = floor_y
				vertical_speed = absf(vertical_speed) * 0.28
		points.append(Vector3(position.x, height, position.y))
		if pocket >= 0 and velocity.length() < 0.08 and absf(vertical_speed) < 0.06:
			return {"hole": pocket, "positions": points, "impacts": impacts, "hits": impacts.size(), "duration": (step + 1) * STEP, "launch": launch}
	return {}


static func sample(positions: PackedVector3Array, seconds: float) -> Vector3:
	var frame: float = clampf(seconds / STEP, 0.0, float(positions.size() - 1))
	var index: int = floori(frame)
	return positions[index].lerp(positions[mini(index + 1, positions.size() - 1)], frame - index)
