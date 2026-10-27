## ACT_02 only. Reuse the approved revolver; no roulette, flag or gameplay RNG.
## The owning queue launches the real pawn at release, while muzzle smoke fades.
extends Node2D

const SHOT_AT := 0.58
const HIT_AT := 0.65
const RELEASE_AT := 0.74
const TOTAL_TIME := 1.12
const GOLD := Color("ffe3a1")
const FOCUS := preload("res://assets/fx/sniper_focus.gdshader")
const SMOKE := preload("res://assets/fx/bang_smoke.gdshader")
var elapsed := 0.0
var pace := 1.0
var target_id := -1
var fired := false
var hit_started := false
var released := false
var complete := false
var phase: StringName = &"aim"
var gun: ToyFlagGun3D
var _board_ref: WeakRef
var _view_ref: WeakRef
var _generation := 0
var _at := Vector2.ZERO
var _origin := Vector2.ZERO
var _muzzle := Vector2.ZERO
var _direction := Vector2.RIGHT
var _angle := 0.0
var _saved: Dictionary = {}
var _restored := false
var _veil: ColorRect
var _light: ShaderMaterial
var _smoke: ColorRect
var _smoke_material: ShaderMaterial

func play(board: MainBoard, shooter: int, target: int, speed: float) -> void:
	name = "BangStage"
	z_index = 35
	_board_ref = weakref(board)
	_generation = board._fx_generation
	pace = clampf(speed, 0.35, 2.0)
	target_id = target
	var view: Node2D = board._pawn_views.get(target)
	if not is_instance_valid(view):
		complete = true
		return
	board._kill_fx(view)
	_view_ref = weakref(view)
	_saved = {"scale": view.scale, "rotation": view.rotation, "tint": view.modulate, "z": view.z_index}
	# Convert both endpoints to board-local coordinates, including the pawn layer.
	_at = to_local(view.to_global(Vector2(0, -18)))
	var source := board._profile_center(shooter)
	_origin = to_local(source) if source.is_finite() else _at + Vector2(-260, 100)
	_direction = _origin.direction_to(_at)
	if _direction.is_zero_approx(): _direction = Vector2.RIGHT
	_origin += _direction * 86.0
	var frame := get_viewport_rect().size
	_origin = _origin.clamp(Vector2(130, 90), frame - Vector2(130, 90))
	if _origin.distance_to(_at) < 170:
		_origin = (_at - _direction * 230).clamp(Vector2(130, 90), frame - Vector2(130, 90))
	_direction = _origin.direction_to(_at)
	_angle = _direction.angle()
	_veil = ColorRect.new()
	_veil.size = frame
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.z_index = -2
	_light = ShaderMaterial.new()
	_light.shader = FOCUS
	_veil.material = _light
	add_child(_veil)
	gun = ToyFlagGun3D.new()
	gun.name = "BangRevolver"
	gun.custom_minimum_size = Vector2.ZERO
	gun.sound_enabled = false
	add_child(gun)
	gun.render_view.size = Vector2i(600, 360)
	gun.size = Vector2(240, 144)
	gun.pivot_offset = gun.size / 2
	gun.flip_h = _direction.x >= 0
	gun.show_side()
	gun.render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_smoke = ColorRect.new()
	_smoke.size = Vector2(130, 90)
	_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = SMOKE
	_smoke.material = _smoke_material
	add_child(_smoke)
	Sfx.play(&"toy_click", -8.0, 0.0)
	_update_pose()

func _process(delta: float) -> void:
	if _board_ref == null or complete: return
	var board: MainBoard = _board_ref.get_ref()
	if board == null or board._fx_generation != _generation:
		cancel()
		return
	# A first-use model upload must not skip the shot/hit beats on a slow frame.
	elapsed += minf(delta / pace, 0.05)
	phase = &"aim" if elapsed < SHOT_AT else (&"shot" if elapsed < HIT_AT else (&"impact" if elapsed < RELEASE_AT else &"release"))
	if elapsed >= SHOT_AT and not fired:
		fired = true
		Sfx.play(&"shot", -3.0, 0.0)
	if elapsed >= HIT_AT and not hit_started:
		hit_started = true
		board.screen_shake(4.0, 0.12 * pace)
	if not released:
		var view: Node2D = _view_ref.get_ref()
		if view != null and hit_started:
			var hold := sin(clampf((elapsed - HIT_AT) / (RELEASE_AT - HIT_AT), 0, 1) * PI)
			view.scale = (_saved.scale as Vector2) * Vector2(1 + 0.18 * hold, 1 - 0.14 * hold)
			view.modulate = (_saved.tint as Color).lerp(Color(2, 1.65, 1.15), hold * 0.75)
		if elapsed >= RELEASE_AT:
			_restore(false)
			released = true
	_update_pose()
	queue_redraw()
	if elapsed >= TOTAL_TIME:
		complete = true
		gun.stop_rendering()
		set_process(false)
		hide()

func _update_pose() -> void:
	var enter := smoothstep(0, 0.22, elapsed)
	var exit := 1 - smoothstep(0.82, TOTAL_TIME, elapsed)
	var recoil := exp(-maxf(elapsed - SHOT_AT, 0) * 20) if fired else 0.0
	var right := _direction.x >= 0
	gun.position = _origin - gun.size / 2 - _direction * (24 * (1 - enter) + 13 * recoil)
	gun.rotation = _angle + (0 if right else -PI) - (0.12 if right else -0.12) * recoil
	gun.modulate.a = enter * exit
	gun._hammer.rotation.z = -0.22 * smoothstep(0.15, 0.44, elapsed) * (1 - smoothstep(SHOT_AT, SHOT_AT + 0.03, elapsed))
	gun._trigger.rotation.z = 0.17 * smoothstep(0.44, SHOT_AT, elapsed) * (1 - smoothstep(SHOT_AT, SHOT_AT + 0.10, elapsed))
	# Project the actual model muzzle, rather than guessing an offset in the sprite.
	var pixel := gun._camera.unproject_position(gun._assembly.to_global(ToyFlagGun3D.MUZZLE))
	pixel *= gun.size / Vector2(gun.render_view.size)
	if gun.flip_h: pixel.x = gun.size.x - pixel.x
	if not fired: _muzzle = to_local(gun.get_global_transform() * pixel)
	_light.set_shader_parameter("frame_size", _veil.size)
	_light.set_shader_parameter("focus", get_global_transform() * _at)
	_light.set_shader_parameter("strength", enter * exit * 0.65)
	_smoke.position = _muzzle - Vector2(12, 45).rotated(_angle)
	_smoke.rotation = _angle
	_smoke.visible = fired
	_smoke_material.set_shader_parameter("age", maxf(elapsed - SHOT_AT, 0))

func _draw() -> void:
	if _view_ref == null: return
	var fade := smoothstep(0.10, 0.27, elapsed) * (1 - smoothstep(SHOT_AT, HIT_AT, elapsed))
	var radius := lerpf(48, 23, smoothstep(0.12, 0.48, elapsed))
	# Four small converging corners leave the character unobscured.
	for i: int in 4:
		var direction := Vector2.from_angle(PI / 4 + i * PI / 2)
		var corner := _at + direction * radius
		draw_line(corner, corner - Vector2(direction.x * 9, 0), Color(GOLD, fade), 2, true)
		draw_line(corner, corner - Vector2(0, direction.y * 9), Color(GOLD, fade), 2, true)
	if fired:
		var age := elapsed - SHOT_AT
		var flash := 1 - smoothstep(0.015, 0.10, age)
		var points := PackedVector2Array()
		for i: int in 12:
			var angle := i * TAU / 12
			var length := (28.0 if i % 2 == 0 else 10.0) * (1 - minf(age * 4, 0.5))
			points.append(_muzzle + Vector2(cos(angle) * 1.35, sin(angle)).rotated(_angle) * length)
		draw_colored_polygon(points, Color("ffbb57", flash * 0.8))
		draw_circle(_muzzle, 9 * flash, Color(1, 0.97, 0.79, flash))
		var flight := clampf(age / (HIT_AT - SHOT_AT), 0, 1)
		var head := _muzzle.lerp(_at, flight)
		var tail := _muzzle.lerp(_at, maxf(flight - 0.33, 0))
		var alpha := 1 - smoothstep(HIT_AT, HIT_AT + 0.045, elapsed)
		draw_line(tail, head, Color(1, 0.65, 0.2, alpha * 0.20), 9, true)
		draw_line(tail, head, Color(GOLD, alpha), 2.5, true)
	if hit_started:
		var age := elapsed - HIT_AT
		var alpha := 1 - smoothstep(0.025, 0.20, age)
		for i: int in 9:
			var direction := Vector2.from_angle(i * TAU / 9 + 0.2)
			var spread := 5 + age * 120
			draw_line(_at + direction * spread, _at + direction * (spread + 10 + (i % 3) * 5), Color(GOLD, alpha), 2, true)

func _restore(cancelled: bool) -> void:
	if _restored and not cancelled: return
	_restored = true
	var view: Node2D = _view_ref.get_ref() if _view_ref != null else null
	if view != null:
		view.scale = _saved.scale
		view.rotation = _saved.rotation
		view.modulate = _saved.tint
		view.z_index = _saved.z
	if cancelled and view != null:
		var board: MainBoard = _board_ref.get_ref() if _board_ref != null else null
		var pawn: PlayerPawn = board.state.get_pawn(target_id) if board != null else null
		if pawn != null:
			board._kill_fx(view)
			view.position = board._pawn_position(pawn)
			view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier == null

func cancel() -> void:
	_restore(true)
	complete = true
	if gun != null: gun.stop_rendering()
	queue_free()

func _exit_tree() -> void:
	if not complete: _restore(true)
