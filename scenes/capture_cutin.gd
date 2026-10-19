class_name CaptureCutin
extends Control

signal impact
signal completed

const DURATION: float = 0.5
const IMPACT_AT: float = 0.11
const HOLD_UNTIL: float = 0.20
const RECOIL_UNTIL: float = 0.36
const MAX_PAIRS: int = 3

var active: bool = false
var attacker_avatar: StringName = &""
var defender_avatar: StringName = &""
var elapsed: float = 0.0
var _attack: Texture2D = null
var _hit: Texture2D = null
var _queue: Array[Dictionary] = []
var _keys: Dictionary = {}
var _current_key: String = ""
var _hit_fired: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


## De-duplicate stacks/chain captures of the same players during one sequence.
## No await, game-state changes, RNG consumption or global time-scale changes.
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
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if not _hit_fired and elapsed >= IMPACT_AT:
		_hit_fired = true
		Sfx.play(&"slam", -2.0, 0.025)
		impact.emit()
	if elapsed >= DURATION:
		_keys.erase(_current_key)
		_start_next()
	queue_redraw()


static func ramp(time: float, start: float, end: float) -> float:
	var value: float = clampf((time - start) / (end - start), 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)


func _draw() -> void:
	if not active:
		return
	var fade: float = ramp(elapsed, 0.0, 0.045) * (1.0 - ramp(elapsed, RECOIL_UNTIL, DURATION))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.01, 0.025, 0.76 * fade))
	# Restrained vignette; the existing board stays visible underneath.
	for edge: int in 4:
		var width: float = size.x * 0.025
		var opacity: float = (0.12 - edge * 0.025) * fade
		draw_rect(Rect2(Vector2(edge * width, 0), Vector2(width, size.y)), Color(0, 0, 0, opacity))
		draw_rect(Rect2(Vector2(size.x - (edge + 1) * width, 0), Vector2(width, size.y)), Color(0, 0, 0, opacity))
	var shake: Vector2 = Vector2.ZERO
	if elapsed >= IMPACT_AT and elapsed < HOLD_UNTIL:
		var beat: float = elapsed - IMPACT_AT
		shake = Vector2(sin(beat * 170.0), sin(beat * 130.0)) * 5.0 * (1.0 - beat / (HOLD_UNTIL - IMPACT_AT))
	var target: Vector2 = Vector2(size.x * 0.53, size.y * 0.40) + shake
	var side: float = minf(size.x * 0.41, size.y * 0.74)
	var gap: float = size.x * 0.10
	# Match the horizontal strike height while leaving room between fist and face.
	var attack_target := target - Vector2(gap * 0.5, 0)
	var hit_target := target + Vector2(gap * 0.5, 0)
	var lunge: float = lerpf(-side * 0.08, 0.0, ramp(elapsed, 0.0, IMPACT_AT))
	var recoil: float = ramp(elapsed, HOLD_UNTIL, RECOIL_UNTIL)
	_draw_actor(_hit, defender_avatar, &"hit", hit_target + Vector2(side * 0.08 * recoil, 0), side * 0.93, 0.04 * recoil, fade)
	_draw_actor(_attack, attacker_avatar, &"attack", attack_target + Vector2(lunge, 0), side, 0.0, fade)
	# Rendered separately from either transparent character image.
	var spark_alpha: float = (1.0 - ramp(elapsed, 0.15, 0.225)) if elapsed >= IMPACT_AT else 0.0
	if spark_alpha > 0.0:
		var points := PackedVector2Array()
		for i: int in 16:
			var radius: float = side * (0.055 if i % 2 == 0 else 0.016)
			points.append(target + Vector2.from_angle(i * TAU / 16.0) * radius)
		draw_colored_polygon(points, Color(1.0, 0.92, 0.65, spark_alpha))
		var flash: float = (1.0 - ramp(elapsed, IMPACT_AT, IMPACT_AT + 0.035)) * 0.08
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.90, 0.72, flash))


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
