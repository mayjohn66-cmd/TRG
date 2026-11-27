extends SceneTree
var failures: Array[String] = []
var count := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	count+=1
	if not ok: failures.append(message)
func frames(n: int=4) -> void:
	for i: int in n: await process_frame
func run() -> void:
	L10n.install()
	root.content_scale_size = Vector2i(1366,768)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	for resolution: Vector2i in [Vector2i(1366,768),Vector2i(844,390)]:
		root.size=resolution
		MobileSupport.force_touch=resolution.x<1000
		for language: String in ["ko","en","ja"]:
			L10n.set_language(language)
			for id: StringName in ToolPick.SPECS:
				var modal := ToolPickModal.new()
				modal.setup(id)
				host.add_child(modal)
				var emitted: Array = []
				modal.picked.connect(func(indices: Array[int]) -> void: emitted.append(indices))
				await frames()
				var panel := modal.find_child("PickPanel",true,false) as Control
				check(root.get_visible_rect().encloses(panel.get_global_rect()),"Panel outside viewport: %s %s %s" % [id,language,resolution])
				check(modal.item_count()==ToolPick.count_of(id),"Candidate count: %s" % id)
				check(emitted.is_empty(),"Premature roll: %s" % id)
				if ToolPick.choose_of(id)>1:
					var item := modal.find_child("PickItem0",true,false) as Control
					var touch := InputEventScreenTouch.new()
					touch.pressed=true
					item.gui_input.emit(touch)
					var mouse := InputEventMouseButton.new()
					mouse.button_index=MOUSE_BUTTON_LEFT
					mouse.pressed=true
					item.gui_input.emit(mouse)
					check(modal.picks()==[0],"Touch-emulated mouse must not toggle twice: %s" % id)
					modal.pick(0)
					check(modal.picks().is_empty(),"Selection toggle: %s" % id)
				for index: int in ToolPick.choose_of(id): modal.pick(index)
				modal.pick(-1)
				modal.pick(0)
				await create_timer(0.43).timeout
				check(emitted.size()==1,"Single completion: %s" % id)
				if emitted.size()==1:
					check(ToolPick.sanitize(id,emitted[0]).size()==ToolPick.choose_of(id),"Valid selected order: %s" % id)
				modal.queue_free()
				await frames(1)
	MobileSupport.force_touch=false
	if failures.is_empty(): print("TOOL_PICK_PRESENTATION_OK: ",count," checks");quit(0)
	else:
		for failure: String in failures: printerr("TOOL_PICK_PRESENTATION_FAIL ",failure)
		quit(1)
