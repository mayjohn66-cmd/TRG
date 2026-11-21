## Actual selection-card renderer: 8 registered laws, no preview law registration.
extends SceneTree
var out := OS.get_environment("DARTS_CAPTURE_OUT")
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	L10n.set_language("ko")
	var state:=TestCase.new().make_state()
	for page:int in 2:
		var sheet:=Control.new();root.add_child(sheet)
		var bg:=ColorRect.new();bg.size=Vector2(1366,768);bg.color=Color("20222e");sheet.add_child(bg)
		CardSkin.label(sheet,"Title","특수 승리 증강 · %d / 2"%(page+1),Rect2(24,32,1318,50),30,Color("ffe6a7"),true)
		for i:int in 4:
			var id:=StringName("AUG_LAW_%02d"%(page*4+i+1))
			var definition:=AugmentRegistry.get_def(id)
			var info:=MainBoard.augment_card_info(definition,state,1)
			var law:=LawRegistry.create(str(definition.payload))
			if AugmentDef.strip_title_tag(definition.title)!=law.law_name:
				push_error("Law selection title mismatch: "+str(id));quit(1);return
			var card:=MainBoard.make_augment_card(info,Callable(),1.0,true)
			card.position=Vector2(136+i*278,150);sheet.add_child(card)
		for i:int in 12:await process_frame
		await RenderingServer.frame_post_draw
		var error:=root.get_texture().get_image().save_png(out.path_join("law-icons-native-%d.png"%(page+1)))
		if error!=OK:quit(1);return
		sheet.queue_free();await process_frame
	print("LAW_ICONS_NATIVE 8/8 current names and native cards saved")
	quit(0)
