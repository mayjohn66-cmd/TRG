## Render real detailed/hand card skins, then toggle only the new paper decoration.
extends SceneTree
var out:=OS.get_environment("DARTS_CAPTURE_OUT")
var sheet:Control
var decorations:Array[CanvasItem]=[]

func _initialize() -> void:_run.call_deferred()

func title(text:String,at:Vector2,extent:Vector2,px:int) -> void:
	CardSkin.label(sheet,"GalleryLabel",text,Rect2(at,extent),px,Color("35282f"),true)

func card(id:StringName,at:Vector2,extent:Vector2,detailed:bool) -> void:
	var data:BaseCard=CardRegistry.get_card(id)
	var frame:=PanelContainer.new();frame.position=at;frame.size=extent
	frame.add_theme_stylebox_override("panel",CardSkin.frame(data.category,false,16 if detailed else 8))
	var text:String=MainBoard.card_summary(id) if detailed else str(MainBoard.CARD_SHORT.get(id,""))
	frame.add_child(CardSkin.body(data,extent,text,MainBoard.CARD_CATEGORY_NAMES[data.category],detailed))
	sheet.add_child(frame)

func gather(node:Node) -> void:
	if node.name in ["CardPaper","NamePaper","ArtPaper","EffectPaper"]:decorations.append(node as CanvasItem)
	for child:Node in node.get_children():gather(child)

func snap(filename:String) -> void:
	for i:int in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(filename+".png"))

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	sheet=Control.new();root.add_child(sheet)
	var base:=ColorRect.new();base.size=Vector2(1366,768);base.color=Color("f9f2df");sheet.add_child(base)
	title("카드 배경 · 무광 카드지 질감",Vector2(30,14),Vector2(1306,44),28)
	var ids:Array[StringName]=[&"ACT_16",&"TRP_05",&"SUM_02",&"CNT_01"]
	for i:int in 4:card(ids[i],Vector2(70+i*315,72),Vector2(270,378),true)
	title("손패 크기",Vector2(30,468),Vector2(1306,30),20)
	for i:int in 4:card(ids[i],Vector2(290+i*210,514),Vector2(140,196),false)
	for i:int in 10:await process_frame
	gather(sheet)
	for layer:CanvasItem in decorations:layer.hide()
	await snap("01-before")
	for layer:CanvasItem in decorations:layer.show()
	await snap("02-after")
	MobileSupport.force_touch=true
	sheet.queue_free();await process_frame
	sheet=Control.new();root.add_child(sheet)
	base=ColorRect.new();base.size=Vector2(1366,768);base.color=Color("f9f2df");sheet.add_child(base)
	title("모바일 손패 · 확대 미리보기",Vector2(30,20),Vector2(1306,48),28)
	for i:int in 4:card(ids[i],Vector2(138+i*280,130),Vector2(240,336),false)
	await snap("03-touch-cards")
	MobileSupport.force_touch=false;MatchTelemetry.test_sender=Callable()
	print("CARD_PAPER_NATIVE saved 3 galleries; real four categories, detail/hand/touch")
	quit(0)
