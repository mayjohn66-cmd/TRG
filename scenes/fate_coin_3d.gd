## Fixed-outcome coin toss for SUPER_01. Presentation never rolls gameplay RNG.
extends Node2D

const TOSS_TIME := 1.05
const VIEW_SIZE := Vector2(230,230)
var render_view: SubViewport
var rotor: Node3D
var sprite: Sprite2D
var caption: Label
var settled := false
var success := false
var progress := 0.0

func _ready() -> void:
	name = "FateCoin3D"
	z_index = 40
	render_view = SubViewport.new()
	render_view.size = Vector2i(512,512)
	render_view.own_world_3d = true
	render_view.transparent_bg = true
	render_view.gui_disable_input = true
	render_view.msaa_3d = Viewport.MSAA_2X
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(render_view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.3
	camera.position = Vector3(0,0,6)
	render_view.add_child(camera)
	camera.current = true
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("fff0cb")
	world.environment.ambient_light_energy = 0.7
	render_view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28,-30,0)
	key.light_energy = 1.1
	render_view.add_child(key)
	rotor = Node3D.new()
	rotor.name = "TwoSidedCoin"
	render_view.add_child(rotor)
	var gold := paint(Color("f6be43"),0.45)
	var rim := paint(Color("ffde7c"),0.40)
	disc("Edge",1.04,1.04,0.16,0.0,gold)
	disc("FrontBevel",0.97,1.04,0.065,0.112,rim)
	disc("BackBevel",1.04,0.97,0.065,-0.112,rim)
	disc("GoldFace",0.86,0.86,0.018,0.15,paint(Color("eaa12b"),0.30))
	disc("RedFace",0.86,0.86,0.018,-0.15,paint(Color("b33b48"),0.05))
	# Raised, simple symbols stay legible at game size: star / cross.
	var star := PackedVector2Array()
	for index: int in 10:
		var angle := -PI/2.0+index*PI/5.0
		star.append(Vector2(cos(angle),sin(angle))*(0.57 if index%2==0 else 0.26))
	mark(star,0.18,false,paint(Color("fff1b1"),0.1))
	for angle: float in [-PI/4.0,PI/4.0]:
		var points := PackedVector2Array()
		for corner: Vector2 in [Vector2(-0.12,-0.58),Vector2(0.12,-0.58),Vector2(0.12,0.58),Vector2(-0.12,0.58)]:
			points.append(corner.rotated(angle))
		mark(points,-0.18,true,paint(Color("fff0dd"),0.0))
	for index: int in 24:
		var angle := TAU*index/24.0
		var rib := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.035,0.07,0.12)
		rib.mesh = box
		rib.position = Vector3(cos(angle),sin(angle),0)
		rib.rotation.z = angle
		rib.material_override = rim
		rotor.add_child(rib)
	sprite = Sprite2D.new()
	sprite.texture = render_view.get_texture()
	sprite.scale = VIEW_SIZE/Vector2(render_view.size)
	add_child(sprite)
	caption = Label.new()
	caption.position = Vector2(-150,78)
	caption.size = Vector2(300,48)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",30)
	caption.add_theme_color_override("font_color",Color("fff0b3"))
	caption.add_theme_color_override("font_outline_color",Color("302033"))
	caption.add_theme_constant_override("outline_size",7)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)

func play(result: bool, pace: float = 1.0) -> void:
	success = result
	settled = false
	caption.text = ""
	var toss := create_tween()
	toss.tween_method(seek,0.0,1.0,TOSS_TIME*pace)

func seek(value: float) -> void:
	progress = clampf(value,0.0,1.0)
	var turn := 1.0-pow(1.0-progress,2.1)
	rotor.rotation = Vector3((TAU*4.0+(0.0 if success else PI))*turn,0.14*sin(progress*TAU),0.12*sin(progress*PI))
	sprite.position.y = -110.0*sin(progress*PI)
	sprite.scale = VIEW_SIZE/Vector2(render_view.size)*(1.0+0.12*sin(progress*PI))
	settled = progress>=1.0
	if settled:
		caption.text = "완주!" if success else "출발선 추방"
		caption.add_theme_color_override("font_color",Color("ffe28c") if success else Color("ffb1b1"))
	render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func _draw() -> void:
	var shadow := PackedVector2Array()
	for index: int in 40:
		var angle := TAU*index/40.0
		shadow.append(Vector2(cos(angle)*45.0,sin(angle)*9.0+68.0))
	draw_colored_polygon(shadow,Color(0.15,0.10,0.08,0.24*(1.0-0.6*sin(progress*PI))))

func disc(node_name: String, top: float, bottom: float, height: float, z: float, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 64
	item.mesh = mesh
	item.rotation.x = PI/2.0
	item.position.z = z
	item.material_override = material
	rotor.add_child(item)

func mark(points: PackedVector2Array, z: float, reverse: bool, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for index: int in indices:
		tool.set_normal(Vector3(0,0,-1 if reverse else 1))
		tool.add_vertex(Vector3(points[index].x,-points[index].y,z))
	var item := MeshInstance3D.new()
	item.mesh = tool.commit()
	item.material_override = material
	rotor.add_child(item)

func paint(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
