class_name CaptureCutin
extends Control

signal impact
signal completed

const DURATION: float = 0.96
const SWING_AT: float = 0.04
const IMPACT_AT: float = 0.14
const HOLD_UNTIL: float = 0.26
const RECOIL_UNTIL: float = 0.72
const MAX_PAIRS: int = 3
const INK_PATH: String = "res://assets/fx/capture/ink_impact.png"
const SLASH_PATH: String = "res://assets/fx/capture/scythe_slash.png"

var active: bool = false
var attacker_avatar: StringName = &""
var defender_avatar: StringName = &""
var elapsed: float = 0.0
var _attack: Texture2D = null
var _hit: Texture2D = null
var _ink: Texture2D = null
var _slash: Texture2D = null
var _queue: Array[Dictionary] = []
var _keys: Dictionary = {}
var _current_key: String = ""
var _hit_fired: bool = false
var _swing_fired: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(INK_PATH):
		_ink = load(INK_PATH) as Texture2D
	if ResourceLoader.exists(SLASH_PATH):
		_slash = load(SLASH_PATH) as Texture2D
	visible = false
	set_process(false)


## All timing belongs to this visual layer; the authoritative simulation and RNG are untouched.
func enqueue(attacker: StringName, defender: StringName, attacking_player: int, defending_player: int) -> bool:
	if attacking_player == defending_player:
		return false
	var key: String = "%d:%d" % [attacking_player, defending_player]
	if _keys.has(key) or _keys.size() >= MAX_PAIRS:
		return false
	_keys[key] = true
	_queue.append({"attack": attacker, "hit": defender, "key": key})
	if not active:
		_start_next()
	return true


func busy() -> bool:
	return active or not _queue.is_empty()


func cancel() -> void:
	_queue.clear()
	_keys.clear()
	_current_key = ""
	active = false
	visible = false
	elapsed = 0.0
	_attack = null
	_hit = null
	set_process(false)
	queue_redraw()


func _start_next() -> void:
	if _queue.is_empty():
		active = false
		visible = false
		set_process(false)
		completed.emit()
		return
	var pair: Dictionary = _queue.pop_front()
	_current_key = pair["key"]
	attacker_avatar = AvatarCatalog.sanitize(pair["attack"])
	defender_avatar = AvatarCatalog.sanitize(pair["hit"])
	_attack = AvatarCombatArt.texture(attacker_avatar, &"attack")
	_hit = AvatarCombatArt.texture(defender_avatar, &"hit")
	elapsed = 0.0
	_hit_fired = false
	_swing_fired = false
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if not _swing_fired and elapsed >= SWING_AT:
		_swing_fired = true
		Sfx.play(&"dash", -9.0, 0.01)
	if not _hit_fired and elapsed >= IMPACT_AT:
		_hit_fired = true
		Sfx.play(&"slam", -1.0, 0.015)
		impact.emit()
	if elapsed >= DURATION:
		_keys.erase(_current_key)
		_start_next()
	queue_redraw()


static func ramp(time: float, start: float, end: float) -> float:
	var value: float = clampf((time - start) / (end - start), 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)


## The exact same motion sample drives drawing and the hold/slow-motion regression check.
## Values are in sprite-width units. Camera zoom also stops during the impact hold.
static func motion_at(time: float) -> Dictionary:
	if time < IMPACT_AT:
		var strike: float = ramp(time, SWING_AT, IMPACT_AT)
		return {"attack": -0.20 * (1.0 - strike * strike), "hit": 0.0, "angle": 0.0, "zoom": lerpf(1.0, 1.075, ramp(time, 0.0, IMPACT_AT))}
	if time < HOLD_UNTIL:
		return {"attack": 0.0, "hit": 0.0, "angle": 0.0, "zoom": 1.075}
	var slow: float = ramp(time, HOLD_UNTIL, RECOIL_UNTIL)
	var release: float = ramp(time, RECOIL_UNTIL, DURATION)
	return {"attack": -0.012 * slow - 0.025 * release, "hit": 0.075 * slow + 0.16 * release, "angle": 0.04 * slow + 0.05 * release, "zoom": 1.075 + 0.018 * slow - 0.035 * release}


static func impact_kind(avatar: StringName) -> StringName:
	match avatar:
		&"avatar_02", &"avatar_04", &"avatar_06": return &"pierce"
		&"avatar_05": return &"slash"
		&"avatar_07": return &"magic"
	return &"blunt"


static func impact_color(avatar: StringName) -> Color:
	match avatar:
		&"avatar_03", &"avatar_05": return Color("a3eaff")
		&"avatar_06": return Color("c3dcff")
		&"avatar_07": return Color("ff9aa8")
		&"avatar_08": return Color("bde6a1")
	return Color("ffe1a6")


## Weapon trails share the actors' impact hold, then finish in slow motion.
static func trail_time(time: float) -> float:
	if time < IMPACT_AT:
		return time
	return IMPACT_AT + maxf(0.0, time - HOLD_UNTIL) * 0.24


static func uses_shock_ring(avatar: StringName) -> bool:
	return impact_kind(avatar) in [&"blunt", &"magic"]


func _draw() -> void:
	if not active:
		return
	var fade: float = ramp(elapsed, 0.0, 0.045) * (1.0 - ramp(elapsed, RECOIL_UNTIL, DURATION))
	var motion: Dictionary = motion_at(elapsed)
	var color: Color = impact_color(attacker_avatar)
	var side: float = minf(size.x * 0.39, size.y * 0.70) * float(motion["zoom"])
	var shake := Vector2.ZERO
	var beat: float = elapsed - IMPACT_AT
	if beat >= 0.0 and beat < 0.13:
		var strength: float = pow(1.0 - beat / 0.13, 2.0)
		shake = Vector2(sin(beat * 145.0), cos(beat * 175.0) * 0.55) * 9.0 * strength
	var target := Vector2(size.x * 0.53, size.y * 0.43) + shake
	_draw_backdrop(target, side, color, fade)
	_draw_ink(target, side, color, fade)
	_draw_weapon_trail(target, side, color, fade)
	var gap: float = size.x * 0.10 * float(motion["zoom"])
	var attack_target := target - Vector2(gap * 0.5, 0)
	var hit_target := target + Vector2(gap * 0.5, 0)
	var attack_at := attack_target + Vector2(side * float(motion["attack"]), 0)
	var hit_at := hit_target + Vector2(side * float(motion["hit"]), 0)
	var trail: float = ramp(elapsed, SWING_AT, IMPACT_AT) * (1.0 - ramp(elapsed, IMPACT_AT, IMPACT_AT + 0.05))
	if trail > 0.0:
		_draw_actor(_attack, attacker_avatar, &"attack", attack_at - Vector2(side * 0.06, 0), side, 0.0, fade * trail * 0.085)
	_draw_actor(_hit, defender_avatar, &"hit", hit_at, side * 0.93, float(motion["angle"]), fade)
	_draw_actor(_attack, attacker_avatar, &"attack", attack_at, side, 0.0, fade)
	_draw_contact(target, side, color, fade)


func _draw_backdrop(target: Vector2, side: float, color: Color, fade: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.008, 0.02, 0.86 * fade))
	var bar: float = size.y * 0.045 * fade
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, bar)), Color(0, 0, 0, 0.95 * fade))
	draw_rect(Rect2(Vector2(0, size.y - bar), Vector2(size.x, bar)), Color(0, 0, 0, 0.95 * fade))
	# A restrained diagonal dark red ink field, behind both characters.
	draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.72), Vector2(size.x, size.y * 0.12), Vector2(size.x, size.y * 0.42), Vector2(0, size.y * 0.94)]), Color(0.12, 0.025, 0.045, 0.45 * fade))
	var ink_time: float = minf(elapsed, IMPACT_AT) + maxf(0.0, minf(elapsed, RECOIL_UNTIL) - HOLD_UNTIL) * 0.14
	var intensity: float = (0.16 + 0.12 * ramp(elapsed, SWING_AT, IMPACT_AT)) * fade
	for index: int in 22:
		var angle: float = index * TAU / 22.0 + sin(index * 3.7) * 0.055
		var direction := Vector2.from_angle(angle)
		var normal := direction.orthogonal()
		var inner: float = side * (0.58 + 0.10 * sin(index * 4.3 + ink_time * 8.0))
		var outer: float = maxf(size.x, size.y) * 1.1
		var width: float = 1.5 + float(index % 4) * 0.8
		var ray_color := Color(color.r, color.g, color.b, intensity * (0.7 if index % 3 == 0 else 0.35))
		draw_colored_polygon(PackedVector2Array([target + direction * inner, target + direction * outer + normal * width, target + direction * outer - normal * width]), ray_color)


func _draw_ink(target: Vector2, side: float, color: Color, fade: float) -> void:
	if elapsed < IMPACT_AT or _ink == null or not uses_shock_ring(attacker_avatar):
		return
	var age: float = elapsed - IMPACT_AT
	var opacity: float = (1.0 - ramp(elapsed, HOLD_UNTIL + 0.10, RECOIL_UNTIL)) * fade
	var extent: float = side * lerpf(0.62, 1.0, ramp(age, 0.0, 0.055)) * (1.0 + 0.10 * ramp(elapsed, HOLD_UNTIL, RECOIL_UNTIL))
	var center := target + Vector2(side * 0.22, -side * 0.025)
	var rect := Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)
	draw_texture_rect(_ink, rect.grow(side * 0.025), false, Color(0.10, 0.01, 0.035, opacity * 0.9))
	draw_texture_rect(_ink, rect, false, Color(color.r, color.g, color.b, opacity * 0.78))
	# Separate small fragments drift at the same slow visual pace; no RNG calls.
	var drift: float = ramp(elapsed, IMPACT_AT, HOLD_UNTIL) * 0.025 + ramp(elapsed, HOLD_UNTIL, RECOIL_UNTIL) * 0.08
	for index: int in 9:
		var angle: float = -1.25 + index * 0.30
		var at := target + Vector2.from_angle(angle) * side * (0.14 + drift + float(index % 3) * 0.035)
		var radius: float = side * (0.004 + float(index % 3) * 0.002)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-radius * 1.5, 0), at + Vector2(0, -radius), at + Vector2(radius * 2.0, radius * 0.4)]), Color(color.r, color.g, color.b, opacity * 0.75))


func _draw_weapon_trail(target: Vector2, side: float, color: Color, fade: float) -> void:
	var kind: StringName = impact_kind(attacker_avatar)
	if elapsed < SWING_AT or (kind != &"slash" and kind != &"pierce"):
		return
	var time: float = trail_time(elapsed)
	var strike: float = ramp(time, SWING_AT, IMPACT_AT)
	var opacity: float = fade * (1.0 - ramp(time, IMPACT_AT + 0.025, IMPACT_AT + 0.085))
	if kind == &"slash":
		if _slash == null:
			return
		# Reveal the painted crescent from top to bottom along the scythe blade.
		# Keep the hollow interior and both faces unobscured, behind the actors.
		var extent := Vector2(side * 0.72, side * 0.76)
		var center := target + Vector2(-side * 0.22, side * 0.04)
		var reveal: float = lerpf(0.08, 1.0, strike)
		var rect := Rect2(center - extent * 0.5, Vector2(extent.x, extent.y * reveal))
		var source := Rect2(Vector2.ZERO, Vector2(_slash.get_width(), _slash.get_height() * reveal))
		draw_texture_rect_region(_slash, rect, source, Color(color.r, color.g, color.b, opacity * strike * 0.92))
	else:
		# Arrows, slingshot shots and Daya's thrust follow a narrow rightward line.
		var direction := Vector2(1.0, -0.025).normalized()
		var normal := direction.orthogonal()
		var tip := target + direction * side * lerpf(-0.24, 0.24, strike)
		for index: int in 3:
			var offset: float = float(index - 1) * side * 0.013
			var tail := tip - direction * side * (0.45 - absf(float(index - 1)) * 0.12) + normal * offset
			var width: float = side * (0.005 if index == 1 else 0.0018)
			var tint := Color(color.r, color.g, color.b, opacity * strike * (0.9 if index == 1 else 0.45))
			draw_colored_polygon(PackedVector2Array([tail, tip - direction * side * 0.08 + normal * (offset + width), tip, tip - direction * side * 0.08 + normal * (offset - width)]), tint)


func _draw_contact(target: Vector2, side: float, color: Color, fade: float) -> void:
	if elapsed < IMPACT_AT:
		return
	var age: float = elapsed - IMPACT_AT
	var opacity: float = (1.0 - ramp(elapsed, HOLD_UNTIL + 0.06, RECOIL_UNTIL)) * fade
	var radius: float = side * (0.055 + 0.04 * ramp(age, 0.0, 0.12) + 0.018 * ramp(elapsed, HOLD_UNTIL, RECOIL_UNTIL))
	var light := Color(color.r, color.g, color.b, opacity * 0.8)
	match impact_kind(attacker_avatar):
		&"slash":
			pass # The painted blade sweep supplies the contact accent too.
		&"pierce":
			var tip := target + Vector2(radius * 1.4, -radius * 0.5)
			draw_colored_polygon(PackedVector2Array([target - Vector2(radius, -radius * 0.4), target + Vector2(-radius * 0.15, -radius * 0.15), tip, target + Vector2(0, radius * 0.15)]), light)
		&"magic":
			for index: int in 4:
				var at := target + Vector2.from_angle(index * PI * 0.5 + 0.3) * radius
				var r: float = side * 0.012
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r * 1.7), at + Vector2(r, 0), at + Vector2(0, r * 1.7), at - Vector2(r, 0)]), light)
		_:
			draw_arc(target, radius, -2.0, 2.0, 28, light, 3.5, true)
			draw_arc(target - Vector2(side * 0.018, 0), radius * 0.72, -1.6, 1.6, 24, Color(1, 1, 1, opacity * 0.7), 1.5, true)
	var flash: float = (1.0 - ramp(age, 0.0, 0.035)) * 0.12
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.94, 0.82, flash))


func _actor_size(texture: Texture2D, avatar: StringName, pose: StringName, side: float) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var extent: Vector2 = texture.get_size()
	return extent * (side * AvatarCombatArt.pose_scale(avatar, pose) / maxf(extent.x, extent.y))


func _draw_actor(texture: Texture2D, avatar: StringName, pose: StringName, target: Vector2, side: float, angle: float, opacity: float) -> void:
	if texture == null:
		return
	var drawn: Vector2 = _actor_size(texture, avatar, pose, side)
	var contact: Vector2 = AvatarCombatArt.contact(avatar, pose) * drawn
	draw_set_transform(target, angle)
	draw_texture_rect(texture, Rect2(-contact, drawn), false, Color(1, 1, 1, opacity))
	draw_set_transform(Vector2.ZERO)
