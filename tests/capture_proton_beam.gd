## Isolated VFX on the real board; registered cards and gameplay remain untouched.
extends "res://tests/capture_darts_integration.gd"
const BEAM=preload("res://scenes/proton_beam_view.gd")

func _run() -> void:
	MatchTelemetry.test_sender=func(_url:String,_body:PackedByteArray,_type:String)->void:pass
	_board._on_draft_auto_pressed();await settle(15);quiet()
	_board.instant_roll_for_test=false
	var tip:=_board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip!=null:tip.hide()
	_board._skill_hint.hide();_board._roll_button.hide();_board.set_process(false)
	var snapshot:=TurnSnapshot.capture(_board.state).data
	var rng_before:int=_board.state.rng.state
	var laws:Array[String]=LawRegistry.ALL_IDS.duplicate()
	var deck:Dictionary=CardRegistry.DECK_COMPOSITION.duplicate()
	var beam:=BEAM.new();beam.hide();beam.z_index=5
	_board._pawn_layer.add_child(beam)
	beam.setup_projection(_board);beam.position=_board._surface_project(Vector2.ONE*0.5)
	var impacts:Array[int]=[0]
	beam.landed.connect(func()->void:impacts[0]+=1)
	recording=true;await settle(6)
	beam.descend(0.70)
	await settle(15)
	_expect(beam.drop<0.98 and beam._floor_ink.get_shader_parameter("strength")==0.0,"ground glow waits for actual arrival")
	_expect(beam._burst_ink.get_shader_parameter("strength")==0.0,"contact spikes wait for actual arrival")
	await snap("01-column-descending")
	await settle(8);await snap("02-ground-contact")
	_expect(impacts[0]==1,"one landing impact")
	_expect(beam._burst_ink.get_shader_parameter("strength")>0.9,"continuous impact spikes active at contact")
	_expect(beam._rear_burst.get_index()<beam._column.get_index() and beam._burst.get_index()>beam._column.get_index(),"ground contact wraps behind and in front of column")
	await settle(22);await snap("03-sustained-satellite-beam")
	check_floor(beam)
	var before_move:Vector2=beam.global_position
	var glide:=beam.create_tween()
	glide.tween_property(beam,"position",_board._tile_center(3),1.0).set_trans(Tween.TRANS_LINEAR)
	await settle(16);await snap("04-gliding-contact")
	_expect(beam.global_position!=before_move and beam._floor.get_global_transform_with_canvas().origin.distance_to(beam.get_global_transform_with_canvas().origin)<0.01,"moving contact remains anchored to beam")
	await glide.finished;await settle(6)
	beam.configure(2);_expect(beam.rounds_left==2 and beam._label.text=="2R","existing lifetime configuration API preserved")
	await snap("04b-full-width-before-collapse")
	var full_image:Image=root.get_texture().get_image()
	beam.fade_out(0.75)
	await settle(12);await snap("05-narrowing-column")
	var half_image:Image=root.get_texture().get_image()
	var height:float=float(beam._column_ink.get_shader_parameter("foot_y"))
	var top_probe:Vector2=beam.get_global_transform_with_canvas()*Vector2(0,-height*0.70)
	var base_probe:Vector2=beam.get_global_transform_with_canvas()*Vector2(0,-height*0.12)
	var side_probe:Vector2=beam.get_global_transform_with_canvas()*Vector2(40,-height*0.55)
	var mid_contact:float=float(beam._floor_ink.get_shader_parameter("strength"))
	_expect(beam._column.scale.x>0.25 and beam._column.scale.x<0.70 and is_equal_approx(beam._column.scale.y,1.0) and absf(beam._column.position.x+beam._column.size.x*beam._column.scale.x*0.5)<0.01,"column narrows around its fixed center without losing height")
	_expect(mid_contact>0.2 and mid_contact<0.95 and is_equal_approx(beam._burst.scale.x,beam._column.scale.x) and beam._floor.get_global_transform_with_canvas().origin.distance_to(beam.get_global_transform_with_canvas().origin)<0.01,"contact contracts and dims with the narrowing column at the same floor point")
	await settle(9);await snap("05b-final-thin-thread")
	var late_contact:float=float(beam._floor_ink.get_shader_parameter("strength"))
	_expect(beam._column.scale.x<0.10 and late_contact>0.0 and late_contact<mid_contact and is_equal_approx(late_contact,float(beam._burst_ink.get_shader_parameter("strength"))),"last thin thread and both contact layers fade together")
	await settle(8);await snap("06-board-restored");recording=false
	var clean_image:Image=root.get_texture().get_image()
	_expect(_patch_delta(half_image,clean_image,top_probe)>0.15 and _patch_delta(half_image,clean_image,base_probe)>0.15,"thin column remains lit at both top and bottom at mid-collapse")
	# Sample multiple heights so a dark gap in the painted energy cannot hide an edge.
	var full_edge:float=0.0;var thin_edge:float=0.0
	for offset:float in [-0.15,0.0,0.15]:
		var point:Vector2=side_probe+Vector2(0,height*offset)
		full_edge=maxf(full_edge,_patch_delta(full_image,clean_image,point))
		thin_edge=maxf(thin_edge,_patch_delta(half_image,clean_image,point))
	_expect(full_edge>0.10 and thin_edge<0.06,"actual column edges recede horizontally rather than fading in place")
	_expect(not is_instance_valid(beam),"fade removes beam and shader/particle nodes")
	var cancelled:=BEAM.new();_board._pawn_layer.add_child(cancelled)
	cancelled.setup_projection(_board);cancelled.descend(0.6);await settle(4);cancelled.cancel()
	var frozen:float=cancelled._clock;await settle(3)
	_expect(not cancelled.visible and not cancelled.is_processing() and cancelled._clock==frozen,"cancel stops all beam processing")
	cancelled.queue_free();await settle(3)
	_expect(TurnSnapshot.capture(_board.state).data==snapshot and _board.state.rng.state==rng_before,"VFX alters no game state or RNG")
	_expect(LawRegistry.ALL_IDS==laws and CardRegistry.DECK_COMPOSITION==deck,"visual preview leaves registered cards and laws unchanged")
	var board:MainBoard=_board;_board=null;board.queue_free();await settle(5)
	for failure:String in _failures:printerr("PROTON_BEAM_FAIL ",failure)
	print("PROTON_BEAM_NATIVE ",_failures.size()," failures; frames=",recorded_frames)
	MatchTelemetry.test_sender=Callable();quit(0 if _failures.is_empty() else 1)

func _patch_delta(a:Image,b:Image,point:Vector2) -> float:
	var total:float=0.0
	for y:int in range(-2,3):
		for x:int in range(-2,3):
			var p:=Vector2i(point)+Vector2i(x,y)
			p.x=clampi(p.x,0,a.get_width()-1);p.y=clampi(p.y,0,a.get_height()-1)
			var ca:Color=a.get_pixelv(p);var cb:Color=b.get_pixelv(p)
			total+=(absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b))/3.0
	return total/25.0

func check_floor(beam:Node2D) -> void:
	var origin:Vector2=_board._surface_project(Vector2.ONE*0.5)
	var frame:Transform2D=beam._floor.get_global_transform_with_canvas()
	for axis:Vector2 in [Vector2.RIGHT,Vector2.DOWN]:
		var expected:Vector2=_board._board_layer.get_global_transform_with_canvas()*(_board._surface_project(Vector2.ONE*0.5+axis*0.095))- _board._board_layer.get_global_transform_with_canvas()*origin
		var actual:Vector2=frame.basis_xform(axis)
		_expect(actual.distance_to(expected*BEAM.FLOOR_SCALE)<0.01,"contact ellipse uses actual board projection axes")
