## Native selection-card rendering; pawn evolution keeps its existing pawn art.
extends SceneTree
var out := OS.get_environment("DARTS_CAPTURE_OUT")
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	L10n.set_language("ko")
	var sheet:=Control.new();root.add_child(sheet)
	var background:=ColorRect.new();background.size=Vector2(1366,768);background.color=Color("20222e");sheet.add_child(background)
	CardSkin.label(sheet,"Title","신규 증강 4종 · 기존 아이콘 화풍에 맞춤",Rect2(24,16,1318,50),30,Color("ffe6a7"),true)
	var state:=TestCase.new().make_state()
	var ids:Array[StringName]=[&"TOOL_DICE_STOCK",&"TOOL_DICE_DARTS",&"AUG_UTIL_DRIFT",&"AUG_UTIL_BOUNTY"]
	for i:int in ids.size():
		var definition:=AugmentRegistry.get_def(ids[i])
		var card:=MainBoard.make_augment_card(MainBoard.augment_card_info(definition,state,1),Callable(),1.0,true)
		card.position=Vector2(136+i*278,91)
		sheet.add_child(card)
	CardSkin.label(sheet,"PawnNote","기물 증강: 기존 기물 이미지를 그대로 사용",Rect2(24,505,1318,40),23,Color("e5ecd7"),true)
	for i:int in 2:
		var id:=&"EVO_7_6" if i==0 else &"EVO_7_7"
		var definition:=AugmentRegistry.get_def(id)
		var info:=MainBoard.augment_card_info(definition,state,1)
		var emblem:=MainBoard._make_emblem(info.glyph,info.color,info.art)
		emblem.position=Vector2(465+i*280,551);sheet.add_child(emblem)
		CardSkin.label(sheet,"PawnName%d"%i,"모브 큐이" if i==0 else "괴상한 멜론",Rect2(430+i*280,704,220,32),20,Color("e5ecd7"),true)
	for i:int in 12:await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_png(out.path_join("new-augment-icons-native.png"))
	print("NEW_AUGMENT_ICONS_NATIVE saved=",result==OK)
	quit(0 if result==OK else 1)
