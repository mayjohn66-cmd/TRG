## Shared physical toy wheel for direct manipulation and remote roll reveals.
## The engine chooses 1..10; this local clock only animates that fixed outcome.
class_name RouletteSpin3D
extends TextureRect

signal tick_passed(ordinal: int)

const VIEW_SIZE: Vector2 = Vector2(350,350)
const RENDER_SIZE: Vector2i = Vector2i(768,768)
const STEP: float = TAU/10.0
const LEAD_TIME: float = 0.06
const ACCEL_TIME: float = 0.18
const COAST_TIME: float = 0.15
const BRAKE_TIME: float = 1.55
const SPIN_TIME: float = LEAD_TIME+ACCEL_TIME+COAST_TIME+BRAKE_TIME
const SETTLE_TIME: float = 0.16
const RESULT_TIME: float = SPIN_TIME+SETTLE_TIME
const TOTAL_TIME: float = RESULT_TIME+0.55
const CAMERA_HOME: Vector3 = Vector3(0,10,5.5)
const CAMERA_TARGET: Vector3 = Vector3(0,0.15,0)
const CAMERA_SIZE: float = 4.85
const COLORS: Array[String] = ["c6e89b","8fd7cf","f5aec7","9cd4ed","c6e89b","9cd4ed","ffcf57","f5aec7","8fd7cf","e8d299"]
const TOY_SHADER: Shader = preload("res://assets/ui/trickcal/roulette/roulette_toy.gdshader")
const FONT: Font = preload("res://assets/fonts/ONE-Mobile-POP.otf")
static var _housing_mesh: ArrayMesh
static var _rotor_mesh: ArrayMesh
static var _pointer_mesh: ArrayMesh
var render_view: SubViewport
var rotor: Node3D
var pointer: Node3D
var angle: float = 0.0:
	set(value):
		angle = value
		if rotor != null:
			rotor.rotation.y = value
			if render_view.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
				render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
var settled: bool = false
var result_value: int = 1
var tick_times: Array[float] = []
var _start: float = 0.0
var _distance: float = 0.0
var _direction: float = 1.0
var _crossed: int = 0
var _last_sound: float = -1.0
var _sounded_crossing: int = 0
var _time: float = 0.0
var _result_played: bool = false
var _winner: MeshInstance3D


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "RouletteViewport"
	render_view.size = RENDER_SIZE
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(render_view)
	texture = render_view.get_texture()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.position = CAMERA_HOME
	render_view.add_child(camera)
	camera.look_at(CAMERA_TARGET)
	camera.current = true
	if _housing_mesh == null:
		_housing_mesh = make_housing_mesh()
		_rotor_mesh = make_rotor_mesh()
		_pointer_mesh = make_pointer_mesh()
	var toy := ShaderMaterial.new()
	toy.shader = TOY_SHADER
	_add_mesh(render_view,_housing_mesh,toy)
	rotor = Node3D.new()
	rotor.name = "TenSectorRotor"
	render_view.add_child(rotor)
	_add_mesh(rotor,_rotor_mesh,toy)
	for index: int in 10:
		var label := Label3D.new()
		label.text = str(index+1)
		label.font = FONT
		label.font_size = 96
		label.pixel_size = 0.0045
		label.outline_size = 12
		label.modulate = Color("784723") if index == 6 else Color("376245")
		label.outline_modulate = Color("fff7dc")
		label.no_depth_test = false
		label.shaded = false
		label.position = radial(index*STEP,1.22,0.366)
		label.rotation = Vector3(-PI/2.0,-index*STEP,0)
		rotor.add_child(label)
	pointer = Node3D.new()
	pointer.name = "FixedSpringPointer"
	pointer.position = Vector3(0,0.49,-1.94)
	render_view.add_child(pointer)
	_add_mesh(pointer,_pointer_mesh,toy)
	# A solid hub hides the ten sector tips and gives the wheel a real axle.
	var hub := SurfaceTool.new()
	hub.begin(Mesh.PRIMITIVE_TRIANGLES)
	lathe(hub,[Vector2(0,0.37),Vector2(0.31,0.37),Vector2(0.35,0.42),Vector2(0.31,0.48),Vector2(0,0.48)],Color("fff3c4"))
	_add_mesh(rotor,hub.commit(),toy)
	var winner := SurfaceTool.new()
	winner.begin(Mesh.PRIMITIVE_TRIANGLES)
	sector(winner,-STEP*0.46,STEP*0.46,0.40,1.64,0.36,Color("fff5bd"))
	_winner = _add_mesh(rotor,winner.commit(),toy)
	_winner.visible = false
	angle = angle


func begin(face: int, power: float, initial_angle: float = 0.0, direction: float = 1.0) -> void:
	result_value = clampi(face,1,10)
	_start = fposmod(initial_angle,TAU)
	_direction = -1.0 if direction < 0 else 1.0
	_distance = travel_for(result_value,power,_start,_direction)
	_crossed = 0
	_last_sound = -1.0
	_sounded_crossing = 0
	_time = 0.0
	_result_played = false
	settled = false
	_winner.visible = false
	_winner.rotation.y = -(result_value-1)*STEP
	tick_times = crossing_times(_start,_distance,_direction)
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


func set_idle_angle(value: float) -> void:
	angle = value
	if pointer != null:
		pointer.rotation.z = 0.0
		_winner.visible = false


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func apply_time(seconds: float) -> void:
	_time = maxf(seconds,0.0)
	angle = _start+_direction*_distance*progress_at(_time)
	var settle: float = clampf((_time-SPIN_TIME)/SETTLE_TIME,0,1)
	if _time >= SPIN_TIME:
		angle += _direction*0.014*sin(settle*TAU)*pow(1.0-settle,2)
	while _crossed < tick_times.size() and tick_times[_crossed] <= _time:
		_crossed += 1
		tick_passed.emit(_crossed)
	# No catch-up sound burst after a delayed frame. At high speed at most 30Hz.
	if _crossed > 0:
		var since: float = _time-tick_times[_crossed-1]
		pointer.rotation.z = _direction*0.23*exp(-since/0.042)*sin(since/0.075*PI)
		if _crossed != _sounded_crossing and since < 0.055 and _time-_last_sound >= 0.032 and _time < SPIN_TIME:
			Sfx.play(&"roulette_tick",-7.0,0.0,1.04-0.18*progress_at(_time))
			_last_sound = _time
			_sounded_crossing = _crossed
	settled = _time >= RESULT_TIME
	_winner.visible = settled
	if settled and not _result_played:
		_result_played = true
		if _time-RESULT_TIME < 0.08:
			Sfx.play(&"roulette_stop",-3.0,0.0)
			if result_value == ToolLifeRoulette.JACKPOT_FACE:
				Sfx.play(&"good",-8.0,0.0)
	if settled:
		pointer.rotation.z = 0.0
		if render_view.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			render_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func displayed_value() -> int:
	return face_under_pointer(angle)


static func face_under_pointer(value: float) -> int:
	return posmod(int(floor(value/STEP+0.5)),10)+1


static func travel_for(face: int, power: float, start: float, direction: float) -> float:
	var turns: int = 2+int(roundf(clampf(power,0,1)*2.0))
	return turns*TAU+fposmod(direction*((clampi(face,1,10)-1)*STEP-start),TAU)


## Integral of a velocity ramp, short coast, and quartic ease-out brake.
## Both the angle and angular velocity are continuous at each phase boundary.
static func progress_at(seconds: float) -> float:
	var t: float = clampf(seconds-LEAD_TIME,0,SPIN_TIME-LEAD_TIME)
	var area: float = ACCEL_TIME*0.5+COAST_TIME+BRAKE_TIME*0.25
	if t <= ACCEL_TIME:
		return t*t/(2.0*ACCEL_TIME*area)
	if t <= ACCEL_TIME+COAST_TIME:
		return (ACCEL_TIME*0.5+t-ACCEL_TIME)/area
	var u: float = clampf((t-ACCEL_TIME-COAST_TIME)/BRAKE_TIME,0,1)
	return (ACCEL_TIME*0.5+COAST_TIME+BRAKE_TIME*(1.0-pow(1.0-u,4))*0.25)/area


static func crossing_times(start: float, distance: float, direction: float) -> Array[float]:
	var result: Array[float] = []
	# Sector boundaries lie halfway between labels; pointer contact follows them.
	var first: float = fposmod(direction*(STEP*0.5-start),STEP)
	if first < 0.00001:
		first += STEP
	var travel: float = first
	while travel < distance-0.00001:
		var low: float = LEAD_TIME
		var high: float = SPIN_TIME
		for iteration: int in 24:
			var mid: float = (low+high)*0.5
			if progress_at(mid)*distance < travel:
				low = mid
			else:
				high = mid
		result.append((low+high)*0.5)
		travel += STEP
	return result


static func radial(phi: float, radius: float, height: float) -> Vector3:
	return Vector3(sin(phi)*radius,height,-cos(phi)*radius)


static func _add_mesh(parent: Node, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	# Godot front faces are clockwise. Correct the winding once, at construction.
	var points := PackedVector3Array([a,b,c])
	if (b-a).cross(c-a).dot(normal)>=0:
		points.reverse()
	for point: Vector3 in points:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(point)


static func sector(st: SurfaceTool, from: float, to: float, inner: float, outer: float, y: float, color: Color) -> void:
	for index: int in 16:
		var a: float = lerpf(from,to,index/16.0)
		var b: float = lerpf(from,to,(index+1)/16.0)
		triangle(st,radial(a,inner,y),radial(a,outer,y),radial(b,outer,y),Vector3.UP,color)
		triangle(st,radial(a,inner,y),radial(b,outer,y),radial(b,inner,y),Vector3.UP,color)


static func lathe(st: SurfaceTool, profile: Array[Vector2], color: Color) -> void:
	for edge: int in profile.size()-1:
		var a: Vector2 = profile[edge]
		var b: Vector2 = profile[edge+1]
		var n := Vector2(b.y-a.y,a.x-b.x).normalized()
		for index: int in 96:
			var phi: float = index*TAU/96.0
			var next: float = (index+1)*TAU/96.0
			var normal: Vector3 = radial((phi+next)*0.5,n.x,n.y)
			triangle(st,radial(phi,a.x,a.y),radial(next,a.x,a.y),radial(next,b.x,b.y),normal,color)
			triangle(st,radial(phi,a.x,a.y),radial(next,b.x,b.y),radial(phi,b.x,b.y),normal,color)


static func make_housing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	lathe(st,[Vector2(0,0.02),Vector2(1.90,0.02),Vector2(2.03,0.10),Vector2(2.03,0.19),Vector2(1.98,0.27),Vector2(0,0.27)],Color("46734d"))
	lathe(st,[Vector2(1.98,0.25),Vector2(1.98,0.33),Vector2(1.94,0.39),Vector2(1.84,0.39),Vector2(1.77,0.32),Vector2(1.77,0.25)],Color("fff0bc"))
	lathe(st,[Vector2(1.84,0.395),Vector2(1.81,0.385),Vector2(1.79,0.35)],Color("d9aa45"))
	for i: int in 10:
		sector(st,i*STEP-0.018,i*STEP+0.018,1.87,1.92,0.395,Color("92bd5d"))
	return st.commit()


static func make_rotor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	lathe(st,[Vector2(0,0.27),Vector2(1.71,0.27),Vector2(1.76,0.31),Vector2(1.74,0.35),Vector2(0,0.35)],Color("d1b47b"))
	for i: int in 10:
		sector(st,i*STEP-STEP*0.5+0.010,i*STEP+STEP*0.5-0.010,0.29,1.73,0.356,Color(COLORS[i]))
	return st.commit()


static func make_pointer_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Blunt physical pointer, pivot at the top; tip enters the wheel at +Z.
	var outline: Array[Vector2] = [Vector2(-0.13,-0.11),Vector2(0.13,-0.11),Vector2(0.17,0.10),Vector2(0,0.44),Vector2(-0.17,0.10)]
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var av := Vector3(a.x,0.06,a.y)
		var bv := Vector3(b.x,0.06,b.y)
		triangle(st,Vector3(0,0.06,0.05),av,bv,Vector3.UP,Color("e9a952"))
		var n := Vector3(b.y-a.y,0,a.x-b.x).normalized()
		triangle(st,av,bv,Vector3(b.x,-0.04,b.y),n,Color("905933"))
		triangle(st,av,Vector3(b.x,-0.04,b.y),Vector3(a.x,-0.04,a.y),n,Color("905933"))
	return st.commit()
