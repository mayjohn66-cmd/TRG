extends "res://tests/ui_fx_test.gd"
## 하단 배치 개편(2026-11) 검사: 내 프로필 제거 → 기물 독 중앙 하단, 손패는 우측 하단 접힘/펼침, 야추 족보 위로.
var checks:=0
func _expect(ok: bool,message: String) -> void:
	checks+=1;super._expect(ok,message)
func settle(n: int=4) -> void:
	for i: int in n:await process_frame
func screenshot(label: String) -> void:
	var folder:=OS.get_environment("HOTFIX_CAPTURE_DIR")
	if folder.is_empty():return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func quiet() -> void:
	_board._announcer.cancel();_board._reset_presentation();_board._close_opening();_board._close_draft_overlay();_board._close_augment_review()
	_board._announced_round=_board.state.round_number
	_board._bot.set_enabled(false);_board.manager.set_process(false);_board.instant_roll_for_test=true;_board.pacing_enabled=false

func _run() -> void:
	MatchTelemetry.test_sender=func(_url: String,_body: PackedByteArray,_type: String) -> void:pass
	_board._on_draft_auto_pressed();await settle(10);quiet();await settle()
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet()
	var me:int=_board.local_player_id
	print("LAYOUT ai_mode=",_board.ai_mode," me=",me," current=",_board.manager.current_player_id())
	_board.state.hands[me]=[&"ACT_02",&"TRP_02",&"ACT_15",&"ACT_04",&"ACT_17"]
	_board._refresh_all();await settle()
	var profile:Control=_board._profiles[me]["panel"]
	_expect(not profile.visible,"내 프로필(우측 하단 큰 카드)은 숨겨진다")
	# 기물 독: 중앙 하단
	var bar:Control=_board._pawn_bar
	var screen:=_board.get_viewport_rect()
	_expect(bar.visible,"손패가 접혀 있으면 기물 독이 보인다")
	_expect(absf(bar.get_global_rect().get_center().x-screen.size.x/2.0)<30.0 and bar.get_global_rect().end.y<=screen.size.y,"기물 독은 화면 중앙 하단에 있다")
	_expect(_board.active_skill_buttons()==_board._dock_skill_buttons,"필살기 버튼은 기물 독의 것을 쓴다")
	# 접힌 손패
	var stack:Control=_board._hand_stack
	_expect(stack.visible and not _board._dock.visible and not _board._hand_open,"손패는 처음에 접혀 있다 (우측 하단 일렬)")
	_expect(stack.get_global_rect().position.x>screen.size.x*0.6 and stack.get_global_rect().end.y<=screen.size.y,"접힌 손패는 우측 하단에 있다")
	_expect(stack.get_children().filter(func(c:Node)->bool:return c.name!="HandCount").size()==5,"손패 5장이 미니 카드 5장으로 일렬 표시된다")
	await screenshot("layout-collapsed")
	# 눌러서 펼침
	var tap:=InputEventMouseButton.new();tap.button_index=MOUSE_BUTTON_LEFT;tap.pressed=true;tap.position=Vector2(40,40)
	_board._on_hand_stack_input(tap);await settle()
	_expect(_board._hand_open and _board._dock.visible and not stack.visible,"손패를 누르면 부채꼴 큰 카드로 펼쳐진다")
	_expect(not bar.visible,"펼친 동안 기물 독은 숨는다")
	_expect(_board._dock.get_child_count()==5,"펼친 독에 카드 5장")
	await screenshot("layout-expanded")
	# 밖을 누르면 접힘
	_expect(_board._hand_outside_press(Vector2(300,150)),"독 밖(보드 위)을 누르면 접힘 대상이다")
	_expect(not _board._hand_outside_press(_board._dock.global_position+Vector2(200,80)),"독 안을 누르면 접히지 않는다")
	_board._set_hand_open(false);await settle()
	_expect(not _board._hand_open and stack.visible and bar.visible,"접으면 일렬 손패와 기물 독이 돌아온다")
	# 장수가 줄면 접힌다
	_board._set_hand_open(true)
	_board.state.hands[me]=[&"ACT_02",&"TRP_02"];_board._refresh_hands();await settle()
	_expect(not _board._hand_open,"카드를 쓰거나 잃어 장수가 줄면 다시 접힌다")
	_expect(_board.state.hands[me].size()==2 and stack.get_children().filter(func(c:Node)->bool:return c.name!="HandCount").size()==2,"접힌 손패가 장수를 따라간다")
	_board.state.hands[me]=[]
	_board._refresh_hands();await settle()
	_expect(not stack.visible and not _board._dock.visible,"손패가 없으면 일렬도 독도 보이지 않는다")
	# 모바일(터치): 접힌 손패 누르는 영역이 위로 넓어지고 기물 독이 커지며, 화면 밖으로 나가지 않는다
	_board.state.hands[me]=[&"ACT_02",&"TRP_02",&"ACT_15"];_board._refresh_hands();await settle()
	var normal_stack:=stack.get_global_rect();var normal_bar:=bar.get_global_rect()
	MobileSupport.force_touch=true;_board._apply_hand_layout();_board._refresh_hands();await settle()
	var touch_stack:=stack.get_global_rect()
	_expect(touch_stack.size.y>normal_stack.size.y+20.0 and absf(touch_stack.end.y-normal_stack.end.y)<1.0,"터치: 접힌 손패 누르는 영역이 아래는 그대로 위로만 넓어진다")
	_expect(bar.scale.x>1.1 and bar.get_global_transform().get_scale().x>1.1,"터치: 기물 독이 커진다")
	var bar_visual:Rect2=bar.get_global_transform()*Rect2(Vector2.ZERO,bar.size)
	_expect(screen.encloses(bar_visual) and bar_visual.end.y<=screen.size.y+0.5,"터치: 커진 기물 독도 화면 안에 있다 (%s)"%bar_visual)
	_expect(not bar_visual.intersects(stack.get_global_rect().grow(-2.0)),"터치: 기물 독과 접힌 손패가 겹치지 않는다")
	await screenshot("touch-layout")
	_board.layout_for(Vector2(1920,1080));await settle()
	_expect(is_equal_approx(float(stack.get_meta("touch_pad",0.0)),MainBoard.HAND_STACK_TOUCH_PAD) and stack.size.y>MainBoard.HAND_STACK_SIZE.y+20.0,"터치: 창 크기가 바뀌어도 누르는 영역 여백이 유지된다")
	_board.layout_for(Vector2(1366,768))
	# 터치: 확대(미리 보기) 중에 밖을 눌러도 손패는 접히지 않는다
	_board._set_hand_open(true)
	_board._open_zoom(me,&"ACT_02");await settle()
	_expect(_board._zoom_view!=null and not _board._hand_outside_press(Vector2(300,150)),"터치: 카드 확대를 닫는 터치로는 손패가 접히지 않는다")
	_board._close_zoom();_board._set_hand_open(false)
	MobileSupport.force_touch=false;_board._apply_hand_layout();_board._refresh_hands();await settle()
	_expect(is_equal_approx(bar.scale.x,1.0) and is_equal_approx(stack.size.y,MainBoard.HAND_STACK_SIZE.y),"터치를 끄면 원래 크기로 돌아온다")
	_board.state.hands[me]=[]
	_board._refresh_hands();await settle()
	# 내 순위 도장은 기물 독에 찍힌다 (내 프로필이 숨겨져 있어서)
	_board.state.rankings.append(me);_board.state.rank_reasons[me]=&"LAW_01";_board._refresh_all();await settle()
	var mine_stamp: Variant=_board._pawn_bar.get_node_or_null("RankStamp")
	_expect(mine_stamp!=null and mine_stamp._rank_art.resource_path.ends_with("/1ST.png") and mine_stamp._border_art.resource_path.ends_with("/border-special.png"),"내 순위 도장(붉은 테두리 1ST)은 기물 독에 찍힌다")
	_board.state.rankings.clear();_board.state.rank_reasons.clear();_board._refresh_all();await settle()
	# 내 증강 버튼은 로그 머리에
	var aug_button:=_board._action_log.find_child("MyAugmentsButton",true,false) as Button
	_expect(aug_button!=null and aug_button.is_visible_in_tree(),"[내 증강] 버튼이 로그 머리에 있다")
	# 야추 판은 이전보다 위
	_expect(_board._stage_yacht.position.y+YachtStage.STAGE_SIZE.y/2.0<335.0-20.0,"야추 족보 판은 이전(중심 335)보다 위로 올라갔다")
	_board._reset_presentation();_board._close_zoom();_board._close_choice();MatchTelemetry.test_sender=Callable()
	var board:=_board;_board=null;board.queue_free();await settle(8)
	for failure: String in _failures:printerr("LAYOUT_FAIL ",failure)
	print("LAYOUT ",checks," assertions; ",_failures.size()," failures")
	quit(0 if _failures.is_empty() else 1)
