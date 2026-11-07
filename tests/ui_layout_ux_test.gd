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
	# 터치: 증강 선택 창 — [리롤]을 카드에서 띄우고 크게 만들며, 창이 새로 그려진 직후의 이어 누름은 카드를 고르지 않는다 (2026-11 제보)
	_board.instant_roll_for_test=false
	_board.manager.change_state(TurnManager.State.PHASE_ROUND_START)
	_board.manager._draft_offers[1]=AugmentRegistry.generate_offers(_board.state,1);_board.manager._draft_picks.clear()
	_board._build_draft_overlay(1,2);await settle()
	var gap_ok:=false;var tall_ok:=false;var apart_ok:=false
	if _board._draft_cards.size()==3 and _board._draft_reroll_buttons.size()==3:
		var card0:Button=_board._draft_cards[0];var reroll0:Button=_board._draft_reroll_buttons[0]
		gap_ok=reroll0.get_global_rect().position.y-card0.get_global_rect().end.y>=MainBoard.DRAFT_REROLL_GAP_TOUCH*0.9
		tall_ok=reroll0.size.y>=MainBoard.DRAFT_REROLL_HEIGHT_TOUCH-0.5
		apart_ok=not card0.get_global_rect().intersects(reroll0.get_global_rect())
	_expect(gap_ok,"터치: [리롤]은 카드에서 충분히 떨어져 있다")
	_expect(_board._draft_title_label!=null and _board._draft_title_label.get_global_rect().position.y>=_board._augment_timeline.get_global_rect().end.y-1.0,"[증강 선택] 제목이 위쪽 타임라인에 가려지지 않는다")
	_expect(tall_ok and apart_ok,"터치: [리롤]은 크고 카드와 겹치지 않는다")
	_board._draft_cards[0].pressed.emit();await settle()
	_expect(not _board._draft_locked,"터치: 창이 열린 직후의 누름은 카드를 고르지 않는다")
	_board._draft_guard_until_msec=0
	_board._draft_cards[0].pressed.emit()
	_expect(_board._draft_locked,"터치: 잠깐 뒤의 누름은 카드를 고른다")
	_board._close_draft_overlay();_board._draft_locked=false;_board.instant_roll_for_test=true;_board.manager._draft_offers.clear()
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
	# 내 프로필이 숨겨진 뒤 그 자리(우측 하단)에 피격·보상 효과가 떠다니지 않는다 (2026-11 제보)
	var fx_before:int=_board.get_child_count()
	_board.instant_roll_for_test=false
	_board._profile_react(me,false);_board._profile_react(me,true);_board._revenge_charged_popup(me)
	await settle(2)
	var stray:=_board.get_children().filter(func(n:Node)->bool:return n is Panel and (n as Panel).z_index==36)
	_expect(stray.is_empty() and _board.get_child_count()<=fx_before,"내 프로필 숨김: 피격 빨간 깜빡임·조각·숫자 효과가 숨은 자리에 생기지 않는다 (추가 %d개)"%(_board.get_child_count()-fx_before))
	var other_id:int=_board.state.player_ids.filter(func(id:int)->bool:return id!=me)[0]
	_board._profile_react(other_id,false);await settle(2)
	_expect(not _board.get_children().filter(func(n:Node)->bool:return n is Panel and (n as Panel).z_index==36).is_empty(),"다른 사람 프로필에는 피격 효과가 그대로 나온다")
	_board.instant_roll_for_test=true
	# 증강 타임라인: 위쪽 가운데, 라운드에 따라 글·칩이 바뀐다 (2026-11 제보 "증강이 언제 나오는지 알려주면 좋겠음")
	var timeline:=_board._augment_timeline as AugmentTimeline
	_expect(timeline!=null and timeline.visible,"증강 타임라인이 보인다")
	_expect(timeline.get_global_rect().position.y<20.0 and absf(timeline.get_global_rect().get_center().x-screen.get_center().x)<1.0,"타임라인은 화면 위쪽 정중앙에 있다")
	_expect(not timeline.get_global_rect().intersects(_board._menu_button.get_global_rect()),"타임라인이 [메뉴] 버튼과 겹치지 않는다")
	_board.state.round_number=3;_board._refresh_all();await settle()
	_expect(timeline.caption_kind==&"soon" and timeline.rounds.size()==5 and bool(timeline.rounds[3]["draft"]),"3라운드: 다음 라운드(4R)가 증강")
	_expect(timeline._numbers[2].text=="3R" and timeline._numbers[2].get_theme_color("font_color")==Color.WHITE,"일반 라운드는 흰색 숫자")
	_expect(timeline._numbers[3].text=="4R" and timeline._numbers[3].get_theme_color("font_color")==AugmentTimeline.COLOR_GOLD,"증강 라운드는 노란색 숫자")
	var current_style := timeline._numbers[2].get_theme_stylebox("normal") as StyleBoxFlat
	_expect(current_style.bg_color==AugmentTimeline.COLOR_CURRENT and current_style.border_color==AugmentTimeline.COLOR_EDGE,"중앙 현재 칸은 별도 배경색과 기본 테두리")
	var enlarged := timeline._numbers.filter(func(chip: Label) -> bool: return not chip.scale.is_equal_approx(Vector2.ONE))
	_expect(enlarged==[timeline._numbers[2]] and timeline._numbers[2].scale.x>1.0,"다섯 칸 중 가운데 현재 라운드만 확대한다")
	_expect(timeline._numbers[0].get_rect().end.x<timeline._numbers[1].position.x,"라운드 칸 사이에 여백이 있다")
	_expect(_board.round_banner_sub().contains("\n"),"3라운드 시작 연출에 [다음 라운드 증강 선택!] 사전 예고가 붙는다")
	await create_timer(5.0).timeout  # 증강 선택 알림이 사라진 뒤의 모습
	# 라운드 시작 연출(ROUND N)에 사전 예고가 한 줄 더 붙는 모습
	_board.instant_roll_for_test=false;_board.pacing_enabled=true
	_board._announce("라운드","ROUND 3","",Color("ffd43b"),null,3.0,true,{"key":"round","sub":_board.round_banner_sub()})
	await create_timer(1.2).timeout
	await screenshot("round-banner-warning")
	_board._announcer.cancel();_board.instant_roll_for_test=true;_board.pacing_enabled=false
	await screenshot("timeline-r3")
	_board.state.round_number=5;_board._refresh_all();await settle()
	_expect(timeline.caption_kind==&"later" and timeline.caption_rounds==2 and not _board.round_banner_sub().contains("\n"),"5라운드: 7라운드까지 2라운드 뒤, 사전 예고 없음")
	_board.state.round_number=6;_board._refresh_all();await settle()
	_expect(not bool(timeline.rounds[3]["super"]) and timeline._numbers[3].get_theme_color("font_color")==AugmentTimeline.COLOR_GOLD,"7라운드(템포 0)는 쉬운 증강만 섞이고 증강 숫자는 노란색")
	_board.state.round_number=1;_board.state.auto_law_preview="";_board._refresh_all();await settle()
	_expect(_board.round_banner_sub().contains(L10n.t("{e:target} 승리 조건: 말 4개를 가장 먼저 완주시키거나, 중반에 열리는 [중앙 법전] 조건을 달성하세요!")),"1라운드 배너에 기본 승리 조건 한 줄")
	_board.state.round_number=6;_board.state.auto_law_preview="LAW_01";_board._refresh_all();await settle()
	_expect(_board.round_banner_sub().contains(L10n.t("★ %d라운드에 [%s] 법전이 열립니다!")%[TempoUp.stage_rounds[0],L10n.t(LawRegistry.create("LAW_01").law_name)]) and not _board.round_banner_sub().contains("{e:target}"),"6라운드 배너에 열릴 법전 예고 (승리 조건 한 줄은 1라운드만)")
	_board.state.auto_law_preview=""
	_board.state.round_number=9;_board._refresh_all();await settle()
	_expect(AugmentTimeline.is_super_round(10) and AugmentTimeline.pool_news(10)!="" and AugmentTimeline.pool_news(13)=="" and AugmentTimeline.pool_news(16)!="","고급 증강 합류는 10라운드, 초증강 합류는 16라운드 증강에서 알린다")
	_expect(_board.round_banner_sub().contains(L10n.t("★ %s 합류!")%L10n.t(AugmentTimeline.pool_news(10))),"9라운드 사전 예고에 새로 합류하는 증강 안내")
	_board.state.round_number=6;_board._refresh_all();await settle()
	_expect((timeline._numbers[4].get_theme_stylebox("normal") as StyleBoxFlat).border_color==AugmentTimeline.COLOR_TEMPO,"앞에 보이는 템포 업 시작 라운드는 붉은 테두리")
	await screenshot("timeline-r6")
	_board.state.round_number=TempoUp.stage_rounds[0];_board._refresh_all();await settle()
	_expect((timeline._numbers[2].get_theme_stylebox("normal") as StyleBoxFlat).border_color==AugmentTimeline.COLOR_TEMPO,"템포 업이 시작되는 라운드 칸만 붉은 테두리")
	_expect((timeline._numbers[3].get_theme_stylebox("normal") as StyleBoxFlat).border_color==AugmentTimeline.COLOR_EDGE,"템포 업이 이어지는 다음 라운드 칸은 기본 테두리")
	await screenshot("timeline-tempo")
	for language:String in ["en","ja"]:
		L10n.set_language(language);_board._refresh_all();await settle()
		_expect(timeline.size.x<=screen.size.x and timeline.tooltip_text.contains(L10n.t("노란 숫자는 증강 라운드, 붉은 테두리는 템포 업이 시작되는 라운드를 뜻합니다. 템포 업 1단계부터 고급 증강(법전 등), 2단계부터 초증강도 증강 선택지에 합류합니다.")),"타임라인과 도움말이 %s에서도 표시된다"%language)
		await screenshot("timeline-"+language)
	L10n.set_language("ko")
	var next_number := timeline._numbers[3]
	var prior_x := next_number.position.x
	_board.instant_roll_for_test=false
	_board.state.round_number+=1
	_board._refresh_augment_timeline()
	_expect(timeline._numbers[2]==next_number and is_equal_approx(next_number.position.x,prior_x),"다음 칸이 기존 위치에서 중앙으로 이동하기 시작한다")
	await create_timer(AugmentTimeline.SLIDE_SECONDS + 0.06).timeout
	_expect(is_equal_approx(next_number.position.x+next_number.pivot_offset.x,timeline.size.x*0.5) and not timeline._spare.visible,"전환이 끝나면 새 라운드는 중앙, 지난 칸은 퇴장")
	_expect(is_equal_approx(next_number.scale.x,AugmentTimeline.CURRENT_SCALE) and timeline._numbers[1].scale.is_equal_approx(Vector2.ONE),"전환 뒤에는 새 현재 라운드만 커진다")
	_board.instant_roll_for_test=true
	_board.state.round_number=1;_board._refresh_all();await settle()
	await screenshot("timeline-opening")
	# 야추 판은 이전보다 위
	_expect(_board._stage_yacht.position.y+YachtStage.STAGE_SIZE.y/2.0<335.0-20.0,"야추 족보 판은 이전(중심 335)보다 위로 올라갔다")
	_board._reset_presentation();_board._close_zoom();_board._close_choice();MatchTelemetry.test_sender=Callable()
	var board:=_board;_board=null;board.queue_free();await settle(8)
	for failure: String in _failures:printerr("LAYOUT_FAIL ",failure)
	print("LAYOUT ",checks," assertions; ",_failures.size()," failures")
	quit(0 if _failures.is_empty() else 1)
