## Focused audit of the two overhead-light paths; no unrelated effect suites.
extends "res://tests/ui_mobile_fx_test.gd"
const STAGE=preload("res://scenes/pawn_stage_spotlight.gd")
var before:=OS.get_environment("SPOTLIGHT_BASELINE")=="1"
var cut:VictoryCutscene
var layer:CanvasLayer
var light:ColorRect
var target:Node2D

func run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	create_timer(80).timeout.connect(func()->void:printerr("SPOTLIGHT_FAIL timeout");quit(1))
	root.content_scale_size=Vector2i(1366,768)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	await window(Vector2i(1366,768));await fixture()
	# Keep this audit's captures clear of unrelated ready-skill help and draft notices.
	board._skill_hint.hide()
	var snapshot:=TurnSnapshot.capture(board.state).data
	var rng_before:int=board.state.rng.state
	var clock_before:float=Engine.time_scale
	target=board._pawn_views[11]
	var saved_z:int=target.z_index
	layer=CanvasLayer.new();layer.layer=90;board.add_child(layer)
	cut=VictoryCutscene.new();layer.add_child(cut)
	cut.setup(VictoryCutscene.MODE_LAW,Color.GOLD,null,null,"","","","")
	var old_points:Array[Vector2]=[]
	for index:int in [3,10,18,23]:old_points.append(board.get_global_transform_with_canvas()*board._tile_center(index))
	if before:cut.set_spots(old_points)
	else:cut.call("set_board_spots",board,[3,10,18,23])
	cut.play();cut.set_process(false);cut._spot_view=0.40
	light=STAGE.new();board.add_child(light)
	light.illuminate(board,target,Color.GOLD,60.0)
	light.set_process(false)
	await frames(9)
	for size:Vector2i in [Vector2i(1366,768),Vector2i(844,390),Vector2i(740,360),Vector2i(390,844)]:
		await window(size)
		await sample("%dx%d"%[size.x,size.y])
	if not before:
		await window(Vector2i(1366,768))
		board._board_layer.scale=Vector2.ONE*1.12;board._pawn_layer.scale=Vector2.ONE*1.12
		board._board_layer.position=Vector2(-64,-24);board._pawn_layer.position=Vector2(-64,-24)
		await sample("zoom-shift")
		board._board_layer.scale=Vector2.ONE;board._pawn_layer.scale=Vector2.ONE
		board.layout_for(root.get_visible_rect().size)
		board._alkkagi_camera=1.0;board._apply_view_mode()
		await sample("top-plane")
		await themed_confirmations()
	check(TurnSnapshot.capture(board.state).data==snapshot and board.state.rng.state==rng_before and Engine.time_scale==clock_before,"alignment changes no game state, RNG or clock")
	light.queue_free();layer.queue_free();await frames(3)
	check(target.z_index==saved_z,"temporary pawn light draw order restored")
	board.queue_free();await frames(4);MatchTelemetry.test_sender=Callable()
	print("SPOTLIGHT_MEASUREMENTS ",measurements," ",JSON.stringify(errors))
	for failure:String in failures:printerr("SPOTLIGHT_FAIL ",failure)
	print("SPOTLIGHT_NATIVE ",failures.size()," failures; baseline=",before)
	quit(0 if failures.is_empty() else 1)

func sample(label:String) -> void:
	board._skill_hint.hide()
	light.hide();cut.show();cut.set_time(0)
	if not before:
		var points:PackedVector2Array=cut._spot_material.get_shader_parameter("spots")
		var indices:Array[int]=[3,10,18,23]
		for i:int in 4:
			var tile:Control=board._tile_views[indices[i]]
			near("law ground center",cut._spot_overlay.get_global_transform_with_canvas()*points[i],tile.get_global_transform_with_canvas()*(tile.size*0.5))
		check_floor(cut._spot_material,cut._spot_overlay)
	await capture("law-"+label)
	cut.hide();light.show();light._update_light();light.modulate.a=1.0
	if not before:
		near("pawn foot",light.get_global_transform_with_canvas()*light.material.get_shader_parameter("foot"),target.get_global_transform_with_canvas().origin)
		check_floor(light.material,light)
	await capture("pawn-"+label)

func themed_confirmations() -> void:
	cut.hide();light.hide()
	board._alkkagi_camera=0.0;board._apply_view_mode()
	for id:String in LawRegistry.ALL_IDS:
		var themed:=VictoryCutscene.new();layer.add_child(themed)
		themed.setup(VictoryCutscene.MODE_LAW,Color.GOLD,null,null,"","","","")
		themed.set_board_spots(board,[3,10,18,23])
		themed.set_law_context(id,board._board_center(),&"avatar_01","조명 점검",1)
		themed.play();themed.set_process(false);themed._spot_view=0.40;themed._intro_view=-1;themed.set_time(0)
		var points:PackedVector2Array=themed._spot_material.get_shader_parameter("spots")
		var indices:Array[int]=[3,10,18,23]
		for i:int in 4:
			var tile:Control=board._tile_views[indices[i]]
			near(id+" confirmation ground",themed._spot_overlay.get_global_transform_with_canvas()*points[i],tile.get_global_transform_with_canvas()*(tile.size*0.5))
		check_floor(themed._spot_material,themed._spot_overlay)
		await capture("confirm-"+id)
		themed.cancel();themed.queue_free();await frames(2)

func check_floor(shader:ShaderMaterial,overlay:CanvasItem) -> void:
	var origin:Vector2=board._surface_project(Vector2.ONE*0.5)
	for axis:Vector2 in [Vector2.RIGHT,Vector2.DOWN]:
		var projected:Vector2=board._board_layer.get_global_transform_with_canvas()*(board._surface_project(Vector2.ONE*0.5+axis*0.095))-board._board_layer.get_global_transform_with_canvas()*origin
		var parameter:String="floor_axis_x" if axis==Vector2.RIGHT else "floor_axis_y"
		var supplied:Vector2=shader.get_shader_parameter(parameter)
		var frame:=overlay.get_global_transform_with_canvas()
		near(parameter,frame*supplied-frame.origin,projected)
