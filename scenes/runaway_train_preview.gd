## Standalone model inspection. Drag to orbit, wheel to zoom, 1/2 for close/full view.
extends Node3D

var camera: Camera3D
var target := Vector3(-0.4,1.4,0)
var yaw := -0.47
var elevation := 0.39

func _ready() -> void:
	add_child((preload("res://assets/models/runaway_train/runaway_train_v02.tscn") as PackedScene).instantiate())
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e4e5dd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f8f3e6")
	environment.ambient_light_energy = 0.22
	world.environment = environment
	add_child(world)
	for settings: Array in [[Vector3(-52,-38,0),0.48,Color("fff0dc")],[Vector3(-30,140,0),0.15,Color("dceeff")]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = settings[0]
		light.light_energy = settings[1]
		light.light_color = settings[2]
		light.shadow_enabled = settings[1]>0.3
		light.shadow_normal_bias = 2.0
		add_child(light)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor.mesh = plane
	floor.position.y = -0.005
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Color("e4e5dd")
	matte.roughness = 0.85
	floor.material_override = matte
	add_child(floor)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.6
	add_child(camera)
	camera.current = true
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x*0.008
		elevation = clampf(elevation+event.relative.y*0.006,0.08,1.45)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(2.0,camera.size*0.9)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(24.0,camera.size/0.9)
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_1:
			target = Vector3(-7.3,1.7,0)
			camera.size = 4.8
		elif event.keycode==KEY_2:
			target = Vector3(-0.4,1.4,0)
			camera.size = 10.6
	_update_camera()

func _update_camera() -> void:
	camera.position = target+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*28.0
	camera.look_at(target)
