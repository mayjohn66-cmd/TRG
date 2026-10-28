# File: res://tests/test_match_telemetry.gd
# Class: class_name TestMatchTelemetry
# Role: 통계 알림 - 로비 입장·매치 시작·매치 완료 한 줄 문구, 익명 태그와 누적 판 수, 모드·우승 방식 이름, 웹이 아니면 보내지 않음, 켜졌을 때 조용한 웹후크 본문
class_name TestMatchTelemetry
extends TestCase

const AUGMENTS: Array[String] = ["체스 퀸 진화", "주사위 교체"]


func cleanup() -> void:
	MatchTelemetry.test_force_enabled = false
	MatchTelemetry.test_sender = Callable()
	MatchTelemetry._lobby_reported = false
	super()


func test_lines_follow_the_three_formats() -> void:
	check_eq(MatchTelemetry.lobby_line("교주(#A7B2)", "PC", "0.9.0+abc1234"), "%s 교주(#A7B2) | PC | v0.9.0+abc1234" % MatchTelemetry.lobby_tag(), "로비 입장")
	check_eq(MatchTelemetry.start_line("교주(#A7B2)", "놀이터", 3), "%s 교주(#A7B2) | 놀이터 | 3번째 판 시작" % MatchTelemetry.start_tag(), "매치 시작")
	check_eq(MatchTelemetry.end_line("교주(#A7B2)", 3, "놀이터", 13, 754, 2, "특수승리(투기장의 지배자)", AUGMENTS),
		"%s 교주(#A7B2) (3번째 판) | 놀이터 | 13라운드(소요시간 12분 34초) | 내 최종 순위: 2위 | 1위 우승방식: 특수승리(투기장의 지배자) | 고른 증강: 체스 퀸 진화, 주사위 교체" % MatchTelemetry.tag(), "매치 완료")
	check(MatchTelemetry.end_line("A(#B2C3)", 1, "4인 수동", 5, 30, 0, "일반", [] as Array[String]).contains("내 최종 순위: - | 1위 우승방식: 일반 | 고른 증강: 없음"), "한 화면 4인 수동은 순위 칸이 비고 증강이 없으면 [없음]")
	check_eq(MatchTelemetry.tag(), "[%s 매치 완료]" % String.chr(0x1F4CA), "📊")
	check_eq(MatchTelemetry.lobby_tag(), "[%s 로비 입장]" % String.chr(0x1F44B), "👋")
	check_eq(MatchTelemetry.start_tag(), "[%s 매치 시작]" % String.chr(0x1F3AE), "🎮")


func test_mode_win_and_duration_labels() -> void:
	check_eq(MatchTelemetry.mode_label(false, true), "놀이터", "컴퓨터와 대전")
	check_eq(MatchTelemetry.mode_label(true, true, false), "친선", "방 코드 방")
	check_eq(MatchTelemetry.mode_label(true, true, true), "익명", "빠른 매칭")
	check_eq(MatchTelemetry.mode_label(false, false), "4인 수동", "한 화면")
	check_eq(MatchTelemetry.win_label(VictoryChecker.ALL_HOME), "일반", "말 4개 완주")
	check_eq(MatchTelemetry.win_label(&"LAW_01"), "특수승리(투기장의 지배자)", "특수 승리는 교칙 이름까지")
	check_eq(MatchTelemetry.duration_text(65), "1분 5초", "걸린 시간")
	check_eq(MatchTelemetry.device_label(), "PC", "데스크톱 테스트는 PC")


func test_anonymous_tag_is_four_safe_characters_and_stays_the_same() -> void:
	var tag: String = GameSession.player_tag()
	check(GameSession.is_valid_tag(tag), "4자리 영숫자 (%s)" % tag)
	check_eq(GameSession.player_tag(), tag, "다시 물어도 같은 태그")
	check(GameSession.tagged_name().ends_with("(#%s)" % tag), "닉네임(#태그)")
	check(not GameSession.is_valid_tag("A0O1") and not GameSession.is_valid_tag("ABC"), "헷갈리는 글자·길이 틀림은 무효")
	var before: int = GameSession.match_count()
	check_eq(GameSession.begin_match(), before + 1, "판을 시작하면 누적 판 수가 오른다")
	check_eq(GameSession.match_count(), before + 1, "저장된 판 수")


func test_nothing_is_sent_outside_a_web_build() -> void:
	var sent: Array = []
	MatchTelemetry.test_sender = func(url: String, _body: PackedByteArray, _type: String) -> void: sent.append(url)
	check(not MatchTelemetry.is_active(), "에디터·테스트에서는 꺼져 있다")
	check(not MatchTelemetry.report_lobby_entry(null), "로비 입장도 보내지 않는다")
	check(not MatchTelemetry.report_match_start(null, "놀이터", 1), "매치 시작도")
	check(not MatchTelemetry.report_match_end(null, 1, "놀이터", 5, 60, 1, VictoryChecker.ALL_HOME, AUGMENTS), "매치 완료도")
	check(sent.is_empty(), "전송 함수가 불리지 않는다")


func test_enabled_reports_are_quiet_and_lobby_entry_is_once_per_session() -> void:
	var sent: Array = []
	MatchTelemetry.test_force_enabled = true
	MatchTelemetry.test_sender = func(url: String, body: PackedByteArray, content_type: String) -> void: sent.append([url, body.get_string_from_utf8(), content_type])
	check(MatchTelemetry.report_lobby_entry(null), "로비 입장")
	check(not MatchTelemetry.report_lobby_entry(null), "같은 접속에서 두 번째 입장은 보내지 않는다")
	check(MatchTelemetry.report_match_start(null, "친선", 4), "매치 시작")
	check(MatchTelemetry.report_match_end(null, 4, "친선", 13, 754, 1, &"LAW_01", AUGMENTS), "매치 완료")
	check_eq(sent.size(), 3, "세 줄")
	check_eq(sent[0][0], FeedbackModal.DISCORD_WEBHOOK_URL, "전용 주소가 없으면 피드백 웹후크를 쓴다")
	check((sent[0][1] as String).contains(MatchTelemetry.lobby_tag() + " " + GameSession.tagged_name() + " | PC | v"), "로비 입장 줄")
	check((sent[1][1] as String).contains("| 친선 | 4번째 판 시작"), "매치 시작 줄")
	check((sent[2][1] as String).contains("내 최종 순위: 1위 | 1위 우승방식: 특수승리(투기장의 지배자)"), "매치 완료 줄")
	for entry: Array in sent:
		check((entry[1] as String).contains("\"flags\":4096") and (entry[1] as String).contains("\"allowed_mentions\":{\"parse\":[]}"), "알림음 없이, 멘션 막고")
		check((entry[2] as String).begins_with("multipart/form-data; boundary="), "사전 확인 없이 가는 multipart")


func test_end_line_carries_the_difficulty_figures() -> void:
	var line: String = MatchTelemetry.end_line("교주(#A7B2)", 10, "놀이터", 14, 900, 3, "일반", AUGMENTS, {"winner": "컴퓨터 4", "kills": 3, "deaths": 5, "played": 10, "wins": 2})
	check(line.contains("내 최종 순위: 3위 / 우승자: 컴퓨터 4 | 1위 우승방식: 일반"), "내 순위와 우승자 (%s)" % line)
	check(line.contains("| 킬/데스: 3킬 5데스 |") and line.contains("| 누적: 10판 중 1위 2회 |"), "킬/데스와 누적 승률")
	check(line.ends_with("고른 증강: 체스 퀸 진화, 주사위 교체"), "증강은 마지막")
	var hotseat: String = MatchTelemetry.end_line("A(#B2C3)", 1, "4인 수동", 5, 30, 0, "일반", [] as Array[String], {"winner": "플레이어 2"})
	check(hotseat.contains("내 최종 순위: - / 우승자: 플레이어 2") and not hotseat.contains("킬/데스") and not hotseat.contains("누적:"), "4인 수동은 우승자만")


func test_vote_line_and_choices() -> void:
	check_eq(MatchTelemetry.vote_tag(), "[%s%s 유저 미니투표]" % [String.chr(0x1F5F3), String.chr(0xFE0F)], "🗳️")
	var choices: Array = MatchTelemetry.vote_choices()
	check_eq(choices.size(), 5, "버튼 5개")
	check(str(choices[0][1]).ends_with("템포·역전 각 딱 재밌어요!") and str(choices[3][2]) == "말이 자꾸 죽어서 완주가 답답해요", "디스코드 글·화면 글")
	for choice: Array in choices:
		check(not L10n.has_hangul(L10n.translate_text(str(choice[2]), "en")) and not L10n.has_hangul(L10n.translate_text(str(choice[2]), "ja")), "투표 버튼 번역 (%s)" % choice[2])
	var line: String = MatchTelemetry.vote_line("교주(#A7B2)", str(choices[1][1]), "  빵집 털이 사기\n진짜로  ", 3, 14)
	check_eq(line, "%s 교주(#A7B2) | %s | 빵집 털이 사기 진짜로 | (3위 · 14라운드)" % [MatchTelemetry.vote_tag(), choices[1][1]], "투표 한 줄 (줄바꿈·앞뒤 공백 정리)")
	check(MatchTelemetry.vote_line("A(#B2C3)", "x", "", 0, 5).ends_with("| x | - | (순위 - · 5라운드)"), "한줄평이 없으면 -")
	check(MatchTelemetry.vote_line("A", "x", "가".repeat(300), 1, 1).length() < 200, "한줄평은 잘린다")
	check_eq(MatchTelemetry.vote_line("A", "x", "", 2, 9, "놀이터 %s" % BotTemper.tag(5)), "%s A | 놀이터 [Lv.5 핵불닭] | x | - | (2위 · 9라운드)" % MatchTelemetry.vote_tag(), "투표에 놀이터 난이도 태그")
	var detail: String = MatchTelemetry.vote_line("A", "x", "", 1, 3, "", {"stacks": 4, "skills": 1, "cards": 6, "law_pct": 75, "speed": 2})
	check(detail.ends_with("\n[행동 분석] 아군 업기 성사: 4회 | 기물 필살기 사용: 1회 | 생떼 카드 사용: 6장 | 달성/보유 법전 진행도: 최대 75% | 배속 설정: 2x"), "투표에 행동 분석 줄 (%s)" % detail)
	for level: int in BotTemper.ALL:
		check(BotTemper.tag(level).begins_with("[Lv.%d " % level), "난이도 태그 %d" % level)


func test_vote_is_sent_only_when_active() -> void:
	var sent: Array = []
	MatchTelemetry.test_sender = func(_url: String, body: PackedByteArray, _type: String) -> void: sent.append(body.get_string_from_utf8())
	check(not MatchTelemetry.report_vote(null, "x", "", 1, 1), "웹 빌드가 아니면 보내지 않는다")
	MatchTelemetry.test_force_enabled = true
	check(MatchTelemetry.report_vote(null, "x", "한 줄", 1, 1), "켜져 있으면 보낸다")
	check(sent.size() == 1 and (sent[0] as String).contains(MatchTelemetry.vote_tag()), "투표 한 줄")


func test_tally_kills_and_deaths_follow_ejections_and_survive_objection() -> void:
	var state := make_state(2)
	place(state, 21, 3, [2])
	place(state, 11, 5, [4])
	state.send_to_start(state.get_pawn(21), 1)  # P1이 P2 말을 잡았다
	state.send_to_start(state.get_pawn(11), 1)  # 내 지뢰에 내 말이 날아갔다 (데스만)
	check_eq(state.stat(1, GameState.TALLY_KILLS), 1, "P1 킬 1")
	check_eq(state.stat(2, GameState.TALLY_DEATHS), 1, "P2 데스 1")
	check_eq(state.stat(1, GameState.TALLY_DEATHS), 1, "자기 말이 날아가도 데스")
	state.law_stats[1][&"kills"] = 0  # 이의 있음!은 교칙 기록만 지운다
	check_eq(state.stat(1, GameState.TALLY_KILLS), 1, "통계 킬은 남는다")
	state.send_to_start(state.get_pawn(22), 1)
	check_eq(state.stat(1, GameState.TALLY_KILLS), 1, "출발선 대기 말은 잡은 것이 아니다")
