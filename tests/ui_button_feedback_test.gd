extends SceneTree
## Real pointer input checks shared, custom, textured and child-painted buttons.
var failed:=false
var clicks:=0
var output:=OS.get_environment("BUTTON_CAPTURE_DIR")

func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i: int in 5: await process_frame
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed=true
		push_error(message)
func move(at: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=at
	event.global_position=at
	root.push_input(event)
	await settle()
func press(at: Vector2, down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=at
	event.global_position=at
	event.pressed=down
	root.push_input(event)
	await settle()
func capture(label: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	root.size=Vector2i(1366,768)
	var page:=Control.new()
	root.add_child(page)
	var buttons: Array[Button]=[]
	for i: int in 4:
		var item:=Button.new()
		item.position=Vector2(40+i*230,150)
		item.size=Vector2(200,70)
		item.text=["Shared","Custom","Artwork","Child artwork"][i]
		item.pressed.connect(func() -> void: clicks+=1)
		if i==0: UiSkin.button(item)
		elif i==1:
			for state: String in ["normal","hover","pressed","disabled"]:
				item.add_theme_stylebox_override(state,UiSkin.surface(Color("79bdaa"),Color("315d50"),2,18,0,10))
		elif i==2:
			HubArt.button(item,&"round_button",70)
			item.size.x=70
		else:
			for state: String in ["normal","hover","pressed","disabled"]:
				item.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			var art:=Panel.new()
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.mouse_filter=Control.MOUSE_FILTER_IGNORE
			art.add_theme_stylebox_override("panel",UiSkin.surface(Color("d8bcf0"),Color("62437f"),2,30))
			item.add_child(art)
			item.move_child(art,0)
		buttons.append(item)
		page.add_child(item)
	await settle()
	await move(Vector2(5,5))
	await capture("normal")
	for i: int in buttons.size():
		var item:=buttons[i]
		var geometry:=item.get_global_rect()
		var minimum:=item.get_combined_minimum_size()
		await move(geometry.get_center())
		expect(item.get_draw_mode()==BaseButton.DRAW_HOVER,"Pointer hover must activate")
		await capture("hover-%s"%i)
		await press(geometry.get_center(),true)
		expect(item.get_draw_mode()==BaseButton.DRAW_PRESSED,"Held pointer must press")
		expect(item.get_global_rect()==geometry and item.get_combined_minimum_size()==minimum,"Feedback must preserve layout and hitbox")
		await capture("pressed-%s"%i)
		await press(geometry.get_center(),false)
		expect(clicks==i+1,"Each click must execute exactly once")
		item.disabled=true
		await settle()
		if i==3: expect(item.modulate==Color.WHITE,"Disabled child artwork must clear hover tint")
		await press(geometry.get_center(),true)
		await press(geometry.get_center(),false)
		expect(clicks==i+1,"Disabled button cannot execute")
		item.disabled=false
	# Repeated selection/style refresh must not accumulate drivers or change normal art.
	var custom:=buttons[1]
	for i: int in 8:
		var face:=UiSkin.surface(Color("adcfe0"),Color("315d50"),2,18,0,10)
		custom.add_theme_stylebox_override("normal",face)
		await settle()
		expect(custom.get_theme_stylebox("normal")==face,"Selection face must stay intact")
	expect(custom.get_children().filter(func(node: Node) -> bool: return node.name=="ButtonFeedback").size()==1,"Dynamic reskin must retain one driver")
	page.queue_free()
	await settle()
	print("GLOBAL_BUTTON_FEEDBACK_OK" if not failed else "GLOBAL_BUTTON_FEEDBACK_FAILED")
	quit(1 if failed else 0)
