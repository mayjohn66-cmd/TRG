extends SceneTree

var failures: Array[String] = []
var capturing := false

func _initialize() -> void:
	capturing = OS.get_environment("AVATAR_HQ_CAPTURE_DIR")!=""
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	for id: StringName in AvatarCatalog.ids():
		var path := AvatarSlot.character_path(id)+"/idle_hq.tres"
		check(ResourceLoader.exists(path),str(id)+" HQ resource exists")
		if not ResourceLoader.exists(path): continue
		var frames := load(path) as SpriteFrames
		check(frames!=null and frames.has_animation(&"idle"),str(id)+" idle animation")
		if frames==null:continue
		var count := frames.get_frame_count(&"idle")
		check(count>=32,str(id)+" full animation frame count")
		check(is_equal_approx(frames.get_animation_speed(&"idle"),HubKit.IdleLoop.FPS),str(id)+" runtime playback cadence")
		var common := Rect2()
		for index: int in count:
			var frame := frames.get_frame_texture(&"idle",index) as AtlasTexture
			check(frame!=null,str(id)+" atlas texture")
			if frame==null:continue
			check(frame.atlas.get_size()==Vector2(1024,1024),str(id)+" HQ imported resolution")
			if index==0:common=frame.region
			check(frame.region==common,str(id)+" stable common crop")
			check(Rect2(Vector2.ZERO,frame.atlas.get_size()).encloses(frame.region),str(id)+" crop stays inside source")
		var actor := HubKit.avatar_full(id,AvatarCatalog.color_of(id),620)
		actor.position=Vector2(683-actor.custom_minimum_size.x/2.0,80)
		host.add_child(actor)
		var title := Label.new()
		title.text=AvatarCatalog.name_of(id)+"  ·  HQ 1024 / 16 FPS"
		title.add_theme_font_size_override("font_size",28)
		title.position=Vector2(400,24);host.add_child(title)
		var loop: HubKit.IdleLoop = null
		for child: Node in actor.get_children():
			if child is HubKit.IdleLoop:loop=child
		check(loop!=null and loop._frames.size()==count,str(id)+" actual lobby selects HQ loop")
		if loop!=null:
			loop.set_process(false)
			loop._clock=0.0
			loop._process(0.0)
			var first: Texture2D=loop.texture
			loop._process(1.0/HubKit.IdleLoop.FPS+0.001)
			check(loop.texture!=first,str(id)+" idle advances")
			if capturing:
				for index: int in [0,count/2,count-1]:
					loop.texture=frames.get_frame_texture(&"idle",index)
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OS.get_environment("AVATAR_HQ_CAPTURE_DIR").path_join("%s-%02d.png" % [id,index]))
		var released: WeakRef = weakref(actor)
		actor.queue_free();title.queue_free()
		actor=null;loop=null;frames=null
		await process_frame
		check(released.get_ref()==null,str(id)+" avatar node released")
		print("AVATAR_HQ_CHARACTER_OK "+str(id)+" "+str(count))
	if failures.is_empty():print("AVATAR_HQ_OK: eight native HQ lobby loops")
	else:
		for failure: String in failures:printerr("AVATAR_HQ_FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
