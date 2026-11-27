## 3D cookie reveal driven by the same presentation clock as the roll result.
class_name FortuneCookieView
extends Control

const SIZE := Vector2(420, 300)
const DROP_END := 0.40
const WOBBLE_END := 1.00
const CRACK_AT := 1.02
const UNFOLD_AT := 1.45
const REVEAL_AT := 1.95
const TOTAL_TIME := 2.60
const WHOLE: PackedScene = preload("res://assets/models/optimized/v4/fortune_cookie/fortune-cookie-whole.scn")
const BROKEN: PackedScene = preload("res://assets/models/optimized/v4/fortune_cookie/fortune-cookie-broken.scn")
const SLIP: PackedScene = preload("res://assets/models/optimized/v4/fortune_cookie/fortune-cookie-slip.scn")
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")
const CLOSED_SEAM := Vector3(0.0, 0.39, -0.83)
const LEFT_OPENING := Vector3(-1.38, 1.08, -0.38)
const RIGHT_OPENING := Vector3(1.38, 1.22, -0.38)

var settled := false
var _paper_print: Label
var _stage: SubViewport
var _print_view: SubViewport
var _cookie: Node3D
var _whole: Node3D
var _broken: Node3D
var _left: Node3D
var _right: Node3D
var _left_rest: Vector3
var _right_rest: Vector3
var _paper: Node3D


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary, _kept: int = 0) -> void:
	if _stage == null:
		_build_scene()
	var sentence := L10n.t(str(details.get("message", ""))).strip_edges()
	_paper_print.text = sentence
	var measured := FONT.get_string_size(sentence, HORIZONTAL_ALIGNMENT_LEFT, -1, 55).x
	_paper_print.add_theme_font_size_override("font_size", 55 if measured <= 900.0 else floori(55.0 * 900.0 / measured))
	_print_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	apply_time(0.0)


static func caption(details: Dictionary, steps: int) -> String:
	return ToolFortuneCookie.caption(details, steps)


func _build_scene() -> void:
	_print_view = SubViewport.new()
	_print_view.disable_3d = true
	_print_view.size = Vector2i(1024, 164)
	add_child(_print_view)
	var paper_color := ColorRect.new()
	paper_color.size = Vector2(_print_view.size)
	paper_color.color = Color("fcf3df")
	_print_view.add_child(paper_color)
	_paper_print = Label.new()
	_paper_print.size = Vector2(_print_view.size)
	_paper_print.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper_print.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_paper_print.add_theme_font_override("font", FONT)
	_paper_print.add_theme_color_override("font_color", Color("523321"))
	_print_view.add_child(_paper_print)

	_stage = SubViewport.new()
	_stage.size = Vector2i(630, 450)
	_stage.own_world_3d = true
	_stage.transparent_bg = true
	_stage.msaa_3d = Viewport.MSAA_2X
	_stage.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_stage)
	var display := TextureRect.new()
	display.texture = _stage.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.size = SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("fff0da")
	world.environment.ambient_light_energy = 0.72
	_stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.light_energy = 0.82
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 135, 0)
	rim.light_energy = 0.29
	_stage.add_child(rim)

	var camera := Camera3D.new()
	_stage.add_child(camera)
	camera.position = Vector3(0.0, 4.8, 7.8)
	camera.look_at(Vector3(0.0, 0.91, 0.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.28
	camera.current = true

	_cookie = Node3D.new()
	_stage.add_child(_cookie)
	_whole = WHOLE.instantiate() as Node3D
	_broken = BROKEN.instantiate() as Node3D
	_cookie.add_child(_whole)
	_cookie.add_child(_broken)
	_left = _broken.find_child("LeftHalf", true, false) as Node3D
	_right = _broken.find_child("RightHalf", true, false) as Node3D
	_left_rest = _left.position
	_right_rest = _right.position

	_paper = SLIP.instantiate() as Node3D
	_cookie.add_child(_paper)
	var mesh := _paper.find_child("FoldedPaper", true, false) as MeshInstance3D
	var ink := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	ink.albedo_texture = _print_view.get_texture()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.set_surface_override_material(0, ink)


func apply_time(t: float) -> void:
	settled = t >= REVEAL_AT
	if _stage == null:
		return
	var drop := clampf(t / DROP_END, 0.0, 1.0)
	var settle := clampf(inverse_lerp(DROP_END, WOBBLE_END, t), 0.0, 1.0)
	var lift := 1.62 * (1.0 - drop * drop)
	lift += 0.15 * absf(sin(2.0 * PI * settle)) * (1.0 - settle)
	_cookie.position = Vector3(0.0, -0.26 + lift, 0.39)
	_cookie.rotation_degrees = Vector3(
		-9.0 * (1.0 - drop),
		16.0 - 24.0 * (1.0 - drop) + 11.0 * sin(settle * TAU * 2.0) * sin(settle * PI),
		7.0 * sin(settle * TAU * 2.0) * sin(settle * PI)
	)

	var cracked := t >= CRACK_AT
	_whole.visible = not cracked
	_broken.visible = cracked
	_paper.visible = t > CRACK_AT + 0.10
	if not cracked:
		return

	# Anchor the strip to the openings as the halves pull it across the gap.
	var spread := smoothstep(CRACK_AT, REVEAL_AT - 0.10, t)
	_cookie.rotation_degrees.y = lerpf(16.0, 0.0, spread)
	var left_mouth := CLOSED_SEAM.lerp(LEFT_OPENING, spread)
	var right_mouth := CLOSED_SEAM.lerp(RIGHT_OPENING, spread)
	_place_half(_left, _left_rest, left_mouth, Vector3(6.0, -34.0, 63.0) * spread)
	_place_half(_right, _right_rest, right_mouth, Vector3(-3.0, 35.0, -62.0) * spread)

	var unfold := smoothstep(UNFOLD_AT - 0.15, REVEAL_AT, t)
	_paper.position = (left_mouth + right_mouth) * 0.5 + Vector3(0.0, -0.12, -0.19)
	_paper.rotation_degrees = Vector3(lerpf(39.0, 64.0, unfold), 0.0, 3.0 * spread)
	_paper.scale = Vector3(lerpf(0.04, 0.99, spread), 1.0, lerpf(0.70, 1.12, unfold))


func _place_half(half: Node3D, rest: Vector3, mouth: Vector3, rotation: Vector3) -> void:
	half.rotation_degrees = rotation
	half.position = mouth - half.basis * (CLOSED_SEAM - rest)
