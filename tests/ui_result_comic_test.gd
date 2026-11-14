## 4등→3등→2등→뜸→1등의 순서/스포일러 방지/비대칭 컷과 기존 다음 장 흐름.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func _entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rank: int in range(1, 5):
		var face := ColorRect.new()
		face.color = Color.BLACK
		out.append({"rank": rank, "name": "닉네임%d" % rank, "color": Color("ff6b6b"), "avatar": face, "art": null})
	return out


func _page_alone() -> void:
	var page := ResultComicPage.new()
	root.add_child(page)
	page.setup(_entries(), "RACE OVER", "말 4개 모두 완주")
	await settle()
	page.set_time(0.0)
	_expect(not page._left.visible and page.stamp.modulate.a == 0.0, "처음에는 우승자 그림과 도장이 공개되지 않는다")
	page.set_time(ResultComicPage.FADE_SECONDS * 0.5)
	_expect(ResultComicPage.fade_alpha(page._time_view) > 0.0 and ResultComicPage.fade_alpha(page._time_view) < 1.0 and not page.panels[0].visible, "먼저 기존 화면에서 검정으로 페이드한다")
	page.set_time(ResultComicPage.FADE_SECONDS + 0.05)
	_expect(ResultComicPage.fade_alpha(page._time_view) == 1.0 and not page.panels[0].visible and not page.panels[3].visible, "Result 전에 온전한 검은 화면이 있다")
	page.set_time(ResultComicPage.RESULT_AT + ResultComicPage.PANEL_LEN)
	_expect(page.panels[0].visible and not page.panels[3].visible, "Result 제목만 먼저 자리를 잡는다")
	for index: int in [3,2,1]:
		page.set_time(ResultComicPage.panel_start(index) + ResultComicPage.PANEL_LEN)
		_expect(page.panels[index].visible and page.panels[index].position.length() < 0.5, "%d등은 짧게 들어와 제자리에서 멈춘다" % (index+1))
		for unrevealed: int in range(1,index):
			_expect(not page.panels[unrevealed].visible, "아직 차례가 아닌 %d등의 이름은 공개되지 않는다" % (unrevealed+1))
		_expect(not page._left.visible and page.winner_label.modulate.a == 0.0, "하위 순위 발표 중 1등 그림/이름은 보이지 않는다")
	_expect(ResultComicPage.panel_start(2) - ResultComicPage.panel_start(3) >= 0.65 and ResultComicPage.panel_start(1) - ResultComicPage.panel_start(2) >= 0.65, "하위 순위가 촤르륵 겹치지 않고 한 박자씩 분리된다")
	var second_settled := ResultComicPage.panel_start(1) + ResultComicPage.PANEL_LEN
	_expect(ResultComicPage.LEFT_START - second_settled >= 0.85, "2등 정착 뒤 1등 등장까지 뜸을 들인다")
	page.set_time(ResultComicPage.LEFT_START - 0.01)
	_expect(not page._left.visible and page.winner_label.modulate.a == 0.0 and page.stamp.modulate.a == 0.0, "뜸들이는 동안 우승자가 먼저 새지 않는다")
	page.set_time(ResultComicPage.LEFT_END)
	_expect(page._left.visible and page._left.position.length() < 0.5 and page.stamp.modulate.a == 0.0, "1등 큰 컷이 마지막에 들어온 뒤 도장을 기다린다")
	page.set_time(ResultComicPage.STAMP_AT)
	_expect(page.stamp.modulate.a > 0.99 and page.stamp.scale.is_equal_approx(Vector2.ONE), "1등 도장이 마지막으로 찍힌다")
	_expect(page.next_button.disabled, "최종 정착 전에 다음 장을 누를 수 없다")
	var landed: Array[int] = []
	var impacts: Array[int] = [0]
	page.panel_landed.connect(func(index: int) -> void: landed.append(index))
	page.impact.connect(func() -> void: impacts[0] += 1)
	page.play(1.0)
	await create_timer(ResultComicPage.DURATION + 0.3).timeout
	_expect(landed == [3,2,1], "실시간 착지 신호도 4등→3등→2등 순서이며 헤더는 제외 (%s)" % [landed])
	_expect(impacts[0] == 1, "마지막 우승자 impact는 한 번")
	_expect(not page.active and not page.next_button.disabled, "전체 발표가 끝나면 다음 장 활성화")
	var nexts: Array[int] = [0]
	page.next_pressed.connect(func() -> void: nexts[0] += 1)
	page.next_button.pressed.emit()
	_expect(nexts[0] == 1, "다음 장 연결 유지")
	for view: Vector2 in [Vector2(1366,768),Vector2(960,540),Vector2(640,360)]:
		page.anchor_right = 0;page.anchor_bottom = 0;page.size = view;page._relayout();page.set_time(ResultComicPage.DURATION)
		var title_center := Vector2.ZERO
		for corner: Vector2 in page.result_title_corners():
			_expect(Geometry2D.is_point_in_polygon(corner,page.panels[0].polygon), "Result의 외곽선·그림자까지 헤더 컷 안에 들어간다")
			title_center += corner*0.25
		_expect(title_center.x > view.x*0.77 and title_center.x < view.x*0.82 and title_center.y < view.y*0.14, "Result는 헤더 중앙에 배치된다")
		for index: int in [1,2,3]:
			var avatar := page.panels[index].get_node("Avatar") as Control
			var poly := page.panels[index].polygon
			var tag := page.panels[index].get_node("Tag") as Label
			var label := page.panels[index].get_node("Name") as Label
			var edge := poly[1] - poly[0]
			_expect(avatar.size.y > (poly[2].y-poly[1].y)*1.4 and avatar.position.y < poly[0].y, "얼굴은 작은 스티커가 아니라 컷 위아래까지 채우는 클로즈업이다")
			_expect(tag.position.distance_to(poly[0]) < view.x * 0.025, "순위는 얼굴 옆이 아니라 해당 컷 좌상단 모서리에 붙는다")
			_expect(absf(label.rotation - atan2(edge.y,edge.x)) < 0.001, "이름은 컷 윗변의 기울기를 따른다")
			_expect(Geometry2D.is_point_in_polygon(avatar.position + avatar.size * 0.5,page.panels[index].polygon), "각 해상도에서 얼굴 중심이 해당 비대칭 컷 안에 들어간다")
	# Long Korean and wide Latin names retain all ten characters at each supported layout.
	for full_name: String in ["가나다라마바사아자차","WWWWWWWWWW"]:
		var long_entries := _entries()
		for entry: Dictionary in long_entries:entry["name"]=full_name
		var names_page := ResultComicPage.new()
		root.add_child(names_page);names_page.setup(long_entries,"RACE OVER","")
		await settle(2)
		for view: Vector2 in [Vector2(1366,768),Vector2(960,540),Vector2(640,360)]:
			names_page.anchor_right=0;names_page.anchor_bottom=0;names_page.size=view;names_page._relayout();names_page.set_time(ResultComicPage.DURATION)
			for index: int in [1,2,3]:
				var label: Label = names_page.panels[index].get_node("Name")
				var tag: Label = names_page.panels[index].get_node("Tag")
				_expect(label.text.replace("\n","")==full_name and label.get_line_count()<=2,"10글자 이름 전체를 최대 두 줄로 출력한다")
				var corners := PackedVector2Array()
				var padded := Rect2(Vector2(-5,-5),label.size+Vector2(10,10))
				for point: Vector2 in [padded.position,Vector2(padded.end.x,padded.position.y),padded.end,Vector2(padded.position.x,padded.end.y)]:corners.append(label.get_transform()*point)
				var inside := true
				for corner: Vector2 in corners:
					if not Geometry2D.is_point_in_polygon(corner,names_page.panels[index].polygon):inside=false
				_expect(inside,"회전·외곽선을 포함한 10글자 이름이 순위 컷 바깥으로 넘치지 않는다")
				_expect(tag.get_theme_font("font")==ResultComicPage.RESULT_FONT and tag.get_node_or_null("RankBubble")!=null,"2~4등은 전용 카툰 글꼴과 말풍선을 쓴다")
			var winner := names_page.winner_label
			_expect(winner.text==full_name and winner.size.x*winner.scale.x < view.x*0.48,"1등의 10글자 이름도 생략하지 않고 배정 폭에 들어간다")
		_expect(names_page.stamp.get_theme_font("font")==ResultComicPage.RESULT_FONT and names_page.stamp.get_node_or_null("RankBubble")!=null,"1등도 같은 카툰 글꼴과 우승 말풍선을 쓴다")
		names_page.queue_free();await settle(2)
	var page2 := ResultComicPage.new()
	root.add_child(page2);page2.setup(_entries().slice(0,2),"RACE OVER","")
	var impacts2: Array[int] = [0]
	var short_landed: Array[int] = []
	page2.impact.connect(func() -> void: impacts2[0] += 1)
	page2.panel_landed.connect(func(index: int) -> void:short_landed.append(index))
	page2.play(1.0);await settle(2);page2.skip();page2.skip()
	_expect(impacts2[0] == 1 and not page2.active and short_landed == [1], "2인 판 건너뛰기는 없는 3/4등을 발표하지 않고 impact 한 번")
	page.queue_free();page2.queue_free();await settle()


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	await _page_alone()
	_board._on_draft_auto_pressed()
	await settle(10)
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	for avatar: StringName in AvatarCatalog.ids():
		_expect(ResourceLoader.exists(ResultFaceArt.path_for(avatar)), "선택 가능한 아바타의 전용 팝아트 얼굴이 모두 있다: " + String(avatar))
		var tex := ResultFaceArt.texture(avatar)
		_expect(tex != null and tex.get_image().get_pixel(0,0).a == 0.0, "얼굴 원본은 배경 없는 투명 이미지다: " + String(avatar))
	var state: GameState = _board.state
	state.rankings = [1, 3, 2, 4] as Array[int]
	state.winner = 1
	state.rank_reasons[1] = VictoryChecker.ALL_HOME
	_board.instant_roll_for_test = false  # 연출을 켠다: 결과 1쪽(만화 컷)부터
	for player: int in [1,2,3,4]:
		state.law_stats[player]={GameState.TALLY_KILLS:player*2,GameState.TALLY_DEATHS:player+1,&"kills":99,&"ejected":88}
	var rng_before := state.rng.state
	var time_before := Engine.time_scale
	_board._show_result_overlay()
	var comic: ResultComicPage = _board._result_overlay.find_child("ResultComicPage", true, false) as ResultComicPage
	_expect(comic != null, "연출이 켜져 있으면 결과 1쪽 만화 컷부터")
	_expect(comic._art.texture == AvatarCombatArt.texture(_board._avatar_for(1),&"victory") and comic._art.texture != ResultFaceArt.texture(_board._avatar_for(1)), "1등은 얼굴 스티커 대신 기존 승리 컷신 포즈를 재사용한다")
	for index: int in [1,2,3]:
		_expect(comic.panels[index].get_node("Avatar").material is ShaderMaterial, "확대 얼굴은 각 사선 컷의 잉크 경계 안쪽에서만 그린다")
		_expect(comic.panels[index].get_node("Avatar") is TextureRect, "결과에는 둥근 AvatarSlot 대신 얼굴 컷아웃을 직접 쓴다")
	_expect(comic.panels[0].get_node("ResultTitle").get_theme_font("font") == ResultComicPage.RESULT_FONT and comic.panels[1].get_node("Name").get_theme_font("font") != ResultComicPage.RESULT_FONT, "Result는 카툰 글꼴을 쓰고 이름은 기존 UI 글꼴을 유지한다")
	_expect(_board._caption.lines().is_empty(), "결과창에 이전 차례 자막이 남지 않는다")
	_expect(_board._result_overlay.get_parent() is CanvasLayer and (_board._result_overlay.get_parent() as CanvasLayer).layer == 10000, "결과는 게임 도구보다 앞, 피드백 전용 층보다 뒤")
	var report := _board._result_overlay.find_child("ResultComicReport",true,false) as ResultComicReport
	_expect(report!=null and _board._result_overlay.find_child("Podium",true,false)==null,"기존 시상대 모달 대신 만화 결과 리포트가 준비된다")
	_expect(report.find_child("ReportTitle",true,false).text=="RESULT REPORT","새 결과 리포트의 전용 만화 타이틀")
	var restart: Button = _board._result_overlay.find_child("LobbyButton", true, false) as Button
	_expect(restart != null and not restart.is_visible_in_tree(), "상세 결과표는 [Next Page] 전까지 숨김")
	_expect(_board.result_comic_texts(1) == (["RACE OVER", "말 4개 모두 완주"] as Array[String]), "완주 우승의 승리 이름·조건")
	var expected_phrases := {"LAW_01":"Mochi Reality Shock","LAW_02":"SWEET VICTORY","LAW_03":"Unlimited Trap Works","LAW_04":"JACK POT","LAW_05":"CIRCLE COMPLETE","LAW_06":"Perma Death","LAW_07":"ENDLESS DICE","LAW_08":"Attack on Meeple"}
	for law_id: String in expected_phrases:
		state.rank_reasons[1]=StringName(law_id)
		_expect(_board.result_comic_texts(1)[0]==expected_phrases[law_id],"특수 승리 결과도 승인된 컷신 승리 문구를 쓴다: "+law_id)
	state.rank_reasons[1]=VictoryChecker.ALL_HOME
	var deadline := Time.get_ticks_msec() + 8000
	while comic != null and (not comic.visible or comic.active) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(comic.visible and not comic.active and comic.stamp.modulate.a > 0.99, "등장이 끝나 1st 도장까지")
	var names: Array[String] = []
	for index: int in range(1, 4):
		names.append((comic.panels[index].get_node("Name") as Label).text)
	_expect(names == ([_board._player_name(3), _board._player_name(2), _board._player_name(4)] as Array[String]), "2nd·3rd·4th 패널 이름 (%s)" % [names])
	comic.next_button.pressed.emit()
	var turning := _board._result_overlay.get_node_or_null("ResultPageTurn") as ResultPageTurn
	_expect(turning != null and turning.mouse_filter == Control.MOUSE_FILTER_STOP, "넘기는 동안 새 결과 버튼을 잘못 누르지 않게 막는다")
	turning.set_process(false)
	var report_impacts: Array[int]=[0]
	turning.impact.connect(func() -> void:report_impacts[0]+=1)
	turning.seek(ResultPageTurn.ENTER_DELAY)
	_expect(report.position.y < -root.get_visible_rect().size.y,"리포트는 화면 위에서 시작한다")
	_expect(restart.disabled and (report.find_child("SelectRecord1",true,false) as Button).disabled,"내려찍는 동안 기능 버튼과 기록 선택의 키보드·포인터 입력을 잠근다")
	turning.seek(ResultPageTurn.IMPACT_AT-0.005)
	_expect(report_impacts[0]==0,"바닥에 닿기 전에 충격 신호가 나가지 않는다")
	turning.seek(ResultPageTurn.IMPACT_AT)
	var contact_scale:=report.scale
	var contact_position:=report.position
	_expect(report_impacts[0]==1 and contact_scale.y<1.0 and contact_scale.x>1.0,"착지 한 번에만 충격이 나고 종이가 눌린다")
	turning.seek(ResultPageTurn.IMPACT_AT+ResultPageTurn.HOLD_SECONDS*0.8)
	_expect(report.scale==contact_scale and report.position==contact_position,"충격 순간 짧게 멈추는 것은 리포트 시계 안에서만 처리한다")
	turning.set_process(true)
	var detail_root: Control = restart
	while detail_root.get_parent() != _board._result_overlay:detail_root = detail_root.get_parent()
	_board._turn_result_page(comic, detail_root, [] as Array[Control], _board._result_overlay.find_child("RankingAnnouncer",true,false) as Label)
	_expect(_board._result_overlay.find_children("ResultPageTurn", "", false, false).size() == 1, "연속 입력으로 페이지 넘김이 중복 생성되지 않는다")
	await create_timer(_board.RESULT_PAGE_IN + 0.25).timeout
	_expect(not is_instance_valid(comic) or comic.is_queued_for_deletion(), "넘긴 만화 컷은 치운다")
	_expect(restart.is_visible_in_tree(), "상세 결과표가 펼쳐진다")
	var detail: Control = restart
	while detail.get_parent() != _board._result_overlay:
		detail = detail.get_parent()
	_expect(absf(detail.position.x) < 1.0 and absf(detail.rotation) < 0.001, "상세 결과표가 제자리에 (x=%.1f)" % detail.position.x)
	_expect(_board._result_overlay.get_node_or_null("ResultPageTurn") == null, "넘긴 뒤 입력 덮개와 접힘 그림자가 남지 않는다")
	_expect(is_equal_approx(detail.scale.x,1.0) and detail.modulate == Color.WHITE, "상세 결과표는 축소나 음영이 남지 않는다")
	_expect(not restart.disabled,"충격 연출이 끝나면 원래 버튼 입력 상태를 복원한다")
	for index: int in range(1,5):
		var rank_cut:=report.find_child("Rank%d"%index,true,false)
		var expected:=VictoryChecker.standings(state,_board.manager.player_order,state.winner)[index-1]
		_expect(rank_cut.get_meta("finished")==expected["finished"] and rank_cut.get_meta("remaining")==expected["remaining"],"리포트는 실제 완주 수와 남은 거리 기록을 유지한다")
	_expect(report.find_child("WinnerPose",true,false)==null and report.find_child("ReportStats1",true,false)==null and report.find_child("ReportReason1",true,false)==null,"승리 일러스트 반복과 좁은 순위 칸의 빽빽한 기록 문장을 제거한다")
	for index: int in range(4):
		(report.find_child("SelectRecord%d"%(index+1),true,false) as Button).pressed.emit()
		var entry:=VictoryChecker.standings(state,_board.manager.player_order,state.winner)[index]
		var player:=int(entry["player"])
		_expect(report.selected_index==index and report.find_child("RecordKills",true,false).text==str(state.stat(player,GameState.TALLY_KILLS)) and report.find_child("RecordDeaths",true,false).text==str(state.stat(player,GameState.TALLY_DEATHS)),"플레이어 선택 시 법전 수치가 아닌 실제 킬·데스를 표시한다")
		_expect(report.find_child("RecordProgress",true,false).text=="%d%%"%int(entry["progress"]),"선택한 플레이어의 실제 진행률을 크게 표시한다")
	report.select_record(-1)
	_expect(report.selected_index==3,"잘못된 선택은 기존 기록을 바꾸지 않는다")
	report.select_record(0)
	# Exercise real GUI dispatch for the new selector (other transition checks use signals).
	var selector:=report.find_child("SelectRecord3",true,false) as Button
	var pointer:=selector.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pointer;root.push_input(motion,true)
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=pointer;press.pressed=true
	root.push_input(press,true);await settle(1)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=pointer;release.pressed=false
	root.push_input(release,true);await settle(2)
	_expect(report.selected_index==2,"실제 포인터 입력도 순위 컷을 선택해 왼쪽 기록을 바꾼다")
	var sample:=report._entries.duplicate(true)
	sample[2]["kills"]=0;sample[2]["deaths"]=0
	var preferred:=ResultComicReport.new();root.add_child(preferred)
	preferred.setup(sample,"RACE OVER","말 4개 모두 완주",14,int(sample[2]["player"]))
	await settle(2)
	_expect(preferred.selected_index==2 and preferred.find_child("RecordName",true,false).text==sample[2]["name"],"본인이 우승자가 아니어도 본인 기록을 먼저 표시한다")
	_expect(preferred.find_child("RecordKills",true,false).text=="0" and preferred.find_child("RecordDeaths",true,false).text=="0","킬·데스가 없는 경우에도 실제 0을 표시한다")
	_expect(state.stat(1,GameState.TALLY_KILLS)==2 and state.stat(1,&"kills")==99,"기록 탐색은 실제 누적 기록이나 법전 진행도를 바꾸지 않는다")
	preferred.queue_free();await settle(2);report.select_record(0)
	var vote:=report.find_child("VoteBar",true,false) as Control
	_board._open_vote_details(vote,"잘 모르겠어요")
	await settle(3)
	_expect(vote.find_child("VoteDetails",true,false)!=null,"새 만화 페이지에서도 아쉬운 점 후속 투표를 열 수 있다")
	for view: Vector2 in [Vector2(1366,768),Vector2(960,540),Vector2(640,360)]:
		report.anchor_right=0;report.anchor_bottom=0;report.size=view;report._layout()
		var visible:=Rect2(Vector2.ZERO,view)
		var fits:=true
		for node: Node in report.find_children("*","Button",true,false):
			if not visible.encloses((node as Button).get_global_rect()):fits=false
		_expect(fits,"확장된 후속 투표와 하단 기능이 %dpx 화면 안에 들어간다"%int(view.x))
	report.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);report._layout()
	_board._on_vote_pressed(vote,"test intercepted vote",false)
	await settle(3)
	_expect(vote.find_child("VoteThanks",true,false)!=null and bool(vote.get_meta("voted")),"기존 투표 완료 동작과 중복 투표 방지가 유지된다")
	var review := _board._result_overlay.find_child("ReviewFeedbackButton",true,false) as Control
	_expect(root.get_visible_rect().encloses(review.get_global_rect()), "펼쳐진 상세 결과표의 마지막 후기 버튼까지 화면 안에 보인다")
	_expect(state.rng.state == rng_before and Engine.time_scale == time_before, "도장 정지와 페이지 넘김은 게임 RNG와 전역 시간을 바꾸지 않는다")
	# The result can be closed/restarted while a fold is active.
	_board._close_result_overlay();await settle()
	_board._show_result_overlay();await settle(2)
	var closing := _board._result_overlay.find_child("ResultComicPage",true,false) as ResultComicPage
	closing.skip();closing.next_button.pressed.emit();await settle(2)
	var old_overlay := _board._result_overlay
	_board._close_result_overlay();await settle(8)
	_expect(not is_instance_valid(old_overlay) and _board.find_children("ResultPageTurn","",true,false).is_empty(), "페이지를 넘기는 도중 닫아도 고아 연출이나 입력 잠금이 남지 않는다")
	_board._close_result_overlay()
	_board.instant_roll_for_test = true
	state.rank_reasons[1]=&"LAW_03"
	state.rank_stats[1]={"finished":1,"remaining":70,"progress":47}
	_board._show_result_overlay();await settle(3)
	var immediate:=_board._result_overlay.find_child("ResultComicReport",true,false) as ResultComicReport
	_expect(immediate!=null and immediate.is_visible_in_tree() and _board._result_overlay.find_child("ResultComicPage",true,false)==null,"연출을 끈 경우에도 새 리포트를 즉시 보여 준다")
	_expect(immediate.find_child("RecordFinished",true,false).text=="완주 1/4","특수 승리 결과는 실제 완주 1/4를 유지하고 4/4로 바꾸지 않는다")
	_expect(immediate.find_child("ReportVictoryPhrase",true,false).text=="Unlimited Trap Works","특수 승리의 리포트 문구도 기존 컷신 문구와 같다")
	_board._close_result_overlay();await settle(3)
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("RESULT_COMIC_FAIL ", failure)
	print("RESULT_COMIC ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
