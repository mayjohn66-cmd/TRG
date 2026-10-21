## Integer fixed-point tabletop physics. No scene-tree physics, clock or RNG.
## The authority and the visible replay run the identical 120 Hz simulation.
class_name BottleCapPhysics
extends RefCounted

const HZ := 120
const SCALE := 1000
const RADIUS := 22000
const HEIGHT := 252000
const EDGE := 600000
const START := Vector2i(72000, 126000)
const DRAG := 30  # Constant sliding friction, in position units / tick².
const SHOT_BASE := 10000
const POWER_MAX := 1150
const AIM_MAX := 24
const MAX_TICKS := 420

var caps: Array[Dictionary] = []
var events: Array[Dictionary] = []
var ticks := 0
var contacts := 0

func _init() -> void:
	for index: int in 2:
		caps.append({"pos": START, "vel": Vector2i.ZERO, "active": false, "out": false, "angle": 0, "spin": 0, "fall_tick": -1})

static func encode(power: int, aim: int = 0) -> int:
	return SHOT_BASE + (clampi(aim, -AIM_MAX, AIM_MAX) + AIM_MAX) * (POWER_MAX + 1) + clampi(power, 0, POWER_MAX)

static func valid(value: int) -> bool:
	return (value >= 0 and value <= POWER_MAX) or (value >= SHOT_BASE and value < SHOT_BASE + (AIM_MAX * 2 + 1) * (POWER_MAX + 1))

static func decode(value: int) -> Vector2i:
	if value < SHOT_BASE:
		return Vector2i(clampi(value, 0, POWER_MAX), 0)
	var packed := value - SHOT_BASE
	@warning_ignore("integer_division")
	return Vector2i(packed % (POWER_MAX + 1), packed / (POWER_MAX + 1) - AIM_MAX)

## Floor integer square root: all game arithmetic stays identical across native/web.
static func isqrt(value: int) -> int:
	if value <= 0:
		return 0
	var x := value
	@warning_ignore("integer_division")
	var y: int = (x + 1) / 2
	while y < x:
		x = y
		@warning_ignore("integer_division")
		y = (x + value / x) / 2
	return x

@warning_ignore("integer_division")
static func div_int(a: int, b: int) -> int:
	return a / b

func shoot(index: int, value: int) -> void:
	var shot := decode(value)
	var distance := div_int((EDGE - START.x) * shot.x, 1000)
	var speed := maxi(0, isqrt(2 * DRAG * distance + div_int(DRAG * DRAG, 4)) - div_int(DRAG, 2))
	var slope := shot.y * 18
	var vx := div_int(speed * 1000, isqrt(1000000 + slope * slope))
	var body: Dictionary = caps[index]
	body.merge({"pos": START, "vel": Vector2i(vx, div_int(vx * slope, 1000)), "active": true, "out": false,
		"spin": 1100 + div_int(shot.x, 45) * 100 + shot.y * 70, "angle": index * 37000, "fall_tick": -1}, true)
	events.clear()

func moving() -> bool:
	for cap: Dictionary in caps:
		if bool(cap.active) and not bool(cap.out) and cap.vel != Vector2i.ZERO:
			return true
	return false

func _fall(index: int) -> void:
	var body: Dictionary = caps[index]
	if not bool(body.out) and (body.pos as Vector2i).x > EDGE:
		body.out = true
		body.fall_tick = ticks
		body.vel = Vector2i.ZERO
		events.append({"kind": &"fall", "index": index, "pos": body.pos})

func step() -> void:
	ticks += 1
	events.clear()
	for index: int in 2:
		var body: Dictionary = caps[index]
		if not bool(body.active) or bool(body.out):
			continue
		var p: Vector2i = body.pos
		var v: Vector2i = body.vel
		p += v
		if p.y < RADIUS or p.y > HEIGHT - RADIUS:
			p.y = clampi(p.y, RADIUS, HEIGHT - RADIUS)
			v.y = -div_int(v.y * 68, 100)
			v.x = div_int(v.x * 97, 100)
			body.spin = int(body.spin) + div_int(v.x, 180) * 100
			events.append({"kind": &"rail", "index": index, "pos": p})
		if p.x < RADIUS:
			p.x = RADIUS
			v.x = -div_int(v.x * 60, 100)
		var speed := isqrt(v.x * v.x + v.y * v.y)
		if speed <= DRAG:
			v = Vector2i.ZERO
			body.spin = 0
		else:
			v = Vector2i(div_int(v.x * (speed - DRAG), speed), div_int(v.y * (speed - DRAG), speed))
		body.pos = p
		body.vel = v
		body.angle = int(body.angle) + int(body.spin)
		body.spin = div_int(int(body.spin) * 990, 1000)
		_fall(index)
	_collide()
	for index: int in 2:
		_fall(index)

func _collide() -> void:
	var a: Dictionary = caps[0]
	var b: Dictionary = caps[1]
	if not bool(a.active) or not bool(b.active) or bool(a.out) or bool(b.out):
		return
	var delta: Vector2i = b.pos - a.pos
	var square := delta.x * delta.x + delta.y * delta.y
	if square >= RADIUS * RADIUS * 4:
		return
	if square == 0:
		delta = Vector2i(1, 0)
		square = 1
	var distance := maxi(1, isqrt(square))
	var overlap := RADIUS * 2 - distance + 2
	var correction := Vector2i(div_int(delta.x * overlap, distance * 2), div_int(delta.y * overlap, distance * 2))
	a.pos = (a.pos as Vector2i) - correction
	b.pos = (b.pos as Vector2i) + correction
	var relative: Vector2i = b.vel - a.vel
	var dot := relative.x * delta.x + relative.y * delta.y
	if dot >= 0:
		return
	# Equal-mass impulse, restitution 0.82. Glancing impact also transfers spin.
	var impulse := Vector2i(div_int(-dot * 182 * delta.x, 200 * square), div_int(-dot * 182 * delta.y, 200 * square))
	a.vel = (a.vel as Vector2i) - impulse
	b.vel = (b.vel as Vector2i) + impulse
	var tangent := div_int(relative.x * delta.y - relative.y * delta.x, distance * 80) * 100
	a.spin = int(a.spin) + tangent
	b.spin = int(b.spin) - tangent
	contacts += 1
	events.append({"kind": &"contact", "pos": (a.pos as Vector2i) + div_vector(delta, 2), "strength": isqrt(impulse.x * impulse.x + impulse.y * impulse.y)})

static func div_vector(v: Vector2i, denominator: int) -> Vector2i:
	return Vector2i(div_int(v.x, denominator), div_int(v.y, denominator))

func settle() -> void:
	for tick: int in MAX_TICKS:
		if not moving():
			break
		step()

func result() -> Dictionary:
	var a_out := bool(caps[0].out)
	var b_out := bool(caps[1].out)
	var winner := 0
	var cause: StringName = &"game"
	if a_out and b_out:
		cause = &"both_fell"
	elif a_out != b_out:
		winner = 1 if a_out else 0
		cause = &"fall"
	elif (caps[1].pos as Vector2i).x > (caps[0].pos as Vector2i).x:
		winner = 1
	return {"index": winner, "decided_by": cause}

static func simulate(first: int, second: int) -> BottleCapPhysics:
	var world := BottleCapPhysics.new()
	world.shoot(0, first)
	world.settle()
	world.shoot(1, second)
	world.settle()
	return world

func distance_text(index: int) -> String:
	if bool(caps[index].out):
		return "장외"
	return "절벽까지 %.1fcm" % (float(EDGE - (caps[index].pos as Vector2i).x) / float(SCALE * 10))
