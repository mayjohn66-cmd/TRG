## CardSkin gallery using the registered SUM_03 definition and board summary.
extends SceneTree
var out:=OS.get_environment("DARTS_CAPTURE_OUT")

func _initialize() -> void:_run.call_deferred()

func _run() -> void:
	var sheet:=Control.new();root.add_child(sheet)
	var background:=ColorRect.new();background.size=Vector2(1366,768);background.color=Color("f9f2df");sheet.add_child(background)
	CardSkin.label(sheet,"GalleryTitle","롤링 양성자빔 · 카드 일러스트",Rect2(24,18,1318,44),30,CardSkin.INK,true)
	var data:BaseCard=CardRegistry.get_card(&"SUM_03")
	var sizes:Array[Vector2]=[Vector2(400,560),Vector2(140,196)]
	var locations:Array[Vector2]=[Vector2(260,105),Vector2(880,276)]
	for i:int in 2:
		var frame:=PanelContainer.new();frame.position=locations[i];frame.size=sizes[i]
		frame.custom_minimum_size=sizes[i]
		frame.add_theme_stylebox_override("panel",CardSkin.frame(data.category,false,16 if i==0 else 8))
		# Reuse the live card description so the gallery stays aligned with the hand UI.
		frame.add_child(CardSkin.body(data,sizes[i],MainBoard.card_summary(&"SUM_03"), "소환",i==0));sheet.add_child(frame)
		CardSkin.label(sheet,"SizeCaption%d"%i,"상세 보기" if i==0 else "손패 크기",Rect2(locations[i].x,locations[i].y+sizes[i].y+16,sizes[i].x,36),20,CardSkin.INK,true)
	for i:int in 12:await process_frame
	await RenderingServer.frame_post_draw
	var result:Error=root.get_texture().get_image().save_png(out.path_join("proton-card-art-preview.png"))
	print("PROTON_CARD_ART_NATIVE saved=",result==OK)
	quit(0 if result==OK else 1)
