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
	# Approved icon family once existed only in an uncommitted art checkout.
	# Exercise the actual rulebook renderer, not merely file presence.
	var art_book := Rulebook.new()
	for role: StringName in [&"board", &"capture", &"hidden_trap", &"pawn_ability", &"corner", &"halfway", &"bread", &"wardrobe", &"store", &"vending", &"witch_shop", &"cauldron", &"spirit", &"boost", &"pawn_basics"]:
		var image := Rulebook._art(role, Vector2(40, 40))
		var atlas := image.texture as AtlasTexture
		check(atlas != null, "Rulebook uses cropped artwork for %s" % role)
		if atlas != null:
			check(atlas.atlas.resource_path == "res://assets/ui/trickcal/rulebook/v04/%s.png" % role, "Approved v04 artwork remains connected: %s" % role)
			check(atlas.region.has_area() and Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), "Imported artwork crop stays inside %s" % role)
		check(image.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Artwork never intercepts a chapter or entry click")
		image.free()
	for role: StringName in [&"roll", &"play_card", &"lawbook", &"supply", &"super"]:
		var image := Rulebook._art(role, Vector2(40, 40))
		var atlas := image.texture as AtlasTexture
		check(atlas != null and atlas.atlas.resource_path == "res://assets/ui/trickcal/rulebook/v05/%s.png" % role, "Unified chapter icon uses approved v05 artwork: %s" % role)
		if atlas != null:
			check(atlas.atlas.get_size() == Vector2(256, 256), "Chapter icons remain lightweight at runtime")
			check(atlas.region.has_area() and Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), "Unified chapter crop remains valid")
		image.free()
	var defense_sources: Dictionary = {}
	for item: Dictionary in art_book._ch_capture()["entries"]:
		if item["title"] in ["방어 카드", "잡기 방어", "공격 방어", "함정 방어", "만능 방어"]:
			var texture: Texture2D = item.get("texture")
			if texture == null: texture = Rulebook.VISUALS.texture(item["art"])
			defense_sources[(texture.atlas if texture is AtlasTexture else texture).resource_path] = true
	check(defense_sources.size() == 5, "Defense overview and its four types have distinguishable illustrations")
	art_book.free()
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
		for chapter: int in range(Rulebook.BOARD_SPREAD,Rulebook.TAB_NAMES.size()):
			book.show_spread(chapter)
			await frames(10)
			var scroll := book._right_scroll
			var grid := book._right_holder.get_node("EntryGrid") as GridContainer
			check(grid.columns==(3 if MobileSupport.touch_mode() and chapter!=Rulebook.CARD_SPREAD else 4),"Readable phone columns for chapter %d" % chapter)
			check(not scroll.get_h_scroll_bar().visible,"No sideways overflow in chapter %d" % chapter)
			var row_end := book._tiles[mini(grid.columns,book._tiles.size())-1].get_global_rect().end.x
			var pane_end := scroll.get_global_rect().end.x-(scroll.get_v_scroll_bar().size.x if scroll.get_v_scroll_bar().visible else 0.0)
			check(book._tiles.size()<grid.columns or absf(row_end-pane_end)<8.0,"Card columns fill the pane without a blank right-hand strip (chapter %d: %.0f vs %.0f)" % [chapter,row_end,pane_end])
			for tile: Control in book._tiles:
				var face := tile.get_child(0) as Button
				check(absf(face.size.x*face.scale.x-tile.size.x)<0.1,"Card face fills its grid hit area")
				check(absf(face.size.y*face.scale.y-tile.size.y)<0.5,"Row height matches card face (chapter %d)" % chapter)  # 줄을 다 못 채우면 행 높이가 정수로 올림된다
			await capture("chapter_%d_%d" % [chapter,resolution.x])
		book.show_spread(Rulebook.LAW_SPREAD)
		await frames()
		var switch_button := book._right_holder.find_child("BoardVariantButton", true, false) as Button
		check(switch_button != null, "The bakery law has a board variant button")
		if switch_button != null:
			var variant_index := book._tiles.find(switch_button.get_parent())
			check(switch_button.text.begins_with(L10n.t("보드 %d/%d ▶").get_slice("%", 0)) and switch_button.text.ends_with("▶"), "The switch is a [Board 1/4 ▶] chip (%s)" % switch_button.text)
			check(switch_button.size.y >= (44.0 if MobileSupport.touch_mode() else 36.0) - 0.5, "The board chip keeps its touch height")
			var switch_point := point(switch_button)
			await drag(switch_point, switch_point + Vector2.ONE, MobileSupport.touch_mode())
			check(book.entry == -1, "The switch flips the card without opening its detail")
			check((book._content.entries[variant_index]["texture"] as Texture2D).resource_path == AugmentArt.ROOT + str(BoardCatalog.law_variant(&"monatium", "LAW_02")["icon"]), "Detail art switches with the card")
			var reverse_button := book._tiles[variant_index].get_node("BoardVariantButton") as Button
			check(reverse_button.text.contains("2/%d" % BoardCatalog.ids().size()), "The chip counts the board it shows (%s)" % reverse_button.text)
			switch_point = point(reverse_button)
			await drag(switch_point, switch_point + Vector2.ONE, MobileSupport.touch_mode())
			check(str(book._content.entries[variant_index].get("title", "")) == "Bad Carrot", "The second press shows the Belatien witch-shop card (%s)" % book._content.entries[variant_index].get("title", ""))
			# 남은 보드 판(정령산 등)을 한 장씩 넘긴 뒤 한 번 더 누르면 원래 빵집 카드로 돌아온다
			var variant_boards: int = 0
			for board: Dictionary in BoardCatalog.available():
				if (board.get("law_variants", {}) as Dictionary).has("LAW_02"):
					variant_boards += 1
			for press: int in range(variant_boards - 1):
				var next_button := book._tiles[variant_index].get_node("BoardVariantButton") as Button
				switch_point = point(next_button)
				await drag(switch_point, switch_point + Vector2.ONE, MobileSupport.touch_mode())
				var flipped: bool = bool(book._content.entries[variant_index].get("variant_flipped", false))
				check(flipped == (press < variant_boards - 2), "Press %d shows %s" % [press + 3, "the next board card" if press < variant_boards - 2 else "the bakery card again"])
		book.show_spread(Rulebook.BOARD_SPREAD+1)
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
		check(book._popup_dim.visible and book._popup_dim.get_global_rect().encloses(root.get_visible_rect()),"Detail dim covers the whole rulebook screen")
		check(is_equal_approx(book._popup_dim.color.a,0.65),"Detail dim is 65% black")
		check(book._popup_x.visible and book._popup_x.size==Vector2(44,44) and book._notebook_page.get_global_rect().encloses(book._popup_x.get_global_rect()),"Detail popup has a 44x44 [x] inside its frame")
		check((book._popup_close.get_theme_stylebox("normal") as StyleBoxFlat).bg_color==Rulebook.CLOSE_FILL,"[Close] is the dark brown button")
		check(book._notebook_root.z_index>book._list_box.z_index,"Large detail stays above the background tabs")
		check(book._notebook_page.size.x>=book._stage.size.x*0.85 and book._notebook_page.size.y>=700,"Detail fills most of the landscape screen")
		check(root.get_visible_rect().encloses(book._notebook_page.get_global_rect()),"Large detail stays inside the viewport")
		check(book._note_column.scale.is_equal_approx(Vector2.ONE),"Detail text and card geometry render at their native size")
		var page := book._notebook_page.get_global_rect()
		check(not book._medal.visible,"The medal yields the top-right corner to [x] in the detail popup")
		for action: Button in [book._prev_entry,book._next_entry,book._popup_close]:
			check(page.encloses(action.get_global_rect()),"Detail navigation stays inside the frame")
			check(page.end.y-action.get_global_rect().end.y>=30.0,"Detail navigation has a bottom safe margin")
		check(book._left_scroll.get_global_rect().end.y+12.0<=book._popup_close.get_global_rect().position.y,"Scrollable rules do not cover the navigation row")
		await capture("detail_%d" % resolution.x)
		# 실제 클릭·터치로 상세 창 버튼이 눌린다 (암전 막이 노트 버튼 클릭을 가로채던 1.3.1 제보)
		for touch: bool in [false, true]:
			book.show_entry(0)
			await frames()
			await drag(point(book._next_entry),point(book._next_entry)+Vector2.ONE,touch)
			check(book.entry==1,"[Next] responds to a real %s" % ("touch" if touch else "click"))
			await drag(point(book._prev_entry),point(book._prev_entry)+Vector2.ONE,touch)
			check(book.entry==0,"[Prev] responds to a real %s" % ("touch" if touch else "click"))
			await drag(point(book._popup_close),point(book._popup_close)+Vector2.ONE,touch)
			check(book.entry==-1,"[Close] responds to a real %s" % ("touch" if touch else "click"))
			book.show_entry(0)
			await frames()
			await drag(point(book._popup_x),point(book._popup_x)+Vector2.ONE,touch)
			check(book.entry==-1,"[x] responds to a real %s" % ("touch" if touch else "click"))
		book.show_entry(0)
		await frames()
		var wheel := InputEventMouseButton.new()
		wheel.position = book._stage.get_global_transform_with_canvas()*Vector2(book._stage.size.x-56,300)
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await frames()
		check(book.entry==0 and scroll.scroll_vertical==0,"Wheel outside the page cannot move the background catalog")
		var outside := book._stage.get_global_transform_with_canvas()*Vector2(40,280)
		await mouse(outside,true)
		await mouse(outside,false)
		check(book.entry==-1 and book.spread==Rulebook.BOARD_SPREAD+1 and is_instance_valid(book),"Outside click returns to the same catalog instead of closing the book or changing chapter")
		book.show_entry(0)
		await frames()
		var inside_blank := book._notebook_page.get_global_transform_with_canvas()*Vector2(30,book._notebook_page.size.y-60)
		await mouse(inside_blank,true)
		await mouse(inside_blank,false)
		check(book.entry==0,"A tap inside the detail frame does not dismiss it")
		await drag(outside,outside+Vector2.ONE,true)
		check(book.entry==-1 and book.spread==Rulebook.BOARD_SPREAD+1,"Native touch outside returns without activating the chapter behind it")
		book.show_entry(0)
		await frames()
		var old := scroll.scroll_vertical
		await drag(point(book._popup_dim)+Vector2(300,0),point(book._popup_dim)+Vector2(300,-100))
		check(scroll.scroll_vertical==old,"An open detail does not drag the background grid")
		book.show_entry(-1)
		await frames()
		await drag(point(book._tiles[0]),point(book._tiles[0])+Vector2(1,1),true)
		check(book.entry==0,"Native touch tap opens the same card without a mouse click")
		book.show_spread(Rulebook.CARD_SPREAD)
		book.show_entry(4)
		await frames()
		await capture("card_detail_%d" % resolution.x)
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
		var content_before := book._left_holder.global_position
		var available := detail.get_v_scroll_bar().max_value-detail.get_v_scroll_bar().page
		await drag(point(detail),point(detail)-Vector2(0,150),true)
		check(detail.scroll_vertical>0,"Long entry detail supports finger dragging")
		check(absf((content_before-book._left_holder.global_position).y-minf(150.0,available*detail.get_global_transform().get_scale().y))<2.0,"Magnified content follows the drag distance without speeding up")
		book.show_entry(-1)
		await frames()
		var bar := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(bar.max_value)
		await frames()
		check(book._tiles.back().get_global_rect().end.y<=scroll.get_global_rect().end.y+2.0,"The last card can be reached without clipping its bottom")
		var tab := book._list_buttons[Rulebook.CARD_SPREAD]
		await mouse(point(tab),true)
		await mouse(point(tab),false)
		check(book.spread==Rulebook.CARD_SPREAD,"Chapter tabs still receive normal button input")
		for lang: String in ["ko","en","ja"]:
			L10n.set_language(lang)
			book.show_spread(Rulebook.CARD_SPREAD)
			await frames()
			check(book._right_scroll.size.x<=book._book_inset.size.x,"Translated card grid stays in book")
			book.show_entry(0)
			await frames()
			check(not book._left_scroll.get_h_scroll_bar().visible,"Translated card detail has no sideways clipping")
			check(book._left_holder.get_global_rect().end.x+10.0<=book._left_scroll.get_global_rect().end.x,"Detail content leaves a gutter beside its scrollbar")
		L10n.set_language("ko")
		# UI-01: 카드 장 분류 필터 5종 (배너 대신), 이전·다음은 필터 안에서만
		book.show_spread(Rulebook.CARD_SPREAD)
		await frames()
		check(book._filter_row.visible and not book._summary_banner.visible,"Card chapter shows the filter row instead of the banner")
		check(book._filter_buttons.size()==5,"Five card filter pills")
		check(Rulebook.card_filter_count(-1)==book._tiles.size(),"[All] counts every card tile")
		check(book._right_scroll.get_global_rect().position.y>=book._filter_row.get_global_rect().end.y-2.0,"Card grid starts below the filter pills")
		book._right_scroll.scroll_vertical = 300
		await mouse(point(book._filter_buttons[3]),true)
		await mouse(point(book._filter_buttons[3]),false)
		await frames()
		check(book.card_filter==GameEnums.CardCategory.TRAP and book._tiles.size()==Rulebook.card_filter_count(GameEnums.CardCategory.TRAP),"Trap filter keeps only trap cards")
		check(book._right_scroll.scroll_vertical==0,"Switching filter scrolls back to the top")
		book.show_entry(book.entry_count()-1)
		await frames()
		book._next_entry.pressed.emit()
		await frames()
		check(book.entry==0 and CardRegistry.get_card(book._content.entries[0]["card"]).category==GameEnums.CardCategory.TRAP,"[Next] wraps inside the filtered cards")
		book.show_entry(-1)
		book.set_card_filter(-1)
		await frames()
		check(book._tiles.size()==Rulebook.card_filter_count(-1),"[All] restores the full card grid")
		book.show_spread(Rulebook.BOARD_SPREAD)
		await frames()
		check(book._summary_banner.visible and not book._filter_row.visible,"Other catalog chapters keep the summary banner")
		# UI-03: 백업 팝업 [x]와 바깥 누르기
		book._toggle_save_popup()
		await frames()
		check(book._save_close.size.x>=36.0 and book._save_popup.get_global_rect().encloses(book._save_close.get_global_rect()),"Backup popup has an [x] button")
		check((book._code_field.get_theme_stylebox("normal") as StyleBoxFlat).bg_color==LobbyTheme.INPUT_BG,"Backup code field uses the bright input skin")
		await mouse(point(book._save_close),true)
		await mouse(point(book._save_close),false)
		check(not book._save_popup.visible,"[x] closes the backup popup")
		book._toggle_save_popup()
		await frames()
		var away := book._stage.get_global_transform_with_canvas()*Vector2(700,600)
		await mouse(away,true)
		await mouse(away,false)
		check(not book._save_popup.visible and book.entry==-1,"Clicking outside closes the backup popup without opening a tile")
		# UI-04·UI-10: 기본 규칙 노트는 첫 화면에 판 전체·꿀팁까지
		book.show_spread(3)
		await frames(8)
		var board := book._left_holder.find_child("BoardPanel",true,false).get_child(0) as Control
		check(board.size.x<=Rulebook.BASIC_BOARD_PX+0.5 and book._left_scroll.get_global_rect().encloses(board.get_global_rect()),"Special-tile board shows down to the start line without scrolling")
		book.show_spread(1)
		await frames(8)
		var turn_bar := book._left_scroll.get_v_scroll_bar()
		check(turn_bar.max_value<=turn_bar.page+1.0,"One-turn overview shows its tip box without scrolling")
		for index: int in book._list_buttons.size():
			if book._list_buttons[index].visible:
				check(book._list_buttons[index].size.y>=48.0,"Chapter buttons stay touch-sized")
		book.queue_free()
		await frames()
	check(PlayerSave.data()==saved,"Browsing and dragging do not change saved records")
	parent.queue_free()
	await frames()
	if failures.is_empty(): print("UI_RULEBOOK_SCROLL_OK: %d checks" % checks); quit(0)
	else:
		for failure: String in failures: printerr("UI_RULEBOOK_SCROLL_FAIL: "+failure)
		quit(1)
