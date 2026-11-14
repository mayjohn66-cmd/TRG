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
const STRIKE_PATH: String = "res://assets/fx/capture/singular_strike.png"
const MOTION_PATH: String = "res://assets/fx/capture/motion_brush_v01.png"
const PIERCE_PATH: String = "res://assets/fx/capture/pierce_trail_v01.png"
const MAGIC_PATH: String = "res://assets/fx/capture/magic_contact_v01.png"

var active: bool = false
var attacker_avatar: StringName = &""
var defender_avatar: StringName = &""
var elapsed: float = 0.0
## 재생 빠르기 (1.0 = DURATION초). AI끼리의 처치는 터보 AI 턴에서 빠르게 재생한다.
var speed: float = 1.0
var _attack: Texture2D = null
var _hit: Texture2D = null
var _ink: Texture2D = null
var _slash: Texture2D = null
var _strike: Texture2D = null
var _motion_brush: Texture2D = null
var _pierce: Texture2D = null
var _magic: Texture2D = null
var _strike_region := Rect2()
var _queue: Array[Dictionary] = []
var _keys: Dictionary = {}
var _current_key: String = ""
var _hit_fired: bool = false
var _swing_fired: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink = TextureCache.fetch(INK_PATH)
	_slash = TextureCache.fetch(SLASH_PATH)
	_motion_brush = TextureCache.fetch(MOTION_PATH)
	_pierce = TextureCache.fetch(PIERCE_PATH)
	_magic = TextureCache.fetch(MAGIC_PATH)
	var strike_art: Dictionary = PawnArt.load_sprite([STRIKE_PATH])
	if not strike_art.is_empty():
		_strike = strike_art.texture
		_strike_region = strike_art.region
	visible = false
	set_process(false)


## All timing belongs to this visual layer; the authoritative simulation and RNG are untouched.
func enqueue(attacker: StringName, defender: StringName, attacking_player: int, defending_player: int, play_speed: float = 1.0) -> bool:
	if attacking_player == defending_player:
		return false
	var key: String = "%d:%d" % [attacking_player, defending_player]
	if _keys.has(key) or _keys.size() >= MAX_PAIRS:
		return false
	_keys[key] = true
	_queue.append({"attack": attacker, "hit": defender, "key": key, "speed": maxf(play_speed, 0.1)})
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
	speed = float(pair.get("speed", 1.0))
	_hit_fired = false
	_swing_fired = false
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta * speed
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


## The critical lettering snaps on at contact and shares the frozen impact pose.
static func caption_at(time: float) -> Dictionary:
	if time < IMPACT_AT or time >= DURATION:
		return {"alpha": 0.0, "scale": 1.08}
	return {"alpha": 1.0 - ramp(time, RECOIL_UNTIL, DURATION), "scale": 1.08 - 0.08 * ramp(time, HOLD_UNTIL, HOLD_UNTIL + 0.08)}


static func caption_rect(viewport: Vector2, aspect: float, scale_factor: float) -> Rect2:
	var maximum := Vector2(viewport.x * 0.82, viewport.y * 0.15)
	var extent := Vector2(aspect, 1.0) * minf(maximum.x / aspect, maximum.y) * scale_factor
	var center := Vector2(viewport.x * 0.5, viewport.y * 0.115)
	return Rect2(center - extent * 0.5, extent)


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
	_draw_strike_caption()


func _draw_strike_caption() -> void:
	if _strike == null or not _strike_region.has_area():
		return
	var caption: Dictionary = caption_at(elapsed)
	if float(caption["alpha"]) <= 0.0:
		return
	var rect: Rect2 = caption_rect(size, _strike_region.size.x / _strike_region.size.y, float(caption["scale"]))
	draw_texture_rect_region(_strike, rect, _strike_region, Color(1, 1, 1, float(caption["alpha"])))


func _draw_backdrop(target: Vector2, side: float, color: Color, fade: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.008, 0.02, 0.86 * fade))
	var bar: float = size.y * 0.045 * fade
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, bar)), Color(0, 0, 0, 0.95 * fade))
	draw_rect(Rect2(Vector2(0, size.y - bar), Vector2(size.x, bar)), Color(0, 0, 0, 0.95 * fade))
	if _motion_brush != null:
		# Loose fibrous motion paint at the edges; the middle stays empty for faces.
		var time := trail_time(elapsed)
		var drift := Vector2(-size.x, size.y) * time * 0.035
		var rect := Rect2(Vector2.ZERO + drift, size).grow(side * 0.03)
		draw_texture_rect(_motion_brush, rect.grow(side * 0.01), false, Color(0.4, 0.07, 0.12, fade * 0.24))
		draw_texture_rect(_motion_brush, rect, false, Color(color, fade * 0.22))


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
	# The original painting already contains torn flecks; no triangular confetti.


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
		if _pierce == null:
			return
		var tip := target + Vector2(side * lerpf(-0.24, 0.24, strike), -side * 0.006)
		var extent := Vector2(side * 0.60, side * 0.40)
		draw_set_transform(tip, -0.025)
		draw_texture_rect(_pierce, Rect2(-extent * Vector2(0.86, 0.5), extent), false, Color(color, opacity * strike * 0.88))
		draw_set_transform(Vector2.ZERO)


func _draw_contact(target: Vector2, side: float, color: Color, fade: float) -> void:
	if elapsed < IMPACT_AT:
		return
	var age: float = elapsed - IMPACT_AT
	var opacity: float = (1.0 - ramp(elapsed, HOLD_UNTIL + 0.06, RECOIL_UNTIL)) * fade
	var slow := ramp(elapsed, HOLD_UNTIL, RECOIL_UNTIL)
	match impact_kind(attacker_avatar):
		&"slash":
			pass # The painted blade sweep supplies the contact accent too.
		&"pierce":
			if _pierce != null:
				var extent := Vector2(side * 0.27, side * 0.22) * (1 + slow * 0.2)
				draw_set_transform(target, -0.12)
				draw_texture_rect(_pierce, Rect2(-extent * Vector2(0.7, 0.5), extent), false, Color(color, opacity * 0.7))
		&"magic":
			if _magic != null:
				var extent := Vector2.ONE * side * (0.36 + slow * 0.08)
				draw_set_transform(target, slow * 0.16)
				draw_texture_rect(_magic, Rect2(-extent / 2, extent), false, Color(color, opacity * 0.82))
		_:
			if _ink != null:
				var extent := Vector2.ONE * side * (0.22 + slow * 0.06)
				draw_texture_rect(_ink, Rect2(target - extent / 2, extent), false, Color(color, opacity * 0.78))
	draw_set_transform(Vector2.ZERO)
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
