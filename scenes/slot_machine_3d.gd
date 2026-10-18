## Three physical six-symbol drums. The authoritative engine supplies the stops.
## A cached image strip is wrapped around every cylinder, never shuffled as text.
class_name SlotMachine3D
extends TextureRect

signal reel_stopped(index: int)

const VIEW_SIZE: Vector2 = Vector2(500,330)
const RENDER_SIZE: Vector2i = Vector2i(1000,660)
const STRIP_SIZE: Vector2i = Vector2i(256,1536)
const SYMBOLS: Array[String] = ["체리","레몬","종","BAR","다이아","7"]
const ICON_FILES: Dictionary = {0:"CHERRY",1:"LEMON",2:"BELL",4:"DIAMOND"}
const ICON_EXTENTS: Dictionary = {0:240.0,1:216.0,2:224.0,4:208.0}
const FONT: Font = preload("res://assets/fonts/ONE-Mobile-POP.otf")
const BODY_SHADER: Shader = preload("res://assets/ui/trickcal/dice/toy_die.gdshader")
const REEL_SHADER: Shader = preload("res://assets/ui/trickcal/slot/slot_reel.gdshader")
const STEP: float = TAU/6.0
const LEAD_TIME: float = 0.10
const ACCEL_TIME: float = 0.12
const BRAKE_TIME: float = 0.55
const STOP_TIMES: Array[float] = [1.10,1.48,1.86]
const SETTLE_TIME: float = 0.14
const RESULT_TIME: float = 2.00
const TOTAL_TIME: float = RESULT_TIME+0.65
const REEL_RADIUS: float = 1.0
const REEL_HALF_WIDTH: float = 0.51
const CAMERA_HOME: Vector3 = Vector3(0,1.6,12)
const CAMERA_TARGET: Vector3 = Vector3(0.18,0.0,0)
const CAMERA_SIZE: float = 4.6
const STARTS: Array[float] = [0.0,2.0*STEP,4.0*STEP]
static var _drum_mesh: ArrayMesh
static var _box_meshes: Dictionary = {}
var render_view: SubViewport
var drums: Array[Node3D] = []
var stopped: Array[bool] = [false,false,false]
var result_values: Array[int] = [0,0,0]
var settled: bool = false
var winning_reels: Array[bool] = [false,false,false]
var _strip_view: SubViewport
var _materials: Array[ShaderMaterial] = []
var _lamp_materials: Array[ShaderMaterial] = []
var _frame_materials: Array[ShaderMaterial] = []
var _cabinet: Node3D
var _lever: Node3D
var _sign: Label3D
var _power: float = 0.5
var _time: float = 0.0
var _last_whirr: float = -1.0
var _announced: bool = false


func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_strip_view = _make_strip()
	render_view = SubViewport.new()
	render_view.name = "SlotMachineViewport"
	render_view.size = RENDER_SIZE
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	texture = render_view.get_texture()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.position = CAMERA_HOME
	render_view.add_child(camera)
	camera.look_at(CAMERA_TARGET)
	camera.current = true
	_cabinet = Node3D.new()
	render_view.add_child(_cabinet)
	_build_cabinet()
	if _drum_mesh == null:
		_drum_mesh = make_drum_mesh()
	for index: int in 3:
		var pivot := Node3D.new()
		pivot.name = "PhysicalReel%d" % (index+1)
		pivot.position = Vector3((index-1)*1.35,0,-0.35)
		_cabinet.add_child(pivot)
		drums.append(pivot)
		var body := MeshInstance3D.new()
		body.mesh = _drum_mesh
		var material := ShaderMaterial.new()
		material.shader = REEL_SHADER
		material.set_shader_parameter("strip",_strip_view.get_texture())
		body.material_override = material
		pivot.add_child(body)
		_materials.append(material)
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.085
		sphere.height = 0.17
		sphere.radial_segments = 12
		sphere.rings = 6
		lamp.mesh = sphere
		lamp.position = Vector3((index-1)*1.35,-0.88,1.01)
		var paint: ShaderMaterial = toy_material(Color("7f936b"))
		lamp.material_override = paint
		_cabinet.add_child(lamp)
		_lamp_materials.append(paint)
		var frame: ShaderMaterial = toy_material(Color("e5cd91"))
		_frame_materials.append(frame)
		for side: float in [-1.0,1.0]:
			box(Vector3(0.56,0.028,0.018),Vector3((index-1)*1.35,side*0.56,1.005),frame,0.016)


func _make_strip() -> SubViewport:
	var view := SubViewport.new()
	view.name = "SixSymbolStrip"
	view.size = STRIP_SIZE
	view.disable_3d = true
	view.gui_disable_input = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)
	var paper := ColorRect.new()
	paper.color = Color("fff8df")
	paper.size = Vector2(STRIP_SIZE)
	view.add_child(paper)
	for symbol: int in 6:
		var row: int = strip_row(symbol)
		if ICON_FILES.has(symbol):
			var icon := TextureRect.new()
			icon.texture = load("res://assets/ui/trickcal/slot/SLOT_%s.png" % ICON_FILES[symbol]) as Texture2D
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var extent: float = ICON_EXTENTS[symbol]
			icon.position = Vector2((256-extent)/2.0,row*256+(256-extent)/2.0)
			icon.size = Vector2(extent,extent)
			view.add_child(icon)
		else:
			var label := Label.new()
			label.text = "BAR" if symbol==3 else "7"
			label.add_theme_font_override("font",FONT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size",88 if symbol==3 else 196)
			label.add_theme_color_override("font_color",Color("376245") if symbol==3 else Color("de5076"))
			label.add_theme_color_override("font_outline_color",Color("fff2bc"))
			label.add_theme_constant_override("outline_size",9)
			label.position = Vector2(0,row*256)
			label.size = Vector2(256,256)
			view.add_child(label)
	return view


func _build_cabinet() -> void:
	box(Vector3(2.58,1.53,0.36),Vector3(0,0,-0.65),toy_material(Color("46734d")),0.20)
	box(Vector3(2.48,1.46,0.25),Vector3(0,0,-0.28),toy_material(Color("a1d77b")),0.18)
	box(Vector3(2.29,1.16,0.10),Vector3(0,0,0.07),toy_material(Color("554d3d")),0.14)
	var cream: ShaderMaterial = toy_material(Color("fff0c9"))
	for side: float in [-1.0,1.0]:
		box(Vector3(2.40,0.54,0.17),Vector3(0,side*1.10,0.82),cream,0.13)
		box(Vector3(0.22,0.78,0.16),Vector3(side*2.18,0,0.82),cream,0.10)
		box(Vector3(0.11,0.78,0.16),Vector3(side*0.675,0,0.82),cream,0.07)
	box(Vector3(1.34,0.20,0.14),Vector3(0,1.11,0.92),toy_material(Color("649f48")),0.13)
	var title: Label3D = sign_label("777",112,0.0040,Color("fff1bb"))
	title.position = Vector3(0,1.11,1.08)
	_sign = sign_label("",64,0.0036,Color("46734d"))
	_sign.position = Vector3(0,-1.11,1.02)
	# Physical arrows mark only the centre payline, never a fake near-miss row.
	for side: float in [-1.0,1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		RouletteSpin3D.triangle(st,Vector3(side*2.32,-0.12,1.01),Vector3(side*2.32,0.12,1.01),Vector3(side*2.08,0,1.01),Vector3.BACK,Color("649f48"))
		var arrow := MeshInstance3D.new()
		arrow.mesh = st.commit()
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.vertex_color_use_as_albedo = true
		arrow.material_override = paint
		_cabinet.add_child(arrow)
	_lever = Node3D.new()
	_lever.position = Vector3(2.61,-0.15,0)
	_cabinet.add_child(_lever)
	var bar := MeshInstance3D.new()
	bar.mesh = MahjongSlam3D.rounded_box(Vector3(0.07,0.53,0.07),0.06)
	bar.position = Vector3(0,0.42,0)
	bar.material_override = toy_material(Color("d6c287"))
	_lever.add_child(bar)
	var handle := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.20
	ball.height = 0.4
	ball.radial_segments = 16
	ball.rings = 8
	handle.mesh = ball
	handle.position = Vector3(0,1.02,0)
	handle.material_override = toy_material(Color("eb83a7"))
	_lever.add_child(handle)


func sign_label(text: String, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 4
	label.modulate = color
	label.outline_modulate = Color("fff4d6")
	label.shaded = false
	_cabinet.add_child(label)
	return label


static func toy_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("cream",color)
	return material


func box(half: Vector3, at: Vector3, material: Material, radius: float) -> void:
	radius = minf(radius,minf(half.x,minf(half.y,half.z)))
	var key: String = "%s/%s" % [half,radius]
	if not _box_meshes.has(key):
		_box_meshes[key] = MahjongSlam3D.rounded_box(half,radius)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_meshes[key]
	mesh.position = at
	mesh.material_override = material
	_cabinet.add_child(mesh)


func begin(values: Array, power: float = 0.5) -> void:
	result_values.clear()
	for index: int in 3:
		result_values.append(clampi(int(values[index]),0,5))
	_power = clampf(power,0,1)
	stopped = [false,false,false]
	winning_reels = matching_reels(result_values)
	settled = false
	_time = 0.0
	_last_whirr = -1.0
	_announced = false
	_sign.text = ""
	for i: int in 3:
		_lamp_materials[i].set_shader_parameter("cream",Color("7f936b"))
		_frame_materials[i].set_shader_parameter("cream",Color("e5cd91"))
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	apply_time(0.0)


func stop_rendering() -> void:
	if render_view != null:
		render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func apply_time(seconds: float) -> void:
	_time = maxf(seconds,0.0)
	var reaction: float = 0.0
	for i: int in 3:
		drums[i].rotation.x = angle_at(_time,i,result_values[i],_power)
		var velocity: float = absf(angle_at(_time+0.001,i,result_values[i],_power)-angle_at(_time,i,result_values[i],_power))/0.001
		_materials[i].set_shader_parameter("blur",clampf(velocity/24.0,0,1))
		var since: float = _time-STOP_TIMES[i]
		if since>=0 and since<SETTLE_TIME:
			reaction += 0.025*sin(since/SETTLE_TIME*TAU)*pow(1.0-since/SETTLE_TIME,2)
		if since>=0 and not stopped[i]:
			stopped[i] = true
			reel_stopped.emit(i)
			_lamp_materials[i].set_shader_parameter("cream",Color("a1db64"))
			if since<0.07:
				Sfx.play(&"slot_stop",-3.0,0.0,0.94+i*0.08)
	if _time<STOP_TIMES[2] and _time>=LEAD_TIME and _time-_last_whirr>=0.16:
		Sfx.play(&"slot_spin",-17.0,0.0)
		_last_whirr = _time
	_cabinet.position.y = reaction
	var handle_phase: float = clampf(_time/0.30,0,1)
	_lever.rotation.x = -0.75*sin(handle_phase*PI)
	settled = _time>=RESULT_TIME
	if settled and not _announced:
		_announced = true
		var payout: int = ToolSlot777.steps_for(result_values)
		_sign.text = result_title(result_values)
		for i: int in 3:
			if winning_reels[i]:
				_lamp_materials[i].set_shader_parameter("cream",Color("ffd45f"))
				_frame_materials[i].set_shader_parameter("cream",Color("eab03f"))
		if payout>1 and _time-RESULT_TIME<0.08:
			Sfx.play(&"good",-4.0 if payout==20 else -9.0,0.0)
	if settled:
		_cabinet.position.y = 0.0
		_lever.rotation.x = 0.0


func displayed_values() -> Array[int]:
	var values: Array[int] = []
	for drum: Node3D in drums:
		values.append(symbol_at(drum.rotation.x))
	return values


static func strip_row(symbol: int) -> int:
	return posmod(-symbol,6)


static func symbol_at(angle: float) -> int:
	return posmod(int(floor(angle/STEP+0.5)),6)


static func matching_reels(values: Array[int]) -> Array[bool]:
	return [values[0]==values[1] or values[0]==values[2],values[1]==values[0] or values[1]==values[2],values[2]==values[0] or values[2]==values[1]]


static func result_title(values: Array[int]) -> String:
	match ToolSlot777.steps_for(values):
		20: return "777 잭팟!"
		8: return "3개 일치!"
		4: return "2개 일치!"
	return "일치 없음"


static func angle_at(seconds: float, index: int, symbol: int, power: float) -> float:
	var stop: float = STOP_TIMES[index]
	var turns: int = 2+int(roundf(clampf(power,0,1)*2))+index
	var distance: float = turns*TAU+fposmod(symbol*STEP-STARTS[index],TAU)
	var coast: float = stop-LEAD_TIME-ACCEL_TIME-BRAKE_TIME
	var area: float = ACCEL_TIME*0.5+coast+BRAKE_TIME*0.25
	var t: float = clampf(seconds-LEAD_TIME,0,stop-LEAD_TIME)
	var progress: float
	if t<=ACCEL_TIME:
		progress = t*t/(2*ACCEL_TIME*area)
	elif t<=ACCEL_TIME+coast:
		progress = (ACCEL_TIME*0.5+t-ACCEL_TIME)/area
	else:
		var u: float = clampf((t-ACCEL_TIME-coast)/BRAKE_TIME,0,1)
		progress = (ACCEL_TIME*0.5+coast+BRAKE_TIME*(1-pow(1-u,4))*0.25)/area
	var angle: float = STARTS[index]+distance*progress
	if seconds>=stop:
		var settle: float = clampf((seconds-stop)/SETTLE_TIME,0,1)
		angle += 0.035*sin(settle*TAU)*pow(1-settle,2)
	return angle


static func make_drum_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for segment: int in 193:
		var theta: float = segment*TAU/192.0
		var normal := Vector3(0,sin(theta),cos(theta))
		for side: int in 2:
			vertices.append(Vector3((-1.0 if side==0 else 1.0)*REEL_HALF_WIDTH,normal.y*REEL_RADIUS,normal.z*REEL_RADIUS))
			normals.append(normal)
			uvs.append(Vector2(side,0.5/6.0-theta/TAU))
		if segment<192:
			var a: int = segment*2
			indices.append_array(PackedInt32Array([a,a+3,a+1,a,a+2,a+3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
