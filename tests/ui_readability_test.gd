## 2026-11 연출 납득 보강: 사건 자막(최근 두 줄, 굴림 제외, 중요 사건 금테), 읽을 시간 보장, 느려진 AI 터보, 사람을 겨눈 AI 턴은 보통 속도.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	# 1) 읽을 시간: 글이 길수록 오래, 상·하한
	_expect(is_equal_approx(EventCaption.reading_seconds(""), EventCaption.READ_MIN_SECONDS), "빈 글은 최소 시간")
	_expect(EventCaption.reading_seconds("가".repeat(28)) > EventCaption.reading_seconds("가".repeat(7)), "긴 글일수록 오래 띄운다")
	_expect(is_equal_approx(EventCaption.reading_seconds("가".repeat(400)), EventCaption.READ_MAX_SECONDS), "아주 긴 글도 상한까지만")
	_expect(is_equal_approx(EventCaption.reading_seconds("[color=#ff0000][b]처치![/b][/color]"), EventCaption.reading_seconds("처치!")), "bbcode 태그는 글자 수에 넣지 않는다")
	_expect(MainBoard.announce_reading_seconds("가".repeat(200), "") <= MainBoard.ANNOUNCE_READ_MAX, "알림 읽기 시간 상한")
	_expect(MainBoard.announce_reading_seconds("함정 발동!", "", {"sub": "P2-말1"}) > EventCaption.READ_MIN_SECONDS, "도장 알림은 부제까지 읽을 시간")
	# 1배속 최소 표시 시간: 카드 발동!·공격! 같은 도장 알림은 1.8초 아래로 줄지 않는다 (배속은 게임 시간을 줄인다)
	_expect(MainBoard.stamp_min_hold({"key": "card", "sub": "P1"}) == MainBoard.STAMP_MIN_SECONDS and MainBoard.STAMP_MIN_SECONDS >= 1.7, "카드 발동! 도장은 1배속 최소 시간이 있다")
	for key: String in ["attack", "defense", "trap", "trap_set", "skill", "tarot", "npc", "extra_turn"]:
		_expect(MainBoard.stamp_min_hold({"key": key}) == MainBoard.STAMP_MIN_SECONDS, "%s 도장도 최소 시간" % key)
	_expect(MainBoard.stamp_min_hold({"key": "round"}) == 0.0 and MainBoard.stamp_min_hold({}) == 0.0, "라운드 표지·도장이 아닌 알림은 대상이 아니다")
	# 실제 알림: 1배속(터보 포함)에서도 카드 발동!은 1.8초 이상 띄우고, 라운드 표지는 그대로
	_board.pacing_enabled = true
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	_board._announce_now("카드 발동", "카드 발동!", "", Color.WHITE, null, 1.1, true, {"key": "card", "sub": "P1"})
	var queued: Array = ([_board._announcer._current] if not _board._announcer._current.is_empty() else []) + _board._announcer._queue
	_expect(not queued.is_empty() and float((queued[0] as Dictionary)["duration"]) >= MainBoard.STAMP_MIN_SECONDS, "카드 발동! 알림은 1배속에서 %.1f초 이상 (%s)" % [MainBoard.STAMP_MIN_SECONDS, str(queued[0]["duration"]) if not queued.is_empty() else "-"])
	_board._announcer.cancel()
	_board._announce_now("라운드", "ROUND 3", "", Color.WHITE, null, 1.0, true, {"key": "round"})
	queued = ([_board._announcer._current] if not _board._announcer._current.is_empty() else []) + _board._announcer._queue
	_expect(not queued.is_empty() and float((queued[0] as Dictionary)["duration"]) < MainBoard.STAMP_MIN_SECONDS, "라운드 표지는 짧게 그대로")
	_board._announcer.cancel()
	_board.pacing_enabled = false
	_board.instant_roll_for_test = true
	# 2) 속도: AI 터보가 덜 빠르고, 여운이 길어졌다
	_expect(MainBoard.TURBO_PACE_SCALE >= 0.75 and MainBoard.STEP_LINGER_SECONDS >= 0.5 and MainBoard.CALLOUT_SECONDS >= 1.2 and MainBoard.BEAT_AFTER_MOVE >= 0.45, "속도 보강 상수")
	# 3) 자막 분류
	_expect(not MainBoard.caption_worthy("[기본 주사위] 굴림 → 4칸"), "굴림 결과는 자막에서 뺀다")
	_expect(not MainBoard.caption_worthy("[BANG!] 사용! → P1") and not MainBoard.caption_worthy("[지뢰] 밟음! (5번 타일)") and not MainBoard.caption_worthy("은신 함정 설치!"), "카드·함정·설치 줄은 자막에서 뺀다 (로그에만)")
	_expect(not MainBoard.caption_worthy("!! 템포 업 Lv.1 - 첫 이동 +1칸 · 처치"), "템포 업은 자막에 올리지 않는다 (가운데 경고가 있다)")
	_expect(MainBoard.caption_worthy("■ 플레이어 1의 [1번 말] 처치!") and MainBoard.caption_worthy("순위 확정: 1위") and MainBoard.caption_worthy("[법전] 기물 슬레이어 등록!"), "처치·순위 확정·법전은 자막에 올린다")
	_expect(MainBoard.is_important_record("■ 플레이어 1의 [1번 말] 처치!") and MainBoard.is_important_record("[BANG!] 사용! → P1") and MainBoard.is_important_record("[지뢰] 밟음! (5번 타일)"), "처치·카드 사용·함정은 중요")
	_expect(not MainBoard.is_important_record("은신 함정 설치!") and not MainBoard.is_important_record("템포 업 +1 → 총 5칸 전진!"), "설치·추가 전진은 보통 줄")
	# 4) 보드에 붙은 자막
	_board._on_draft_auto_pressed()
	await settle(10)
	_board.instant_roll_for_test = true  # 연출 큐 없이 기록이 바로 자막에 오른다
	var caption: EventCaption = _board._caption
	_expect(caption != null and caption.is_inside_tree() and caption.position.y >= 60.0 and caption.position.y < 90.0, "자막은 위쪽 가운데, 증강 타임라인 바로 아래")
	caption.clear()
	await settle()
	_board._record(2, "[기본 주사위] 굴림 → 4칸")
	_expect(caption.lines().is_empty(), "굴림 줄은 자막에 오르지 않는다 (로그에만)")
	_board._record(2, "%s 사용! → P1" % _board._bq("BANG!"))
	_expect(caption.lines().is_empty(), "카드 사용 줄도 자막에 오르지 않는다")
	_board._record(2, "[1번 말] 처치!")
	_board._record(1, "순위 확정: 1위")
	var shown: Array[String] = caption.lines()
	_expect(shown.size() == 2 and shown[0].contains("순위 확정") and shown[1].contains("처치"), "새 줄이 위, 이전 줄은 아래 (%s)" % [shown])
	_expect(shown.size() == 2 and shown[1].contains(_board._player_name(2)), "누가 했는지 이름이 붙는다")
	if shown.size() < 2:
		quit(1)
		return
	var older: Control = caption.get_child(1) as Control
	_expect(older.modulate.a < 0.9 and bool(older.get_meta("important")), "이전 줄은 흐려지고, 처치는 중요 줄")
	_board._record(3, "[2번 말] 사출!")
	await settle()
	_expect(caption.lines().size() == EventCaption.MAX_LINES, "두 줄까지만")
	# 오래되면 사라진다
	for child: Node in caption.get_children():
		child.set_meta("expires", 0)
	await create_timer(EventCaption.FADE_SECONDS + 0.3).timeout
	_expect(caption.lines().is_empty(), "읽을 시간이 지나면 사라진다")
	# 5) 사람을 겨눈 AI 카드 턴은 보통 속도
	_board.ai_mode = true
	_board._spotlight_turn = false
	var human: int = _board.local_player_id
	_board._record_card({"player_id": human % 4 + 1, "card_id": &"ACT_02", "params": {"target_player": human}})
	_expect(_board._spotlight_turn, "AI가 사람을 겨눈 카드를 쓰면 그 턴은 주목(보통 속도)")
	_board._spotlight_turn = false
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("READABILITY_FAIL ", failure)
	print("READABILITY ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
