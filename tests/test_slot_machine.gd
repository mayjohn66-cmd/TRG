class_name TestSlotMachine
extends TestCase


func test_all_216_engine_combinations_land_on_the_correct_three_physical_symbols() -> void:
	var seen: int = 0
	for a: int in 6:
		for b: int in 6:
			for c: int in 6:
				var values: Array[int] = [a,b,c]
				for power: float in [0.0,0.5,1.0]:
					for i: int in 3:
						var angle: float = SlotMachine3D.angle_at(SlotMachine3D.RESULT_TIME,i,values[i],power)
						check_eq(SlotMachine3D.symbol_at(angle),values[i],"physical centre symbol matches engine, independent of power")
						check(absf(wrapf(angle-values[i]*SlotMachine3D.STEP,-PI,PI))<0.00001,"drum locks on symbol centre")
				var expected: int = 20 if a==5 and b==5 and c==5 else (8 if a==b and b==c else (4 if a==b or a==c or b==c else 1))
				check_eq(ToolSlot777.steps_for(values),expected,"existing payout table is unchanged")
				seen += 1
	check_eq(seen,216,"complete combination coverage")
	print("SLOT_COMBINATION_COVERAGE 216/216")


func test_reel_rotation_is_continuous_and_cannot_reveal_a_different_symbol_on_rebound() -> void:
	for i: int in 3:
		for symbol: int in 6:
			var before: float = SlotMachine3D.STARTS[i]
			for step: int in 121:
				var t: float = SlotMachine3D.STOP_TIMES[i]*step/120.0
				var angle: float = SlotMachine3D.angle_at(t,i,symbol,1.0)
				check(angle>=before-0.000001,"spinning drums advance monotonically until stop")
				before = angle
			for step: int in 20:
				var t: float = SlotMachine3D.STOP_TIMES[i]+SlotMachine3D.SETTLE_TIME*step/19.0
				check_eq(SlotMachine3D.symbol_at(SlotMachine3D.angle_at(t,i,symbol,0.0)),symbol,"small rebound cannot cross to a neighbouring symbol")
			for t: float in [SlotMachine3D.LEAD_TIME,SlotMachine3D.LEAD_TIME+SlotMachine3D.ACCEL_TIME,SlotMachine3D.STOP_TIMES[i]-SlotMachine3D.BRAKE_TIME]:
				var dt: float = 0.00001
				var left: float = (SlotMachine3D.angle_at(t,i,symbol,0.5)-SlotMachine3D.angle_at(t-dt,i,symbol,0.5))/dt
				var right: float = (SlotMachine3D.angle_at(t+dt,i,symbol,0.5)-SlotMachine3D.angle_at(t,i,symbol,0.5))/dt
				check(absf(left-right)<0.01,"angular velocity stays continuous at acceleration/brake changes")


func test_actual_drum_uvs_show_upright_symbols_and_outward_front_faces() -> void:
	var mesh: ArrayMesh = SlotMachine3D.make_drum_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i: int in vertices.size():
		check(is_equal_approx(Vector2(vertices[i].y,vertices[i].z).length(),SlotMachine3D.REEL_RADIUS),"reel is a true cylinder")
	for symbol: int in 6:
		var index: int = symbol*32*2
		check(absf(fposmod(uv[index].y,1.0)-(SlotMachine3D.strip_row(symbol)+0.5)/6.0)<0.00001,"UV centre samples the correct actual atlas cell")
		check(uv[index+2].y<uv[index].y,"moving upward on the drum samples upward in the image")
	for i: int in range(0,indices.size(),3):
		var a: int = indices[i]
		var b: int = indices[i+1]
		var c: int = indices[i+2]
		check((vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a])<0,"Godot clockwise faces point outside the drum")
	check_eq(SlotMachine3D.STRIP_SIZE,Vector2i(256,1536),"six exact cells share one cached strip")
	for file: String in SlotMachine3D.ICON_FILES.values():
		check(ResourceLoader.exists("res://assets/ui/trickcal/slot/SLOT_%s.png" % file),"native generated symbol is bundled: "+file)


func test_matching_lights_do_not_invent_a_win_or_highlight_the_wrong_reel() -> void:
	check_eq(SlotMachine3D.matching_reels([0,1,2]),[false,false,false] as Array[bool],"miss has no winning lamps")
	check_eq(SlotMachine3D.matching_reels([0,1,0]),[true,false,true] as Array[bool],"separated pair highlights only matching outside reels")
	check_eq(SlotMachine3D.matching_reels([2,2,2]),[true,true,true] as Array[bool],"triple highlights all three")
	check_eq(SlotMachine3D.result_title([5,5,5]),"777 잭팟!","only actual 777 gets jackpot title")
	check_eq(SlotMachine3D.result_title([5,5,2]),"2개 일치!","two sevens are a pair, not jackpot")


func test_provisional_slot_sound_events_are_distinct_short_and_cached() -> void:
	var stop: AudioStreamWAV = Sfx.synth(&"slot_stop")
	check(stop.get_length()<0.10 and Sfx.synth(&"slot_spin").get_length()<0.20,"slot feedback uses short samples")
	check(stop==Sfx.synth(&"slot_stop"),"stop sound is cached")
	check(stop.data!=Sfx.synth(&"roulette_tick").data,"heavy reel lock differs from pointer tick")
