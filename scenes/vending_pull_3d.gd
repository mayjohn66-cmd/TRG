## Cosmetic only: the engine-supplied drink is shown, never rolled again here.
extends Control

const MODEL_PATH := "res://assets/models/vending/monatium_vending_v02.tscn"
const CAN_ROOT := "res://assets/models/vending/can_"
var render_view: SubViewport
var machine: Node3D
var can_pivot: Node3D
var can: Node3D
var flap: Node3D
var selected_button: StandardMaterial3D
var drink: StringName
var phase: StringName = &"select"
var elapsed := 0.0
var pace := 1.0
var machine_at := Vector3(-1.5,0,0)
var drop_at: Vector3
var tray_at: Vector3
var sound_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	render_view = SubViewport.new()
	render_view.name = "VendingViewport"
	render_view.size = Vector2i(1040,560)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.msaa_3d = Viewport.MSAA_4X
	add_child(render_view)
	var image := TextureRect.new()
	image.texture = render_view.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d2ebf5")
	settings.ambient_light_energy = 0.4
	environment.environment = settings
	render_view.add_child(environment)
	for entry: Array in [[Vector3(-40,-35,0),0.95],[Vector3(-20,140,0),0.25]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = entry[0]
		light.light_energy = entry[1]
		render_view.add_child(light)
	machine = (load(MODEL_PATH) as PackedScene).instantiate()
	machine.position = machine_at
	render_view.add_child(machine)
	flap = machine.get_node("DeliveryFlap")
	drop_at = machine_at+(machine.get_node("CanDropAnchor") as Marker3D).position+Vector3(0,0.24,0)
	tray_at = machine_at+Vector3(-0.24,0.70,0.66)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	render_view.add_child(camera)
	camera.position = Vector3(0.65,2.35,9)
	camera.look_at(Vector3(0,1.85,0))
	camera.current = true
	set_process(false)

func play(id: StringName, motion_pace: float) -> void:
	drink = id
	pace = maxf(motion_pace,0.1)
	can_pivot = Node3D.new()
	can_pivot.name = "DispensedCanPivot"
	render_view.add_child(can_pivot)
	can = (load(CAN_ROOT+String(drink)+"_v02.tscn") as PackedScene).instantiate()
	can.position.y = -0.24
	can_pivot.add_child(can)
	var button: MeshInstance3D = machine.get_node("Select_"+String(drink))
	selected_button = button.material_override.duplicate() as StandardMaterial3D
	selected_button.emission = selected_button.albedo_color
	button.material_override = selected_button
	elapsed = 0.0
	set_time(0.0)
	set_process(true)

func _process(delta: float) -> void:
	var previous: float = elapsed
	elapsed += delta/pace
	set_time(elapsed)
	if sound_enabled and previous < 0.76 and elapsed >= 0.76:
		Sfx.play(&"ui_click",-9.0)

func progress(at: float, start: float, finish: float) -> float:
	return clampf((at-start)/(finish-start),0.0,1.0)

## Seekable for checking the actual drop/reveal geometry at all viewport sizes.
func set_time(at: float) -> void:
	if can_pivot == null: return
	elapsed = at
	selected_button.emission_enabled = at >= 0.18 and at < 0.48
	var selected: Node3D = machine.get_node("Can_"+String(drink))
	selected.visible = at < 0.38
	can_pivot.visible = at >= 0.38
	can_pivot.scale = Vector3.ONE
	can_pivot.rotation = Vector3.ZERO
	flap.rotation.x = -0.9*sin(progress(at,0.30,1.08)*PI)
	if at < 0.38:
		phase = &"select"
		can_pivot.position = drop_at
	elif at < 0.76:
		phase = &"drop"
		var p: float = progress(at,0.38,0.76)
		can_pivot.position = drop_at.lerp(tray_at,p*p)
		can_pivot.rotation.z = lerpf(-0.12,PI/2.0,p*p)
	elif at < 1.02:
		phase = &"tray"
		var p: float = progress(at,0.76,1.02)
		can_pivot.position = tray_at+Vector3(0,sin(p*TAU)*0.035*(1.0-p),p*0.22)
		can_pivot.rotation.z = PI/2.0+sin(p*TAU)*0.07*(1.0-p)
	else:
		phase = &"reveal"
		var p: float = progress(at,1.02,1.36)
		var eased: float = p*p*(3.0-2.0*p)
		can_pivot.position = (tray_at+Vector3(0,0,0.22)).lerp(Vector3(2.0,3.18,0.7),eased)
		can_pivot.position.y += sin(p*PI)*0.18
		can_pivot.rotation = Vector3(0,0.1,lerpf(PI/2.0,0.0,eased))
		can_pivot.scale = Vector3.ONE*lerpf(1.0,2.4,eased)
