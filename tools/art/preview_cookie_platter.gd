extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder:=OS.get_cmdline_user_args()[0]
	var file:=FileAccess.open(folder.path_join("model-report.json"),FileAccess.READ)
	var report: Dictionary=JSON.parse_string(file.get_as_text())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1100,900)
	var holder:=Control.new()
	holder.size=Vector2(1100,900)
	root.add_child(holder)
	var background:=ColorRect.new()
	background.size=holder.size;background.color=Color("fff9ed")
	holder.add_child(background)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1100,900);viewport.transparent_bg=true;viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	holder.add_child(viewport)
	var display:=TextureRect.new()
	display.size=holder.size;display.texture=viewport.get_texture()
	holder.add_child(display)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("fff5e5")
	world.environment.ambient_light_energy=.35
	world.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	viewport.add_child(world)
	for entry: Array in [[Vector3(-4,7,5),.8],[Vector3(5,5,2),.35],[Vector3(0,7,-5),.5]]:
		var lamp:=DirectionalLight3D.new()
		viewport.add_child(lamp)
		lamp.position=entry[0]
		lamp.look_at(Vector3(0,.4,0))
		lamp.light_energy=entry[1]
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	var error:=document.append_from_file("res://art_source/selection_props/cookie_platter_v1/ceramic_plate.glb",state)
	assert(error==OK,"Plate GLB import failed")
	var plate:=document.generate_scene(state)
	var plate_scene:=PackedScene.new()
	assert(plate_scene.pack(plate)==OK)
	var native_path:="res://assets/models/fortune_cookie/platter_v1/plate_runtime.scn"
	assert(ResourceSaver.save(plate_scene,native_path,ResourceSaver.FLAG_COMPRESS)==OK)
	viewport.add_child(plate)
	var heap_path:="res://assets/models/fortune_cookie/platter_v1/cookie_platter_heaped.tscn"
	var heap_file:=FileAccess.open(heap_path,FileAccess.READ)
	var text:=heap_file.get_as_text().replace("ceramic_plate.glb","plate_runtime.scn")
	heap_file.close()
	heap_file=FileAccess.open(heap_path,FileAccess.WRITE)
	heap_file.store_string(text);heap_file.close()
	var saved:=load(heap_path) as PackedScene
	assert(saved!=null,"Saved platter scene failed to load")
	var check:=saved.instantiate()
	assert(check.find_children("PickCookie_*","Node3D",true,false).size()==16)
	check.free()
	report["plate_source_bytes"]=report.plate_bytes
	report["plate_runtime_bytes"]=FileAccess.get_file_as_bytes(native_path).size()
	report["scene_bytes"]=FileAccess.get_file_as_bytes(heap_path).size()
	report["total_new_runtime_bytes"]=int(report.plate_runtime_bytes)+int(report.scene_bytes)
	var report_out:=FileAccess.open(folder.path_join("model-report.json"),FileAccess.WRITE)
	report_out.store_string(JSON.stringify(report,"  "));report_out.close()
	var source:=load("res://assets/models/fortune_cookie/fortune-cookie-whole.glb") as PackedScene
	var shared: Dictionary={}
	var count:=0
	for raw: Array in report.cookie_transforms_godot:
		var instance:=source.instantiate() as Node3D
		instance.name="PickCookie_%02d" % [count+1]
		viewport.add_child(instance)
		instance.transform=Transform3D(Basis(Vector3(raw[0],raw[1],raw[2]),Vector3(raw[3],raw[4],raw[5]),Vector3(raw[6],raw[7],raw[8])),Vector3(raw[9],raw[10],raw[11]))
		assert(instance.transform.is_finite())
		for child: Node in instance.find_children("*","MeshInstance3D",true,false):
			shared[(child as MeshInstance3D).mesh.get_rid().get_id()]=true
		count+=1
	assert(count==16)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.0
	viewport.add_child(camera);camera.position=Vector3(4,6,6);camera.look_at(Vector3(0,.55,0));camera.current=true
	for i: int in 8: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("cookie-platter-godot.png"))
	print("COOKIE_PLATTER_GODOT_OK: ",count," cookies, ",shared.size()," shared mesh resources")
	quit()
