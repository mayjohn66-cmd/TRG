extends SceneTree
const MODELS := [
	["Cookie","res://assets/models/fortune_cookie/fortune-cookie-whole.glb"],
	["Capsule machine","res://assets/models/capsule_gacha/machine.glb"],
	["Pirate","res://assets/models/pirate_roulette/blender_v3/pirate_figure.glb"],
	["Vending machine","res://assets/models/vending/monatium_vending_v02.tscn"],
]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder:=OS.get_cmdline_user_args()[0]
	var file:=FileAccess.open(folder.path_join("runtime-map.json"),FileAccess.READ)
	var mapping: Dictionary=JSON.parse_string(file.get_as_text())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,1120)
	var host:=Control.new()
	host.size=Vector2(root.size)
	root.add_child(host)
	var background:=ColorRect.new()
	background.color=Color("f5f1e6")
	background.size=host.size
	host.add_child(background)
	for row: int in MODELS.size():
		var original: Node3D=load(MODELS[row][1]).instantiate()
		var bounds:=model_bounds(original)
		original.free()
		for column: int in 2:
			var at:=Vector2(column*640,row*280)
			var label:=Label.new()
			label.text=str(MODELS[row][0])+ (" | Original" if column==0 else " | Low poly")
			label.add_theme_color_override("font_color",Color("245c46"))
			label.add_theme_font_size_override("font_size",22)
			label.size=Vector2(640,30)
			label.position=at
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			host.add_child(label)
			var view:=SubViewport.new()
			view.size=Vector2i(1280,500)
			view.transparent_bg=true
			view.own_world_3d=true
			view.msaa_3d=Viewport.MSAA_2X
			host.add_child(view)
			var display:=TextureRect.new()
			display.texture=view.get_texture()
			display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			display.size=Vector2(640,250)
			display.position=at+Vector2(0,30)
			host.add_child(display)
			var environment:=WorldEnvironment.new()
			environment.environment=Environment.new()
			environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color=Color("fff7e8")
			environment.environment.ambient_light_energy=.4
			view.add_child(environment)
			var lamp:=DirectionalLight3D.new()
			lamp.rotation_degrees=Vector3(-45,-35,0)
			lamp.light_energy=.9
			view.add_child(lamp)
			var model: Node3D=load(MODELS[row][1] if column==0 else mapping[MODELS[row][1]]).instantiate()
			view.add_child(model)
			var center:=bounds.get_center()
			var diameter:=bounds.size.length()
			var camera:=Camera3D.new()
			camera.projection=Camera3D.PROJECTION_ORTHOGONAL
			camera.size=maxf(bounds.size.y,bounds.size.x/2.56)*1.2
			view.add_child(camera)
			camera.position=center+Vector3(.22,.28,1).normalized()*diameter*2
			camera.look_at(center)
			camera.current=true
	for i: int in 6: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("original-vs-lowpoly.png"))
	print("LOWPOLY_PREVIEW_OK")
	quit()
func model_bounds(root_node: Node3D) -> AABB:
	var first:=true
	var total: AABB
	for child: Node in root_node.find_children("*","MeshInstance3D",true,false):
		var mesh:=child as MeshInstance3D
		var pose:=mesh.transform
		var ancestor:=mesh.get_parent()
		while ancestor is Node3D:
			pose=(ancestor as Node3D).transform*pose
			ancestor=ancestor.get_parent()
		var box: AABB=pose*mesh.get_aabb()
		total=box if first else total.merge(box)
		first=false
	return total
