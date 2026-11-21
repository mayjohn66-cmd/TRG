class_name TestMahjongSlam
extends TestCase


func test_thirty_tile_identities_and_cjk_glyphs_are_exact() -> void:
	for tile: int in ToolMahjong.TILE_KINDS:
		var data: Dictionary = MahjongFace.model(tile)
		check_eq(data.id,tile,"tile identity survives visual mapping")
		check_eq(data.name,ToolMahjong.tile_name(tile),"tile label agrees with rule engine")
		if not data.glyph.is_empty():
			check(MahjongFace.FONT.has_char(str(data.glyph).unicode_at(0)),"bundled subset contains actual CJK glyph")
	check(MahjongFace.FONT.has_char("萬".unicode_at(0)),"character-suit glyph is bundled")
	check_eq(MahjongFace.model(27).glyph,"","white dragon has a clean blank face")
	check_eq(MahjongFace.model(28).glyph,"發","green dragon uses 發")
	check_eq(MahjongFace.model(29).glyph,"中","red dragon uses 中")
	print("MAHJONG_FACE_COVERAGE 30/30")


func test_printed_dot_and_bamboo_counts_are_deterministic() -> void:
	for tile: int in range(9,27):
		var marks: Array[Dictionary] = MahjongFace.marks(tile)
		check_eq(marks.size(),tile%9+1,"printed marks match rank, with one bird for one bamboo")
		for mark: Dictionary in marks:
			check(MahjongFace.art(mark.art) != null,"every ink motif is a real imported image")
			check(Rect2(Vector2.ZERO,Vector2(MahjongFace.FACE_SIZE)).encloses(Rect2(mark.centre-mark.size*0.5,mark.size)),"complete printed artwork stays inside the tile")
	for rank: int in [2,3,4,6,8]:
		for mark: Dictionary in MahjongFace.marks(18+rank-1):
			check_eq(mark.art,"BAMBOO_GREEN","all-green bamboo ranks contain no red ink")
	check_eq(MahjongFace.marks(18)[0].art,"BAMBOO_BIRD","one bamboo is a bird, not a single line")
	check(MahjongFace.art("BACK_LEAF") != null,"tile back has generated clover artwork")


func test_three_landings_are_separate_rigid_and_never_clip_the_mat() -> void:
	for index: int in 3:
		check(absf(MahjongSlam3D.impact_time(index)-(0.30+index*0.24))<0.00001,"one landing per beat")
		for step: int in 201:
			var time: float = float(step)/100.0
			var pose: Transform3D = MahjongSlam3D.pose_at(time,index)
			var rotation: Quaternion = pose.basis.get_rotation_quaternion()
			check(pose.origin.y+0.00001 >= MahjongSlam3D.TABLE_Y+MahjongSlam3D.support_height(rotation),"rotating corners never pass below the mat")
			check(absf(pose.basis.determinant()-1.0)<0.0001,"hard tile is never squashed or stretched")
		var contact: float = MahjongSlam3D.impact_time(index)
		var at: Transform3D = MahjongSlam3D.pose_at(contact,index)
		var frozen: Transform3D = MahjongSlam3D.pose_at(contact+0.03,index)
		check(at.is_equal_approx(frozen),"35ms contact hold sells the hard impact locally")
		var final: Transform3D = MahjongSlam3D.pose_at(2.0,index)
		check(final.basis.is_equal_approx(Basis.IDENTITY),"printed face settles flat facing up")
		check(final.is_equal_approx(MahjongSlam3D.pose_at(4.0,index)),"result hold cannot keep moving")
		var before: Transform3D = MahjongSlam3D.pose_at(contact-0.00001,index)
		check(before.origin.distance_to(at.origin)<0.003,"fast slam still has continuous contact")


func test_falling_tiles_fit_the_render_frame_including_flip_corners() -> void:
	var camera_basis: Basis = Basis.looking_at(MahjongSlam3D.CAMERA_TARGET-MahjongSlam3D.CAMERA_HOME)
	var half_height: float = MahjongSlam3D.CAMERA_SIZE*0.5
	var half_width: float = half_height*MahjongSlam3D.RENDER_SIZE.x/MahjongSlam3D.RENDER_SIZE.y
	for index: int in 3:
		for step: int in 61:
			var time: float = MahjongSlam3D.LEAD_TIME+index*MahjongSlam3D.INTERVAL+step/100.0
			var pose: Transform3D = MahjongSlam3D.pose_at(time,index)
			for x: float in [-1.0,1.0]:
				for y: float in [-1.0,1.0]:
					for z: float in [-1.0,1.0]:
						var point: Vector3 = pose*(Vector3(x,y,z)*MahjongSlam3D.HALF)-MahjongSlam3D.CAMERA_TARGET
						check(absf(point.dot(camera_basis.x))<half_width-0.04 and absf(point.dot(camera_basis.y))<half_height-0.04,"complete falling tile and outline stay inside the render frame")


func test_mahjong_tap_is_short_distinct_cached_pcm() -> void:
	var stream: AudioStreamWAV = Sfx.synth(&"mahjong_tap")
	check(stream != null,"dedicated hard tile tap exists")
	check(stream.get_length() > 0.09 and stream.get_length() < MahjongSlam3D.INTERVAL,"tap ends before the next landing")
	check(stream.data != Sfx.synth(&"card_pick").data,"tile sound is distinct from soft paper/card feedback")
	check(stream == Sfx.synth(&"mahjong_tap"),"short impact sample is reused")
