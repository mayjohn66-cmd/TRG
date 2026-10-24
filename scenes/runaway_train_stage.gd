## Board-aligned 3D presentation only. NpcSweep remains authoritative for clearing.
class_name RunawayTrainStage
extends Node2D

signal tile_passed(tile: int)
signal pose_changed
signal finished

const TRAIN = preload("res://assets/models/runaway_train/runaway_train_v02.tscn")
const TRACK = preload("res://assets/models/runaway_train/straight_track_v01.tscn")
const MODEL_SCALE := 0.032
const TRACK_LENGTH := 3.2
const LAY_INTERVAL := 0.065
const DROP_TIME := 0.16
const PAUSE_TIME := 0.40
const RUN_TIME := 1.85
const AFTER_TIME := 0.62
const CLEAR_TIME := 0.28
const FRONT_OFFSET := 9.569448*MODEL_SCALE
var mode: StringName = &"idle"
var elapsed := 0.0
var pace := 1.0
var path: Array[int] = []
var passed: Array[int] = []
var laid_count := 0
var contact_times: Dictionary = {}
var render_view: SubViewport
var camera: Camera3D
var image: Sprite2D
var train: Node3D
var models: Node3D
var segments: Array[Node3D] = []
var wheels: Array[Node3D] = []
var smoke: Array[Dictionary] = []
var plane_projector: Callable
var direction := Vector2.RIGHT
var origin := Vector2.ZERO
var distance := 1.0
var lay_end := 0.0
var run_start := 0.0
var front_distance := -0.38
var _previous_front := -0.38
var _chug_clock := 0.0
var _smoke_clock := 0.0
var _track_mesh: ArrayMesh

func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "RunawayTrainViewport"
	render_view.size = Vector2i(1600,1200)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	models = Node3D.new()
	render_view.add_child(models)
	train = TRAIN.instantiate() as Node3D
	models.add_child(train)
	wheels = _find_wheels(train)
	for wheel: Node3D in wheels:
		_batch_meshes(wheel,false)
	_batch_meshes(train,true)
	train.hide()
	var track := TRACK.instantiate() as Node3D
	_track_mesh = _batch_meshes(track,false)
	track.free()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.25
	camera.position = Vector3(3.5,3.48,3.5)
	render_view.add_child(camera)
	camera.look_at(Vector3(0.5,0,0.5))
	camera.current = true
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0,0,0,0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff6e6")
	environment.ambient_light_energy = 0.28
	world.environment = environment
	render_view.add_child(world)
	for settings: Array in [[Vector3(-52,-38,0),0.52,Color("fff0dc")],[Vector3(-30,140,0),0.18,Color("dceeff")]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = settings[0]
		light.light_energy = settings[1]
		light.light_color = settings[2]
		render_view.add_child(light)
	image = Sprite2D.new()
	image.name = "BoardTrainComposite"
	image.centered = false
	image.texture = render_view.get_texture()
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(image)
	hide()

func play(route: Array[int], speed: float, projector: Callable) -> void:
	cancel()
	path = route.duplicate()
	if path.size()<2:
		finished.emit()
		return
	plane_projector = projector
	pace = clampf(speed,0.5,2.0)
	origin = BoardLayout.tile_norm(path[0])
	var end := BoardLayout.tile_norm(path[-1])
	direction = (end-origin).normalized()
	distance = origin.distance_to(end)
	var count := maxi(2,ceili((distance+0.16)/(TRACK_LENGTH*MODEL_SCALE)))
	var spacing := (distance+0.16)/count
	var heading := atan2(direction.y,-direction.x)
	for index: int in count:
		var segment := Node3D.new()
		segment.name = "LaidSegment%02d" % index
		var point := origin+direction*(-0.08+(index+0.5)*spacing)
		segment.position = Vector3(point.x,0,point.y)
		segment.rotation.y = heading
		segment.scale = Vector3(spacing/TRACK_LENGTH,MODEL_SCALE,MODEL_SCALE)
		models.add_child(segment)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _track_mesh
		segment.add_child(mesh)
		segment.hide()
		segments.append(segment)
	lay_end = (count-1)*LAY_INTERVAL+DROP_TIME+0.10
	run_start = lay_end+PAUSE_TIME
	front_distance = -0.38
	_previous_front = front_distance
	train.rotation = Vector3(0,heading,0)
	train.scale = Vector3.ONE*MODEL_SCALE
	train.hide()
	for wheel: Node3D in wheels:
		wheel.rotation.z = 0.0
	mode = &"lay"
	show()
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sync_projection()
	_update_pose()

func cancel() -> void:
	mode = &"idle"
	elapsed = 0.0
	laid_count = 0
	passed.clear()
	contact_times.clear()
	_chug_clock = 0.0
	_smoke_clock = 0.0
	for segment: Node3D in segments:
		segment.queue_free()
	segments.clear()
	for puff: Dictionary in smoke:
		(puff.node as Node3D).queue_free()
	smoke.clear()
	if train != null:
		train.hide()
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()

func sync_projection() -> void:
	if camera == null or not plane_projector.is_valid():
		return
	var at := camera.unproject_position(Vector3.ZERO)
	var screen_plane := Transform2D(camera.unproject_position(Vector3.RIGHT)-at,camera.unproject_position(Vector3.BACK)-at,at)
	image.transform = (plane_projector.call() as Transform2D)*screen_plane.affine_inverse()

func _process(delta: float) -> void:
	if mode!=&"idle":
		advance(delta)

## Solve the same acceleration curve used by the visible locomotive front.
## Contacts retain their actual time when a browser frame crosses several tiles.
func contact_time(tile: int) -> float:
	var along := (BoardLayout.tile_norm(tile)-origin).dot(direction)
	var fraction := clampf((along+0.38)/(distance+1.16),0.0,1.0)
	var progress := (-0.35+sqrt(0.1225+2.6*fraction))/1.3
	return run_start+progress*RUN_TIME

func camera_weight() -> float:
	if mode==&"idle":
		return 0.0
	var enter := smoothstep(run_start-0.38,run_start,elapsed)
	var leave := smoothstep(run_start+RUN_TIME+0.12,run_start+RUN_TIME+AFTER_TIME+CLEAR_TIME,elapsed)
	return enter*(1.0-leave)

func camera_focus() -> Vector2:
	var progress := smoothstep(run_start,run_start+RUN_TIME,elapsed)
	return origin+direction*distance*lerpf(0.18,0.60,progress)

func advance(delta: float) -> void:
	if mode==&"idle":
		return
	var dt := delta/pace
	elapsed += dt
	for index: int in segments.size():
		var age := elapsed-index*LAY_INTERVAL
		if age<0.0:
			continue
		segments[index].show()
		var phase := clampf(age/DROP_TIME,0.0,1.0)
		segments[index].position.y = (0.045*(1.0-phase*phase)) if phase<1.0 else absf(sin((age-DROP_TIME)*PI/0.10))*0.004*(1.0-clampf((age-DROP_TIME)/0.10,0,1))
		if age>=DROP_TIME and laid_count<=index:
			laid_count = index+1
			Sfx.play(&"yut_clack",-12.0,0.015,1.05+index*0.015)
	if elapsed<lay_end:
		mode = &"lay"
	elif elapsed<run_start:
		mode = &"pause"
	elif elapsed<run_start+RUN_TIME:
		if mode!=&"run":
			train.show()
			Sfx.play(&"rocket",-7.0,0.0,0.78)
			Sfx.play(&"launch",-5.0,0.0,0.85)
		mode = &"run"
		var p := clampf((elapsed-run_start)/RUN_TIME,0,1)
		front_distance = lerpf(-0.38,distance+0.78,p*0.35+p*p*0.65)
		_chug_clock += dt
		_smoke_clock += dt
		if _chug_clock>lerpf(0.16,0.065,p):
			_chug_clock = 0.0
			Sfx.play(&"yut_clack",-17.0,0.01,0.65+p*0.2)
		if _smoke_clock>0.085:
			_smoke_clock = 0.0
			_spawn_smoke()
	elif elapsed<run_start+RUN_TIME+AFTER_TIME:
		mode = &"after"
		train.hide()
	else:
		mode = &"clear"
		var p := clampf((elapsed-run_start-RUN_TIME-AFTER_TIME)/CLEAR_TIME,0,1)
		for segment: Node3D in segments:
			segment.position.y = -p*0.04
		image.modulate.a = 1.0-p
		if p>=1.0:
			mode = &"idle"
			train.hide()
			hide()
			render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
			finished.emit()
	# Move the visible model before delivering its collision events.
	_update_pose()
	# Recover ordered contacts even if a browser frame skips across the run boundary.
	if elapsed>=run_start and passed.size()<path.size():
		for tile: int in path:
			var hit_at := contact_time(tile)
			if not passed.has(tile) and elapsed>=hit_at:
				passed.append(tile)
				contact_times[tile] = hit_at
				tile_passed.emit(tile)
	_update_smoke(dt)
	pose_changed.emit()
	# The board's camera rig is updated by pose_changed; use that same frame's plane.
	sync_projection()

func _update_pose() -> void:
	image.modulate.a = 1.0 if mode!=&"clear" else image.modulate.a
	var point := origin+direction*(front_distance-FRONT_OFFSET)
	train.position = Vector3(point.x,(0.40-0.035)*MODEL_SCALE,point.y)
	var traveled := maxf(front_distance-_previous_front,0.0)
	for wheel: Node3D in wheels:
		var radius := float(wheel.get_meta("wheel_radius",0.5))
		wheel.rotation.z += traveled/(radius*MODEL_SCALE)
	_previous_front = front_distance

func _spawn_smoke() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 12
	mesh.rings = 6
	var puff := MeshInstance3D.new()
	puff.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1,0.97,0.88,0.7)
	puff.material_override = material
	models.add_child(puff)
	var at := train.transform*(Vector3(-8.46,3.42,0))
	puff.position = at
	smoke.append({"node":puff,"age":0.0,"origin":at})

func _update_smoke(delta: float) -> void:
	for index: int in range(smoke.size()-1,-1,-1):
		var puff: Dictionary = smoke[index]
		puff.age = float(puff.age)+delta
		var age: float = puff.age
		if age>0.65:
			(puff.node as Node3D).queue_free()
			smoke.remove_at(index)
			continue
		var node := puff.node as MeshInstance3D
		node.position = (puff.origin as Vector3)+Vector3(-direction.x*age*0.09,age*0.11,-direction.y*age*0.09)
		node.scale = Vector3.ONE*(0.8+age*2.5)
		(node.material_override as StandardMaterial3D).albedo_color.a = (1.0-age/0.65)*0.7

func _find_wheels(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child: Node in node.get_children():
		if str(child.name).begins_with("DriverWheel") or str(child.name).begins_with("WagonWheel"):
			result.append(child as Node3D)
		else:
			result.append_array(_find_wheels(child))
	return result

## Batch the approved meshes by material on instances only; source assets remain intact.
func _batch_meshes(branch: Node3D, skip_wheels: bool) -> ArrayMesh:
	var buckets: Dictionary = {}
	var originals: Array[MeshInstance3D] = []
	var stack: Array = [[branch,Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node3D = entry[0]
		var transform: Transform3D = entry[1]
		if node!=branch:
			if skip_wheels and (str(node.name).begins_with("DriverWheel") or str(node.name).begins_with("WagonWheel")):
				continue
			transform *= node.transform
		for child: Node in node.get_children():
			if child is Node3D:
				stack.append([child,transform])
		if node is not MeshInstance3D:
			continue
		var part := node as MeshInstance3D
		originals.append(part)
		for surface: int in part.mesh.get_surface_count():
			var material: Material = part.material_override if part.material_override!=null else part.mesh.surface_get_material(surface)
			if not buckets.has(material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				buckets[material] = tool
			(buckets[material] as SurfaceTool).append_from(part.mesh,surface,transform)
	var combined := ArrayMesh.new()
	for material: Material in buckets:
		(buckets[material] as SurfaceTool).commit(combined)
		combined.surface_set_material(combined.get_surface_count()-1,material)
	for original: MeshInstance3D in originals:
		original.free()
	var display := MeshInstance3D.new()
	display.name = "BatchedModel"
	display.mesh = combined
	branch.add_child(display)
	return combined
