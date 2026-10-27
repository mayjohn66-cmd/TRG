## Rulebook-only pointer, touch and responsive card layout checks.
extends SceneTree

var book: Rulebook
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not failures.has(message): failures.append(message)

func frames(count: int = 5) -> void:
	for index: int in count: await process_frame

func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

func mouse(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event,true)
	await frames(1)

func drag(from: Vector2, to: Vector2, touch: bool = false) -> void:
	if touch:
		var press := InputEventScreenTouch.new()
		press.position = from
		press.index = 0
		press.pressed = true
		root.push_input(press,true)
	else: await mouse(from,true)
	await frames(1)
	for step: int in range(1,9):
		var at := from.lerp(to,float(step)/8.0)
		if touch:
			var motion := InputEventScreenDrag.new()
			motion.index = 0
			motion.position = at
			motion.relative = (to-from)/8.0
			root.push_input(motion,true)
		else:
			var motion := InputEventMouseMotion.new()
			motion.position = at
			motion.global_position = at
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion,true)
		await frames(1)
	if touch:
		var release := InputEventScreenTouch.new()
		release.position = to
		release.index = 0
		release.pressed = false
		root.push_input(release,true)
	else: await mouse(to,false)
	await frames()

func capture(label: String) -> void:
	var folder := OS.get_environment("RULEBOOK_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func run() -> void:
	create_timer(80).timeout.connect(func() -> void: printerr("UI_RULEBOOK_SCROLL_FAIL timeout"); quit(1))
	PlayerSave.use_browser = false
	PlayerSave._data = PlayerSave.blank()
	PlayerSave._loaded = true
	var saved := PlayerSave.data().duplicate(true)
	AudioServer.set_bus_mute(0,true)
	root.content_scale_size = Vector2i(1366,768)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.notify_mouse_entered()
	var parent := Control.new()
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(parent)
	LobbyTheme.add_background(parent)
	L10n.install()
	for resolution: Vector2i in [Vector2i(844,390),Vector2i(740,360),Vector2i(1366,768)]:
		L10n.set_language("ko")
		root.size = resolution
		MobileSupport.force_touch = resolution.x<1000
		await frames()
		book = Rulebook.open(parent,4)
		await frames(10)
		check(is_equal_approx(book._stage.size.x,root.get_visible_rect().size.x),"Book uses available canvas width at %s" % resolution)
		for chapter: int in range(4,10):
			book.show_spread(chapter)
			await frames(10)
			var scroll := book._right_scroll
			var grid := book._right_holder.get_node("EntryGrid") as GridContainer
			check(grid.columns==(3 if MobileSupport.touch_mode() and chapter!=6 else 4),"Readable phone columns for chapter %d" % chapter)
			check(not scroll.get_h_scroll_bar().visible,"No sideways overflow in chapter %d" % chapter)
			var row_end := book._tiles[grid.columns-1].get_global_rect().end.x
			var pane_end := scroll.get_global_rect().end.x-scroll.get_v_scroll_bar().size.x
			check(absf(row_end-pane_end)<8.0,"Card columns fill the pane without a blank right-hand strip")
			for tile: Control in book._tiles:
				var face := tile.get_child(0) as Button
				check(absf(face.size.x*face.scale.x-tile.size.x)<0.1,"Card face fills its grid hit area")
				check(absf(face.size.y*face.scale.y-tile.size.y)<0.1,"Row height matches card face")
			await capture("chapter_%d_%d" % [chapter,resolution.x])
		book.show_spread(4)
		await frames()
		var scroll := book._right_scroll
		var start := point(book._tiles[0])
		await drag(start,start-Vector2(0,180))
		check(scroll.scroll_vertical>=170 and book.entry==-1,"Mouse drag on a card scrolls without opening details")
		var before := scroll.scroll_vertical
		var middle := point(scroll)
		await drag(middle,middle+Vector2(0,100),true)
		check(scroll.scroll_vertical<=before-90 and book.entry==-1,"Finger drag scrolls back without selecting")
		scroll.scroll_vertical = 0
		await frames()
		await drag(point(book._tiles[0]),point(book._tiles[0])+Vector2(1,1))
		check(book.entry==0 and book._notebook_root.visible,"A short tap still opens exactly that card")
		check(book._popup_dim.get_global_rect().is_equal_approx(book._book_inset.get_global_rect()),"Detail dim follows the expanded rounded book bounds")
		check(book._list_box.z_index>book._notebook_root.z_index,"Left tabs remain above the modal dim")
		await capture("detail_%d" % resolution.x)
		var old := scroll.scroll_vertical
		await drag(point(book._popup_dim)+Vector2(300,0),point(book._popup_dim)+Vector2(300,-100))
		check(scroll.scroll_vertical==old,"An open detail does not drag the background grid")
		book.show_entry(-1)
		await frames()
		await drag(point(book._tiles[0]),point(book._tiles[0])+Vector2(1,1),true)
		check(book.entry==0,"Native touch tap opens the same card without a mouse click")
		book.show_spread(6)
		var long_index := 0
		var rows := 0
		for index: int in book.entry_count():
			var count: int = book._content.entries[index].get("rows",[]).size()
			if count>rows:
				rows = count
				long_index = index
		book.show_entry(long_index)
		await frames(10)
		var detail := book._left_scroll
		check(detail.get_v_scroll_bar().max_value>detail.size.y,"Long real card rules need vertical scrolling")
		await drag(point(detail),point(detail)-Vector2(0,150),true)
		check(detail.scroll_vertical>0,"Long entry detail supports finger dragging")
		book.show_entry(-1)
		await frames()
		var bar := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(bar.max_value)
		await frames()
		check(book._tiles.back().get_global_rect().end.y<=scroll.get_global_rect().end.y+2.0,"The last card can be reached without clipping its bottom")
		var tab := book._list_buttons[6]
		await mouse(point(tab),true)
		await mouse(point(tab),false)
		check(book.spread==6,"Chapter tabs still receive normal button input")
		for lang: String in ["ko","en","ja"]:
			L10n.set_language(lang)
			book.show_spread(6)
			await frames()
			check(book._right_scroll.size.x<=book._book_inset.size.x,"Translated card grid stays in book")
		book.queue_free()
		await frames()
	check(PlayerSave.data()==saved,"Browsing and dragging do not change saved records")
	parent.queue_free()
	await frames()
	if failures.is_empty(): print("UI_RULEBOOK_SCROLL_OK: %d checks" % checks); quit(0)
	else:
		for failure: String in failures: printerr("UI_RULEBOOK_SCROLL_FAIL: "+failure)
		quit(1)
