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
		book = Rulebook.open(parent,Rulebook.BOARD_SPREAD)
		await frames(10)
		check(is_equal_approx(book._stage.size.x,root.get_visible_rect().size.x),"Book uses available canvas width at %s" % resolution)
		check(book.find_child("PrevPage", true, false) == null and book.find_child("Group0", true, false) is Label,"Chapter list is grouped under headings instead of top tabs")
		for chapter: int in book.spread_count():
			book.show_spread(chapter)
			await frames(6)
			var scroll := book._right_scroll
			check(not scroll.get_h_scroll_bar().visible,"No sideways overflow in chapter %d" % chapter)
			check(book._tiles.size()==book.entry_count(),"Every entry of chapter %d has its own block" % chapter)
			var grid := book._right_holder.get_node("EntryGrid") as GridContainer
			if book.is_catalog():
				check(grid.columns>=2,"Catalog chapter %d keeps at least two card columns" % chapter)
				var row_end := book._tiles[mini(grid.columns,book._tiles.size())-1].get_global_rect().end.x
				var pane_end := scroll.get_global_rect().end.x-scroll.get_v_scroll_bar().size.x
				if book._tiles.size()>=grid.columns:
					check(absf(row_end-pane_end)<10.0,"Card columns fill the pane without a blank right-hand strip (chapter %d)" % chapter)
				for tile: Control in book._tiles:
					var name_label := tile.find_child("EntryName",true,false) as Label
					var brief := tile.find_child("EntryBrief",true,false) as Label
					check(name_label != null and name_label.clip_text,"Card names stay on one line")
					check(brief != null and brief.max_lines_visible==2,"Card summaries stay within two lines")
					check(tile.size.y<=Rulebook.CARD_H+1.0,"Catalog cards keep one height (chapter %d: %s)" % [chapter,tile.size.y])
				check(book._overview_button.visible,"Catalog chapter %d offers its basic explanation" % chapter)
			else:
				check(not book._overview_button.visible and book._right_holder.get_child_count()==2,"Basic chapter %d shows its explanation and every entry open on one page" % chapter)
			await capture("chapter_%d_%d" % [chapter,resolution.x])
		# 보드마다 바뀌는 특수 승리: 상세 창의 보드 버튼으로 다른 보드의 판을 본다
		book.show_spread(Rulebook.LAW_SPREAD)
		await frames()
		var law_index := -1
		for index: int in book.entry_count():
			if str(book._content.entries[index].get("law_id",""))=="LAW_02": law_index = index
		check(law_index>=0,"The bakery law is in the law chapter")
		if law_index>=0:
			book.show_entry(law_index)
			await frames()
			var variant_buttons: Array[Node] = book._variant_row.get_children()
			check(variant_buttons.size()==BoardCatalog.ids().size(),"The bakery law offers every board's version")
			var original: String = book._detail_title.text
			for board_id: StringName in BoardCatalog.ids():
				var button := book._variant_row.get_node("Variant_%s" % board_id) as Button
				button.pressed.emit()
				await frames()
				var expected: String = str(BoardCatalog.law_variant(board_id,"LAW_02").get("name","봉인된 에르핀의 식권"))
				check(book._detail_title.text==expected,"%s button shows that board's law (%s)" % [board_id,book._detail_title.text])
				check((book._tiles[law_index].find_child("EntryName",true,false) as Label).text==expected,"The grid card follows the shown board")
			book._variant_row.get_node("Variant_%s" % BoardCatalog.ids()[0]).pressed.emit()
			await frames()
			check(book._detail_title.text==original,"Returning to the current board restores the bakery law")
			book.show_entry(-1)
		book.show_spread(Rulebook.BOARD_SPREAD+2)
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
		check(book.entry==0 and book._modal.visible,"A short tap still opens exactly that card")
		check(root.get_visible_rect().encloses(book._modal_panel.get_global_rect()),"Detail window stays inside the viewport")
		check(book._modal_panel.size.y>=book._stage.size.y*0.85,"Detail window uses most of the screen height")
		await capture("detail_%d" % resolution.x)
		book._next_button.pressed.emit()
		await frames()
		check(book.entry==1 and book._detail_count.text=="2 / %d" % book.entry_count(),"Next steps to the following card")
		book._prev_button.pressed.emit()
		book._prev_button.pressed.emit()
		await frames()
		check(book.entry==book.entry_count()-1,"Previous wraps around to the last card")
		book.show_entry(0)
		await frames()
		var wheel := InputEventMouseButton.new()
		wheel.position = book._stage.get_global_transform_with_canvas()*Vector2(book._stage.size.x-40,300)
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await frames()
		check(book.entry==0 and scroll.scroll_vertical==0,"Wheel outside the window cannot move the background catalog")
		var outside := book._stage.get_global_transform_with_canvas()*Vector2(30,400)
		await mouse(outside,true)
		await mouse(outside,false)
		check(book.entry==-1 and not book._modal.visible and book.spread==Rulebook.BOARD_SPREAD+2 and is_instance_valid(book),"Outside click returns to the same catalog instead of closing the book or changing chapter")
		book.show_entry(0)
		await frames()
		var inside_blank := book._modal_panel.get_global_transform_with_canvas()*Vector2(30,book._modal_panel.size.y-40)
		await mouse(inside_blank,true)
		await mouse(inside_blank,false)
		check(book.entry==0,"A tap inside the detail window does not dismiss it")
		await drag(outside,outside+Vector2.ONE,true)
		check(book.entry==-1 and book.spread==Rulebook.BOARD_SPREAD+2,"Native touch outside returns without activating the chapter behind it")
		book.show_entry(0)
		await frames()
		var old := scroll.scroll_vertical
		await drag(outside,outside+Vector2(0,-100))
		check(scroll.scroll_vertical==old,"An open detail does not drag the background grid")
		book.show_entry(-1)
		await frames()
		await drag(point(book._tiles[0]),point(book._tiles[0])+Vector2(1,1),true)
		check(book.entry==0,"Native touch tap opens the same card without a mouse click")
		book.show_spread(Rulebook.BOARD_SPREAD+3)
		var long_index := 0
		var rows := 0
		for index: int in book.entry_count():
			var count: int = book._content.entries[index].get("rows",[]).size()
			if count>rows:
				rows = count
				long_index = index
		book.show_entry(long_index)
		await frames(10)
		await capture("card_detail_%d" % resolution.x)
		var detail := book._detail_scroll
		check(detail.get_v_scroll_bar().max_value>detail.size.y,"Long real card rules need vertical scrolling")
		await drag(point(detail),point(detail)-Vector2(0,150),true)
		check(detail.scroll_vertical>0,"Long entry detail supports finger dragging")
		book.show_entry(-1)
		await frames()
		var bar := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(bar.max_value)
		await frames()
		check(book._tiles.back().get_global_rect().end.y<=scroll.get_global_rect().end.y+2.0,"The last card can be reached without clipping its bottom")
		var tab := book._list_buttons[1]
		book._list_scroll.scroll_vertical = 0
		await frames()
		await mouse(point(tab),true)
		await mouse(point(tab),false)
		check(book.spread==1,"Chapter buttons still receive normal button input")
		book.show_spread(3, 2)
		await frames(4)
		check(book.entry==2 and not book._modal.visible,"Opening an entry of a basic chapter scrolls to it without a window")
		for lang: String in ["ko","en","ja"]:
			L10n.set_language(lang)
			book.show_spread(Rulebook.BOARD_SPREAD+3)
			await frames()
			check(book._right_scroll.get_global_rect().end.x<=book._book.get_global_rect().end.x,"Translated card grid stays in book")
		book.queue_free()
		await frames()
	check(PlayerSave.data()==saved,"Browsing and dragging do not change saved records")
	parent.queue_free()
	await frames()
	if failures.is_empty(): print("UI_RULEBOOK_SCROLL_OK: %d checks" % checks); quit(0)
	else:
		for failure: String in failures: printerr("UI_RULEBOOK_SCROLL_FAIL: "+failure)
		quit(1)
