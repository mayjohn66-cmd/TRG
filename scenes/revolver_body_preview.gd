## Independent turntable for the revolver body, with no cylinder present.
extends Control

const BODY_SCRIPT = preload("res://scenes/revolver_body_3d.gd")
const TARGET: Vector3 = Vector3(-1.60,-1.55,0)
var model: Node3D
var camera: Camera3D
var render_view: SubViewport
var yaw: float = -0.12
var pitch: float = 0.06
var _dragging: bool = false
var _pivot: Node3D
var _spin: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("17222d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	render_view = SubViewport.new()
	render_view.size = Vector2i(1200,800)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.msaa_3d = Viewport.MSAA_4X
	add_child(render_view)
	var image := TextureRect.new()
	image.texture = render_view.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_bottom = -72
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdcbd9")
	env.ambient_light_energy = 0.65
	environment.environment = env
	render_view.add_child(environment)
	for data: Array in [[Vector3(-35,-30,0),1.7,Color("fff1db")],[Vector3(25,125,0),1.1,Color("a8c9ff")],[Vector3(-20,180,0),1.0,Color.WHITE]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = data[0]
		light.light_energy = data[1]
		light.light_color = data[2]
		render_view.add_child(light)
	_pivot = Node3D.new()
	_pivot.position = TARGET
	render_view.add_child(_pivot)
	model = BODY_SCRIPT.new()
	model.position = -TARGET
	_pivot.add_child(model)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.80
	render_view.add_child(camera)
	camera.current = true
	update_camera()
	var spin := Button.new()
	spin.text = "회전"
	spin.add_theme_font_override("font",load("res://assets/fonts/ONE-Mobile-POP.otf"))
	spin.add_theme_font_size_override("font_size",24)
	spin.position = Vector2(32,24)
	spin.size = Vector2(120,52)
	spin.pressed.connect(func() -> void:
		if _spin!=null: _spin.kill()
		_spin = create_tween()
		_spin.tween_property(_pivot,"rotation:y",_pivot.rotation.y+TAU,2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	add_child(spin)
	var hint := Label.new()
	hint.text = "드래그해서 다른 각도 보기"
	hint.add_theme_font_override("font",load("res://assets/fonts/ONE-Mobile-POP.otf"))
	hint.add_theme_font_size_override("font_size",20)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -58
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func update_camera() -> void:
	camera.position = TARGET+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*12.0
	camera.look_at(TARGET)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x*0.008
		pitch = clampf(pitch+event.relative.y*0.008,-1.1,1.1)
		update_camera()
