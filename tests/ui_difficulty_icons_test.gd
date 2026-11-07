## Difficulty selection only: actual button input, image states, records and idle cleanup.
extends SceneTree

var failures: Array[String] = []
var picker: FireLevelPicker
var selected: Array[int] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func capture(label: String) -> void:
	var folder := OS.get_environment("DIFFICULTY_ICONS_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func click(button: Button) -> void:
	var at := button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func run() -> void:
	create_timer(35).timeout.connect(func() -> void: printerr("UI_DIFFICULTY_ICONS_FAIL timeout"); quit(1))
	# Test-only in-memory profile: status rendering must not write player records.
	PlayerSave.use_browser = false
	PlayerSave._data = PlayerSave.blank()
	PlayerSave._data["cleared_buldak"] = {"2":{"clears":1,"best_round":18},"4":{"clears":1,"best_round":24}}
	PlayerSave._loaded = true
	var records := PlayerSave.data().duplicate(true)
	var bg := ColorRect.new()
	bg.color = Color("fbf6df")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	picker = FireLevelPicker.create(1)
	picker.position = Vector2(365,190)
	picker.size = Vector2(620,350)
	root.add_child(picker)
	picker.level_chosen.connect(func(value: int) -> void: selected.append(value))
	await process_frame
	await process_frame
	root.notify_mouse_entered()
	check(DifficultyArt.FACES.get_width()<=1024,"face atlas stays within its bounded UI import size")
	for texture: Texture2D in [DifficultyArt.FLAME,DifficultyArt.CROWN,DifficultyArt.LOCK]:
		check(texture.get_width()<=128 and texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"small status art retains alpha and bounded import size")
	for level: int in BotTemper.ALL:
		await click(picker._cells[level])
		check(picker.level==level and picker._face.level==level and picker._bowl.level==level,"button input updates face, bowl and selected difficulty together")
		check(picker._record_icon.kind==(&"crown" if level in [2,4] else &"lock"),"the selected record uses the actual completion state")
		for step: int in BotTemper.ALL:
			check(picker._crowns[step].kind==(&"crown" if step in [2,4] else &"lock"),"status icons distinguish cleared from uncompleted, independently of selection")
			var flame: FireLevelPicker.FlameIcon = picker._cells[step].find_child("Flame",true,false)
			check(flame.lit==(step<=level) and (flame.material==null)==(step<=level),"only reached flame cells retain orange; others use the muted art shader")
		for alternate: bool in [false,true]:
			var region := DifficultyArt.face_region(level,alternate)
			check(region.has_area() and Rect2(Vector2.ZERO,DifficultyArt.FACES.get_size()).encloses(region),"all ten expression frames are nonempty and inside their atlas")
		picker._face._reaction = 1.0
		picker._face._time = 0.2
		picker._face.queue_redraw()
		await capture("level_%d" % level)
		picker._face._time = 3.72 if level in [1,3] else (1.8 if level==2 else 0.5)
		picker._face.queue_redraw()
		await capture("level_%d_alternate" % level)
	check(selected==[1,2,3,4,5],"each actual button click emits exactly one selection")
	check(PlayerSave.data()==records,"selection and animated icons never alter completion records")
	picker.hide()
	await process_frame
	check(not picker._face.is_processing() and not picker._bowl.is_processing(),"hidden selector stops animated face and bowl")
	for step: int in BotTemper.ALL:
		check(not picker._cells[step].find_child("Flame",true,false).is_processing(),"hidden selector stops every flame")
	picker.show()
	await process_frame
	check(picker._face.is_processing(),"visible selector resumes its facial animation")
	picker.queue_free()
	await process_frame
	# The production menu must route the same real button clicks to GameSession.
	var menu: StartMenu = (load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	menu.change_scene_enabled = false
	root.add_child(menu)
	menu.open_training()
	for index: int in 4: await process_frame
	var embedded: FireLevelPicker = menu.find_child("FireLevelPicker",true,false)
	check(embedded!=null and embedded.is_visible_in_tree(),"the actual training menu embeds the painted selector")
	for level: int in [2,5]:
		await click(embedded._cells[level])
		check(GameSession.bot_difficulty()==level and embedded.level==level,"production menu input persists the requested difficulty")
		embedded._face._reaction = 1.0
		embedded._face.queue_redraw()
		await capture("training_level_%d" % level)
	check(PlayerSave.data().get("cleared_buldak")==records.get("cleared_buldak"),"production selection preserves the user's completion records")
	menu.queue_free()
	await process_frame
	if failures.is_empty():
		print("UI_DIFFICULTY_ICONS_OK")
		quit(0)
	else:
		for failure: String in failures: printerr("UI_DIFFICULTY_ICONS_FAIL: "+failure)
		quit(1)
