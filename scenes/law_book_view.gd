extends VBoxContainer
## The announcement owns the clock and can discard this view at any point.

const MODEL_PATH := "res://assets/models/law_codex/law_codex.glb"
const DISPLAY := Vector2(610, 390)
const LAND := 0.20
const OPEN := 0.30
const OPEN_END := 0.83
const READ := 1.02

var _stage: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _condition: Label
var _laws: Control
var _viewport: SubViewport
var _camera: Camera3D
var _book: Node3D
var _hinge: Node3D
var _left_rect: Rect2
var _right_rect: Rect2
var _animated := false
var _landed := false
var _turned := false
var _settled := false


func setup(left: VBoxContainer, right: VBoxContainer, laws: Control, animated: bool) -> void:
	name = "LawBook"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	_animated = animated
	_left = left
	_right = right
	_condition = right.get_node("LawCondition") as Label
	_laws = laws
	_stage = Control.new()
	_stage.custom_minimum_size = DISPLAY
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.add_child(_left)
	_stage.add_child(_right)
	add_child(_laws)
	_left.hide()
	_right.hide()
	_laws.modulate.a = 0.0 if animated else 1.0


func _ready() -> void:
	if not _animated:
		_build()
		_pose(READ)


func set_presentation_time(elapsed: float, duration: float) -> void:
	if _settled or elapsed >= duration:
		return
	if _viewport == null:
		_build()
	var pace := minf(duration / 3.4, 1.0)
	# Keep the opening readable at higher game speeds while reserving the hold.
	var time := elapsed / maxf(0.40, pace)
	if not _landed and time >= LAND:
		_landed = true
		Sfx.play(&"thud", -8.0)
	if not _turned and time >= OPEN + 0.08:
		_turned = true
		Sfx.play(&"page_flip", -4.0)
	_pose(time)


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "LawBookViewport"
	_viewport.size = Vector2i(DISPLAY * 1.5)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_stage.add_child(_viewport)

	var surface := TextureRect.new()
	surface.name = "CodexSurface"
	surface.texture = _viewport.get_texture()
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(surface)
	_stage.move_child(surface, 0)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("ead7f0")
	world.environment.ambient_light_energy = 0.48
	_viewport.add_child(world)
	_light(Vector3(-55, -33, -10), Color("fff0d3"), 0.65)
	_light(Vector3(-28, 140, 0), Color("a9b5ff"), 0.28)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 3.83
	_camera.position = Vector3(0, 8, 2.08)
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0, 0.35, 0.14))
	_camera.current = true
	_book = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	_viewport.add_child(_book)
	var parts := _book.get_children()
	_hinge = Node3D.new()
	_hinge.name = "RightCoverHinge"
	_hinge.position.y = 0.40
	_book.add_child(_hinge)
	for part: Node3D in parts:
		if str(part.name).begins_with("Right"):
			part.reparent(_hinge)

	_left_rect = _page_rect(-1.98, -0.35)
	_right_rect = _page_rect(0.32, 2.02)
	_left.position = _left_rect.position
	_right.position = _right_rect.position
	_left.minimum_size_changed.connect(_fit_pages)
	_right.minimum_size_changed.connect(_fit_pages)
	_fit_pages()


func _light(angles: Vector3, tint: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_color = tint
	light.light_energy = energy
	_viewport.add_child(light)


func _page_rect(x0: float, x1: float) -> Rect2:
	var start := _camera.unproject_position(Vector3(x0, 0.56, -1.28)) / 1.5
	var end := _camera.unproject_position(Vector3(x1, 0.56, 1.24)) / 1.5
	return Rect2(start, end - start)


func _fit_pages() -> void:
	# Wrapped labels recalculate their minimum height after receiving the page width.
	var condition_px := _condition.get_theme_font_size("font_size")
	if _condition.size.x >= _right_rect.size.x - 2.0 and _right.get_combined_minimum_size().y > _right_rect.size.y and condition_px > 16:
		_condition.add_theme_font_size_override("font_size", condition_px - 2)
	_left.size = _left_rect.size
	_right.size = _right_rect.size


func _pose(time: float) -> void:
	var drop := clampf(time / LAND, 0.0, 1.0)
	var rebound := clampf((time - LAND) / 0.14, 0.0, 1.0)
	var open := smoothstep(OPEN, OPEN_END, time)
	var reading := smoothstep(OPEN_END - 0.04, READ, time)
	var book_width := 0.82 + 0.18 * drop
	_book.position.x = 1.05 * (1.0 - open) + 0.13 * (1.0 - drop)
	_book.position.z = -1.0 * (1.0 - drop * drop) + sin(PI * rebound) * 0.09
	_book.scale = Vector3.ONE * book_width
	_book.rotation.y = deg_to_rad(-15.0) * (1.0 - open)
	_hinge.rotation.z = deg_to_rad(161.0) * (1.0 - open)
	_left.visible = reading > 0.0
	_right.visible = reading > 0.0
	_left.modulate.a = reading
	_right.modulate.a = reading
	_left.position.y = _left_rect.position.y + 9.0 * (1.0 - reading)
	_right.position.y = _right_rect.position.y + 9.0 * (1.0 - reading)
	_laws.modulate.a = reading
	_settled = time >= READ
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if _settled else SubViewport.UPDATE_ALWAYS
