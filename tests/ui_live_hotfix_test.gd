extends "res://tests/ui_fx_test.gd"
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
func click_control(button: Control) -> void:
	var at:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
	root.push_input(motion,true);await settle(1)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=pressed
		root.push_input(event,true);await settle(1)
func quiet() -> void:
	_board._announcer.cancel();_board._reset_presentation();_board._close_opening();_board._close_draft_overlay();_board._close_augment_review()
	_board._announced_round=_board.state.round_number
	_board._bot.set_enabled(false);_board.manager.set_process(false);_board.instant_roll_for_test=true;_board.pacing_enabled=false;_board.ai_mode=false

func _run() -> void:
	MatchTelemetry.test_sender=func(_url: String,_body: PackedByteArray,_type: String) -> void:pass
	_board._on_draft_auto_pressed();await settle(10);quiet();await settle()
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet()
	var player:=_board.manager.current_player_id()
	_board.state.tools[player]=ToolPinball.new()
	_board.state.hands[player]=[&"TRP_02",&"ACT_15"]
	for seat: int in _board.state.player_ids:
		if seat!=player:_board.state.hands[seat]=[]
	_board._refresh_all();await settle()
	print("HOTFIX_STAGE_SETUP phase=",_board.manager.current_state," busy=",_board._ui_busy()," intro=",_board._intro_blocks()," disabled=",_board._roll_button.disabled," visible=",_board._roll_button.visible)
	_expect(not _board._stage_pinball.visible,"pinball cannot cover the board at turn start")
	_expect(_board._roll_button.visible and not _board._roll_button.disabled,"explicit pinball preparation button available")
	_board._on_card_pressed(player,&"TRP_02")
	_expect(_board._tile_pick_active and not _board._stage_pinball.visible,"trap placement exposes the clickable board")
	await screenshot("pinball-trap-board")
	var tile:=-1
	for index: int in BoardSpec.tile_count:
		if CardRegistry.get_card(&"TRP_02").is_legal(_board.state,player,{"tile":index}):tile=index;break
	await click_control(_board._tile_views[tile] as Control);await settle();quiet()
	_expect(not _board.state.has_card(player,&"TRP_02"),"trap card is actually consumed after tile click")
	_expect(not _board.state.board.get_tile(tile).attachments.is_empty(),"trap really installs with pinball equipped")
	# A fresh allowed card window for the independent UNO report.
	_board.manager._card_played_this_turn=false
	_board._on_card_pressed(player,&"ACT_15");await settle()
	_expect(_board._choice_overlay!=null,"UNO target choice opens")
	if _board._choice_overlay!=null:
		_expect((_board._choice_overlay.get_parent() as CanvasLayer).layer>=10000,"target modal uses priority canvas above judgement tools")
		_expect(not _board._stage_pinball.visible,"tool stays hidden throughout target selection")
		var choices:=_board._choice_overlay.find_children("*","Button",true,false)
		await screenshot("uno-target-priority")
		await click_control(choices[0] as Button);await settle();quiet()
		_expect(not _board.state.has_card(player,&"ACT_15"),"choosing UNO target actually plays the card")
	_board._refresh_controls();_board._on_roll_pressed();await settle()
	_expect(_board._stage_pinball.visible,"pinball stage appears only after explicit preparation")
	var armed_key:=_board._pinball_key();_board.manager.phase_serial+=1
	_expect(_board._pinball_key()==armed_key,"network proceed acknowledgement cannot discard pinball preparation")
	await screenshot("pinball-prepared")
	_board._show_choice("Target",[{"label":"P2","value":2}],func(_v: Variant)->void:pass)
	_expect(not _board._stage_pinball.visible,"even a prepared stage cannot cover choices")
	_board._close_choice();_board._refresh_controls();await settle()
	# The counter popup must have exactly the same priority as target choices.
	_board.manager._counter_offer={"victim":player,"attack":-1,"cards":[&"CNT_02"],"resume":&"roll"}
	_board._build_reaction_popup(player,"hotfix-counter");_board._refresh_tool_stage();await settle()
	_expect(_board._reaction_popup!=null and (_board._reaction_popup.get_parent() as CanvasLayer).layer>=10000,"defence popup uses the highest judgement priority")
	_expect(not _board._stage_pinball.visible,"defence cannot be hidden by a prepared pinball stage")
	_board.manager._counter_offer={};_board._close_reaction_popup();_board._refresh_controls()
	# Real TextEdit input, plus direct global handler checks while it owns focus.
	var modal:=_board._open_feedback("hotfix-test")
	await settle();modal._body_edit.grab_focus();modal._body_edit.text="hello";modal._body_edit.set_caret_column(5)
	var phase_before:=_board.manager.current_state
	var space:=InputEventKey.new();space.keycode=KEY_SPACE;space.unicode=32;space.pressed=true
	_board._input(space);_board._unhandled_key_input(space)
	root.push_input(space);await settle()
	_expect(modal._body_edit.text=="hello ","feedback TextEdit accepts an actual trailing Space key")
	_expect(_board.manager.current_state==phase_before,"text input cannot roll or change phase")
	modal._name_edit.grab_focus();modal._name_edit.text="A";modal._name_edit.caret_column=1
	root.push_input(space);await settle();_expect(modal._name_edit.text=="A ","single-line editor accepts spaces too")
	modal.close_modal();await settle();quiet()
	# Touch preview is read-first and only its explicit button may activate.
	MobileSupport.force_touch=true
	_board.manager._card_played_this_turn=false;_board.state.hands[player]=[&"ACT_04"]
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN);quiet();_board._refresh_all()
	var held:=(_board.state.hands[player] as Array).duplicate()
	await settle()
	var hand_views:=_board._dock.get_children().filter(func(node: Node) -> bool:return node is PanelContainer and node.has_meta("home_y"))
	await click_control(hand_views[0] as Control);await settle()
	_expect(_board.state.hands[player]==held,"first touch is read-only")
	var detail:=_board._zoom_view
	_expect(detail!=null and detail.find_child("MobileCardDescription",true,false)!=null,"large mobile card description is visible")
	var use:=detail.find_child("UseCard",true,false) as Button
	_expect(use!=null and not use.disabled,"usable card has an explicit second-step Use button")
	_expect((detail.find_child("MobileCardDescription",true,false) as RichTextLabel).get_theme_font_size("normal_font_size")>=20,"readable mobile detail type")
	await screenshot("mobile-card-read-first")
	await click_control(use);await settle();quiet()
	_expect(not _board.state.has_card(player,&"ACT_04"),"only the Use tap activates the card")
	_expect(_board._zoom_view==null,"preview closes after explicit activation")
	# Long translated descriptions remain scrollable and within narrow landscape screens.
	var old_language:=L10n.current_lang
	for language: String in ["ko","en","ja"]:
		L10n.set_language(language)
		for viewport: Vector2 in [Vector2(844,390),Vector2(667,375)]:
			var card:=CardRegistry.get_card(&"CNT_02")
			var sample:=preload("res://scenes/mobile_card_detail.gd").make(card,_board._make_card_preview(&"CNT_02"),_board.card_summary(&"CNT_02"),"피격 시",viewport,false,func()->void:pass,func()->void:pass)
			root.add_child(sample);await settle()
			_expect(Rect2(Vector2.ZERO,viewport).encloses(sample.get_global_rect()),"translated detail fits mobile viewport "+language)
			_expect((sample.find_child("MobileCardDescription",true,false) as RichTextLabel).scroll_active,"long detail scrolls "+language)
			_expect((sample.find_child("UseCard",true,false) as Button).disabled,"unusable counter cannot fire from preview")
			sample.queue_free();await settle()
		# 2026-11-04 제보: 모바일에서 방해령 사리의 [사용하기]가 가려짐. 줄바꿈 글자 칸의 폭이 정해지지 않아 패널이 세로로 늘어나 버튼이 화면 밖으로 밀렸다.
		# 진짜 보드의 확대 보기로 모든 언어에서 [사용하기]·[닫기]가 패널 안, 화면 안에 있는지 본다.
		for card_id: StringName in [&"ACT_04", &"ACT_18", &"ACT_19", &"ACT_20", &"SUM_03"]:
			_board._open_zoom(player,card_id);await settle()
			var shown:=_board._zoom_view
			_expect(shown!=null,"touch detail opens for %s %s"%[card_id,language])
			if shown!=null:
				var screen:=_board.get_viewport_rect()
				for button_name: String in ["UseCard","CloseCard"]:
					var action:=shown.find_child(button_name,true,false) as Button
					_expect(action!=null and screen.encloses(action.get_global_rect()) and shown.get_global_rect().encloses(action.get_global_rect().grow(-1.0)),"%s stays inside the detail and the screen: %s %s"%[button_name,card_id,language])
				_expect(shown.get_global_rect().size.y<=screen.size.y,"detail panel does not grow past the screen: %s %s (%d)"%[card_id,language,int(shown.get_global_rect().size.y)])
			_board._close_zoom();await settle()
	L10n.set_language(old_language)
	MobileSupport.force_touch=false
	# 순위 도장: 졸업한 플레이어의 프로필에 1ST/2ND 도장 + 깃발 (흰색=일반 승리, 붉은색=특수 승리)
	var stamp_ids:Array=_board.state.player_ids
	_expect(_board._profiles[stamp_ids[0]]["avatar"].get_node_or_null("RankStamp")==null,"no rank stamp before anyone is ranked")
	_board.state.rankings.append(stamp_ids[0]);_board.state.rank_reasons[stamp_ids[0]]=VictoryChecker.ALL_HOME
	_board.state.rankings.append(stamp_ids[1]);_board.state.rank_reasons[stamp_ids[1]]=&"LAW_01"
	_board._refresh_all();await settle()
	await screenshot("rank-stamps")
	var first_stamp: Variant=_board._profiles[stamp_ids[0]]["avatar"].get_node_or_null("RankStamp")
	var second_stamp: Variant=_board._profiles[stamp_ids[1]]["avatar"].get_node_or_null("RankStamp")
	_expect(first_stamp!=null and first_stamp.label_text=="1ST" and not first_stamp.special,"일반 완주 1위는 흰 깃발 1ST 도장")
	_expect(second_stamp!=null and second_stamp.label_text=="2ND" and second_stamp.special,"법전(특수 승리) 2위는 붉은 깃발 2ND 도장")
	_expect(_board._profiles[stamp_ids[2]]["avatar"].get_node_or_null("RankStamp")==null,"아직 순위가 없는 플레이어에게는 도장이 없다")
	_expect(first_stamp!=null and _board._profiles[stamp_ids[0]]["avatar"].get_global_rect().grow(2.0).encloses(first_stamp.get_global_rect()) and first_stamp.size.x<=_board._profiles[stamp_ids[0]]["avatar"].size.x+1.0,"도장이 프로필 그림 안에 있다")
	_board._refresh_all();await settle()
	_expect(_board._profiles[stamp_ids[0]]["avatar"].find_children("RankStamp","",true,false).size()==1,"갱신해도 도장이 겹쳐 쌓이지 않는다")
	_board.state.rankings.clear();_board.state.rank_reasons.clear();_board._refresh_all();await settle()
	_expect(_board._profiles[stamp_ids[0]]["avatar"].get_node_or_null("RankStamp")==null,"순위가 없으면 도장이 사라진다")
	# 법전 책: 새 교칙이 제정되면 중앙에 펼친 책으로 그림·이름·승리 조건을 보여 준다.
	for language: String in ["ko","en","ja"]:
		L10n.set_language(language)
		var new_law:=LawRegistry.create("LAW_01")
		_board.state.rulebook.enqueue_law(new_law)
		var book:=_board._make_law_book(new_law)
		_board.add_child(book);book.position=Vector2(300,150);await settle()
		await screenshot("law-book-"+language)
		_expect(book.find_children("*","TextureRect",true,false).size()>=1,"법전 책 왼쪽 쪽에 교칙 그림이 있다 (%s)"%language)
		var texts:=book.find_children("*","Label",true,false).map(func(label:Node)->String:return (label as Label).text)
		_expect(texts.has(new_law.law_name) and texts.has(new_law.description),"법전 책에 새 교칙 이름과 승리 조건이 있다 (%s)"%language)
		_expect(book.get_global_rect().size.x<=_board.get_viewport_rect().size.x and book.get_global_rect().size.y<=_board.get_viewport_rect().size.y*0.7,"법전 책이 화면 안에 들어간다 (%s %s)"%[language,book.get_global_rect().size])
		book.queue_free();await settle()
	L10n.set_language(old_language)
	# Result diagnostics must use departure facts, never synthetic retirement finishes.
	var helper:=load("res://tests/test_live_hotfix.gd").new() as TestCase
	var game:=helper.make_state(4);helper.place(game,11,5);helper.place(game,21,9);helper.place(game,31,13);helper.place(game,41,17)
	helper.add_law(game,"LAW_01");game.add_stat(1,&"kills",10)
	_board.state=game;_board.manager.state=game;_board.manager.is_game_over=false;_board.manager.end_when_graduated=[1]
	_board._show_choice("Target",[{"label":"P2","value":2}],func(_v: Variant)->void:pass)
	MobileSupport.force_touch=true;_board._open_zoom(1,&"ACT_04");MobileSupport.force_touch=false
	_board.manager._judge_special_victory();await settle()
	_expect(_board._choice_overlay==null and _board._zoom_view==null,"victory closes priority choices/previews before the result")
	_expect(not _board._stage_pinball.visible and not _board._stage_blackjack.visible and not _board._stage_yacht.visible,"no judgement stage covers the final result")
	var report:=_board._build_diagnostic_snapshot()
	_expect(report.contains("완주 0/4") and not report.contains("완주 4/4"),"special victory snapshot preserves every real finish count")
	_expect(report.contains("9번") and report.contains("기물 슬레이어") and report.contains("달성 완료"),"snapshot retains real tiles and achieved law name")
	_expect(_board._result_overlay!=null or _board._presentation_active(),"victory transitions to the result presentation")
	_board._reset_presentation();_board._close_zoom();_board._close_choice();MatchTelemetry.test_sender=Callable()
	var board:=_board;_board=null;board.queue_free();await settle()
	for failure: String in _failures:printerr("HOTFIX_UI_FAIL ",failure)
	print("HOTFIX_UI ",checks," assertions; ",_failures.size()," failures")
	quit(0 if _failures.is_empty() else 1)
