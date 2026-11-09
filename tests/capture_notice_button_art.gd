## Actual StartMenu pointer path: artwork, N badge and native notice popup.
extends SceneTree
var out:=OS.get_environment("DARTS_CAPTURE_OUT")
var failures:Array[String]=[]
var menu:StartMenu

func _initialize() -> void:_run.call_deferred()

func settle(frames:int) -> void:
	for i:int in frames:await process_frame

func expect(value:bool,message:String) -> void:
	if not value:failures.append(message)

func snap(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))

func pointer(button:Control,down:bool) -> void:
	var point:=button.get_global_transform_with_canvas()*(button.size*0.5)
	var event:=InputEventMouseButton.new();event.position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await process_frame

func hover(button:Control) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=button.get_global_transform_with_canvas()*(button.size*0.5)
	root.push_input(event,true);await settle(8)

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	GameSession.nickname="공지 미리보기";L10n.set_language("ko")
	PlayerSave.set_value(UpdateNotes.SEEN_KEY,"")
	menu=(load("res://scenes/start_menu.tscn") as PackedScene).instantiate()
	menu.change_scene_enabled=false;root.add_child(menu);await settle(35)
	menu._show_step(2);await settle(5)
	expect(menu.find_child("TipBar",true,false)==null and menu.find_child("TipNext",true,false)==null,"hub has no removed tip strip or next-tip button")
	var button:=menu.find_child("HubUpdates",true,false) as Button
	expect(button!=null and button.is_visible_in_tree(),"real hub displays the notice button")
	if button==null:quit(1);return
	var icon:=button.get_node_or_null("HubArt_notes") as TextureRect
	var badge:=button.get_node_or_null("NewBadge") as Label
	expect(icon!=null and icon.texture==HubArt.ART[&"notes"] and icon.mouse_filter==Control.MOUSE_FILTER_IGNORE,"notice uses imported image and does not block clicks")
	expect(badge!=null and badge.visible and UpdateNotes.has_unseen(),"unread notices retain the N badge")
	var original_position:Vector2=button.position
	await snap("01-hub-notice-unread")
	await hover(button);await snap("02-notice-hover")
	await pointer(button,true);await snap("03-notice-pressed")
	expect(menu.find_child("UpdateNotesPopup",true,false)==null,"press alone does not open the popup")
	await pointer(button,false);await settle(6)
	var popup:=menu.find_child("UpdateNotesPopup",true,false) as Control
	expect(popup!=null and popup.is_visible_in_tree(),"actual pointer release opens the notice popup")
	expect(not badge.visible and not UpdateNotes.has_unseen(),"opening marks current news seen and hides N")
	if popup!=null:
		expect(popup.find_children("NotesRow*","Button",true,false).size()==UpdateNotes.entries().size(),"one expandable row per version")
		await snap("04-notices-open")
		var close:=popup.find_child("NotesClose",true,false) as Button
		await hover(close);await pointer(close,true);await pointer(close,false);await settle(6)
		expect(not is_instance_valid(popup),"actual close button dismisses notices")
	for lang:String in ["en","ja","ko"]:
		L10n.set_language(lang);await settle(5)
		expect(button.position.distance_to(original_position)<0.1,"notice position remains stable in "+lang)
		expect(button.get_global_rect().end.x<=menu.size.x and button.get_global_rect().position.x>=0,"notice fits hub in "+lang)
	await snap("05-hub-notice-read")
	var region:=Rect2i(button.get_global_rect().grow(8))
	root.get_texture().get_image().get_region(region).save_png(out.path_join("notice-button-native-detail.png"))
	menu.queue_free();await settle(5);MatchTelemetry.test_sender=Callable()
	for failure:String in failures:printerr("NOTICE_ART_FAIL ",failure)
	print("NOTICE_ART_NATIVE ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
