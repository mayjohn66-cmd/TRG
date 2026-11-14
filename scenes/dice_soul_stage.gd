## Shared rounded D6 geometry, one transparent 3D world, no gameplay RNG or physics.
extends Control
const INTRO_SECONDS := 3.25
const FRONT_AT := 2.05
const MORPH_AT := 2.40
const PRINT_AT := 3.00
const ART = preload("res://scenes/cutscene_print_art.gd")
const HANDOFF_SECONDS := 0.65
const FADE_SECONDS := 0.42
const RAIN_COUNT := 54
const HERO_FACES := [1,3,6]
const MOTIF=preload("res://scenes/victory_motif_layout.gd")
var render_view: SubViewport
var camera: Camera3D
var heroes: Array[Node3D] = []
var rain: Array[MultiMesh] = []
var _surface: TextureRect
var _last_time := -99.0
var _last_view := Vector2.ZERO
var icon_mode := false
var prints: Array[TextureRect] = []
var _surface_ink: ShaderMaterial

func _init() -> void:
	name = "DiceSoulStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func _ready() -> void:
	render_view = SubViewport.new()
	render_view.name = "DiceSoulWorld"
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(render_view)
	_surface = TextureRect.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_surface.texture = render_view.get_texture()
	_surface_ink = ART.material(true,true)
	_surface.material = _surface_ink
	add_child(_surface)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 2.0
	camera.position = Vector3(0,0,20)
	camera.current = true
	render_view.add_child(camera)
	if DiceRoll3D._body_mesh==null: DiceRoll3D._body_mesh = DiceRoll3D._make_body_mesh()
	var cream := ShaderMaterial.new()
	cream.shader = DiceRoll3D.BODY_SHADER
	cream.set_shader_parameter("cream",Color("fff5da"))
	var ink := ShaderMaterial.new()
	ink.shader = DiceRoll3D.OUTLINE_SHADER
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	for material: Material in [ink,cream,paint]:
		var mesh := DiceRoll3D._pip_mesh_for(&"D6") if material==paint else DiceRoll3D._body_mesh
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		batch.instance_count = RAIN_COUNT
		var instances := MultiMeshInstance3D.new()
		instances.multimesh = batch
		instances.material_override = material
		render_view.add_child(instances)
		rain.append(batch)
	for i: int in 3:
		var die := Node3D.new()
		die.name = "SoulDie%d"%(i+1)
		render_view.add_child(die)
		for material: Material in [ink,cream,paint]:
			var part := MeshInstance3D.new()
			part.mesh = DiceRoll3D._pip_mesh_for(&"D6") if material==paint else DiceRoll3D._body_mesh
			part.material_override = material
			die.add_child(part)
		heroes.append(die)
	for source: Texture2D in ART.dice():
		var picture := ART.picture(source)
		picture.material = ART.material()
		add_child(picture)
		prints.append(picture)

static func _hash(i: int) -> float:
	return float(posmod(i*73+19,127))/126.0

static func _world(point: Vector2, view: Vector2, z: float) -> Vector3:
	return Vector3((point.x-0.5)*2.0*view.x/view.y,(0.5-point.y)*2.0,z)

static func rain_pose(t: float, i: int, view: Vector2) -> Transform3D:
	var age := t-float(i)*0.016
	var flight := 0.64+0.20*_hash(i+6)
	var fall := clampf(age/flight,0,1)
	var x := 0.04+0.92*_hash(i)+(0.5-_hash(i+8))*0.12*fall
	var y := lerpf(-0.22-_hash(i+2)*0.22,0.64+0.13*_hash(i+3),fall*fall)
	if age>flight:
		var bounce := clampf((age-flight)/0.32,0,1)
		y -= sin(bounce*PI)*0.10*(1-bounce)
		y += smoothstep(1.35,2.05,t)*0.60
	var turn := Quaternion.from_euler(Vector3(age*(5+_hash(i+4)*4),age*7+float(i),age*3))
	var scale := (0.038+0.045*_hash(i+5))*(1-smoothstep(1.55,2.05,t)) if age>=0 else 0.0
	return Transform3D(Basis(turn).scaled(Vector3.ONE*scale),_world(Vector2(x,y),view,-2-_hash(i+9)*3))

static func hero_pose(t: float, i: int, view: Vector2, icon: bool = false) -> Transform3D:
	if icon:
		var points := [Vector2(0.34,0.37),Vector2(0.68,0.39),Vector2(0.51,0.67)]
		var turn := Quaternion.from_euler(Vector3(-0.25,0.38 if i%2==0 else -0.38,0.14 if i==0 else -0.12))*YachtRoll3D.front_orientation(HERO_FACES[i])
		return Transform3D(Basis(turn).scaled(Vector3.ONE*0.235),_world(points[i],view,float(i)*0.5))
	var rise := smoothstep(1.12,FRONT_AT,t)
	var handoff := smoothstep(INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS,t)
	var age := t-(0.28+float(i)*0.13)
	var fall := clampf(age/0.84,0,1)
	var landing := Vector2(0.23+float(i)*0.27,0.62+float(i%2)*0.03)
	var point := Vector2(landing.x+sin(fall*PI)*0.035,lerpf(-0.25,landing.y,fall*fall))
	point = point.lerp(Vector2(0.30+float(i)*0.20,0.46),rise)
	point = point.lerp(Vector2(0.04+float(i)*0.35,0.68-float(i)*0.15),handoff)
	var stop_age := 1.12-(0.28+float(i)*0.13)
	var tumble := Quaternion.from_euler(Vector3(stop_age*9+float(i),stop_age*7,stop_age*4))
	var turn := tumble.slerp(YachtRoll3D.front_orientation(HERO_FACES[i]),rise)
	if rise<=0.0: turn = Quaternion.from_euler(Vector3(age*9+float(i),age*7,age*4))
	var scale := lerpf(lerpf(0.072,0.215,rise),0.64,handoff) if age>=0 else 0.0
	return Transform3D(Basis(turn).scaled(Vector3.ONE*scale),_world(point,view,2.0+float(i)*0.04))

func seek(t: float, view: Vector2) -> void:
	size = view
	if render_view==null: return
	_surface.size = view
	var sampled := minf(t,INTRO_SECONDS+HANDOFF_SECONDS)
	if is_equal_approx(sampled,_last_time) and view==_last_view: return
	_last_time = sampled; _last_view = view
	var pixels := view*minf(1.25,1600.0/maxf(view.x,1.0))
	render_view.size = Vector2i(maxi(32,roundi(pixels.x)),maxi(32,roundi(pixels.y)))
	for i: int in RAIN_COUNT:
		var frame := rain_pose(sampled,i,view)
		for batch: MultiMesh in rain: batch.set_instance_transform(i,frame)
	for i: int in heroes.size(): heroes[i].transform = hero_pose(sampled,i,view,icon_mode)
	var mix := smoothstep(MORPH_AT,PRINT_AT,sampled) if not icon_mode else 0.0
	var areas := PackedVector4Array()
	for i: int in prints.size():
		var frame := heroes[i].transform
		var center := Vector2(0.5+frame.origin.x/(2.0*view.x/view.y),0.5-frame.origin.y/2.0)*view
		var extent := Vector2.ONE*view.y*frame.basis.get_scale().x*1.05
		var picture := prints[i]
		picture.position=center-extent*0.5;picture.size=extent
		picture.visible=mix>0
		picture.modulate.a=MOTIF.opacity("LAW_07",sampled,INTRO_SECONDS,INTRO_SECONDS+HANDOFF_SECONDS) if not icon_mode else 1.0
		(picture.material as ShaderMaterial).set_shader_parameter("dimensions",extent)
		(picture.material as ShaderMaterial).set_shader_parameter("amount",mix)
		areas.append(Vector4(picture.position.x/view.x,picture.position.y/view.y,extent.x/view.x,extent.y/view.y))
	_surface_ink.set_shader_parameter("dimensions",view)
	_surface_ink.set_shader_parameter("areas",areas)
	_surface_ink.set_shader_parameter("amount",mix)
	_surface.visible=mix<1.0
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE if _surface.visible else SubViewport.UPDATE_DISABLED
