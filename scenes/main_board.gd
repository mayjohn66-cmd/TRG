# File: res://scenes/main_board.gd
# Class: class_name MainBoard
# Role: 로컬 핫시트 플레이 화면. 32칸 사각 보드·4인 말·중앙 법전·손패·증강 드래프트·타일 선택 모드·결과창을 기본 도형으로 그리고, TurnManager의 시그널만 구독하며 act()로만 행동을 보낸다
class_name MainBoard
extends Control

const MATCH_BACKGROUND_SCRIPT: Script = preload("res://scenes/match_background.gd")
const COMMON_SHOCKWAVE: Texture2D = preload("res://assets/fx/common/shockwave_v01.png")
const COMMON_FLECK: Texture2D = preload("res://assets/fx/common/spark_fleck_v01.png")
const PAWN_SILHOUETTE: Shader = preload("res://assets/fx/common/pawn_silhouette.gdshader")

const PLAYER_IDS: Array[int] = [1, 2, 3, 4]
const PLAYER_COLORS: Dictionary = {
	1: Color("e5484d"),
	2: Color("3e8bff"),
	3: Color("30a46c"),
	4: Color("f5b700"),
}
## 보드판(큼직하게): 받침 판 584x584 안에 520x520 타일 영역. 모바일 가로 화면에서도 보드가 화면 높이의 대부분을 차지한다.
const PLATE_POS: Vector2 = Vector2(391, 68)
const PLATE_SIZE: Vector2 = Vector2(584, 584)
const BOARD_ORIGIN: Vector2 = Vector2(423, 75)
const BOARD_SIZE: float = 520.0
## 보드 시점. TOP: 완전 탑뷰, TILT: 테이블에 앉아 비스듬히 내려다보는 기울인 탑뷰(세로 압축 + 위쪽이 멀어 보이는 원근 + 서 있는 말과 그림자).
## 보드는 한 변 BoardSpec.side칸의 정사각 트랙을 45도 돌려 마름모로 세운다 (0번 출발선이 아래 꼭짓점, 반시계로 오른쪽 -> 위 -> 왼쪽 꼭짓점).
const TOOL_CARD_CENTER_Y: float = 384.0  ## 판정 도구 카드의 세로 중심 (우측 중앙)
const DIAMOND_KX: float = 520.0        ## 회전한 평면 좌표 1.0당 가로 픽셀
const DIAMOND_KY: float = 330.0        ## 회전한 평면 좌표 1.0당 세로 픽셀 (눌러서 마름모 비율을 만든다)
enum ViewMode { TOP, TILT }
const TILT_SQUASH: float = 0.90        ## 검토된 시안 v0.9: 과도한 세로 압축 완화
const TILT_FAR_SCALE: float = 0.90
const TILT_TILE_SQUASH: float = 0.90
const TILT_PAWN_LIFT: float = 2.0      ## 토큰 받침대의 접지 보정(px)
const TILT_MARGIN: float = 0.11        ## 보드 받침이 타일 바깥으로 나오는 정도(정규화 좌표)
const TILT_ZOOM: float = 1.05          ## 세로를 눌러 남는 공간만큼 보드를 키운다
const TILE_SIZE: float = 48.0
const PAWN_RADIUS: float = 10.0
const STEP_DELAY: float = 0.22
## 엔진이 한 칸 걸을 때마다 기다리는 시간 (연출 속도 배율을 곱하지 않는다). 장거리면 TurnManager.MOVE_TIME_CAP이 칸당 시간을 더 줄인다.
## 2026-10-26: "타다다닥"이 아니라 "탁 탁 탁"으로 한 칸씩 세며 보이게 0.12 -> 0.28초 (점프 0.2초 + 착지 쉼).
const MOVE_STEP_SECONDS: float = 0.28
## 굴림 결과 칸수 배지가 뜬 뒤 말이 출발하기까지의 틈 (예전 0.3초 x 연출 속도 1.7 + 잠금 0.5초 -> 0.12초, 배지는 이동과 함께 떠 있다).
const ROLL_SUMMARY_LEAD: float = 0.4  ## 2026-10 여운 패치: 0.12 -> 0.25 ("N칸 전진!"을 읽을 틈)
## 리벤지 부스터 배너가 뜬 뒤 말이 날아가기까지의 틈.
const REVENGE_LAUNCH_LEAD: float = 0.15
## 카드·함정·필살기 발동 카드(뒤이어 효과가 이어지는 [문] 알림)의 최대 길이(초, 연출 속도 배율 전).
const GATE_MAX_SECONDS: float = 1.1  ## 2026-10 여운 패치: 0.8 -> 1.1
## 한 칸 점프: 걸리는 시간(초)과 솟구치는 높이(px). 도착 직후 납작하게 찌그러졌다가 탱글하게 돌아온다.
const ONE_CLICK_POWER: float = 0.75  ## 원클릭 굴림의 연출 세기 (파워 게이지를 없앴다)
const NPC_ANNOUNCE_BODY: String = "사료스탕스는 정방향, 와구와구 유령은 역방향으로 가장 가까운 적 말을 덮치고 사라집니다"
const NPC_TIP_ROBBER: String = "소환된 자리에서 기다리다가 라운드가 끝나면 정방향으로 가장 가까운 적 말까지 달려가 그 말 하나를 출발선으로 날려버리고 사라집니다"
const NPC_TIP_GHOST: String = "소환된 자리에서 기다리다가 라운드가 끝나면 역방향으로 가장 가까운 적 말까지 달려가 그 말 하나를 출발선으로 날려버리고 사라집니다"
const HOP_SECONDS: float = 0.20
## 한 칸 점프 뒤 다음 점프까지 착지해 멈춰 있는 틈 (칸 시간의 이 비율, 상한 HOP_REST_MAX초).
const HOP_REST_RATIO: float = 0.3
const HOP_REST_MAX: float = 0.09
const HOP_HEIGHT: float = 20.0
const SLAM_HEIGHT: float = 45.0
const CELL_OFFSETS: Array[Vector2] = [Vector2(-11, -8), Vector2(11, -8), Vector2(-11, 8), Vector2(11, 8)]
const CARD_SIZE: Vector2 = Vector2(80, 110)
const PROFILE_SIZE: Vector2 = Vector2(230, 112)
## 현재 턴이 아닌 프로필은 이 색으로 가라앉고, 현재 턴 프로필은 환하게 밝아진다 (스포트라이트).
const PROFILE_DIM: Color = Color(0.42, 0.42, 0.45, 0.85)
const PROFILE_LIT: Color = Color(1.1, 1.1, 1.1, 1.0)
const PAWN_SLOT_SIZE: float = 38.0
## 좌석 앵커(네 모서리): me=나(우하단, 크게) / right=다음 순서(우상단) / top=맞은편(좌하단) / left=이전 순서(좌상단).
const SEAT_ME: StringName = &"me"
const SEAT_RIGHT: StringName = &"right"
const SEAT_TOP: StringName = &"top"
const SEAT_LEFT: StringName = &"left"
const SEAT_POSITIONS: Dictionary = {
	&"me": Vector2(1000, 598),
	&"right": Vector2(1124, 52),
	&"top": Vector2(12, 644),
	&"left": Vector2(12, 52),
}
## 내 프로필은 다른 사람보다 크다: 큰 아바타 + 기물 4칸 한 줄 + 칸마다 필살기 버튼.
const ME_PROFILE_SIZE: Vector2 = Vector2(340, 164)
const ME_SLOT_SIZE: float = 48.0
const AVATAR_SIZE: Vector2 = Vector2(84, 84)
const ME_AVATAR_SIZE: Vector2 = Vector2(118, 118)
## 카드 독 안에서 카드가 놓이는 기준 y (호버 시 15px 솟아오른다).
const DOCK_CARD_Y: float = 6.0
## 손패 카드는 한 장 전체 일러스트(140x196)가 따로 있고, 화면 아래로 반쯤 가려진 채 부채꼴로 펼쳐진다. 호버하면 전체가 올라와 보인다.
const HAND_CARD_SIZE: Vector2 = Vector2(140, 196)
const HAND_FAN_DEGREES: float = 5.0
## 피해 되돌리기 팝업이 자동으로 넘어가기까지의 시간(초).
const REACTION_SECONDS: float = 6.0
## 행동 사이의 호흡(초): 이동이 끝난 뒤 멈춤 / [P2 차례] 알림 길이.
const DRAFT_OPEN_BEAT: float = 0.45  ## 증강 창이 열리기 전 여운 (0.12 -> 0.3)
const BEAT_AFTER_MOVE: float = 0.3  ## 이동 뒤 여운 (0.8 -> 0.12 -> 0.3 -> 0.5 -> 2026-10-27 플레이 시간 단축 0.3: 도착 결과를 잠깐 보여 준 뒤 다음 턴·증강 창으로)
## 차례 배너는 짧게 막는다: 누구 차례인지 보여 준 뒤에야 카드 선언·굴리기가 열린다 (봇도 배너가 끝난 뒤 움직인다).
const TURN_BANNER_SECONDS: float = 0.85
## 터보 AI 턴: AI 차례의 연출 시간 배율 (보통 속도 대비 50% 단축, 2026-10 여운 패치 전에는 65%). 사람 말을 잡거나 특수 승리·법전이 움직인 턴은 보통 속도로 보여 준다.
const TURBO_PACE_SCALE: float = 0.5  ## 2026-10-26: 0.5(2배속) -> 0.8, 2026-10-27: 평균 플레이 10분 목표로 다시 0.5 (라운드당 -27%, 6.99)
## AI 차례 배너는 더 짧게 (사람 차례 배너는 그대로).
const TURBO_TURN_BANNER_SECONDS: float = 0.45
## 연출 여운: 화면에 무언가를 보여 준 연출 단계(움직임·컷인·배너·여운이 있던 단계)가 끝난 뒤 다음 단계로 넘어가기 전에 결과를 보여 주는 시간(초).
## 기록 줄처럼 그 자리에서 끝나는 단계에는 붙지 않는다. AI 터보 턴에는 절반.
const STEP_LINGER_SECONDS: float = 0.35  ## 2026-10-26: 0.35 -> 0.55, 2026-10-27: 플레이 시간 단축으로 다시 0.35 (연출 단계 사이 인터벌)
## 이보다 오래 걸린 단계를 '보여 준 단계'로 본다 (밀리초).
const STEP_LINGER_MIN_MSEC: int = 60
## 처치 확정 대기의 최대 시간(초): 방어 결정이 이보다 오래 걸리면(연결 끊김 등) 연출을 계속한다.
const COUNTER_GATE_LIMIT: float = 30.0
## 상대를 해치는 공격 카드: 카드를 공개하기 전에 [공격 카드 발동!] 경보를 먼저 띄운다.
const ATTACK_CARDS: Array[StringName] = [&"ACT_02", &"ACT_03", &"ACT_06", &"ACT_07", &"ACT_08", &"ACT_09", &"ACT_10", &"ACT_14", &"ACT_15"]
const ATTACK_TAG: String = "공격"
const HAND_RAISED_Y: float = -92.0
## 우측 하단 기물 독에서 기물 슬롯이 놓이는 기준 y (필살기 버튼 줄 아래).
const SLOT_BASE_Y: float = 50.0
const AUGMENT_CARD_SIZE: Vector2 = Vector2(260, 390)
## 도감용 낮은 증강 카드 높이 (390의 72%: 아래 빈 공간 없이 그림·제목·조건만).
const AUGMENT_COMPACT_HEIGHT: float = 280.0
const AUGMENT_HOVER_SCALE: float = 1.06
## 증강 카드를 고른 뒤 다음 단계로 넘어가기 전에 선택 연출을 보여 주는 시간(초).
const AUGMENT_PICK_SECONDS: float = 0.9
const SELECT_CARD_SIZE: Vector2 = Vector2(135, 165)
const SELECT_BANNER_POS: Vector2 = Vector2(380, 568)
const SLOT_SIZE: Vector2 = Vector2(76, 88)
## 슬링샷 조준: 이 거리(px)만큼 당기면 파워 100%.
## 호버 툴팁이 뜨기까지 커서를 가만히 대고 있어야 하는 시간(초).
const TIP_DELAY: float = 0.35
const COLOR_BG: Color = Color("0d1018")
const COLOR_PANEL: Color = Color("1a2030")
const COLOR_PANEL_EDGE: Color = Color("39435c")
const COLOR_GOLD: Color = Color("ffd43b")
## 카드 배경색은 카드의 속성(카테고리)을 알려 준다: 즉발 주황 / 함정 보라 / 소환 청록.
const CARD_BG_COLORS: Dictionary = CardSkin.FILLS
const CARD_CATEGORY_NAMES: Dictionary = {
	GameEnums.CardCategory.INSTANT: "즉발",
	GameEnums.CardCategory.TRAP: "함정",
	GameEnums.CardCategory.SUMMON: "소환",
	GameEnums.CardCategory.COUNTER: "방어",
}
## 작은 손패 카드에 보여 주는 1줄 핵심 요약 (15자 이내). 자세한 규칙은 클릭해서 확대할 때 CARD_SUMMARIES로 본다.
const CARD_SHORT: Dictionary = {
	&"CNT_01": "되감고 턴 종료",
	&"CNT_02": "공격한 말 사출",
	&"CNT_03": "공격 카드 반사",
	&"CNT_04": "공격 1회 회피",
	&"CNT_05": "함정 파괴 +3칸",
	&"CNT_06": "함정 무효+강탈",
	&"CNT_07": "함정 카드 획득",
	&"ACT_02": "상대 선두 사출",
	&"ACT_03": "폭탄 패스 & +4칸",
	&"ACT_04": "이번 굴림 +4",
	&"ACT_06": "승리 기록 초기화",
	&"ACT_07": "한 변 설치물 붕괴",
	&"ACT_08": "꼴찌 ↔ 선두 교환",
	&"ACT_09": "승자 +3칸·패자 사출",
	&"ACT_10": "앞 3칸 적 사출",
	&"ACT_11": "굴림 결과 지정",
	&"ACT_12": "한 턴 더",
	&"ACT_13": "반환점까지 순간이동",
	&"ACT_14": "2턴 카드·스킬 금지",
	&"ACT_15": "상대 턴 건너뛰기",
	&"TRP_02": "눈금 4+ 적 사출",
	&"TRP_03": "반경 2칸 폭파",
	&"TRP_05": "반경 함정 연쇄",
	&"TRP_06": "미끄러짐+카드 강탈",
	&"TRP_07": "지나가면 정지",
	&"TRP_08": "꼴찌와 자리 교환",
	&"TRP_C01": "코너 감옥화",
	&"TRP_C02": "내 편 점프·적 사출",
	&"TRP_C03": "카드 상납 or 정지",
	&"TRP_C04": "주변 적 끌어오기",
	&"SUM_01": "정방향 질주 사출",
	&"SUM_02": "역방향 질주 사출",
}
## 카드 확대 보기에서 읽는 개조식 요약 (키워드 + 명사형 종결). cards_table.csv의 desc가 있으면 그것이 우선이다.
const CARD_SUMMARIES: Dictionary = {
	&"CNT_01": "[방어] 공격당하면 이번 턴을 통째로 되감고 공격자의 턴 종료",
	&"CNT_02": "[방어] 잡기를 막고 공격한 말을 출발선으로 사출",
	&"CNT_03": "[방어] 공격 카드를 막고 반사: 밴·스킵·이의 있음은 공격자에게 그대로 · 그 밖의 카드는 공격자 선두 말 사출",
	&"CNT_04": "[방어] 잡기·공격 카드 1회 회피",
	&"CNT_05": "[방어] 걸린 함정을 부수고 +3칸 전진",
	&"CNT_06": "[방어] 걸린 함정 무효 + 설치자 카드 1장 강탈",
	&"CNT_07": "[방어] 걸린 함정을 발동하지 않고 그 함정 카드를 내 패로",
	&"ACT_02": "상대 선두 말을 출발선으로 장외 사출",
	&"ACT_03": "다음 유저에게 폭탄 패스: 선두 말 사출 + 내 이동 +4칸",
	&"ACT_04": "굴리기 전 사용! 이번 굴림 +4칸",
	&"ACT_06": "특수 승리 기록 1개를 0으로 초기화",
	&"ACT_07": "고른 한 변의 설치물 전부 붕괴",
	&"ACT_08": "내 꼴찌 말 ↔ 1등 적 선두 말 위치 교환",
	&"ACT_09": "적 1명과 6종 랜덤 미니게임 데스매치! 승자 말 +3칸, 패자 선두 말 사출",
	&"ACT_10": "내 선두 말 앞 3칸의 적 사출 + 설치물 파괴",
	&"ACT_11": "다음 굴림 결과를 1~6칸 중 직접 지정",
	&"ACT_12": "이번 턴이 끝나면 한 턴 더",
	&"ACT_13": "내 선두 말을 반환점까지의 빈 칸 중 고른 칸으로 순간이동",
	&"ACT_14": "상대 1명 2턴 동안 카드·필살기·주사위 리롤 금지",
	&"ACT_15": "상대 1명의 다음 턴 건너뛰기",
	&"TRP_02": "눈금 4+ 로 지나가는 적 말 출발선 사출",
	&"TRP_03": "밟으면 반경 2칸 내 모든 말 폭파",
	&"TRP_05": "밟은 말은 멈추고, 반경 2칸 안의 함정이 전부 연쇄 발동",
	&"TRP_06": "밟은 적 말 +3칸 미끄러짐 + 카드 1장 강탈",
	&"TRP_07": "지나가던 적 말 그 칸에 강제 정지",
	&"TRP_08": "밟은 적 말 ↔ 보드 꼴찌 말 위치 교환",
	&"TRP_C01": "[코너] 멈춘 적 말 감금",
	&"TRP_C02": "[코너] 내 말 +5칸 점프 / 적 말 출발선 사출",
	&"TRP_C03": "[코너] 지나가는 적은 카드 1장 상납, 없으면 강제 정지",
	&"TRP_C04": "[코너] 밟은 적 정지 + 코너 2칸 안의 적 말 끌어오기",
	&"SUM_01": "[상단 코너] 소환 · 라운드가 끝나면 정방향으로 가장 가까운 적 말 하나를 처치하고 사라짐",
	&"SUM_02": "[상단 코너] 소환 · 라운드가 끝나면 역방향으로 가장 가까운 적 말 하나를 처치하고 사라짐",
}


## 카드 확대 요약: cards_table.csv의 desc({p1}·{p2}는 param 값으로 바뀜), 비어 있으면 위 CARD_SUMMARIES 기본 문구.
static func card_summary(card_id: StringName) -> String:
	var text: String = GameData.text("cards", card_id, "desc", str(CARD_SUMMARIES.get(card_id, "")))
	return text.replace("{p1}", str(GameData.param("cards", card_id, 1, 0))).replace("{p2}", str(GameData.param("cards", card_id, 2, 0)))


## 비어 있는 법전 슬롯에 그리는 어두운 점선 테두리.
class DashedBorder extends Control:
	var line_color: Color = Color("4a5368")

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var area := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var corners: Array[Vector2] = [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
		for index: int in 4:
			draw_dashed_line(corners[index], corners[(index + 1) % 4], line_color, 2.0, 6.0)


## 페이즈 이름의 화면 문구 키 (content_trickcal/data/ui_strings.csv, tr_ui로 꺼낸다).
const PHASE_KEYS: Dictionary = {
	TurnManager.State.PHASE_ROUND_START: "phase.round_start",
	TurnManager.State.PHASE_TURN_BEGIN: "phase.turn_begin",
	TurnManager.State.PHASE_ROLL_WAIT: "phase.roll_wait",
	TurnManager.State.PHASE_INTERRUPT_ROLL: "phase.interrupt",
	TurnManager.State.PHASE_SELECT_PAWN: "phase.select_pawn",
	TurnManager.State.PHASE_MOVING_STEP: "phase.moving",
	TurnManager.State.PHASE_RESOLUTION: "phase.resolution",
	TurnManager.State.PHASE_NEUTRAL_NPC: "phase.npc",
}
const YUT_NAMES: Dictionary = {0: "낙", 1: "도", 2: "개", 3: "걸", 4: "윷", 5: "모"}
const HAND_NAMES: Dictionary = {
	&"high_card": "노페어", &"one_pair": "원페어", &"two_pair": "투페어", &"three_kind": "트리플",
	&"straight": "스트레이트", &"flush": "플러시", &"full_house": "풀하우스", &"four_kind": "포카드",
	&"straight_flush": "스트레이트 플러시",
}
const SLOT_SYMBOLS: Array[String] = ["체리", "레몬", "종", "BAR", "다이아", "7"]
const REJECT_REASONS: Dictionary = {
	&"wrong_phase": "지금은 할 수 없는 행동입니다",
	&"not_playable_now": "지금 단계에서는 쓸 수 없는 카드입니다",
	&"not_your_turn": "내 턴이 아닙니다",
	&"card_not_in_hand": "손패에 없는 카드입니다",
	&"invalid_target": "대상이 올바르지 않거나 조건을 만족하지 않습니다",
	&"invalid_pawn": "선택할 수 없는 말입니다",
	&"invalid_index": "올바르지 않은 선택입니다",
	&"nothing_to_cash_out": "확정할 누적치가 없습니다",
	&"game_over": "게임이 끝났습니다",
	&"ambiguous_pair": "교환할 체스 기물 두 개를 골라야 합니다",
	&"reroll_used": "이미 리롤한 카드입니다",
	&"card_limit": "카드는 굴리기 전에 턴당 1장만 쓸 수 있습니다",
	&"no_candidate": "바꿀 수 있는 다른 증강이 없습니다",
}
## 법전(교칙 제정)은 가장 드문 증강이라 크리스탈 청록 + 무지개빛 후광(HOLO), 초증강은 보라 네온 + 황금 테두리(PRISMA)로 구분한다.
## 13px 이하 작은 글자에 쓰는 또렷한 고딕 (ONE Mobile POP은 작게 쓰면 획이 뭉개져 흐릿하고 찌그러져 보인다).
const SMALL_FONT: Font = preload("res://assets/fonts/game_small_font.tres")
const SMALL_TEXT_MAX: int = 13
const PAWN_SKILL_COLOR: Color = Color("ffc078")
const LAW_COLOR: Color = Color("66e3f5")
const SUPER_COLOR: Color = Color("cc5de8")
const HOLO_GLOW: Array[Color] = [Color(0.4, 0.89, 0.96, 0.9), Color(0.93, 0.45, 0.95, 0.9), Color(1.0, 0.85, 0.35, 0.9)]

## 이 화면을 보는 플레이어. 이 플레이어의 프로필·기물 독이 우측 하단에 놓인다 (멀티플레이에서 P2~P4로 접속해도 본인이 우측 하단).
var local_player_id: int = 1
## 이 판에 참여하는 좌석 (컴퓨터 대전/핫시트는 4명 전부, 온라인 대전은 로비에서 정한 2~4명).
var _player_ids: Array[int] = PLAYER_IDS.duplicate()
## 플레이어 -> 앉은 자리 앵커 (SEAT_*). 참가 인원과 내 자리로 정해진다.
var _seat_anchor: Dictionary = {}
## 온라인 대전(락스텝) 동기화. 온라인이 아니면 null.
var net: NetGame = null
## 이번 AI 턴에 사람 말 처치·특수 승리·법전 변화가 있었다: 이 턴의 연출은 보통 속도로 (주목 구간).
var _spotlight_turn: bool = false
## 행동 처리 묶음 안에서 화면 갱신 요청이 있었다 / 묶음 깊이 (_refresh_all 묶음).
var _refresh_queued: bool = false
var _refresh_batch: int = 0
## 화면 전체 갱신을 실제로 그린 횟수 (테스트용).
var refresh_count: int = 0
var _game_seed: int = 0
var _net_lost_overlay: Control = null
var _net_status_label: Label = null
var _silent_seats: Dictionary = {}
var manager: TurnManager = null
var state: GameState = null

var _board_layer: Control = null
var _pawn_layer: Node2D = null
var _tile_views: Dictionary = {}
var _highlights: Dictionary = {}
var _pick_marks: Dictionary = {}
var _tile_marks: Dictionary = {}
## 함정 카드를 보여 주는 동안은 발판을 보라색으로 칠하지 않는다 (카드 알림이 끝난 뒤에 나타난다).
var _trap_pending: Dictionary = {}
var _trap_tiles: Array[int] = []
var _trap_clock: float = 0.0
## 중립 NPC 습격 예고: 타일 번호 -> {"level": 1(NPC가 지나는 길)/2(말이 서 있으면 잡히는 위험 타일), "dir": 화면 방향}.
var _npc_danger: Dictionary = {}
var _danger_clock: float = 0.0
var _danger_label: Label = null
var _hover_danger_tile: int = -1
var _pawn_views: Dictionary = {}
var _npc_views: Dictionary = {}
var _flash_law_ids: Dictionary = {}

var _toast_label: Label = null
var _phase_label: Label = null
var _queue_label: Label = null
var _pick_banner: Label = null
var _pick_cancel: Button = null
var _tag_labels: Dictionary = {}
var _board_hover_pawn: int = -1
var _profiles: Dictionary = {}
var _law_slots: Array[PanelContainer] = []
var _law_labels: Array[Label] = []
var _law_descs: Array[Label] = []
var _law_badges: Array[PanelContainer] = []
var _law_badge_labels: Array[Label] = []
var _law_dashes: Array[Control] = []
## 법전 슬롯 오른쪽 위 [달성 임박!] 배지와 그 깜빡임 (누군가 1칸/1회 남았을 때).
var _law_near: Array[Label] = []
var _law_near_tweens: Array[Tween] = []
## 법전 슬롯 오른쪽의 내 달성도 배지 [ 4 / 6 킬 ] (실시간).
var _law_progress: Array[Label] = []
## 슬롯 배지 상태: 0 없음 / 1 누군가 달성 임박 / 2 내가 조건 충족 (이번 턴이 끝나면 졸업)
var _law_badge_state: Array[int] = []
## 법전 진행도 배지의 단위 (VictoryLaw 단위와 다르게 보여 줄 것만).
const LAW_PROGRESS_UNITS: Dictionary = {"LAW_01": "킬", "LAW_08": "킬", "LAW_05": "구역"}
## 특수 승리 달성 하이라이트(법전 카드가 가운데로 날아와 도장이 찍힘)가 화면을 붙잡는 시간(초). 그 뒤에 순위 배너가 뜬다.
const LAW_ACHIEVED_SECONDS: float = 1.6
## 승리 장면 소리 간격: 순위 확정 배너(졸업 팡파르)를 보여 주는 시간과 그 뒤 쉼, 결과 창 시상대 팡파르 뒤 첫 순위 공개까지의 뜸.
const RANK_BANNER_SECONDS: float = 2.0
const RANK_BEAT_SECONDS: float = 1.8
const PODIUM_INTRO_SECONDS: float = 1.2
const RANK_ROW_SECONDS: float = 0.8
const FIRST_PLACE_DRUMROLL_SECONDS: float = 1.4
var _roll_button: Button = null
var _stop_button: Button = null
var _gun_row: HBoxContainer = null  ## 러시안 룰렛 전용 [발사][정지] 두 버튼 줄
var _fire_button: Button = null
var _skip_button: Button = null
var _new_game_button: Button = null
var _hint_label: Label = null
var _pawn_bar: Panel = null
var _pawn_buttons: Array[Button] = []
var _pawn_slot_parts: Array[Dictionary] = []
## 필살기 버튼: 내 프로필(큰 카드)의 칸 아래 버튼들. 수동 4인 모드에서는 기물 독의 버튼(_dock_skill_buttons)이 대신한다.
var _skill_buttons: Array[Button] = []
var _dock_skill_buttons: Array[Button] = []
var _tile_pick_skill_pawn: int = -1
var _aim_pawn: int = -1
var _aim_angle: float = 0.0
var _aim_power: float = 0.0
var _alkkagi: AlkkagiStage = null
var _train_stage: RunawayTrainStage
var _train_controlled: Dictionary = {}
var _train_trap_hold: Dictionary = {}
var _train_camera_weight := 0.0
var _alkkagi_camera := 0.0
var _alkkagi_camera_tween: Tween
var _alkkagi_saved_view := -1
var _alkkagi_controlled: Dictionary = {}
var _alkkagi_skip_primary_warp := false
var _alkkagi_actor_offset := Vector2.ZERO
var _tool_board: PanelContainer = null
var _tool_title: Label = null
var _tool_icon: PanelContainer = null
var _tool_icon_label: Label = null
var _tool_icon_art: TextureRect = null
var _tool_main: Label = null
var _tool_sub: Label = null
var _tool_rules: VBoxContainer = null
var _tool_note: Label = null
var _tool_toggle: Button = null
## 판정 도구 카드의 상세 족보를 펼쳤는가 (처음에는 한두 줄 요약만 보인다).
var _tool_expanded: bool = false
var _tool_rules_key: String = ""
var _tool_board_key: String = ""
var _status_strip: HBoxContainer = null
var _tip_panel: PanelContainer = null
var _tip_title: Label = null
var _tip_ability: Label = null
var _tip_skill: Label = null
var _tip_rule: ColorRect = null
var _tip_source: Variant = null
var _tip_provider: Callable = Callable()
var _tip_clock: float = 0.0
## 기물 설명은 클릭으로 연다(고정): 같은 기물을 다시 누르거나 다른 곳을 누르면 닫힌다. 고정된 설명은 커서를 따라가지 않는다.
var _tip_pinned: bool = false
var _tip_anchor: Vector2 = Vector2.ZERO
var _zoom_view: PanelContainer = null
var _hold_card: PanelContainer = null  ## 포인터가 영역 안에 있어 올라온 채 유지 중인 손패 카드
var _zoom_key: String = ""
var _drag_press: Dictionary = {}
var _drag_active: bool = false
var _drag_ghost: PanelContainer = null
var _drop_zone: PanelContainer = null
var _drop_label: Label = null
var _dock: Control = null
var _dock_player: int = -1
var _debug_toggle: Button = null
## 이 판의 [매치 완료]를 이미 보냈다 (판마다 한 번).
var _match_complete_sent: bool = false
## 통계: 이 판이 이 사람의 몇 번째 판인지, 언제 시작했는지, 내가 고른 증강 이름들.
var _match_number: int = 0
var _match_started_msec: int = 0
var _my_augments: Array[String] = []
var _pressure_serial: int = -1
var _pressure_second: int = -1
var _pressure_left: float = 0.0
var _emote_row: HBoxContainer = null
var _emote_ready_msec: int = 0
## 치트/디버그 메뉴 노출 여부: 평소에는 숨긴다. 게임 메뉴를 연 채로 비밀 입력(CHEAT_SEQUENCE)을 끝까지 쳐야 켜지고 꺼진다.
## (개발용 실행 인자 --debug로도 켤 수 있다. 웹 주소로는 켤 수 없다.)
var _debug_enabled: bool = false
## 메뉴를 연 채로 친 키 (비밀 입력 판정용)와 마지막 키 시각.
var _cheat_keys: Array[int] = []
var _cheat_key_msec: int = 0
var _log_toggle: Button = null
var _debug_box: PanelContainer = null
var _log_panel: PanelContainer = null
var _tool_option: OptionButton = null
var _card_option: OptionButton = null
var _timer_check: CheckBox = null
var _log: RichTextLabel = null
var _center_banner: PanelContainer = null
var _center_label: Label = null
## 연출 대기 시간(await)을 0초로 건너뛰는 플래그 (헤드리스·ui_smoke 자동 진행용).
var instant_roll_for_test: bool = false:
	set(value):
		instant_roll_for_test = value
		if manager != null:
			manager.review_enabled = not value  # 연출을 켠 판에서만 증강 확인 단계를 둔다 (모든 참가자가 같은 값이어야 한다)
var _presenter: RollPresenter = null
## 카드 획득 연출: 보드 한가운데 덱에서 카드가 뽑혀 손패·프로필로 날아간다.
var _draw_fx: CardDrawFX = null
## 초증강 전용 보드 연출.
var _super_fx: SuperFX = null
## 드래프트에서 지금 처리 중인 증강 선택의 번호: 그 선택이 만든 연출 단계에 붙여, 초증강 연출을 그 단계들 바로 앞에 끼운다.
var _pick_serial: int = 0
## 이번 증강 선택 동안 엔진이 낸 변화 (초증강 연출이 무엇을 보여 줄지 정한다).
var _super_changes: Array[Dictionary] = []
## 카드를 빼앗긴 사람: 바로 뒤에 오는 카드 획득은 그 사람 프로필에서 날아온다.
var _steal_from: int = -1
## 도박사의 영혼: 이번 굴림이 배수가 됐거나(배수) 과열됐다(-1) - 굴림 결과가 나올 때 주사위 위에 보여 준다.
var _gambler_flash: Dictionary = {}
var _announcer: EventAnnouncer = null
var _pending_power: float = 0.5
var _fx_busy: bool = false
var _capture_cutin: CaptureCutin = null
var _capture_marks: Dictionary = {}
## 처치 확정 대기: 잡기·공격으로 말이 날아가기 전에, 맞은 사람이 방어 카드를 낼지 정할 때까지 처치 연출을 멈춰 둔다 (연출 큐의 한 단계가 기다리는 중).
var _counter_gate_waiting: bool = false
## 방어 카드로 막아 낸 말: 처치 연출 대신 방어 이펙트를 한 번 보여 준다 (pawn_id -> true).
var _defended_shown: Dictionary = {}
var _capture_epoch: int = 0
## 말 움직임 연출(PawnFx): 이 시각(msec)까지는 입력·봇을 잠가 움직임이 끝나기를 기다린다.
var _fx_until_msec: int = 0
## 말 id -> 다음 이동 연출에 쓸 힌트 {delay, arc, peak, spin, dur, drop, t(만든 시각)}. 이벤트가 어떻게 움직일지 미리 알려 준다.
var _fx_hints: Dictionary = {}
## [문]으로 등록된 알림 번호들과, 문이 열렸는지(카드가 끝나 말이 움직일 수 있는지).
var _fx_gates: Array[int] = []
var _fx_gate_open: bool = false
var _motion_retry: bool = false
var _shown_turn: int = -1
## 게임 시작 오프닝: 진행 중이면 증강 선택 창·봇·입력을 잠근다 (테스트용 즉시 모드에서는 켜져 있지 않은 것으로 본다).
var _intro_pending: bool = false
var _opening: OpeningSequence = null
## 오프닝 직후 첫 증강 창은 아래에서 위로 솟아오르며 나타난다.
var _draft_entrance: bool = false
var _draft_banner_round: int = 0
## 이번 드래프트에서 고른 증강 모음 (끝나면 한 장으로 공개).
var _draft_summary: Array[Dictionary] = []
## 드래프트 중에 생긴 효과 연출: 증강 공개 카드 뒤로 미뤄 둔다 ({"step", "pawn"}).
## 지금 재생 중인 연출 단계의 함수 이름 (템포 계측기 tests/turn_tempo_probe.gd가 어디서 시간이 드는지 나눠 본다).
var presentation_label: String = ""
var _draft_deferred: Array[Dictionary] = []
## 여러 단계를 한꺼번에 세우는 중 (_enqueue_batch): 다 세울 때까지 재생을 시작하지 않는다.
var _enqueue_batching: bool = false
## 마지막으로 누른 증강 리롤 버튼 번호 (거절되면 그 버튼에 이유를 적는다).
var _last_reroll_index: int = -1
var _last_reroll_player: int = -1
## 지난 프레임에 굴리기 화면을 띄울 수 있었는가 (바뀌는 순간에만 화면을 다시 맞춘다).
var _last_roll_view: bool = false
## 드래프트 창이 열렸다 (augment_offers 이후). 이때부터 생긴 연출만 [선택한 증강] 공개 뒤로 미룬다.
var _draft_open: bool = false
## 게임 필: 화면 흔들림, 말 id -> 이동 연출을 필살기 스크립트가 맡는 중(걸음 무시), 차 돌진 중 잡힌 말이 나는 시점을 늦추는 값(초).
var _shake_tween: Tween = null
var _shake_origin: Vector2 = Vector2.ZERO
var _shake_active: bool = false
var _fx_skip_steps: Dictionary = {}
var _nitro_skips: Dictionary = {}
var _nitro_victims: Dictionary = {}
var _fx_hint_bonus: float = 0.0
var _fx_generation: int = 0
## 단일 연출 큐(FIFO): 말 걸음·발판 팝업·처치 컷인·배너·워프·출발선 사출이 이 줄에서 한 번에 하나씩만 재생된다.
## 엔진은 한 번에 결과를 계산하고 시그널을 연달아 쏘지만, 화면은 앞 연출이 완전히 끝난 뒤에야 다음 연출을 시작한다.
var _presentation_queue: Array[Callable] = []
## 연출 큐의 단계마다 카드 획득 비행(_launch_drawn_card)인가 (큐와 같은 순서).
var _presentation_draws: Array[bool] = []
## 바로 앞 단계가 다음 카드 비행과 이어지는 카드 비행이었다 (다음 카드는 기다리지 않고 띄운다).
var _chained_draw: bool = false
## 연출 큐의 단계마다 말 이동 단계(한 칸 점프·리벤지 로켓)인가 (큐와 같은 순서).
var _presentation_moves: Array[bool] = []
## 말 이동 단계: 이어지는 걸음 사이에는 여운·정리 대기를 두지 않는다 (걸음마다 0.35초 여운이 붙어 13칸 이동이 3초 넘게 걸렸다).
const MOVE_STEP_LABELS: Array[String] = ["_play_hop", "_play_rocket", "_play_callout"]
## 여운을 붙이지 않는 단계: 걸음과 리벤지 부스터 출발 배너 (이동은 끊기지 않고 이어져야 한다).
const NO_LINGER_LABELS: Array[String] = ["_play_hop", "_play_rocket", "_play_revenge_launch", "_play_callout"]
## 지금 이어 뛰는 걸음 줄의 길이 (줄의 첫 걸음에서 센다). TurnManager.LONG_MOVE_TILES 이상이면 한 칸 점프를 LONG_MOVE_STEP_SECONDS로 줄인다.
var _move_chain_len: int = 0
var _move_chained: bool = false
## Own preview controls while their announcement is waiting in the presentation queue.
var _announcement_extras: Node = null
var _is_playing_presentation: bool = false
## 큐에 아직 남은 말별 연출 수 (이 말은 큐가 끝나기 전에 최종 위치로 순간 이동하지 않는다).
var _pawn_pending: Dictionary = {}
## 한 행동 안에서 엔진이 동시에 방송한 처치 연출(컷신·장외 사출): 그 행동의 이동 연출이 모두 끝난 뒤(큐 맨 뒤)에 재생한다.
var _late_steps: Array[Dictionary] = []
## 리벤지 부스터 로켓 출격 중인 말 -> 로켓이 내려앉을 타일 (그 칸까지의 걸음은 한 칸씩 뛰지 않고 한 번에 날아간다)
var _rocket_target: Dictionary = {}
## 리벤지 부스터 로켓 뒤에 이어 갈 눈금 칸수 (경유지에서 [눈금 N칸]을 띄운다).
var _rocket_followup: Dictionary = {}
## 플레이어 -> 이번 굴림 칸수를 늘린 이유들 (가속 보너스·템포 업·도박사) / 말 -> 리벤지 부스터 뒤 눈금 이동에 붙일 기물 능력 이유.
var _roll_reasons: Dictionary = {}
var _move_bonus_notes: Dictionary = {}
## 도착 칸 정산 뒤 추가 이동 중인 말 (점프 부스트·부스터 발판·8번 공 돌진): 이 말의 걸음은 앞선 처치 연출 뒤에 선다. 이동이 끝나면(move_resolved) 지운다.
var _follow_up_pawns: Dictionary = {}
## 한 번에 터지는 파편 수 상한 (웹·모바일에서 한 화면에 파티클이 몰리지 않게).
const MAX_BURST_PARTICLES: int = 24
## 일회성 연출 노드 묶음 이름과, 수명에 더하는 여유(초): 이 여유가 지나도 남아 있으면 끊긴 연출로 보고 치운다.
const ONESHOT_FX_GROUP: StringName = &"trg_oneshot_fx"
## 1위·법전 졸업을 영구 기록(PlayerSave)에 남기는가 (실제 플레이만: 검사 장면은 끈다).
var record_meta_progress: bool = not OS.has_feature("editor")
## 자주 생겼다 사라지는 연출 노드(플로팅 글자·파편·충격 링)를 지우지 않고 다시 쓴다.
var _fx_pool: FxPool = FxPool.new()
var _common_ring_region := Rect2()
const ONESHOT_GRACE_SECONDS: float = 2.0
## 이동 단계 사이(부스터 도착·점프 부스트 직전)의 짧은 멈춤(초). 연출 속도 배율을 곱하지 않는 고정값.
const WAYPOINT_PAUSE: float = 0.15
## 굴림 직후 확정 칸수 표시용: 플레이어 -> 가속 보너스까지 합친 최종 칸수
var _roll_total: Dictionary = {}
## 점프 코너·옷장 포탈의 2단계 이동(발판에 멈춤 -> 발동 연출 -> 비행/워프)이 진행 중인 수. 0보다 크면 다른 말의 연출과 알림은 끝날 때까지 기다린다.
var _stage_warps: int = 0
## 증강 선택 창은 이동·처치·함정 연출이 모두 끝나고 0.12초 여운이 지난 뒤에 연다.
var _draft_wait_motion: bool = false
## 굴림 연출마다 늘어나는 번호: 새 연출이 앞선 연출을 덮어쓰면(취소) 앞선 연출의 뒷정리가 입력 잠금을 풀지 않게 한다.
var _fx_serial: int = 0
var _stack_overlay: Control = null
## 사람이 조작하는 플레이어 번호 (AI 대전 모드에서 P2~P4는 봇이 맡는다).
const HUMAN_ID: int = 1  ## local_player_id의 기본값 (테스트 참조용)
## true면 [1P vs 3AI 봇] 모드: P2~P4를 BotController가 조작하고 P1의 손패만 앞면으로 보인다. false면 4인 수동 조작.
var ai_mode: bool = true
var _bot: BotController = null
var _mode_toggle: Button = null
var _stage_yacht: YachtStage = null  ## 새 판정 도구 3종의 중앙 오픈 스테이지 (해당 도구를 쓰는 차례에만 보인다)
var _stage_blackjack: BlackjackStage = null
var _stage_pinball: PinballStage = null
var _stage_turn_key: String = ""
var _menu_button: Button = null
var _feedback_button: Button = null  ## 왼쪽 위 피드백 / 버그 제보 (소리·언어는 설정 화면에 있다)
var _speed_button: Button = null  ## 오른쪽 위 [배속 1x] 진행 속도 (1x -> 2x -> 3x)
var _language_button: LanguageToggle = null  ## [배속] 왼쪽의 [🌐 한국어 ▾] 언어 버튼 (한국어 / ENGLISH / 日本語 중 고르면 화면 글자가 바로 바뀐다)
## 이 판을 시작한 시각 (피드백 스냅샷의 플레이 타임).
var _game_started_msec: int = 0
## 액션 로그에 마지막으로 적은 라운드 구분선 (_log_round_divider).
var _divider_round: int = 0
var _step_chain: int = 0
var _step_sound_msec: int = -10000
## 메뉴 오버레이(계속하기/게임 설정/전체 로그/새 게임/치트/게임 나가기). 열려 있지 않으면 null.
var _menu_overlay: Control = null
var _menu_box: VBoxContainer = null
var _menu_page: StringName = &"main"
## 창 비율 대응: 디자인 기준 1366x768 화면의 왼쪽 묶음 / 가운데 묶음(보드) / 오른쪽 묶음을 창이 넓거나 높을 때 각자 밀어 배치한다.
const DESIGN_SIZE: Vector2 = Vector2(1366, 768)
## 화면 가장자리에서 띄우는 안전 여백(px). 모서리가 둥근 폰·베젤에서 UI가 잘려 보이지 않게 한다.
const SAFE_MARGIN: float = 12.0
## 액션 로그 미니 패널의 왼쪽 위 (법전 아래, 왼쪽 아래 프로필 위의 빈 자리).
const ACTION_LOG_POS: Vector2 = Vector2(12.0, 466.0)
## 액션 로그의 자리 표시 (P1~P4 색 네모).
const PLAYER_MARKS: Dictionary = {1: "■", 2: "■", 3: "■", 4: "■"}
## 메뉴의 [전체 로그] 서랍(디버그용 상세 로그)이 보관하는 최대 줄 수.
const DEBUG_LOG_LINES: int = 200
var _layout_entries: Array[Dictionary] = []
var _off_left: Vector2 = Vector2.ZERO
var _off_center: Vector2 = Vector2.ZERO
var _off_right: Vector2 = Vector2.ZERO
var _law_panel: PanelContainer = null
var _plate: Panel = null
var view_mode: int = ViewMode.TOP
var _board_surface: MeshInstance2D = null
var _flat_board_surface: MeshInstance2D = null
var _board_edge: Line2D = null
var _board_shadow: Polygon2D = null
var _match_background: TextureRect = null
var _track_lines: Array[Line2D] = []
var _action_row: HFlowContainer = null
var _roll_pad: RollPad = null
var _roll_geometry: StringName = &""

var _choice_overlay: Control = null
var _draft_overlay: Control = null
var _draft_player: int = -1
var _reaction_popup: PanelContainer = null
var _reaction_bar: ProgressBar = null
var _reaction_use_button: Button = null
var _reaction_pass_button: Button = null
var _reaction_key: String = ""
var _reaction_left: float = 0.0
var _select_banner: Panel = null
var _dir_left: Node2D = null
var _dir_right: Node2D = null
var _announced_round: int = 0
var _announced_turn_key: String = ""
## false면 [N 차례] 알림과 이동 뒤 멈춤을 쓰지 않는다 (연출 타이밍을 따로 검사하는 테스트용).
var pacing_enabled: bool = true
var _beat_until_msec: int = 0
var _select_title: Label = null
var _select_cards: Array[Button] = []
var _select_parts: Array[Dictionary] = []
var _select_hover_slot: int = -1
var _flash_pawn: int = -1
var _flash_tween: Tween = null
var _draft_signature_value: String = ""
var _draft_locked: bool = false
var _pawn_choice_cards: Array = []
var _draft_title_label: Label = null
var _draft_cards: Array[Button] = []
var _draft_reroll_buttons: Array[Button] = []
var _result_overlay: Control = null
## 판이 끝난 뒤 남은 정리 연출(졸업·말 철수·순위 확정·[매치 종료] 브리핑)이 끝날 때까지 결과 창을 미룬다.
var _result_hold: bool = false
var _auto_draft_enabled: bool = false

var _tile_pick_active: bool = false
## 뱅! 저격: 타일 대신 상대 프로필을 눌러 고르는 모드 (_tile_pick_active와 함께 켜진다). 프로필마다 표식이 붙는다.
var _snipe_pick: bool = false
## ACT_09 결투: 중앙 스테이지 결투장, 승자가 고를 수 있는 말(보드 위 붉은 표식), 카드를 놓은 대상 플레이어.
var _duel_arena: DuelArena = null
## 액션 로그 (누가 무엇을 했는지 최근 100줄, 미니/펼침).
var _action_log: ActionLogPanel = null
var _duel_drop_target: int = -1
var _snipe_marks: Dictionary = {}
var _tile_pick_player: int = -1
var _tile_pick_card: StringName = &""


func _ready() -> void:
	L10n.install()
	L10n.on_changed(_on_language_changed)
	Sfx.bgm_stop()
	Sfx.apply_settings()
	Sfx.unlock()
	Sfx.bgm_play.call_deferred(Sfx.BATTLE_TRACK)
	pacing_enabled = GameSession.pacing_enabled
	view_mode = GameSession.view_mode
	if GameSession.net_active:
		local_player_id = GameSession.net_local_seat
		ai_mode = true  # 화면 규칙은 AI 대전과 같다: 내 자리만 직접 조작하고 나머지는 봇이나 원격 사람
		_player_ids = GameSession.net_players.duplicate()
	else:
		# 훈련(컴퓨터 대전): 나(P1) + AI 1~3명
		_player_ids = []
		for seat: int in range(1, clampi(GameSession.ai_opponents, 1, 3) + 2):
			_player_ids.append(seat)
	_compute_seats()
	manager = TurnManager.new()
	manager.name = "TurnManager"
	manager.hotseat_mode = true
	manager.step_delay_sec = MOVE_STEP_SECONDS
	manager.review_enabled = not instant_roll_for_test  # 드래프트 뒤 [선택한 증강] 확인 단계 (모두 확인하면 라운드 시작)
	manager.stack_choice_enabled = true  # 아군 말에 도착하면 합류(업기)할지 고른다 (모든 기물)
	_bot = BotController.new()
	_bot.name = "BotController"
	_bot.manager = manager
	_bot.pace = 1.0  # 봇 생각 시간은 연출 속도 배율을 곱하지 않는다 (배속은 Engine.time_scale이 맡는다)
	_bot.busy_check = _bot_should_wait
	_bot.enabled = ai_mode
	if not GameSession.net_active:
		var computer_seats: Array[int] = []
		for seat: int in _player_ids:
			if seat != local_player_id:
				computer_seats.append(seat)
		_bot.bot_players = computer_seats
		_bot.difficulty = GameSession.bot_difficulty()  # 놀이터 난이도 (불닭 Fire Level 1~5)
	add_child(_bot)
	add_child(manager)
	manager.set_process(false)  # 제한 시간은 체크박스로 켤 때만 흐른다 (혼자 테스트할 때 자동 진행 방지)
	if GameSession.net_active:
		_setup_net()
	manager.phase_changed.connect(_on_phase_changed)
	manager.processing_started.connect(_begin_refresh_batch)
	manager.processing_finished.connect(_end_refresh_batch)
	manager.event_received.connect(_on_event)
	manager.action_rejected.connect(_on_action_rejected)
	manager.turn_order_reversed.connect(_on_turn_order_reversed)
	manager.game_over.connect(_on_game_over)
	_sync_race_end()
	_build_ui()
	if net != null:
		_log_line("상대를 기다리는 중입니다...", Color("ffe066"))
		net.begin.call_deferred()
	else:
		_new_game()
	_apply_game_speed()
	var mobile := MobileSupport.new()
	add_child(mobile)


## 보드를 떠나면(로비·시작 화면) 배속을 풀어 다른 화면이 빨라지지 않게 한다.
func _exit_tree() -> void:
	Engine.time_scale = 1.0


## 코너 번호(0 우하단, 1 우상단, 2 좌상단, 3 좌하단)에 앉는 플레이어: 로컬 플레이어 기준 상대 좌석.
func get_player_for_corner(corner_idx: int) -> int:
	return ((local_player_id - 1 + corner_idx) % 4) + 1


## get_player_for_corner()의 역함수: 플레이어가 앉는 코너 번호.
func corner_of_player(player_id: int) -> int:
	return posmod(player_id - local_player_id, 4)


## 참가 인원과 내 자리로 모두의 앉은 자리를 정한다. 나는 아래, 나머지는 턴 순서(다음 -> 맞은편 -> 이전)대로:
## 1명이면 맞은편(위), 2명이면 오른쪽·왼쪽, 3명이면 오른쪽·위·왼쪽.
func _compute_seats() -> void:
	_seat_anchor.clear()
	_seat_anchor[local_player_id] = SEAT_ME
	var others: Array[int] = []
	for step: int in range(1, 4):
		var candidate: int = ((local_player_id - 1 + step) % 4) + 1
		if _player_ids.has(candidate):
			others.append(candidate)
	var anchors: Array[StringName] = []
	match others.size():
		1: anchors = [SEAT_RIGHT]
		2: anchors = [SEAT_RIGHT, SEAT_LEFT]
		_: anchors = [SEAT_RIGHT, SEAT_TOP, SEAT_LEFT]
	for index: int in others.size():
		_seat_anchor[others[index]] = anchors[index]


func seat_anchor_of(player_id: int) -> StringName:
	return _seat_anchor.get(player_id, SEAT_ME)


func _process(delta: float) -> void:
	_update_trap_pulse(delta)
	_update_danger_pulse(delta)
	if manager == null or manager.state == null or state == null:
		return
	if not manager.is_game_over:
		_phase_label.text = _phase_text()
	_bot.instant = instant_roll_for_test
	_update_time_pressure(delta)
	# 굴리기 화면은 앞선 연출·카드 끌기·필살기 겨누기가 끝나는 순간 켜지고, 시작되는 순간 꺼진다 (어떤 경로로 바뀌든 프레임마다 맞춘다)
	# 이어서 당기려고 남겨 둔 리볼버: 그 사람의 굴림 대기가 끝나면(차례가 넘어가거나 멈추기) 내린다
	if _presenter != null and _presenter.holding and not _fx_busy:
		var holder_tool: BaseJudgmentTool = state.tools.get(manager.current_player_id())
		if manager.current_player_id() != _presenter.hold_owner or manager.current_state != TurnManager.State.PHASE_ROLL_WAIT or holder_tool == null or not holder_tool.has_pending_state():
			_presenter.cancel()
	if _stack_overlay == null and manager.stack_offer_pending():
		_refresh_stack_overlay()  # 알림이 끝나는 순간 업기 선택 창을 띄운다
	var roll_view: bool = _roll_view_allowed()
	if roll_view != _last_roll_view:
		_last_roll_view = roll_view
		_refresh_controls()
	if _review_bar != null and is_instance_valid(_review_bar):
		var track: Control = _review_bar.get_parent()
		var full: float = GameEnums.PHASE_TIME_REVIEW * maxf(manager.timer_scale, 0.001)
		_review_bar.size = Vector2(track.size.x * clampf(manager.phase_time_left / full, 0.0, 1.0), track.size.y)
	_update_tip(delta)
	_update_reaction_popup(delta)
	if _motion_retry and not _fx_motion_pending():
		_motion_retry = false
		_refresh_all()
	if _hold_card != null and (not is_instance_valid(_hold_card) or not _card_zone(_hold_card).has_point(get_global_mouse_position())):
		_release_hold_card()
	# 말 선택 단계: 지금 고를 수 있는 내 말 도형이 위아래로 통통 튄다.
	var selecting: bool = manager.current_state == TurnManager.State.PHASE_SELECT_PAWN and not manager.is_game_over
	var wave: float = -absf(sin(Time.get_ticks_msec() / 1000.0 * 7.0)) * 6.0
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null:
			continue
		var bounce: Node2D = view.get_node_or_null("Bounce")
		if bounce != null:
			var active: bool = selecting and pawn.owner_id == manager.current_player_id() and _can_pick_now(pawn)
			bounce.position.y = (wave if active else 0.0) - (TILT_PAWN_LIFT if view_mode == ViewMode.TILT else 0.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Sfx.unlock()  # 웹 브라우저가 소리를 막아 두므로 첫 클릭에서 오디오를 깨운다
	if _track_cheat_sequence(event):
		get_viewport().set_input_as_handled()
		return
	_emote_picker_input(event)
	if manager == null or state == null or _menu_is_open():
		return
	if _snipe_pick and _handle_snipe_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_aim_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_card_pointer(event):
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT and _pawn_click_target(press.position) == -1:
		_on_board_tip_click(press.position)  # 이동으로 쓰이지 않는 클릭은 말·설치물 설명을 열고 닫는다
	if event is InputEventMouseMotion:
		_hover_attachment_tip((event as InputEventMouseMotion).position)  # 설치물 위에 커서를 올리면 바로 설명
	if manager.current_state != TurnManager.State.PHASE_SELECT_PAWN:
		return
	if _pawn_pick_blocked():
		return
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null:
		# 보드 위의 내 말 도형을 직접 클릭해 이동한다.
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked: int = _pawn_click_target(button_event.position)
			if clicked != -1:
				get_viewport().set_input_as_handled()
				_on_pawn_pressed(clicked)
		return
	if not (event is InputEventMouseMotion):
		return
	var hovered: int = _pawn_at((event as InputEventMouseMotion).position)
	if hovered != -1 and hovered != _board_hover_pawn:
		_preview_pawn(hovered)
		_board_hover_pawn = hovered
	elif hovered == -1 and _board_hover_pawn != -1:
		_clear_highlight()


## 지금은 보드에서 말을 골라 움직일 수 없다 (연출·봇 차례·다른 창·칸 고르기 중).
func _pawn_pick_blocked() -> bool:
	return _ui_busy() or _is_bot_turn() or _choice_overlay != null or _draft_overlay != null or _result_overlay != null or _stack_overlay != null or _tile_pick_active


## 이 클릭으로 움직일 내 말 ID (말 선택 단계에서 고를 수 있는 내 말을 눌렀을 때). 이동으로 쓰이지 않으면 -1.
func _pawn_click_target(pointer: Vector2) -> int:
	if manager.current_state != TurnManager.State.PHASE_SELECT_PAWN or _pawn_pick_blocked():
		return -1
	if _select_banner != null and _select_banner.visible and _select_banner.get_global_rect().has_point(pointer):
		return -1
	return _pawn_at(pointer)


## 화면 좌표 근처(18px)에 있는, 지금 고를 수 있는 내 말의 ID. 없으면 -1.
func _pawn_at(mouse: Vector2) -> int:
	var found: int = -1
	var best: float = 50.0
	for pawn: PlayerPawn in state.selectable_pawns(manager.current_player_id(), _queued_dice()):
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null or not view.visible:
			continue
		var distance: float = (view.position + _pawn_layer.position + Vector2(0,-12)).distance_to(mouse)
		if PawnToken.HIT_BOX.has_point((view.get_node("Bounce") as Node2D).to_local(mouse)) and distance < best:
			best = distance
			found = pawn.entity_id
	return found


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo:
		return
	# Ctrl/Alt/Meta/Shift 조합은 브라우저·OS 단축키(예: Ctrl+Shift+R 강력 새로고침)이므로 게임 단축키로 쓰지 않는다.
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed or key_event.shift_pressed:
		return
	var roll_key: bool = key_event.keycode == KEY_R or key_event.keycode == KEY_SPACE
	if not key_event.pressed:
		return
	if key_event.keycode == KEY_ESCAPE:
		if _menu_is_open():
			if _menu_page == &"main":
				_close_menu()
			else:
				_show_menu_page(&"main")
		elif _aim_pawn != -1 or _tile_pick_active:
			_cancel_aim()
			_cancel_tile_pick()
		elif _choice_overlay == null and _draft_overlay == null and _stack_overlay == null:
			_open_menu()
		return
	if _menu_is_open():
		return
	if key_event.keycode == KEY_L and _action_log != null:
		_action_log.toggle()  # 액션 로그 펼치기/접기 (오버레이가 떠 있어도 볼 수 있다)
		return
	if _choice_overlay != null or _draft_overlay != null or _result_overlay != null or _stack_overlay != null:
		return
	if roll_key:
		_roll_by_key()


# ---------------------------------------------------------------------------
# 새 게임
# ---------------------------------------------------------------------------

## 통계에 쓰는 이 판의 모드 이름 (놀이터 / 친선 / 익명 / 4인 수동).
func _telemetry_mode() -> String:
	var label: String = MatchTelemetry.mode_label(net != null, ai_mode, GameSession.lobby_intent == &"quick")
	if net == null and ai_mode:
		label += " %s" % BotTemper.tag(_bot.difficulty if _bot != null else GameSession.bot_difficulty())  # 놀이터 [Lv.2 로제] (디스코드 통계는 한국어)
	elif net != null and GameSession.lobby_intent != &"quick":
		# 친선 [클래식 완주전] / 친선 [법전OFF/함정비공개/봇Lv.3]: 방장이 고른 규칙 (디스코드 통계는 한국어)
		var rules: Dictionary = state.match_rules if state != null and not state.match_rules.is_empty() else GameSession.match_rules()
		label += " [%s]" % MatchTelemetry.rules_label(rules, not GameSession.net_bots.is_empty())
	return label


## 통계에서 '나'로 칠 자리: 컴퓨터 대전·온라인은 내 자리, 한 화면 4인 수동은 없다(-1).
func _telemetry_seat() -> int:
	return local_player_id if (ai_mode or net != null) else -1


## 보드판에 들어와 새 판이 시작됐다: [매치 시작]을 알리고 걸린 시간·고른 증강을 모으기 시작한다.
## 생애 첫 판(누적 판 수 1 이하)에만: 화면 위쪽에 "어디를 보면 효과를 알 수 있는지" 한 줄 팁을 몇 초 띄운다.
const FIRST_MATCH_TIP: String = "팁: 보드 위의 말, 함정, 좌측 법전에 마우스를 올리면(모바일은 탭) 상세 효과를 언제든 볼 수 있어요!"
const FIRST_MATCH_TIP_SECONDS: float = 7.0


func _show_first_match_tip() -> void:
	if not _fx_on() or not is_inside_tree():
		return
	var old: Node = get_node_or_null("FirstMatchTip")
	if old != null:
		old.queue_free()
	var canvas := CanvasLayer.new()
	canvas.name = "FirstMatchTip"
	canvas.layer = 55
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.09, 0.16, 0.92)
	box.border_color = Color("ffd43b")
	box.set_border_width_all(2)
	box.set_corner_radius_all(18)
	box.content_margin_left = 16
	box.content_margin_right = 20
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	canvas.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var bulb: TextureRect = HubArt.icon(&"tip")
	bulb.custom_minimum_size = Vector2(28, 28)
	bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bulb)
	var text := _make_label(FIRST_MATCH_TIP, MobileSupport.text_px(16), Color("fff3bf"))
	text.name = "FirstMatchTipText"
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(text)
	var view: Vector2 = get_viewport_rect().size
	panel.reset_size()
	panel.position = Vector2((view.x - panel.size.x) / 2.0, 56.0)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(panel, "position:y", 62.0, 0.4).from(40.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(FIRST_MATCH_TIP_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(canvas.queue_free)


func _report_match_start() -> void:
	_match_started_msec = Time.get_ticks_msec()
	_my_augments.clear()
	_match_number = 0
	if not MatchTelemetry.is_active():
		return
	_match_number = GameSession.begin_match()
	MatchTelemetry.report_match_start(self, _telemetry_mode(), _match_number)


## 결과 화면(시상대)이 뜬 판을 [매치 완료]로 알린다. 내가 먼저 졸업했으면 그때 이미 보냈다 (판마다 한 번).
func _report_match_once() -> void:
	if state == null or manager == null or not manager.is_game_over:
		return
	var seat: int = _telemetry_seat()
	_send_match_complete_webhook(state.rankings.find(seat) + 1 if seat != -1 else 0)


## 순위가 확정됐다: 그 사람이 '나'면 즉시 [매치 완료]를 보낸다 (봇끼리 남은 판을 기다리지 않는다).
func _report_player_ranked(player_id: int, rank: int) -> bool:
	if player_id == -1 or player_id != _telemetry_seat():
		return false
	_record_meta_progress(player_id, rank)
	return _send_match_complete_webhook(rank)


## 영구 기록(PlayerSave): 특수 승리 법전으로 졸업하면 그 법전을 도감 도장으로, 놀이터(컴퓨터 대전)에서 1위면 그 불닭 난이도의 왕관·최단 라운드를 남긴다.
## 게임 규칙에는 영향이 없는 표시용 기록이다. 검사·연출 끈 판은 남기지 않는다.
func _record_meta_progress(player_id: int, rank: int) -> void:
	if state == null or not record_meta_progress:
		return
	var reason: String = str(state.rank_reasons.get(player_id, ""))
	if LawRegistry.ALL_IDS.has(reason) and PlayerSave.mark_law(reason):
		_log_line("[법전 수집] 새 도장: %s (%d/8)" % [VictoryChecker.short_reason(StringName(reason)), PlayerSave.law_count()], Color("ffd43b"))
	if rank == 1 and net == null and ai_mode:
		var level: int = _bot.difficulty if _bot != null else GameSession.bot_difficulty()
		if PlayerSave.record_buldak(level, int(state.round_number)):
			_log_line("[불닭 정복] %s 최고 기록: %d라운드" % [BotTemper.label(level), int(state.round_number)], Color("ffd43b"))


## [매치 완료] 보내기: 로컬 플레이어의 순위가 확정되는 순간(일반 완주·특수 승리) 또는 결과 화면이 뜨는 순간 중 먼저 오는 쪽에서 한 번만.
## 컴퓨터 대전에서 내가 먼저 졸업하면 봇끼리 끝까지 두는 동안 로비로 나가 버려 결과 화면(게임 종료)까지 가지 않는 경우가 많다 -> 졸업 즉시 보낸다.
## 1위의 우승 방식은 지금까지 확정된 1위 기준이다. 값이 비어 있어도 안전한 기본값으로 보낸다.
func _send_match_complete_webhook(my_rank: int) -> bool:
	if _match_complete_sent or state == null:
		return false
	_match_complete_sent = true
	var first: int = int(state.rankings[0]) if not state.rankings.is_empty() else -1
	var reason: StringName = StringName(str(state.rank_reasons.get(first, VictoryChecker.ALL_HOME)))
	var seconds: int = maxi(int((Time.get_ticks_msec() - _match_started_msec) / 1000), 0) if _match_started_msec > 0 else 0
	var nth: int = _match_number if _match_number > 0 else GameSession.match_count()
	var augments: Array[String] = []
	for name: Variant in _my_augments:
		augments.append(str(name))
	return MatchTelemetry.report_match_end(self, nth, _telemetry_mode(), int(state.round_number), seconds, maxi(my_rank, 0), reason, augments, _difficulty_report(my_rank, first))


## 체감 난이도 지표: 1위 이름, 내 킬/데스, 누적 [N판 중 1위 M회] ('나'가 없는 4인 수동은 1위 이름만). 누적 기록은 이때 한 판 늘린다.
func _difficulty_report(my_rank: int, first: int) -> Dictionary:
	var report: Dictionary = {"winner": _player_name(first) if first != -1 else ""}
	var seat: int = _telemetry_seat()
	if seat == -1:
		return report
	report["kills"] = state.stat(seat, GameState.TALLY_KILLS)
	report["deaths"] = state.stat(seat, GameState.TALLY_DEATHS)
	if my_rank > 0 and MatchTelemetry.is_active():
		report.merge(GameSession.record_match_result(my_rank))
	return report


func _new_game() -> void:
	_match_complete_sent = false
	sweep_oneshot_fx(true)  # 다시 하기: 앞 판의 일회성 연출은 수명과 상관없이 모두 치운다
	# Initial scene entry has already selected a backdrop; an actual rematch repicks.
	if state != null and _match_background != null:
		_match_background.choose_random()
	_close_choice()
	_close_draft_overlay()
	_close_result_overlay()
	_cancel_tile_pick()
	for view: Node in _pawn_views.values():
		view.queue_free()
	for view: Node in _npc_views.values():
		view.queue_free()
	_pawn_views.clear()
	_npc_views.clear()
	_log.clear()
	if _action_log != null:
		_action_log.clear_entries()
	_divider_round = 0
	_toast_label.text = ""
	_dock_player = -1
	_announced_round = 0
	_announced_turn_key = ""
	_beat_until_msec = 0
	_close_reaction_popup()
	_reset_presentation()
	_capture_epoch += 1
	_capture_marks.clear()
	if _capture_cutin != null:
		_capture_cutin.cancel()
	_stage_warps = 0
	_trap_pending.clear()
	_trap_tiles.clear()
	_fx_busy = false
	_bot.set_enabled(_bot_active())
	_presenter.cancel()
	if _draw_fx != null:
		_draw_fx.clear()
	_roll_pad.cancel_spin()
	_roll_pad.reset_revolver()
	_announcer.cancel()
	_cancel_card_drag()
	_cancel_aim()
	_close_zoom()
	_tip_end()
	_tool_board_key = ""
	_close_stack_overlay()
	_close_opening()
	_shown_turn = -1
	_draft_summary.clear()
	_draft_banner_round = 0
	state = null
	manager.match_rules = GameSession.match_rules()
	manager.start_game(_player_ids, _game_seed)
	state = manager.state
	_report_match_start()
	if GameSession.match_count() <= 1 and (ai_mode or net != null):
		_show_first_match_tip()
	var rule_summary: String = MatchRules.summary(state.match_rules)
	if rule_summary != "":
		_log_line("[방 규칙] %s" % rule_summary, Color("63e6be"))
	_bind_state()
	_build_tiles_once()
	_build_pawn_views()
	_apply_view_mode()
	_intro_pending = true
	_start_opening.call_deferred()
	if net != null:
		_log_line("온라인 대전을 시작했습니다 (%d명). 내 차례에 직접 조작하세요." % _player_ids.size(), Color("63e6be"))
	else:
		_log_line("새 게임을 시작했습니다. 4인 핫시트: 버튼을 눌러 모든 플레이어를 번갈아 조작하세요.", Color("adb5bd"))
	_refresh_all()


func _bind_state() -> void:
	_game_started_msec = Time.get_ticks_msec()
	state.pawn_stepped.connect(_on_pawn_stepped)
	state.pawn_warped.connect(_on_pawn_warped)
	state.pawn_warped.connect(func(pawn_id: int, _from_tile: int, to_tile: int) -> void: _note_super({"kind": "teleport", "pawn": pawn_id, "tile": to_tile}))
	state.pawn_captured.connect(_on_pawn_captured)
	state.snapshot_restored.connect(func() -> void:
		_reset_presentation()
		_capture_epoch += 1
		_capture_marks.clear()
		if _capture_cutin != null:
			_capture_cutin.cancel())
	state.pawn_teleported.connect(func(pawn_id: int, to_tile: int) -> void: _note_super({"kind": "teleport", "pawn": pawn_id, "tile": to_tile}))
	state.redistribution_started.connect(func(hand_counts: Dictionary, reference_player: int) -> void:
		_note_super({"kind":"redistribution", "hands":hand_counts.duplicate(), "reference":reference_player}))
	state.pawn_sent_to_start.connect(func(pawn_id: int, by_player: int) -> void:
		_note_super({"kind": "start", "pawn": pawn_id, "by": by_player})
		var victim: PlayerPawn = state.get_pawn(pawn_id)
		_log_line("%s 출발선으로 복귀%s" % [_pawn_name(pawn_id), "  [복수 부스터 획득: 다음 출발 +%d칸]" % _revenge_steps(victim) if victim != null and victim.revenge_boost else ""], Color("ff8787"))
		if victim == null:
			return
		if not _fx_on():
			_record_ejection(pawn_id, by_player)
		if _alkkagi_controlled.has(pawn_id) or _train_controlled.has(pawn_id) or _nitro_victims.has(pawn_id):
			if _fx_on():
				_record_ejection(pawn_id, by_player)
			return
		var victim_owner: int = victim.owner_id
		if by_player != victim_owner and not _is_computer_seat(victim_owner):
			_mark_spotlight()  # AI가 사람 말을 잡은 턴은 보통 속도로 보여 준다
		# 반격(거울의 힘·우노 리버스): 방어 대기 중에 막은 사람이 공격한 말을 날렸다 -> 공격자가 역으로 처치 컷인을 맞는다.
		if _fx_on() and manager.counter_pending() and by_player == int(manager.pending_counter()["victim"]) and by_player != victim_owner and not _capture_marks.has(pawn_id):
			_enqueue_reflect_cutin(pawn_id, by_player, victim_owner)
		# 실제 잡기: [방어 결정 대기 -> 컷신 -> 장외 홈런 -> 0번 복귀]를 이동·발판 연출이 모두 끝난 뒤(큐 맨 뒤)에 재생한다.
		# 방어 카드로 막았으면 컷신·홈런·처치 기록 없이 방어 이펙트만 보여 준다 (날아갔다가 돌아오는 장면을 만들지 않는다).
		# 아바타 표정은 바뀌지 않는다: 표정은 플레이어가 고른 감정 표현(이모트)으로만 바뀐다.
		var cutin_capture: bool = _capture_marks.has(pawn_id)
		_capture_marks.erase(pawn_id)
		if _fx_on():
			_enqueue_counter_gate()
			_enqueue_late(func() -> void:
				if not _ejection_confirmed(pawn_id):
					_show_defended(pawn_id)
					return
				_record_ejection(pawn_id, by_player, true)  # 처치 기록은 처치가 확정되고 연출이 나올 때 적는다
				await _play_capture_eject(pawn_id, by_player, victim_owner, cutin_capture), pawn_id))
	state.revenge_boost_fired.connect(_on_revenge_boost_fired)
	state.nitro_dashed.connect(_on_nitro_dashed)
	state.leapfrog_boosted.connect(_on_leapfrog_boosted)
	state.capture_charge_started.connect(func(pawn_id: int, charge_steps: int) -> void:
		_follow_up_pawns[pawn_id] = true
		_log_line("[8번 공 돌진] %s 처치 후 +%d칸 더 굴러갑니다" % [_pawn_name(pawn_id), charge_steps], Color("ffd43b"))
		if not _fx_on():
			return
		_enqueue_after_kills(func() -> void:
			var ball: Node2D = _pawn_views.get(pawn_id)
			if ball == null or not is_instance_valid(ball):
				return
			_floating_badge(ball.position + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + Vector2(0, -40), "[8번 공] 처치 돌진 +%d칸!" % charge_steps, Color("ffd43b"), 30), pawn_id))
	state.dash_pad_triggered.connect(func(pawn_id: int, tile: int) -> void:
		_log_line("[부스터 발판] %s %d번 발판! +%d칸 추가 전진" % [_pawn_name(pawn_id), tile, GameData.dash_steps()], Color("63e6be"))
		var pad_pos: Vector2 = (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + _tile_center(tile)
		_follow_up_pawns[pawn_id] = true  # 발판 추가 이동은 도착 칸 처치 연출 뒤에
		if not _fx_on():
			return
		_enqueue_after_kills(func() -> void:
			Sfx.play(&"dash")
			_impact_ring(pad_pos, Color("63e6be"), 46.0)
			_number_pop(pad_pos + Vector2(0, -30), "부스터 발판 +%d" % GameData.dash_steps(), Color("63e6be"))
			_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(300.0 * _motion_pace()))))
	state.pawn_finished.connect(func(pawn_id: int) -> void:
		_note_super({"kind": "finish", "pawn": pawn_id})
		_log_line(tr_ui("log.finish", [_pawn_name(pawn_id)]), Color("69db7c"))
		var finisher: PlayerPawn = state.get_pawn(pawn_id)
		if finisher != null:
			var finisher_owner: int = finisher.owner_id
			_fx_when_announced(func() -> void:
				_profile_react(finisher_owner, true)))
	state.pawn_promoted.connect(func(pawn_id: int) -> void:
		var promoted_pawn: PlayerPawn = state.get_pawn(pawn_id)
		if promoted_pawn != null and promoted_pawn.kind == GameEnums.PawnKind.SHOGI:
			_log_line("[나리] %s 승급! 이동할 때마다 +1칸" % _pawn_name(pawn_id), Color("ff6b6b"))
			_announce_gate("기물 능력", "[나리(成り)!] %s 승급" % promoted_pawn.display_label().split(":")[-1], "%s 승급 ◆ 이동할 때마다 +1칸" % _pawn_name(pawn_id), Color("ff6b6b"), null, 1.2)
			_fx_when_announced(func() -> void: _fx_promote(pawn_id, Color("ff4d4d")))
			_refresh_pawns()
			return
		_log_line("[승진] %s → 체스:퀸! (반환점 통과 승급)" % _pawn_name(pawn_id), Color("ffd43b"))
		_announce_gate("기물 능력", "[발동!] 체스 퀸 승진", "%s 퀸 승진 ◆ 이동 +2칸 · 말·함정 관통" % _pawn_name(pawn_id), Color("ffd43b"), null, 1.2)
		_fx_when_announced(func() -> void: _fx_promote(pawn_id, Color("ffd43b"))))
	state.domino_collapsed.connect(func(pawn_id: int, _passed: Array[int], chain: Array[int]) -> void:
		_log_line("[도미노 연쇄] %s이(가) 도미노를 밟아 함정 %d개가 연쇄 발동!" % [_pawn_name(pawn_id), chain.size()], Color("63e6be"))
		var cannon_pos: Vector2 = (_pawn_views[pawn_id] as Node2D).position if _pawn_views.has(pawn_id) else Vector2.ZERO
		_fx_when_announced(func() -> void:
			screen_shake(7.0, 0.25)
			_impact_ring(cannon_pos, Color("63e6be"), 40.0))
		_announce_gate("함정 발동", "도미노 연쇄!", "%s이(가) 도미노를 밟고 멈췄습니다\n반경 %d칸의 함정 %d개가 줄줄이 터집니다" % [_pawn_name(pawn_id), TrapDomino.chain_radius(), chain.size()], Color("63e6be"), null, 1.4))
	state.tower_struck.connect(func(tile: int, scattered: Array[Dictionary]) -> void:
		_log_line("[타로] 무너지는 탑이 %d번 타일에 벼락! 말 %d개가 흩어졌습니다" % [tile, scattered.size()], Color("ffa94d"))
		_announce_gate("타로", "XVI. 무너지는 탑!", "%d번 타일에 벼락이 내리쳐 말 %d개가 뿔뿔이 흩어졌습니다" % [tile, scattered.size()], Color("ffa94d"), null, 1.5)
		var struck_pos: Vector2 = _tile_center(tile)
		for entry: Dictionary in scattered:
			_set_hint(int(entry["pawn_id"]), {"arc": 52.0, "peak": 1.3, "dur": 0.6, "delay": 0.35})
		_fx_when_announced(func() -> void: _impact_ring(struck_pos, Color("ffe066"), 44.0))
		_refresh_pawns())
	state.wheel_turned.connect(func(player_id: int, mine_id: int, enemy_id: int, outcome: StringName) -> void:
		if outcome == &"swap":
			_log_line("[타로] P%d의 운명의 수레바퀴: %s ↔ %s 위치 교환" % [player_id, _pawn_name(mine_id), _pawn_name(enemy_id)], Color("ffa94d"))
			_announce_gate("타로", "X. 운명의 수레바퀴!", "%s과(와) %s의 위치가 뒤바뀝니다" % [_pawn_name(mine_id), _pawn_name(enemy_id)], Color("ffa94d"), null, 1.5)
		elif outcome == &"eject_place":
			_log_line("[타로] P%d의 운명의 수레바퀴: %s 장외 사출 → %s이(가) 그 자리로" % [player_id, _pawn_name(enemy_id), _pawn_name(mine_id)], Color("ffa94d"))
			_announce_gate("타로", "X. 운명의 수레바퀴!", "%s이(가) 출발선으로 날아가고 %s이(가) 그 자리를 차지합니다" % [_pawn_name(enemy_id), _pawn_name(mine_id)], Color("ffa94d"), null, 1.5)
			_set_hint(mine_id, {"arc": 52.0, "peak": 1.3, "dur": 0.6, "delay": 0.35})
		else:
			_log_line("[타로] 운명의 수레바퀴: %s 장외 사출" % _pawn_name(enemy_id), Color("ffa94d"))
			_announce_gate("타로", "X. 운명의 수레바퀴!", "%s이(가) 출발선으로 날아갑니다" % _pawn_name(enemy_id), Color("ffa94d"), null, 1.5)
		_refresh_pawns())
	state.pawn_evolved.connect(func(pawn_id: int, kind: int, unit_no: int) -> void: _log_line("[진화] %s → %s" % [_pawn_name(pawn_id), PawnCatalog.unit_label(kind, unit_no)], Color("ffa94d")))
	state.pawns_stacked.connect(func(leader_id: int, member_ids: Array[int]) -> void: _log_line("%s 업기 (%d마리)" % [_pawn_name(leader_id), member_ids.size()], Color("ffd43b")))
	state.pawns_swapped.connect(func(a_id: int, b_id: int) -> void:
		_log_line("%s ↔ %s 위치 교환" % [_pawn_name(a_id), _pawn_name(b_id)], Color("ffd43b"))
		_hint_swap(a_id, b_id))
	state.pawns_castled.connect(func(a_id: int, b_id: int) -> void:
		_note_super({"kind": "castle", "a": a_id, "b": b_id})
		_hint_swap(a_id, b_id))
	state.pawn_pushed_back.connect(func(pawn_id: int, _from: int, _to: int) -> void:
		if not _fx_hints.has(pawn_id):
			_set_hint(pawn_id, {"arc": 0.0, "dur": 0.5}))
	state.passive_triggered.connect(_on_passive_triggered)
	state.shield_broken.connect(func(pawn_id: int, tile: int) -> void:
		_refresh_pawn_protection(pawn_id, true)
		_on_passive_triggered(pawn_id, &"shield_block")
		var shield_pawn: PlayerPawn = state.get_pawn(pawn_id)
		if shield_pawn != null and shield_pawn.sub_type() != GameEnums.PawnSubType.BADUK_WHITE:
			_log_line("[보호막] %s이(가) %d번 타일에서 공격을 막고 보호막이 깨졌습니다" % [_pawn_name(pawn_id), tile], Color("4dabf7"))
		else:
			_log_line("[백돌 방어막] %s이(가) %d번 타일에서 공격을 막고 방어막이 깨졌습니다" % [_pawn_name(pawn_id), tile], Color("b197fc"))
		if _fx_on():
			_fx_when_announced(func() -> void:
				_impact_ring(_tile_center(tile) + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO), Color("e5dbff"), 30.0)
				Sfx.play(&"good")))
	state.side_collapsed.connect(func(side: int, tiles: Array[int], destroyed: int) -> void:
		_log_line("[무너지는 탑] %d번 변(%d~%d번 칸)의 설치물 %d개가 무너졌습니다" % [side + 1, tiles[0], tiles[-1], destroyed], Color("ffa94d"))
		_refresh_tiles()
		if _fx_on():
			_fx_when_announced(func() -> void:
				screen_shake(9.0, 0.3)
				for tile: int in tiles:
					_impact_ring(_tile_center(tile) + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO), Color("ffa94d"), 22.0)
				Sfx.play(&"slam")))
	state.crowbar_swung.connect(func(player_id: int, tiles: Array[int]) -> void:
		_log_line("[내 앞을 막지마!] %s이(가) %s번 칸을 휘둘렀습니다" % [_player_name(player_id), ", ".join(PackedStringArray(tiles.map(func(tile: int) -> String: return str(tile))))], Color("ffa94d"))
		_refresh_tiles())
	state.pawns_bonded.connect(func(a: int, b: int) -> void:
		_note_super({"kind": "bond", "a": a, "b": b})
		_log_line("[강제 연대책임] %s ↔ %s 일심동체!" % [_pawn_name(a), _pawn_name(b)], Color("ffa94d")))
	state.bond_resolved.connect(func(kind: StringName, pawn_id: int, partner_id: int) -> void:
		if _fx_on() and _pawn_views.has(pawn_id) and _pawn_views.has(partner_id):
			var inverse := get_global_transform().affine_inverse()
			var pulse := {"a":pawn_id,"b":partner_id,"mode":kind,"from":inverse*_pawn_views[pawn_id].global_position,"to":inverse*_pawn_views[partner_id].global_position}
			_enqueue_late(_play_bond_stage.bind(pulse),partner_id)
		var pawn: PlayerPawn = state.get_pawn(pawn_id)
		var verb: String = "함께 골인!" if kind == &"finish" else "함께 출발선으로!"
		_log_line("[강제 연대책임] %s의 짝 %s도 %s" % [_pawn_name(pawn_id), _pawn_name(partner_id), verb], Color("ffa94d"))
		if pawn != null:
			_record(pawn.owner_id, "연대책임: %s 짝 말도 %s" % [_bq("%d번 말" % pawn.slot), verb], "", true))
	state.npc_sweep_started.connect(_on_train_sweep_started)
	state.npc_swept.connect(_on_npc_swept)
	state.shield_recharged.connect(func(pawn_id: int) -> void:
		_refresh_pawn_protection(pawn_id)
		_log_line("[백돌 방어막] %s의 방어막이 다시 차올랐습니다" % _pawn_name(pawn_id), Color("b197fc")))
	state.trap_defused.connect(func(tile: int, id: String, pawn_id: int) -> void:
		_on_passive_triggered(pawn_id, &"sweeper_defuse")
		_log_line("[지뢰찾기] %s이(가) %d번 타일의 %s을(를) 해체하고 카드 1장!" % [_pawn_name(pawn_id), tile, _attachment_name(id)], Color("63e6be"))
		var sweeper: PlayerPawn = state.get_pawn(pawn_id)
		if sweeper != null:
			_record(sweeper.owner_id, "%d번 타일의 %s 해체! (카드 1장)" % [tile, _bq(_attachment_name(id))])
		_refresh_tiles())
	state.attachment_triggered.connect(func(tile: int, id: String, pawn_id: int, _cutscene: StringName) -> void:
		var trapped: PlayerPawn = state.get_pawn(pawn_id)
		if trapped != null:
			var trapped_owner: int = trapped.owner_id
			var trap_pos: Vector2 = _tile_center(tile)
			# 순서: 함정이 터진다(충격) -> 잠깐 뒤 프로필 반응 -> 그 뒤 말이 날아간다 (_fx_hint_bonus)
			_fx_hint_bonus = maxf(_fx_hint_bonus, 0.4)
			_fx_when_announced(func() -> void:
				Sfx.play(&"trap")
				screen_shake(8.0, 0.25)
				_impact_ring(trap_pos, Color("ff6b6b"), 56.0)
				_burst_shards(trap_pos, Color("ff8787"), 14)
				get_tree().create_timer(0.25).timeout.connect(func() -> void:
					_profile_react(trapped_owner, false)))
		_log_line("[설치물] %d번 타일 %s 발동! (%s)" % [tile, _attachment_name(id), _pawn_name(pawn_id)], Color("ff6b6b"))
		if trapped != null:
			_record(trapped.owner_id, "%s 밟음! (%d번 타일, %s)" % [_bq(_attachment_name(id)), tile, _bq("%d번 말" % trapped.slot)])
		if id != "TRP_05":  # 도미노는 [도미노 연쇄!] 알림(domino_collapsed)이 먼저 나왔다: 같은 알림을 연쇄 뒤에 또 띄우지 않는다
			_announce_gate("함정 발동", "[발동!] %s" % _attachment_name(id), "%s\n%d번 타일에서 %s에게 발동" % [card_summary(StringName(id)), tile, _pawn_name(pawn_id)], Color("ff6b6b"), null, 1.2))
	# 중립 기물이 사라질 때는 알림 카드를 띄우지 않는다: 엔진이 즉시 내는 신호라 진행 중인 다른 연출(처치·이동) 사이에 끼어들었다.
	# 결과는 [중립 기물 이동] 카드·달리기·처치 컷인과 기록(로그)으로 이미 보인다.
	state.npc_vanished.connect(func(_npc_id: int, tile: int) -> void:
		_log_line("[중립 기물] %d번 타일에서 사라졌습니다" % tile, Color("fa5252")))
	state.attachment_placed.connect(func(tile: int, id: String, owner_id: int) -> void:
		_note_super({"kind": "place", "tile": tile, "id": id})
		if id.begins_with("TRP") and _fx_on():
			# 카드를 먼저 보여 준 뒤 발판이 짙은 보라색으로 깜빡이며 나타난다.
			_trap_pending[tile] = true
			_fx_when_announced(func() -> void:
				_trap_pending.erase(tile)
				_refresh_tiles()
				_tile_glow(tile)
				_impact_ring(_tile_center(tile) + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO), Color("7b2cbf"), 26.0)
				Sfx.play(&"trap_set")
				_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(350.0 * _motion_pace())))  # 깜빡임을 볼 틈: 다음 알림은 그 뒤에
			if _draft_in_progress() and not _draft_deferred.is_empty():
				_draft_deferred[-1]["trap_tile"] = tile
		_log_line("P%d가 %d번 타일에 [%s]을(를) 설치했습니다" % [owner_id, tile, "뒷면 카드" if id.begins_with("TRP") and not MatchRules.trap_reveal(state) else _attachment_name(id)], Color("adb5bd"))
		_refresh_tiles())
	state.card_drawn.connect(func(player_id: int, card_id: StringName) -> void:
		if _fx_on():
			_fly_drawn_card(player_id, card_id))
	state.card_drawn.connect(func(player_id: int, _card_id: StringName) -> void: _log_line("[카드] P%d 생떼 카드 1장 획득" % player_id, Color("ffa94d")))  # 뽑은 카드는 비공개
	state.card_stolen.connect(func(player_id: int, card_id: StringName) -> void:
		_steal_from = player_id  # 바로 뒤의 카드 획득은 이 사람 프로필에서 날아온다
		_log_line("P%d의 카드 [%s]를 도적이 빼앗았습니다" % [player_id, _card_name(card_id)], Color("ff6b6b")))
	state.npc_spawned.connect(func(_npc_id: int, tile: int) -> void:
		_log_line("중립 기물이 %d번 타일에 소환되었습니다. 라운드가 끝나면 가장 가까운 적 말 하나를 처치하고 사라집니다." % tile, Color("fa5252"))
		_refresh_all())
	state.rulebook.law_added.connect(_on_law_added)
	state.rulebook.law_removed.connect(func(law: LawResource) -> void:
		_log_line("[법전] 교칙 파기: [%s] %s" % [law.law_id, law.law_name], Color("ff8787"))
		_record(-1, "[color=#ff8787][lb]법전] %s 파기[/color]" % _bb(law.law_name), "", true)  # 그 라운드 마지막 처치 기록보다 먼저 찍히지 않게
		_refresh_laws())
	state.rulebook.law_applied.connect(_on_law_applied)


# ---------------------------------------------------------------------------
# UI 구성
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_background = MATCH_BACKGROUND_SCRIPT.new()
	_match_background.name = "MatchBackground"
	_match_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_match_background)

	# 보드판 받침: 화면 정중앙의 둥근 판
	var plate := Panel.new()
	_plate = plate
	plate.position = PLATE_POS
	plate.size = PLATE_SIZE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(plate)
	_flat_board_surface = BoardSkin.make_surface()
	_flat_board_surface.position = -PLATE_POS
	plate.add_child(_flat_board_surface)
	_board_layer = Control.new()
	_board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_layer)
	# 기울인 시점의 보드 면(사다리꼴)과 그림자: 타일·선보다 아래에 깔린다.
	_board_shadow = Polygon2D.new()
	_board_shadow.color = Color(0, 0, 0, 0.45)
	_board_shadow.visible = false
	_board_layer.add_child(_board_shadow)
	_board_surface = BoardSkin.make_surface()
	_board_surface.visible = false
	_board_layer.add_child(_board_surface)
	_board_edge = Line2D.new()
	_board_edge.width = 1.0
	_board_edge.default_color = Color("5da530", 0.35)
	_board_edge.closed = true
	_board_edge.visible = false
	_board_layer.add_child(_board_edge)
	_pawn_layer = Node2D.new()
	add_child(_pawn_layer)

	_build_toast_label()
	_build_profiles()
	_build_law_board()
	_build_action_log()
	_build_tool_board()
	_build_status_strip()
	_build_action_bar()
	_build_dock()
	_build_pawn_dock()
	_build_emote_row()
	_build_select_banner()
	_build_direction_icons()
	_build_center_banner()
	_build_roll_fx()
	_build_drawers()
	_build_menu()
	_build_drop_zone()
	_build_aim_layer()
	_build_train_stage()
	_build_hover_tip()
	var capture_layer := CanvasLayer.new()
	capture_layer.name = "CapturePresentation"
	capture_layer.layer = 60
	add_child(capture_layer)
	_capture_cutin = CaptureCutin.new()
	_capture_cutin.name = "CaptureCutin"
	capture_layer.add_child(_capture_cutin)
	_debug_enabled = debug_requested()
	_debug_toggle.visible = _debug_enabled
	_register_layout()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_apply_avatars()
	# 이 판에 앉지 않은 자리의 프로필은 숨긴다 (온라인 2~3인 대전).
	for seat: int in PLAYER_IDS:
		if not _player_ids.has(seat):
			(_profiles[seat]["panel"] as Control).visible = false
	if GameSession.net_active:
		# 온라인에서는 새 게임·모드 전환·치트(상태를 직접 바꿔 판이 어긋난다)를 쓸 수 없다.
		for control: Control in [_mode_toggle, _new_game_button, _debug_toggle, _debug_box]:
			control.visible = false


## 상단 중앙 리본 배너(슬림): 라운드 / 현재 턴 / 진행 방향 한 줄. 이벤트는 중앙 알림과 전체 로그가 맡는다.
## 어느 묶음에 속하는지 등록해 둔다: 0 왼쪽 / 1 가운데(보드) / 2 오른쪽. 기준 위치(base)에 묶음 오프셋을 더해 배치한다.
func _register_layout() -> void:
	_layout_entries.clear()
	var left: Array = [_law_panel, _feedback_button]
	var center: Array = [_select_banner, _dir_left, _dir_right, _board_layer, _pawn_layer, _dock, _drop_zone, _pick_banner, _pick_cancel, _roll_button, _roll_pad, _gun_row, _stage_yacht, _stage_blackjack, _stage_pinball, _danger_label]
	var right: Array = [_tool_board, _action_row, _pawn_bar, _emote_row, _menu_button, _speed_button, _language_button, _debug_box, _log_panel]
	for index: int in PLAYER_IDS.size():
		var player_id: int = PLAYER_IDS[index]
		var panel: Control = _profiles[player_id]["panel"]
		match seat_anchor_of(player_id):
			SEAT_LEFT, SEAT_TOP: left.append(panel)
			_: right.append(panel)
	for node: Variant in left:
		_layout_entries.append({"node": node, "base": (node as CanvasItem).position, "group": 0})
	for node: Variant in center:
		_layout_entries.append({"node": node, "base": (node as CanvasItem).position, "group": 1})
	for node: Variant in right:
		_layout_entries.append({"node": node, "base": (node as CanvasItem).position, "group": 2})
	# 배경 위 플레이트는 _build_ui에서 만든 지역 변수라 보드 레이어 쪽에서 함께 옮긴다.


## 창이 디자인 크기(1366x768)보다 넓거나 높으면 남는 공간을 묶음별로 나눠 쓴다: 왼쪽 묶음은 왼쪽 끝, 오른쪽 묶음은 오른쪽 끝에 붙고 보드는 가운데에 선다. 세로는 모두 가운데 정렬.
func _apply_layout() -> void:
	# 창이 없는 환경(헤드리스 테스트)에서는 창 크기가 0이라 디자인 크기를 그대로 쓴다.
	var window_size: Vector2i = DisplayServer.window_get_size()
	layout_for(get_viewport_rect().size if window_size.x > 0 and window_size.y > 0 else DESIGN_SIZE)


## 주어진 화면 크기에 맞춰 묶음 배치를 적용한다 (테스트가 여러 비율을 직접 넣어 볼 수 있다).
func layout_for(viewport_size: Vector2) -> void:
	var extra: Vector2 = Vector2(maxf(viewport_size.x - DESIGN_SIZE.x, 0.0), maxf(viewport_size.y - DESIGN_SIZE.y, 0.0))
	_off_left = Vector2(0.0, extra.y / 2.0)
	_off_center = Vector2(extra.x / 2.0, extra.y / 2.0)
	_off_right = Vector2(extra.x, extra.y / 2.0)
	for entry: Dictionary in _layout_entries:
		var node: CanvasItem = entry["node"]
		if node == null or not is_instance_valid(node):
			continue
		var offset: Vector2 = [_off_left, _off_center, _off_right][int(entry["group"])]
		node.position = (entry["base"] as Vector2) + offset
	if _plate != null:
		_plate.position = PLATE_POS + _off_center
	if _drop_zone != null:
		var drop_bounds: Rect2 = _board_rect()
		_drop_zone.position = drop_bounds.position
		_drop_zone.size = drop_bounds.size
	if _action_log != null:
		_action_log.place(ACTION_LOG_POS + _off_left)
	if _announcer != null:
		_announcer.center = _board_center()
	if _presenter != null:
		_presenter.center = _board_center() + Vector2(0, -40)
		_presenter.toss_board_outline = BoardSkin.outline(_surface_project, _off_center)
	if _draw_fx != null:
		_layout_card_deck()
	if _train_stage != null and _train_stage.mode!=&"idle":
		_train_camera_step()
		_train_stage.sync_projection()


## 보드 한가운데의 화면 좌표 (창 비율 오프셋 포함).
func _board_center() -> Vector2:
	return BOARD_ORIGIN + Vector2(BOARD_SIZE, BOARD_SIZE) / 2.0 + _off_center


## Place the pile beside the lower-right board edge, clear of tiles and dock.
func _layout_card_deck() -> void:
	if _draw_fx == null:
		return
	var center: Vector2 = _board_center()
	var direction := Vector2(1.0,0.52).normalized()
	var outline: PackedVector2Array = BoardSkin.outline(_surface_project,_off_center)
	var rim: Vector2 = center+direction*330.0
	for index: int in outline.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(center,center+direction*2000.0,outline[index],outline[(index+1)%outline.size()])
		if hit != null:
			rim = hit
			break
	_draw_fx.deck_position = rim+direction*100.0
	_draw_fx.reveal_position = center+Vector2(0,-15)
	_draw_fx.place_deck()


## 상단 리본은 없앴다: 현재 턴은 프로필의 밝기·강조선, 라운드는 중앙 알림이 알려 준다. 로그 문구만 받는 숨김 라벨만 남긴다.
func _build_toast_label() -> void:
	_toast_label = _make_label("", MobileSupport.text_px(11), Color("ffe8a3"))
	_toast_label.visible = false
	add_child(_toast_label)


## 화면 네 모서리의 미니멀 프로필 카드: 좌측 84x84 아바타 액자, 우측 상단 닉네임(+카드 수), 우측 하단 2x2 기물 상태 슬롯.
## 슬롯은 배경·테두리만으로 [대기(어두운 회색) / 출전(플레이어 색) / 완주(황금빛 ★)]를 구분한다.
func _build_profiles() -> void:
	for player_id: int in PLAYER_IDS:
		var color: Color = PLAYER_COLORS[player_id]
		var anchor: StringName = seat_anchor_of(player_id) if _player_ids.has(player_id) else SEAT_LEFT
		var big: bool = anchor == SEAT_ME
		var card_size: Vector2 = ME_PROFILE_SIZE if big else PROFILE_SIZE
		var slot_size: float = ME_SLOT_SIZE if big else PAWN_SLOT_SIZE
		var panel := PanelContainer.new()
		panel.position = SEAT_POSITIONS[anchor]
		panel.custom_minimum_size = card_size
		panel.size = card_size
		panel.pivot_offset = card_size / 2.0
		add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)

		# 아바타 칸: 사도 Spine/스프라이트 시트가 들어갈 자리 (에셋이 없으면 좌석 글자 + 감정 이름)
		var avatar := AvatarSlot.new()
		avatar.icon_border = false  # 게임 화면은 좌석 색 테두리를 쓴다
		avatar.setup(player_id, color, ME_AVATAR_SIZE if big else AVATAR_SIZE)
		avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 칸이 카드 높이만큼 길쭉하게 늘어나지 않게 정사각형으로 둔다
		row.add_child(avatar)

		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 6 if big else 4)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(right)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(top)
		var name_label := _make_label("플레이어 %d" % player_id, MobileSupport.text_px(18 if big else 15, 20), color.lightened(0.3))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.add_theme_color_override("font_outline_color", Color("0d1018"))
		name_label.add_theme_constant_override("outline_size", 3)
		top.add_child(name_label)
		# [증강]: 이 플레이어의 보유 증강·기물·판정 도구 요약 (올리면 미리 보기, 누르면 고정)
		var info_button: Button = _make_button("증강", Callable(), 11 if not big else 12, Color("3b4a6b"), 4)
		info_button.name = "ProfileInfo"
		info_button.focus_mode = Control.FOCUS_NONE
		info_button.custom_minimum_size = Vector2(40 if not big else 46, 20 if not big else 24)
		info_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_button.pressed.connect(func() -> void: _tip_toggle(info_button, _fill_profile_tip.bind(player_id)))
		_bind_tip(info_button, _fill_profile_tip.bind(player_id))
		top.add_child(info_button)
		var hand_pips := HBoxContainer.new()  # 손패 수는 글자(x3) 대신 카드 뒷면 칩 개수로 보여 준다
		hand_pips.add_theme_constant_override("separation", 1)  # 손패 상한이 8장까지 늘어도 이름 칸을 밀어내지 않게 촘촘히
		hand_pips.alignment = BoxContainer.ALIGNMENT_END
		hand_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand_pips.mouse_filter = Control.MOUSE_FILTER_PASS
		for _i: int in GameEnums.MAX_HAND_SIZE + UtilityAugments.HAND_EXPAND_MAX:  # 에심당 뽈사탕으로 늘어난 상한까지
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(6, 12) if not big else Vector2(8, 14)
			pip.pivot_offset = pip.custom_minimum_size / 2.0
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.add_theme_stylebox_override("panel", _style(Color("ffd43b"), Color("fff3bf"), 1, 2, 0, 0))
			pip.visible = false
			hand_pips.add_child(pip)
		top.add_child(hand_pips)
		var slot_container: Container
		if big:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			slot_container = line
		else:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 4)
			grid.add_theme_constant_override("v_separation", 4)
			slot_container = grid
		slot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(slot_container)
		var slots: Array[Dictionary] = []
		for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
			var cell: Control = slot_container
			if big:
				# 칸 아래에 그 기물의 필살기 버튼이 붙는다 (필살기가 있는 기물만 보인다).
				var column := VBoxContainer.new()
				column.add_theme_constant_override("separation", 3)
				column.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_container.add_child(column)
				cell = column
			var icon := PanelContainer.new()
			icon.custom_minimum_size = Vector2(slot_size, slot_size)
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", -2)
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(box)
			var letter := _make_label("", 20 if big else 16, Color("f1f3f5"))
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(letter)
			var status := _make_label("", 9, Color("f1f3f5"))
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status.mouse_filter = Control.MOUSE_FILTER_IGNORE
			status.visible = true
			box.add_child(status)
			icon.gui_input.connect(_on_pawn_icon_input.bind(icon, player_id * 10 + slot))
			cell.add_child(icon)
			if big:
				var skill_button: Button = _make_button(tr_ui("btn.skill"), _on_skill_pressed.bind(slot - 1), 11, Color("c77d0a"), 6)
				skill_button.custom_minimum_size = Vector2(slot_size, 26)
				skill_button.focus_mode = Control.FOCUS_NONE
				skill_button.add_theme_color_override("font_color", Color("fff9db"))
				skill_button.add_theme_color_override("font_outline_color", Color("5c3a00"))
				skill_button.add_theme_constant_override("outline_size", 3)
				skill_button.visible = false
				skill_button.mouse_entered.connect(_on_pawn_slot_hover.bind(slot - 1))
				skill_button.mouse_exited.connect(_on_pawn_slot_unhover.bind(skill_button))
				cell.add_child(skill_button)
				_skill_buttons.append(skill_button)
			slots.append({"panel": icon, "letter": letter, "status": status})
		_profiles[player_id] = {
			"panel": panel,
			"name": name_label,
			"hand_pips": hand_pips,
			"slots": slots,
			"avatar": avatar,
			"anchor": anchor,
		}
		panel.resized.connect(_fit_profile_to_seat.bind(panel, anchor))
		_fit_profile_to_seat(panel, anchor)


## Preserve seat margins when avatar/skill content grows, and enlarge inward.
func _fit_profile_to_seat(panel: Control, anchor: StringName) -> void:
	var nominal: Vector2 = ME_PROFILE_SIZE if anchor == SEAT_ME else PROFILE_SIZE
	var base: Vector2 = SEAT_POSITIONS[anchor]
	var right_edge: bool = anchor in [SEAT_ME, SEAT_RIGHT]
	var bottom_edge: bool = anchor in [SEAT_ME, SEAT_TOP]
	if right_edge:
		base.x -= maxf(0.0,panel.size.x-nominal.x)
	if bottom_edge:
		base.y -= maxf(0.0,panel.size.y-nominal.y)
	panel.pivot_offset = Vector2(panel.size.x if right_edge else 0.0, panel.size.y if bottom_edge else 0.0)
	var offset := Vector2.ZERO
	for entry: Dictionary in _layout_entries:
		if entry["node"] == panel:
			entry["base"] = base
			offset = [_off_left,_off_center,_off_right][int(entry["group"])]
			break
	panel.position = base+offset


## 좌석의 아바타 id: 온라인은 로비에서 정한 값(컴퓨터는 좌석별 고정), 훈련은 내가 고른 것(컴퓨터는 좌석별 고정).
func _avatar_for(player_id: int) -> StringName:
	var chosen: Array[StringName] = []
	var mine: StringName = AvatarCatalog.sanitize(GameSession.avatar_id)
	if net != null:
		for seat: int in _player_ids:
			if GameSession.net_avatars.has(seat):
				chosen.append(AvatarCatalog.sanitize(GameSession.net_avatars[seat]))
		if GameSession.net_avatars.has(player_id):
			return AvatarCatalog.sanitize(GameSession.net_avatars[player_id])
	elif player_id == local_player_id:
		return mine
	else:
		chosen.append(mine)
	return AvatarCatalog.bot_avatar(player_id, chosen)


func _apply_avatars() -> void:
	# 이번 판에 앉지 않은 사도의 그림·자세는 캐시에서 내린다 (여러 판을 이어 하면 판마다 다른 사도가 쌓였다)
	var seated: Array = []
	for player_id: int in PLAYER_IDS:
		if _player_ids.has(player_id):
			seated.append(_avatar_for(player_id))
	TextureCache.forget_under(AvatarSlot.AVATAR_DIR, seated.map(func(id: StringName) -> String: return AvatarSlot.character_path(id)))
	AvatarCombatArt.retain(seated)
	# 웹: 이 판에 앉은 아바타의 애니메이션 묶음을 내 것부터 뒤에서 받는다 (인트로·첫 드래프트 동안 도착)
	if _player_ids.has(local_player_id):
		AvatarPacks.request(_avatar_for(local_player_id), true)
	for player_id: int in PLAYER_IDS:
		if _player_ids.has(player_id):
			(_profiles[player_id]["avatar"] as AvatarSlot).set_character(_avatar_for(player_id))
			AvatarCombatArt.warm(_avatar_for(player_id))
			AvatarPacks.request(_avatar_for(player_id))


## 플레이어의 아바타가 감정을 보인다 (에셋이 있으면 그 애니메이션, 없으면 자리표시자 연출).
func _avatar_react(player_id: int, new_emotion: AvatarSlot.Emotion, seconds: float = 1.4) -> void:
	var card: Dictionary = _profiles.get(player_id, {})
	if card.is_empty() or not _player_ids.has(player_id):
		return
	(card["avatar"] as AvatarSlot).react(new_emotion, seconds)


## 좌측 중앙 '엘리아스 중앙 법전' 위젯: 둥근 카드형 슬롯 4개를 만들고, 이 판에 걸 수 있는 법전 수만큼만 보인다 (빈 슬롯은 점선 테두리, 활성 교칙은 명패).
func _build_law_board() -> void:
	var panel := PanelContainer.new()
	_law_panel = panel
	panel.position = Vector2(SAFE_MARGIN, 190)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.scale = Vector2(0.78, 0.78)  # 넓어진 마름모의 왼쪽 꼭짓점과 겹치지 않게 줄여 둔다
	panel.add_theme_stylebox_override("panel", UiSkin.panel())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var law_title := _make_label(tr_ui("law.board_title"), MobileSupport.text_px(16, 20), Color.WHITE)
	UiSkin.title(law_title)
	box.add_child(law_title)
	for slot: int in GameEnums.MAX_LAWS:
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(280, 66)
		box.add_child(slot_panel)
		var dash := DashedBorder.new()
		slot_panel.add_child(dash)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(inner)
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(36, 36)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _style(COLOR_GOLD, Color("fff3bf"), 2, 18, 0, 0))
		inner.add_child(badge)
		var badge_label := _make_label("", 14, Color("2b2100"))
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(badge_label)
		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 0)
		text_box.alignment = BoxContainer.ALIGNMENT_CENTER
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(text_box)
		var name_label := _make_label("", MobileSupport.text_px(14), UiSkin.INK)
		name_label.clip_text = true
		text_box.add_child(name_label)
		var desc_label := _make_label("", MobileSupport.text_px(12), UiSkin.SOFT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.max_lines_visible = 2
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(desc_label)
		# [달성 임박!]: 슬롯 오른쪽 위 (PanelContainer가 크기 플래그대로 모서리에 붙인다)
		var near := _make_label("[달성 임박!]", MobileSupport.text_px(13), Color.WHITE)
		near.name = "LawNearBadge"
		near.size_flags_horizontal = Control.SIZE_SHRINK_END
		near.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var near_box := StyleBoxFlat.new()
		near_box.bg_color = Color("e03131")
		near_box.set_corner_radius_all(8)
		near_box.set_content_margin_all(3)
		near_box.content_margin_left = 6
		near_box.content_margin_right = 6
		near.add_theme_stylebox_override("normal", near_box)
		near.add_theme_color_override("font_outline_color", Color("5c0a0a"))
		near.add_theme_constant_override("outline_size", 3)
		near.mouse_filter = Control.MOUSE_FILTER_IGNORE
		near.visible = false
		slot_panel.add_child(near)
		_law_near.append(near)
		_law_near_tweens.append(null)
		# 내 달성도 [ 4 / 6 킬 ]: 슬롯 오른쪽에 큼직하게
		var progress := _make_label("", MobileSupport.text_px(15), Color("fff3bf"))
		progress.name = "LawProgress"
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		progress.custom_minimum_size = Vector2(86, 30)
		progress.size_flags_vertical = Control.SIZE_SHRINK_END  # 위쪽 모서리는 [달성 임박!] 배지 자리
		var progress_box := StyleBoxFlat.new()
		progress_box.bg_color = Color("2b3a55")
		progress_box.set_corner_radius_all(10)
		progress_box.set_content_margin_all(4)
		progress.add_theme_stylebox_override("normal", progress_box)
		progress.add_theme_color_override("font_outline_color", Color("101626"))
		progress.add_theme_constant_override("outline_size", 3)
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.visible = false
		inner.add_child(progress)
		_law_progress.append(progress)
		_law_badge_state.append(0)
		_bind_tip(slot_panel, _fill_law_tip.bind(_law_slots.size()))
		_law_slots.append(slot_panel)
		_law_labels.append(name_label)
		_law_descs.append(desc_label)
		_law_badges.append(badge)
		_law_badge_labels.append(badge_label)
		_law_dashes.append(dash)


## 우측 중앙 판정 도구 카드(고정 210x250 세로형): 상단에 48x48 심볼 + 도구 이름, 가운데에 전진 규칙 한두 줄만 크게.
func _build_tool_board() -> void:
	_tool_board = PanelContainer.new()
	_tool_board.position = Vector2(1144, 172)
	_tool_board.custom_minimum_size = Vector2(210, 0)
	_tool_board.size = Vector2(210, 140)
	_tool_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_board.add_theme_stylebox_override("panel", UiSkin.panel())
	add_child(_tool_board)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_board.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	_tool_icon = PanelContainer.new()
	_tool_icon.custom_minimum_size = Vector2(48, 48)
	_tool_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_tool_icon)
	_tool_icon_label = _make_label("", 26, Color("ffffff"))
	_tool_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tool_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_icon.add_child(_tool_icon_label)
	_tool_icon_art = AugmentArt.make_texture(null, 48.0)
	_tool_icon_art.visible = false
	_tool_icon.add_child(_tool_icon_art)
	_tool_title = _make_label("", 17, COLOR_GOLD)
	_tool_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tool_title.custom_minimum_size = Vector2(120, 48)
	head.add_child(_tool_title)
	var center := VBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(center)
	_tool_main = _make_label("", MobileSupport.text_px(14), UiSkin.INK)
	_tool_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_main.custom_minimum_size = Vector2(184, 0)
	center.add_child(_tool_main)
	_tool_sub = _make_label("", MobileSupport.text_px(12), UiSkin.GREEN)
	_tool_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_sub.custom_minimum_size = Vector2(184, 0)
	center.add_child(_tool_sub)
	_tool_rules = VBoxContainer.new()
	_tool_rules.add_theme_constant_override("separation", 2)
	_tool_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_tool_rules)
	_tool_note = _make_label("", MobileSupport.text_px(12), UiSkin.SOFT)
	_tool_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_note.custom_minimum_size = Vector2(184, 0)
	center.add_child(_tool_note)
	_tool_toggle = _make_button("▼ 상세 족보", _on_tool_toggle_pressed, 12, Color("5da530"), 8)
	_tool_toggle.custom_minimum_size = Vector2(184, 26)
	_tool_toggle.focus_mode = Control.FOCUS_NONE
	box.add_child(_tool_toggle)


func _on_tool_toggle_pressed() -> void:
	_tool_expanded = not _tool_expanded
	_apply_tool_expand()
	_tool_board.reset_size()
	_place_action_row_below_tool_card()


## 판정 도구 카드는 화면 우측 중앙(세로 중심 384)을 기준으로 앉고, 펼치면 위아래로 늘어난다. 멈추기·패스 버튼 행은 카드 바로 아래에 붙는다.
func _place_action_row_below_tool_card() -> void:
	var height: float = maxf(_tool_board.size.y, _tool_board.get_combined_minimum_size().y)
	var top_y: float = TOOL_CARD_CENTER_Y - height / 2.0
	_set_layout_base(_tool_board, Vector2(1144, top_y))
	_set_layout_base(_action_row, Vector2(1134, top_y + height + 8.0))
	_apply_layout_now()


## 상세 족보(규칙표·메모)는 펼쳤을 때만 보이고, 족보가 없는 도구는 토글 버튼도 숨긴다.
func _apply_tool_expand() -> void:
	var has_rules: bool = _tool_rules.get_child_count() > 0
	_tool_toggle.visible = has_rules
	_tool_toggle.text = "▲ 접기" if _tool_expanded else "▼ 상세 족보"
	_tool_rules.visible = has_rules and _tool_expanded
	_tool_note.visible = has_rules and _tool_expanded and _tool_note.text != ""


## 보드 아래 한 줄 상태 띠: 단계 / 안내 문구 / 이동 대기열. (개입 카드 탭이 뜨면 그 자리를 양보한다.)
func _build_status_strip() -> void:
	_status_strip = HBoxContainer.new()
	_status_strip.position = Vector2(283, 590)
	_status_strip.size = Vector2(800, 24)
	_status_strip.add_theme_constant_override("separation", 10)
	_status_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_strip.visible = false  # 긴 안내문은 화면에서 걷어냈다 (문구는 내부에서만 갱신)
	add_child(_status_strip)
	_phase_label = _make_label("", MobileSupport.text_px(13), COLOR_GOLD)
	_status_strip.add_child(_phase_label)
	_hint_label = _make_label("", MobileSupport.text_px(12), Color("a5d8ff"))
	_hint_label.clip_text = true
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_strip.add_child(_hint_label)
	_queue_label = _make_label("", 11, Color("adb5bd"))
	_status_strip.add_child(_queue_label)
	_pick_banner = _make_label("", MobileSupport.text_px(13), Color("63e6be"))
	_pick_banner.position = Vector2(423, 74)
	_pick_banner.size = Vector2(400, 26)
	_pick_banner.clip_text = true
	_pick_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_banner.add_theme_stylebox_override("normal", _style(Color("0b3b33"), Color("63e6be"), 2, 8, 0, 3))
	_pick_banner.visible = false
	add_child(_pick_banner)
	_pick_cancel = _make_button(tr_ui("btn.cancel"), _on_pick_cancel_pressed, 12, Color("5c2b2b"), 8)
	_pick_cancel.position = Vector2(831, 58)
	_pick_cancel.size = Vector2(88, 30)
	_pick_cancel.visible = false
	_pick_cancel.z_index = 25
	add_child(_pick_cancel)
	# 상단에는 [메뉴] 버튼 하나만 둔다. 새 게임·모드·치트·전체 로그·설정·나가기는 메뉴 안에 있다 (_build_menu).
	_new_game_button = _make_button("새 게임", _new_game, 12, Color("3b4766"), 8)
	_menu_button = _make_button(tr_ui("btn.menu"), _toggle_menu, 13, Color("3b4766"), 8)
	_menu_button.position = Vector2(1270, 10)
	_menu_button.size = Vector2(84, 32)
	_menu_button.tooltip_text = tr_ui("btn.menu_tip")
	add_child(_menu_button)
	_feedback_button = _make_button(tr_ui("btn.feedback"), _open_feedback.bind("상단 버튼"), 13, Color("c2255c"), 8)
	_feedback_button.name = "FeedbackButton"
	# 소리·언어는 설정 화면으로 옮겼다. 피드백은 왼쪽 위 (오른쪽 위는 [메뉴] 하나)
	_feedback_button.position = Vector2(SAFE_MARGIN, 10)
	_feedback_button.size = Vector2(150, 32)
	_feedback_button.tooltip_text = tr_ui("btn.feedback_tip")
	add_child(_feedback_button)
	_speed_button = _make_button("", _on_speed_pressed, 13, Color("3b4766"), 8)
	_speed_button.name = "SpeedButton"
	_speed_button.position = Vector2(1180, 10)
	_speed_button.size = Vector2(84, 32)
	add_child(_speed_button)
	_refresh_speed_button()
	_language_button = LanguageToggle.create(13, Color.WHITE)
	_apply_button_style(_language_button, Color("3b4766"), 8)
	Sfx.bind_button(_language_button)
	_language_button.position = Vector2(1180 - 8 - 132, 10)
	_language_button.size = Vector2(132, 32)
	add_child(_language_button)
	if MobileSupport.touch_mode():
		_apply_touch_top_bar()


## 터치 기기: 위쪽 [피드백]·[배속]·[메뉴] 버튼을 손가락 크기로 키운다 (기준 84x32 -> 124x48, 프로필 패널 위 여백 안에서).
func _apply_touch_top_bar() -> void:
	var height: float = MobileSupport.TOUCH_BUTTON_HEIGHT
	var right: float = 1366.0 - SAFE_MARGIN + 4.0
	_menu_button.size = Vector2(124, height)
	_menu_button.position = Vector2(right - 124.0, 3)
	_speed_button.size = Vector2(124, height)
	_speed_button.position = Vector2(right - 124.0 * 2.0 - 8.0, 3)
	_language_button.size = Vector2(132, height)
	_language_button.position = Vector2(right - 124.0 * 2.0 - 8.0 - 132.0 - 8.0, 3)
	_feedback_button.size = Vector2(190, height)
	_feedback_button.position = Vector2(SAFE_MARGIN, 3)
	for button: Button in [_menu_button, _speed_button, _language_button, _feedback_button]:
		button.add_theme_font_size_override("font_size", 17)
		MobileSupport.touch_button(button, height)


## 우측 중앙의 큼직한 둥근 [굴리기] 버튼(모두의 마블 방식)과 그 아래의 멈추기·개입 패스·폭탄 떠넘기기 버튼.
func _build_action_bar() -> void:
	_roll_button = _make_button(tr_ui("btn.roll"), _on_roll_pressed, 24, Color("2b8a3e"), 60)
	_roll_button.position = Vector2(623, 320)
	_roll_button.size = Vector2(120, 120)
	_roll_button.custom_minimum_size = Vector2(120, 120)
	_apply_round_button_style(_roll_button, Color("2b8a3e"))
	_roll_button.tooltip_text = "꾹 눌러 파워 게이지를 채우고 손을 떼면 굴러갑니다 (R / Space 키도 동일)"
	add_child(_roll_button)
	# 룰렛(원판을 잡고 돌리기)과 러시안 룰렛(방아쇠 당기기)은 굴리기 버튼 대신 같은 자리의 직접 조작 패드를 쓴다.
	_roll_pad = RollPad.new()
	_roll_pad.position = Vector2(583, 250)  # 마름모 보드 한가운데 (패드 중심 = (683, 335)); 크게 보이도록 켤 때 1.9배로 키운다
	_roll_pad.spin_released.connect(_on_pad_spin_released)
	_roll_pad.trigger_pulled.connect(_on_pad_trigger_pulled)
	_roll_pad.preparation_finished.connect(_refresh_controls)
	add_child(_roll_pad)
	# 러시안 룰렛은 [발사]와 [정지] 두 버튼만 쓴다 (정지 버튼은 룰렛을 쓸 때만 이 줄로 옮겨 온다).
	_gun_row = HBoxContainer.new()
	_gun_row.position = Vector2(683.0 - 170.0, 470.0)
	_gun_row.size = Vector2(340, 60)
	_gun_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_gun_row.add_theme_constant_override("separation", 20)
	_gun_row.visible = false
	add_child(_gun_row)
	_fire_button = _make_button("발사", _on_pad_trigger_pulled, 24, Color("c92a2a"), 16)
	_fire_button.custom_minimum_size = Vector2(150, 58)
	_gun_row.add_child(_fire_button)
	var action_row := HFlowContainer.new()
	_action_row = action_row
	action_row.position = Vector2(1134, 440)
	action_row.size = Vector2(220, 30)
	action_row.alignment = FlowContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("h_separation", 6)
	action_row.add_theme_constant_override("v_separation", 4)
	add_child(action_row)
	_stop_button = _make_button("멈추고 이동 확정", _on_stop_pressed, 13, Color("37506b"), 12)
	_stop_button.custom_minimum_size = Vector2(150, 30)
	action_row.add_child(_stop_button)
	_skip_button = _make_button("개입 패스", _on_skip_pressed, 13, Color("7a4a14"), 12)
	_skip_button.custom_minimum_size = Vector2(100, 30)
	action_row.add_child(_skip_button)


## 둥근 큰 버튼 스타일 (일반/호버/눌림/비활성): 두꺼운 테두리와 그림자로 눌러 보고 싶게 만든다.
func _apply_round_button_style(button: Button, base: Color) -> void:
	var radius: int = int(button.size.x / 2.0)
	var normal: StyleBoxFlat = _style(base, Color("fff3bf"), 5, radius, 14, 4)
	var hover: StyleBoxFlat = _style(base.lightened(0.15), Color("ffffff"), 5, radius, 18, 4)
	var pressed: StyleBoxFlat = _style(base.darkened(0.2), COLOR_GOLD, 5, radius, 0, 4)
	var disabled: StyleBoxFlat = _style(base.darkened(0.55), base.darkened(0.2), 4, radius, 0, 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_disabled_color", Color("7b8499"))


## 하단 정중앙 TCG 스타일 카드 독. 카드는 _refresh_hands()가 채운다.
func _build_dock() -> void:
	_dock = Control.new()
	_dock.position = Vector2(250, 648)
	_dock.size = Vector2(860, 108)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock)


## 주사위/판정 결과를 보드 한가운데에 크게 띄우는 배너.
func _build_center_banner() -> void:
	_center_banner = PanelContainer.new()
	_center_banner.visible = false
	_center_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_banner.add_theme_stylebox_override("panel", _style(Color("101626"), COLOR_GOLD, 4, 20, 22, 18))
	add_child(_center_banner)
	_center_label = _make_label("", 30, Color("ffffff"))
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.add_theme_constant_override("outline_size", 6)
	_center_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_center_banner.add_child(_center_label)


## 메뉴에서 열리는 오버레이 서랍 두 개(치트/디버그, 전체 로그)와 그 열기 버튼.
func _build_drawers() -> void:
	# 열기 버튼은 메뉴 안에 놓인다 (_build_menu가 부모를 정한다).
	_debug_toggle = _make_button("치트 / 디버그", _on_debug_toggle_pressed, 13, Color("4a3a66"), 8)
	_log_toggle = _make_button("상세 로그 (개발용)", _on_log_toggle_pressed, 13, Color("2f4a66"), 8)

	var debug_drawer: Dictionary = _make_drawer("치트 / 디버그", _on_debug_toggle_pressed)
	_debug_box = debug_drawer["panel"]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(debug_drawer["body"] as VBoxContainer).add_child(scroll)
	var debug_content: VBoxContainer = _build_debug_panel()
	debug_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(debug_content)

	var log_drawer: Dictionary = _make_drawer("상세 로그 (개발용)", _on_log_toggle_pressed)
	_log_panel = log_drawer["panel"]
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 12)
	(log_drawer["body"] as VBoxContainer).add_child(_log)


## 우측에서 열리는 오버레이 서랍 틀. 기본은 숨김이다.
func _make_drawer(title: String, close_callback: Callable) -> Dictionary:
	var panel := PanelContainer.new()
	panel.position = Vector2(922, 44)
	panel.custom_minimum_size = Vector2(436, 716)
	panel.size = Vector2(436, 716)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _style(Color("131826"), COLOR_PANEL_EDGE, 3, 16, 24, 12))
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title_label := _make_label(title, 16, COLOR_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(_make_button("닫기", close_callback, 12, Color("5c2b2b"), 8))
	return {"panel": panel, "body": body}


func _build_debug_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var law_buttons := HFlowContainer.new()
	law_buttons.add_theme_constant_override("h_separation", 4)
	law_buttons.add_theme_constant_override("v_separation", 3)
	box.add_child(law_buttons)
	law_buttons.add_child(_make_label("교칙 추가(테스트):", 12, Color("868e96")))
	for law_id: String in LawRegistry.ALL_IDS:
		var sample: LawResource = LawRegistry.create(law_id)
		var law_button: Button = _make_button("%s %s" % [law_id.trim_prefix("LAW_"), sample.law_name], _on_add_law_pressed.bind(law_id), 11)
		law_button.tooltip_text = "[%s] %s\n%s\n(작동 시점: %s)" % [law_id, sample.law_name, sample.description, sample.trigger_timing]
		law_buttons.add_child(law_button)
	var debug_row := HFlowContainer.new()
	debug_row.add_theme_constant_override("h_separation", 6)
	debug_row.add_theme_constant_override("v_separation", 3)
	box.add_child(debug_row)
	debug_row.add_child(_make_label("현재 플레이어 판정 도구:", 12, Color("868e96")))
	_tool_option = OptionButton.new()
	_tool_option.custom_minimum_size = Vector2(190, 0)
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		_tool_option.add_item(ToolRegistry.create(tool_id).display_name)
	_tool_option.item_selected.connect(_on_tool_selected)
	debug_row.add_child(_tool_option)
	debug_row.add_child(_make_label("카드 지급:", 12, Color("868e96")))
	_card_option = OptionButton.new()
	_card_option.custom_minimum_size = Vector2(190, 0)
	for card_id: StringName in CardRegistry.all_ids():
		_card_option.add_item("%s %s" % [card_id, CardRegistry.get_card(card_id).display_name])
		_card_option.set_item_metadata(_card_option.item_count - 1, card_id)
	debug_row.add_child(_card_option)
	debug_row.add_child(_make_button("현재 플레이어에게", _on_grant_card_pressed, 12))
	debug_row.add_child(_make_button("도적 소환(%d번)" % BoardSpec.bakery_tiles[1], _on_spawn_npc_pressed.bind(GameEnums.NpcBehavior.CHASE_NEAREST, BoardSpec.bakery_tiles[1]), 12))
	debug_row.add_child(_make_button("와구와구 유령 소환(%d번)" % BoardSpec.halfway_tile, _on_spawn_npc_pressed.bind(GameEnums.NpcBehavior.PATROL_REVERSE, BoardSpec.halfway_tile), 12))
	_timer_check = CheckBox.new()
	_timer_check.text = "제한 시간 사용"
	_timer_check.toggled.connect(func(enabled: bool) -> void: manager.set_process(enabled))
	debug_row.add_child(_timer_check)
	return box


static func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	_restyle_label(label, text, font_size, color)
	return label


## 라벨의 글·크기·색을 바꾼다 (새 라벨과 풀에서 다시 쓰는 라벨이 같은 모습이 되게).
static func _restyle_label(label: Label, text: String, font_size: int, color: Color) -> void:
	font_size = FontSizes.snap(font_size)  # 표준 크기로 (글꼴이 크기마다 글리프를 굽는다)
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size <= SMALL_TEXT_MAX:
		label.add_theme_font_override("font", SMALL_FONT)  # 작은 글자는 ONE Mobile POP이 뭉개져 보여 또렷한 고딕으로
	else:
		label.remove_theme_font_override("font")


func _make_section(text: String) -> Label:
	return _make_label(text, 13, Color("74c0fc"))


## 화면 문구 (content_trickcal/data/ui_strings.csv). 지금 언어의 번역이 없으면 한국어로 돌아간다 (L10n).
static func tr_ui(key: String, args: Array = []) -> String:
	return L10n.tr_ui(key, args)


func _phase_name(phase: int) -> String:
	return tr_ui(PHASE_KEYS[phase]) if PHASE_KEYS.has(phase) else ""


func _make_button(text: String, callback: Callable, font_size: int, base_color: Color = Color("3b4766"), radius: int = 8) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	_apply_button_style(button, base_color, radius)
	Sfx.bind_button(button)
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


## 둥근 모서리·테두리가 있는 게임풍 버튼 스타일 (일반/호버/눌림/비활성).
func _apply_button_style(button: Button, base_color: Color, _radius: int) -> void:
	var is_action: bool = base_color.g > base_color.r * 1.2 and base_color.g > base_color.b
	UiSkin.button(button, is_action)


## 둥근 모서리·테두리·그림자가 있는 패널 스타일.
static func _style(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 10, shadow: int = 0, margin: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	if shadow > 0:
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.shadow_size = shadow
		box.shadow_offset = Vector2(0, 3)
	return box


## 개발용 실행 인자 --debug 가 있는가 (웹 주소 ?debug=1 은 더 이상 받지 않는다: 테스터가 쉽게 켜지 않게).
static func debug_requested() -> bool:
	return OS.get_cmdline_user_args().has("--debug")


## 치트를 켜고 끄는 비밀 입력: 게임 메뉴를 연 채로 ↑↑↓↓←→←→BA (키 사이 1.5초 안).
const CHEAT_SEQUENCE: Array[int] = [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A]
const CHEAT_KEY_GAP_MSEC: int = 1500


## 메뉴가 열려 있을 때만 키를 모아 비밀 입력이 끝까지 맞으면 치트를 켜고 끈다. 마지막 키를 먹었으면 true.
func _track_cheat_sequence(event: InputEvent) -> bool:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	if not _menu_is_open() or net != null:
		_cheat_keys.clear()
		return false
	var now: int = Time.get_ticks_msec()
	if now - _cheat_key_msec > CHEAT_KEY_GAP_MSEC:
		_cheat_keys.clear()
	_cheat_key_msec = now
	_cheat_keys.append(int(key_event.keycode))
	if _cheat_keys.size() > CHEAT_SEQUENCE.size():
		_cheat_keys = _cheat_keys.slice(_cheat_keys.size() - CHEAT_SEQUENCE.size())
	if _cheat_keys != CHEAT_SEQUENCE:
		return false
	_cheat_keys.clear()
	toggle_debug_access()
	return true


## 비밀 입력이 끝나면 치트/디버그 메뉴 항목을 켜고 끈다 (온라인 대전에서는 쓸 수 없다). 켜면 디버그 서랍도 바로 연다.
func toggle_debug_access() -> void:
	if net != null:
		return
	_debug_enabled = not _debug_enabled
	_debug_toggle.visible = _debug_enabled
	_debug_box.visible = _debug_enabled
	if _debug_enabled:
		_log_panel.visible = false
		_show_top_toast("치트/디버그 켜짐 (메뉴에서도 열 수 있어요)")
	else:
		_show_top_toast("치트/디버그 꺼짐")


func _on_debug_toggle_pressed() -> void:
	_log_panel.visible = false
	_debug_box.visible = not _debug_box.visible


func _on_log_toggle_pressed() -> void:
	_debug_box.visible = false
	_log_panel.visible = not _log_panel.visible


# ---------------------------------------------------------------------------
# 보드 / 말 그리기
# ---------------------------------------------------------------------------

## 타일 번호 -> 0~1 정규화 좌표 (BoardLayout과 같은 좌표계: 우하단 0번에서 반시계로 한 변 BoardSpec.side칸).
static func tile_norm(index: int) -> Vector2:
	return BoardLayout.tile_norm(index)


## 평면 정규화 좌표(0~1) -> 화면 좌표. 탑뷰는 그대로 펴고, 기울인 시점은 세로를 누르고 위쪽(먼 쪽)을 좁혀 원근을 준다. 규칙·좌표는 평면 그대로이고 이 함수만 시점을 안다.
func _project(norm: Vector2) -> Vector2:
	return _surface_project(BoardSkin.track(norm))


## Artwork, tile footprints and pawn trajectories use one shared plane.
## 평면 좌표(0~1)를 45도 돌려 마름모로 세운다 (두 시점 모두 같은 마름모, 시점은 보드 면·그림자·말 높이만 다르다).
func _surface_project(norm: Vector2) -> Vector2:
	var center: Vector2 = BOARD_ORIGIN + Vector2(BOARD_SIZE, BOARD_SIZE) / 2.0
	var offset: Vector2 = norm - Vector2(0.5, 0.5)
	var rotated := Vector2((offset.x - offset.y) * 0.70710678, (offset.x + offset.y) * 0.70710678)
	return (center + Vector2(rotated.x * DIAMOND_KX, rotated.y * DIAMOND_KY)).lerp(center+offset*500.0,_alkkagi_camera)


## 마름모에는 원근 크기 차이가 없다.
func _depth_scale(_norm_y: float) -> float:
	return 1.0


func _tile_center(index: int) -> Vector2:
	return _project(tile_norm(index))


## 점프 코너의 화살표가 가리킬 타일. LAW_01 중에는 점프가 막혀 바로 다음 칸을 가리킨다.
func _jump_arrow_target(index: int) -> int:
	if not BoardSpec.jump_corner_targets.has(index):
		return -1
	if state != null and state.rulebook.has_law("LAW_01"):
		return index + 1
	return BoardSpec.jump_corner_targets[index]


## 타일 하나를 현재 시점에 맞게 놓는다 (위치·원근 크기·세로 압축, 글자는 되돌려 찌그러지지 않게).
func _place_tile(index: int) -> void:
	var tile: BoardSkin.Tile = _tile_views[index]
	var span: float = BOARD_SIZE
	# 회전한 직사각형 발판의 바깥 사각형 크기 (가로·세로 변 합 x 0.707 x 마름모 배율)
	var footprint: Vector2 = tile.data.footprint as Vector2
	tile.size = Vector2(DIAMOND_KX, DIAMOND_KY) * (footprint.x + footprint.y) * 0.70710678 + Vector2.ONE * 8.0
	tile.pivot_offset = tile.size / 2.0
	tile.position = _tile_center(index) - tile.size / 2.0
	var depth: float = 1.0
	var squash: float = 1.0
	tile.scale = Vector2.ONE
	var target: int = _jump_arrow_target(index)
	tile.arrow_target = target
	var direction: Vector2 = (tile_norm(target) - tile_norm(index)).normalized() if target >= 0 else BoardSkin.forward_world(index)
	tile.configure(_surface_project, BoardSkin.track(tile_norm(index)), span, _depth_scale(BoardSkin.track(tile_norm(index)).y), direction)
	tile.set_dash(BoardSpec.dash_tiles.has(index), _tile_center((index + 1) % BoardSpec.tile_count) - _tile_center(index))
	for child: Control in [_highlights.get(index), _pick_marks.get(index)]:
		if child != null:
			child.size = tile.size
	for label: Label in [_tag_labels.get(index), _tile_marks.get(index)]:
		if label != null:
			label.pivot_offset = label.size / 2.0
			label.scale = Vector2(1.0, 1.0 / squash)


## 시점을 바꾼다 (게임 설정에서 언제든). 타일·선·보드 면·말·받침을 다시 놓는다.
func set_view_mode(mode: int) -> void:
	if mode == view_mode and not _track_lines.is_empty():
		return
	view_mode = mode
	GameSession.view_mode = mode
	_apply_view_mode()


func _apply_view_mode(refresh_pawns: bool = true) -> void:
	if _presenter != null:
		_presenter.toss_board_outline = BoardSkin.outline(_surface_project, _off_center)
	_layout_card_deck()
	var tilt: bool = true  # 마름모 보드는 항상 보드 면 메시로 그린다 (평면 받침 판은 쓰지 않는다)
	if _plate != null:
		_plate.visible = false
	if _board_surface != null:
		BoardSkin.update_surface(_board_surface, _surface_project)
		BoardSkin.update_surface(_flat_board_surface, _surface_project)
		var corners: PackedVector2Array = BoardSkin.outline(_surface_project)
		_board_surface.visible = tilt
		_board_edge.points = corners
		_board_edge.visible = tilt
		var shadow_points := PackedVector2Array()
		for point: Vector2 in corners:
			shadow_points.append(point + Vector2(0, 10))
		_board_shadow.polygon = shadow_points
		_board_shadow.visible = tilt
	if _drop_zone != null:
		var bounds: Rect2 = _board_rect()
		_drop_zone.position = bounds.position
		_drop_zone.size = bounds.size
	if _pawn_layer != null:
		_pawn_layer.y_sort_enabled = view_mode == ViewMode.TILT
	if _tile_views.is_empty():
		return
	for index: int in BoardSpec.tile_count:
		_place_tile(index)
	for line: Line2D in _track_lines:
		line.queue_free()
	_track_lines.clear()
	_add_track_lines()
	if state != null and refresh_pawns:
		_refresh_pawns()


func _build_tiles_once() -> void:
	if not _tile_views.is_empty():
		return
	_add_track_lines()
	for index: int in BoardSpec.tile_count:
		var node: TileNode = state.board.get_tile(index)
		var tile := BoardSkin.Tile.new()
		tile.initialize(index)
		tile.gui_input.connect(_on_tile_gui_input.bind(index))
		_board_layer.add_child(tile)
		_tile_views[index] = tile

		var light: bool = _is_light_tile(index, node.tile_type)
		# 타일 안 요소 배치(번호 글자는 없앴다): 설명=하단 중앙, 설치물 배지=우상단, 말=정중앙.
		var text_color: Color = Color("212529") if light else Color("f8f9fa")
		var tag: String = _tile_tag(index, node.tile_type)
		var tag_label := _make_label(tag, 10, text_color)
		tag_label.visible = false # Names are provided by tooltips; the pad uses a simple mark.
		tag_label.name = "Tag"
		tag_label.position = Vector2(0, TILE_SIZE - 15)
		tag_label.size = Vector2(TILE_SIZE, 14)
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tag_label)
		_tag_labels[index] = tag_label
		var mark := _make_label("", 10, Color("ff6b6b"))
		mark.position = Vector2(TILE_SIZE - 4, 0)
		mark.add_theme_constant_override("outline_size", 4)
		mark.add_theme_color_override("font_outline_color", Color("111418"))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(mark)
		_tile_marks[index] = mark
		var highlight := BoardSkin.Ring.new()
		highlight.border_color = Color("ffe066")
		highlight.border_width = 3.0
		highlight.editor_only = false
		highlight.size = tile.size
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(highlight)
		_highlights[index] = highlight
		var pick_mark := BoardSkin.Ring.new()
		pick_mark.border_color = Color("63e6be")
		pick_mark.border_width = 4.0
		pick_mark.editor_only = false
		pick_mark.size = tile.size
		pick_mark.visible = false
		pick_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(pick_mark)
		_pick_marks[index] = pick_mark
		_place_tile(index)


func _add_track_lines() -> void:
	var loop: Array[int] = []
	for index: int in BoardSpec.tile_count:
		loop.append(index)
	loop.append(0)
	_add_track_line(loop)


func _add_track_line(route: Array[int]) -> void:
	var line := Line2D.new()
	line.width = 3.6
	line.default_color = Color("b7ce87")
	line.antialiased = true
	for tile_index: int in route:
		line.add_point(_tile_center(tile_index))
	var inset := Line2D.new()
	inset.points = line.points
	inset.width = 1.1
	inset.default_color = Color("91ad61")
	inset.antialiased = true
	line.add_child(inset)
	_board_layer.add_child(line)
	# 선은 보드 면 바로 위, 타일 아래에 그린다.
	_board_layer.move_child(line, 3 + _track_lines.size())
	_track_lines.append(line)


func _is_light_tile(_index: int, tile_type: TileNode.TileType) -> bool:
	return tile_type == TileNode.TileType.NORMAL


func _tile_color(index: int, tile_type: TileNode.TileType) -> Color:
	match tile_type:
		TileNode.TileType.START_GOAL: return Color("2f9e44")
		TileNode.TileType.BAKERY: return Color("e8890c")
		TileNode.TileType.PORTAL: return Color("9c36b5")
	if BoardSpec.corner_tiles.has(index):
		return Color("495057")
	return Color("ced4da")


func _tile_tag(index: int, tile_type: TileNode.TileType) -> String:
	var base: String = _tile_tag_base(index, tile_type)
	if BoardSpec.dash_tiles.has(index):
		var dash: String = "부스터 발판 (멈추면 +%d칸)" % GameData.dash_steps()
		return dash if base.is_empty() else "%s · %s" % [base, dash]
	return base


func _tile_tag_base(index: int, tile_type: TileNode.TileType) -> String:
	match tile_type:
		TileNode.TileType.START_GOAL: return "▲출발"
		TileNode.TileType.BAKERY: return "빵집"
		TileNode.TileType.PORTAL: return "옷장"
	if BoardSpec.jump_corner_targets.has(index):
		return "점프 코너 → %d번" % int(BoardSpec.jump_corner_targets[index])
	if index == BoardSpec.halfway_tile:
		return "반환점"
	return ""


func _build_pawn_views() -> void:
	for pawn: PlayerPawn in state.pawns:
		var view := Node2D.new()
		var shadow := Polygon2D.new()
		shadow.name = "Shadow"
		shadow.polygon = _circle_points(16.0, 24)
		shadow.scale = Vector2(1.0, 0.36)
		shadow.position = Vector2(0, 5)
		shadow.color = Color(0, 0, 0, 0.28)
		view.add_child(shadow)
		var bounce := Node2D.new()
		bounce.name = "Bounce"
		view.add_child(bounce)
		var token := PawnToken.new()
		token.name = "Token"
		token.ground_shadow = false
		token.shield_motion = _fx_on()
		token.configure(pawn, PLAYER_COLORS[pawn.owner_id])
		bounce.add_child(token)
		var badge := _make_label("", 9, Color.WHITE)
		badge.name = "Badge"
		badge.position = Vector2(-16, 11)
		badge.add_theme_constant_override("outline_size", 4)
		badge.add_theme_color_override("font_outline_color", Color("111418"))
		bounce.add_child(badge)
		view.position = _pawn_position(pawn)
		_pawn_layer.add_child(view)
		_pawn_views[pawn.entity_id] = view


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in count:
		var angle: float = TAU * i / count
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _pawn_position(pawn: PlayerPawn) -> Vector2:
	if pawn.is_finished:
		return _pawn_position_at(pawn, GameEnums.GOAL_TILE)
	return _pawn_position_at(pawn, pawn.current_tile_idx)


## 말이 지정한 타일에 섰을 때의 화면 좌표.
func _pawn_position_at(pawn: PlayerPawn, tile: int) -> Vector2:
	var owner_index: int = PLAYER_IDS.find(pawn.owner_id)
	var micro := Vector2(((pawn.slot - 1) % 2) * 5.0 - 2.5, ((pawn.slot - 1) / 2) * 5.0 - 2.5)
	var position_in_tile: Vector2 = _tile_center(tile) + (CELL_OFFSETS[owner_index] + micro) * _depth_scale(tile_norm(tile).y)
	if pawn.is_finished:
		position_in_tile = _tile_center(GameEnums.GOAL_TILE) + Vector2(-22 + owner_index * 14 + (pawn.slot - 1) * 3.0, 38)
	return position_in_tile


## Shield events update the token in place, so a shield never survives on a stale sprite.
func _refresh_pawn_protection(pawn_id: int, blocked: bool = false) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	var view: Node2D = _pawn_views.get(pawn_id)
	if pawn == null or view == null:
		return
	var token := view.get_node("Bounce/Token") as PawnToken
	token.configure(pawn, PLAYER_COLORS[pawn.owner_id])
	if blocked:
		token.shield_hit()


func _refresh_pawns() -> void:
	# 사도 포위망이 법전에 있으면 내 말 중 지금 포위망에 세어지는 말에 [포위망] 표시
	var spread_ids: Array[int] = []
	var viewer: int = _law_view_player()
	if viewer != -1 and state.rulebook.has_law("LAW_05"):
		spread_ids = VictoryLaw.spread_pawn_ids(state, viewer)
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null:
			continue
		_settle_pawn_view(view, pawn)
		(view.get_node("Bounce/Token") as PawnToken).configure(pawn, PLAYER_COLORS[pawn.owner_id])
		var badge_text: String = ""
		if pawn.restrained_turns > 0 or pawn.blocked_this_turn:
			badge_text += " 구속"
		if pawn.is_imprisoned:
			badge_text += " 감옥"
		if state.bonds.has(pawn.entity_id):
			badge_text += " 연대"  # 강제 연대책임: 일심동체로 묶인 말
		if spread_ids.has(pawn.entity_id):
			badge_text += " 포위망"  # 사도 포위망에 세어지는 말
		(view.get_node("Bounce/Badge") as Label).text = badge_text
	for npc: NeutralNPC in state.npcs:
		if not _npc_views.has(npc.entity_id):
			var marker := PawnToken.new()
			marker.configure_npc(npc.behavior)
			_pawn_layer.add_child(marker)
			_npc_views[npc.entity_id] = marker
		var npc_view: Node2D = _npc_views[npc.entity_id]
		if npc_view.has_meta("npc_run"):
			continue  # 달리는 연출이 끝나면 도착 칸에 다시 보인다
		var npc_target: Vector2 = _tile_center(npc.current_tile_idx)
		npc_view.scale = Vector2.ONE * _depth_scale(tile_norm(npc.current_tile_idx).y)
		if _fx_on() and npc_view.position.distance_to(npc_target) > 3.0 and npc_view.position != Vector2.ZERO:
			if not _fx_holding():
				_glide_node(npc_view, npc_target, 0.35)
		elif not npc_view.has_meta("fx") or not _fx_node_running(npc_view):
			npc_view.position = npc_target
	for npc_id: int in _npc_views.keys():
		if state.get_npc(npc_id) == null:
			(_npc_views[npc_id] as Node).queue_free()
			_npc_views.erase(npc_id)


func _refresh_tiles() -> void:
	if _tile_marks.is_empty():
		return
	for index: int in BoardSpec.tile_count:
		if _train_trap_hold.has(index):
			continue
		var parts: Array[String] = []
		if BoardSpec.jump_corner_targets.has(index):
			if (_tile_views[index] as BoardSkin.Tile).arrow_target != _jump_arrow_target(index):
				_place_tile(index)
		var tips: Array[String] = []
		var kind_label: String = _tile_tag(index, state.board.get_tile(index).tile_type)
		if not kind_label.is_empty():
			tips.append(kind_label)
		var color: Color = Color("ff6b6b")
		var has_trap: bool = false
		var trap_icon: Texture2D = null
		for attachment: TileAttachment in state.board.get_tile(index).attachments:
			if _structure_kind(attachment) != &"":
				tips.append("지뢰 (P%d) - 밟으면 폭발" % attachment.owner_id)  # 필살기로 묻은 공개 지뢰는 지뢰 모형으로 보인다
				continue
			if attachment.attachment_id.begins_with("TRP"):
				has_trap = true
				trap_icon = _trap_icon(attachment)
				tips.append(_trap_tooltip(attachment))
			elif attachment.attachment_id == "HOTEL":
				tips.append("호텔 (P%d) - 다른 플레이어가 멈추면 통행료" % attachment.owner_id)  # 칸 위 글자 대신 호텔 건물 모형이 선다 (_refresh_structures)
		var in_goal: bool = TempoUp.in_zone_for(state, index)
		(_tile_views[index] as BoardSkin.Tile).set_goal(in_goal)
		if in_goal:
			tips.append("당겨진 결승선 (템포 업): 여기 들어서면 완주")
		var shown_trap: bool = has_trap and not _trap_pending.has(index)
		(_tile_views[index] as BoardSkin.Tile).set_trap(shown_trap, trap_icon)
		if shown_trap and not _trap_tiles.has(index):
			_trap_tiles.append(index)
		elif not shown_trap:
			_trap_tiles.erase(index)
		(_tile_views[index] as Control).tooltip_text = "\n".join(tips)
		var mark: Label = _tile_marks[index]
		mark.text = " ".join(parts)
		mark.position = Vector2((_tile_views[index] as Control).size.x - 2 - mark.get_minimum_size().x, 0)
		mark.add_theme_color_override("font_color", color)
	_refresh_structures()


## 중립 NPC가 라운드 끝에 덮칠 길을 붉은 테두리·삼각 경고·진행 화살표로 예고한다. 위험 계산은 NeutralNPC.danger_preview가 맡는다.
func _refresh_npc_danger() -> void:
	_npc_danger.clear()
	if state != null and not manager.is_game_over:
		for npc: NeutralNPC in state.npcs:
			var preview: Dictionary = npc.danger_preview(state)
			var tiles: Array = preview["tiles"]
			var catch_tiles: Array = preview["catch_tiles"]
			for i: int in tiles.size():
				var tile: int = int(tiles[i])
				var from_tile: int = int(tiles[i - 1]) if i > 0 else npc.current_tile_idx
				var next_tile: int = int(tiles[i + 1]) if i + 1 < tiles.size() else -1
				# 화살표: 다음 타일이 있으면 그쪽, 마지막 타일이면 NPC가 계속 가는 방향
				var heading: Vector2 = (_tile_center(next_tile) - _tile_center(tile)) if next_tile != -1 else (_tile_center(tile) - _tile_center(from_tile))
				var level: int = 2 if catch_tiles.has(tile) else 1
				var existing: Dictionary = _npc_danger.get(tile, {})
				if int(existing.get("level", 0)) < level:
					_npc_danger[tile] = {"level": level, "dir": heading}
			if tiles.is_empty() and not catch_tiles.is_empty():
				_npc_danger[int(catch_tiles[0])] = {"level": 2, "dir": Vector2.ZERO}
	for index: int in _tile_views.keys():
		var entry: Dictionary = _npc_danger.get(index, {})
		(_tile_views[index] as BoardSkin.Tile).set_danger(int(entry.get("level", 0)), entry.get("dir", Vector2.ZERO))
	_refresh_danger_label()


func _update_danger_pulse(delta: float) -> void:
	_update_dash_pulse()
	if _npc_danger.is_empty():
		return
	_danger_clock += delta
	var pulse: float = 0.5 + 0.5 * sin(_danger_clock * 6.0)
	for index: int in _npc_danger.keys():
		var tile: BoardSkin.Tile = _tile_views.get(index)
		if tile != null:
			tile.set_danger_pulse(pulse)
	if _danger_label != null and _danger_label.visible:
		_danger_label.modulate.a = 0.75 + 0.25 * pulse


## 부스터 발판 화살표를 흘려 보낸다.
func _update_dash_pulse() -> void:
	var phase: float = fmod(float(Time.get_ticks_msec()) / 900.0, 1.0)
	for index: int in BoardSpec.dash_tiles:
		var tile: BoardSkin.Tile = _tile_views.get(index)
		if tile != null:
			tile.set_dash_phase(phase)


## 내 말이 위험 타일에 서 있거나 이동 미리보기가 위험 타일에 닿으면 경고 문구를 띄운다.
func _danger_warning_needed() -> bool:
	if _npc_danger.is_empty() or state == null:
		return false
	# 이동 미리보기: 기물이 덮칠 칸이거나, 그 앞길(내가 서면 가장 가까운 적이 된다)이면 위험. 내가 소환한 기물은 내 말을 덮치지 않는다.
	if _hover_danger_tile != -1 and int((_npc_danger.get(_hover_danger_tile, {}) as Dictionary).get("level", 0)) >= 1:
		for npc: NeutralNPC in state.npcs:
			if npc.owner_id != _dock_owner():
				return true
	for pawn: PlayerPawn in state.pawns_of(_dock_owner()):
		if pawn.is_finished or not pawn.has_left_start or pawn.carrier != null:
			continue
		if int((_npc_danger.get(pawn.current_tile_idx, {}) as Dictionary).get("level", 0)) >= 2:
			return true
	return false


func _refresh_danger_label() -> void:
	if _danger_label == null:
		return
	_danger_label.visible = _danger_warning_needed() and not manager.is_game_over
	_danger_label.modulate.a = 1.0


## 칸 위 건축물: 필살기로 지은 호텔·공개 지뢰는 부루마블 건물처럼 칸 위에 모형으로 선다 (지어질 때 솟아오른다).
var _structure_views: Dictionary = {}


## 이 설치물을 칸 위 모형으로 보여 줄지: 호텔, 그리고 필살기로 묻은 공개 지뢰(카드로 깐 지뢰는 숨은 함정이라 모형으로 보이지 않는다).
static func _structure_kind(attachment: TileAttachment) -> StringName:
	if attachment.attachment_id == "HOTEL":
		return &"hotel"
	if attachment.attachment_id == "TRP_03" and not attachment.is_hidden_trap:
		return &"mine"
	return &""


func _refresh_structures() -> void:
	if _pawn_layer == null or state == null:
		return
	var wanted: Dictionary = {}
	for index: int in BoardSpec.tile_count:
		for attachment: TileAttachment in state.board.get_tile(index).attachments:
			var kind: StringName = _structure_kind(attachment)
			if kind != &"":
				wanted[index] = {"kind": kind, "owner": attachment.owner_id}
				break
	for index: int in _structure_views.keys():
		var entry: Dictionary = _structure_views[index]
		var want: Dictionary = wanted.get(index, {})
		if want.is_empty() or want["kind"] != entry["kind"] or want["owner"] != entry["owner"] or not is_instance_valid(entry["node"]):
			var old: Node = entry["node"]
			if is_instance_valid(old):
				old.queue_free()
			_structure_views.erase(index)
	for index: int in wanted.keys():
		var model: BoardStructure
		if _structure_views.has(index):
			model = _structure_views[index]["node"]
		else:
			model = BoardStructure.new()
			model.name = "Structure_%d" % index
			model.kind = wanted[index]["kind"]
			model.color = PLAYER_COLORS.get(int(wanted[index]["owner"]), Color("ffd43b"))
			_pawn_layer.add_child(model)
			_pawn_layer.move_child(model, 0)  # 말 그림보다 먼저 그려 말이 건물 앞에 선다 (z를 낮추면 보드 칸 밑으로 숨는다)
			_structure_views[index] = {"kind": model.kind, "owner": wanted[index]["owner"], "node": model}
			if _fx_on():
				Sfx.play(&"build_hotel" if model.kind == &"hotel" else &"build_mine", -2.0)
				# 땅에서 솟아오르듯 세워진다
				model.scale = Vector2(1.0, 0.05)
				model.create_tween().tween_property(model, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		model.position = _tile_center(index) + Vector2(0, -4) * _depth_scale(tile_norm(index).y)


## 함정이 깔린 발판의 보라색 깜빡임.
func _update_trap_pulse(delta: float) -> void:
	if _trap_tiles.is_empty():
		return
	_trap_clock += delta
	var pulse: float = 0.5 + 0.5 * sin(_trap_clock * 5.0)
	for index: int in _trap_tiles:
		var tile: BoardSkin.Tile = _tile_views.get(index)
		if tile != null:
			tile.set_trap_pulse(pulse)


## 함정 툴팁. 함정 공개 규칙(MatchRules.trap_reveal: 싱글 Lv.1~3 기본)이면 누구 함정이든 정체가 보인다.
## 비공개 규칙(Lv.4~5 기본·방 설정 [심리전])이면 AI 대전·온라인에서 내가 깐 함정만 보이고, 남이 깐 함정은 [? 수상한 함정]이다.
func _trap_tooltip(attachment: TileAttachment) -> String:
	if not attachment.is_hidden_trap or attachment.always_revealed or (_trap_known(attachment) and attachment.owner_id != local_player_id):
		return "[함정] %s (설치: %s)" % [_attachment_name(attachment.attachment_id), _player_name(attachment.owner_id)]  # 코너 함정·공개 규칙
	if _trap_known(attachment):
		return "[내 함정] %s" % _attachment_name(attachment.attachment_id)
	return "[? 수상한 함정] (설치: %s)" % _player_name(attachment.owner_id) if ai_mode or net != null else "[? 수상한 함정]"


## 이 화면이 함정의 정체를 알아도 되는가: 공개 함정이거나, 함정 공개 규칙이거나, 혼자 보는 화면(AI 대전·온라인)에서 내가 깐 함정.
func _trap_known(attachment: TileAttachment) -> bool:
	if not attachment.is_hidden_trap or attachment.always_revealed or MatchRules.trap_reveal(state):
		return true
	return (ai_mode or net != null) and attachment.owner_id == local_player_id


## 함정 타일에 붙일 그림: 정체를 모르는 함정은 물음표.
func _trap_icon(attachment: TileAttachment) -> Texture2D:
	var key: String = attachment.attachment_id if _trap_known(attachment) else "HIDDEN"
	var icon: Texture2D = TextureCache.fetch("res://assets/board/traps/%s.png" % key)
	return icon if icon != null else TextureCache.fetch("res://assets/board/traps/HIDDEN.png")


func _on_pawn_stepped(pawn_id: int, _from_tile: int, _to_tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if view == null or pawn == null:
		return
	# Deployment changes on the first step, before the next phase refresh.
	# Update only this owner's slots, without restarting turn-light tweens.
	_refresh_pawn_slots(pawn.owner_id)
	view.visible = pawn.carrier == null and not pawn.is_finished
	if not _fx_on():
		if view.has_meta("fx"):
			_kill_fx(view)
		var quick: Tween = create_tween()
		quick.tween_property(view, "position", _pawn_position(pawn), maxf(STEP_DELAY * _pace() * 0.85, 0.05))
		quick.parallel().tween_property(view, "scale", Vector2.ONE * _depth_scale(tile_norm(pawn.current_tile_idx).y), maxf(STEP_DELAY * _pace() * 0.85, 0.05))
		view.set_meta("fx", quick)
		return
	if view.has_meta("fx_script") and _fx_running(view):
		return  # 필살기 연출이 이 말을 직접 움직이는 중
	var target_scale: float = _depth_scale(tile_norm(pawn.current_tile_idx).y)
	if _fx_skip_steps.has(pawn_id):
		return  # 필살기 스크립트(차 돌진 등)가 이 말을 직접 움직인다
	if _rocket_target.has(pawn_id):
		var rocket_tile: int = int(_rocket_target[pawn_id])
		if _to_tile != GameEnums.GOAL_TILE and _to_tile < rocket_tile:
			return  # 로켓 구간의 걸음: 한 칸씩 뛰지 않는다
		_rocket_target.erase(pawn_id)
		if _to_tile == rocket_tile:
			enqueue_step(_play_rocket.bind(pawn_id, _pawn_position(pawn), target_scale, rocket_tile), pawn_id)
			return
	# 한 칸씩 연출 큐에 세운다: 엔진이 여러 걸음(발판 가속·효과 전진)을 한꺼번에 방송해도 화면은 앞 걸음이 끝난 뒤에 다음 걸음을 뛴다.
	# 도착 정산 뒤의 추가 이동(점프 부스트·발판·8번 공 돌진)이면 도착 칸 처치 연출이 끝난 뒤에 뛴다 (이동 4단계).
	var hop: Callable = _play_hop.bind(pawn_id, _pawn_position(pawn), target_scale, pawn.current_tile_idx)
	if _follow_up_pawns.has(pawn_id):
		_enqueue_after_kills(hop, pawn_id)
	else:
		enqueue_step(hop, pawn_id)


## 큐의 한 단계: 말이 한 칸을 통통 뛰고 착지할 때까지 기다린다.
func _play_hop(pawn_id: int, to_pos: Vector2, to_scale: float, tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	if view == null or not is_instance_valid(view):
		return
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn != null:
		view.visible = pawn.carrier == null and not pawn.is_finished
	# 한 칸 점프 길이는 엔진의 이번 이동 칸당 시간과 같다 (장거리일수록 짧아져 이동 전체가 0.75초 안에 끝난다).
	var hop: float = manager.current_step_seconds if manager != null and manager.current_step_seconds > 0.0 else HOP_SECONDS
	if _move_chain_len >= TurnManager.LONG_MOVE_TILES:
		hop = minf(hop, TurnManager.LONG_MOVE_STEP_SECONDS)  # 장거리 이동: 큐에 이어진 걸음이 많으면 타다닥
	# 칸 시간 = 점프 + 착지 쉼: 점프는 칸 시간의 70%, 나머지는 제자리에서 멈춰 한 칸씩 끊어 보이게 한다
	var jump: float = minf(hop * (1.0 - HOP_REST_RATIO), HOP_SECONDS * minf(_pace(), 1.5))
	_glide(view, to_pos, to_scale, {"dur": jump, "arc": HOP_HEIGHT, "pace_cap": 1.0, "land_tile": tile})
	var generation: int = _fx_generation
	while generation == _fx_generation and is_instance_valid(view) and _fx_running(view):
		await get_tree().process_frame
	var rest: float = minf(hop * HOP_REST_RATIO, HOP_REST_MAX)
	if rest > 0.0 and generation == _fx_generation and _fx_on():
		await get_tree().create_timer(rest).timeout


## 점프 코너나 옷장 포탈에서 시작한 워프인가: 발판에 먼저 멈춰 발동 연출을 보여 준 뒤 날아가야 한다.
func _is_stage_warp(from_tile: int, to_tile: int) -> bool:
	return from_tile != to_tile and (BoardSpec.jump_corner_targets.has(from_tile) or BoardSpec.portal_tiles.has(from_tile))


## 2단계 분리 이동: (A) 말이 발판에 도착해 멈출 때까지 기다린다 -> (B) 발판이 빛나며 [발동] 배너 0.45초 -> (C) 높은 포물선으로 날아가거나(코너) 줄었다 커지며(포탈) 목적지에 착지 -> (D) 밀려 있던 잡기·함정 연출을 이어서 재생한다.
## 그동안 다른 말의 연출·알림·입력은 _fx_holding()으로 기다린다 (_stage_warps).
func _stage_warp(pawn_id: int, from_tile: int, to_tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if view == null or pawn == null:
		return
	var generation: int = _fx_generation
	_stage_warps += 1
	var corner: bool = BoardSpec.jump_corner_targets.has(from_tile)
	var pace: float = _motion_pace()
	# A) 발판에 닿을 때까지 (밀려 있던 걸음, 알림 카드, 점프 중인 말)
	while generation == _fx_generation and is_instance_valid(view) and (_fx_running(view) or (_announcer != null and _announcer.holding() and not _fx_gate_open)):
		await get_tree().process_frame
	if generation != _fx_generation or not is_instance_valid(view):
		return
	# B) 발판 발동 연출
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now((0.45 + 0.9) * pace * 1000.0 + 150))
	_tile_glow(from_tile)
	var pad: Vector2 = (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + _tile_center(from_tile)
	_impact_ring(pad, Color("ffe066") if corner else Color("99e9f2"), 52.0)
	_burst_shards(pad, Color("ffe066") if corner else Color("99e9f2"), 12)
	Sfx.play(&"launch" if corner else &"warp")
	await get_tree().create_timer(0.45 * pace).timeout
	if generation != _fx_generation or not is_instance_valid(view):
		return
	# C) 목적지로 비행(코너) / 워프(포탈)
	var target: Vector2 = _pawn_position(pawn)
	var target_scale: float = _depth_scale(tile_norm(pawn.current_tile_idx).y)
	if corner:
		_glide(view, target, target_scale, {"dur": 0.45, "arc": 130.0, "peak": 1.3, "pace_cap": pace, "land_tile": to_tile, "land_big": true})
	else:
		_kill_fx(view)
		view.z_index = 4
		view.set_meta("land_tile", to_tile)
		var warp: Tween = create_tween()
		warp.tween_property(view, "scale", Vector2.ONE * 0.05, 0.22 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		warp.parallel().tween_property(view, "modulate:a", 0.0, 0.22 * pace)
		warp.tween_callback(func() -> void: view.position = target)
		warp.tween_property(view, "scale", Vector2.ONE * target_scale, 0.23 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		warp.parallel().tween_property(view, "modulate:a", 1.0, 0.2 * pace)
		warp.tween_callback(_glide_done.bind(view))
		view.set_meta("fx", warp)
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(0.5 * pace * 1000.0 + 80))
	while generation == _fx_generation and is_instance_valid(view) and _fx_running(view):
		await get_tree().process_frame
	if generation != _fx_generation:
		return
	# D) 도착한 칸의 잡기·함정 연출 이어서
	_stage_warps = maxi(_stage_warps - 1, 0)
	if _stage_warps == 0:
		_fx_after_announcer()
		_refresh_pawns()
		_refresh_all()


## 타일 위에 잠깐 떠올랐다 사라지는 짧은 배너.
## 순간이동(옷장·비행기·탑 흩어짐 등): 높이 떠올라 포물선으로 날아가 내려앉는다.
func _on_pawn_warped(pawn_id: int, _from_tile: int, _to_tile: int) -> void:
	if _alkkagi_skip_primary_warp and _alkkagi_controlled.get(pawn_id,{}).get("shooter",false):
		_alkkagi_skip_primary_warp = false
		return
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if view == null or pawn == null:
		return
	view.visible = pawn.carrier == null and not pawn.is_finished
	if not _fx_on():
		_on_pawn_stepped(pawn_id, _from_tile, _to_tile)
		return
	if view.has_meta("fx_script") and _fx_running(view):
		return
	if _is_stage_warp(_from_tile, _to_tile):
		enqueue_step(_stage_warp.bind(pawn_id, _from_tile, _to_tile), pawn_id)
		return
	var opts: Dictionary = _take_hint(pawn_id)
	var merged: Dictionary = {"arc": 46.0, "peak": 1.35, "dur": 0.55}
	merged.merge(opts, true)
	enqueue_step(_play_warp_glide.bind(pawn_id, _pawn_position(pawn), _depth_scale(tile_norm(pawn.current_tile_idx).y), merged), pawn_id)


## 큐의 한 단계: 사출된 말을 최종 위치(출발선)로 보내는 연출(장외 홈런 등)을 재생하고 끝날 때까지 기다린다.
func _play_eject_settle(pawn_id: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if view == null or pawn == null or not is_instance_valid(view):
		return
	# The FIFO has already waited for the entire capture pose; do not wait twice.
	if _fx_hints.has(pawn_id):
		var hint: Dictionary = _fx_hints[pawn_id]
		if bool(hint.get("homerun", false)):
			hint["delay"] = 0.0
	_settle_pawn_view(view, pawn, true)
	var generation: int = _fx_generation
	while generation == _fx_generation and is_instance_valid(view) and _fx_running(view):
		await get_tree().process_frame


## 큐의 한 단계: 잡힌 말이 회전하며 장외로 날아가 출발선(0번)에 떨어지고, 주인들이 반응한다.
func _play_capture_eject(pawn_id: int, by_player: int, owner_id: int, cutin_capture: bool, impact_feedback: bool = true) -> void:
	if impact_feedback:
		_fx_impact_at_pawn(pawn_id, 0.0)
	# 처치·사출은 어떤 경우든(잡기·필살기·함정·카드) 보드 밖으로 날아가는 장외 홈런으로 보여 준다 (출발선으로 걸어 돌아가지 않는다).
	_set_hint(pawn_id, {"homerun": true, "arc": 110.0, "spin": 2.0 * TAU, "dur": 0.45, "land_thud": true})
	get_tree().create_timer(0.2 * _motion_pace()).timeout.connect(func() -> void:
		_profile_react(owner_id, false)
		if by_player != owner_id:
			_profile_react(by_player, true))
	await _play_eject_settle(pawn_id)
	var ejected: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if ejected != null and ejected.revenge_boost and not ejected.has_left_start:
		_revenge_charged_popup(ejected.owner_id, ejected)


## 리벤지 부스터 [획득]: 그 플레이어 모서리 프로필 위에 복수심 장전 문구를 띄운다.
func _revenge_charged_popup(player_id: int, pawn: PlayerPawn = null) -> void:
	if not _fx_on() or not _profiles.has(player_id):
		return
	var panel: Control = _profiles[player_id]["panel"]
	var at: Vector2 = get_global_transform().affine_inverse() * panel.get_global_rect().get_center()
	at.x = clampf(at.x, 60.0, size.x - 60.0)
	at.y = clampf(at.y, 60.0, size.y - 60.0)
	_number_pop(at, "+%d" % _revenge_steps(pawn), Color("ff922b"))
	Sfx.play(&"revenge_ignite")
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(120.0 * _motion_pace()))  # 배지는 혼자 떠오르므로 큐를 오래 붙잡지 않는다


## 리벤지 부스터 [발동] = 이동 4단계 중 1단계: 부스터 칸수만큼 로켓으로 먼저 날아가 잠깐 멈추고(경유지라 판정 없음), 2단계로 눈금만큼 한 칸씩 간다.
func _on_revenge_boost_fired(pawn_id: int, base_steps: int, bonus: int, total: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	var dice_part: int = maxi(total - bonus, 0)  # 눈금 + 기물 능력 (부스터 뒤에 이어 가는 본 이동)
	_log_line("[리벤지 부스터] %s +%d칸 선행 전진! 이어서 눈금 %d칸" % [_pawn_name(pawn_id), bonus, dice_part], Color("ff922b"))
	if pawn != null:
		_record(pawn.owner_id, "리벤지 부스터 +%d칸 선행 전진 → 이어서 눈금 %d칸 전진" % [bonus, dice_part])
	if not _fx_on() or pawn == null:
		return
	_rocket_target[pawn_id] = GameEnums.GOAL_TILE + bonus
	_rocket_followup[pawn_id] = dice_part
	enqueue_step(_play_revenge_launch.bind(pawn_id, base_steps, bonus, total), pawn_id)


## 큐의 한 단계: [리벤지 부스터 발동! 수식] 배너를 띄우고(발사음·화염 링) 0.15초 뒤 바로 출발한다.
## 배너는 혼자 떠 있다 사라진다 (예전: 기본 눈금 0.25초 + 수식 0.45초를 연출 속도 1.7배로 붙잡아 약 1.2초 멈췄다).
func _play_revenge_launch(pawn_id: int, base_steps: int, bonus: int, total: int) -> void:
	Sfx.play(&"rocket")
	screen_shake(6.0, 0.2)
	_show_center_banner("[리벤지 부스터] +%d칸 선행 전진!\n도착하면 이어서 눈금 %d칸" % [bonus, maxi(total - bonus, 0)], Color("ff922b"))
	var view: Node2D = _pawn_views.get(pawn_id)
	if view != null and _pawn_layer != null:
		_impact_ring(view.position, Color("ff6b00"), 58.0)
		_burst_shards(view.position, Color("ff922b"), 14)
	await get_tree().create_timer(REVENGE_LAUNCH_LEAD).timeout


## 점프 부스트 = 이동 4단계 중 4단계: 눈금 이동이 끝난 칸(경유지)의 처치 연출이 다 끝난 뒤, [점프 부스트 +N] 배지와 함께 잠깐 멈췄다가 추가 이동을 시작한다.
func _on_leapfrog_boosted(pawn_id: int, waypoint: int, bonus: int) -> void:
	_log_line("[점프 부스트] %s %d번 칸에서 +%d칸 추가 이동!" % [_pawn_name(pawn_id), waypoint, bonus], Color("ffd43b"))
	_follow_up_pawns[pawn_id] = true
	if not _fx_on():
		return
	_enqueue_after_kills(func() -> void:
		var view: Node2D = _pawn_views.get(pawn_id)
		if view == null or not is_instance_valid(view):
			return
		Sfx.play(&"dash")
		_floating_badge(view.position + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + Vector2(0, -40), "점프 부스트 +%d" % bonus, Color("ffd43b"), 34)
		await get_tree().create_timer(WAYPOINT_PAUSE).timeout, pawn_id)


## 초증강 아우토반 니트로: 선두 말이 리벤지 부스터처럼 화염을 뿜으며 코너(또는 길을 막은 말이 있는 칸)까지 한 번에 날아간다.
## 엔진은 움직이기 전에 방송하므로 지금 자리에서 출발하고, 한 칸씩 뛰는 걸음은 건너뛴다. 막은 칸의 말 사출은 그 뒤 처치 연출로 이어진다.
func _on_nitro_dashed(pawn_id: int, path: Array[int], blocked: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	_log_line("[아우토반 니트로] %s %s" % [_pawn_name(pawn_id), "%d번 칸의 말을 들이받고 멈춤!" % blocked if blocked != -1 else "%d번까지 질주!" % path.back()], Color("ff922b"))
	if not _fx_on() or pawn==null or path.is_empty() or not _pawn_views.has(pawn_id):
		return
	var dash := {"kind":"nitro","pawn":pawn_id,"path":path.duplicate(),"blocked":blocked,"goal_scale":_depth_scale(tile_norm(int(path.back())).y)}
	var victims: Dictionary = {}
	if blocked>=0:
		for leader: PlayerPawn in state.leaders_at(blocked):
			if leader.entity_id==pawn_id or not leader.has_left_start or leader.is_finished:
				continue
			for member: PlayerPawn in leader.stack_members():
				var view: Node2D = _pawn_views.get(member.entity_id)
				if view==null:
					continue
				_kill_fx(view)
				victims[member.entity_id] = {"position":view.position,"visible":view.visible,"scale":view.scale,"rotation":view.rotation,"tint":view.modulate,"z":view.z_index}
				_nitro_victims[member.entity_id] = true
	dash["victims"] = victims
	_note_super(dash)
	_fx_skip_steps[pawn_id] = true
	_nitro_skips[pawn_id] = true
	# Draft play is owned by its SUPER_10 step, which combines lane and movement.
	if not _draft_in_progress():
		enqueue_step(_play_nitro_stage.bind(dash),pawn_id)


func _play_nitro_stage(dash: Dictionary) -> void:
	var stage := SuperFX.NITRO_STAGE.new()
	add_child(stage)
	stage.play(self,dash,_motion_pace())
	while is_instance_valid(stage) and not stage._complete:
		await get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


func _play_bond_stage(pair: Dictionary) -> void:
	var stage := SuperFX.BOND_STAGE.new()
	add_child(stage)
	stage.play(self,pair,_motion_pace())
	while is_instance_valid(stage) and not stage._complete:
		await get_tree().process_frame
	if is_instance_valid(stage):
		stage.queue_free()


func _release_nitro_victims(ids: Array) -> void:
	for id: int in ids:
		_nitro_victims.erase(id)
		var view: Node2D = _pawn_views.get(id)
		var pawn: PlayerPawn = state.get_pawn(id) if state!=null else null
		if view!=null and pawn!=null:
			view.rotation = 0.0
			view.modulate = Color.WHITE
			view.z_index = 0
			view.scale = Vector2.ONE*_depth_scale(tile_norm(pawn.current_tile_idx).y)
			view.position = _pawn_position(pawn)
			view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null


## 큐의 한 단계: 출발선에서 부스터 칸까지 화염 잔상을 남기며 0.28초 만에 낮은 아치로 날아가 쾅 착지한다.
func _play_rocket(pawn_id: int, to_pos: Vector2, to_scale: float, tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	if view == null or not is_instance_valid(view):
		return
	var start: Vector2 = view.position if view.visible else _tile_center(GameEnums.GOAL_TILE)
	_glide(view, to_pos, to_scale, {"from_pos": start, "dur": 0.28, "arc": 14.0, "pace_cap": 1.0, "land_tile": tile, "land_big": true})
	var generation: int = _fx_generation
	var frame: int = 0
	var previous: Vector2 = start
	while generation == _fx_generation and is_instance_valid(view) and _fx_running(view):
		if frame % 2 == 0:
			_rocket_puff(view.position, view.position.direction_to(previous))
		previous = view.position
		frame += 1
		await get_tree().process_frame
	if generation != _fx_generation or not is_instance_valid(view):
		return
	screen_shake(7.0, 0.22)
	_impact_ring(view.position, Color("ff6b00"), 50.0)
	_floating_badge(view.position + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + Vector2(0, -42), "리벤지 부스터 +%d" % _revenge_steps(state.get_pawn(pawn_id) if state != null else null), Color("ff922b"), 34)
	# 1단계(부스터)와 2단계(눈금 이동) 사이의 짧은 호흡: 경유지라 아직 판정하지 않는다
	var dice_part: int = int(_rocket_followup.get(pawn_id, 0))
	_rocket_followup.erase(pawn_id)
	await get_tree().create_timer(WAYPOINT_PAUSE).timeout
	if dice_part > 0 and is_instance_valid(view):
		var bonus_notes: Array = _move_bonus_notes.get(pawn_id, [])
		_move_bonus_notes.erase(pawn_id)
		_floating_badge(view.position + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + Vector2(0, -42), ("눈금 %d칸" % dice_part) + (" (%s)" % " · ".join(PackedStringArray(bonus_notes)) if not bonus_notes.is_empty() else ""), Color("f8f9fa"), 30)


## 이동 반대쪽으로 말려 올라오는 실제 화염 그림. 짧게 흐려지고 풀로 돌아간다.
func _rocket_puff(at: Vector2, direction: Vector2 = Vector2.UP, color: Color = Color("ff922b")) -> void:
	if not _fx_on() or _pawn_layer == null or not is_inside_tree():
		return
	var puff: Sprite2D = _fx_pool.take(&"rocket_flame")
	if puff == null:
		puff = _fx_pool.adopt(&"rocket_flame", PaintedFx.sprite(PaintedFx.FLAME))
		puff.offset.y = -puff.region_rect.size.y * 0.5
		puff.z_index = 0
		_pawn_layer.add_child(puff)
	_pawn_layer.move_child(puff,0)
	var heading := direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	puff.position = at + Vector2(0, -2)
	puff.rotation = heading.angle() + PI * 0.5
	puff.scale = Vector2(16, 27) / puff.region_rect.size
	puff.modulate = Color(color, color.a * 0.74)
	puff.visible = true
	_mark_oneshot(puff, 0.32)
	var tween: Tween = puff.create_tween().set_parallel(true)
	puff.set_meta(FxPool.TWEEN_META, tween)
	tween.tween_property(puff, "position", puff.position + heading * 14, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", puff.scale * Vector2(0.65, 1.4), 0.32)
	tween.tween_property(puff, "modulate:a", 0.0, 0.32)
	tween.chain().tween_callback(_fx_pool.give_back.bind(puff))


## 빵집에 멈추면 얻은 것을 분명히 보여 준다: 카드를 받으면 [빵집! 카드 획득] 금빛 알림과 환호, 손패가 가득 차 못 받으면 그 이유를 알려 준다.
func _bakery_feedback(data: Dictionary) -> void:
	if not _fx_on() or bool(data.get("canceled", false)):
		return
	var path: Array = data.get("path", [])
	if path.is_empty():
		return
	var pawn_id: int = int(data["pawn_id"])
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn == null or pawn.is_finished or pawn.current_tile_idx != int(path.back()) or not BoardSpec.bakery_tiles.has(pawn.current_tile_idx):
		return
	var owner_id: int = pawn.owner_id
	var tile: int = pawn.current_tile_idx
	var drawn: StringName = data.get("drawn_card", &"")
	var full: bool = drawn == &"" and (state.hands[owner_id] as Array).size() >= state.hand_limit(owner_id)
	if drawn == &"" and not full:
		return
	var at: Vector2 = (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + _tile_center(tile) + Vector2(0, -46)
	# 같은 이동에서 잡기가 있었다면 처치 연출(컷인·사출)이 먼저 나오도록 그 뒤에 세운다 (잡기도 프레임 끝에 큐로 들어간다).
	_enqueue_late(func() -> void:
		if drawn != &"":
			Sfx.play(&"good")
		_fly_card_to_profile(at, owner_id, drawn == &"")  # 어떤 카드인지는 알려 주지 않는다 (뒷면만 날아간다)
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(180.0 * _motion_pace())))  # 배지는 혼자 떠오르므로 큐를 오래 붙잡지 않는다


## 코너에 정확히 도착해 받은 버프: 그 말 위에 [다음 굴림 +N]이 떠오른다.
func _corner_buff_feedback(data: Dictionary) -> void:
	var buff: int = int(data.get("corner_buff", 0))
	if buff <= 0 or not _pawn_views.has(int(data["pawn_id"])):
		return
	var owner_id: int = int(data["player_id"]) if data.has("player_id") else manager.current_player_id()
	var tile: int = int((data["path"] as Array).back()) if not (data["path"] as Array).is_empty() else -1
	_log_line("[코너 도착] P%d: 다음 굴림 +%d!" % [owner_id, buff], Color("8ce99a"))
	if tile == -1 or not _fx_on():
		return
	var at: Vector2 = (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + _tile_center(tile) + Vector2(0, -46)
	_enqueue_late(func() -> void:
		Sfx.play(&"good", -6.0)
		_floating_badge(at, "다음 굴림 +%d" % buff, Color("8ce99a"), 26)
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(180.0 * _motion_pace())))


## 테스트용: move_resolved 없이 빵집 알림만 확인한다.
func _enqueue_bakery_for_test(data: Dictionary) -> void:
	_bakery_feedback(data)


## 큐의 한 단계: 말이 포물선으로 날아가 내려앉을 때까지 기다린다.
func _play_warp_glide(pawn_id: int, to_pos: Vector2, to_scale: float, options: Dictionary) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	if view == null or not is_instance_valid(view):
		return
	_glide(view, to_pos, to_scale, options)
	var generation: int = _fx_generation
	while generation == _fx_generation and is_instance_valid(view) and _fx_running(view):
		await get_tree().process_frame


# ---------------------------------------------------------------------------
# 갱신
# ---------------------------------------------------------------------------

## 화면 전체를 상태에 맞춘다. 행동 하나를 처리하는 동안(_begin_refresh_batch ~ _end_refresh_batch)에는 요청만 모아 두고
## 행동이 끝날 때 한 번만 그린다: 행동 하나가 신호 여러 개(단계 변경·이벤트·로그)를 내며 매번 프로필·손패·버튼을 다시 그리던 것이
## 웹에서 끊김(한 번에 수십 ms 멈춤)의 주원인이었다. 묶음 밖에서는 예전처럼 바로 그린다.
## [KR / EN] 토글: 글자는 자동 번역 노드가 알아서 바뀌고, 보드판 말 라벨(한두 글자)과 손패 카드(이름 글자 크기를 언어에 맞춤)만 다시 그린다.
func _on_language_changed() -> void:
	if not is_inside_tree() or manager == null or manager.state == null:
		return
	_refresh_all()
	if _dock != null:
		_refresh_hands()


func _refresh_all() -> void:
	if manager == null or manager.state == null:
		return
	state = manager.state
	if _refresh_batch > 0:
		_refresh_queued = true
		return
	_refresh_now()


## 행동 처리 묶음 시작 (겹쳐 불러도 된다).
func _begin_refresh_batch() -> void:
	_refresh_batch += 1


## 행동 처리 묶음 끝: 그 사이 요청된 화면 갱신을 한 번에 그린다.
func _end_refresh_batch() -> void:
	_refresh_batch = maxi(_refresh_batch - 1, 0)
	if _refresh_batch == 0 and _refresh_queued:
		_refresh_now()


func _refresh_now() -> void:
	_refresh_queued = false
	refresh_count += 1
	if manager == null or manager.state == null:
		return
	state = manager.state
	_refresh_header()
	_refresh_players()
	_refresh_laws()
	_refresh_tiles()
	_refresh_npc_danger()
	_refresh_pawns()
	_refresh_hands()
	_refresh_controls()
	_refresh_overlays()
	_refresh_super_marks()
	if _draw_fx != null:
		_draw_fx.set_deck_visible(not _draft_in_progress() and not _intro_blocks() and not manager.is_game_over)
	_check_round_banner()
	_check_turn_banner()


## 제한 시간 효과음: 내가 정할 차례에 남은 시간이 5초 안으로 들어오면 1초마다 째깍, 시간이 다 돼 넘어가면 부저.
## 타이머를 화면에 보여 주는 판(타이머 켜기·온라인)에서만 울린다.
func _update_time_pressure(delta: float) -> void:
	var left: float = manager.phase_time_left
	var serial: int = manager.phase_serial
	if serial != _pressure_serial:
		# 째깍거리던 단계가 시간이 다 돼서 끝났다 (마지막 프레임에 남은 시간이 한 프레임 안쪽이었다)
		if _pressure_second != -1 and _pressure_left <= delta * 3.0 + 0.05 and _fx_on():
			Sfx.play(&"timeout")
		_pressure_serial = serial
		_pressure_second = -1
	var visible_timer: bool = (_timer_check != null and _timer_check.button_pressed) or net != null
	var waiting_on_me: bool = manager.current_state == TurnManager.State.PHASE_ROUND_START or not (ai_mode or net != null) or manager.current_player_id() == local_player_id
	if visible_timer and waiting_on_me and not manager.is_game_over and _fx_on() and left > 0.0 and left <= 5.0 and int(ceilf(left)) != _pressure_second:
		_pressure_second = int(ceilf(left))
		Sfx.play(&"timer_tick")
	_pressure_left = left


func _phase_text() -> String:
	var text: String = _phase_name(manager.current_state)
	if ((_timer_check != null and _timer_check.button_pressed) or net != null) and manager.phase_time_left > 0.0:
		text += "  (%.1f초)" % manager.phase_time_left
	return text


func _refresh_header() -> void:
	_phase_label.text = _phase_text()
	_refresh_direction()
	var queue_text: String = "남은 이동 대기열: %s" % str(manager.move_queue) if not manager.move_queue.is_empty() else ""
	if manager.command_stack != null and manager.command_stack.interrupt_count() > 0:
		queue_text += "   개입 대기 카드: %d장 (나중에 낸 카드부터 실행)" % manager.command_stack.interrupt_count()
	if _fx_busy:
		queue_text = ""  # 굴림 연출 중에는 결과가 먼저 새지 않게 숨긴다
	_queue_label.text = queue_text
	_queue_label.visible = queue_text != ""


func _refresh_direction() -> void:
	var reversed: bool = manager.turn_direction == -1
	if _dir_left != null:
		# 정방향은 출발선에서 반시계: 보드 오른쪽은 위로, 왼쪽은 아래로. 우노 리버스(역방향)면 둘 다 뒤집힌다.
		_dir_right.rotation = deg_to_rad(90.0 if reversed else -90.0)
		_dir_left.rotation = deg_to_rad(-90.0 if reversed else 90.0)
		var tint: Color = Color("ffa94d") if reversed else Color("ff6b6b")
		for node: Node2D in [_dir_left, _dir_right]:
			for chevron: Node in node.get_children():
				(chevron as Polygon2D).color = Color(tint.r, tint.g, tint.b, 0.4)
	if not _tag_labels.has(GameEnums.GOAL_TILE):
		return
	var start_tag: Label = _tag_labels[GameEnums.GOAL_TILE]
	start_tag.text = "▼역순" if reversed else "▲출발"
	start_tag.visible = reversed
	start_tag.add_theme_color_override("font_color", Color("ffe8cc") if reversed else Color("f8f9fa"))


## 보드 양옆에 은은하게 깜빡이는 진행 방향 쌍화살표 (>>). 회전은 _refresh_direction이 정한다.
func _build_direction_icons() -> void:
	for side: int in 2:
		var icon := Node2D.new()
		icon.position = Vector2(352, 346) if side == 0 else Vector2(1014, 346)
		icon.visible = false  # 마름모 보드에서는 양옆 쌍화살표를 쓰지 않는다 (진행 방향은 코너 화살표가 알린다)
		icon.z_index = 0  # 오버레이(증강 선택·결과 등)보다 아래: 같은 z면 나중에 추가된 노드가 위에 그려진다
		for index: int in 2:
			var chevron := Polygon2D.new()
			chevron.polygon = PackedVector2Array([Vector2(-8, -20), Vector2(2, -20), Vector2(14, 0), Vector2(2, 20), Vector2(-8, 20), Vector2(4, 0)])
			chevron.position = Vector2(-10 + index * 16, 0)
			chevron.color = Color(1.0, 0.42, 0.42, 0.4)
			icon.add_child(chevron)
		add_child(icon)
		var pulse: Tween = icon.create_tween().set_loops()
		pulse.tween_property(icon, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(icon, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		if side == 0:
			_dir_left = icon
		else:
			_dir_right = icon


## 말의 움직임 연출(잡기 등)이 진행 중이거나 곧 시작될 예정인가. 이때는 다음 턴 안내·강조를 미뤄 한꺼번에 일어나지 않게 한다.
func _fx_motion_pending() -> bool:
	if not _fx_on():
		return false
	if _draw_fx != null and _draw_fx.busy():
		return true
	if _capture_cutin != null and _capture_cutin.busy():
		return true
	if _stage_warps > 0 or _presentation_active():
		return true
	# 굴림 연출·실패 알림이 진행 중이면 아직 이전 플레이어의 턴이다 (결과를 다 보여 준 뒤에야 다음 턴으로 넘어간다).
	if _fx_busy or (_announcer != null and _announcer.holding()):
		return true
	var now: int = Time.get_ticks_msec()
	if now < _fx_until_msec or now < _beat_until_msec:
		return true
	for view: Node2D in _pawn_views.values():
		if _fx_running(view):
			return true
	for hint: Dictionary in _fx_hints.values():
		if now - int(hint.get("t", 0)) < 2500:
			return true
	return false


## 연출이 끝날 때까지 턴·라운드 안내를 미룬다 (끝나면 _process가 화면을 다시 갱신해 안내가 뜬다).
func _defer_for_motion() -> bool:
	if _fx_motion_pending():
		_motion_retry = true
		return true
	return false


## 프로필의 현재 턴 강조는 말의 움직임이 끝날 때까지 이전 턴 플레이어에 머문다 (순서: 잡기 연출 -> 다음 턴으로 넘어감).
func _shown_turn_player() -> int:
	if _fx_motion_pending() and _shown_turn != -1:
		_motion_retry = true
		return _shown_turn
	_shown_turn = manager.current_player_id()
	return _shown_turn


func _npc_runner_name(display_id: StringName) -> String:
	if display_id == &"TRAIN":
		return "폭주 기관차"
	return "사료스탕스" if display_id == &"SUM_01" else "와구와구 유령"


## 소환 카드·폭주 기관차: 알림이 먼저 뜨고(어디서 출발하는지만), 기물이 길을 따라 달린 다음 결과(사출 수)가 나온다. 사출 연출은 그 뒤에 이어진다.
func _on_npc_swept(display_id: StringName, path: Array[int], ejected: Array[int]) -> void:
	if display_id==&"TRAIN":
		_play_train_sweep(path,ejected)
		return
	var runner: String = _npc_runner_name(display_id)
	var outcome: String = "%d번 → %d번 질주! " % [path[0], path[-1]]
	if display_id == &"TRAIN":
		outcome += "말 %d개 사출, 함정 파괴" % ejected.size()
	elif ejected.is_empty():
		outcome += "아무도 못 잡아 보드에 남아 계속 전진합니다"
	else:
		outcome += "말 %d개를 잡고 사라졌습니다" % ejected.size()
	_announce("초증강" if display_id == &"TRAIN" else "소환", "[%s 출동!]" % runner, "%d번에서 출발합니다" % path[0], Color("fa5252"), null, 0.8)
	var npc_id: int = -1
	var behavior: int = GameEnums.NpcBehavior.PATROL_REVERSE if display_id == &"SUM_02" else GameEnums.NpcBehavior.CHASE_NEAREST
	for npc: NeutralNPC in state.npcs:
		if npc.display_id == display_id:
			npc_id = npc.entity_id
	var steps: Array = path.slice(1)
	_play_npc_run(display_id, behavior, path[0], steps, npc_id, func() -> void:
		_log_line("[%s] %s" % [runner, outcome], Color("fa5252"))
		_record(-1, "%s %s" % [_bq(runner), outcome]))


func _build_train_stage() -> void:
	_train_stage = RunawayTrainStage.new()
	_train_stage.name = "RunawayTrainPresentation"
	add_child(_train_stage)
	# Rails cover tile artwork, while pieces remain readable above the rails.
	# The HUD stays above the presentation; launched pawns still use z=12.
	move_child(_train_stage,_pawn_layer.get_index())
	_train_stage.tile_passed.connect(_train_contact)
	_train_stage.pose_changed.connect(_train_pose)

func _train_plane() -> Transform2D:
	var at := _project(Vector2.ZERO)
	return _pawn_layer.transform*Transform2D(_project(Vector2.RIGHT)-at,_project(Vector2.DOWN)-at,at)

## A small world-only camera move: board, pawns and train share one transform.
## HUD stays still, and layout/resizing can reapply this without accumulating drift.
func _train_camera_step() -> void:
	_train_camera_weight = _train_stage.camera_weight() if _train_stage != null else 0.0
	var zoom := 1.0+0.12*_train_camera_weight
	var center := BOARD_ORIGIN+Vector2.ONE*BOARD_SIZE*0.5
	var focus := _project(_train_stage.camera_focus()) if _train_camera_weight>0.0 else center
	var offset := _off_center+center*(1.0-zoom)+(center-focus)*0.16*_train_camera_weight
	_board_layer.scale = Vector2.ONE*zoom
	_pawn_layer.scale = Vector2.ONE*zoom
	_board_layer.position = offset
	_pawn_layer.position = offset

func _on_train_sweep_started(display_id: StringName, path: Array[int]) -> void:
	if display_id!=&"TRAIN" or not _fx_on():
		return
	for tile: int in path:
		if tile==GameEnums.GOAL_TILE:
			continue
		for attachment: TileAttachment in state.board.get_tile(tile).attachments:
			if attachment.attachment_id.begins_with("TRP"):
				_train_trap_hold[tile] = true
		for pawn: PlayerPawn in state.leaders_at(tile):
			if not pawn.has_left_start or pawn.is_finished:
				continue
			for member: PlayerPawn in pawn.stack_members():
				var view: Node2D = _pawn_views.get(member.entity_id)
				if view!=null:
					_kill_fx(view)
					_train_controlled[member.entity_id] = {"tile":tile,"position":view.position,"visible":view.visible,"hit":-1.0}

func _play_train_sweep(path: Array[int], ejected: Array[int]) -> void:
	if not _fx_on() or path.size()<2:
		_train_release()
		return
	var route := path.duplicate()
	var count := ejected.size()
	enqueue_step(func() -> void:
		var generation := _fx_generation
		_train_stage.play(route,_motion_pace(),_train_plane)
		while generation==_fx_generation and _train_stage.mode!=&"idle":
			await get_tree().process_frame
		if generation!=_fx_generation:
			return
		_train_release()
		_refresh_tiles()
		_log_line("[폭주 기관차] %d번 → %d번 질주! 말 %d개 사출 · 경로의 함정 파괴" % [route[0],route[-1],count],Color("fa5252"))
		_record(-1,"폭주 기관차 · 말 %d개 사출" % count))

func _train_contact(tile: int) -> void:
	var hit := false
	for id: int in _train_controlled:
		var info: Dictionary = _train_controlled[id]
		if int(info.tile)==tile and float(info.hit)<0.0:
			info.hit = _train_stage.contact_times[tile]
			var view: Node2D = _pawn_views.get(id)
			if view!=null:
				view.z_index = 12
			hit = true
	if _train_trap_hold.has(tile):
		_train_trap_hold.erase(tile)
		_refresh_tiles()
		_burst_shards(_tile_center(tile),Color("b995eb"),10)
		hit = true
	if hit:
		Sfx.play(&"slam",-4.0,0.02,1.12)
		_train_impact(_tile_center(tile))
		_burst_shards(_tile_center(tile),Color("ffe5a1"),8)
		screen_shake(3.5,0.12)

func _train_impact(at: Vector2) -> void:
	var ring := Line2D.new()
	ring.position = at+Vector2(0,-10)
	ring.width = 2.5
	ring.closed = true
	ring.default_color = Color("ffe0a3")
	ring.z_index = 17
	_pawn_layer.add_child(ring)
	var tween := create_tween()
	tween.tween_method(func(p: float) -> void:
		ring.points = _circle_points(lerpf(7.0,29.0,p),32)
		ring.modulate.a = 1.0-p,0.0,1.0,0.24*_motion_pace())
	tween.tween_callback(ring.queue_free)

func _train_pose() -> void:
	if _train_stage==null:
		return
	_train_camera_step()
	for id: int in _train_controlled:
		var info: Dictionary = _train_controlled[id]
		var view: Node2D = _pawn_views.get(id)
		if view==null:
			continue
		if float(info.hit)<0.0:
			view.position = info.position
			view.visible = info.visible
			continue
		var age := maxf(0.0,_train_stage.elapsed-float(info.hit))
		var phase := clampf(age/0.80,0,1)
		var forward := (_project(_train_stage.origin+_train_stage.direction*0.1)-_project(_train_stage.origin)).normalized()
		var outward := forward.orthogonal()
		if outward.dot(_tile_center(int(info.tile))-_project(Vector2.ONE/2.0))<0.0:
			outward = -outward
		var flight := minf(age,0.80)
		view.position = (info.position as Vector2)+(forward*300.0+outward*145.0+Vector2(0,-240.0))*flight+Vector2(0,320.0)*flight*flight
		view.rotation = age*(9.0 if id%2==0 else -9.0)
		view.scale = Vector2.ONE*(1.0+sin(phase*PI)*0.16)
		view.modulate.a = 1.0-smoothstep(0.48,0.80,age)
		view.visible = bool(info.visible) and phase<1.0

func _train_release() -> void:
	_train_camera_weight = 0.0
	if _board_layer != null and _pawn_layer != null:
		_board_layer.scale = Vector2.ONE
		_pawn_layer.scale = Vector2.ONE
		_board_layer.position = _off_center
		_pawn_layer.position = _off_center
	for id: int in _train_controlled:
		var view: Node2D = _pawn_views.get(id)
		var pawn: PlayerPawn = state.get_pawn(id) if state!=null else null
		if view!=null:
			view.rotation = 0.0
			view.scale = Vector2.ONE
			view.modulate = Color.WHITE
			view.z_index = 0
			if pawn!=null:
				view.position = _pawn_position(pawn)
				view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null
	_train_controlled.clear()
	_train_trap_hold.clear()


## 중립 기물이 한 칸씩 달리는 연출. 보드의 실제 기물 그림(npc_id)은 달리는 동안 숨기고, 끝나면 도착 칸에 다시 보인다.
## 잡힌 말의 사출은 이 연출 뒤에 연출 큐가 이어서 보여 준다 (말이 먼저 날아가지 않게). 끝나면 after를 부른다.
func _play_npc_run(display_id: StringName, behavior: int, from_tile: int, path: Array, npc_id: int, after: Callable) -> void:
	if not _fx_on() or path.is_empty():
		after.call()
		return
	var hidden: Node2D = _npc_views.get(npc_id)
	if hidden != null:
		hidden.visible = false
		hidden.set_meta("npc_run", true)
	enqueue_step(func() -> void:
		var token := PawnToken.new()
		token.configure_npc(behavior)
		var runner: Node2D = token
		runner.name = "NpcRunner"
		runner.z_index = 6
		_pawn_layer.add_child(runner)
		var start: int = from_tile if from_tile >= 0 else int(path[0])
		runner.position = _tile_center(start)
		runner.scale = Vector2.ONE * _depth_scale(tile_norm(start).y)
		var step_time: float = 0.16 * _motion_pace()
		for tile: Variant in path:
			var target: Vector2 = _tile_center(int(tile))
			var hop: Tween = runner.create_tween().set_parallel(true)
			hop.tween_property(runner, "position", target, step_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			hop.tween_property(runner, "scale", Vector2.ONE * _depth_scale(tile_norm(int(tile)).y), step_time)
			Sfx.play(&"hop")
			await hop.finished
			if not is_instance_valid(runner):
				break
		if is_instance_valid(runner):
			_impact_ring(runner.position + _pawn_layer.position, Color("fa5252"), 36.0)
			runner.queue_free()
		# 기물 그림은 달리는 동안 지워질 수 있다(사라진 기물): 람다에 노드를 잡지 않고 다 달린 뒤에 다시 찾는다.
		var real: Node2D = _npc_views.get(npc_id)
		if real != null and is_instance_valid(real):
			real.remove_meta("npc_run")
			var still: NeutralNPC = state.get_npc(npc_id)
			if still != null:
				real.position = _tile_center(still.current_tile_idx)
				real.scale = Vector2.ONE * _depth_scale(tile_norm(still.current_tile_idx).y)
			real.visible = true
		after.call())


## 지금 라운드의 리벤지 부스터 칸 수 (템포 업이 오르면 커진다).
## 리벤지 부스터 칸수. 말을 주면 그 말 기준(루도 복수자는 +4칸 더).
func _revenge_steps(pawn: PlayerPawn = null) -> int:
	if pawn != null and state != null:
		return MoveExecutor.revenge_bonus_of(pawn, state)
	var base: int = GameData.revenge_bonus()
	return maxi(base, TempoUp.revenge_bonus(state.round_number)) if base > 0 and state != null else base


## 라운드가 시작될 때(증강 선택이 끝나고 첫 플레이어의 턴이 오기 직전) 중앙에 크게 알린다.
func _check_round_banner() -> void:
	if _announcer == null or manager.is_game_over or manager.current_state == TurnManager.State.PHASE_ROUND_START:
		return
	if _fx_on() and (_draft_open or not _draft_deferred.is_empty() or (_review_overlay != null and is_instance_valid(_review_overlay))):
		_motion_retry = true
		return  # 증강 확인 창이 닫히고, 고른 증강의 즉시 효과(진화·도구 교체·카드 보급·초증강) 연출이 다 끝난 뒤에 라운드를 연다
	if _defer_for_motion():
		return
	if state.round_number == _announced_round:
		return
	_announced_round = state.round_number
	_announced_turn_key = "%d:%d" % [state.round_number, manager.current_player_id()]
	var tempo: int = TempoUp.level(state.round_number)
	# 라운드 첫 차례는 이 배너가 차례 배너를 겸한다: 누구 차례인지 함께 알리고, 끝날 때까지 굴리기를 막는다
	var first: int = manager.current_player_id()
	var whose: String = tr_ui("turn.mine") if ai_mode and first == local_player_id else tr_ui("turn.other", [_player_name(first)])
	var body: String = whose + ("\n템포 업 Lv.%d %s · 최종 이동 +%d칸" % [tempo, TempoUp.stage_name(tempo), TempoUp.move_bonus(state.round_number)] if tempo > 0 else "")
	if _fx_on():
		Sfx.play(&"round_start")
	_announce("라운드", "%d라운드 시작!" % state.round_number, body, COLOR_GOLD, null, 1.0)


## 새 차례인데 아직 [OO 차례] 배너를 띄우지 못했다 (앞 연출이 끝나기를 기다리는 중): 그동안 봇·굴리기 버튼은 움직이지 않는다.
func _turn_banner_pending() -> bool:
	if not pacing_enabled or _announcer == null or instant_roll_for_test or manager == null or manager.is_game_over:
		return false
	if manager.current_state != TurnManager.State.PHASE_TURN_BEGIN:
		return false
	return "%d:%d" % [state.round_number, manager.current_player_id()] != _announced_turn_key


## 새 플레이어의 턴이 시작될 때 [P2 차례] 알림을 짧게 보여 준다 (추가 턴·롤백 재시작에는 다시 띄우지 않는다).
func _check_turn_banner() -> void:
	if not pacing_enabled or _announcer == null or manager.is_game_over or manager.current_state != TurnManager.State.PHASE_TURN_BEGIN:
		return
	if _defer_for_motion():
		return
	var key: String = "%d:%d" % [state.round_number, manager.current_player_id()]
	if key == _announced_turn_key:
		return
	_announced_turn_key = key
	var player_id: int = manager.current_player_id()
	var who: String = tr_ui("turn.mine") if (not ai_mode or player_id == local_player_id) and ai_mode else tr_ui("turn.other", [_player_name(player_id)])
	if _fx_on():
		Sfx.play(&"turn_start")
	_announce("턴", who, "", PLAYER_COLORS[player_id], null, TURBO_TURN_BANNER_SECONDS if _turbo_turn() else TURN_BANNER_SECONDS)


## 프로필에 보여 줄 이름: AI 대전에서는 내 닉네임과 "컴퓨터 n", 4P 수동 조작에서는 "플레이어 n".
func _player_name(player_id: int) -> String:
	if net != null:
		return net.display_name(player_id)
	if ai_mode:
		return GameSession.display_nickname() if player_id == local_player_id else "컴퓨터 %d" % player_id
	return "플레이어 %d" % player_id


## 손패 칩: 장수만큼 카드 뒷면 칩을 켠다. 늘어난 칩은 톡 튀어 오른다.
func _refresh_hand_pips(player_id: int) -> void:
	var pips: HBoxContainer = _profiles[player_id]["hand_pips"]
	var count: int = (state.hands[player_id] as Array).size()
	var before: int = int(pips.get_meta("count", count))
	pips.set_meta("count", count)
	pips.tooltip_text = "손패 %d장" % count
	for index: int in pips.get_child_count():
		var pip: Panel = pips.get_child(index)
		pip.visible = index < count
		if index >= before and index < count and _fx_on():
			pip.scale = Vector2(1.8, 1.8)
			pip.create_tween().tween_property(pip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_players() -> void:
	for player_id: int in _player_ids:
		var card: Dictionary = _profiles[player_id]
		var color: Color = PLAYER_COLORS[player_id]
		var rank: int = state.rankings.find(player_id) + 1
		(card["name"] as Label).text = ("%s%d위 · %s" % ["★ " if rank == 1 else "", rank, _player_name(player_id)]) if rank > 0 else _player_name(player_id)
		_refresh_hand_pips(player_id)
		_refresh_pawn_slots(player_id)
		var panel: PanelContainer = card["panel"]
		# 스포트라이트: 현재 턴 플레이어만 환하게 밝고 살짝 커지며 외곽 광채가 켜지고, 나머지는 어둡게 가라앉는다.
		var is_turn: bool = player_id == _shown_turn_player() and not manager.is_game_over
		var game_over: bool = manager.is_game_over
		var margin: int = 8
		var lit_key: String = "%s:%s" % [is_turn, game_over]
		if str(panel.get_meta("lit_key", "")) != lit_key:  # 바뀌었을 때만 다시 칠한다 (매 갱신마다 스타일·트윈을 새로 만들지 않게)
			panel.set_meta("lit_key", lit_key)
			if is_turn:
				panel.add_theme_stylebox_override("panel", _style(Color("273049"), Color("fff3bf"), 4, 14, 26, margin))
			else:
				panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, color.darkened(0.35), 2, 14, 4, margin))
		_set_profile_light(panel, PROFILE_LIT if (is_turn or game_over) else PROFILE_DIM, Vector2(1.05, 1.05) if is_turn else Vector2.ONE)
		_refresh_status_stamps(player_id)


## [범용] 증강을 고른 순간 보드 위에 무슨 일이 일어났는지 짧은 콜아웃으로 알린다 (함정 철거·보호막·순보·결승선 단축·재추첨 등).
func _on_utility_picked(player_id: int, augment_id: StringName) -> void:
	if not UtilityAugments.NEW_IDS.has(augment_id) or state == null:
		return
	var text: String = str(UtilityAugments.CALLOUTS.get(augment_id, ""))
	var layer: Vector2 = _pawn_layer.position if _pawn_layer != null else Vector2.ZERO
	var at: Vector2 = _board_center()
	var fx_list: Array[Dictionary] = state.utility_fx.filter(func(entry: Dictionary) -> bool: return int(entry.get("player_id", -1)) == player_id)
	state.utility_fx = state.utility_fx.filter(func(entry: Dictionary) -> bool: return int(entry.get("player_id", -1)) != player_id)
	for entry: Dictionary in fx_list:
		if entry.get("kind", "") == "shield":
			_refresh_pawn_protection(int(entry["pawn_id"]))
		if entry.has("tile"):
			at = layer + _tile_center(int(entry["tile"])) + Vector2(0, -40)
		elif entry.has("pawn_id"):
			var pawn: PlayerPawn = state.get_pawn(int(entry["pawn_id"]))
			if pawn != null and pawn.has_left_start:
				at = layer + _tile_center(pawn.current_tile_idx) + Vector2(0, -40)
	_refresh_tiles()
	_refresh_status_stamps(player_id)
	if text != "" and _fx_on():
		_floating_badge(at, text, AugmentRegistry.get_def(augment_id).display_color(), 26)


## 알고리즘 밴·UDO 스킵을 맞은 플레이어는 자기가 당했는지 알 수 있도록 프로필 그림 위에 도장이 찍힌다.
## 밴은 [BANNED] 붉은 도장(밴이 풀릴 때까지), 스킵은 [금지] 표시(건너뛰는 차례가 올 때까지). 새로 걸리는 순간 쾅 찍히는 연출이 나온다.
func _refresh_status_stamps(player_id: int) -> void:
	var host: Control = _profiles[player_id]["avatar"]
	_refresh_revive_mark(host, player_id)
	var wanted: Dictionary = {&"skip": bool(state.rest_next_turn.get(player_id, false)) and not state.is_graduated(player_id), &"ban": state.is_banned(player_id) and not state.is_graduated(player_id)}
	for kind: StringName in [&"skip", &"ban"]:
		var node_name: String = "Stamp_%s" % kind
		var stamp: StatusStamp = host.get_node_or_null(node_name) as StatusStamp
		if not wanted[kind]:
			if stamp != null:
				stamp.queue_free()
				host.remove_child(stamp)  # 같은 프레임에 다시 걸려도 이름이 겹치지 않게 바로 뗀다
			continue
		if stamp != null:
			stamp.combined = wanted[&"skip"] and wanted[&"ban"]
			continue
		stamp = StatusStamp.new()
		stamp.name = node_name
		stamp.kind = kind
		stamp.combined = wanted[&"skip"] and wanted[&"ban"]
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(stamp)
		if _fx_on() and not instant_roll_for_test:
			stamp.slam_in(self)


## [범용] 다이스: 리바이브가 장전돼 있으면 프로필 그림 아래에 [리바이브] 표시 (쓰면 사라진다).
func _refresh_revive_mark(host: Control, player_id: int) -> void:
	var mark: Label = host.get_node_or_null("ReviveMark") as Label
	var armed: bool = int(state.revive_charges.get(player_id, 0)) > 0 and not state.is_graduated(player_id)
	if not armed:
		if mark != null:
			mark.queue_free()
			host.remove_child(mark)
		return
	if mark != null:
		return
	mark = _make_label("[리바이브]", 12, Color("0d1018"))
	mark.name = "ReviveMark"
	mark.tooltip_text = "다이스: 리바이브 - 0칸·턴 종료 굴림이 나오면 한 턴 더 (1회)"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_stylebox_override("normal", _style(AugmentDef.DISPLAY_COLORS[&"passive"], Color.WHITE, 1, 8, 0, 1))
	mark.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mark.position = Vector2(host.size.x / 2.0 - 34, host.size.y - 18)
	mark.size = Vector2(68, 18)
	mark.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(mark)


func _refresh_pawn_slots(player_id: int) -> void:
	var slots: Array = _profiles[player_id]["slots"]
	for index: int in slots.size():
		_paint_pawn_slot(slots[index], state.get_pawn(player_id * 10 + index + 1), PLAYER_COLORS[player_id])


## 프로필 패널의 명암(modulate)과 크기를 목표로 보낸다 (테스트·초기화 때는 즉시, 평소에는 짧은 트윈).
func _set_profile_light(panel: Control, tint: Color, target_scale: Vector2) -> void:
	var target: Array = [tint, target_scale]
	if panel.has_meta("light_target") and panel.get_meta("light_target") == target and not instant_roll_for_test:
		return  # 이미 그 목표로 가는 중이거나 도착했다: 트윈을 다시 시작하지 않는다
	panel.set_meta("light_target", target)
	if panel.has_meta("light_tween"):
		var previous: Tween = panel.get_meta("light_tween")
		if previous != null and previous.is_valid():
			previous.kill()
	if instant_roll_for_test or not panel.is_inside_tree():
		panel.modulate = tint
		panel.scale = target_scale
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate", tint, 0.15)
	tween.tween_property(panel, "scale", target_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.set_meta("light_tween", tween)


## 기물 슬롯 하나를 3상태로 칠한다: 대기(어두운 회색·반투명) / 출전(플레이어 색) / 완주(황금빛 ★).
func _token_in(parent: Control, pawn: PlayerPawn, color: Color, position_in_parent: Vector2, token_scale: float) -> PawnToken:
	var token: PawnToken = parent.get_node_or_null("PawnToken") as PawnToken
	if token == null:
		token = PawnToken.new()
		token.name = "PawnToken"
		parent.add_child(token)
	token.position = position_in_parent
	token.scale = Vector2.ONE * token_scale
	token.configure(pawn, color)
	return token


func _paint_pawn_slot(parts: Dictionary, pawn: PlayerPawn, color: Color) -> void:
	var letter: Label = parts["letter"]
	var status: Label = parts["status"]
	var panel: PanelContainer = parts["panel"]
	letter.visible = false
	status.visible = false
	_token_in(panel, pawn, color, Vector2.ZERO, 1.0)
	# 칸 모양을 정하는 값이 그대로면 스타일을 새로 만들지 않는다 (16칸 x 갱신마다 스타일·테마를 다시 씌우던 것이 갱신 비용의 대부분이었다).
	var reflow: Callable = _fit_profile_token.bind(panel)
	if not panel.resized.is_connected(reflow):
		panel.resized.connect(reflow)
	_fit_profile_token(panel)
	var paint_key: Array = [pawn.letter(), L10n.current_lang, pawn.is_promoted_shogi(), pawn.is_finished, pawn.has_left_start, pawn.revenge_boost, color]
	if panel.has_meta("paint_key") and panel.get_meta("paint_key") == paint_key:
		return
	panel.set_meta("paint_key", paint_key)
	var shown: String = pawn.letter()
	letter.text = shown if shown != "" else PawnCatalog.basic_letter()
	letter.add_theme_color_override("font_color", Color("ff6b6b") if pawn.is_promoted_shogi() else Color("f8f9fa"))
	if pawn.is_finished:
		panel.add_theme_stylebox_override("panel", _style(Color("d4a72c"), Color("fff3bf"), 3, 8, 12, 1))
		letter.add_theme_color_override("font_color", Color("2b2100"))
		status.add_theme_color_override("font_color", Color("2b2100"))
		status.text = "★완주"
		panel.modulate = Color.WHITE
	elif pawn.has_left_start:
		panel.add_theme_stylebox_override("panel", _style(color.darkened(0.1), color.lightened(0.5), 2, 8, 0, 1))
		letter.add_theme_color_override("font_color", Color("ffffff"))
		status.add_theme_color_override("font_color", Color("fff3bf"))
		status.text = "출전"
		panel.modulate = Color.WHITE
	else:
		panel.add_theme_stylebox_override("panel", _style(Color("2a2d36"), Color("454a57"), 1, 8, 0, 1))
		letter.add_theme_color_override("font_color", Color("adb5bd"))
		status.add_theme_color_override("font_color", Color("868e96"))
		status.text = "대기"
		panel.modulate = Color.WHITE if pawn.revenge_boost else Color(1, 1, 1, 0.6)
	_paint_revenge_glow(panel, pawn.revenge_boost and not pawn.has_left_start and not pawn.is_finished)


## 리벤지 부스터가 장전된 대기 말: 프로필 칸이 이글이글 불탄다 (주황 네온 테두리 + 칸 가장자리에서 넘실대는 불꽃, 글자 없음).
func _paint_revenge_glow(host: Control, on: bool) -> void:
	var glow: Panel = host.get_node_or_null("RevengeGlow") as Panel
	if not on:
		if glow != null:
			glow.visible = false
		return
	if glow == null:
		glow = Panel.new()
		glow.name = "RevengeGlow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(1.0, 0.35, 0.05, 0.12)
		frame.border_color = Color("ff6b00")
		frame.set_border_width_all(3)
		frame.set_corner_radius_all(8)
		frame.shadow_color = Color(1.0, 0.4, 0.0, 0.6)
		frame.shadow_size = 6
		glow.add_theme_stylebox_override("panel", frame)
		host.add_child(glow)
		var fire := RevengeFire.new()
		fire.name = "RevengeFire"
		fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fire.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.add_child(fire)
		var pulse: Tween = glow.create_tween().set_loops()
		pulse.tween_property(glow, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(glow, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	glow.visible = true


func _fit_profile_token(host: Control) -> void:
	var token: PawnToken = host.get_node_or_null("PawnToken") as PawnToken
	if token == null:
		return
	var extent: Vector2 = host.size.max(host.custom_minimum_size)
	token.position = Vector2(extent.x/2.0,extent.y*0.79)
	token.scale = Vector2.ONE*(1.12 if extent.y>=46 else 0.88)


func _refresh_laws() -> void:
	# 슬롯은 이 판에 동시에 걸 수 있는 법전 수만큼만 보인다 (기본 2개, 싱글 Lv.1~2는 1개). 법전을 끈 판은 안내 한 줄만.
	var laws_on: bool = bool(MatchRules.of(state).get("laws", true))
	var shown: int = maxi(MatchRules.max_laws(state) if laws_on else 0, state.rulebook.active_laws_queue.size())
	var resized: bool = false
	for slot: int in _law_slots.size():
		var want: bool = slot < maxi(shown, 1)
		if _law_slots[slot].visible != want:
			_law_slots[slot].visible = want
			resized = true
	if resized and _law_panel != null:
		_law_panel.reset_size()
	for slot: int in _law_labels.size():
		var active: bool = slot < state.rulebook.active_laws_queue.size()
		_law_dashes[slot].visible = not active
		_law_badges[slot].visible = active
		if active:
			var law: LawResource = state.rulebook.active_laws_queue[slot]
			var flashing: bool = _flash_law_ids.has(law.law_id)
			_law_slots[slot].add_theme_stylebox_override("panel", UiSkin.panel("inset_flash" if flashing else "inset_active", 8.0))
			_law_badge_labels[slot].text = law.law_id.trim_prefix("LAW_")
			# 누군가 달성 직전이면 이름 앞에 경고 표시 (자세한 진행도는 마우스를 올리면 나온다).
			var danger: bool = law is VictoryLaw and SpecialVictory.progress_rows(state, law as VictoryLaw).any(func(row: Dictionary) -> bool: return bool(row["danger"]) and not bool(row["done"]))
			_law_labels[slot].text = law.law_name
			_law_labels[slot].add_theme_color_override("font_color", Color("c92a2a") if danger else UiSkin.INK)
			_law_descs[slot].text = law.description
			_law_slots[slot].tooltip_text = ""
			# 내 달성도 배지: 조건을 다 채웠으면 [★ 턴 종료 시 달성!] (차례가 끝나면 바로 졸업)
			var mine_done: bool = false
			if law is VictoryLaw and slot < _law_progress.size():
				var victory: VictoryLaw = law as VictoryLaw
				var viewer: int = _law_view_player()
				var value: int = victory.progress(state, viewer)
				var unit: String = str(LAW_PROGRESS_UNITS.get(law.law_id, victory.unit()))
				# 단위까지 한 문구로 번역한다 ("개"만 따로 번역하면 윷의 "개"가 된다)
				_law_progress[slot].text = L10n.tf("[ %d / %d " + unit + " ]", [mini(value, victory.goal()), victory.goal()])
				_law_progress[slot].visible = viewer != -1
				mine_done = viewer != -1 and value >= victory.goal() and not state.is_graduated(viewer)
				_law_progress[slot].add_theme_color_override("font_color", Color("ffd43b") if mine_done else Color("fff3bf"))
			_set_law_near(slot, 2 if mine_done else (1 if danger else 0))
		else:
			if slot < _law_progress.size():
				_law_progress[slot].visible = false
			_set_law_near(slot, 0)
			_law_slots[slot].add_theme_stylebox_override("panel", UiSkin.panel("inset", 8.0))
			_law_labels[slot].text = "이번 판은 특수 승리 법전이 없어요" if shown == 0 and slot == 0 else ""
			_law_labels[slot].add_theme_color_override("font_color", UiSkin.SOFT)
			_law_descs[slot].text = ""
			_law_slots[slot].tooltip_text = ""


## 법전 진행도 배지를 보여 줄 사람: 컴퓨터 대전·온라인은 나, 한 화면 여럿이 하는 판은 지금 차례인 사람.
func _law_view_player() -> int:
	if state == null or manager == null:
		return -1
	if ai_mode or net != null:
		return local_player_id
	return manager.current_player_id()


## 법전 슬롯 배지: 1 = 누군가 한 걸음 남음 → 빨간 [달성 임박!] + 노랑↔빨강 깜빡임,
## 2 = 내가 조건을 다 채움 → 금색 [★ 턴 종료 시 달성!] + 슬롯 전체가 황금빛으로 반짝임. 0 = 없음.
func _set_law_near(slot: int, mode: int) -> void:
	if slot >= _law_near.size():
		return
	var badge: Label = _law_near[slot]
	var panel: Control = _law_slots[slot]
	if _law_badge_state[slot] == mode:
		return
	_law_badge_state[slot] = mode
	badge.visible = mode != 0
	badge.text = "[★ 턴 종료 시 달성!]" if mode == 2 else "[달성 임박!]"
	var box: StyleBoxFlat = badge.get_theme_stylebox("normal") as StyleBoxFlat
	if box != null:
		box.bg_color = Color("e8a400") if mode == 2 else Color("e03131")
	var old: Tween = _law_near_tweens[slot]
	if old != null and old.is_valid():
		old.kill()
	_law_near_tweens[slot] = null
	panel.self_modulate = Color.WHITE
	badge.modulate = Color.WHITE
	if mode == 0 or not _fx_on():
		return
	var pulse: Tween = panel.create_tween().set_loops()
	if mode == 2:
		pulse.tween_property(panel, "self_modulate", Color(1.45, 1.3, 0.55), 0.35).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(badge, "modulate", Color(1.3, 1.2, 0.8), 0.35)
		pulse.tween_property(panel, "self_modulate", Color(1.1, 1.05, 0.85), 0.35).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(badge, "modulate", Color.WHITE, 0.35)
	else:
		pulse.tween_property(panel, "self_modulate", Color(1.25, 1.15, 0.55), 0.45).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(badge, "modulate", Color(1.0, 0.9, 0.3), 0.45)
		pulse.tween_property(panel, "self_modulate", Color(1.3, 0.7, 0.7), 0.45).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(badge, "modulate", Color.WHITE, 0.45)
	_law_near_tweens[slot] = pulse


## 특수 승리 달성 하이라이트: 그 법전 카드가 슬롯에서 화면 가운데로 날아와 커지고 [특수 승리 조건 달성!] 도장이 찍힌다.
## LAW_ACHIEVED_SECONDS 동안 연출 큐를 붙잡아, 순위 배너는 이 장면이 끝난 뒤에 뜬다.
func _fx_law_achieved(from: Rect2, law_name: String, law_desc: String, color: Color) -> void:
	if not _fx_on():
		return
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(LAW_ACHIEVED_SECONDS * _motion_pace() * 1000.0))
	# 보드·패널보다 위 (처치 컷인과 같은 높이의 화면 레이어)
	var canvas := CanvasLayer.new()
	canvas.name = "LawAchievedFX"
	canvas.layer = 60
	add_child(canvas)
	var layer := Control.new()
	layer.size = get_viewport_rect().size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var card := PanelContainer.new()
	card.name = "LawAchievedCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _style(COLOR_GOLD, Color("fff3bf"), 3, 12, 0, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var title := _make_label(law_name, 16, Color("2b2100"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var desc := _make_label(law_desc, 12, Color("5c4a00"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(desc)
	card.custom_minimum_size = Vector2(maxf(from.size.x, 280.0), maxf(from.size.y, 66.0))
	layer.add_child(card)
	card.reset_size()
	card.pivot_offset = card.size / 2.0
	card.position = from.position
	var view: Vector2 = get_viewport_rect().size
	var target: Vector2 = view / 2.0 - card.size / 2.0 + Vector2(0, -30)
	var stamp := _make_label("[특수 승리 조건 달성!]", 30, color.lightened(0.15))
	stamp.name = "LawAchievedStamp"
	stamp.add_theme_color_override("font_outline_color", Color("3b0a0a"))
	stamp.add_theme_constant_override("outline_size", 8)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stamp)
	stamp.size = Vector2(view.x, 48)
	stamp.position = Vector2(0, view.y / 2.0 + 70.0)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = -0.08
	stamp.scale = Vector2.ONE * 2.6
	stamp.modulate.a = 0.0
	var pace: float = _motion_pace()
	var tween: Tween = layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim, "color:a", 0.45, 0.25 * pace)
	tween.tween_property(card, "position", target, 0.35 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * 1.9, 0.35 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)  # 여기부터는 차례대로: 도장 → 잠깐 멈춤 → 사라짐
	tween.tween_callback(func() -> void:
		Sfx.play_stinger(&"law")
		screen_shake(8.0, 0.2))
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.18 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(stamp, "modulate:a", 1.0, 0.12 * pace)
	tween.tween_interval(0.85 * pace)
	tween.tween_property(layer, "modulate:a", 0.0, 0.22 * pace)
	tween.tween_callback(canvas.queue_free)


func _refresh_hands() -> void:
	for child: Node in _dock.get_children():
		child.queue_free()
	# AI 모드: 하단 독에는 사람(P1)의 손패만 앞면으로 보인다 (봇의 손패는 장수만 프로필 카드에 표시).
	var player_id: int = local_player_id if ai_mode else manager.current_player_id()
	_dock_player = player_id
	var hand: Array = state.hands[player_id]
	if hand.is_empty():
		return
	var count: int = hand.size()
	# 덱에서 날아오는 중인 카드는 내려앉을 때까지 숨겨 둔다 (도착하면 다시 그린다)
	var arriving: int = int(_draw_fx.pending.get(player_id, 0)) if _draw_fx != null else 0
	for index: int in count:
		var card_id: StringName = hand[index]
		var card_view: PanelContainer = _make_card_view(player_id, card_id)
		var offset: float = float(index) - float(count - 1) / 2.0
		var home_rot: float = clampf(offset * HAND_FAN_DEGREES, -16.0, 16.0)
		var home_y: float = DOCK_CARD_Y + minf(offset * offset * 2.0, 16.0)
		card_view.position = _dock_slot(index, count)
		card_view.rotation = deg_to_rad(home_rot)
		if index >= count - arriving:
			card_view.modulate.a = 0.0
		card_view.set_meta("home_y", home_y)
		card_view.set_meta("home_rot", home_rot)
		_dock.add_child(card_view)


## 손패를 펼칠 수 있는 가로 구간 (독 안 x 좌표 [왼쪽, 오른쪽]): 독과 같은 높이에 있는 아래쪽 프로필 카드를 덮지 않게 그 사이로 줄인다.
## 손패가 많으면(최대 8장) 카드끼리 더 겹쳐 펼쳐진다. 부채꼴 기울기만큼 여유(DOCK_PROFILE_GAP)를 둔다.
const DOCK_PROFILE_GAP: float = 56.0


func _dock_span() -> Vector2:
	var lo: float = 0.0
	var hi: float = _dock.size.x
	var dock_rect := Rect2(_dock.global_position, _dock.size)
	var mid: float = dock_rect.get_center().x
	for player_id: Variant in _profiles.keys():
		var panel: Control = _profiles[player_id].get("panel")
		if panel == null or not panel.is_visible_in_tree():
			continue
		var r: Rect2 = panel.get_global_rect()
		if r.end.y < dock_rect.position.y or r.position.y > dock_rect.end.y + HAND_CARD_SIZE.y:
			continue  # 독과 다른 높이(위쪽) 프로필은 상관없다
		if r.get_center().x > mid:
			hi = minf(hi, r.position.x - dock_rect.position.x - DOCK_PROFILE_GAP)
		else:
			lo = maxf(lo, r.end.x - dock_rect.position.x + DOCK_PROFILE_GAP)
	if hi - lo < HAND_CARD_SIZE.x * 2.0:
		return Vector2(0.0, _dock.size.x)  # 화면이 아주 좁으면 원래 폭을 쓴다
	return Vector2(lo, hi)


## 손패 독에서 index번째 카드의 자리 (독 안 좌표, 카드 왼쪽 위). count장이 부채꼴로 펼쳐진다.
func _dock_slot(index: int, count: int) -> Vector2:
	var span: Vector2 = _dock_span()
	var step: float = minf(HAND_CARD_SIZE.x - 14.0, (span.y - span.x - HAND_CARD_SIZE.x) / maxf(count - 1, 1))
	var total: float = HAND_CARD_SIZE.x + step * (count - 1)
	var start_x: float = span.x + (span.y - span.x - total) / 2.0
	var offset: float = float(index) - float(count - 1) / 2.0
	return Vector2(start_x + step * index, DOCK_CARD_Y + minf(offset * offset * 2.0, 16.0))


## 카드를 얻었다: 덱 뭉치에서 뽑혀 내 손패(앞면으로 뒤집혀) 또는 그 사람 프로필(뒷면 그대로)로 날아간다.
## 빼앗은 카드(도적단 대습격·바나나 껍질 등)는 덱이 아니라 빼앗긴 사람 프로필에서 날아온다.
## 드래프트 중에 얻은 카드는 [선택한 증강] 공개 뒤에 날아간다 (손패에서는 바로 숨겨 둔다).
func _fly_drawn_card(player_id: int, card_id: StringName) -> void:
	var origin: Vector2 = Vector2(INF, INF)
	var source_player: int = _steal_from
	if _steal_from != -1:
		if _steal_from != player_id:
			origin = _profile_center(_steal_from)
		_steal_from = -1
	if _draw_fx == null:
		Sfx.play(&"card_get")
		return
	var local: bool = player_id == _dock_owner() and _dock != null and _dock.is_visible_in_tree()
	var index: int = (state.hands[player_id] as Array).size() - 1
	if local:
		_draw_fx.reserve(player_id)
	var launch: Callable = _launch_drawn_card.bind(player_id, card_id, local, index, origin)
	if _draft_in_progress():
		_draft_deferred.append({"step": launch, "pawn": -1, "pick": _pick_serial,
			"draw_job":{"player":player_id,"id":card_id,"local":local,"index":index,"source":source_player}})
		return
	if _presentation_active() or _fx_busy or (_announcer != null and _announcer.holding()):
		# Engine broadcasts rewards and captures in one call. Let late captures
		# register before putting the reward card after them.
		# 드래프트 전에 받은 카드다: 프레임 끝에 줄을 설 때 드래프트가 이미 열렸어도 드래프트 뒤로 미루지 않는다.
		call_deferred("_queue_drawn_after_effects",launch,_fx_generation)
		return
	launch.call()


func _queue_drawn_after_effects(launch: Callable, generation: int) -> void:
	if generation != _fx_generation:
		return
	if not _late_steps.is_empty():
		_late_steps.append({"step": launch, "pawn": -1, "defer": false, "pick": _pick_serial})
	else:
		enqueue_step(launch, -1, false)


func _launch_drawn_card(player_id: int, card_id: StringName, local: bool, index: int, origin: Vector2, grouped: bool = false, origin_provider: Callable = Callable()) -> void:
	var target: Vector2 = Vector2(INF, INF)
	if local:
		target = _drawn_card_destination(player_id,index).position
	else:
		target = _profile_center(player_id)
	if not target.is_finite():
		if local:
			_draw_fx.release(player_id)
			_refresh_hands()
		Sfx.play(&"card_get")
		return
	_draw_fx.draw_card(player_id, card_id, local, target, Callable() if local else _profile_nudge.bind(player_id), local, origin, _drawn_card_destination.bind(player_id,index) if local else _remote_card_destination.bind(player_id), grouped, origin_provider)
	_refresh_controls()


func _remote_card_destination(player_id: int) -> Dictionary:
	return {"position":_profile_center(player_id),"rotation":0.0}

func _tile_card_origin(tile: int) -> Vector2:
	return _pawn_layer.get_global_transform()*_tile_center(tile)


## Match the visual centre and angle of the live fan, whose pivot is its foot.
func _drawn_card_destination(player_id: int, index: int) -> Dictionary:
	var count: int = maxi((state.hands[player_id] as Array).size(),1)
	index = clampi(index,0,count-1)
	var offset: float = float(index)-float(count-1)/2.0
	var angle: float = deg_to_rad(clampf(offset*HAND_FAN_DEGREES,-16.0,16.0))
	var pivot := Vector2(HAND_CARD_SIZE.x/2.0,HAND_CARD_SIZE.y)
	var centre: Vector2 = _dock_slot(index,count)+pivot+(HAND_CARD_SIZE/2.0-pivot).rotated(angle)
	return {"position":_dock.get_global_transform()*centre,"rotation":angle+_dock.get_global_transform().get_rotation()}


## 날아온 카드가 내 손패에 내려앉았다: 숨겨 둔 카드를 보이고 톡 튀게 한다.
func _on_drawn_card_landed(player_id: int, local: bool) -> void:
	if not local or player_id != _dock_player or state == null:
		return
	_refresh_hands()
	var shown: int = (state.hands[player_id] as Array).size() - int(_draw_fx.pending.get(player_id, 0)) - 1
	var live: Array[Node] = _dock.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion())
	if shown < 0 or shown >= live.size():
		return
	var card_view: Control = live[shown]
	card_view.scale = Vector2.ONE * 1.12
	card_view.create_tween().tween_property(card_view, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 카드가 프로필에 꽂히는 순간 프로필이 살짝 흔들린다 (큰 반응 연출이 진행 중이면 그것을 둔다).
func _profile_nudge(player_id: int) -> void:
	if not _profiles.has(player_id):
		return
	var panel: Control = _profiles[player_id]["panel"]
	if panel.has_meta("react_tween"):
		var running: Tween = panel.get_meta("react_tween")
		if running != null and running.is_valid() and running.is_running():
			return
	var base: Vector2 = panel.get_meta("react_base", panel.position) if panel.has_meta("react_tween") else panel.position
	panel.position = base
	panel.set_meta("react_base", base)
	var tween: Tween = create_tween()
	for shift: float in [5.0, -4.0, 2.0]:
		tween.tween_property(panel, "position:x", base.x + shift, 0.04)
	tween.tween_property(panel, "position:x", base.x, 0.04)
	panel.set_meta("react_tween", tween)


## 방어 팝업(InterceptionPrompt): 내 말이 잡히거나, 공격 카드를 맞거나, 함정에 걸렸을 때 그 공격을 받아칠 방어 카드가 손에 있으면
## 진행이 멈추고 가운데에 팝업이 뜬다. 카드마다 [발동] 버튼이 있고, REACTION_SECONDS 동안 고르지 않으면 그냥 맞고 넘어간다.
func _reaction_holder() -> int:
	if manager.is_game_over or not manager.counter_pending():
		return -1
	if _fx_on() and _presentation_active() and not _counter_gate_waiting:
		return -1  # 공격하는 말이 그 칸에 도착해 대치할 때까지(연출 큐가 방어 대기 단계에 닿을 때까지) 팝업을 띄우지 않는다
	var victim: int = int(manager.pending_counter()["victim"])
	if ai_mode or net != null:
		return victim if victim == local_player_id else -1
	return victim  # 같은 화면 대전은 맞은 사람이 직접 고른다


func _update_reaction_popup(delta: float) -> void:
	var holder: int = _reaction_holder()
	if holder == -1:
		_close_reaction_popup()
		return
	var key: String = "%d:%d" % [holder, int(manager.pending_counter()["attack"])]
	if _reaction_popup == null or _reaction_key != key:
		_build_reaction_popup(holder, key)
	if _reaction_bar == null:
		return
	_reaction_left -= delta
	_reaction_bar.value = maxf(_reaction_left, 0.0) / REACTION_SECONDS * 100.0
	if _reaction_left <= 0.0:
		_on_reaction_pass(holder)


## 어떤 공격인지 한 줄로: "P2의 [뱅!]" / "P3의 말에게 잡힘" / "P4의 [바나나 껍질] 함정".
func _attack_text(offer: Dictionary) -> String:
	var attacker: int = int(offer.get("attacker", -1))
	var who: String = _player_name(attacker) if attacker >= 1 else "누군가"
	match StringName(offer.get("kind", &"")):
		&"card": return "%s의 [%s] 공격" % [who, _card_name(offer.get("card_id", &""))]
		&"trap": return "%s의 [%s] 함정" % [who, _attachment_name(String(offer.get("trap_id", "")))]
	return "%s의 말에게 잡힘" % who


func _build_reaction_popup(holder: int, key: String) -> void:
	_close_reaction_popup()
	var offer: Dictionary = manager.pending_counter()
	var entry: Dictionary = state.get_attack(int(offer["attack"]))
	var cards: Array = offer.get("cards", [])
	if cards.is_empty():
		return
	_reaction_key = key
	_reaction_left = REACTION_SECONDS
	_reaction_popup = PanelContainer.new()
	_reaction_popup.name = "InterceptionPrompt"
	_reaction_popup.z_index = 60
	_reaction_popup.add_theme_stylebox_override("panel", _style(Color("101626"), Color("4c6ef5"), 4, 18, 26, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_reaction_popup.add_child(box)
	var title := _make_label("%s 방어하시겠습니까?" % _player_name(holder), 22, Color("bac8ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var ask := _make_label(_attack_text(entry if not entry.is_empty() else offer), 16, Color("f8f9fa"))
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ask)
	var row_cards := HBoxContainer.new()
	row_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	row_cards.add_theme_constant_override("separation", 12)
	box.add_child(row_cards)
	_reaction_use_button = null
	for card_id: Variant in cards:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		column.add_child(_make_card_preview(StringName(card_id)))
		var use := _make_button("발동!", _on_reaction_use.bind(holder, StringName(card_id)), 16, Color("3b5bdb"), 10)
		use.name = "Use_%s" % card_id
		use.custom_minimum_size = Vector2(130, 40)
		column.add_child(use)
		row_cards.add_child(column)
		if _reaction_use_button == null:
			_reaction_use_button = use
	_reaction_bar = ProgressBar.new()
	_reaction_bar.custom_minimum_size = Vector2(300, 10)
	_reaction_bar.show_percentage = false
	_reaction_bar.value = 100.0
	_reaction_bar.add_theme_stylebox_override("fill", _style(Color("4c6ef5"), Color(0, 0, 0, 0), 0, 5, 0, 0))
	_reaction_bar.add_theme_stylebox_override("background", _style(Color("2b2f3a"), Color(0, 0, 0, 0), 0, 5, 0, 0))
	box.add_child(_reaction_bar)
	_reaction_pass_button = _make_button("그냥 맞기", _on_reaction_pass.bind(holder), 16, Color("495a85"), 10)
	_reaction_pass_button.custom_minimum_size = Vector2(130, 40)
	_reaction_pass_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_reaction_pass_button)
	add_child(_reaction_popup)
	_reaction_popup.reset_size()
	_reaction_popup.position = _board_center() - _reaction_popup.size / 2.0
	_reaction_popup.pivot_offset = _reaction_popup.size / 2.0
	_reaction_popup.scale = Vector2(0.85, 0.85)
	_reaction_popup.create_tween().tween_property(_reaction_popup, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"bad")


func _close_reaction_popup() -> void:
	if _reaction_popup != null:
		_reaction_popup.name = "ClosingPrompt"  # 같은 프레임에 새 팝업이 이름을 이어받게 한다
		_reaction_popup.queue_free()
		_reaction_popup = null
		_reaction_use_button = null
		_reaction_pass_button = null
		_reaction_bar = null
	_reaction_key = ""


func _on_reaction_use(holder: int, card_id: StringName) -> void:
	_close_reaction_popup()
	_act(&"play_card", {"player_id": holder, "card_id": card_id})


func _on_reaction_pass(holder: int) -> void:
	_close_reaction_popup()
	_act(&"counter_pass", {"player_id": holder})
	_refresh_all()


## 지금 개입 창(INTERRUPT_ROLL / RESOLUTION)인가.
func _in_intervention_window() -> bool:
	var phase: TurnManager.State = manager.current_state
	return not manager.is_game_over and (phase == TurnManager.State.PHASE_INTERRUPT_ROLL or phase == TurnManager.State.PHASE_RESOLUTION)


## 개입 창에서 낼 수 있는 카드를 가진 플레이어들 (현재 턴 플레이어 먼저).
func _window_holders() -> Array[int]:
	var holders: Array[int] = []
	var order: Array[int] = [manager.current_player_id()]
	for player_id: int in _player_ids:
		if player_id != manager.current_player_id():
			order.append(player_id)
	for player_id: int in order:
		for card_id: StringName in state.hands[player_id]:
			var card: BaseCard = CardRegistry.get_card(card_id)
			if card.category != GameEnums.CardCategory.COUNTER and card.is_playable_in(manager.current_state) and card.could_play(state, player_id):
				holders.append(player_id)
				break
	return holders


## 종류색 프레임. 손패와 알림 앞면은 같은 재현 가능한 스킨을 쓴다.
func _card_frame_style(category: GameEnums.CardCategory, glow: bool, radius: int = 8) -> StyleBoxFlat:
	return CardSkin.frame(category, glow, radius)


## 크기가 다른 손패와 상세 카드는 텍스트 영역을 각각 배치한다.
func _build_card_body(card_id: StringName, card_size: Vector2, detail_mode: bool = false) -> Control:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var summary: String = card_summary(card_id) if detail_mode else str(CARD_SHORT.get(card_id, ""))
	return CardSkin.body(card, card_size, summary, CARD_CATEGORY_NAMES[card.category], detail_mode)


## 한 장짜리 전체 카드 (140x196). 손패에서는 아래 절반이 화면 밖에 가려져 이름과 일러스트가 보이고, 호버하면 올라와 전체가 보인다.
func _make_card_view(player_id: int, card_id: StringName) -> PanelContainer:
	var card: BaseCard = CardRegistry.get_card(card_id)
	# 방어 카드는 끌어 쓰지 않는다: 내게 열린 피격 팝업이 이 카드를 받을 때만 밝게 보인다
	var usable: bool = _card_usable_now(player_id, card) or _counter_offered_to(player_id, card_id)
	var view := PanelContainer.new()
	view.custom_minimum_size = HAND_CARD_SIZE
	view.size = HAND_CARD_SIZE
	view.pivot_offset = Vector2(HAND_CARD_SIZE.x / 2.0, HAND_CARD_SIZE.y)
	var idle_style: StyleBoxFlat = _card_frame_style(card.category, false)
	var glow_style: StyleBoxFlat = _card_frame_style(card.category, true)
	view.add_theme_stylebox_override("panel", idle_style)
	view.modulate = Color.WHITE if usable else Color(0.62, 0.62, 0.68)
	# 커서를 대면 뜨던 설명 상자는 없앴다: 카드 앞면이 이름·효과를 이미 보여 준다.
	view.add_child(_build_card_body(card_id, HAND_CARD_SIZE))
	view.gui_input.connect(_on_card_gui_input.bind(player_id, card_id, view))
	view.set_meta("idle_style", idle_style)
	view.mouse_entered.connect(_on_card_enter.bind(view, glow_style))
	view.mouse_exited.connect(_on_card_exit.bind(view, idle_style))
	return view


## 카드가 솟아오르면 카드 모양이 움직여 포인터가 카드 밖이 되어 곧바로 내려갔다 다시 올라가는 떨림이 생긴다.
## 그래서 올라온 카드는 [원래 자리 ~ 올라온 자리] 영역 안에 포인터가 있는 동안 계속 올라가 있고(`_hold_card`), 영역을 벗어나면 내린다.
func _on_card_enter(view: PanelContainer, glow_style: StyleBoxFlat) -> void:
	if _hold_card != null and is_instance_valid(_hold_card) and _hold_card != view:
		_release_hold_card()
	_hold_card = null
	_on_card_hover(view, glow_style, true)


func _on_card_exit(view: PanelContainer, idle_style: StyleBoxFlat) -> void:
	if not is_instance_valid(view):
		return
	if _card_zone(view).has_point(get_global_mouse_position()):
		_hold_card = view
		return
	_on_card_hover(view, idle_style, false)


func _card_zone(view: Control) -> Rect2:
	var home_y: float = float(view.get_meta("home_y", DOCK_CARD_Y))
	var parent: Control = view.get_parent() as Control
	var origin: Vector2 = parent.global_position if parent != null else Vector2.ZERO
	var top: float = minf(HAND_RAISED_Y, home_y)
	return Rect2(origin + Vector2(view.position.x, top), Vector2(view.size.x, home_y + view.size.y - top))


func _release_hold_card() -> void:
	var view: PanelContainer = _hold_card
	_hold_card = null
	if view != null and is_instance_valid(view):
		_on_card_hover(view, view.get_meta("idle_style"), false)


func _on_card_hover(view: PanelContainer, style: StyleBoxFlat, raised: bool) -> void:
	if not is_instance_valid(view):
		return
	view.add_theme_stylebox_override("panel", style)
	view.z_index = 20 if raised else 0
	if view.has_meta("lift"):
		var previous: Tween = view.get_meta("lift")
		if previous != null and previous.is_valid():
			previous.kill()
	var home_y: float = float(view.get_meta("home_y", DOCK_CARD_Y))
	var home_rot: float = float(view.get_meta("home_rot", 0.0))
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position:y", HAND_RAISED_Y if raised else home_y, 0.12)
	tween.tween_property(view, "rotation", 0.0 if raised else deg_to_rad(home_rot), 0.12)
	tween.tween_property(view, "scale", Vector2.ONE * (1.08 if raised else 1.0), 0.12)
	view.set_meta("lift", tween)


## 카드를 누르면 드래그/클릭 판정을 시작한다 (실제 처리는 _handle_card_pointer가 한다).
func _on_card_gui_input(event: InputEvent, player_id: int, card_id: StringName, view: Control) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_card_press(player_id, card_id, get_viewport().get_mouse_position(), view.global_position, view)


func _card_press(player_id: int, card_id: StringName, pointer: Vector2, home: Vector2, view: Control = null) -> void:
	_drag_press = {"player": player_id, "card": card_id, "origin": pointer, "home": home, "view": view}


## 전역 포인터 입력: 카드 위에서 시작한 누르기를 클릭(확대 토글) 또는 드래그(보드에 던져 발동)로 해석한다. 처리했으면 true.
func _handle_card_pointer(event: InputEvent) -> bool:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and not _drag_press.is_empty():
		_card_move(motion.position)
		return true
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if button.pressed:
		# 확대 카드 밖(손패 독 제외)을 누르면 확대가 닫힌다.
		if _zoom_view != null and _zoom_view.visible and _drag_press.is_empty() and not Rect2(_dock.global_position, _dock.size).has_point(button.position):
			_close_zoom()
		return false
	if _drag_press.is_empty():
		return false
	_card_release(button.position)
	return true


func _card_move(pointer: Vector2) -> void:
	if _drag_press.is_empty():
		return
	if not _drag_active and pointer.distance_to(_drag_press["origin"]) > 10.0:
		_drag_begin()
	if _drag_active:
		_drag_update(pointer)


func _card_release(pointer: Vector2) -> void:
	var press: Dictionary = _drag_press
	_drag_press = {}
	if _drag_active:
		_drag_drop(pointer, press)
	else:
		_toggle_zoom(int(press["player"]), press["card"])


func _drag_begin() -> void:
	var card_id: StringName = _drag_press["card"]
	var player_id: int = int(_drag_press["player"])
	var card: BaseCard = CardRegistry.get_card(card_id)
	_drag_active = true
	Sfx.play(&"card_pick")
	_close_zoom()
	# 손패에 있던 카드 UI(프레임·카테고리 아이콘·요약)를 그대로 집어 들고 간다. 원래 자리의 카드는 흐리게 남는다.
	_drag_ghost = _make_card_view(player_id, card_id)
	_drag_ghost.tooltip_text = ""
	_drag_ghost.z_index = 70
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.modulate = Color.WHITE
	add_child(_drag_ghost)
	_drag_ghost.size = HAND_CARD_SIZE
	_drag_ghost.position = _drag_press["origin"] - HAND_CARD_SIZE / 2.0
	_drag_ghost.pivot_offset = HAND_CARD_SIZE / 2.0
	_drag_ghost.scale = Vector2(1.08, 1.08)
	var source: Control = _drag_press.get("view")
	if source != null and is_instance_valid(source):
		source.modulate = Color(1, 1, 1, 0.25)
	var usable: bool = _card_usable_now(player_id, card)
	_drop_label.text = "[여기에 놓아 카드 발동!]" if usable else "[지금은 쓸 수 없는 카드입니다]"
	if card.category == GameEnums.CardCategory.COUNTER:
		_drop_label.text = "[방어 카드는 공격받을 때 팝업에서 발동합니다]"
	if card.needs_tile():
		_drop_label.text = "[보드판에 놓으면 설치할 타일을 고릅니다]" if usable else "[지금은 쓸 수 없는 카드입니다]"
	if card.card_id == &"ACT_09" and usable:
		_drop_label.text = "[상대 프로필이나 말 위에 놓으면 결투 신청! (보드판에 놓으면 가장 앞선 상대)]"
	_drop_zone.visible = true


func _drag_update(pointer: Vector2) -> void:
	if _drag_ghost == null:
		return
	_drag_ghost.position = pointer - HAND_CARD_SIZE / 2.0
	var over_board: bool = _board_rect().has_point(pointer)
	_drop_zone.add_theme_stylebox_override("panel", _style(Color(1.0, 0.83, 0.23, 0.22 if over_board else 0.08), COLOR_GOLD if over_board else Color("b8962e"), 5 if over_board else 3, 24, 0, 0))


func _drag_drop(pointer: Vector2, press: Dictionary) -> void:
	_drag_active = false
	_drop_zone.visible = false
	_clear_highlight()
	for mark: BoardSkin.Ring in _pick_marks.values():
		mark.visible = false
	var source: Control = press.get("view")
	if source != null and is_instance_valid(source):
		source.modulate = Color.WHITE
	var player_id: int = int(press["player"])
	var card_id: StringName = press["card"]
	var card: BaseCard = CardRegistry.get_card(card_id)
	var reason: String = ""
	var duel_target: int = _duel_target_at(pointer, player_id) if card_id == &"ACT_09" else -1
	if card.category == GameEnums.CardCategory.COUNTER:
		reason = "방어 카드 [%s]는 내가 공격받을 때 뜨는 팝업에서 발동합니다." % card.display_name
	elif not _card_usable_now(player_id, card):
		reason = "지금은 [%s]를 쓸 수 없습니다." % card.display_name
	elif duel_target != -1 and not DuelRules.targets(state, player_id).has(duel_target):
		reason = "%s는 보드 위에 나온 말이 없어 결투할 수 없습니다." % _player_name(duel_target)
	elif not _board_rect().has_point(pointer) and duel_target == -1:
		reason = "카드를 보드판 위에 놓아야 발동합니다." if card_id != &"ACT_09" else "결투할 상대의 말이나 프로필, 또는 보드판 위에 놓으세요."
	if reason != "":
		_log_line(reason, Color("ff8787"))
		_return_ghost(press["home"])
		return
	# 카드가 보드로 날아가 쾅 내리찍힌다 (타일 지정 카드는 타일을 고른 뒤 그 타일에서도 임팩트가 터진다).
	_duel_drop_target = duel_target
	_throw_ghost(_board_center() if not card.needs_tile() else pointer)
	# 타일 지정 카드는 보드에 던지면 '어디에 쓸지' 고르는 UI가 열리고, 즉발 카드는 바로 발동한다.
	_on_card_pressed(player_id, card_id)


## 못 쓰는 위치/타이밍에 놓인 카드가 손패 원위치로 스르륵 돌아간다.
func _return_ghost(home: Vector2) -> void:
	if _drag_ghost == null:
		return
	var ghost: PanelContainer = _drag_ghost
	_drag_ghost = null
	var tween: Tween = create_tween()
	tween.tween_property(ghost, "global_position", home, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ghost.queue_free)


func _free_ghost() -> void:
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null


func _cancel_card_drag() -> void:
	_drag_press = {}
	_drag_active = false
	_free_ghost()
	if _drop_zone != null:
		_drop_zone.visible = false


func _board_rect() -> Rect2:
	var points: PackedVector2Array = BoardSkin.outline(_surface_project)
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return Rect2(result.position + _off_center, result.size)


## 화면 좌표 아래의 보드 타일 번호. 없으면 -1.
func _tile_at(pointer: Vector2) -> int:
	for index: int in _tile_views.keys():
		if (_tile_views[index] as BoardSkin.Tile).contains_global(pointer):
			return index
	return -1


func _toggle_zoom(player_id: int, card_id: StringName) -> void:
	var key: String = "%d:%s" % [player_id, card_id]
	if _zoom_view != null and _zoom_view.visible and _zoom_key == key:
		_close_zoom()
		return
	_open_zoom(player_id, card_id)


## 확대 카드(350x490)와 별도 사용 안내 패널. 남의 턴에도 열람할 수 있다.
func _open_zoom(player_id: int, card_id: StringName) -> void:
	_close_zoom()
	var card: BaseCard = CardRegistry.get_card(card_id)
	var card_size: Vector2 = HAND_CARD_SIZE * 2.5
	_zoom_key = "%d:%s" % [player_id, card_id]
	_zoom_view = PanelContainer.new()
	_zoom_view.name = "CardZoom"
	_zoom_view.z_index = 30
	_zoom_view.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_zoom_view.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_close_zoom())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_view.add_child(box)
	var face := PanelContainer.new()
	face.name = "CardFace"
	face.custom_minimum_size = card_size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", CardSkin.frame(card.category, false, 20))
	face.add_child(_build_card_body(card_id, card_size, true))
	box.add_child(face)
	var guide := PanelContainer.new()
	guide.name = "CardGuide"
	guide.custom_minimum_size = Vector2(card_size.x, 0)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.add_theme_stylebox_override("panel", UiSkin.panel("panel", 12))
	box.add_child(guide)
	var guide_box := VBoxContainer.new()
	guide_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_box.add_theme_constant_override("separation", 4)
	guide.add_child(guide_box)
	var how: String = "보드에 드래그 → 타일 선택" if card.needs_tile() else "보드에 드래그"
	if card.category == GameEnums.CardCategory.COUNTER:
		how = "피격 시 발동 여부를 묻는 팝업에서 [발동]"
	var timing := _make_label("발동: %s\n방법: %s" % [_card_timing_text(card), how], MobileSupport.text_px(14), UiSkin.INK)
	timing.name = "CardTiming"
	timing.custom_minimum_size = Vector2(card_size.x - 24.0, 0)
	timing.size = Vector2(card_size.x - 24.0, 40)
	timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_box.add_child(timing)
	if CardSkin.SELF_RISK.has(card_id):
		# 내 말도 휘말리는 카드: 카드 왼쪽 위의 경고 아이콘과 같은 그림 + 상세 문구
		var caution := HBoxContainer.new()
		caution.name = "CardCaution"
		caution.add_theme_constant_override("separation", 6)
		caution.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caution_icon := CardSkin.WarningIcon.new()
		caution_icon.custom_minimum_size = Vector2(22, 22)
		caution.add_child(caution_icon)
		var caution_text := _make_label("주의: %s" % CardSkin.SELF_RISK[card_id], MobileSupport.text_px(14), CardSkin.WARNING_RED)
		caution_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caution_text.custom_minimum_size = Vector2(card_size.x - 24.0 - 28.0, 0)
		caution_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caution.add_child(caution_text)
		guide_box.add_child(caution)
	var usable: bool = _card_usable_now(player_id, card)
	var status_text: String = "지금 사용 가능" if usable else "지금은 사용 불가"
	if card.category == GameEnums.CardCategory.COUNTER:
		usable = _counter_offered_to(player_id, card.card_id)
		status_text = "지금 방어 가능 (팝업에서 발동)" if usable else "내가 공격받을 때만 사용 가능"
	var status := _make_label(status_text, MobileSupport.text_px(14), Color("416c2b") if usable else Color("747c64"))
	status.name = "CardStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_box.add_child(status)
	add_child(_zoom_view)
	var total: Vector2 = _zoom_view.get_combined_minimum_size()
	_zoom_view.size = total
	var screen: Vector2 = get_viewport_rect().size
	_zoom_view.position = Vector2(maxf(24, (screen.x - total.x) / 2), maxf(24, (screen.y - total.y) / 2))


func _card_timing_text(card: BaseCard) -> String:
	if card.category == GameEnums.CardCategory.COUNTER:
		return "피격 시 (내 말이 잡히거나 공격 카드·함정에 당했을 때)"
	var names: Array[String] = []
	for phase: int in card.playable_phases:
		var full: String = _phase_name(phase)
		names.append(full.split(" - ")[0])
	return " / ".join(names) if not names.is_empty() else "-"


func _close_zoom() -> void:
	if _zoom_view != null:
		_zoom_view.queue_free()
		_zoom_view = null
	_zoom_key = ""


# ---------------------------------------------------------------------------
# 호버 툴팁 (기물 능력 & 세트 시너지): 0.35초 이상 가리키고 있으면 뜨고, 벗어나면 즉시 사라진다
# ---------------------------------------------------------------------------

## 카드를 끄는 동안 보드판 테두리에 뜨는 드롭 존 하이라이트.
func _build_drop_zone() -> void:
	_drop_zone = PanelContainer.new()
	_drop_zone.position = PLATE_POS
	_drop_zone.size = PLATE_SIZE
	_drop_zone.z_index = 20
	_drop_zone.visible = false
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_theme_stylebox_override("panel", _style(Color(1.0, 0.83, 0.23, 0.08), Color("b8962e"), 3, 24, 0, 0))
	add_child(_drop_zone)
	_drop_label = _make_label("[여기에 놓아 카드 발동!]", 22, COLOR_GOLD)
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_drop_label.add_theme_constant_override("outline_size", 6)
	_drop_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_drop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_child(_drop_label)


func _build_hover_tip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.visible = false
	_tip_panel.z_index = 90
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.08, 0.13, 0.94), COLOR_GOLD, 2, 10, 12, 10))
	add_child(_tip_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(360, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(column)
	_tip_title = _make_label("", 22, COLOR_GOLD)
	_tip_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_title.custom_minimum_size = Vector2(360, 0)
	column.add_child(_tip_title)
	_tip_ability = _make_label("", 19, Color("f1f3f5"))
	_tip_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_ability.custom_minimum_size = Vector2(360, 0)
	column.add_child(_tip_ability)
	# 기물 툴팁: 패시브와 필살기 사이 구분선 (다른 툴팁에서는 숨긴다)
	_tip_rule = ColorRect.new()
	_tip_rule.color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.45)
	_tip_rule.custom_minimum_size = Vector2(0, 2)
	_tip_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_rule.visible = false
	column.add_child(_tip_rule)
	_tip_skill = _make_label("", 19, Color("ffa94d"))
	_tip_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_skill.custom_minimum_size = Vector2(360, 0)
	column.add_child(_tip_skill)


## 기물 툴팁 내용: 이름 / 상시 능력 / 1회용 필살기 (세트 설명은 없다).
func _fill_pawn_tip(pawn_id: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return
	var status: String = ""
	if pawn.is_finished:
		status = "  (완주)"
	elif pawn.restrained_turns > 0 or pawn.blocked_this_turn:
		status = "  (구속)"
	elif pawn.is_imprisoned:
		status = "  (감옥)"
	if pawn.is_promoted_shogi():
		status += "  ★나리 승급(+1칸)"
	if pawn.revenge_boost and not pawn.has_left_start:
		status += "\n리벤지 부스터 활성화: 이번 출격 시 이동 거리 +%d칸!" % _revenge_steps(pawn)
	if pawn.ward:
		status += "  보호막 있음"
	elif pawn.sub_type() == GameEnums.PawnSubType.BADUK_WHITE:
		status += "  방어막 있음" if pawn.shield else "  (방어막 깨짐)"
	_tip_title.text = "%s  - P%d%s" % [PawnCatalog.full_name(pawn.kind, pawn.unit_no), pawn.owner_id, status]
	# 판정 도구 카드처럼 구분선 위에 패시브(둘이면 줄 나눔), 아래에 필살기. [패시브]·[필살기] 머리말은 쓰지 않는다.
	var passive: String = PawnCatalog.passive_lines(pawn.kind, pawn.unit_no)
	_tip_ability.visible = passive != ""
	_tip_ability.text = passive
	var skill: StringName = PawnCatalog.skill_of(pawn.sub_type())
	_tip_skill.visible = skill != &""
	_tip_rule.visible = _tip_ability.visible and _tip_skill.visible
	if skill != &"":
		var locked: String = "  (승급 후)" if PawnCatalog.PROMOTED_SKILLS.has(skill) and not pawn.promoted else ""
		_tip_skill.text = "%s%s%s\n%s" % [PawnCatalog.skill_name(skill), "  (사용됨)" if pawn.skill_used else "", locked, PawnCatalog.skill_text(skill)]


## 프로필 [증강] 요약: 지금까지 고른 증강 / 말 4개의 기물과 패시브 / 장착한 판정 도구.
func _fill_profile_tip(player_id: int) -> void:
	if state == null or manager == null:
		return
	var owned: Array = manager.augments.get(player_id, [])
	_tip_title.text = "%s · 보유 증강 %d개" % [_player_name(player_id), owned.size()]
	var counts: Dictionary = {}
	var order: Array[StringName] = []
	for id: Variant in owned:
		if not counts.has(id):
			order.append(StringName(str(id)))
		counts[id] = int(counts.get(id, 0)) + 1
	var lines: PackedStringArray = []
	for id: StringName in order:
		var definition: AugmentDef = AugmentRegistry.get_def(id)
		if definition == null:
			continue
		var name_text: String = definition.title if definition.title != "" else definition.display_name
		lines.append(name_text if int(counts[id]) <= 1 else "%s ×%d" % [name_text, int(counts[id])])
	_tip_ability.text = "\n".join(lines) if not lines.is_empty() else "아직 고른 증강이 없어요"
	var info: PackedStringArray = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		info.append(("%d번 말: %s  (완주)" if pawn.is_finished else "%d번 말: %s") % [pawn.slot, PawnCatalog.full_name(pawn.kind, pawn.unit_no)])
		if pawn.kind != GameEnums.PawnKind.BASIC:
			var passive: String = PawnCatalog.passive_lines(pawn.kind, pawn.unit_no)
			if passive != "":
				info.append(passive)
	var tool: BaseJudgmentTool = state.tools.get(player_id)
	if tool != null:
		info.append("판정 도구: %s" % tool.display_name)
		var span: Array[int] = AugmentDef.tool_step_range(tool.tool_id)
		if span.size() == 2:
			info.append("최소 %d칸 ~ 최대 %d칸" % [span[0], span[1]])
	_tip_skill.visible = true
	_tip_skill.text = "\n".join(info)


## 법전 슬롯 툴팁: 특수 승리 조건과 모두의 실시간 진행도 ("P2  3/6 처치  [위험!]").
func _fill_law_tip(slot: int) -> void:
	if state == null or slot >= state.rulebook.active_laws_queue.size():
		_tip_title.text = "빈 법전 슬롯"
		_tip_ability.text = "특수 승리 교칙이 제정되면 여기에 올라옵니다 (3라운드부터 드래프트)"
		_tip_skill.visible = false
		return
	var law: LawResource = state.rulebook.active_laws_queue[slot]
	_tip_title.text = "★ [특수 승리] %s" % law.law_name
	_tip_ability.text = "조건: %s\n차례가 끝날 때마다 판정: 달성해 있으면 바로 다음 순위로 졸업하고, 이 교칙은 법전에서 사라집니다" % law.description
	_tip_skill.visible = law is VictoryLaw
	if law is VictoryLaw:
		_tip_skill.text = law_progress_text(state, law as VictoryLaw, _player_name)


## 진행도 줄들 (툴팁·테스트 공용).
static func law_progress_text(game: GameState, law: VictoryLaw, name_of: Callable) -> String:
	var lines: Array[String] = []
	for row: Dictionary in SpecialVictory.progress_rows(game, law):
		var player_id: int = int(row["player"])
		var line: String = "%s  %d/%d %s" % [name_of.call(player_id), int(row["value"]), int(row["goal"]), law.unit()]
		if bool(row["done"]):
			line += "  (%d위 졸업)" % (game.rankings.find(player_id) + 1)
		elif bool(row["danger"]):
			line += "  [위험!]"
		lines.append(line)
	return "\n".join(lines)


func _bind_tip(control: Control, provider: Callable) -> void:
	control.mouse_entered.connect(_tip_begin.bind(control, provider))
	control.mouse_exited.connect(_tip_end.bind(control))


func _tip_begin(source: Variant, provider: Callable) -> void:
	_tip_pinned = false
	_tip_source = source
	_tip_provider = provider
	_tip_clock = 0.0
	_tip_panel.visible = false


func _tip_end(source: Variant = null) -> void:
	if source != null and _tip_source != source:
		return
	_tip_source = null
	_tip_pinned = false
	_tip_clock = 0.0
	if _tip_panel != null:
		_tip_panel.visible = false


## 기물 설명 열기/닫기: 열려 있는 같은 기물을 다시 누르면 닫고, 아니면 누른 자리 옆에 바로 연다.
func _tip_toggle(source: Variant, provider: Callable) -> void:
	if _tip_pinned and _tip_source == source:
		_tip_end()
		return
	_tip_source = source
	_tip_provider = provider
	_tip_pinned = true
	_tip_anchor = get_viewport().get_mouse_position()
	_tip_clock = TIP_DELAY
	_tip_panel.visible = false
	_update_tip(0.0)


## 클릭 한 번이 고정된 기물 설명을 닫아야 하는가: 그 설명을 연 칸(프로필·독)이 아닌 곳을 눌렀다.
## 보드 위 말 설명은 _on_board_tip_click이, 그 칸 자신의 클릭은 _tip_toggle이 처리한다.
func _tip_click_elsewhere(pointer: Vector2) -> bool:
	if not _tip_pinned or _tip_source == null:
		return false
	if _tip_source is Control:
		return not (_tip_source as Control).get_global_rect().has_point(pointer)
	return false


func _update_tip(delta: float) -> void:
	if _tip_source == null or _tip_panel == null:
		return
	if _tip_source is Object and not is_instance_valid(_tip_source):
		_tip_end()
		return
	_tip_clock += delta
	if _tip_clock < TIP_DELAY:
		return
	if not _tip_panel.visible:
		_tip_ability.visible = true  # 기물 툴팁만 패시브 칸을 숨기고 구분선을 켠다
		_tip_rule.visible = false
		_tip_provider.call()
		_tip_panel.visible = true
		_tip_panel.reset_size()
	var pointer: Vector2 = _tip_anchor if _tip_pinned else get_viewport().get_mouse_position()
	var spot: Vector2 = pointer + Vector2(16, 18)
	var limit: Vector2 = Vector2(1366, 768) - _tip_panel.size - Vector2(4, 4)
	if spot.x > limit.x:
		spot.x = pointer.x - _tip_panel.size.x - 12.0
	_tip_panel.position = Vector2(clampf(spot.x, 4.0, limit.x), clampf(spot.y, 4.0, limit.y))


func _announce_gate_text_for_tests() -> String:
	return NPC_ANNOUNCE_BODY


## 중립 NPC 설명 툴팁: 어느 방향으로 얼마나 가는지, 마주치면 어떻게 되는지.
func _fill_npc_tip(npc_id: int) -> void:
	var npc: NeutralNPC = state.get_npc(npc_id) if state != null else null
	if npc == null:
		return
	var robber: bool = npc.behavior != GameEnums.NpcBehavior.PATROL_REVERSE
	_tip_title.text = "사료스탕스  ▶ 정방향 전진" if robber else "와구와구 유령  ◀ 역방향 전진"
	_tip_ability.text = NPC_TIP_ROBBER if robber else NPC_TIP_GHOST
	_tip_skill.visible = npc.owner_id >= 1
	_tip_skill.text = "소환: P%d · 라운드가 끝나면 움직이고 사라짐" % npc.owner_id


## 보드 클릭: 아무 말(상대 말·중립 기물 포함)을 누르면 그 설명을 열고, 같은 말을 다시 누르면 닫는다. 빈 곳을 누르면 열린 설명을 닫는다.
func _on_board_tip_click(pointer: Vector2) -> void:
	if _tile_pick_active or _snipe_pick:
		return
	var target: Array = _board_tip_target(pointer)
	if target.is_empty():
		if _tip_pinned and (_tip_source is String or _tip_click_elsewhere(pointer)):
			_tip_end()
		return
	_tip_toggle(target[0], target[1])


## 설치물(함정·코너 함정·호텔·지뢰)이 있는 칸 중 화면 좌표 아래의 칸. 없으면 -1.
func _attachment_tile_at(pointer: Vector2) -> int:
	if state == null or _pawn_layer == null:
		return -1
	var best: int = -1
	var best_distance: float = 24.0
	for index: int in BoardSpec.tile_count:
		if state.board.get_tile(index).attachments.is_empty():
			continue
		var distance: float = (_tile_center(index) + _pawn_layer.position).distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## 커서가 설치물 칸 위에 오면 설명을 바로 띄우고, 벗어나면 닫는다 (눌러서 고정한 설명은 건드리지 않는다).
func _hover_attachment_tip(pointer: Vector2) -> void:
	if _tip_pinned or _tip_panel == null:
		return
	if _draft_overlay != null or _result_overlay != null or _choice_overlay != null:
		return  # 보드를 가린 창 너머의 칸은 설명하지 않는다
	var tile: int = _attachment_tile_at(pointer)
	var key: String = "tile:%d" % tile
	if tile != -1:
		if _tip_source != key:
			_tip_begin(key, _fill_attachment_tip.bind(tile))
			_tip_clock = TIP_DELAY  # 기다리지 않고 바로
	elif _tip_source is String and String(_tip_source).begins_with("tile:"):
		_tip_end(_tip_source)


## 설치물 한 개의 설명 [제목, 효과, 유지]. 정체를 모르는 뒷면 함정은 이름·효과를 숨긴다.
func _attachment_tip_lines(attachment: TileAttachment) -> Array[String]:
	var id: String = attachment.attachment_id
	var kind: String = "호텔" if id == "HOTEL" else ("코너 함정" if id.begins_with("TRP_C") else "함정")
	if _structure_kind(attachment) == &"mine":
		kind = "지뢰"
	var known: bool = id == "HOTEL" or _trap_known(attachment)
	var title: String = "[%s] %s  (설치: %s)" % [kind, _attachment_name(id), _player_name(attachment.owner_id)] if known else "[? 수상한 함정]  (설치: %s)" % _player_name(attachment.owner_id)
	var effect: String = "직접 밟거나 해체하기 전까지 정체를 알 수 없습니다!"
	if id == "HOTEL":
		effect = "다른 플레이어가 멈추면 통행료"
	elif known:
		effect = card_summary(StringName(id))
	var keep: String = "남은 유지: %d턴" % attachment.duration_turns if attachment.duration_turns > 0 else "유지: 발동할 때까지"
	return [title, effect, keep] as Array[String]


## 설치물 칸 툴팁: 그 칸의 설치물마다 [이름] (설치자) / 효과 요약 / 남은 유지 턴.
func _fill_attachment_tip(tile: int) -> void:
	if state == null:
		return
	var titles: PackedStringArray = []
	var bodies: PackedStringArray = []
	var keeps: PackedStringArray = []
	for attachment: TileAttachment in state.board.get_tile(tile).attachments:
		var lines: Array[String] = _attachment_tip_lines(attachment)
		titles.append(lines[0])
		bodies.append(lines[1])
		keeps.append(lines[2])
	_tip_title.text = "\n".join(titles)
	_tip_ability.text = "\n".join(bodies)
	_tip_skill.visible = not keeps.is_empty()
	_tip_skill.text = "\n".join(keeps)


## 화면 좌표 아래의 말·중립 기물·설치물: [설명 키, 내용 채우기]. 없으면 빈 배열.
func _board_tip_target(pointer: Vector2) -> Array:
	for npc: NeutralNPC in state.npcs:
		var npc_view: Node2D = _npc_views.get(npc.entity_id)
		if npc_view != null and (npc_view.position + _pawn_layer.position + Vector2(0, -14)).distance_to(pointer) < 26.0:
			return ["npc:%d" % npc.entity_id, _fill_npc_tip.bind(npc.entity_id)]
	var found: int = -1
	var best: float = 50.0
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null or not view.visible:
			continue
		var distance: float = (view.position + _pawn_layer.position + Vector2(0,-12)).distance_to(pointer)
		if PawnToken.HIT_BOX.has_point((view.get_node("Bounce") as Node2D).to_local(pointer)) and distance < best:
			best = distance
			found = pawn.entity_id
	if found == -1:
		var tile: int = _attachment_tile_at(pointer)
		return ["tile:%d" % tile, _fill_attachment_tip.bind(tile)] if tile != -1 else []  # 말이 없는 설치물 칸 (모바일은 탭)
	return ["board:%d" % found, _fill_pawn_tip.bind(found)]


## 기물 설명 텍스트(테스트·로그용): 이름 / 고유 능력 / 필살기.
func _pawn_info_text(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return ""
	var lines: Array[String] = [PawnCatalog.full_name(pawn.kind, pawn.unit_no), "패시브: %s" % PawnCatalog.ability_text(pawn.kind, pawn.unit_no)]
	if pawn.is_promoted_shogi():
		lines.append("나리(成り) 승급 상태: %s - 이동할 때마다 +1칸" % pawn.display_label())
	var skill: StringName = PawnCatalog.skill_of(pawn.sub_type())
	if skill != &"":
		lines.append("[1회] %s: %s%s" % [PawnCatalog.skill_name(skill), PawnCatalog.skill_text(skill), " (사용됨)" if pawn.skill_used else ""])
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# 우측 하단 대형 기물 선택 독
# ---------------------------------------------------------------------------

func _build_pawn_dock() -> void:
	_pawn_bar = Panel.new()
	_pawn_bar.position = Vector2(1024, 432)
	_pawn_bar.size = Vector2(330, 156)
	_pawn_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pawn_bar.add_theme_stylebox_override("panel", _style(Color("131826"), COLOR_PANEL_EDGE, 2, 12, 8, 0))
	add_child(_pawn_bar)
	var step: float = SLOT_SIZE.x + 5.0
	for slot: int in GameEnums.PAWNS_PER_PLAYER:
		var skill_button: Button = _make_button("필살기\n발동!", _on_skill_pressed.bind(slot), 13, Color("c77d0a"), 8)
		skill_button.position = Vector2(6 + slot * step, 6)
		skill_button.size = Vector2(SLOT_SIZE.x, 38)
		skill_button.custom_minimum_size = Vector2(SLOT_SIZE.x, 38)
		skill_button.focus_mode = Control.FOCUS_NONE
		skill_button.add_theme_color_override("font_color", Color("fff9db"))
		skill_button.add_theme_color_override("font_hover_color", Color.WHITE)
		skill_button.add_theme_color_override("font_outline_color", Color("5c3a00"))
		skill_button.add_theme_constant_override("outline_size", 4)
		skill_button.visible = false
		skill_button.mouse_entered.connect(_on_pawn_slot_hover.bind(slot))
		skill_button.mouse_exited.connect(_on_pawn_slot_unhover.bind(skill_button))
		_pawn_bar.add_child(skill_button)
		_dock_skill_buttons.append(skill_button)
		var button := Button.new()
		button.position = Vector2(6 + slot * step, SLOT_BASE_Y)
		button.size = SLOT_SIZE
		button.custom_minimum_size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		var letter := _make_label("", 28, Color("f8f9fa"))
		letter.position = Vector2(0, 14)
		letter.size = Vector2(SLOT_SIZE.x, 36)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(letter)
		var place := _make_label("", 14, Color("ffe8a3"))
		place.position = Vector2(0, 56)
		place.size = Vector2(SLOT_SIZE.x, 22)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(place)
		var number := _make_label(str(slot + 1), 12, Color("adb5bd"))
		number.position = Vector2(6, 2)
		number.visible = false
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(number)
		var badge := _make_label("", 13, Color("0d1018"))
		badge.position = Vector2(SLOT_SIZE.x - 30, 2)
		badge.size = Vector2(26, 18)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", _style(COLOR_GOLD, Color("fff3bf"), 1, 8, 0, 1))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		button.add_child(badge)
		button.mouse_entered.connect(_on_pawn_slot_hover.bind(slot))
		button.mouse_exited.connect(_on_pawn_slot_unhover.bind(button))
		button.pressed.connect(_on_pawn_slot_pressed.bind(slot))
		_pawn_bar.add_child(button)
		_pawn_buttons.append(button)
		_pawn_slot_parts.append({"letter": letter, "place": place, "badge": badge})


## 내 프로필 위의 [감정 표현] 버튼: 누르면 이모트 판(EmoteCatalog 8종)이 펼쳐지고, 고르면 내 아바타 옆에 말풍선이 튀어나오며 아바타 표정이 바뀐다.
## 온라인이면 상대 화면의 내 프로필에도 같은 말풍선이 뜬다 (클래시 로얄식 이모트).
const EMOTE_COOLDOWN_MSEC: int = 1200

var _emote_button: Button = null
var _emote_picker: PanelContainer = null
var _emote_bubbles: Dictionary = {}


func _build_emote_row() -> void:
	_emote_row = HBoxContainer.new()
	_emote_row.name = "EmoteRow"
	_emote_row.position = Vector2(1030, 538) if MobileSupport.touch_mode() else Vector2(1030, 554)  # 터치 버튼(48px)이 아래 프로필에 닿지 않게 16px 위로
	_emote_row.size = Vector2(320, MobileSupport.TOUCH_BUTTON_HEIGHT if MobileSupport.touch_mode() else 32.0)
	_emote_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(_emote_row)
	_emote_button = _make_button(tr_ui("btn.emote"), _toggle_emote_picker, 14, Color("f08c00"), 14)
	_emote_button.name = "EmoteButton"
	_emote_button.custom_minimum_size = Vector2(150, MobileSupport.TOUCH_BUTTON_HEIGHT) if MobileSupport.touch_mode() else Vector2(124, 32)
	if MobileSupport.touch_mode():
		_emote_button.add_theme_font_size_override("font_size", 17)
		MobileSupport.touch_button(_emote_button)
	_emote_button.focus_mode = Control.FOCUS_NONE
	_emote_button.tooltip_text = "말풍선으로 감정 표현 (상대에게도 보입니다)"
	_emote_row.add_child(_emote_button)
	_emote_picker = PanelContainer.new()
	_emote_picker.name = "EmotePicker"
	_emote_picker.visible = false
	_emote_picker.z_index = 65
	_emote_picker.add_theme_stylebox_override("panel", _style(Color(0.07, 0.09, 0.15, 0.96), Color("ffd43b"), 3, 16, 12, 10))
	add_child(_emote_picker)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_emote_picker.add_child(grid)
	for emote_id: int in EmoteCatalog.count():
		var entry: Dictionary = EmoteCatalog.entry(emote_id)
		var button: Button = _make_button("\n" + str(entry["text"]), _on_emote_pressed.bind(emote_id), 13, entry["color"], 12)
		button.name = "Emote%d" % emote_id
		button.custom_minimum_size = Vector2(88, 74)
		button.focus_mode = Control.FOCUS_NONE
		# 얼굴은 코드로 그린다 (게임 글꼴에 이모지가 없다): 위쪽에 얼굴, 아래쪽에 문구
		var face := EmoteFace.new(entry["face"], 34.0)
		face.position = Vector2((88.0 - 34.0) / 2.0, 4.0)
		button.add_child(face)
		grid.add_child(button)


## 감정 표현은 내 자리를 직접 조작하는 판(AI 대전·온라인)에서만 쓴다. 4인 수동 조작은 기물 독이 같은 자리를 쓴다.
func _refresh_emote_row() -> void:
	if _emote_row != null:
		_emote_row.visible = (ai_mode or net != null) and not manager.is_game_over and _player_ids.has(local_player_id)
		if not _emote_row.visible:
			_close_emote_picker()


func _toggle_emote_picker() -> void:
	if _emote_picker == null:
		return
	if _emote_picker.visible:
		_close_emote_picker()
		return
	Sfx.play(&"ui_click")
	_emote_picker.visible = true
	_emote_picker.reset_size()
	var anchor: Rect2 = _emote_button.get_global_rect()
	var at: Vector2 = get_global_transform().affine_inverse() * Vector2(anchor.end.x - _emote_picker.size.x, anchor.position.y - _emote_picker.size.y - 8.0)
	_emote_picker.position = Vector2(clampf(at.x, 8.0, size.x - _emote_picker.size.x - 8.0), maxf(at.y, 8.0))
	_emote_picker.pivot_offset = Vector2(_emote_picker.size.x, _emote_picker.size.y)
	_emote_picker.scale = Vector2(0.6, 0.6)
	_emote_picker.create_tween().tween_property(_emote_picker, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_emote_picker() -> void:
	if _emote_picker != null:
		_emote_picker.visible = false


## 이모트 판 밖을 누르면 닫는다.
func _emote_picker_input(event: InputEvent) -> void:
	if _emote_picker == null or not _emote_picker.visible:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if not _emote_picker.get_global_rect().has_point(click.position) and not _emote_button.get_global_rect().has_point(click.position):
		_close_emote_picker()


func _on_emote_pressed(emote_id: int) -> void:
	_close_emote_picker()
	var now: int = Time.get_ticks_msec()
	if now < _emote_ready_msec or manager.is_game_over or not EmoteCatalog.is_valid(emote_id):
		return
	_emote_ready_msec = now + EMOTE_COOLDOWN_MSEC
	_show_emote(local_player_id, emote_id)
	if net != null:
		net.send_emote(emote_id)


func _on_net_emote(seat: int, emote_id: int) -> void:
	if not _player_ids.has(seat) or seat == local_player_id or not EmoteCatalog.is_valid(emote_id):
		return
	_show_emote(seat, emote_id)


## 이모트 재생: 아바타 표정 + 프로필 옆 말풍선. 같은 사람의 앞 말풍선은 바로 치운다.
func _show_emote(player_id: int, emote_id: int) -> void:
	if not _profiles.has(player_id):
		return
	var entry: Dictionary = EmoteCatalog.entry(emote_id)
	_avatar_react(player_id, int(entry["emotion"]) as AvatarSlot.Emotion, 2.4)
	Sfx.play(&"emote_pop")
	var previous: Variant = _emote_bubbles.get(player_id)
	if previous != null and is_instance_valid(previous):
		(previous as Node).queue_free()
	var avatar: Control = _profiles[player_id]["avatar"]
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var rect: Rect2 = to_local * avatar.get_global_rect()
	var view: Rect2 = to_local * get_viewport().get_visible_rect()
	var above: bool = rect.get_center().y > _board_center().y  # 보드 중심보다 아래 프로필은 위로, 위 프로필은 아래로 말풍선을 띄운다
	var bubble := EmoteBubble.new()
	bubble.setup(emote_id, above)
	add_child(bubble)
	var tip := Vector2(rect.get_center().x, rect.position.y - 2.0 if above else rect.end.y + 2.0)
	var x: float = clampf(tip.x - bubble.size.x * 0.3, view.position.x + 8.0, view.end.x - bubble.size.x - 8.0)
	bubble.tail_x = clampf(tip.x - x, 22.0, bubble.size.x - 22.0)
	bubble.position = Vector2(x, tip.y - bubble.size.y if above else tip.y)
	bubble.queue_redraw()
	_emote_bubbles[player_id] = bubble
	bubble.play()


## 기물 독이 보여 주는 주인: AI 모드는 항상 로컬 플레이어, 4P 수동 모드는 현재 턴 플레이어.
func _dock_owner() -> int:
	return local_player_id if ai_mode else manager.current_player_id()


## 지금 모드에서 실제로 쓰는 필살기 버튼들 (슬롯 순서): AI·온라인은 내 프로필 카드, 수동 4인은 기물 독.
func active_skill_buttons() -> Array[Button]:
	return _skill_buttons if ai_mode else _dock_skill_buttons


## 말 칸·필살기 버튼에 커서를 대면 그 말의 경로만 미리 보여 준다 (설명은 말 칸을 눌러야 열린다).
func _on_pawn_slot_hover(slot: int) -> void:
	_preview_pawn(_dock_owner() * 10 + slot + 1)


func _on_pawn_slot_unhover(_button: Button) -> void:
	_clear_highlight()


## 기물 독의 말 칸을 누르면 그 말 설명을 열고, 다시 누르면 닫는다.
func _on_pawn_slot_pressed(slot: int) -> void:
	_tip_toggle(_pawn_buttons[slot], _fill_pawn_tip.bind(_dock_owner() * 10 + slot + 1))


## 프로필의 말 칸을 누르면 그 말 설명을 열고, 다시 누르면 닫는다.
func _on_pawn_icon_input(event: InputEvent, icon: Control, pawn_id: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_tip_toggle(icon, _fill_pawn_tip.bind(pawn_id))
		icon.accept_event()


func _refresh_pawn_dock() -> void:
	_refresh_emote_row()
	# AI·온라인에서는 내 프로필 카드가 말 칸과 필살기를 맡으므로 기물 독은 4인 수동 조작에서만 보인다.
	_pawn_bar.visible = not ai_mode
	var owner_id: int = _dock_owner()
	var color: Color = PLAYER_COLORS[owner_id]
	for index: int in _pawn_buttons.size():
		var button: Button = _pawn_buttons[index]
		var parts: Dictionary = _pawn_slot_parts[index]
		var pawn: PlayerPawn = state.get_pawn(owner_id * 10 + index + 1)
		(parts["letter"] as Label).visible = false
		_token_in(button, pawn, color, Vector2(SLOT_SIZE.x/2.0,44),1.28)
		var letter: String = pawn.letter()
		(parts["letter"] as Label).text = letter if letter != "" else PawnCatalog.basic_letter()
		(parts["letter"] as Label).add_theme_color_override("font_color", Color("ff6b6b") if pawn.is_promoted_shogi() else Color("f8f9fa"))
		var place: String = "완주" if pawn.is_finished else ("대기" if not pawn.has_left_start else "%d번" % pawn.current_tile_idx)
		if pawn.blocked_this_turn or pawn.restrained_turns > 0:
			place = "구속"
		elif pawn.is_imprisoned:
			place = "감옥"
		elif pawn.revenge_boost and not pawn.has_left_start:
			place = "대기"  # 리벤지 부스터는 칸이 불타는 것으로 보여 준다 (글자 없음)
		(parts["place"] as Label).text = place
		_paint_revenge_glow(button, pawn.revenge_boost and not pawn.has_left_start and not pawn.is_finished)
		var badge: Label = parts["badge"]
		badge.visible = false
		badge.text = "x%d" % (pawn.carried.size() + 1)
		# 우측 하단 독은 내 말이 어떤 상태인지만 보여 준다 (말 고르기는 가운데 하단 배너가 맡으므로 선택 표시·클릭은 없다).
		button.disabled = false
		var base: Color = color.darkened(0.55)
		button.add_theme_stylebox_override("normal", _style(base, color.darkened(0.2), 2, 10, 2, 4))
		button.add_theme_stylebox_override("hover", _style(base.lightened(0.12), color, 2, 10, 4, 4))
		button.add_theme_stylebox_override("pressed", _style(base, color.darkened(0.2), 2, 10, 2, 4))
		button.add_theme_stylebox_override("disabled", _style(base, color.darkened(0.35), 2, 10, 0, 4))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.modulate = Color(1, 1, 1, 0.55) if pawn.is_finished else Color.WHITE
		var has_skill: bool = PawnSkills.has_skill(pawn) and not pawn.is_finished
		var usable: bool = has_skill and manager.can_use_skill(owner_id, pawn.entity_id) and not _ui_busy() and not _is_bot_turn() and not _tile_pick_active
		# AI·온라인 모드에서는 내 프로필 카드의 버튼이, 수동 4인 모드에서는 기물 독의 버튼이 필살기를 맡는다.
		var profile_button: Button = _skill_buttons[index]
		var dock_button: Button = _dock_skill_buttons[index]
		profile_button.visible = has_skill and ai_mode
		dock_button.visible = has_skill and not ai_mode
		for skill_button: Button in [profile_button, dock_button]:
			skill_button.disabled = not usable
			skill_button.modulate = Color(1.15, 1.0, 0.7) if usable else Color.WHITE
		profile_button.text = tr_ui("btn.skill_used") if pawn.skill_used else tr_ui("btn.skill")
		dock_button.text = "사용 완료" if pawn.skill_used else "필살기\n발동!"


# ---------------------------------------------------------------------------
# 말 선택 배너: 굴림 뒤 보드 아래 중앙에 자동으로 뜨는 4장의 큰 말 카드
# ---------------------------------------------------------------------------

func _build_select_banner() -> void:
	_select_banner = Panel.new()
	_select_banner.position = SELECT_BANNER_POS
	_select_banner.size = Vector2(606, 198)
	_select_banner.visible = false
	_select_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_select_banner.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.12, 0.94), COLOR_GOLD, 3, 16, 14, 0))
	add_child(_select_banner)
	_select_title = _make_label("", 18, Color("ffe066"))
	_select_title.position = Vector2(0, 4)
	_select_title.size = Vector2(606, 26)
	_select_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_title.add_theme_color_override("font_outline_color", Color("5c4300"))
	_select_title.add_theme_constant_override("outline_size", 5)
	_select_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_banner.add_child(_select_title)
	for slot: int in GameEnums.PAWNS_PER_PLAYER:
		var card := Button.new()
		card.custom_minimum_size = SELECT_CARD_SIZE
		card.size = SELECT_CARD_SIZE
		card.position = Vector2(10 + slot * (SELECT_CARD_SIZE.x + 8.0), 30)
		card.focus_mode = Control.FOCUS_NONE
		var badge := _make_label("", 13, Color("0d1018"))
		badge.position = Vector2(8, 6)
		badge.size = Vector2(56, 20)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
		var status := _make_label("", 12, Color("ced4da"))
		status.visible = false  # 출전 중·출발 대기 같은 작은 상태 글자는 그리지 않는다 (말 그림·카드 밝기가 알려 준다)
		status.position = Vector2(4, 28)
		status.size = Vector2(SELECT_CARD_SIZE.x - 8.0, 18)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status)
		var disc := Panel.new()
		disc.position = Vector2((SELECT_CARD_SIZE.x - 44.0) / 2.0, 50)
		disc.size = Vector2(44, 44)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(disc)
		var mark := _make_label("", 22, Color.WHITE)
		mark.size = Vector2(44, 44)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", 4)
		disc.add_child(mark)
		var sub := _make_label("", 16, Color.WHITE)
		sub.position = Vector2(4, 98)
		sub.size = Vector2(SELECT_CARD_SIZE.x - 8.0, 22)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_theme_color_override("font_outline_color", Color.BLACK)
		sub.add_theme_constant_override("outline_size", 3)
		card.add_child(sub)
		var result := _make_label("", 20, Color("8ce99a"))
		result.add_theme_color_override("font_outline_color", Color.BLACK)
		result.add_theme_constant_override("outline_size", 5)
		result.position = Vector2(6, 124)
		result.size = Vector2(SELECT_CARD_SIZE.x - 12.0, 36)
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(result)
		card.pressed.connect(_on_select_card_pressed.bind(slot))
		card.mouse_entered.connect(_on_select_card_hover.bind(slot, true))
		card.mouse_exited.connect(_on_select_card_hover.bind(slot, false))
		_select_banner.add_child(card)
		_select_cards.append(card)
		_select_parts.append({"badge": badge, "status": status, "disc": disc, "mark": mark, "sub": sub, "result": result})


func _queued_dice() -> int:
	return 0 if manager.move_queue.is_empty() else int(manager.move_queue[0])


## 지금 굴림 값으로 이 말을 고를 수 있는가 (후퇴 눈금이면 출발 전 말은 제외).
func _can_pick_now(pawn: PlayerPawn) -> bool:
	return state.can_pick(pawn, _queued_dice())


## 이 말이 지금 굴림 값으로 움직이면 지나갈 경로 (선택할 수 없으면 빈 배열).
func _pawn_move_path(pawn: PlayerPawn) -> Array[int]:
	if manager.move_queue.is_empty() or not _can_pick_now(pawn):
		return [] as Array[int]
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = pawn.owner_id
	ctx.dice_value = manager.move_queue[0]
	ctx.direction = state.movement_direction()
	ctx.pawn = pawn
	ctx.trigger_timing = RuleContext.ON_MOVE_CALC
	ctx.is_preview = true  # Dry-Run: 법전 로그·깜빡임 없이 수치만 계산
	ctx = state.rulebook.process_context(ctx)
	# 실제 이동과 같은 계산(포 넘기 +3, 퀸 +2 등 기물 능력 포함)으로 예상 경로를 구한다.
	return MoveExecutor.plan_path(state, pawn, ctx, MoveReport.new())


## 선택 결과 예고: {"text": 카드에 적을 짧은 한마디(처치!·완주! 등, 평범한 이동은 빈 문자열), "good": 초록 테두리로 강조할 좋은 결과}.
## 도착 칸 번호는 적지 않는다 (판에 칸 번호가 없고, 카드에 마우스를 올리면 판 위에 경로가 그려진다).
func _pawn_prediction(pawn: PlayerPawn) -> Dictionary:
	if pawn.is_finished or not pawn.is_selectable() or not _can_pick_now(pawn):
		return {"text": "", "good": false}
	var path: Array[int] = _pawn_move_path(pawn)
	if path.is_empty():
		return {"text": "", "good": false}
	if path.has(GameEnums.GOAL_TILE) and pawn.has_left_start and pawn.can_finish(state):
		return {"text": tr_ui("preview.finish"), "good": true}
	var dest: int = path.back()
	var tile: TileNode = state.board.get_tile(dest)
	var promote: bool = false
	if pawn.kind == GameEnums.PawnKind.SHOGI and not pawn.promoted:
		for step_tile: int in path:
			if BoardSpec.promotion_tiles.has(step_tile):
				promote = true
				break
	if not state.rulebook.has_law("LAW_01") and BoardSpec.jump_corner_targets.has(dest):
		return {"text": "점프!", "good": true}
	if tile.tile_type == TileNode.TileType.PORTAL and not state.rulebook.has_law("LAW_01"):
		return {"text": "워프!", "good": true}
	var allied: bool = false
	for leader: PlayerPawn in state.leaders_at(dest):
		if leader.owner_id != pawn.owner_id:
			if not MoveExecutor.is_capture_immune(state, leader):
				return {"text": "처치!", "good": true}
		elif leader != pawn:
			allied = true
	if tile.tile_type == TileNode.TileType.BAKERY:
		return {"text": "빵집!", "good": true}
	if promote:
		return {"text": "나리!", "good": true}
	if allied:
		return {"text": "합류", "good": false}
	return {"text": "", "good": false}


func _select_banner_wanted() -> bool:
	if manager.is_game_over or manager.current_state != TurnManager.State.PHASE_SELECT_PAWN:
		return false
	if _ui_busy() or _is_bot_turn() or _tile_pick_active or _draft_overlay != null or _choice_overlay != null or _result_overlay != null or _stack_overlay != null:
		return false
	return not state.selectable_pawns(manager.current_player_id(), _queued_dice()).is_empty()


func _refresh_select_banner() -> void:
	if _select_banner == null:
		return
	var wanted: bool = _select_banner_wanted()
	if not wanted:
		if _select_banner.visible:
			_stop_pawn_flash()
			_select_hover_slot = -1
		_select_banner.visible = false
		return
	var owner_id: int = manager.current_player_id()
	var color: Color = PLAYER_COLORS[owner_id]
	var steps: int = absi(manager.move_queue[0]) if not manager.move_queue.is_empty() else 0
	_select_title.text = "[어느 말을 %d칸 이동시킬까요?]" % steps
	for index: int in _select_cards.size():
		var card: Button = _select_cards[index]
		var parts: Dictionary = _select_parts[index]
		var pawn: PlayerPawn = state.get_pawn(owner_id * 10 + index + 1)
		var can_pick: bool = _can_pick_now(pawn)
		var badge: Label = parts["badge"]
		badge.text = "%d번 말" % (index + 1)
		badge.add_theme_stylebox_override("normal", _style(color.lightened(0.25) if can_pick else Color("6c757d"), Color("ffffff"), 1, 8, 0, 1))
		var status: String
		if pawn.is_finished:
			status = "★완주 완료"
		elif pawn.blocked_this_turn or pawn.restrained_turns > 0:
			status = "구속 중"
		elif pawn.is_imprisoned:
			status = "감옥"
		elif not pawn.has_left_start and pawn.revenge_boost:
			status = "출격 +%d (리벤지 부스터)" % _revenge_steps(pawn)
		elif not pawn.has_left_start:
			status = "출발 대기"
		else:
			status = "출전 중 (%d번)" % pawn.current_tile_idx
		(parts["status"] as Label).text = status
		var letter: String = pawn.letter()
		(parts["mark"] as Label).text = letter if letter != "" else PawnCatalog.basic_letter()
		(parts["disc"] as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		(parts["mark"] as Label).visible = false
		_token_in(parts["disc"], pawn, color, Vector2(22,34),0.95)
		var sub_name: String = "기본 말" if pawn.kind == GameEnums.PawnKind.BASIC else pawn.display_label().split(":")[-1]
		(parts["sub"] as Label).text = sub_name
		var prediction: Dictionary = _pawn_prediction(pawn)
		var result: Label = parts["result"]
		result.text = str(prediction["text"])
		result.add_theme_color_override("font_color", Color("8ce99a") if bool(prediction["good"]) else Color("ffe066"))
		var base: Color = Color("1b2236") if can_pick else Color("101319")
		var edge: Color = Color("69db7c") if bool(prediction["good"]) and can_pick else color.lightened(0.1)
		card.disabled = not can_pick
		card.modulate = Color.WHITE if can_pick else Color(1, 1, 1, 0.5)
		card.add_theme_stylebox_override("normal", _style(base, edge, 4 if edge != color.lightened(0.1) else 3, 12, 10 if edge != color.lightened(0.1) else 6, 0))
		card.add_theme_stylebox_override("hover", _style(base.lightened(0.15), Color("ffe066"), 4, 12, 18, 0))
		card.add_theme_stylebox_override("pressed", _style(base.darkened(0.1), COLOR_GOLD, 4, 12, 0, 0))
		card.add_theme_stylebox_override("disabled", _style(base, Color("495057"), 2, 12, 0, 0))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_select_banner.visible = true


func _on_select_card_pressed(slot: int) -> void:
	_stop_pawn_flash()
	_select_hover_slot = -1
	_on_pawn_pressed(manager.current_player_id() * 10 + slot + 1)


## 카드에 마우스를 올리면 카드가 떠오르고, 보드 위 해당 말이 크게 깜빡이며 이동 경로 타일이 굵은 노란 테두리로 표시된다.
func _on_select_card_hover(slot: int, entered: bool) -> void:
	var card: Button = _select_cards[slot]
	var tween: Tween = card.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not entered:
		tween.tween_property(card, "position:y", 30.0, 0.1)
		if _select_hover_slot == slot:
			_select_hover_slot = -1
			_stop_pawn_flash()
			_clear_highlight()
		_fade_select_banner(false)
		return
	if card.disabled:
		return
	tween.tween_property(card, "position:y", 18.0, 0.1)
	_select_hover_slot = slot
	var pawn_id: int = manager.current_player_id() * 10 + slot + 1
	_preview_pawn(pawn_id)
	_start_pawn_flash(pawn_id)
	_fade_select_banner(true)


## 호버 중에는 배너 배경과 나머지 카드를 흐리게 해서 아래 보드의 경로 표시가 잘 보이게 한다.
func _fade_select_banner(hovering: bool) -> void:
	var style: StyleBoxFlat = _style(Color(0.05, 0.07, 0.12, 0.35 if hovering else 0.94), COLOR_GOLD, 3, 16, 14, 0)
	_select_banner.add_theme_stylebox_override("panel", style)
	for index: int in _select_cards.size():
		var card: Button = _select_cards[index]
		if card.disabled:
			continue
		card.modulate = Color(1, 1, 1, 0.45) if hovering and index != _select_hover_slot else Color.WHITE


func _start_pawn_flash(pawn_id: int) -> void:
	_stop_pawn_flash()
	var view: Node2D = _pawn_views.get(pawn_id)
	var bounce: Node2D = view.get_node_or_null("Bounce") if view != null else null
	if bounce == null:
		return
	_flash_pawn = pawn_id
	_flash_tween = bounce.create_tween().set_loops()
	_flash_tween.set_parallel(true)
	_flash_tween.tween_property(bounce, "scale", Vector2.ONE * 1.8, 0.28).set_trans(Tween.TRANS_SINE)
	_flash_tween.tween_property(bounce, "modulate", Color(2.2, 2.0, 0.8), 0.28)
	_flash_tween.chain().set_parallel(true)
	_flash_tween.tween_property(bounce, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_SINE)
	_flash_tween.tween_property(bounce, "modulate", Color.WHITE, 0.28)


func _stop_pawn_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null
	if _flash_pawn != -1:
		var view: Node2D = _pawn_views.get(_flash_pawn)
		var bounce: Node2D = view.get_node_or_null("Bounce") if view != null else null
		if bounce != null:
			bounce.scale = Vector2.ONE
			bounce.modulate = Color.WHITE
		_flash_pawn = -1


# ---------------------------------------------------------------------------
# 우측 중앙 판정 도구 카드
# ---------------------------------------------------------------------------

## 도구별 [심볼 글자, 심볼 색, 전진 규칙 첫 줄, 둘째 줄].
## 판정 도구 카드 안 족보표의 한 줄 폭 (카드 폭 210에서 여백을 뺀 값).
const TOOL_RULE_WIDTH: float = 180.0

const TOOL_CARDS: Dictionary = {
	&"D6": ["6", Color("c92a2a"), "굴려서 전진한다", ""],
	&"YUT": ["윷", Color("8a5a2b"), "윷을 던져 나온 만큼 전진한다", "윷·모 재굴림 +1"],
	&"LIFE_ROULETTE": ["룰", Color("1971c2"), "룰렛을 돌려 전진한다", "7 당첨 재굴림 +1"],
	&"HOLDEM": ["♠", Color("343a40"), "카드 족보만큼 전진한다", ""],
	&"CHINCHIRO": ["친", Color("0b7285"), "주사위를 굴려 전진한다", ""],
	&"SLOT_777": ["7", Color("862e9c"), "슬롯을 돌려 전진한다", "777 잭팟 20칸"],
	&"REVOLVER": ["탄", Color("495057"), "방아쇠를 당긴 만큼 전진한다", "폭죽 발사 → 0칸·턴 종료"],
	&"DICE_HWATU": ["화", Color("c92a2a"), "화투패 족보만큼 전진한다", ""],
	&"DICE_MAHJONG": ["마", Color("2b8a3e"), "마작패 족보만큼 전진한다", "역만 재굴림 +1"],
	&"DICE_TAROT": ["타", Color("5f3dc4"), "타로를 뽑아 전진한다", "매달린 남자: 다음 +8칸"],
	&"DICE_YACHT": ["야", Color("e03131"), "주사위 5개 고정·리롤(2회)로 족보 완성!", "(트리플 5칸 / 풀하·4연속 7칸 / ★야추 12칸+한번더)"],
	&"DICE_BLACKJACK": ["21", Color("2b8a3e"), "카드 합계(11~21)에서 -10 한 만큼 전진!", "(★21 달성: 11칸+한번더 / 22↑ 초과 시 0칸 폭발!)"],
	&"DICE_PINBALL": ["핀", Color("1971c2"), "발사대를 당겨 쇠구슬 발사!", "구슬이 골인한 칸의 숫자(1 ~ 10칸)만큼 전진"],
}


## 도구별 전체 규칙표: [항목, 전진 결과] 행들과 보충 설명. 새로운 방식의 도구는 유저가 모르므로 족보·확률을 전부 보여 준다.
const TOOL_RULES: Dictionary = {
	&"D6": {"rows": [["1 ~ 6 눈금", "나온 눈금만큼"]], "note": "각 눈금 1/6"},
	&"YUT": {"rows": [["낙 (판 밖으로)", "0칸, 턴 종료"], ["도 (1)", "1칸"], ["개 (2)", "2칸"], ["걸 (3)", "3칸"], ["윷 (4)", "4칸 + 한 번 더!"], ["모 (5)", "5칸 + 한 번 더!"]], "note": "6가지 각 1/6"},
	&"LIFE_ROULETTE": {"rows": [["1 ~ 6, 8 ~ 10", "나온 숫자만큼"], ["7 당첨", "7칸 + 한 번 더!"]], "note": "1 ~ 10 균등 · 원판 돌리기"},
	&"HOLDEM": {"rows": [["노페어", "1칸"], ["원페어", "3칸"], ["투페어", "5칸"], ["트리플", "7칸"], ["스트레이트", "10칸"], ["플러시 이상", "15칸"]], "note": "5장 드로우 · 플러시 이상 15칸"},
	&"CHINCHIRO": {"rows": [["4 눈금", "4칸 (2/6)"], ["5 눈금", "5칸 (2/6)"], ["6 눈금", "6칸 (1/6)"], ["삐끗!", "이번 이동 0칸 (1/6)"]], "note": "접시 밖 이탈 = 삐끗 (후퇴는 없음)"},
	&"SLOT_777": {"rows": [["3개 모두 다름", "1칸"], ["2개 일치", "4칸"], ["3개 일치", "8칸"], ["7 7 7 잭팟", "20칸"]], "note": "릴 3개 · 그림 6종"},
	&"DICE_HWATU": {"rows": [["망통", "0칸, 턴 종료"], ["1~3 / 4~6 / 7~9끗", "2 / 3 / 4칸"], ["1~6 / 7~9땡", "6 / 7칸"], ["장땡·광땡", "8칸"]], "note": "월 합 끝자리 (망통 = 끝자리 0)"},
	&"DICE_MAHJONG": {"rows": [["핑후 (불일치)", "2칸"], ["또이츠 (같은 패 2개)", "3칸"], ["슌쯔 (연속 숫자)", "5칸"], ["커쯔 (같은 패 3개)", "8칸"], ["역만 (8%)", "12칸 + 한 번 더!"]], "note": "역만 = 국사무쌍·대삼원"},
	&"DICE_TAROT": {"rows": [["0. 광대", "0칸, 턴 종료"], ["VII. 전차", "6칸"], ["X. 운명의 수레바퀴", "4칸 + 한 번 더!"], ["XII. 매달린 남자", "1칸, 다음 굴림 +8칸"], ["XXI. 세계", "9칸"]], "note": "5장 중 1장 · 축복은 다음 굴림"},
	&"REVOLVER": {"rows": [["방아쇠 1회", "+3칸 누적"], ["최대 누적", "15칸"], ["폭죽 (6칸 중 1칸)", "누적 0칸, 턴 종료"], ["멈추기", "누적한 칸만큼 이동"]], "note": "6칸 중 1칸은 폭죽 · 깃발이 나오면 누적 소멸"},
	&"DICE_YACHT": {"rows": [["찬스 (족보 없음)", "최고 눈÷2 올림 (1~3칸)"], ["트리플 (3개 동일)", "5칸"], ["4연속 / 풀하우스", "7칸"], ["포카드 / 5연속", "9칸"], ["★ 야추 (5개 동일)", "12칸 + 한 번 더!"]], "note": "고정(Keep)하고 나머지를 최대 2번 다시 굴림"},
	&"DICE_BLACKJACK": {"rows": [["시작", "합 11 이상까지 받음"], ["11 ~ 20 스탠드", "(합 - 10)칸"], ["★ 정확히 21", "11칸 + 한 번 더!"], ["22 이상 (버스트)", "0칸, 턴 종료"]], "note": "A는 11 (넘으면 1) · 히트로 더 뽑거나 스탠드로 확정"},
	&"DICE_PINBALL": {"rows": [["하단 구멍 7칸", "2·4·6·★10·5·3·1"], ["골인한 구멍", "그 숫자만큼 (1~10칸)"], ["★10 구멍", "가장 드문 대박"]], "note": "발사 버튼을 꾹 눌렀다 놓으면 발사"},
}


func _refresh_tool_board(tool: BaseJudgmentTool, player_id: int) -> void:
	var card: Array = TOOL_CARDS.get(tool.tool_id, ["?", Color("495057"), tool.display_name, ""])
	_tool_board_key = "%d:%s" % [player_id, tool.tool_id]
	_tool_icon.add_theme_stylebox_override("panel", _style(card[1], (card[1] as Color).lightened(0.4), 2, 12, 0, 0))
	_tool_icon_label.text = card[0]
	_tool_icon_art.texture = AugmentArt.load_first(AugmentArt.tool_candidates(tool.tool_id))
	_tool_icon_art.visible = _tool_icon_art.texture != null
	_tool_icon_label.visible = _tool_icon_art.texture == null
	_tool_title.text = tool.display_name
	_tool_title.add_theme_color_override("font_color", UiSkin.INK)
	_tool_main.text = GameData.text("dice", tool.tool_id, "desc", str(card[2]))  # dice_table.csv의 desc
	var rules: Dictionary = TOOL_RULES.get(tool.tool_id, {})
	var sub: String = card[3]
	_tool_sub.text = sub
	_tool_sub.visible = sub != "" and rules.is_empty()
	if _tool_rules_key != str(tool.tool_id):
		_tool_rules_key = str(tool.tool_id)
		_rebuild_tool_rules(rules, card[1])
	_apply_tool_expand()
	_tool_board.reset_size()
	_place_action_row_below_tool_card()


## 규칙표를 다시 그린다: 행마다 [항목 ......... 결과] 한 줄.
## 라벨 글자가 한 줄로 차지하는 폭.
func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


func _rebuild_tool_rules(rules: Dictionary, _accent: Color) -> void:
	for child: Node in _tool_rules.get_children():
		_tool_rules.remove_child(child)
		child.queue_free()
	var rows: Array = rules.get("rows", [])
	for index: int in rows.size():
		var pair: Array = rows[index]
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", UiSkin.panel("inset", 2.0))
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		# 카드 폭(TOOL_RULE_WIDTH)을 넘는 줄만 줄바꿈한다: 긴 족보(야추·블랙잭·핀볼)가 카드를 넓혀 화면 오른쪽 밖으로 잘렸다.
		var name_label := _make_label(str(pair[0]), 12, UiSkin.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(name_label)
		var value_label := _make_label(str(pair[1]), 12, UiSkin.GREEN)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_width: float = _text_width(name_label)
		var value_width: float = _text_width(value_label)
		var gap: float = float(line.get_theme_constant("separation"))
		if name_width + value_width + gap > TOOL_RULE_WIDTH:
			var value_room: float = minf(value_width, TOOL_RULE_WIDTH * 0.5)
			value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			value_label.custom_minimum_size = Vector2(value_room, 0)
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_label.custom_minimum_size = Vector2(TOOL_RULE_WIDTH - value_room - gap, 0)
		line.add_child(value_label)
		_tool_rules.add_child(row)
	_tool_note.text = str(rules.get("note", ""))
	_apply_tool_expand()


func _category_text(category: GameEnums.CardCategory) -> String:
	match category:
		GameEnums.CardCategory.TRAP: return "타일 설치형 (사용 후 보드판의 타일을 클릭)"
		GameEnums.CardCategory.SUMMON: return "중립 NPC 소환형"
	return "즉발·개입형"


## 지금 이 플레이어에게 열린 방어 대기(피격 팝업)에 이 카드를 낼 수 있는가.
func _counter_offered_to(player_id: int, card_id: StringName) -> bool:
	if manager == null or not manager.counter_pending():
		return false
	var offer: Dictionary = manager.pending_counter()
	return int(offer["victim"]) == player_id and (offer.get("cards", []) as Array).has(card_id)


## 손패에서 끌어 쓸 수 있는가. 방어 카드는 끌어 쓰지 않고 피격 팝업에서만 내므로 언제나 false다.
func _card_usable_now(player_id: int, card: BaseCard) -> bool:
	if card.category == GameEnums.CardCategory.COUNTER:
		return false
	if manager.is_game_over or _ui_busy() or manager.stack_offer_pending() or manager.duel_pending() or not card.is_playable_in(manager.current_state):
		return false
	if ai_mode and player_id != local_player_id:
		return false
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and (player_id != manager.current_player_id() or manager.card_played_this_turn()):
		return false
	if state.is_banned(player_id) or not card.could_play(state, player_id):
		return false  # 지금은 대상이 없다 (예: UDO +4의 다음 차례 사람이 보드에 말이 없음): 흐리게 두고 이유는 _card_block_reason
	return true


## 지금 이 카드를 낼 수 없는 이유 (낼 수 있으면 빈 문자열). 카드를 눌렀는데 아무 일도 없던 것처럼 보이지 않게 화면에 띄운다.
func _card_block_reason(player_id: int, card: BaseCard) -> String:
	if state.is_banned(player_id):
		return "알고리즘 밴! %d턴 동안 카드를 쓸 수 없습니다" % int(state.banned_turns[player_id])
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and manager.card_played_this_turn():
		return "카드는 굴리기 전에 턴당 1장만 쓸 수 있습니다"
	if card.could_play(state, player_id):
		return ""
	match card.card_id:
		&"ACT_03":
			var victim: int = PenaltyBombCommand.victim_of(state, player_id)
			if victim == -1:
				return "[UDO +4] 폭탄을 넘길 다음 사람이 없습니다"
			return "[UDO +4] 다음 차례인 %s의 말이 보드 위에 없어 쓸 수 없습니다" % _player_name(victim)
	return "[%s] 지금은 대상이 없어 쓸 수 없습니다" % card.display_name


func _refresh_controls() -> void:
	var player_id: int = manager.current_player_id()
	var current_phase: TurnManager.State = manager.current_state
	var tool: BaseJudgmentTool = state.tools[player_id]
	var over: bool = manager.is_game_over
	var can_roll: bool = not over and (current_phase == TurnManager.State.PHASE_TURN_BEGIN or current_phase == TurnManager.State.PHASE_ROLL_WAIT)
	_roll_button.disabled = not can_roll or _tile_pick_active or _ui_busy() or manager.stack_offer_pending() or manager.duel_pending() or _is_bot_turn()
	_refresh_roll_pad()
	_refresh_tool_stage()
	var can_stop: bool = not over and tool.has_pending_state() and current_phase == TurnManager.State.PHASE_ROLL_WAIT
	if tool is ToolRussianRoulette:
		# 러시안 룰렛: [방아쇠 당기기]와 [멈추고 N칸 이동 확정]을 한 세트로 상시 노출한다. 1발도 못 당겼으면 멈추기는 비활성(회색)이고,
		# 누적이 생기면 초록색으로 바뀐다.
		_roll_button.text = "방아쇠\n당기기"
		_set_gun_buttons(true)
		_stop_button.visible = not over
		_stop_button.text = "정지"
		# 이어서 당기는 중(내 리볼버가 생존 결과로 짧게 철컥하는 동안): 버튼을 회색으로 바꿨다 되돌리면 당길 때마다 깜빡인다.
		# 모양은 그대로 두고 그동안 클릭만 무시한다 (키 입력은 _roll_button.disabled가 막는다).
		var mid_pull: bool = _fx_busy and _roll_pad.kind == RollPad.Kind.REVOLVER and _roll_pad.active and not _roll_pad.preparing and can_stop and not _is_bot_turn() and manager.current_player_id() == _dock_owner()
		_fire_button.disabled = (_roll_button.disabled or _roll_pad.active) and not mid_pull
		_stop_button.disabled = (not can_stop or _tile_pick_active or _is_bot_turn() or _ui_busy() or _roll_pad.active) and not mid_pull
		for gun_button: Button in [_fire_button, _stop_button]:
			gun_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if mid_pull else Control.MOUSE_FILTER_STOP
		_stop_button.modulate = Color(0.55, 1.0, 0.62) if can_stop else Color.WHITE
	else:
		_set_gun_buttons(false)
		_roll_button.text = _roll_button_label(tool)
		_stop_button.visible = can_stop and not _is_stage_tool(tool.tool_id)  # 야추·블랙잭은 스테이지에 자기 확정 버튼이 있다
		_stop_button.text = "멈추고 이동 확정"
		_stop_button.disabled = false
		_stop_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_stop_button.modulate = Color.WHITE
	_refresh_tool_board(state.tools[_dock_owner()], _dock_owner())
	# 개입 창은 이제 피해를 되돌리는 카드(ACT_05) 하나뿐이라 가운데 팝업(_update_reaction_popup)이 맡는다. 예전 [개입 패스] 버튼은 쓰지 않는다.
	_skip_button.visible = false
	_hint_label.text = _hint_text(current_phase, tool)

	_refresh_pawn_dock()
	_refresh_select_banner()
	_tool_option.disabled = over or not (current_phase == TurnManager.State.PHASE_TURN_BEGIN or current_phase == TurnManager.State.PHASE_ROLL_WAIT) or tool.has_pending_state()
	var tool_index: int = ToolRegistry.ALL_IDS.find(tool.tool_id)
	if tool_index != -1:
		_tool_option.select(tool_index)


## 러시안 룰렛이면 정지 버튼을 [발사] 옆 큰 버튼으로 옮기고, 다른 도구면 원래 자리(우측 버튼 줄)로 돌려보낸다.
func _set_gun_buttons(gun: bool) -> void:
	var wanted_parent: Node = _gun_row if gun else _action_row
	if _stop_button.get_parent() != wanted_parent:
		_stop_button.reparent(wanted_parent, false)
		if gun:
			wanted_parent.move_child(_stop_button, wanted_parent.get_child_count() - 1)
		else:
			wanted_parent.move_child(_stop_button, 0)
	_stop_button.custom_minimum_size = Vector2(150, 58) if gun else Vector2(150, 30)
	_stop_button.add_theme_font_size_override("font_size", 24 if gun else 13)
	_gun_row.visible = gun and _gun_row.visible


## 주사위 계열 도구인가 (굴림 소리가 주사위 던지는 소리다).
func _is_dice_family(tool: BaseJudgmentTool) -> bool:
	return tool.tool_id == &"D6" or tool.tool_id == &"CHINCHIRO" or tool.tool_id == &"YUT" or tool.tool_id == &"DICE_YACHT" or tool.tool_id == &"DICE_HWATU" or tool.tool_id == &"DICE_MAHJONG" or tool.tool_id == &"DICE_TAROT"


## 굴림 버튼에 쓰는 글자: 도구마다 다르다.
func _roll_button_label(tool: BaseJudgmentTool) -> String:
	if tool is ToolHwatu:
		return "패\n뒤집기"
	if tool is ToolHoldem:
		return "카드 뽑기"
	if tool is ToolSlot777:
		return "레버 당기기"
	if tool is ToolMahjong:
		return "쯔모!"
	if tool is ToolTarot:
		return "운명\n뽑기"
	if tool is ToolPinball:
		return "발사!"
	return tr_ui("btn.roll")


## 굴림 조작 방식: 차징형(기본 주사위·윷·친치로)은 보드 아래 작은 굴리기 버튼+파워 게이지, 그 외(룰렛 원판·리볼버·홀덤/슬롯 큰 버튼)는 보드 한가운데에 크게 보여 준다.
func _roll_mode_for(tool: BaseJudgmentTool) -> StringName:
	if tool is ToolLifeRoulette:
		return &"wheel"
	if tool is ToolRussianRoulette:
		return &"gun"
	if tool is ToolHoldem or tool is ToolSlot777 or tool is ToolHwatu or tool is ToolMahjong or tool is ToolTarot:
		return &"big"
	if tool is ToolYacht or tool is ToolBlackjack:
		return &"stage"
	if tool is ToolPinball:
		return &"pinball"
	return &"charge"


## 내 판정 도구에 맞는 굴림 위젯을 보여 준다.
## 굴리기 화면(굴리기 버튼·룰렛/리볼버 패드·야추/블랙잭/핀볼 스테이지)을 띄워도 되는가.
## 앞선 연출이 하나라도 남아 있으면(라운드·차례 배너, 연출 큐, 처치 컷인, 오프닝·드래프트·확인 창) 띄우지 않는다.
## 카드를 끌거나 칸을 고르는 중, 필살기를 겨누는 중에도 화면을 끄고 그 연출을 보여 준다 (끝나면 다시 뜬다).
func _roll_view_allowed() -> bool:
	if manager.is_game_over or not (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN or manager.current_state == TurnManager.State.PHASE_ROLL_WAIT):
		return false
	if _intro_blocks() or _turn_banner_pending() or (_announcer != null and _announcer.holding()):
		return false
	if _presentation_active() or (_capture_cutin != null and _capture_cutin.busy()) or _stage_warps > 0:
		return false
	if _foreign_roll_fx():
		return false  # 앞 사람의 굴림 연출(리볼버·룰렛·주사위 등)이 아직 보이는 동안 다음 사람의 굴리기 화면을 겹쳐 띄우지 않는다
	if _tile_pick_active or _aim_pawn != -1 or _drag_active:
		return false
	if _draft_overlay != null or (_review_overlay != null and is_instance_valid(_review_overlay)):
		return false
	return true


func _refresh_roll_pad() -> void:
	# A fired outcome advances the engine turn immediately. Keep the current
	# visual until its local timeline finishes, even if the next tool differs.
	if _fx_busy and _roll_pad.active:
		_roll_pad.set_enabled(false)
		_gun_row.visible = _roll_pad.kind == RollPad.Kind.REVOLVER
		return
	var owner_tool: BaseJudgmentTool = state.tools[_dock_owner()]
	var mode: StringName = _roll_mode_for(owner_tool)
	var wanted: RollPad.Kind = RollPad.Kind.NONE
	if mode == &"wheel":
		wanted = RollPad.Kind.ROULETTE
	elif mode == &"gun":
		wanted = RollPad.Kind.REVOLVER
	_roll_pad.instant = instant_roll_for_test
	if _roll_pad.kind != wanted:
		_roll_pad.set_kind(wanted)
	if mode == &"big" or mode == &"charge" or mode == &"pinball":
		_roll_button.text = _roll_button_label(owner_tool)  # 글자를 먼저 바꿔야 새 크기가 이전 글자 폭에 눌리지 않는다
	if mode != _roll_geometry:
		_set_roll_geometry(mode)
	# 굴림 위젯은 굴릴 차례에만 보인다. 굴림이 끝나면 지워서 보드 한가운데가 가리지 않게 한다 (룰렛·리볼버 패드는 돌아가는 연출 중에는 남긴다).
	# 중앙 알림(라운드 시작·차례 알림 등)·오프닝이 떠 있는 동안에는 숨겼다가, 알림이 끝나면(drained -> _refresh_all) 다시 나온다.
	var roll_phase: bool = _roll_view_allowed() and not _is_bot_turn()
	# 연출 중에 남겨 두는 것은 '내 도구'가 굴러가는 연출일 때뿐이다 (다른 사람이 굴리는 동안 내 리볼버·룰렛이 밑에 비치지 않게).
	# 앞 사람의 굴림 연출기(_presenter)가 아직 보이면 그 _fx_busy는 내 도구의 연출이 아니다 (차례가 막 넘어온 순간 내 리볼버가 먼저 떴다 숨는 깜빡임 방지).
	var own_fx: bool = _fx_busy and manager.current_player_id() == _dock_owner() and not _presenter_showing()
	_roll_button.visible = wanted == RollPad.Kind.NONE and roll_phase and mode != &"stage"
	if wanted != RollPad.Kind.NONE:
		_roll_pad.visible = roll_phase or own_fx or _roll_pad.active
	_gun_row.visible = wanted == RollPad.Kind.REVOLVER and (roll_phase or own_fx or _roll_pad.active)
	if mode == &"big" or mode == &"charge" or mode == &"pinball":
		_roll_button.text = _roll_button_label(owner_tool)
	_roll_pad.set_enabled(not _roll_button.disabled)
	if wanted == RollPad.Kind.REVOLVER and roll_phase and not _ui_busy():
		var gun_key: String = "%d:%d:%d:%d" % [state.get_instance_id(),state.round_number,_dock_owner(),owner_tool.get_instance_id()]
		_roll_pad.ensure_revolver_prepared(gun_key,owner_tool.has_pending_state())


## 굴림 위젯의 크기·위치를 방식에 맞춘다: charge는 중앙 무대 아래쪽에 작게(120px), 그 외는 보드 한가운데 크게(버튼 190px / 패드 1.9배).
func _set_roll_geometry(mode: StringName) -> void:
	_roll_geometry = mode
	var big: bool = mode != &"charge" and mode != &"pinball"
	var diameter: float = 190.0 if mode == &"big" else (110.0 if mode == &"pinball" else 120.0)
	var center: Vector2 = Vector2(683.0, 335.0) if mode == &"big" else (Vector2(940.0, 470.0) if mode == &"pinball" else Vector2(683.0, 380.0))
	_roll_button.custom_minimum_size = Vector2(diameter, diameter)
	_roll_button.size = Vector2(diameter, diameter)
	_roll_button.add_theme_font_size_override("font_size", 32 if mode == &"big" else 24)
	_apply_round_button_style(_roll_button, Color("2b8a3e"))
	_set_layout_base(_roll_button, center - Vector2(diameter, diameter) / 2.0)
	_roll_pad.pivot_offset = _roll_pad.size / 2.0
	_roll_pad.scale = Vector2(1.9, 1.9) if big else Vector2.ONE
	_roll_pad.set_text_scale(_roll_pad.scale.x)  # 키운 패드의 글자는 화면 픽셀 크기로 다시 그린다 (흐림 방지)
	_apply_layout_now()


## 등록된 배치 노드의 기준 위치를 바꾼다.
func _set_layout_base(node: CanvasItem, base: Vector2) -> void:
	for entry: Dictionary in _layout_entries:
		if entry["node"] == node:
			entry["base"] = base


func _apply_layout_now() -> void:
	var window_size: Vector2i = DisplayServer.window_get_size()
	layout_for(get_viewport_rect().size if window_size.x > 0 and window_size.y > 0 else DESIGN_SIZE)


## 룰렛 원판을 돌려 놓았다: 돌린 속도가 연출 세기가 되고 굴림은 평소처럼 엔진이 정한다.
func _on_pad_spin_released(power: float) -> void:
	_roll_with_power(power)


func _on_pad_trigger_pulled() -> void:
	if _roll_pad.preparing or _roll_pad.active:
		return
	_roll_with_power(0.5)


func _roll_with_power(power: float) -> void:
	_pending_power = power
	if manager.is_game_over or _roll_button.disabled or _ui_busy() or _is_bot_turn() or _roll_pad.preparing:
		return
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_act(&"proceed")
	if manager.current_state == TurnManager.State.PHASE_ROLL_WAIT:
		_act(&"roll")


func _hint_text(current_phase: TurnManager.State, tool: BaseJudgmentTool) -> String:
	if manager.is_game_over:
		return "게임 종료. [새 게임]으로 다시 시작하세요."
	if _fx_busy:
		return "굴러가는 중..."
	if manager.counter_pending():
		var victim: int = int(manager.pending_counter()["victim"])
		if _reaction_holder() == victim:
			return "공격당했습니다! 가운데 방어 팝업에서 방어 카드를 고르거나 [그냥 맞기]를 누르세요. 시간이 지나면 그냥 맞습니다."
		return "%s이(가) 방어할지 고르는 중입니다..." % _player_name(victim)
	if _is_bot_turn() and not manager.stack_offer_pending() and current_phase != TurnManager.State.PHASE_INTERRUPT_ROLL and current_phase != TurnManager.State.PHASE_RESOLUTION:
		if net != null and not net.is_bot(manager.current_player_id()):
			return "%s 님의 차례입니다. 기다려 주세요..." % _player_name(manager.current_player_id())
		return "P%d (AI 봇)가 생각하는 중입니다..." % manager.current_player_id()
	if (current_phase == TurnManager.State.PHASE_INTERRUPT_ROLL or current_phase == TurnManager.State.PHASE_RESOLUTION) and not manager.stack_offer_pending():
		return "정산 중입니다..."
	if manager.stack_offer_pending():
		return "아군 말 업기: [업기 (하나로 합체)] 또는 [그냥 두기 (개별 유지)]를 고르세요. (시간이 지나면 자동으로 업기)"
	if _tile_pick_active:
		return "타일 선택 모드: 보드판에서 사용할 타일(초록 테두리)을 클릭하세요. 취소는 ESC 또는 오른쪽 클릭."
	match current_phase:
		TurnManager.State.PHASE_TURN_BEGIN:
			return "카드(▣ 표시는 타일을 클릭해 설치/소환)를 쓰거나 [굴리기] 버튼(또는 R/Space)을 한 번 누르세요. (판정 도구: %s)" % tool.display_name
		TurnManager.State.PHASE_ROLL_WAIT:
			if tool.has_pending_state() and tool is ToolYacht:
				return "고정할 주사위를 클릭하고 [나머지 다시 굴리기], 마음에 들면 [현재 족보로 이동 확정]을 누르세요."
			if tool.has_pending_state() and tool is ToolBlackjack:
				return "[히트]로 카드를 더 뽑거나 [스탠드]로 (합계-10)칸 이동을 확정하세요. 22 이상이면 버스트!"
			if tool.has_pending_state():
				return "계속 당기거나, 멈추고 누적 칸수만큼 이동하세요. 깃발이 나오면 누적이 사라져요!"
			return "다시 굴려야 합니다 (재굴림)." if not manager.move_queue.is_empty() else "굴리기 버튼(또는 R/Space)을 한 번 누르세요."
		TurnManager.State.PHASE_INTERRUPT_ROLL:
			return "[개입 기회! 카드를 사용하거나 '패스'를 누르세요]  눈금이 정해졌습니다. 개입 카드를 가진 플레이어는 지금 카드를 누르세요."
		TurnManager.State.PHASE_SELECT_PAWN:
			return "이동할 말을 고르세요 (버튼에 마우스를 올리면 도착 경로가 노란 테두리로 보입니다)."
		TurnManager.State.PHASE_RESOLUTION:
			return "[개입 기회! 카드를 사용하거나 '패스'를 누르세요]  잡힌 플레이어는 [바이츠 더 더스트]로 되감을 수 있습니다."
		TurnManager.State.PHASE_MOVING_STEP:
			return "말이 한 칸씩 이동합니다..."
		TurnManager.State.PHASE_ROUND_START:
			return "라운드 시작 증강 드래프트 중입니다."
	return ""


# ---------------------------------------------------------------------------
# 버튼 입력 (모든 행동은 TurnManager.act()로만 보낸다)
# ---------------------------------------------------------------------------

func _act(action: StringName, params: Dictionary = {}) -> void:
	if params.get("player_id") == null:
		params["player_id"] = manager.current_player_id()
	manager.act(action, params)
	_refresh_all()


func _on_roll_pressed() -> void:
	# 원클릭: 누르고 있을 필요 없이 한 번 누르면 바로 굴러간다. 연출 세기는 도구마다 경쾌한 고정값을 쓴다.
	_pending_power = ONE_CLICK_POWER
	if manager.is_game_over or _roll_button.disabled or _ui_busy() or _is_bot_turn() or _roll_pad.preparing:
		return  # 리볼버 장전 연출 중에 쏘면 3D 화면에 장전 자세가 한두 프레임 다시 비친다 (발사 버튼과 같은 조건)
	var tool: BaseJudgmentTool = state.tools[_dock_owner()]
	# Yut, Mahjong, cards, roulette, slots and the toy gun emit their own
	# material sounds at animation cues. Only dice need the generic clatter.
	if _is_dice_family(tool) and tool.tool_id != &"YUT":
		Sfx.play(&"dice_roll")
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_act(&"proceed")
	if manager.current_state == TurnManager.State.PHASE_ROLL_WAIT:
		_act(&"roll")


## R / Space 키 한 번으로 굴린다 (굴림 버튼을 한 번 누른 것과 같다).
func _roll_by_key() -> void:
	if _roll_button.disabled or _ui_busy() or manager.is_game_over or _stack_overlay != null or _is_bot_turn() or _tile_pick_active:
		return
	if state != null and _is_stage_tool(state.tools[manager.current_player_id()].tool_id):
		return  # 야추·블랙잭은 스테이지의 버튼으로만 조작한다
	_on_roll_pressed()


func _on_stop_pressed() -> void:
	if _stop_button.disabled or _roll_pad.active:
		return  # 리볼버가 철컥하는 연출 중(버튼 모양은 그대로 둔다)에는 정지를 받지 않는다
	_act(&"stop")


func _on_skip_pressed() -> void:
	manager.force_timeout()
	_refresh_all()




func _on_pawn_pressed(pawn_id: int) -> void:
	_stop_pawn_flash()
	_clear_highlight()
	_act(&"select_pawn", {"pawn_id": pawn_id})


func _on_add_law_pressed(law_id: String) -> void:
	if state.rulebook.has_law(law_id):
		_log_line("[%s]는 이미 법전에 있습니다." % law_id, Color("868e96"))
		return
	state.rulebook.enqueue_law(LawRegistry.create(law_id))
	_refresh_all()


func _on_tool_selected(index: int) -> void:
	var player_id: int = manager.current_player_id()
	var new_tool: BaseJudgmentTool = ToolRegistry.create(ToolRegistry.ALL_IDS[index])
	state.tools[player_id] = new_tool
	_log_line("P%d의 판정 도구를 [%s](으)로 바꿨습니다." % [player_id, new_tool.display_name], Color("adb5bd"))
	_refresh_all()


func _on_grant_card_pressed() -> void:
	var card_id: StringName = _card_option.get_item_metadata(_card_option.selected)
	if not state.give_card(manager.current_player_id(), card_id):
		_log_line("손패가 가득 찼습니다.", Color("868e96"))
	_refresh_all()


func _on_spawn_npc_pressed(behavior: GameEnums.NpcBehavior, tile: int) -> void:
	var display_id: StringName = &"SUM_01" if behavior == GameEnums.NpcBehavior.CHASE_NEAREST else &"SUM_02"
	state.spawn_npc(tile, behavior, manager.current_player_id(), display_id)


func _on_card_pressed(player_id: int, card_id: StringName) -> void:
	var card: BaseCard = CardRegistry.get_card(card_id)
	if card is CardCounter:
		if manager.counter_pending() and int(manager.pending_counter()["victim"]) == player_id and card.could_play(state, player_id):
			_on_reaction_use(player_id, card_id)
		else:
			_log_line("[%s] 방어 카드는 공격을 받았을 때 뜨는 방어 팝업에서 씁니다." % card.display_name, Color("868e96"))
		return
	var blocked: String = _card_block_reason(player_id, card)
	if blocked != "":
		_log_line(blocked, Color("ff8787"))
		_show_center_banner(blocked, Color("ff8787"))  # 숨은 로그만 남기면 눌러도 아무 반응이 없는 것처럼 보인다
		Sfx.play(&"bad", -6.0)
		return
	if card.needs_tile():
		_begin_tile_pick(player_id, card_id)
		return
	match card_id:
		&"ACT_02":
			_begin_snipe_pick(player_id, card_id)
		&"ACT_09":
			if DuelRules.targets(state, player_id).is_empty():
				_log_line("[%s] 보드 위에 나와 있는 상대 말이 없습니다." % card.display_name, Color("868e96"))
				return
			var duel_target: int = _duel_drop_target
			_duel_drop_target = -1
			_act(&"play_card", {"player_id": player_id, "card_id": card_id, "target_player": duel_target})
		&"ACT_06":
			var options: Array[Dictionary] = []
			for choice: Dictionary in CardObjection.choices(state):
				var law: VictoryLaw = LawRegistry.create(choice["law_id"]) as VictoryLaw
				var target: int = int(choice["target_player"])
				options.append({"label": "%s - %s (%d%s)" % [_player_name(target), law.law_name, law.progress(state, target), law.unit()], "value": choice})
			if options.is_empty():
				_log_line("초기화할 특수 승리 기록이 없습니다.", Color("868e96"))
				return
			_show_choice("이의 있음! 누구의 어떤 기록을 0으로 되돌릴까요?", options, _play_card_with_dict.bind(player_id, card_id))
		&"ACT_07":
			var sides: Array[Dictionary] = []
			for side: int in 4:
				if TowerCommand.has_attachments(state, side):
					var tiles: Array[int] = TowerCommand.side_tiles(side)
					sides.append({"label": "%d번 변 (%d~%d번 칸)" % [side + 1, tiles[0], tiles[-1]], "value": side})
			if sides.is_empty():
				_log_line("무너뜨릴 설치물이 보드에 없습니다.", Color("868e96"))
				return
			_show_choice("무너지는 탑! 설치물을 무너뜨릴 변을 고르세요", sides, _play_card_with.bind(player_id, card_id, "side"))
		&"ACT_11":
			var faces: Array[Dictionary] = []
			for steps: int in range(CardStatus.MIN_STEPS, CardStatus.MAX_STEPS + 1):
				faces.append({"label": "%d칸" % steps, "value": steps})
			_show_choice("싸늘한 밑장빼기! 다음 굴림 결과를 고르세요", faces, _play_card_with.bind(player_id, card_id, "steps"), 3)
		&"ACT_14", &"ACT_15":
			var targets: Array[Dictionary] = []
			for target: int in StatusCardCommand.targets(state, player_id):
				targets.append({"label": _player_name(target), "value": target})
			if targets.is_empty():
				return
			_show_choice("[%s] 대상을 고르세요" % card.display_name, targets, _play_card_with.bind(player_id, card_id, "target_player"))
		_:
			_act(&"play_card", {"player_id": player_id, "card_id": card_id})


func _play_card_with(value: Variant, player_id: int, card_id: StringName, param_name: String) -> void:
	_act(&"play_card", {"player_id": player_id, "card_id": card_id, param_name: value})


func _play_card_with_dict(value: Variant, player_id: int, card_id: StringName) -> void:
	var params: Dictionary = (value as Dictionary).duplicate()
	params["player_id"] = player_id
	params["card_id"] = card_id
	_act(&"play_card", params)


# ---------------------------------------------------------------------------
# 1회용 필살기 (기물 독의 [필살기 발동] 버튼)
# ---------------------------------------------------------------------------

func _on_skill_pressed(slot: int) -> void:
	var owner_id: int = _dock_owner()
	var pawn: PlayerPawn = state.get_pawn(owner_id * 10 + slot + 1)
	if pawn == null or not manager.can_use_skill(owner_id, pawn.entity_id) or _ui_busy():
		_log_line("지금은 필살기를 쓸 수 없습니다 (내 턴 시작, 굴리기 전에만 가능).", Color("868e96"))
		return
	_start_skill(pawn)


## 기물의 필살기를 시작한다: 룩은 맞바꿀 아군 선택, 차는 즉시 돌진, 비행기는 목적지 타일 선택, 흑돌은 조준 모드.
func _start_skill(pawn: PlayerPawn) -> void:
	match PawnCatalog.skill_of(pawn.sub_type()):
		&"castle":
			var partners: Array[PlayerPawn] = PawnSkills.rook_partners(state, pawn)
			if partners.is_empty():
				_log_line("[단독 캐슬링] 위치를 맞바꿀 아군 기물이 보드 위에 없습니다.", Color("868e96"))
				return
			if partners.size() == 1:
				_act(&"use_skill", {"pawn_id": pawn.entity_id, "partner": partners[0].entity_id})
				return
			var options: Array[Dictionary] = []
			for partner: PlayerPawn in partners:
				options.append({"label": "%s (%d번 타일)" % [partner.display_label(), partner.current_tile_idx], "value": partner.entity_id})
			_show_choice("룩과 위치를 맞바꿀 아군 기물", options, _on_rook_partner_picked.bind(pawn.entity_id))
		&"charge":
			if PawnSkills.chariot_path(state, pawn).is_empty():
				_log_line("[직선 전차 저격] 돌진할 길이 없습니다.", Color("868e96"))
				return
			_act(&"use_skill", {"pawn_id": pawn.entity_id})
		&"warp": _begin_skill_tile_pick(pawn)
		&"shoot": _begin_aim(pawn)
		&"drop":
			var waiting: Array[PlayerPawn] = PawnSkills.drop_partners(state, pawn)
			if waiting.is_empty() or PawnSkills.drop_tile(state, pawn) == -1:
				_log_line("[모치고마 낙하] 출발선에서 대기 중인 내 말이 없거나 낙하할 자리가 없습니다.", Color("868e96"))
				return
			if waiting.size() == 1:
				_act(&"use_skill", {"pawn_id": pawn.entity_id, "partner": waiting[0].entity_id})
				return
			var drop_options: Array[Dictionary] = []
			for partner: PlayerPawn in waiting:
				drop_options.append({"label": "말 %d번 (출발 대기)" % partner.slot, "value": partner.entity_id})
			_show_choice("낙하시킬 대기 말", drop_options, _on_drop_partner_picked.bind(pawn.entity_id))
		&"fianchetto":
			if PawnSkills.fianchetto_tile(pawn) == -1:
				_log_line("[피앙케토] 대각선 코너가 결승선 너머라 쓸 수 없습니다.", Color("868e96"))
				return
			_act(&"use_skill", {"pawn_id": pawn.entity_id})
		&"bank_shot":
			if PawnSkills.bank_shot_path(state, pawn).is_empty():
				_log_line("[뱅크샷] 앞쪽에 들이받을 적이 없습니다.", Color("868e96"))
				return
			_act(&"use_skill", {"pawn_id": pawn.entity_id})
		&"quake", &"slash", &"horse", &"plant_mine", &"hotel":
			_act(&"use_skill", {"pawn_id": pawn.entity_id})


func _on_drop_partner_picked(value: Variant, fu_id: int) -> void:
	_act(&"use_skill", {"pawn_id": fu_id, "partner": int(value)})


func _on_rook_partner_picked(value: Variant, rook_id: int) -> void:
	_act(&"use_skill", {"pawn_id": rook_id, "partner": int(value)})


## 비행기 직항 워프: 날아갈 수 있는 빵집·코너 타일을 초록 테두리로 켜고 고르게 한다 (일반 타일 선택 모드를 재사용).
func _begin_skill_tile_pick(pawn: PlayerPawn) -> void:
	_tile_pick_active = true
	_tile_pick_player = pawn.owner_id
	_tile_pick_card = &""
	_tile_pick_skill_pawn = pawn.entity_id
	var targets: Array[int] = PawnSkills.plane_targets(pawn)
	for index: int in BoardSpec.tile_count:
		(_pick_marks[index] as BoardSkin.Ring).visible = targets.has(index)
	_pick_banner.text = "[직항 워프] 날아갈 빵집·코너 고르기"
	_pick_banner.visible = true
	_pick_cancel.visible = true
	_refresh_controls()


## 흑돌 알까기 조준 모드: 마우스를 누른 채 뒤로 당겼다 놓으면 당긴 반대 방향으로 파워만큼 날아간다 (슬링샷).
func _begin_aim(pawn: PlayerPawn) -> void:
	_alkkagi_top_view(true)
	_alkkagi_actor_offset = _pawn_position(pawn)-_tile_center(pawn.current_tile_idx)+Vector2(0,-14)
	_aim_pawn = pawn.entity_id
	_aim_power = 0.0
	_alkkagi.open_aim(AlkkagiStage.snapshot(state,pawn,PLAYER_COLORS),pawn.entity_id,func(angle: float,power: float) -> Dictionary: return PawnSkills.shot_result(state,pawn,angle,power))
	_pick_banner.visible = false
	_pick_cancel.visible = false
	_refresh_controls()


func _cancel_aim() -> void:
	if _aim_pawn == -1:
		return
	_aim_pawn = -1
	_alkkagi_top_view(false)
	if _alkkagi != null:
		_alkkagi.cancel()
	if _pick_banner != null and not _tile_pick_active:
		_pick_banner.visible = false
		_pick_cancel.visible = false
	if manager != null and manager.state != null:
		_refresh_controls()


## 조준 모드의 마우스 입력. 처리했으면 true.
func _handle_aim_input(event: InputEvent) -> bool:
	return _alkkagi.handle_input(event) if _aim_pawn != -1 and _alkkagi != null else false


func _aim_fire() -> void:
	if _aim_power < 0.08:
		return
	var pawn_id: int = _aim_pawn
	var angle: float = _aim_angle
	var power: float = _aim_power
	_aim_pawn = -1
	_alkkagi.cancel()
	_act(&"use_skill", {"pawn_id": pawn_id, "angle": angle, "power": power})


func _build_aim_layer() -> void:
	var stage_layer := CanvasLayer.new()
	stage_layer.name = "AlkkagiPresentation"
	stage_layer.layer = 45
	add_child(stage_layer)
	_alkkagi = AlkkagiStage.new()
	_alkkagi.name = "AlkkagiStage"
	stage_layer.add_child(_alkkagi)
	_alkkagi.projector = _alkkagi_screen
	_alkkagi.unprojector = _alkkagi_world
	_alkkagi.screen_scale = func() -> float: return get_global_transform().get_scale().x
	_alkkagi.pose_changed.connect(_alkkagi_pose)
	_alkkagi.cancel_requested.connect(_cancel_aim)
	_alkkagi.shot_requested.connect(func(angle: float,power: float) -> void:
		_aim_angle = angle
		_aim_power = power
		_aim_fire())


## 필살기 발동 연출: 알림 카드(무엇이 발동했는지) -> 보드 위 말들의 움직임. 엔진 결과가 확정되기 직전에 도착하는 이벤트다.
## 알림 카드가 보드를 가리는 동안에는 말을 움직이지 않고, 카드가 끝나면 연출을 시작한다.
func _on_skill_used(data: Dictionary) -> void:
	var skill: StringName = data["skill"]
	var player_id: int = int(data["player_id"])
	var pawn: PlayerPawn = state.get_pawn(int(data["pawn_id"]))
	var who: String = "P%d %s" % [player_id, pawn.display_label() if pawn != null else ""]
	var body: String = PawnCatalog.skill_text(skill)
	match skill:
		&"shoot":
			var hits: Array = data["hits"]
			body = "%d개의 말이 출발선으로 탈락!" % hits.size()
			body += "\n흑돌은 %d번 타일에 안착" % int(data["landing"])
			_prepare_shoot_fx(data)
		&"charge":
			var route: Array = data["path"]
			body = "%d번 타일까지 직선 돌진" % int(route.back())
			_prepare_charge_fx(data)
		&"warp":
			body = "%d번 → %d번 타일로 직항" % [int(data["from"]), int(data["tile"])]
			_set_hint(int(data["pawn_id"]), {"arc": 96.0, "peak": 1.7, "dur": 0.9})
		&"castle":
			body = "%s와(과) 위치를 맞바꿉니다" % _pawn_name(int(data["partner"]))
		&"drop":
			body = "%s이(가) %d번 타일에 낙하!" % [_pawn_name(int(data["partner"])), int(data["tile"])]
			_set_hint(int(data["partner"]), {"drop": true})
		&"fianchetto":
			body = "%d번 → %d번 대각선 코너로!" % [int(data["from"]), int(data["tile"])]
			_set_hint(int(data["pawn_id"]), {"arc": 96.0, "peak": 1.7, "dur": 0.9})
		&"bank_shot":
			body = "%d번 타일의 적에게 돌진!" % int((data["path"] as Array).back())
		&"quake":
			body = "주변 설치물 %d개 파괴!" % (data["destroyed"] as Array).size()
			screen_shake(10.0, 0.35)
		&"slash", &"horse":
			body = "%d개의 말을 베어 출발선으로!" % (data["victims"] as Array).size()
		&"plant_mine":
			body = "%d번 타일에 지뢰 매설" % int(data["from"])
		&"hotel":
			body = "%d번 타일에 호텔 건설 (밟은 적은 멈춤)" % int(data["from"])
	_log_line("[필살기] %s: %s - %s" % [who, PawnCatalog.skill_name(skill), body.replace("\n", " ")], Color("ffa94d"))
	if skill != &"shoot":
		_announce_gate(tr_ui("skill.tag"), "[P%d 발동!] %s" % [player_id, PawnCatalog.skill_name(skill)], body, PLAYER_COLORS[player_id], null, 1.3)


## 실제 잡기만 공격자/피격자 아바타 포즈로 강조한다 (함정·자기 복귀 제외).
## 처치 확정 대기 단계: 맞은 사람의 방어 결정(방어 카드 팝업·봇 판단)이 끝날 때까지 연출 큐를 세운다.
## 이 단계에 닿은 순간 공격한 말은 이미 그 칸에 도착해 대치하고 있고, 그때부터 방어 팝업이 뜬다 (_reaction_holder).
func _enqueue_counter_gate() -> void:
	if not _fx_on():
		return
	var generation: int = _capture_epoch
	_enqueue_late(func() -> void:
		if generation != _capture_epoch:
			return
		_counter_gate_waiting = true
		var waited: float = 0.0
		while generation == _capture_epoch and is_instance_valid(manager) and manager.counter_pending() and not manager.is_game_over and waited < COUNTER_GATE_LIMIT:
			waited += get_process_delta_time()
			await get_tree().process_frame
		_counter_gate_waiting = false)


## 날아갈 말이 지금도 출발선에 있는가 (방어 카드가 되돌렸으면 false: 처치가 확정되지 않았다).
func _ejection_confirmed(pawn_id: int) -> bool:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	return pawn != null and not pawn.has_left_start and not pawn.is_finished


## 방어 성공: 말은 제자리에 둔 채 방패 이펙트만 한 번 (같은 말의 컷인·사출 단계가 둘 다 건너뛰어도 한 번만).
func _show_defended(pawn_id: int) -> void:
	if _defended_shown.has(pawn_id):
		return
	_defended_shown[pawn_id] = true
	var view: Node2D = _pawn_views.get(pawn_id)
	if view == null or not is_instance_valid(view):
		return
	var at: Vector2 = view.position + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO)
	Sfx.play(&"promote", -4.0)
	_impact_ring(at, Color("74c0fc"), 52.0)
	_floating_badge(at + Vector2(0, -44), "방어!", Color("74c0fc"), 30)
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(450.0 * _motion_pace()))
	get_tree().create_timer(1.0).timeout.connect(func() -> void: _defended_shown.erase(pawn_id))


## 반격 컷인: 방어한 사람이 공격한 말을 역으로 처치한다 (공격자가 컷인을 맞고 날아간다).
func _enqueue_reflect_cutin(pawn_id: int, by_player: int, victim_owner: int) -> void:
	if _capture_cutin == null or not _player_ids.has(by_player) or not _player_ids.has(victim_owner):
		return
	_capture_marks[pawn_id] = true
	var attack_avatar: StringName = _avatar_for(by_player)
	var hit_avatar: StringName = _avatar_for(victim_owner)
	var generation: int = _capture_epoch
	_enqueue_late(func() -> void:
		if generation != _capture_epoch or not _ejection_confirmed(pawn_id):
			return
		var cut_speed: float = _cutin_speed()
		_capture_cutin.enqueue(attack_avatar, hit_avatar, by_player, victim_owner, cut_speed)
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(CaptureCutin.DURATION / cut_speed * 1000.0)))


func _on_pawn_captured(attacker_pawn_id: int, victim_pawn_id: int) -> void:
	if _alkkagi_controlled.has(victim_pawn_id):
		return
	if not _fx_on() or _capture_cutin == null:
		return
	var attacker: PlayerPawn = state.get_pawn(attacker_pawn_id)
	var victim: PlayerPawn = state.get_pawn(victim_pawn_id)
	if attacker == null or victim == null or attacker.owner_id == victim.owner_id:
		return
	var attacking_player: int = attacker.owner_id
	var defending_player: int = victim.owner_id
	if not _player_ids.has(attacking_player) or not _player_ids.has(defending_player):
		return
	for member: PlayerPawn in victim.stack_members():
		_capture_marks[member.entity_id] = true
	var attack_avatar: StringName = _avatar_for(attacking_player)
	var hit_avatar: StringName = _avatar_for(defending_player)
	var generation: int = _capture_epoch
	if not _is_computer_seat(defending_player):
		_mark_spotlight()  # 사람 말이 잡히는 턴은 보통 속도로 주목
	_enqueue_counter_gate()
	_enqueue_late(func() -> void:
		if generation != _capture_epoch or not _ejection_confirmed(victim_pawn_id):
			return  # 방어 카드로 막았다: 처치 컷인 없이 방어 이펙트만 (사출 단계에서 한 번)
		var cut_speed: float = _cutin_speed()
		_capture_cutin.enqueue(attack_avatar, hit_avatar, attacking_player, defending_player, cut_speed)
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(CaptureCutin.DURATION / cut_speed * 1000.0)))


## 아바타 컷인 외의 복귀 효과에서 쓰는 보드 말 내리찍기.
func _fx_try_slam(by_player: int, victim_pos: Vector2) -> float:
	if not _fx_on():
		return 0.0
	for pawn: PlayerPawn in state.pawns:
		if pawn.owner_id != by_player:
			continue
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null or not _fx_running(view) or view.has_meta("fx_script"):
			continue
		if _pawn_position(pawn).distance_to(victim_pos) > 36.0:
			continue
		var cap: float = minf(_pace(), 1.5)
		_glide(view, _pawn_position(pawn), _depth_scale(tile_norm(pawn.current_tile_idx).y), {"dur": HOP_SECONDS * 1.3, "arc": SLAM_HEIGHT, "pace_cap": cap, "land_tile": pawn.current_tile_idx, "land_big": true})
		return HOP_SECONDS * 1.3 * cap
	return 0.0


## 승급: 말이 공중으로 떠올라 한 바퀴 돌고 후광이 터진다 (그동안 아이콘 글자가 바뀐다).
func _fx_promote(pawn_id: int, color: Color) -> void:
	if not _fx_on():
		return
	Sfx.play(&"promote")
	var view: Node2D = _pawn_views.get(pawn_id)
	if view == null:
		return
	var bounce: Node2D = view.get_node_or_null("Bounce")
	if bounce == null:
		return
	var pace: float = _motion_pace()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(bounce, "position:y", -34.0, 0.3 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bounce, "rotation", TAU, 0.55 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bounce, "scale", Vector2(1.6, 1.6), 0.3 * pace)
	tween.chain().tween_callback(func() -> void:
		_impact_ring(view.position, color, 56.0)
		_impact_ring(view.position, Color.WHITE, 36.0)
		_burst_shards(view.position, color, 18)
		screen_shake(5.0, 0.2))
	tween.chain().tween_property(bounce, "position:y", 0.0, 0.25 * pace).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bounce, "scale", Vector2.ONE, 0.25 * pace)
	tween.tween_callback(func() -> void:
		if is_instance_valid(bounce):
			bounce.rotation = 0.0)
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(1.1 * pace * 1000.0))


## 맞은 말의 주인 프로필이 억울해한다.
func _react_hit_pawn(pawn_id: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn == null:
		return
	var owner_id: int = pawn.owner_id
	# 총알이 날아가(0.35초) 맞은 뒤에 반응한다
	_fx_when_announced(func() -> void:
		get_tree().create_timer(0.35 * _motion_pace() + 0.1).timeout.connect(func() -> void:
			_profile_react(owner_id, false)))


## 차 저격 연출을 미리 만든다: 뒤로 살짝 당김(차징) -> 섬광 -> 초고속 직선 돌진으로 들이받음(내리찍기). 잡힌 말은 부딪힌 뒤에 날아간다.
func _prepare_charge_fx(data: Dictionary) -> void:
	if not _fx_on():
		return
	var pawn_id: int = int(data["pawn_id"])
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	var view: Node2D = _pawn_views.get(pawn_id)
	var route: Array = data["path"]
	if pawn == null or view == null or route.is_empty():
		return
	var start: Vector2 = view.position
	var goal: Vector2 = _pawn_position_at(pawn, int(route.back()))
	var goal_scale: float = _depth_scale(tile_norm(int(route.back())).y)
	var tile: int = int(route.back())
	var direction: Vector2 = (goal - start).normalized() if start.distance_to(goal) > 1.0 else Vector2.RIGHT
	_fx_skip_steps[pawn_id] = true
	_fx_hint_bonus = 0.3 * _motion_pace() + 0.2
	_fx_when_announced(func() -> void:
		var pace: float = _motion_pace()
		_kill_fx(view)
		view.visible = true
		view.position = start
		view.z_index = 6
		var tween: Tween = create_tween()
		tween.tween_property(view, "position", start - direction * 18.0, 0.3 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "scale", view.scale * 1.3, 0.3 * pace)
		tween.tween_callback(func() -> void: _impact_ring(start, Color("ffe066"), 34.0))
		tween.tween_property(view, "position", goal, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(view, "scale", Vector2.ONE * goal_scale, 0.16)
		tween.tween_callback(func() -> void:
			_fx_land(view, tile, true)
			_fx_skip_steps.erase(pawn_id)
			_fx_script_done(view))
		view.set_meta("fx", tween)
		view.set_meta("fx_script", true)
		_fx_trail(view, 0.16, Color("ffd43b"))
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now((0.3 * pace + 0.5) * 1000.0)))


## Before the engine mutates pawns, retain the real board-plane positions for the alkkagi table.
func _prepare_shoot_fx(data: Dictionary) -> void:
	if not _fx_on():
		return
	var shooter: PlayerPawn = state.get_pawn(int(data["pawn_id"]))
	if shooter == null:
		return
	var items := AlkkagiStage.snapshot(state,shooter,PLAYER_COLORS)
	var shot := PawnSkills.shot_result(state,shooter,float(data["angle"]),float(data["power"]))
	var id: int = shooter.entity_id
	var strength: float = float(data["power"])
	_alkkagi_top_view(true)
	_alkkagi_actor_offset = _pawn_position(shooter)-_tile_center(shooter.current_tile_idx)+Vector2(0,-14)
	for piece: Dictionary in items:
		if int(piece.id)!=id and not (shot.hits as Array).has(int(piece.id)):
			continue
		var pawn: PlayerPawn = state.get_pawn(int(piece.id))
		for member: PlayerPawn in pawn.stack_members():
			var view: Node2D = _pawn_views.get(member.entity_id)
			if view != null:
				_kill_fx(view)
				_alkkagi_controlled[member.entity_id] = {"shooter":int(piece.id)==id,"leader":int(piece.id),"offset":view.position-_project(piece.pos),"origin":piece.pos}
	_alkkagi_skip_primary_warp = true
	enqueue_step(func() -> void:
		var generation: int = _fx_generation
		while generation == _fx_generation and _alkkagi_camera_tween != null and _alkkagi_camera_tween.is_running():
			await get_tree().process_frame
		if generation != _fx_generation:
			return
		_alkkagi.play_shot(items,id,shot,strength,_motion_pace())
		while generation == _fx_generation and _alkkagi.mode != &"idle":
			await get_tree().process_frame
		if generation == _fx_generation:
			_alkkagi_release()
			_alkkagi_top_view(false)
			while generation == _fx_generation and _alkkagi_camera_tween != null and _alkkagi_camera_tween.is_running():
				await get_tree().process_frame,id)


func _alkkagi_plane() -> Transform2D:
	var at := _project(Vector2.ZERO)
	return Transform2D(_project(Vector2.RIGHT)-at,_project(Vector2.DOWN)-at,at)

func _alkkagi_screen(point: Vector2) -> Vector2:
	return get_global_transform()*(_project(point)+_pawn_layer.position+_alkkagi_actor_offset)

func _alkkagi_world(point: Vector2) -> Vector2:
	return _alkkagi_plane().affine_inverse()*(get_global_transform().affine_inverse()*point-_pawn_layer.position-_alkkagi_actor_offset)

func _alkkagi_top_view(active: bool, immediate: bool = false) -> void:
	if active:
		if _alkkagi_saved_view!=-1:
			return
		_alkkagi_saved_view = view_mode
		view_mode = ViewMode.TOP
	elif _alkkagi_saved_view==-1:
		if not immediate or (is_zero_approx(_alkkagi_camera) and (_alkkagi_camera_tween==null or not _alkkagi_camera_tween.is_running())):
			return
	else:
		view_mode = _alkkagi_saved_view
		_alkkagi_saved_view = -1
	if _alkkagi_camera_tween != null:
		_alkkagi_camera_tween.kill()
	var target := 1.0 if active else 0.0
	if immediate or instant_roll_for_test:
		_alkkagi_camera_step(target)
	else:
		_alkkagi_camera_tween = create_tween()
		_alkkagi_camera_tween.tween_method(_alkkagi_camera_step,_alkkagi_camera,target,0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _alkkagi_camera_step(value: float) -> void:
	var positions: Dictionary = {}
	var plane := _alkkagi_plane().affine_inverse()
	for id: int in _pawn_views:
		var view: Node2D = _pawn_views[id]
		var pawn: PlayerPawn = state.get_pawn(id) if state != null else null
		var offset := Vector2.ZERO
		if pawn != null:
			offset = _pawn_position(pawn)-_tile_center(pawn.current_tile_idx)
		positions[view] = {"norm":plane*(view.position-offset),"offset":offset}
	for view: Node2D in _npc_views.values():
		positions[view] = {"norm":plane*view.position,"offset":Vector2.ZERO}
	_alkkagi_camera = value
	_apply_view_mode(false)
	for view: Node2D in positions:
		view.position = _project(positions[view].norm)+(positions[view].offset as Vector2)
	if _alkkagi != null:
		_alkkagi.queue_redraw()

func _alkkagi_pose() -> void:
	if _alkkagi == null or _alkkagi.mode in [&"idle",&"aim"]:
		return
	for id: int in _alkkagi_controlled:
		var view: Node2D = _pawn_views.get(id)
		var info: Dictionary = _alkkagi_controlled[id]
		if view == null:
			continue
		view.visible = true
		view.z_index = 12
		if bool(info.shooter):
			var position_norm := _alkkagi.stone
			if _alkkagi.mode in [&"settle",&"done"]:
				var blend := 1.0 if _alkkagi.mode==&"done" else smoothstep(0.0,0.35,_alkkagi.elapsed-_alkkagi._out_time)
				position_norm = position_norm.lerp(BoardLayout.tile_norm(_alkkagi.landing),blend)
			view.position = _project(position_norm)+(info.offset as Vector2)
		else:
			var pose := _alkkagi.victim_pose(int(info.leader))
			if not pose.is_empty():
				view.position = _project(pose.pos)+(info.offset as Vector2)+Vector2(0,-sin(minf(float(pose.age)/0.85,1.0)*PI)*65.0)
				view.rotation = float(pose.rotation)
				view.modulate.a = float(pose.alpha)
				view.scale = Vector2.ONE*(1.0+sin(minf(float(pose.age)/0.85,1.0)*PI)*0.2)

func _alkkagi_release(reset: bool = false) -> void:
	for id: int in _alkkagi_controlled:
		var view: Node2D = _pawn_views.get(id)
		var pawn: PlayerPawn = state.get_pawn(id) if state != null else null
		if view != null:
			view.rotation = 0.0
			view.modulate = Color.WHITE
			view.scale = Vector2.ONE
			view.z_index = 0
			if pawn != null and (reset or not bool(_alkkagi_controlled[id].shooter)):
				view.position = _pawn_position(pawn)
				view.visible = pawn.has_left_start and not pawn.is_finished and pawn.carrier==null
	_alkkagi_controlled.clear()
	_alkkagi_skip_primary_warp = false


func _fx_script_done(view: Node2D) -> void:
	if not is_instance_valid(view):
		return
	view.remove_meta("fx_script")
	view.remove_meta("fx")
	view.rotation = 0.0
	view.z_index = 0
	if state != null:
		call_deferred("_refresh_all")


# ---------------------------------------------------------------------------
# 말 움직임 연출 (PawnFx): 규칙은 한 번에 결과가 정해지지만 화면은 [출발 -> 이동/충돌 -> 자리 잡기]를 단계로 보여 준다
# ---------------------------------------------------------------------------

func _fx_on() -> bool:
	return not instant_roll_for_test


## 연출 시간 배율: 연출 속도 설정(최대 2배)을 따른다.
func _motion_pace() -> float:
	return minf(_pace(), 2.0)


func _fx_running(view: Node2D) -> bool:
	if not view.has_meta("fx"):
		return false
	var running: Tween = view.get_meta("fx")
	return running != null and running.is_valid() and running.is_running()


func _fx_node_running(node: Node2D) -> bool:
	return _fx_running(node)


func _kill_fx(view: Node2D) -> void:
	if view.has_meta("fx"):
		var running: Tween = view.get_meta("fx")
		if running != null and running.is_valid():
			running.kill()
		view.remove_meta("fx")
	if view.has_meta("fx_script"):
		view.remove_meta("fx_script")
	for key: String in ["land_tile", "land_big", "land_thud"]:
		if view.has_meta(key):
			view.remove_meta(key)
	var bounce: Node2D = view.get_node_or_null("Bounce")
	if bounce != null:
		bounce.scale = Vector2.ONE
	view.rotation = 0.0
	view.z_index = 0


func _set_hint(pawn_id: int, hint: Dictionary) -> void:
	if not _fx_on():
		return
	var stored: Dictionary = hint.duplicate()
	stored["t"] = Time.get_ticks_msec()
	_fx_hints[pawn_id] = stored


## 힌트를 한 번 꺼내 쓴다 (너무 오래된 힌트는 버린다).
func _take_hint(pawn_id: int) -> Dictionary:
	if not _fx_hints.has(pawn_id):
		return {}
	var hint: Dictionary = _fx_hints[pawn_id]
	_fx_hints.erase(pawn_id)
	if Time.get_ticks_msec() - int(hint.get("t", 0)) > 8000:
		return {}
	return hint


func _hint_swap(a_id: int, b_id: int) -> void:
	_set_hint(a_id, {"arc": 54.0, "peak": 1.25, "dur": 0.7})
	_set_hint(b_id, {"arc": -30.0, "peak": 0.9, "dur": 0.7})


## 테스트·빠른 스모크(연출 끔)에서는 큐 없이 즉시 실행한다.
func is_headless_or_fast_smoke() -> bool:
	return not _fx_on()


## 연출 한 단계를 큐 맨 뒤에 세운다. 큐가 비어 있고 알림 카드가 없으면 그 자리에서 바로 시작하고,
## 아니면 앞 연출이 100% 끝난 뒤에 시작한다. pawn_id를 주면 그 말은 이 단계가 끝날 때까지 최종 위치로 건너뛰지 않는다.
## allow_defer=false: 드래프트가 열리기 전에 일어난 일의 연출(라운드 마지막 턴의 처치 등)이라 드래프트 공개 뒤로 미루지 않는다.
func enqueue_step(step_callable: Callable, pawn_id: int = -1, allow_defer: bool = true, pick: int = -1) -> void:
	if is_headless_or_fast_smoke():
		step_callable.call()  # 테스트 모드에선 즉시 실행
		return
	if allow_defer and _draft_in_progress():
		# 증강 드래프트 중에 고른 증강의 효과(폭주 기관차·저격수 등)는 [선택한 증강] 공개 뒤에 보여 준다 (결과를 먼저 흘리지 않게)
		_draft_deferred.append({"step": step_callable, "pawn": pawn_id, "pick": pick if pick != -1 else _pick_serial})
		return
	if pawn_id != -1:
		_pawn_pending[pawn_id] = int(_pawn_pending.get(pawn_id, 0)) + 1
	var label: String = String(step_callable.get_method())
	_presentation_draws.append(label == "_launch_drawn_card")
	_presentation_moves.append(MOVE_STEP_LABELS.has(label))
	_presentation_queue.append(func() -> void:
		presentation_label = label
		# A modal may close while its opening is still queued behind an effect.
		if step_callable.is_valid():
			await step_callable.call()
		if pawn_id != -1:
			_pawn_pending[pawn_id] = maxi(int(_pawn_pending.get(pawn_id, 1)) - 1, 0))
	if not _is_playing_presentation and not _enqueue_batching:
		_process_presentation_queue()


## 여러 단계를 한꺼번에 세운다: 다 세운 뒤에 재생을 시작한다. (하나씩 세우면 기다릴 것 없는 첫 단계가 그 자리에서 끝나 큐가 잠깐 비고,
## 그 틈에 [N라운드 시작!] 같은 다음 알림이 남은 단계보다 먼저 끼어들었다.)
func _enqueue_batch(entries: Array[Dictionary]) -> void:
	_enqueue_batching = true
	for entry: Dictionary in entries:
		enqueue_step(entry["step"], int(entry.get("pawn", -1)), bool(entry.get("defer", true)), int(entry.get("pick", -1)))
	_enqueue_batching = false
	if not _is_playing_presentation and not _presentation_queue.is_empty():
		_process_presentation_queue()


## 연출 큐를 비우고 재생 중인 러너를 멈춘다 (판 초기화·되감기·테스트 정리용). 이미 시작된 트윈은 건드리지 않는다.
func _reset_presentation() -> void:
	var bang_stage: Node2D = get_node_or_null("BangStage")
	if bang_stage != null:
		bang_stage.cancel()
	var bond_stage: Node2D = get_node_or_null("BondStage")
	if bond_stage!=null:
		bond_stage.cancel()
	var nitro_stage: Node2D = get_node_or_null("NitroStage")
	if nitro_stage!=null:
		nitro_stage.cancel()
	for pawn_id: int in _nitro_skips:
		_fx_skip_steps.erase(pawn_id)
	_nitro_skips.clear()
	_release_nitro_victims(_nitro_victims.keys())
	var sniper_stage: Node2D = get_node_or_null("SniperStage")
	if sniper_stage!=null:
		sniper_stage.cancel()
	var bakery_stage: Node2D = get_node_or_null("BakeryStage")
	if bakery_stage!=null:
		bakery_stage.cancel()
	var castling_stage: Node2D = get_node_or_null("CastlingStage")
	if castling_stage!=null:
		castling_stage.cancel()
	var gambler_result: Node2D = get_node_or_null("GamblerResult")
	if gambler_result!=null:
		gambler_result.cancel()
	_follow_up_pawns.clear()
	_rocket_followup.clear()
	_roll_reasons.clear()
	_move_bonus_notes.clear()
	if _train_stage != null:
		_train_stage.cancel()
	_train_release()
	if _alkkagi != null:
		_alkkagi.cancel()
	_alkkagi_release(true)
	_alkkagi_top_view(false,true)
	_aim_pawn = -1
	_fx_generation += 1
	_presentation_queue.clear()
	_presentation_draws.clear()
	_presentation_moves.clear()
	_move_chain_len = 0
	_move_chained = false
	if is_instance_valid(_announcement_extras):
		for extra: Node in _announcement_extras.get_children():
			extra.queue_free()
	_late_steps.clear()
	_draft_deferred.clear()
	_super_changes.clear()
	_steal_from = -1
	_gambler_flash.clear()
	if _draw_fx != null:
		_draw_fx.clear()
	_draft_open = false
	_roll_total.clear()
	_rocket_target.clear()
	_is_playing_presentation = false
	_pawn_pending.clear()


## 처치 연출(컷신·장외 사출)은 같은 행동의 이동·발판 연출이 모두 끝난 뒤에 재생한다: 엔진은 한 번에 방송하므로 프레임 끝에 큐 맨 뒤로 보낸다.
## 처치(사출)가 아직 지연 큐에 있으면 그 뒤에, 없으면 바로 연출 큐에 세운다. 이동 4단계: 도착 칸 처치 연출이 끝난 뒤에 추가 이동(점프 부스트·발판·8번 공 돌진)을 보여 준다.
func _enqueue_after_kills(step_callable: Callable, pawn_id: int = -1) -> void:
	if not _late_steps.is_empty():
		_enqueue_late(step_callable, pawn_id)
	else:
		enqueue_step(step_callable, pawn_id)


func _enqueue_late(step_callable: Callable, pawn_id: int = -1) -> void:
	if not _fx_on():
		step_callable.call()
		return
	if pawn_id != -1:
		_pawn_pending[pawn_id] = int(_pawn_pending.get(pawn_id, 0)) + 1
	# 미룰지는 지금(이 일이 일어난 순간) 정한다: 프레임 끝에 큐로 옮길 때는 엔진이 이미 다음 라운드 드래프트를 열었을 수 있다.
	_late_steps.append({"step": step_callable, "pawn": pawn_id, "defer": _draft_in_progress(), "pick": _pick_serial})
	if _late_steps.size() == 1:
		_flush_late_steps.call_deferred()


func _flush_late_steps() -> void:
	var batch: Array[Dictionary] = _late_steps.duplicate()
	_late_steps.clear()
	_enqueue_batch(batch)
	for entry: Dictionary in batch:
		var pawn_id: int = int(entry["pawn"])
		if pawn_id != -1:
			_pawn_pending[pawn_id] = maxi(int(_pawn_pending.get(pawn_id, 1)) - 1, 0)


## 아직 큐로 옮기지 않은 늦은 단계(처치 사출 등) 중 이 말의 것을 빼낸다: 초증강 연출이 그 장면을 자기 순서 안에서 직접 보여 줄 때.
func _take_late_steps_for(pawn_id: int) -> int:
	var kept: Array[Dictionary] = []
	var taken: int = 0
	for entry: Dictionary in _late_steps:
		if int(entry["pawn"]) == pawn_id:
			taken += 1
			_pawn_pending[pawn_id] = maxi(int(_pawn_pending.get(pawn_id, 1)) - 1, 0)
		else:
			kept.append(entry)
	_late_steps = kept
	return taken


func _add_roll_reason(player_id: int, reason: String) -> void:
	if not _fx_on():
		return
	if not _roll_reasons.has(player_id):
		_roll_reasons[player_id] = []
	(_roll_reasons[player_id] as Array).append(reason)


## 눈금보다 더 가는 이유(퀸 +2칸·룩 직진 +2칸·나리 승급 등)를 말 위에 띄운 뒤 이동한다. 리벤지 부스터 이동이면 부스터 착지 뒤 [눈금 M칸 (이유)]에 붙인다.
func _on_move_bonus(pawn_id: int, notes: Array, revenge: int) -> void:
	_log_line("[추가 전진] %s: %s" % [_pawn_name(pawn_id), ", ".join(PackedStringArray(notes))], Color("ffd43b"))
	if not _fx_on():
		return
	if revenge > 0:
		_move_bonus_notes[pawn_id] = notes
		return
	# 말 위의 표시는 기물별 원인 뱃지([장기:포] 뛰어넘기 +3칸!)가 맡는다 (passive_triggered → _play_callout).


## 기물 고유 능력이 발동했다: 그 말 머리 위에 [기물] 원인 뱃지를 띄운다 (연출 큐 순서대로, 걸음을 끊지 않는다).
func _on_passive_triggered(pawn_id: int, passive: StringName) -> void:
	if PassiveCallout.text(passive) == "" or not _fx_on():
		return
	enqueue_step(_play_callout.bind(pawn_id, passive), pawn_id)


const CALLOUT_SECONDS: float = 0.8


## 원인 뱃지: 말 머리 위에 [기물 글자 칩 + 원인 문구]를 0.8초 크게 띄운다. 말의 자식이라 말이 움직여도 따라간다.
## 같은 말에 여러 개가 겹치면 위로 쌓는다. 연출 큐를 붙잡지 않는다 (걸음은 바로 이어진다).
func _play_callout(pawn_id: int, passive: StringName) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if view == null or not is_instance_valid(view) or pawn == null:
		return
	var tint: Color = PassiveCallout.color(passive)
	var badge := PanelContainer.new()
	badge.name = "PassiveCallout"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 70
	var box: StyleBoxFlat = _style(Color(0.07, 0.08, 0.12, 0.92), tint, 3, 14, 10, 0)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.content_margin_left = 6
	badge.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	var chip := _make_label(PawnCatalog.unit_letter(pawn.kind, pawn.unit_no), 18, Color("13151d"))
	chip.custom_minimum_size = Vector2(26, 26)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_stylebox_override("normal", _style(tint, tint, 0, 13, 0, 0))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	var label := _make_label(PassiveCallout.text(passive), 22, Color.WHITE)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var stacked: int = 0
	for child: Node in view.get_children():
		if child.name.begins_with("PassiveCallout") and not child.is_queued_for_deletion():
			stacked += 1
	view.add_child(badge)
	badge.reset_size()
	var counter: float = 1.0 / maxf(absf(view.scale.x), 0.2)  # 깊이 배율과 상관없이 같은 크기로
	badge.pivot_offset = badge.size / 2.0
	badge.position = Vector2(-badge.size.x / 2.0, -78.0 - 34.0 * stacked * counter)
	badge.scale = Vector2.ONE * 0.4 * counter
	badge.modulate.a = 0.0
	_mark_oneshot(badge, CALLOUT_SECONDS + 0.6)
	var tween: Tween = badge.create_tween()
	tween.tween_property(badge, "scale", Vector2.ONE * counter, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(badge, "modulate:a", 1.0, 0.1)
	tween.tween_interval(CALLOUT_SECONDS - 0.16)
	tween.tween_property(badge, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(badge, "position:y", badge.position.y - 16.0, 0.25)
	tween.tween_callback(badge.queue_free)


## 굴림이 끝나면(주사위가 완전히 멈춘 뒤) 가속 보너스까지 합친 최종 이동 칸수를 숫자로 보여 주고 0.3초 뒤에 이동을 시작한다.
func _enqueue_roll_summary(data: Dictionary) -> void:
	if not _fx_on():
		return
	var result: Dictionary = data["result"]
	if bool(result.get("ends_turn", false)) or bool(result.get("can_continue", false)):
		return
	var steps: int = int(result.get("steps", 0))
	if steps <= 0:
		return
	var player: int = int(data["player_id"])
	_roll_total[player] = steps
	if not _roll_reasons.has(player):
		_roll_reasons[player] = []
	enqueue_step(func() -> void:
		await get_tree().process_frame  # 같은 굴림의 보너스 이벤트가 모두 도착한 뒤
		var frames: int = 0
		while (_fx_busy or _gambler_result_busy()) and frames < 720:
			frames += 1
			await get_tree().process_frame
		var total: int = int(_roll_total.get(player, steps))
		_roll_total.erase(player)
		var reasons: Array = _roll_reasons.get(player, [])
		_roll_reasons.erase(player)
		if total != steps:  # 보너스가 붙었을 때만 최종 칸 수를 크게 (기본 눈금은 굴림 스테이지가 이미 보여 줬다)
			_number_pop(_board_center() + Vector2(0, -60), "%d칸!" % total, Color("ffd43b"))  # 혼자 떠올랐다 사라진다 (이동을 붙잡지 않는다)
			if not reasons.is_empty():  # 왜 늘었는지: 가속 보너스·템포 업·도박사의 영혼
				_floating_badge(_board_center() + Vector2(0, -12), " · ".join(PackedStringArray(reasons)), Color("fff3bf"), 24)
		await get_tree().create_timer(ROLL_SUMMARY_LEAD).timeout)


func _process_presentation_queue() -> void:
	_is_playing_presentation = true
	var generation: int = _fx_generation
	while not _presentation_queue.is_empty():
		var next_step: Callable = _presentation_queue.pop_front()
		var is_draw: bool = bool(_presentation_draws.pop_front()) if not _presentation_draws.is_empty() else false
		var is_move: bool = bool(_presentation_moves.pop_front()) if not _presentation_moves.is_empty() else false
		if not (is_draw and _chained_draw):
			await _presentation_wait_ready(generation)
		if generation != _fx_generation:
			break
		if is_move and not _move_chained:
			_move_chain_len = 1
			while _move_chain_len <= _presentation_moves.size() and bool(_presentation_moves[_move_chain_len - 1]):
				_move_chain_len += 1
		elif not is_move:
			_move_chain_len = 0
		var started_msec: int = Time.get_ticks_msec()
		await next_step.call()  # ★ 앞 연출이 100% 끝날 때까지 다음 연출은 절대 시작하지 않는다
		# 카드 여러 장을 연달아 받으면(초증강·패키지) 다음 카드도 바로 띄운다: 순서는 카드 연출(CardDrawFX)의 줄이 지키고,
		# 줄이 길면 빨리 감는다. 마지막 카드가 끝난 뒤에야 다음 연출로 넘어간다.
		_chained_draw = is_draw and not _presentation_draws.is_empty() and bool(_presentation_draws[0])
		if _chained_draw:
			continue
		# 걸음이 이어지면(다음 단계도 걸음) 정리 대기·여운 없이 바로 다음 칸으로 뛴다: 걸음 단계는 자기 점프가 끝날 때까지 이미 기다렸다.
		_move_chained = is_move and not _presentation_moves.is_empty() and bool(_presentation_moves[0])
		if _move_chained:
			continue
		await _presentation_settle(generation)
		if generation != _fx_generation:
			break
		if not NO_LINGER_LABELS.has(presentation_label) and Time.get_ticks_msec() - started_msec >= STEP_LINGER_MIN_MSEC:
			await _presentation_linger(generation)  # 결과를 잠깐 보여 준 뒤 넘긴다
			if generation != _fx_generation:
				break
	if generation != _fx_generation:
		return  # 판이 초기화됐다: 새 큐가 이어받는다
	_is_playing_presentation = false
	_pawn_pending.clear()
	if state != null and manager != null and is_inside_tree():
		_refresh_all()  # 큐가 비면 연출이 건드리지 않은 나머지 변화를 화면에 맞춘다


## 연출 여운: 보여 준 단계가 끝난 뒤 STEP_LINGER_SECONDS(AI 터보 턴은 3/4)만큼 결과를 보여 준다.
func _presentation_linger(generation: int) -> void:
	var seconds: float = STEP_LINGER_SECONDS * (0.75 if _turbo_turn() else 1.0)
	if seconds <= 0.0 or not pacing_enabled or instant_roll_for_test:
		return
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while generation == _fx_generation and Time.get_ticks_msec() < until:
		await get_tree().process_frame


## 알림 카드·워프 연출이 보드를 가리고 있으면 끝날 때까지 기다린다 (최대 12초).
func _presentation_wait_ready(generation: int) -> void:
	var frames: int = 0
	# 큐에 든 단계는 이미 지금 재생해도 되는 것들이다 (드래프트 뒤로 미룰 연출은 _draft_deferred에 따로 모인다).
	# 그래서 미뤄 둔 드래프트 연출이 있다고 기다리지 않는다: 기다리면 드래프트가 열린 동안 남은 걸음마다 12초 상한까지 멈춰 한 칸씩 기어갔다.
	while generation == _fx_generation and (_fx_holding(false) or _fx_busy or _gambler_result_busy() or (_draw_fx != null and _draw_fx.busy())) and (frames < 720 or _gambler_result_busy() or (_draw_fx != null and _draw_fx.busy())):
		frames += 1
		await get_tree().process_frame


## 한 단계가 시작한 움직임·컷인·배너·여운이 모두 끝나기를 기다린다 (최대 12초).
func _presentation_settle(generation: int) -> void:
	var frames: int = 0
	while generation == _fx_generation and _presentation_step_busy() and (frames < 720 or (_draw_fx != null and _draw_fx.busy())):
		frames += 1
		await get_tree().process_frame


func _presentation_step_busy() -> bool:
	if _gambler_result_busy():
		return true
	if _draw_fx != null and _draw_fx.busy():
		return true
	if _stage_warps > 0 or _fx_busy:
		return true
	if _capture_cutin != null and _capture_cutin.busy():
		return true
	if _announcer != null and _announcer.holding():
		return true
	if Time.get_ticks_msec() < _fx_until_msec:
		return true
	for view: Node2D in _pawn_views.values():
		if _fx_running(view):
			return true
	return false


## 연출 큐가 일하는 중이거나 대기 중인가 (입력·봇·다음 턴·증강 창은 이 동안 기다린다).
func _presentation_active() -> bool:
	return _is_playing_presentation or not _presentation_queue.is_empty() or not _late_steps.is_empty()


## 알림 카드가 끝난 뒤(문이 열린 뒤, 카드가 없으면 바로) 실행한다. 이제 연출 큐의 한 단계로 순서대로 실행된다.
func _fx_when_announced(action: Callable) -> void:
	if not _fx_on():
		return
	enqueue_step(action)


## 알림 카드가 가리고 있어서 말을 움직이면 안 되는 때인가.
## include_draft=false: 연출 큐 자신이 묻는 경우 (큐의 단계는 드래프트와 상관없이 재생해도 된다).
func _fx_holding(include_draft: bool = true) -> bool:
	if _duel_arena != null and is_instance_valid(_duel_arena) and _duel_arena.holds_board():
		return true  # 결투 승패가 공개되기 전에 누가 날아가는지 보여 주지 않는다
	if include_draft and not _draft_deferred.is_empty():
		return true  # 드래프트 효과는 증강 공개 뒤에: 그 전에는 말 그림을 옮기지 않는다
	return _stage_warps > 0 or (_announcer != null and _announcer.holding() and not _fx_gate_open)


## 문으로 등록한 알림 한 건이 끝났다: 말 움직임 연출을 시작하고, 다음 알림은 그 연출이 끝난 뒤에 띄운다.
func _on_announcer_entry_finished(serial: int) -> void:
	if state == null or not _fx_gates.has(serial):
		return
	_fx_gates.erase(serial)
	_fx_gate_open = true
	_fx_after_announcer()
	_refresh_pawns()
	_announcer.hold_until_msec = maxi(_announcer.hold_until_msec, _fx_until_msec)


## 알림 카드가 끝났다 (말 걸음·예약 연출은 이제 연출 큐가 순서대로 재생한다).
func _fx_after_announcer() -> void:
	_fx_hint_bonus = 0.0


## 한 칸 이동(또는 포물선 비행)의 한 프레임: t는 0..1.
func _apply_hop(t: float, view: Node2D, from_pos: Vector2, to_pos: Vector2, from_scale: float, to_scale: float, arc: float, peak: float, spin: float, tilt: float = 0.0) -> void:
	if not is_instance_valid(view):
		return
	var eased: float = t * t * (3.0 - 2.0 * t)
	var lift: float = sin(PI * t)
	view.position = from_pos.lerp(to_pos, eased) + Vector2(0.0, -arc * lift)
	view.scale = Vector2.ONE * lerpf(from_scale, to_scale, eased) * lerpf(1.0, peak, lift)
	view.rotation = spin * eased + tilt * lift


## 말 하나를 현재 자리에서 목표 자리로 포물선으로 옮긴다 (옵션: dur arc peak spin delay from_pos from_scale from_alpha drop).
func _glide(view: Node2D, to_pos: Vector2, to_scale: float, opts: Dictionary = {}) -> void:
	_kill_fx(view)
	var from_pos: Vector2 = opts.get("from_pos", view.position)
	var from_scale: float = float(opts.get("from_scale", view.scale.x))
	var distance: float = from_pos.distance_to(to_pos)
	var cap: float = float(opts.get("pace_cap", _motion_pace()))
	var duration: float = float(opts.get("dur", clampf(0.3 + distance / 1100.0, 0.32, 0.8))) * cap
	var delay: float = float(opts.get("delay", 0.0)) * cap
	var arc: float = float(opts.get("arc", clampf(distance * 0.16, 12.0, 64.0)))
	var peak: float = float(opts.get("peak", 1.0))
	var spin: float = float(opts.get("spin", 0.0))
	var from_alpha: float = float(opts.get("from_alpha", 1.0))
	var tilt: float = float(opts.get("tilt", 0.0))
	if bool(opts.get("drop", false)):
		from_pos = to_pos + Vector2(0.0, -150.0)
		from_scale = to_scale * 2.4
		from_alpha = 0.0
		arc = 0.0
		duration = 0.55 * _motion_pace()
		delay = 0.0
	view.visible = true
	view.z_index = 4
	view.position = from_pos
	view.scale = Vector2.ONE * from_scale
	view.modulate = Color(1, 1, 1, from_alpha)
	if bool(opts.get("homerun", false)):
		_glide_homerun(view, to_pos, to_scale, delay, bool(opts.get("land_thud", false)))
		return
	var tween: Tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	if opts.has("land_tile"):
		view.set_meta("land_tile", int(opts["land_tile"]))
	view.set_meta("land_big", bool(opts.get("land_big", false)))
	view.set_meta("land_thud", bool(opts.get("land_thud", false)))
	tween.tween_method(_apply_hop.bind(view, from_pos, to_pos, from_scale, to_scale, arc, peak, spin, tilt), 0.0, 1.0, duration)
	if from_alpha < 1.0:
		tween.parallel().tween_property(view, "modulate:a", 1.0, duration * 0.5)
	tween.tween_callback(_glide_done.bind(view))
	view.set_meta("fx", tween)
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now((delay + duration) * 1000.0 + 60))


## 장외 홈런: 잡힌 말이 보드 밖(화면 좌상단·우상단 바깥)으로 초고속으로 날아가며 1080도 회전하고 크기가 변한다 (뒤에 흰 연기·별 잔상).
## 화면 밖으로 사라진 뒤 출발선 타일 위에서 툭 떨어져 바운스한다.
const HOMERUN_SECONDS: float = 0.38
const HOMERUN_ROTATION: float = 1080.0


func _glide_homerun(view: Node2D, to_pos: Vector2, to_scale: float, delay: float, land_thud: bool) -> void:
	var from_pos: Vector2 = view.position
	var screen: Vector2 = get_viewport_rect().size
	var go_left: bool = from_pos.x < _board_center().x
	var exit_global: Vector2 = Vector2(-320.0, -220.0) if go_left else Vector2(screen.x + 320.0, -220.0)
	var parent: CanvasItem = view.get_parent() as CanvasItem
	var exit_pos: Vector2 = parent.get_global_transform().affine_inverse() * exit_global if parent != null else exit_global
	var duration: float = HOMERUN_SECONDS * _motion_pace()
	var from_scale: float = view.scale.x
	var tween: Tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		Sfx.play(&"launch"))
	tween.tween_method(_apply_homerun.bind(view, from_pos, exit_pos, from_scale), 0.0, 1.0, duration)
	tween.tween_callback(_homerun_return.bind(view, to_pos, to_scale, land_thud))
	view.set_meta("fx", tween)
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now((delay + duration) * 1000.0 + 120))


func _apply_homerun(t: float, view: Node2D, from_pos: Vector2, exit_pos: Vector2, from_scale: float) -> void:
	if not is_instance_valid(view):
		return
	var eased: float = t * t  # 처음엔 살짝 웅크렸다가 점점 빨라진다
	view.position = from_pos.lerp(exit_pos, eased) + Vector2(0.0, -90.0 * sin(PI * minf(t * 1.2, 1.0)))
	view.rotation = deg_to_rad(HOMERUN_ROTATION) * eased
	view.scale = Vector2.ONE * from_scale * lerpf(1.0, 2.4, sin(PI * t * 0.8))
	var step: int = int(t * 7.0)
	if int(view.get_meta("trail_step", -1)) != step:
		view.set_meta("trail_step", step)
		_burst_shards(view.position, Color("f8f9fa"), 3)
		_burst_shards(view.position, Color("ffe066"), 2)


## 홈런 뒤: 말은 날아가기만 한다. 출발선 대기 말은 보드에 그리지 않으므로 숨긴 채로 출발선 자리에 둔다
## (예전에는 보이는 채로 옮겨 두어 연출 큐가 끝날 때까지 출발선에 잠깐 나타났다가 사라졌다).
func _homerun_return(view: Node2D, to_pos: Vector2, to_scale: float, _land_thud: bool) -> void:
	if not is_instance_valid(view):
		return
	view.visible = false
	if view.has_meta("trail_step"):
		view.remove_meta("trail_step")
	view.rotation = 0.0
	view.position = to_pos
	view.scale = Vector2.ONE * to_scale
	view.modulate = Color.WHITE
	for key: String in ["land_tile", "land_big", "land_thud"]:
		if view.has_meta(key):
			view.remove_meta(key)
	_glide_done(view)


func _glide_done(view: Node2D) -> void:
	if not is_instance_valid(view):
		return
	view.remove_meta("fx")
	_fx_landed(view)
	view.rotation = 0.0
	view.z_index = 0
	view.modulate = Color.WHITE
	if state != null:
		call_deferred("_refresh_all")


## 중립 기물 같은 단순한 노드를 목표 자리로 미끄러뜨린다.
func _glide_node(node: Node2D, to_pos: Vector2, seconds: float) -> void:
	if node.has_meta("fx"):
		var running: Tween = node.get_meta("fx")
		if running != null and running.is_valid():
			running.kill()
	var duration: float = seconds * _motion_pace()
	var tween: Tween = create_tween()
	tween.tween_property(node, "position", to_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.remove_meta("fx"))
	node.set_meta("fx", tween)
	_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(duration * 1000.0 + 60))


## 상태가 바뀐 뒤 말의 화면 자리를 맞춘다: 자리가 달라졌으면 순간이동 대신 포물선으로 움직이고(힌트가 있으면 그 모양으로), 끝나면 보이기/숨기기를 정한다.
func _settle_pawn_view(view: Node2D, pawn: PlayerPawn, force: bool = false) -> void:
	if _alkkagi_controlled.has(pawn.entity_id) or _train_controlled.has(pawn.entity_id) or _nitro_victims.has(pawn.entity_id):
		return
	var target_pos: Vector2 = _pawn_position(pawn)
	var target_scale: float = _depth_scale(tile_norm(pawn.current_tile_idx).y)
	var want_visible: bool = pawn.carrier == null and not pawn.is_finished and pawn.has_left_start
	(view.get_node("Shadow") as Polygon2D).visible = true
	if not _fx_on():
		_kill_fx(view)
		view.position = target_pos
		view.scale = Vector2.ONE * target_scale
		view.visible = want_visible
		view.modulate = Color.WHITE
		return
	if _fx_running(view):
		return  # 움직이는 중이다: 끝나면 다시 맞춘다
	if _fx_holding():
		return  # 알림 카드가 가리는 동안은 기다린다: 카드가 끝나면 다시 맞춘다
	if _presentation_active() and not force:
		return  # 연출 큐가 순서대로 보여 주는 중이다: 큐가 비면 한꺼번에 맞춘다
	if _rocket_target.has(pawn.entity_id) and not force:
		return  # 로켓 출격 걸음이 아직 다 오지 않았다
	if view.visible and view.position.distance_to(target_pos) > 3.0:
		_glide(view, target_pos, target_scale, _take_hint(pawn.entity_id))
		return
	view.position = target_pos
	view.scale = Vector2.ONE * target_scale
	view.modulate = Color.WHITE
	if want_visible and not view.visible:
		# 새로 나타난다: 낙하(모치고마) 힌트가 있으면 위에서 떨어지고, 아니면 작게 시작해 커진다.
		var hint: Dictionary = _take_hint(pawn.entity_id)
		if not bool(hint.get("drop", false)):
			hint = {"from_scale": target_scale * 0.3, "arc": 0.0, "dur": 0.3, "from_pos": target_pos}
		_glide(view, target_pos, target_scale, hint)
		return
	view.visible = want_visible


## Replace only this shot's pending ejection, preserving the counter gate and stack order.
func _fx_bang(shooter: int, target_pawn_id: int) -> void:
	if not _fx_on():
		return
	var action: Callable = _play_bang.bind(shooter, target_pawn_id)
	for entry: Dictionary in _late_steps:
		if int(entry["pawn"]) == target_pawn_id:
			entry["step"] = action
			return
	# Replayed event without an engine signal still uses the same guarded presentation.
	_enqueue_late(action, target_pawn_id)


func _play_bang(shooter: int, target_pawn_id: int) -> void:
	if not _ejection_confirmed(target_pawn_id):
		_show_defended(target_pawn_id)
		return
	var view: Node2D = _pawn_views.get(target_pawn_id)
	var pawn: PlayerPawn = state.get_pawn(target_pawn_id)
	if not is_instance_valid(view) or pawn == null:
		return
	var generation: int = _fx_generation
	var stage: Node2D = preload("res://scenes/bang_stage.gd").new()
	add_child(stage)
	stage.play(self, shooter, target_pawn_id, _motion_pace())
	while generation == _fx_generation and is_instance_valid(stage) and not stage.released and not stage.complete:
		await get_tree().process_frame
	if generation != _fx_generation or not is_instance_valid(stage) or not stage.released:
		if is_instance_valid(stage): stage.cancel()
		return
	_record_ejection(target_pawn_id, shooter, true)
	# Release on the hit beat, without another queue linger between bullet and launch.
	await _play_capture_eject(target_pawn_id, shooter, pawn.owner_id, false, false)
	while generation == _fx_generation and is_instance_valid(stage) and not stage.complete:
		await get_tree().process_frame
	if is_instance_valid(stage): stage.queue_free()


## Keep the UDO +4 card's existing feedback independent of the BANG! cutscene.
func _fx_simple_shot(shooter: int, target_pawn_id: int) -> void:
	if not _fx_on():
		return
	Sfx.play(&"shot")
	var view: Node2D = _pawn_views.get(target_pawn_id)
	var card: Dictionary = _profiles.get(shooter, {})
	if view == null or card.is_empty():
		return
	var panel: Control = card["panel"]
	var from_pos: Vector2 = panel.global_position + panel.size * panel.scale / 2.0
	var to_pos: Vector2 = view.position
	var flight: float = 0.35 * _motion_pace()
	_fx_when_announced(func() -> void:
		var bullet := Polygon2D.new()
		bullet.polygon = _circle_points(5.0, 12)
		bullet.color = Color("ffe066")
		bullet.position = from_pos
		bullet.z_index = 19
		_pawn_layer.add_child(bullet)
		var tween: Tween = create_tween()
		tween.tween_property(bullet, "position", to_pos, flight).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(func() -> void:
			_impact_ring(to_pos, Color("ff6b6b"), 30.0)
			bullet.queue_free())
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now((flight + 0.5 * _motion_pace()) * 1000.0 + 120)))


# ---------------------------------------------------------------------------
# 게임 필(타격감): 화면 흔들림 / 착지 찌그러짐 / 발자국 파동 / 파편 / 플로팅 배지
# ---------------------------------------------------------------------------

## 보드 화면 전체가 intensity(px)만큼 duration초 동안 점점 약해지며 흔들린다.
func screen_shake(intensity: float, duration: float) -> void:
	if not _fx_on() or not GameSession.screen_shake:
		return
	if not _shake_active:
		_shake_origin = position
	_shake_active = true
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(t: float) -> void:
		position = _shake_origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * (1.0 - t), 0.0, 1.0, duration)
	_shake_tween.tween_callback(func() -> void:
		position = _shake_origin
		_shake_active = false)


## 점프가 끝나 발이 닿았다: 말이 납작해졌다가 탱글하게 돌아오고, 밟은 타일이 환해졌다 가라앉는다. big이면 내리찍기(흔들림+충격파).
func _fx_land(view: Node2D, tile: int, big: bool) -> void:
	if not _fx_on() or not is_instance_valid(view):
		return
	var bounce: Node2D = view.get_node_or_null("Bounce")
	if bounce != null:
		bounce.scale = Vector2(1.25, 0.78)
		var squash: Tween = create_tween()
		squash.tween_property(bounce, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if tile >= 0:
		_tile_glow(tile)
	if big:
		Sfx.play(&"slam")
	else:
		# 연달아 걸을 때는 한 칸마다 음높이를 조금씩 올려 다다다닥 달리는 느낌을 낸다 (잠깐 멈추면 처음 높이로).
		var now: int = Time.get_ticks_msec()
		_step_chain = _step_chain + 1 if now - _step_sound_msec < 700 else 0
		_step_sound_msec = now
		Sfx.play(&"hop", 0.0, 0.01, minf(0.95 + 0.05 * float(_step_chain), 1.35))
	if big:
		screen_shake(9.0, 0.25)
		_impact_ring(view.position, Color("fff3bf"), 52.0)
		_burst_shards(view.position, Color("ffd43b"), 10)


func _fx_landed(view: Node2D) -> void:
	if not _fx_on():
		return
	var tile: int = int(view.get_meta("land_tile", -1))
	var big: bool = bool(view.get_meta("land_big", false))
	var thud: bool = bool(view.get_meta("land_thud", false))
	for key: String in ["land_tile", "land_big", "land_thud"]:
		if view.has_meta(key):
			view.remove_meta(key)
	if tile >= 0 or big:
		_fx_land(view, tile, big)
	elif thud:
		Sfx.play(&"thud")
		# 출발선에 쿵 떨어지는 소리 없는 소리: 작은 충격파와 흔들림
		var bounce: Node2D = view.get_node_or_null("Bounce")
		if bounce != null:
			bounce.scale = Vector2(1.3, 0.7)
			create_tween().tween_property(bounce, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_impact_ring(view.position, Color("ced4da"), 30.0)
		screen_shake(4.0, 0.15)


## 타일이 순간 환해졌다가 서서히 원래 색으로 돌아온다 (발자국 파동).
func _tile_glow(tile: int) -> void:
	var view: Control = _tile_views.get(tile)
	if view == null:
		return
	view.modulate = Color(1.7, 1.7, 1.35)
	create_tween().tween_property(view, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 한 점에서 사방으로 튀는 파편 (원샷 파티클).
func _burst_shards(at: Vector2, color: Color, amount: int = 12) -> void:
	if not _fx_on() or not is_inside_tree():
		return
	var particles: CPUParticles2D = _fx_pool.take(&"shards")
	if particles == null:
		particles = _fx_pool.adopt(&"shards", CPUParticles2D.new())
		particles.z_index = 18
		particles.one_shot = true
		particles.texture = COMMON_FLECK
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.08, 0.55, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
		particles.color_ramp = fade
		# 다 터지면 지우지 않고 풀로 돌려놓는다 (노드의 신호에 연결: 노드가 지워지면 연결도 풀린다)
		particles.finished.connect(_fx_pool.give_back.bind(particles))
		_pawn_layer.add_child(particles)
	particles.position = at
	particles.visible = true
	particles.amount = clampi(amount, 1, MAX_BURST_PARTICLES)
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 110.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2(0.0, 320.0)
	# The painted chip has transparent padding; keep its visible body a few pixels wide.
	particles.scale_amount_min = 7.0 / COMMON_FLECK.get_width()
	particles.scale_amount_max = 16.0 / COMMON_FLECK.get_width()
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.angular_velocity_min = -260.0
	particles.angular_velocity_max = 260.0
	particles.damping_min = 50.0
	particles.damping_max = 90.0
	particles.color = color
	particles.restart()  # 풀에서 꺼낸 노드도 처음부터 다시 터진다
	_mark_oneshot(particles, 0.8)


## 실제 말 그림의 윤곽을 남긴다. 점프·회전한 순간의 자세를 고정하고 짧게 흐려진다.
func _fx_trail(view: Node2D, seconds: float, color: Color) -> void:
	if not _fx_on() or not is_inside_tree() or not is_instance_valid(view):
		return
	var generation: int = _fx_generation
	var tracked_view: WeakRef = weakref(view)
	var loops: int = maxi(int(seconds / 0.045), 1)
	var tween: Tween = create_tween().set_loops(loops)
	var sample := {"position": Vector2.INF}
	tween.tween_callback(func() -> void:
		var source: Node2D = tracked_view.get_ref() as Node2D
		if generation != _fx_generation or not _fx_on() or not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_visible_in_tree():
			tween.kill()
			return
		var token: PawnToken = source.get_node_or_null("Bounce/Token") as PawnToken
		if token == null or not token.use_art or token.artwork.is_empty():
			return
		if token.global_position.distance_to(sample.position) < 2.0:
			return
		sample.position = token.global_position
		_pawn_trail_sample(token, color))
	tween.tween_interval(0.045)


func _pawn_trail_sample(token: PawnToken, color: Color) -> void:
	var ghost: Sprite2D = _fx_pool.take(&"trail")
	if ghost == null:
		ghost = _fx_pool.adopt(&"trail", Sprite2D.new())
		ghost.region_enabled = true
		ghost.region_filter_clip_enabled = true
		var silhouette := ShaderMaterial.new()
		silhouette.shader = PAWN_SILHOUETTE
		ghost.material = silhouette
		_pawn_layer.add_child(ghost)
	var region: Rect2 = token.artwork.region
	var factor: float = minf(PawnToken.BODY_BOX.size.x / region.size.x, PawnToken.BODY_BOX.size.y / region.size.y)
	var source: Node2D = token.get_parent().get_parent() as Node2D
	ghost.z_index = mini(source.z_index, 3)
	_pawn_layer.move_child(ghost, 0)  # Behind the pawn, above the board even at z=0.
	ghost.texture = token.artwork.texture
	ghost.region_rect = region
	ghost.transform = _pawn_layer.global_transform.affine_inverse() * token.global_transform * Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2(0, -region.size.y * factor * 0.5))
	ghost.modulate = Color(color.r, color.g, color.b, color.a * 0.32)
	ghost.visible = true
	_mark_oneshot(ghost, 0.24)
	var fade: Tween = ghost.create_tween()
	ghost.set_meta(FxPool.TWEEN_META, fade)
	fade.tween_property(ghost, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_callback(_fx_pool.give_back.bind(ghost))


## 모서리 프로필의 즉각 반응: 좋은 일이면 경쾌하게 점프 + 축하 파편 + 칭찬 배지, 나쁜 일이면 붉게 점멸 + 좌우로 격하게 흔들림 + 억울 배지.
func _profile_react(player_id: int, good: bool, text: String = "") -> void:
	if not _fx_on() or not _player_ids.has(player_id) or not _profiles.has(player_id):
		return
	Sfx.play(&"good" if good else &"bad")
	var panel: Control = _profiles[player_id]["panel"]
	var rect: Rect2 = panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
	if panel.has_meta("react_tween"):
		var previous: Tween = panel.get_meta("react_tween")
		if previous != null and previous.is_valid():
			previous.kill()
		panel.position = panel.get_meta("react_base", panel.position)
	var base: Vector2 = panel.position
	panel.set_meta("react_base", base)
	var tween: Tween = create_tween()
	if good:
		tween.tween_property(panel, "position:y", base.y - 22.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position:y", base.y, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_burst_shards(rect.position + rect.size * Vector2(0.2, 0.4), Color("ffd43b"), 14)
		_burst_shards(rect.position + rect.size * Vector2(0.8, 0.4), Color("69db7c"), 10)
	else:
		for step: int in 6:
			tween.tween_property(panel, "position:x", base.x + (10.0 if step % 2 == 0 else -10.0) * (1.0 - step / 7.0), 0.045)
		tween.tween_property(panel, "position:x", base.x, 0.05)
		var flash := Panel.new()
		flash.position = rect.position
		flash.size = rect.size
		flash.z_index = 36
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.add_theme_stylebox_override("panel", _style(Color(1.0, 0.1, 0.1, 0.45), Color("ff6b6b"), 3, 14, 0, 0))
		add_child(flash)
		var blink: Tween = flash.create_tween()
		for i: int in 3:
			blink.tween_property(flash, "modulate:a", 0.15, 0.09)
			blink.tween_property(flash, "modulate:a", 1.0, 0.09)
		blink.tween_property(flash, "modulate:a", 0.0, 0.2)
		blink.tween_callback(flash.queue_free)
	tween.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.position = base
			panel.remove_meta("react_tween"))
	panel.set_meta("react_tween", tween)
	if text != "":
		_floating_badge(rect.position + Vector2(rect.size.x * 0.5, 6.0), text, Color("ffe066") if good else Color("ff8787"), 34)


## 문장 대신 큰 숫자(+3 등)와 충격 링·파편으로 효과를 알린다.
func _number_pop(at: Vector2, text: String, color: Color) -> void:
	_impact_ring(at, color, 40.0)
	_burst_shards(at, color, 10)
	_floating_badge(at, text, color, 40)


## 카드 뒷면 한 장이 보드에서 그 플레이어 프로필의 손패 칩으로 날아간다. 손패가 가득이면 튕겨 나가며 부서진다.
func _fly_card_to_profile(from: Vector2, player_id: int, rejected: bool) -> void:
	if not _fx_on() or not _profiles.has(player_id):
		return
	var card := Panel.new()
	card.size = Vector2(26, 36)
	card.pivot_offset = card.size / 2.0
	card.position = from - card.size / 2.0
	card.z_index = 60
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _style(Color("ffd43b") if not rejected else Color("868e96"), Color("fff3bf"), 2, 4, 6, 0))
	card.scale = Vector2(0.3, 0.3)
	card.set_meta("hand_card_fx", "rejected" if rejected else "drawn")
	add_child(card)
	_mark_oneshot(card, 0.8)
	var tween: Tween = card.create_tween()
	tween.tween_property(card, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rejected:
		tween.tween_property(card, "rotation", 0.7, 0.3)
		tween.parallel().tween_property(card, "position:y", card.position.y + 30.0, 0.3)
		tween.parallel().tween_property(card, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func() -> void: _burst_shards(from + Vector2(0, 30), Color("adb5bd"), 8))
	else:
		var pips: Control = _profiles[player_id]["hand_pips"]
		var target: Vector2 = get_global_transform().affine_inverse() * pips.get_global_rect().get_center()
		tween.tween_property(card, "position", target - card.size / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(card, "scale", Vector2(0.5, 0.5), 0.45)
		tween.tween_callback(func() -> void: _burst_shards(target, Color("ffd43b"), 8))
	tween.tween_callback(card.queue_free)


## 일회성 연출 노드(파편·충격 링·플로팅 글자·잔상)를 등록한다: 보통은 자기 트윈·타이머가 지우지만,
## 트윈이 도중에 끊기면(연출 취소·판 초기화) 남을 수 있어 턴·라운드 경계에서 sweep_oneshot_fx()가 수명이 지난 것을 치운다.
func _mark_oneshot(node: Node, lifetime: float) -> void:
	node.add_to_group(ONESHOT_FX_GROUP)
	# 게임 배속이 느리면 트윈도 그만큼 늦게 끝난다: 실제 시간 수명은 배속으로 나눈다
	var real_seconds: float = (lifetime + ONESHOT_GRACE_SECONDS) / maxf(Engine.time_scale, 0.1)
	node.set_meta(&"fx_expire_msec", Time.get_ticks_msec() + int(real_seconds * 1000.0))


## 수명이 지난 일회성 연출 노드를 지운다 (force면 모두). 지운 개수를 돌려준다.
func sweep_oneshot_fx(force: bool = false) -> int:
	if not is_inside_tree():
		return 0
	var now: int = Time.get_ticks_msec()
	var swept: int = 0
	for node: Node in get_tree().get_nodes_in_group(ONESHOT_FX_GROUP):
		if node.is_queued_for_deletion() or not is_ancestor_of(node):
			continue
		if force or now >= int(node.get_meta(&"fx_expire_msec", 0)):
			if FxPool.is_pooled(node):
				_fx_pool.give_back(node)  # 풀 노드는 지우지 않고 숨겨 돌려놓는다
			else:
				node.queue_free()
			swept += 1
	return swept


## 위로 솟아올랐다 사라지는 플로팅 텍스트 배지.
func _floating_badge(at: Vector2, text: String, color: Color, font_size: int = 24) -> void:
	var label: Label = _fx_pool.take(&"badge")
	if label == null:
		label = _fx_pool.adopt(&"badge", _make_label(text, font_size, color))
		label.add_theme_constant_override("outline_size", 8)
		label.add_theme_color_override("font_outline_color", Color("1b1405"))
		label.z_index = 60
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	else:
		_restyle_label(label, text, font_size, color)
		label.modulate = Color.WHITE
		label.visible = true
		move_child(label, -1)  # 새 배지가 위에 그려지게
	label.reset_size()
	label.position = at - label.get_minimum_size() / 2.0
	label.pivot_offset = label.get_minimum_size() / 2.0
	label.scale = Vector2(0.4, 0.4)
	_mark_oneshot(label, 1.5)
	var tween: Tween = label.create_tween().set_parallel(true)
	label.set_meta(FxPool.TWEEN_META, tween)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2026-10 여운 패치: 읽을 틈을 늘렸다 (보이는 시간 0.75초 -> 1.2초)
	tween.tween_property(label, "position:y", label.position.y - 56.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(1.2)
	tween.chain().tween_callback(_fx_pool.give_back.bind(label))


## 손패 카드를 보드로 던졌다: 카드가 목표 지점으로 날아가 커졌다가 쾅 내리찍히며 파편이 퍼진다.
func _throw_ghost(target: Vector2) -> void:
	if _drag_ghost == null:
		return
	var ghost: PanelContainer = _drag_ghost
	_drag_ghost = null
	if not _fx_on():
		ghost.queue_free()
		return
	Sfx.play(&"card_throw")
	var tween: Tween = create_tween()
	tween.tween_property(ghost, "global_position", target - ghost.size / 2.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ghost, "scale", Vector2(1.35, 1.35), 0.2)
	tween.tween_property(ghost, "scale", Vector2(0.85, 0.85), 0.07)
	tween.tween_callback(func() -> void:
		_card_impact(target, Color("ffe066")))
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


## 카드 발동 임팩트: 빛 테두리 링 + 파편 + 짧은 화면 흔들림.
func _card_impact(at: Vector2, color: Color) -> void:
	if not _fx_on():
		return
	Sfx.play(&"card_impact")
	_impact_ring(at, color, 70.0)
	_impact_ring(at, Color.WHITE, 40.0)
	_burst_shards(at, color, 16)
	screen_shake(6.0, 0.2)


## 잡힌 말 자리에 맞는 순간의 충격 링 (말이 날아가기 직전).
func _fx_impact_at_pawn(pawn_id: int, delay: float) -> void:
	if not _fx_on():
		return
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if view == null or pawn == null:
		return
	var at: Vector2 = view.position
	var color: Color = PLAYER_COLORS[pawn.owner_id]
	get_tree().create_timer(delay * _motion_pace()).timeout.connect(func() -> void: _impact_ring(at, color, 24.0))


## 기물 아래로 퍼지는 붓결 충격파. 가운데를 비워 기물과 숫자를 가리지 않는다.
func _impact_ring(at: Vector2, color: Color, radius: float) -> void:
	if not _fx_on() or not is_inside_tree():
		return
	var ring: Sprite2D = _fx_pool.take(&"ring")
	if ring == null:
		ring = _fx_pool.adopt(&"ring", Sprite2D.new())
		ring.texture = COMMON_SHOCKWAVE
		ring.region_enabled = true
		if _common_ring_region.size.x <= 0:
			_common_ring_region = PawnArt.visible_region(COMMON_SHOCKWAVE.get_image())
		ring.region_rect = _common_ring_region
		ring.region_filter_clip_enabled = true
		ring.z_index = 0
		_pawn_layer.add_child(ring)
	_pawn_layer.move_child(ring, 0)
	ring.position = at
	var diameter_scale: float = 2.0 / ring.region_rect.size.x
	var shape := Vector2(1.0, 0.65)
	ring.scale = shape * (PAWN_RADIUS * 0.6 * diameter_scale)
	ring.modulate = color.lightened(0.4)
	ring.modulate.a = color.a * 0.82
	ring.visible = true
	_mark_oneshot(ring, 0.3 * _motion_pace())
	var tween: Tween = ring.create_tween().set_parallel(true)
	ring.set_meta(FxPool.TWEEN_META, tween)
	tween.tween_property(ring, "scale", shape * (maxf(radius, 1.0) * diameter_scale), 0.3 * _motion_pace()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3 * _motion_pace())
	tween.chain().tween_callback(_fx_pool.give_back.bind(ring))


## 맞은 말의 자리에서 화면 밖으로 튕겨 나가는 원형 잔상.
func _fly_away(from: Vector2, direction: Vector2, color: Color) -> void:
	var ghost := Polygon2D.new()
	ghost.polygon = _circle_points(PAWN_RADIUS * 2.0, 16)
	ghost.color = color
	ghost.position = from
	ghost.z_index = 18
	_pawn_layer.add_child(ghost)
	_mark_oneshot(ghost, 0.6)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "position", from + direction * 900.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "rotation", 12.0, 0.6)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(ghost.queue_free)


# ---------------------------------------------------------------------------
# 게임 시작 오프닝 (OpeningSequence)
# ---------------------------------------------------------------------------

func _intro_blocks() -> bool:
	return _intro_pending and not instant_roll_for_test


## 게임을 시작하면 증강 선택 전에 4단계 오프닝을 재생한다. 즉시 모드(테스트)에서는 건너뛴다.
func _start_opening() -> void:
	if not is_inside_tree() or state == null:
		return
	if instant_roll_for_test or _opening != null:
		_intro_pending = false
		if state != null:
			_refresh_all()
		return
	_opening = OpeningSequence.new()
	_opening.name = "OpeningSequence"
	add_child(_opening)
	_opening.setup(self)
	_opening.finished.connect(_on_opening_finished)
	_opening.start()


func _on_opening_finished() -> void:
	_opening = null
	_intro_pending = false
	if state == null or manager == null:
		return
	_refresh_all()


func _close_opening() -> void:
	if _opening != null and is_instance_valid(_opening):
		_opening.queue_free()
	_opening = null
	_intro_pending = false


## 화면 위쪽 가운데에 잠깐 떴다 사라지는 안내 토스트.
func _show_top_toast(text: String) -> void:
	var toast := PanelContainer.new()
	toast.add_theme_stylebox_override("panel", _style(Color("101626"), Color("ffe066"), 3, 16, 18, 12))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 75
	var label := _make_label(text, 22, Color("fff3bf"))
	toast.add_child(label)
	add_child(toast)
	toast.reset_size()
	toast.position = Vector2(683.0 - toast.size.x / 2.0 + _off_center.x, 26.0)
	toast.modulate.a = 0.0
	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(toast.queue_free)


# ---------------------------------------------------------------------------
# 뱅! 저격: 상대 프로필을 눌러 고른다
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ACT_09 일기토 데스매치 (중앙 오픈 스테이지: 6종 미니게임 결투장)
# ---------------------------------------------------------------------------

## 이 자리를 이 화면에서 직접 조작하는가 (AI 대전·온라인은 내 자리만, 핫시트는 모두).
func _duel_local(player_id: int) -> bool:
	return not ai_mode or player_id == local_player_id


## 카드를 놓은 위치가 어느 상대를 가리키는가: 상대 프로필 위, 또는 보드 위에 나와 있는 상대 말 위. 없으면 -1.
func _duel_target_at(pointer: Vector2, player_id: int) -> int:
	for other: int in _player_ids:
		if other == player_id or not _profiles.has(other):
			continue
		var panel: Control = _profiles[other]["panel"]
		if (panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)).has_point(pointer):
			return other
	var best: int = -1
	var best_distance: float = 28.0
	for pawn: PlayerPawn in state.pawns:
		if pawn.owner_id == player_id or pawn.carrier != null or not pawn.has_left_start or pawn.is_finished:
			continue
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view == null or not view.visible:
			continue
		var distance: float = (view.position + _pawn_layer.position).distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = pawn.owner_id
	return best


func _on_duel_event(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"duel_started":
			_log_line("[결투] %s가 %s에게 일기토 데스매치를 신청했습니다!" % [_player_name(int(data["challenger"])), _player_name(int(data["defender"]))], Color("ffd43b"))
			if _fx_on():
				_open_duel_arena(int(data["challenger"]), int(data["defender"]), int(data["game"]), data["setup"])
		&"duel_revealed":
			var duel_text: String = "[결투] %s vs %s : [%s] %s → %s" % [_player_name(int(data["challenger"])), _player_name(int(data["defender"])), DuelRules.game_name(int(data["game"])), str(data["detail"]), "무승부, 재대결!" if int(data["winner"]) == -1 else "%s 승리!" % _player_name(int(data["winner"]))]
			# 로그도 결투장이 승패를 다 보여 준 뒤에 남긴다: 결투장에 공개를 먼저 넘긴 다음 연출 큐에 세운다
			_push_duel_event(kind, data)
			enqueue_step(func() -> void: _log_line(duel_text, Color("ffd43b")))
			return
		&"duel_resolved":
			_push_duel_event(kind, data)  # 사출 연출이 공개를 기다리도록 결투장이 먼저 받는다
			_on_duel_resolved(data)
			return
	_push_duel_event(kind, data)


func _push_duel_event(kind: StringName, data: Dictionary) -> void:
	if _duel_arena != null and is_instance_valid(_duel_arena):
		_duel_arena.push_event(kind, data)
	elif not _fx_on():
		_duel_auto_drive.call_deferred()


func _open_duel_arena(challenger: int, defender: int, game: int, game_setup: Dictionary) -> void:
	if _duel_arena != null and is_instance_valid(_duel_arena):
		_duel_arena.queue_free()
	var seats: Array[int] = []
	for seat: int in [challenger, defender]:
		if _duel_local(seat):
			seats.append(seat)
	_duel_arena = DuelArena.new()
	_duel_arena.setup(self, challenger, defender, seats, game, game_setup)
	_duel_arena.game_selected.connect(func(game_id: int) -> void:
		_log_line("[결투 종목] %s" % DuelRules.game_name(game_id), Color("ffd43b")))
	_duel_arena.value_chosen.connect(func(player_id: int, value: int) -> void: _act(&"duel_pick", {"player_id": player_id, "value": value}))
	_duel_arena.closed.connect(func() -> void:
		_duel_arena = null
		_refresh_all())
	add_child(_duel_arena)
	# 카드 발동 알림이 끝난 뒤 열린다 (그 전에 온 이벤트는 결투장 큐에 쌓인다).
	var arena_ref: WeakRef = weakref(_duel_arena)  # 결투장 노드를 직접 잡지 않는다 (먼저 닫혀 지워지면 람다가 지워진 노드를 받는다)
	_fx_when_announced(func() -> void:
		var arena: DuelArena = arena_ref.get_ref() as DuelArena
		if arena != null and not arena.is_queued_for_deletion():  # 알림이 끝나기 전에 결투장이 닫혔으면(되감기·강제 종료) 열지 않는다
			arena.open())
	if not _fx_holding():
		_duel_arena.open()


## 결투 결과: 진 사람의 말이 출발선으로 장외 사출되고(처치 컷신은 pawn_sent_to_start가 띄운다) 이긴 사람의 말이 +3칸 전진한다.
func _on_duel_resolved(data: Dictionary) -> void:
	var pawn_id: int = int(data["pawn_id"])
	if pawn_id == -1:
		return
	var winner: int = int(data["winner"])
	var loser: int = int(data["loser"])
	var resolved_text: String = "[결투] %s이(가) %s의 선두 %s(%d번)을(를) 출발선으로 사출시켰습니다!%s" % [_player_name(winner), _player_name(loser), _pawn_name(pawn_id), int(data["from"]), "  승자의 %s +%d칸 전진 (%d번 → %d번)" % [_pawn_name(int(data["boost_pawn_id"])), int(data.get("advance", DuelRules.winner_advance())), int(data["boost_from"]), int(data["boost_to"])] if int(data["boost_pawn_id"]) != -1 else ""]
	if not _fx_on():
		_log_line(resolved_text, Color("ff6b6b"))
		return
	enqueue_step(func() -> void: _log_line(resolved_text, Color("ff6b6b")))
	# 피격 연출은 연출 큐로 보낸다: 결투장이 승패를 다 보여 준 뒤에 재생된다 (_fx_holding이 결투장 공개를 기다린다).
	enqueue_step(func() -> void:
		Sfx.play(&"shot")
		var view: Node2D = _pawn_views.get(pawn_id)
		if view == null or not is_instance_valid(view):
			return
		var hit_pos: Vector2 = view.position
		_fx_until_msec = maxi(_fx_until_msec, _msec_from_now(1100.0 * _motion_pace()))
		await get_tree().create_timer(0.3 * _motion_pace()).timeout
		screen_shake(9.0, 0.25)
		_impact_ring(hit_pos, Color("ff6b6b"), 54.0)
		_impact_ring(hit_pos, Color.WHITE, 30.0)
		_burst_shards(hit_pos, Color("ff8787"), 12)
		_profile_react(loser, false)
		_profile_react(winner, true), pawn_id)


## 즉시 모드(테스트·ui_smoke): 결투장 없이 내 자리의 값을 바로 낸다 (봇과 같은 규칙으로 무작위).
func _duel_auto_drive() -> void:
	if manager == null or not manager.duel_pending():
		return
	var duel: Dictionary = manager.pending_duel()
	var game: int = int(duel["game"])
	var rng := RandomNumberGenerator.new()
	if game == DuelRules.Game.BARREL:
		var seat: int = int(duel["turn"])
		if _duel_local(seat):
			_act(&"duel_pick", {"player_id": seat, "value": DuelRules.bot_input(game, duel["setup"], seat == int(duel["challenger"]), rng, duel["opened"])})
		return
	for seat: int in [int(duel["challenger"]), int(duel["defender"])]:
		if _duel_local(seat) and not (duel["picks"] as Dictionary).has(seat):
			_act(&"duel_pick", {"player_id": seat, "value": DuelRules.bot_input(game, duel["setup"], seat == int(duel["challenger"]), rng)})
			break


func _begin_snipe_pick(player_id: int, card_id: StringName) -> void:
	var card: BaseCard = CardRegistry.get_card(card_id)
	if not _card_usable_now(player_id, card):
		_log_line("지금은 [%s]를 쓸 수 없습니다 (내 턴 시작 구간에서만)." % card.display_name, Color("868e96"))
		return
	var targets: Array[int] = BangCommand.target_players(state, player_id)
	if targets.is_empty():
		_log_line("[%s] 보드 위에 나와 있는 상대 말이 없습니다." % card.display_name, Color("868e96"))
		return
	_tile_pick_active = true
	_tile_pick_player = player_id
	_tile_pick_card = card_id
	_snipe_pick = true
	_pick_banner.text = "[BANG!] 쏠 상대의 프로필을 눌러 주세요"
	_pick_banner.visible = true
	_pick_cancel.visible = true
	for victim: int in targets:
		_snipe_marks[victim] = _make_snipe_mark(victim)
	_refresh_controls()


## 프로필 위에 겹치는 금색 표식 (은은하게 깜빡이고, 커서를 올리면 밝아진다).
func _make_snipe_mark(victim: int) -> Control:
	var panel: Control = _profiles[victim]["panel"]
	var rect: Rect2 = panel.get_global_transform() * Rect2(Vector2.ZERO, panel.size)
	var mark := Panel.new()
	mark.position = rect.position
	mark.size = rect.size
	mark.z_index = 35
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_stylebox_override("panel", _style(Color(1.0, 0.83, 0.2, 0.16), Color("ffd43b"), 4, 14, 24, 0))
	var front: PlayerPawn = state.front_pawn_of(victim)
	var label := _make_label("저격!", 18, Color("fff3bf"))
	label.position = Vector2(0, rect.size.y - 26)
	label.size = Vector2(rect.size.x, 22)
	label.tooltip_text = "선두 말 %d번 타일" % front.current_tile_idx
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("3b2a00"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_child(label)
	add_child(mark)
	var pulse: Tween = mark.create_tween().set_loops()
	pulse.tween_property(mark, "modulate:a", 0.55, 0.5)
	pulse.tween_property(mark, "modulate:a", 1.0, 0.5)
	return mark


func _end_snipe_marks() -> void:
	_snipe_pick = false
	for mark: Control in _snipe_marks.values():
		if is_instance_valid(mark):
			mark.queue_free()
	_snipe_marks.clear()


func _snipe_target_at(pointer: Vector2) -> int:
	for victim: int in _snipe_marks.keys():
		var mark: Control = _snipe_marks[victim]
		if is_instance_valid(mark) and Rect2(mark.position, mark.size).has_point(pointer):
			return victim
	return -1


## 저격 모드의 입력: 표식이 붙은 프로필을 누르면 그 상대를 쏜다. 다른 곳을 누르거나 오른쪽 버튼이면 취소한다.
func _handle_snipe_input(event: InputEvent) -> bool:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var hovered: int = _snipe_target_at(motion.position)
		for victim: int in _snipe_marks.keys():
			(_snipe_marks[victim] as Control).scale = Vector2.ONE * (1.04 if victim == hovered else 1.0)
		return false
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed:
		return false
	if click.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_tile_pick()
		return true
	if click.button_index != MOUSE_BUTTON_LEFT:
		return false
	var victim: int = _snipe_target_at(click.position)
	if victim == -1:
		return false  # 취소 버튼 등 다른 UI는 그대로 누를 수 있다
	_complete_snipe(victim)
	return true


func _complete_snipe(victim: int) -> void:
	var player_id: int = _tile_pick_player
	var card_id: StringName = _tile_pick_card
	_cancel_tile_pick()
	_play_card_with(victim, player_id, card_id, "target_player")


# ---------------------------------------------------------------------------
# 타일 선택 모드 (TRP/SUM 카드)
# ---------------------------------------------------------------------------

func _begin_tile_pick(player_id: int, card_id: StringName) -> void:
	var card: BaseCard = CardRegistry.get_card(card_id)
	if not _card_usable_now(player_id, card):
		_log_line("지금은 [%s]를 쓸 수 없습니다 (내 턴 시작 구간에서만)." % card.display_name, Color("868e96"))
		return
	_tile_pick_active = true
	_tile_pick_player = player_id
	_tile_pick_card = card_id
	var valid_count: int = 0
	for index: int in BoardSpec.tile_count:
		var valid: bool = card.is_legal(state, player_id, {"tile": index})
		(_pick_marks[index] as BoardSkin.Ring).visible = valid
		if valid:
			valid_count += 1
	if valid_count == 0:
		_log_line("[%s]를 놓을 수 있는 타일이 없습니다." % card.display_name, Color("868e96"))
		_cancel_tile_pick()
		return
	var purpose: String = "함정을 설치할" if card.category == GameEnums.CardCategory.TRAP else ("순간이동할" if card_id == &"ACT_13" else "소환할")
	_pick_banner.text = "[%s] P%d - %s 타일을 고르세요 (초록 테두리)" % [card.display_name, player_id, purpose]
	_pick_banner.visible = true
	_pick_cancel.visible = true
	_refresh_controls()


func _on_pick_cancel_pressed() -> void:
	_cancel_aim()
	_cancel_tile_pick()


func _cancel_tile_pick() -> void:
	if not _tile_pick_active and _pick_banner != null and not _pick_banner.visible:
		return
	_tile_pick_active = false
	_tile_pick_card = &""
	_tile_pick_skill_pawn = -1
	_end_snipe_marks()
	if _pick_banner != null:
		_pick_banner.visible = false
	if _pick_cancel != null:
		_pick_cancel.visible = false
	for mark: BoardSkin.Ring in _pick_marks.values():
		mark.visible = false
	if manager != null and manager.state != null:
		_refresh_controls()


func _on_tile_gui_input(event: InputEvent, index: int) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or not _tile_pick_active or _snipe_pick:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_tile_pick()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_complete_tile_pick(index)


## 고른 타일로 카드를 사용한다. 그 타일에 쓸 수 없으면 선택 모드를 유지한다.
func _complete_tile_pick(tile: int) -> void:
	if not _tile_pick_active:
		return
	if _tile_pick_skill_pawn != -1:
		var plane: PlayerPawn = state.get_pawn(_tile_pick_skill_pawn)
		if plane == null or not PawnSkills.plane_targets(plane).has(tile):
			_log_line("%d번 타일로는 날아갈 수 없습니다. 빵집이나 코너를 고르세요." % tile, Color("ff8787"))
			return
		var plane_id: int = plane.entity_id
		_cancel_tile_pick()
		_act(&"use_skill", {"pawn_id": plane_id, "tile": tile})
		return
	var card: BaseCard = CardRegistry.get_card(_tile_pick_card)
	if not card.is_legal(state, _tile_pick_player, {"tile": tile}):
		_log_line("%d번 타일에는 [%s]를 쓸 수 없습니다. 다른 타일을 고르세요." % [tile, card.display_name], Color("ff8787"))
		return
	var player_id: int = _tile_pick_player
	var card_id: StringName = _tile_pick_card
	_cancel_tile_pick()
	_card_impact(_tile_center(tile), Color("ffe066"))
	_tile_glow(tile)
	_act(&"play_card", {"player_id": player_id, "card_id": card_id, "tile": tile})


# ---------------------------------------------------------------------------
# 오버레이: 선택창 / 증강 드래프트 / 결과창
# ---------------------------------------------------------------------------

## 밝은 본체와 녹색 테두리의 공통 이미지 패널.
func _panel_style() -> StyleBoxTexture:
	return UiSkin.panel("panel", 20.0)


func _new_overlay(alpha: float = 0.7) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	return overlay


func _show_choice(title: String, options: Array[Dictionary], on_pick: Callable, columns: int = 1) -> void:
	_close_choice()
	_choice_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	UiSkin.bind_light_text(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_label(title, 16, Color("f1f3f5")))
	var grid := GridContainer.new()
	grid.columns = columns
	box.add_child(grid)
	for option: Dictionary in options:
		var button: Button = _make_button(str(option["label"]), _on_choice_picked.bind(option["value"], on_pick), 14)
		button.custom_minimum_size = Vector2(60, 32)
		grid.add_child(button)
	box.add_child(_make_button("취소", _close_choice, 13))
	add_child(_choice_overlay)


func _on_choice_picked(value: Variant, on_pick: Callable) -> void:
	_close_choice()
	on_pick.call(value)


func _close_choice() -> void:
	_pawn_choice_cards = []
	if _choice_overlay != null:
		_choice_overlay.queue_free()
		_choice_overlay = null


func _refresh_overlays() -> void:
	_refresh_draft_overlay()
	_refresh_stack_overlay()
	if manager.is_game_over and _result_overlay == null and not _result_hold:
		_show_result_overlay()


## 드래프트 중이면 아직 고르지 않은 첫 플레이어(P1 -> P4 순서)의 3지선다를 화면 중앙에 띄운다.
func _refresh_draft_overlay() -> void:
	if _intro_blocks():
		_close_draft_overlay()
		return
	if _fx_on() and manager.current_state == TurnManager.State.PHASE_ROUND_START and not manager.is_game_over:
		if _fx_motion_pending():
			_draft_wait_motion = true
			_motion_retry = true
			_close_draft_overlay()
			return
		if _draft_wait_motion:
			_draft_wait_motion = false
			_start_beat(DRAFT_OPEN_BEAT / maxf(_pace(), 0.01))
		if Time.get_ticks_msec() < _beat_until_msec:
			_close_draft_overlay()
			return
	var pending: Array[int] = []
	if manager.current_state == TurnManager.State.PHASE_ROUND_START and not manager.is_game_over:
		for candidate: int in manager.draft_pending_players():
			# AI 모드에서는 P1이 고른 뒤 봇들이 BotController로 자동 선택하므로 오버레이에는 사람만 나온다.
			if not (ai_mode and candidate != local_player_id):
				pending.append(candidate)
	if pending.is_empty():
		_close_draft_overlay()
		return
	# 라운드 안내 -> 증강 선택 창 -> (선택이 끝나면) 일괄 공개 순서: 라운드 카드가 먼저 뜨고 끝난 뒤에 증강 창이 올라온다.
	if _fx_on() and _announcer != null:
		if _draft_banner_round != state.round_number:
			_draft_banner_round = state.round_number
			_draft_entrance = true
		if _announcer.active and _draft_overlay == null:
			return
	var player_id: int = pending[0]
	if _auto_draft_enabled and not ai_mode and player_id != _player_ids[0]:
		manager.auto_pick_draft(player_id)
		_log_line("P%d 증강 자동 선택 완료" % player_id, Color("868e96"))
		_refresh_all()
		return
	if _draft_overlay != null and _draft_player == player_id and _draft_signature_value == _draft_signature(player_id):
		return
	_build_draft_overlay(player_id, pending.size())


func _draft_signature(player_id: int) -> String:
	var parts: Array[String] = [str(player_id)]
	for offer: StringName in manager.draft_offers_for(player_id):
		parts.append(str(offer))
	for index: int in GameEnums.DRAFT_OFFER_COUNT:
		parts.append("r" if manager.draft_reroll_used(player_id, index) else "-")
	return "|".join(parts)


## 증강 카드 하나의 표시 정보: 엠블럼 글자·테두리 색·제목·설명.
func _augment_card_info(definition: AugmentDef, player_id: int) -> Dictionary:
	return augment_card_info(definition, state, player_id)


## 판 밖(규칙 도감)에서도 쓰는 증강 카드 정보. game_state가 null이어도 된다.
static func augment_card_info(definition: AugmentDef, game_state: GameState, player_id: int) -> Dictionary:
	var glyph: String = "?"
	var color: Color = definition.display_color()
	var title: String = definition.display_name
	match definition.category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			var kind: GameEnums.PawnKind = definition.payload
			var unit_no: int = definition.units[0]
			glyph = PawnCatalog.unit_letter(kind, unit_no)
			title = "[기물 진화] %s: %s" % [PawnCatalog.display_set_name(kind), PawnCatalog.unit_label(kind, unit_no).split(":")[-1]]
		GameEnums.AugmentCategory.TOOL_SWAP:
			var tool: BaseJudgmentTool = ToolRegistry.create(definition.payload)
			glyph = str((TOOL_CARDS.get(tool.tool_id, ["?"]) as Array)[0])
			title = "[판정 도구] %s" % tool.display_name
		GameEnums.AugmentCategory.LAW_ENACT:
			var law: LawResource = LawRegistry.create(definition.payload)
			glyph = "법"
			title = "[교칙 제정] %s" % law.law_name
		GameEnums.AugmentCategory.SUPER_GAMBLE:
			glyph = "초"
			title = definition.display_name
		GameEnums.AugmentCategory.UTILITY:
			glyph = "보"
			title = definition.display_name
		_:
			glyph = "J"
			title = "[카드 패키지] 생떼 카드 %d장" % definition.card_count()
	# 텍스트 다이어트: 카드마다 되풀이되는 공통 문구(이미 가진 기물·법전 졸업 안내)는 본문에서 빼고 드래프트 아래 공통 안내 바에 한 번만 둔다
	var lines: PackedStringArray = []
	for line: String in definition.describe(game_state, player_id).split("\n"):
		if not line.begins_with("※") and not AugmentDef.is_common_note(line):
			lines.append(line.trim_prefix("◆ "))  # ◆ 머리표는 쓰지 않는다 (번역 사전에 머리표를 뗀 짝이 있다)
	# 판정 도구: 핵심 한 줄 + [최소 N칸 ~ 최대 M칸] 요약을 먼저 크게, 긴 족보표는 구분선 아래 작은 보조 정보로
	var summary: String = ""
	var detail: String = ""
	if definition.category == GameEnums.AugmentCategory.TOOL_SWAP:
		# 공통 문구([내 판정 도구 즉시 교체])를 뺀 나머지 중 표의 desc 줄은 핵심, spec(족보표) 줄은 보조
		var core_lines: PackedStringArray = []
		for line: String in definition.desc.replace("{p1}", definition.param_1).replace("{p2}", definition.param_2).split("\n"):
			if not AugmentDef.is_common_note(line) and line.strip_edges() != "":
				core_lines.append(line.trim_prefix("◆ "))
		var detail_lines: PackedStringArray = []
		for line: String in lines:
			if not core_lines.has(line):
				detail_lines.append(line)
		lines = core_lines
		detail = "\n".join(detail_lines)
		var span: Array[int] = AugmentDef.tool_step_range(definition.payload)
		if span.size() == 2:
			summary = "최소 %d칸 ~ 최대 %d칸" % [span[0], span[1]]
	# 기물 진화: 판정 도구처럼 구분선 위에 패시브(둘이면 줄 나눔), 아래에 필살기. [패시브]·[필살기] 머리말은 쓰지 않는다.
	var skill_text: String = ""
	var skill_only: bool = false
	if definition.category == GameEnums.AugmentCategory.PAWN_EVOLUTION:
		var evo_kind: GameEnums.PawnKind = definition.payload
		var evo_unit: int = definition.units[0]
		var passive: String = PawnCatalog.passive_lines(evo_kind, evo_unit)
		lines = PackedStringArray([passive]) if passive != "" else PackedStringArray()
		skill_text = PawnCatalog.skill_line(PawnCatalog.skill_of(PawnCatalog.sub_type_of(evo_kind, evo_unit)))
		if lines.is_empty() and skill_text != "":
			skill_only = true
			lines = PackedStringArray([skill_text])  # 패시브가 없으면 필살기만 (구분선 없이)
			skill_text = ""
	if definition.title != "":
		title = definition.title  # augments_table.csv의 title
	title = AugmentDef.strip_title_tag(title)  # 제목 앞 [기물 진화]·[판정 도구]·[특수 승리] 같은 계열 머리표는 뗀다
	var tag_text: String = definition.display_category()
	return {"glyph": glyph, "color": color, "title": title, "desc": "\n".join(lines), "summary": summary, "detail": detail, "skill": skill_text, "category": tag_text, "art": AugmentArt.load_first(AugmentArt.candidates(definition)), "super": definition.category == GameEnums.AugmentCategory.SUPER_GAMBLE, "tier": definition.tier,
		"display_group": definition.display_group(),
		"skill_only": skill_only,
		"self_risk": definition.category == GameEnums.AugmentCategory.SUPER_GAMBLE and SuperAugments.SELF_RISK.has(StringName(str(definition.payload)))}


## 150px 후광 / 120px 네온 메달 / 110px 원형 이미지. 이미지가 없으면 글자.
static func _make_emblem(glyph: String, color: Color, texture: Texture2D = null) -> Control:
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(150, 150)
	emblem.size = Vector2(150, 150)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := Panel.new()
	glow.position = Vector2(0, 0)
	glow.size = Vector2(150, 150)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_box: StyleBoxFlat = _style(Color(color.r, color.g, color.b, 0.22), Color(color.r, color.g, color.b, 0.0), 0, 75, 0, 0)
	glow.add_theme_stylebox_override("panel", glow_box)
	emblem.add_child(glow)
	var disc := Panel.new()
	disc.position = Vector2(15, 15)
	disc.size = Vector2(120, 120)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc_box: StyleBoxFlat = _style(color.darkened(0.62), color, 5, 60, 0, 0)
	disc_box.shadow_color = Color(color.r, color.g, color.b, 0.7)
	disc_box.shadow_size = 18
	disc_box.shadow_offset = Vector2.ZERO
	disc.add_theme_stylebox_override("panel", disc_box)
	emblem.add_child(disc)
	if texture != null:
		var art: TextureRect = AugmentArt.make_texture(texture, 110.0)
		art.position = Vector2(5, 5)
		disc.add_child(art)
		# Draw a transparent ring above the image; shader clips only its inner art.
		var ring := Panel.new()
		ring.name = "EmblemRing"
		ring.size = Vector2(120, 120)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, color, 5, 60, 0, 0))
		disc.add_child(ring)
		return emblem
	var mark := _make_label(glyph, 56 if glyph.length() <= 1 else 38, color.lightened(0.55))
	mark.name = "EmblemGlyph"
	mark.position = Vector2(0, 0)
	mark.size = Vector2(120, 120)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_color_override("font_outline_color", color.darkened(0.7))
	mark.add_theme_constant_override("outline_size", 6)
	disc.add_child(mark)
	return emblem


## 260x390 세로 증강 카드 (위 45% 엠블럼 / 중간 15% 제목 / 아래 40% 설명). 호버하면 1.06배로 커지며 금빛 테두리 광채가 밝아진다.
func _make_augment_card(info: Dictionary, on_pick: Callable) -> Button:
	return make_augment_card(info, on_pick)


## 판 밖(규칙 도감)에서도 쓰는 증강 카드. base_scale로 줄여 보여 줄 수 있다 (호버 확대도 그 배율 기준).
## static_frame: 도감처럼 보기만 하는 곳에서는 테두리 후광(번짐)과 마우스를 올렸을 때 커지는 효과를 끈다.
static func make_augment_card(info: Dictionary, on_pick: Callable, base_scale: float = 1.0, static_frame: bool = false, compact: bool = false) -> Button:
	var color: Color = info["color"]
	var supply_card: bool = AugmentDef.SUPPLY_GROUPS.has(StringName(str(info.get("display_group", ""))))
	# compact: 도감용 낮은 카드 (높이 AUGMENT_COMPACT_HEIGHT). 세로 위치는 모두 같은 비율로 줄인다 (배경 그림도 그 비율로 늘어난다).
	var card_size: Vector2 = Vector2(AUGMENT_CARD_SIZE.x, AUGMENT_COMPACT_HEIGHT) if compact else AUGMENT_CARD_SIZE
	var k: float = card_size.y / AUGMENT_CARD_SIZE.y
	var card := Button.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size / 2.0
	card.scale = Vector2.ONE * base_scale
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = false
	var box: StyleBoxFlat = _style(Color("12151f"), color, 3, 16, 8, 0)
	box.shadow_color = Color(color.r, color.g, color.b, 0.35)
	box.shadow_offset = Vector2.ZERO
	var tier: String = str(info.get("tier", "NORMAL"))
	if tier == "PRISMA":
		# PRISMA(초증강 기본): 보라색 네온 후광 + 황금 테두리
		box = _style(Color("160c26"), Color("ffd43b"), 5, 16, 8, 0)
		box.shadow_color = Color(0.62, 0.3, 0.95, 0.85)
		box.shadow_size = 22
		box.shadow_offset = Vector2.ZERO
	elif tier == "HOLO":
		# HOLO(법전 전용, 가장 희귀): 크리스탈 청록 테두리 + 청록 -> 분홍 -> 금빛으로 천천히 도는 무지개 후광
		box = _style(Color("08171d"), Color("b8f6ff"), 5, 16, 8, 0)
		box.shadow_color = HOLO_GLOW[0]
		box.shadow_size = 22
		box.shadow_offset = Vector2.ZERO
	elif tier == "GOLD":
		# GOLD: 황금 테두리와 금빛 후광
		box = _style(Color("1a1608"), Color("ffd43b"), 4, 16, 8, 0)
		box.shadow_color = Color(1.0, 0.83, 0.23, 0.6)
		box.shadow_size = 16
		box.shadow_offset = Vector2.ZERO
	if supply_card:
		# 보급의 희귀도보다 효과 분류 색을 우선한다 (전군 돌연변이 PRISMA도 파랑).
		box.border_color = color
		box.shadow_color = Color(color.r, color.g, color.b, 0.35)
	if static_frame:
		box.shadow_size = 0
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(style_name, box)
	if tier == "HOLO" and not static_frame:
		# 무지개 후광은 카드가 살아 있는 동안만 돈다 (카드가 해제되면 트윈도 같이 멈춘다)
		var shimmer: Tween = card.create_tween().set_loops()
		for index: int in HOLO_GLOW.size():
			var from: Color = HOLO_GLOW[index]
			var to: Color = HOLO_GLOW[(index + 1) % HOLO_GLOW.size()]
			shimmer.tween_method(func(t: float) -> void: box.shadow_color = from.lerp(to, t), 0.0, 1.0, 0.9)
	card.add_child(AugmentCardSkin.make_background(color, card_size, box))
	var emblem: Control = _make_emblem(str(info["glyph"]), color, info.get("art") as Texture2D)
	emblem.scale = Vector2.ONE * k
	emblem.position = Vector2((card_size.x - 150.0 * k) / 2.0, 14.0 * k)
	card.add_child(emblem)
	if bool(info.get("self_risk", false)):
		# 내 말도 휘말려 사출될 수 있는 초증강: 카드 왼쪽 위 경고 아이콘 (카드와 같은 그림), 커서를 대면 주의 문구
		var risk := CardSkin.WarningIcon.new()
		risk.name = "SelfRiskIcon"
		risk.position = Vector2(14, 14)
		risk.size = Vector2(38, 38)
		risk.mouse_filter = Control.MOUSE_FILTER_PASS  # 툴팁은 받고 클릭은 카드로 넘긴다
		risk.mouse_default_cursor_shape = Control.CURSOR_HELP
		risk.tooltip_text = SuperAugments.SELF_RISK_NOTE
		card.add_child(risk)
	var title_width: float = card_size.x - 36.0
	var shown_title: String = L10n.t(str(info["title"]))
	# 제목이 두 줄 칸(54px)에 다 들어가는 크기로: 띄어쓰기 없는 긴 이름(일본어 등)은 글자 단위로 나눈다
	var title_px: int = CardSkin.fit_px(shown_title, title_width, 54.0 * k, 20, 12)
	var measured_width: float = CardSkin.FONT.get_string_size(shown_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
	# Nearly one-line names should not leave just one or two syllables on a second line.
	if measured_width > title_width and measured_width <= title_width * 1.2:
		title_px = maxi(12, mini(title_px, floori(title_px * title_width / measured_width)))
	var title := _make_label("", title_px, Color("ffffff"))
	title.position = Vector2(18, 170.0 * k)
	title.size = Vector2(title_width, 54.0 * k)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.text = str(info["title"])
	card.add_child(title)
	var category_bottom: float = 0.0
	if supply_card:
		# 색만으로 구분하지 않도록 제목과 설명 사이에 실제 분류 이름을 표시한다.
		var category_text: String = str(info["category"])
		var badge := _make_label(category_text, 14, Color("17211f"))
		badge.name = "AugmentCategory"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_width: float = minf(card_size.x - 32.0, badge.get_theme_font("font").get_string_size(L10n.t(category_text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 22.0)
		badge.position = Vector2((card_size.x - badge_width) / 2.0, 225.0 * k)
		badge.size = Vector2(badge_width, maxf(20.0, 22.0 * k))
		badge.add_theme_stylebox_override("normal", _style(color, color.lightened(0.25), 1, 9, 0, 0))
		card.add_child(badge)
		category_bottom = badge.position.y + badge.size.y + 6.0
	# 설명 칸 (카드 아래 끝까지). 판정 도구는 [핵심 한 줄] [최소~최대 요약] ─ [작은 족보표] 순서로 나눠 쓴다.
	var text_top: float = maxf(240.0 * k, category_bottom)
	var text_bottom: float = card_size.y - 12.0
	var detail_text: String = str(info.get("detail", ""))
	var summary_text: String = str(info.get("summary", ""))
	var detail_h: float = 0.0
	if detail_text != "":
		# 족보표는 아래쪽 보조 칸 (작은 글자, 구분선 위)
		detail_h = maxf(62.0 * k, 52.0)  # 낮은 카드에서도 족보표 세 줄은 남긴다
		var detail_box := Vector2(card_size.x - 28.0, detail_h)
		var detail := _make_label("", 12, Color("98a1ad"))
		detail.name = "AugmentDetail"
		detail.position = Vector2(14, text_bottom - detail_h)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(detail_box.x, 0)
		detail.size = detail_box
		detail.clip_text = true
		detail.add_theme_font_size_override("font_size", CardSkin.fit_px(L10n.t(detail_text), detail_box.x, detail_box.y, 13, 9, NAN, detail.get_theme_font("font")))
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.text = detail_text
		card.add_child(detail)
		var rule := ColorRect.new()
		rule.name = "AugmentDetailRule"
		rule.color = Color(color.r, color.g, color.b, 0.55)
		rule.position = Vector2(40, text_bottom - detail_h - 6.0)
		rule.size = Vector2(card_size.x - 80.0, 2)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rule)
		text_bottom -= detail_h + 10.0
	var skill_text: String = str(info.get("skill", ""))
	if skill_text != "":
		# 기물 필살기: 구분선 아래 칸 (패시브보다 조금 작게, 필살기 색)
		var skill_h: float = 62.0 * k  # 위 패시브 칸(두 줄)과 반씩 나눈다
		var skill_box := Vector2(card_size.x - 28.0, skill_h)
		var skill := _make_label("", 16, PAWN_SKILL_COLOR)
		skill.name = "AugmentSkill"
		skill.position = Vector2(14, text_bottom - skill_h)
		skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skill.custom_minimum_size = Vector2(skill_box.x, 0)
		skill.size = skill_box
		skill.clip_text = true
		skill.add_theme_font_size_override("font_size", CardSkin.fit_px(L10n.t(skill_text), skill_box.x, skill_box.y, 16, 10, NAN, skill.get_theme_font("font")))
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill.text = skill_text
		card.add_child(skill)
		var skill_rule := ColorRect.new()
		skill_rule.name = "AugmentSkillRule"
		skill_rule.color = Color(color.r, color.g, color.b, 0.55)
		skill_rule.position = Vector2(40, text_bottom - skill_h - 6.0)
		skill_rule.size = Vector2(card_size.x - 80.0, 2)
		skill_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(skill_rule)
		text_bottom -= skill_h + 10.0
	if summary_text != "":
		# 한눈에 보는 이동 범위: 크고 밝게 (핵심 문구가 없으면 설명 칸 전체를 쓴다)
		var only: bool = str(info["desc"]).strip_edges() == ""
		var summary_h: float = text_bottom - text_top if only else 30.0
		var summary := _make_label("", 20, Color("ffe066"))
		summary.name = "AugmentSummary"
		summary.position = Vector2(14, text_bottom - summary_h)
		summary.size = Vector2(card_size.x - 28.0, summary_h)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.clip_text = true
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		summary.add_theme_font_size_override("font_size", CardSkin.fit_px(L10n.t(summary_text), card_size.x - 28.0, summary_h, 24 if only else 20, 13))
		summary.add_theme_color_override("font_outline_color", Color.BLACK)
		summary.add_theme_constant_override("outline_size", 4)
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		summary.text = summary_text
		card.add_child(summary)
		text_bottom -= summary_h + 2.0
	var desc := _make_label("", 19, PAWN_SKILL_COLOR if bool(info.get("skill_only", false)) else Color("eef1f4"))
	desc.name = "AugmentDesc"
	desc.position = Vector2(14, text_top)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desc_box := Vector2(card_size.x - 28.0, text_bottom - text_top)
	desc.custom_minimum_size = Vector2(desc_box.x, 0)
	desc.size = desc_box
	desc.clip_text = true
	# 핵심 효과는 예전(17/14px)보다 2~3px 크게 시작해 칸에 맞춘다 (공통 문구가 빠져 자리가 남는다)
	desc.add_theme_font_size_override("font_size", CardSkin.fit_px(L10n.t(str(info["desc"])), desc_box.x, desc_box.y, 20 if str(info["desc"]).length() <= 70 else 17, 10))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if summary_text != "" or skill_text != "" else VERTICAL_ALIGNMENT_TOP
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.text = str(info["desc"])  # 줄바꿈 폭이 정해진 뒤에 글자를 넣어야 라벨이 글자 폭만큼 늘어나지 않는다
	card.add_child(desc)
	if on_pick.is_valid():
		card.pressed.connect(on_pick)
	card.set_meta("frame_box", box)
	card.set_meta("display_group", info.get("display_group", &""))
	if not static_frame:
		card.mouse_entered.connect(func() -> void: _hover_augment_card(card, box, color, true, base_scale))
		card.mouse_exited.connect(func() -> void: _hover_augment_card(card, box, color, false, base_scale))
	return card


static func _hover_augment_card(card: Button, box: StyleBoxFlat, color: Color, entered: bool, base_scale: float = 1.0) -> void:
	var hover_color: Color = color.lightened(0.25) if AugmentDef.SUPPLY_GROUPS.has(StringName(str(card.get_meta("display_group", &"")))) else Color("ffe066")
	var tween: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * base_scale * (AUGMENT_HOVER_SCALE if entered else 1.0), 0.14)
	tween.tween_property(box, "shadow_size", 34 if entered else 8, 0.14)
	tween.tween_property(box, "shadow_color", Color(hover_color.r, hover_color.g, hover_color.b, 0.95) if entered else Color(color.r, color.g, color.b, 0.35), 0.14)
	tween.tween_property(box, "border_color", hover_color if entered else color, 0.14)
	card.z_index = 5 if entered else 0


func _build_draft_overlay(player_id: int, remaining: int) -> void:
	_close_draft_overlay()
	_draft_player = player_id
	_draft_signature_value = _draft_signature(player_id)
	_draft_locked = false
	Sfx.play(&"augment_show")
	_draft_overlay = _new_overlay(0.78)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var ready_label := _make_label("준비", 16, Color("adb5bd"))
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ready_label)
	var title := _make_label("증강 선택", 46, Color("ffe066"))
	_draft_title_label = title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("b8860b"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.8, 0.2, 0.55))
	title.add_theme_constant_override("shadow_outline_size", 14)
	box.add_child(title)
	var who := _make_label("라운드 %d - P%d 차례 (%d/%d)" % [state.round_number, player_id, _player_ids.size() - remaining + 1, _player_ids.size()], 15, PLAYER_COLORS[player_id])
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 30)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cards)
	_draft_cards.clear()
	_draft_reroll_buttons.clear()
	var offers: Array[StringName] = manager.draft_offers_for(player_id)
	for index: int in offers.size():
		var definition: AugmentDef = AugmentRegistry.get_def(offers[index])
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 10)
		cards.add_child(slot)
		var card: Button = _make_augment_card(_augment_card_info(definition, player_id), _on_augment_card_picked.bind(player_id, index, definition))
		slot.add_child(card)
		_draft_cards.append(card)
		var used: bool = manager.draft_reroll_used(player_id, index)
		# 알고리즘 밴은 증강 리롤을 막지 않는다 (밴: 카드·필살기·주사위 리롤만)
		var reroll: Button = _make_button("리롤 완료" if used else "[ 리롤 (1회) ]", _on_augment_reroll.bind(player_id, index), 15, Color("495a85"), 10)
		reroll.custom_minimum_size = Vector2(AUGMENT_CARD_SIZE.x, 40)
		reroll.disabled = used
		reroll.focus_mode = Control.FOCUS_NONE
		slot.add_child(reroll)
		_draft_reroll_buttons.append(reroll)
	# 공통 안내 바: 카드 본문에서 뺀 공통 규칙 문구를 이번 선택지에 해당하는 것만 한 줄로 작게
	var notes: PackedStringArray = []
	for offer: StringName in offers:
		var note: String = str(AugmentDef.NOTE_BAR.get(AugmentRegistry.get_def(offer).category, ""))
		if note != "" and not notes.has(note):
			notes.append(note)
	if not notes.is_empty():
		var note_bar: MarqueeLabel = MarqueeLabel.create("   ".join(notes), 14, Color("aab3bf"), Vector2(AUGMENT_CARD_SIZE.x * 3.0 + 60.0, 24), HORIZONTAL_ALIGNMENT_CENTER, "DraftNoteBar")
		note_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(note_bar)
	if net != null:
		# 온라인에서만 [무작위로 자동 선택]을 둔다 (혼자 하는 판은 군더더기라 뺐다).
		var footer := HBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(footer)
		footer.add_child(_make_button("무작위로 자동 선택", _on_draft_auto_pressed, 13))
	add_child(_draft_overlay)
	if MobileSupport.touch_mode():
		_fit_touch_draft.call_deferred(center, box)
	if _draft_entrance and _fx_on():
		_draft_entrance = false
		_draft_overlay.position = Vector2(0, 110)
		_draft_overlay.modulate.a = 0.0
		var rise: Tween = _draft_overlay.create_tween().set_parallel(true)
		rise.tween_property(_draft_overlay, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(_draft_overlay, "modulate:a", 1.0, 0.3)


## 터치 기기(폰 가로 화면은 기준 해상도의 약 0.5배로 보인다): 증강 선택 창(제목·카드 3장·리롤)을 화면에 들어가는 만큼 키운다 (최대 DRAFT_TOUCH_SCALE배).
const DRAFT_TOUCH_SCALE: float = 1.22


## 컨테이너는 자식의 scale을 되돌리므로, 창 전체를 가운데에 놓는 CenterContainer(컨테이너 밖)를 화면 가운데 기준으로 키운다.
func _fit_touch_draft(center: Control, box: Control) -> void:
	if not is_instance_valid(center) or not is_instance_valid(box) or box.size.y <= 0.0:
		return
	var view: Vector2 = get_viewport_rect().size
	var fit: float = minf(DRAFT_TOUCH_SCALE, minf(view.y * 0.97 / box.size.y, view.x * 0.96 / box.size.x))
	center.pivot_offset = center.size / 2.0
	center.scale = Vector2.ONE * maxf(fit, 1.0)


## 증강 카드를 눌렀을 때: 바로 적용하지 않고 [선택한 카드가 커지며 반짝 / 나머지는 어두워짐] 연출을 잠깐 보여 준 뒤 다음 단계(말 고르기 또는 적용)로 넘어간다.
func _on_augment_card_picked(player_id: int, index: int, definition: AugmentDef) -> void:
	if _draft_locked:
		return
	_draft_locked = true
	Sfx.play(&"augment_pick")
	for button: Button in _draft_reroll_buttons:
		button.disabled = true
	if instant_roll_for_test:
		_draft_locked = false
		_on_augment_chosen(player_id, index, definition)
		return
	_play_pick_animation(_draft_cards, index)
	if _draft_title_label != null:
		_draft_title_label.text = "선택 완료!"
	get_tree().create_timer(AUGMENT_PICK_SECONDS * _pace()).timeout.connect(func() -> void:
		_draft_locked = false
		if _draft_overlay != null and _draft_player == player_id:
			_on_augment_chosen(player_id, index, definition))


## 고른 카드를 키우고 빛내며 나머지는 어둡게 가라앉힌다.
func _play_pick_animation(cards: Array, chosen: int) -> void:
	for index: int in cards.size():
		var card: Button = cards[index]
		card.disabled = true
		card.pivot_offset = card.size / 2.0
		var tween: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if index == chosen:
			card.z_index = 10
			tween.tween_property(card, "scale", Vector2.ONE * 1.18, 0.3)
			tween.tween_property(card, "modulate", Color(1.35, 1.25, 0.9), 0.15)
			tween.chain().tween_property(card, "modulate", Color.WHITE, 0.3)
		else:
			tween.tween_property(card, "scale", Vector2.ONE * 0.9, 0.3)
			tween.tween_property(card, "modulate", Color(1, 1, 1, 0.22), 0.3)


func _on_augment_reroll(player_id: int, index: int) -> void:
	_last_reroll_index = index
	_last_reroll_player = player_id
	_act(&"reroll_augment", {"player_id": player_id, "index": index})


func _close_draft_overlay() -> void:
	if _draft_overlay != null:
		_draft_overlay.queue_free()
		_draft_overlay = null
	_draft_player = -1


func _on_auto_draft_toggled(enabled: bool) -> void:
	_auto_draft_enabled = enabled
	_close_draft_overlay()
	_refresh_draft_overlay()


func _on_draft_auto_pressed() -> void:
	for player_id: int in manager.draft_pending_players():
		if net == null or player_id == local_player_id:
			manager.auto_pick_draft(player_id)
	_refresh_all()


func _on_augment_chosen(player_id: int, index: int, definition: AugmentDef) -> void:
	if definition.needs_pawn_choice(state, player_id):
		_show_pawn_choice(player_id, definition, _pick_augment_with_pawn.bind(player_id, index))
		return
	_act(&"pick_augment", {"player_id": player_id, "index": index})


## 기물 증강을 받을 말을 아이콘 카드로 고른다. 이미 진화한 말은 어둡게 잠긴다.
func _show_pawn_choice(player_id: int, definition: AugmentDef, on_pick: Callable) -> void:
	_close_choice()
	# 증강 카드 화면("선택 완료!" 연출)이 뒤에 비쳐 겹쳐 보이지 않도록 말 고르기 동안은 숨긴다 (취소하면 다시 만든다).
	if _draft_overlay != null:
		_draft_overlay.visible = false
	_choice_overlay = _new_overlay(0.88)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var info: Dictionary = _augment_card_info(definition, player_id)
	var shield_pick: bool = definition.category == GameEnums.AugmentCategory.UTILITY
	var title := _make_label("어느 말에 보호막을 씌울까요?" if shield_pick else "어느 말을 [%s]로 진화시킬까요?" % str(info["title"]).split("] ")[-1], 24, Color("ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("5c4300"))
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var color: Color = PLAYER_COLORS[player_id]
	var evo_color: Color = info["color"]
	for slot: int in GameEnums.PAWNS_PER_PLAYER:
		var pawn: PlayerPawn = state.get_pawn(player_id * 10 + slot + 1)
		var can_pick: bool = definition.can_pick_pawn(state, player_id, pawn)
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 200)
		card.size = Vector2(150, 200)
		card.pivot_offset = Vector2(75, 100)
		card.focus_mode = Control.FOCUS_NONE
		card.disabled = not can_pick
		var base: Color = Color("1b2236") if can_pick else Color("101319")
		var hover_box: StyleBoxFlat = _style(base.lightened(0.12), Color("ffe066"), 4, 14, 20, 0)
		card.add_theme_stylebox_override("normal", _style(base, color.lightened(0.1), 3, 14, 6, 0))
		card.add_theme_stylebox_override("hover", hover_box)
		card.add_theme_stylebox_override("pressed", hover_box)
		card.add_theme_stylebox_override("disabled", _style(base, Color("495057"), 2, 14, 0, 0))
		card.modulate = Color.WHITE if can_pick else Color(1, 1, 1, 0.5)
		var badge := _make_label("%d번 말" % (slot + 1), 14, Color("0d1018"))
		badge.position = Vector2(46, 8)
		badge.size = Vector2(58, 22)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", _style(color.lightened(0.25) if can_pick else Color("6c757d"), Color.WHITE, 1, 9, 0, 1))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
		var token_host := Control.new()
		token_host.position = Vector2(30,42)
		token_host.size = Vector2(90,90)
		token_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(token_host)
		_token_in(token_host,pawn,color,Vector2(45,74),2.05)
		var place: String = "완주 완료" if pawn.is_finished else ("출발 대기" if not pawn.has_left_start else "출전 중 (%d번)" % pawn.current_tile_idx)
		var sub := _make_label(place, 13, Color("ced4da"))
		sub.position = Vector2(0, 140)
		sub.size = Vector2(150, 20)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(sub)
		if not can_pick:
			# 고를 수 있는 카드에는 [→ 차 진화!] 같은 문구를 붙이지 않는다 (제목이 이미 무엇으로 진화하는지 말해 준다)
			var action := _make_label("선택 불가" if shield_pick else "진화 불가", 15, Color("868e96"))
			action.position = Vector2(0, 166)
			action.size = Vector2(150, 24)
			action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			action.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(action)
		card.pressed.connect(_on_pawn_choice_picked.bind(pawn.entity_id, on_pick, slot))
		card.mouse_entered.connect(_hover_pawn_choice_card.bind(card, true))
		card.mouse_exited.connect(_hover_pawn_choice_card.bind(card, false))
		row.add_child(card)
	var cancel: Button = _make_button("취소", _cancel_pawn_choice, 15)
	cancel.custom_minimum_size = Vector2(0, 40)
	box.add_child(cancel)
	_pawn_choice_cards = row.get_children().filter(func(node: Node) -> bool: return node is Button)
	add_child(_choice_overlay)


## 말 고르기를 취소하면 증강 카드 3장 화면으로 돌아간다.
func _cancel_pawn_choice() -> void:
	_close_choice()
	_close_draft_overlay()
	_refresh_draft_overlay()


func _hover_pawn_choice_card(card: Button, entered: bool) -> void:
	if card.disabled:
		return
	var tween: Tween = card.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * (1.07 if entered else 1.0), 0.12)


func _on_pawn_choice_picked(pawn_id: int, on_pick: Callable, slot: int) -> void:
	if instant_roll_for_test or _pawn_choice_cards.is_empty():
		_close_choice()
		on_pick.call(pawn_id)
		return
	var overlay: Control = _choice_overlay
	_play_pick_animation(_pawn_choice_cards, slot)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _choice_overlay == overlay and overlay != null:
			_close_choice()
			on_pick.call(pawn_id))


func _pick_augment_with_pawn(pawn_id: int, player_id: int, index: int) -> void:
	_act(&"pick_augment", {"player_id": player_id, "index": index, "pawn_id": pawn_id})


func _show_result_overlay() -> void:
	_result_hold = false
	_report_match_once()
	_close_result_overlay()
	_result_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	UiSkin.bind_light_text(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(1000, 0)
	panel.add_child(box)
	var winner_id: int = state.winner
	var title: Label = _make_label("게임 종료!", 34, Color("ffd43b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	Sfx.play_stinger(&"podium")
	var announcer: Label = _make_label("최종 순위를 발표합니다!", 20, Color("f1f3f5"))
	announcer.name = "RankingAnnouncer"
	announcer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(announcer)
	# 왜 끝났는지: 시상대 위에 결정적 종료 사유 한 줄
	var reason_bar := PanelContainer.new()
	reason_bar.name = "MatchEndReason"
	reason_bar.add_theme_stylebox_override("panel", _style(Color(1.0, 0.85, 0.24, 0.14), Color("ffd43b"), 2, 12, 12, 0))
	var reason_row := HBoxContainer.new()
	reason_row.add_theme_constant_override("separation", 10)
	reason_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reason_bar.add_child(reason_row)
	reason_row.add_child(MetaIcon.create(&"trophy", Vector2(26, 26)))
	var reason_label: Label = _make_label("매치 종료 사유: %s" % match_end_reason(), 18, Color("ffe066"))
	reason_label.name = "MatchEndReasonText"
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.custom_minimum_size = Vector2(880, 0)
	reason_row.add_child(reason_label)
	box.add_child(reason_bar)
	# 왼쪽: 1~4위를 한눈에 보는 시상대 / 오른쪽: 순위 근거·진행도가 적힌 순위표
	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 20)
	box.add_child(stage_row)
	var podium := HBoxContainer.new()
	podium.name = "Podium"
	podium.add_theme_constant_override("separation", 8)
	podium.alignment = BoxContainer.ALIGNMENT_CENTER
	podium.custom_minimum_size = Vector2(420, 0)
	stage_row.add_child(podium)
	var ranking := VBoxContainer.new()
	ranking.name = "RankingList"
	ranking.add_theme_constant_override("separation", 8)
	ranking.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ranking.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_row.add_child(ranking)
	var standings: Array[Dictionary] = VictoryChecker.standings(state, manager.player_order, winner_id)
	var rows: Array[Control] = []
	var columns: Dictionary = {}
	for entry: Dictionary in standings:
		var row: Control = _make_rank_row(entry)
		ranking.add_child(row)
		rows.append(row)
		columns[int(entry["rank"])] = _make_podium_column(entry)
	for rank_no: int in PODIUM_ORDER:  # 2위 · 1위 · 3위 · 4위 순으로 세워 1위 단상이 가운데에 가장 높다
		if columns.has(rank_no):
			podium.add_child(columns[rank_no])
	for row: Control in rows:
		row.set_meta("podium", columns.get(int(row.get_meta("rank"))))
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 4)
	box.add_child(facts)
	var rounds: Label = _make_label("플레이한 라운드: %d라운드" % state.round_number, 17, Color("f1f3f5"))
	rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	facts.add_child(rounds)
	var reason: Label = _make_label("승리 요인: %s" % VictoryChecker.short_reason(state.rank_reasons.get(winner_id, _last_reason)), 17, Color("f1f3f5"))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_child(reason)
	box.add_child(_build_vote_bar())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	if net == null:
		var again: Button = _make_button("같은 설정으로 바로 재시작", _new_game, 19, Color("2b8a3e"))
		again.name = "RestartButton"
		again.custom_minimum_size = Vector2(0, 52)
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(again)
	var lobby: Button = _make_button("로비로 나가기", _on_menu_pressed, 19, Color("3b4766"))
	lobby.name = "LobbyButton"
	lobby.custom_minimum_size = Vector2(0, 52)
	lobby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(lobby)
	# [내 우승 기록 복사하기]: 커뮤니티·디스코드에 바로 붙여 넣는 두 줄 요약 (내 자리가 있는 판만)
	var seat: int = _telemetry_seat()
	if seat != -1 and state.rankings.has(seat):
		var won: bool = int(state.rankings[0]) == seat
		var brag: Button = _make_button("내 우승 기록 복사하기" if won else "내 기록 복사하기", Callable(), 19, Color("e8590c"))
		brag.name = "CopyRecordButton"
		brag.custom_minimum_size = Vector2(0, 52)
		brag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brag.pressed.connect(func() -> void:
			MetaIcon.copy_to_clipboard(brag_text(seat))
			brag.text = "복사했어요! 붙여 넣어 자랑하세요")
		buttons.add_child(brag)
	# 한 판이 끝난 순간이 가장 할 말이 많을 때다: 결과 창 아래에 후기·밸런스 피드백 버튼을 크게 둔다.
	var review: Button = _make_button(tr_ui("result.feedback"), _open_feedback.bind("결과 화면", FeedbackModal.Kind.BALANCE), 18, Color("c2255c"))
	review.name = "ReviewFeedbackButton"
	review.custom_minimum_size = Vector2(0, 50)
	box.add_child(review)
	add_child(_result_overlay)
	_reveal_ranking(rows, announcer)


## 결과 화면 [내 기록 복사하기]의 글 (지금 언어): 1줄 게임·난이도·순위·라운드·졸업 방식, 2줄 판정 도구·기물 4개.
func brag_text(player_id: int) -> String:
	var rank: int = state.rankings.find(player_id) + 1
	var reason: StringName = StringName(str(state.rank_reasons.get(player_id, VictoryChecker.ALL_HOME)))
	var mode: String = BotTemper.label(_bot.difficulty if _bot != null else GameSession.bot_difficulty()) if (net == null and ai_mode) else L10n.t("온라인 대전" if net != null else "친선 대결")
	var head: String = "%s [%s] %s %s! (%s / %s)" % [String.chr(0x1F3C6), L10n.t("초증강 엘리아스 마블"), mode, L10n.t("%d위 졸업" % rank),
		L10n.t("%d라운드 만에" % int(state.round_number)), L10n.t(VictoryChecker.short_reason(reason))]
	var tool: BaseJudgmentTool = state.tools.get(player_id)
	var pawns: PackedStringArray = []
	var counts: Dictionary = {}
	for pawn: PlayerPawn in state.pawns_of(player_id):
		var pawn_name: String = L10n.t(PawnCatalog.full_name(pawn.kind, pawn.unit_no)).trim_prefix("[").trim_suffix("]")
		if not counts.has(pawn_name):
			pawns.append(pawn_name)
		counts[pawn_name] = int(counts.get(pawn_name, 0)) + 1
	for index: int in pawns.size():
		if int(counts[pawns[index]]) > 1:
			pawns[index] = "%s ×%d" % [pawns[index], int(counts[pawns[index]])]  # 같은 기물은 묶는다
	var gear: String = "%s %s: %s | %s %s: %s" % [String.chr(0x1F3B2), L10n.t("판정 도구"), L10n.t(tool.display_name) if tool != null else "-",
		String.chr(0x265F), L10n.t("기물"), ", ".join(pawns)]
	return head + "\n" + gear


## 결과 화면의 원클릭 소감 투표 바: 질문 한 줄 + 버튼 4개. 누르면 바로 개발자 웹후크로 가고, 감사 문구로 바뀌어 다시 누를 수 없다.
## [딱 재밌어요!]가 아닌 버튼은 이어서 피드백/버그 제보 창을 띄워, 더 하고 싶은 말이 있으면 바로 적게 한다.
func _build_vote_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "VoteBar"
	bar.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.06), Color("ffd43b"), 1, 12, 10, 8))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	bar.add_child(column)
	var question: Label = _make_label("이번 판 난이도와 템포는 어떠셨나요? (클릭 시 개발자에게 바로 전달됩니다!)", 16, COLOR_GOLD)
	question.name = "VoteQuestion"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(question)
	var row := HBoxContainer.new()
	row.name = "VoteButtons"
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var tints: Array[Color] = [Color("e8590c"), Color("c2255c"), Color("5f3dc4"), Color("2b8a3e")]
	var choices: Array = MatchTelemetry.vote_choices()
	for index: int in choices.size():
		var choice: Array = choices[index]
		var button: Button = _make_button(str(choice[2]), Callable(), 15, tints[index % tints.size()])
		button.name = "Vote_%s" % choice[0]
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_vote_pressed.bind(bar, str(choice[1]), index != 0))
		row.add_child(button)
	return bar


func _on_vote_pressed(bar: Control, choice: String, ask_more: bool) -> void:
	if not is_instance_valid(bar) or bool(bar.get_meta("voted", false)):
		return
	bar.set_meta("voted", true)
	var seat: int = _telemetry_seat()
	var my_rank: int = state.rankings.find(seat) + 1 if seat != -1 and state != null else 0
	MatchTelemetry.report_vote(self, choice, "", my_rank, state.round_number if state != null else 0, _telemetry_mode())
	if ask_more:
		_open_feedback("결과 화면 투표: %s" % choice, FeedbackModal.Kind.BALANCE)
	for child: Node in bar.get_children():
		child.queue_free()
	var thanks: Label = _make_label("소중한 의견 감사합니다!", 18, Color("69db7c"))
	thanks.name = "VoteThanks"
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(thanks)
	Sfx.play(&"card_get", -6.0)


const RANK_MEDALS: Array[String] = ["1", "2", "3", "4"]
## 시상대 왼쪽부터 세우는 순위와 순위별 단상 높이(px).
const PODIUM_ORDER: Array[int] = [2, 1, 3, 4]
const PODIUM_HEIGHTS: Array[float] = [150.0, 110.0, 80.0, 50.0]
const RANK_COLORS: Array[Color] = [Color("ffd43b"), Color("ced4da"), Color("e8a364"), Color("868e96")]


## 시상대 한 칸: 아바타 · 이름 · 순위 숫자가 적힌 단상 (1위가 가장 높다).
func _make_podium_column(entry: Dictionary) -> Control:
	var rank: int = int(entry["rank"])
	var player_id: int = int(entry["player"])
	var color: Color = RANK_COLORS[mini(rank, 4) - 1]
	var column := VBoxContainer.new()
	column.name = "Podium%d" % rank
	column.set_meta("rank", rank)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size = Vector2(96, 0)
	column.size_flags_vertical = Control.SIZE_FILL
	var avatar := AvatarSlot.new()
	avatar.icon_border = false
	avatar.static_only = true
	var face: float = 84.0 if rank == 1 else 68.0
	avatar.setup(player_id, PLAYER_COLORS.get(player_id, Color.WHITE), Vector2(face, face))
	avatar.set_character(_avatar_for(player_id))
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(avatar)
	var name_label: Label = _make_label(_player_name(player_id), 16 if rank == 1 else 14, PLAYER_COLORS.get(player_id, Color.WHITE).lightened(0.3))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(96, 0)
	column.add_child(name_label)
	var block := PanelContainer.new()
	block.name = "Block"
	block.custom_minimum_size = Vector2(96, PODIUM_HEIGHTS[mini(rank, 4) - 1])
	block.add_theme_stylebox_override("panel", _style(color, color.darkened(0.35), 3, 8, 8, 4))
	column.add_child(block)
	var number: Label = _make_label(str(rank), 44 if rank == 1 else 34, Color.WHITE)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_outline_color", color.darkened(0.55))
	number.add_theme_constant_override("outline_size", 6)
	block.add_child(number)
	return column


## 순위표 한 줄: [순위] [아바타] 이름 / 순위 근거(특수 승리 교칙·완주) · 완주 n/4 · 진행도 막대.
func _make_rank_row(entry: Dictionary) -> Control:
	var rank: int = int(entry["rank"])
	var player_id: int = int(entry["player"])
	var row := PanelContainer.new()
	row.name = "Rank%d" % rank
	row.set_meta("rank", rank)
	row.set_meta("player", player_id)
	row.add_theme_stylebox_override("panel", _style(Color("fff3bf") if rank == 1 else Color("ffffff"), RANK_COLORS[mini(rank, 4) - 1].darkened(0.1), 3 if rank == 1 else 2, 12, 12, 8))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	var medal: Label = _make_label(RANK_MEDALS[mini(rank, 4) - 1], 30 if rank <= 3 else 20, RANK_COLORS[mini(rank, 4) - 1])
	medal.custom_minimum_size = Vector2(54, 0)
	medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(medal)
	var avatar := AvatarSlot.new()
	avatar.icon_border = false
	avatar.static_only = true
	avatar.setup(player_id, PLAYER_COLORS.get(player_id, Color.WHITE), Vector2(56, 56))
	avatar.set_character(_avatar_for(player_id))
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(avatar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	line.add_child(info)
	var name_label: Label = _make_label("%d등  %s" % [rank, _player_name(player_id)], 20 if rank == 1 else 18, PLAYER_COLORS.get(player_id, Color.WHITE).lightened(0.3))
	info.add_child(name_label)
	# 순위의 근거를 먼저 보여 준다 (특수 승리면 교칙 이름). 완주·진행도는 졸업한 순간의 기록이다.
	var reason: StringName = entry.get("reason", &"")
	var progress_text: String = "완주 %d/%d · 진행도 %d%%" % [int(entry["finished"]), GameEnums.PAWNS_PER_PLAYER, int(entry["progress"])]
	var detail: Label = _make_label(progress_text if reason == &"" else "%s · %s" % [VictoryChecker.short_reason(reason), progress_text], 14, Color("ced4da"))
	detail.name = "Detail"
	info.add_child(detail)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 100
	bar.value = int(entry["progress"])
	bar.add_theme_stylebox_override("fill", _style(PLAYER_COLORS.get(player_id, Color.WHITE), Color(0, 0, 0, 0), 0, 4, 0, 0))
	bar.add_theme_stylebox_override("background", _style(Color("e9ecef"), Color(0, 0, 0, 0), 0, 4, 0, 0))
	info.add_child(bar)
	return row


## 순위 발표: 꼴찌부터 한 줄씩 쾅 하고 나타나고, 1등은 잠깐 뜸을 들인 뒤 팡파르와 함께 공개한다 (연출을 끈 테스트에서는 바로 다 보인다).
func _reveal_ranking(rows: Array[Control], announcer: Label) -> void:
	if not _fx_on():
		announcer.text = "★ 최종 순위 ★"
		return
	for row: Control in rows:
		row.modulate.a = 0.0
		var hidden_column: Control = row.get_meta("podium", null)
		if hidden_column != null:
			hidden_column.modulate.a = 0.0
	var overlay: Control = _result_overlay
	var frames: int = 0
	while _presentation_active() and frames < 600:  # 마지막 이동·처치 연출이 끝난 뒤에 발표한다
		frames += 1
		await get_tree().process_frame
	await get_tree().create_timer(PODIUM_INTRO_SECONDS).timeout  # 시상대 팡파르의 머리를 들려준 뒤 발표를 시작한다
	if overlay != _result_overlay:
		return
	for index: int in range(rows.size() - 1, -1, -1):
		if overlay != _result_overlay or not is_instance_valid(rows[index]):
			return
		var row: Control = rows[index]
		var first: bool = int(row.get_meta("rank")) == 1
		if first:
			announcer.text = "그리고 대망의 1등은...!"
			await get_tree().create_timer(FIRST_PLACE_DRUMROLL_SECONDS).timeout
			if overlay != _result_overlay or not is_instance_valid(row):
				return
		else:
			await get_tree().create_timer(RANK_ROW_SECONDS).timeout
			if overlay != _result_overlay or not is_instance_valid(row):
				return
		row.pivot_offset = row.size / 2.0
		row.scale = Vector2(1.25, 1.25) if first else Vector2(1.1, 1.1)
		var tween: Tween = row.create_tween().set_parallel(true)
		tween.tween_property(row, "modulate:a", 1.0, 0.18)
		tween.tween_property(row, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var column: Control = row.get_meta("podium", null)
		if column != null and is_instance_valid(column):
			# 단상이 아래에서 솟아오르며 그 자리의 주인이 나타난다
			column.pivot_offset = Vector2(column.size.x / 2.0, column.size.y)
			column.scale = Vector2(1.0, 0.2)
			tween.tween_property(column, "modulate:a", 1.0, 0.18)
			tween.tween_property(column, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if first:
			Sfx.play_stinger(&"win")  # 시상대 팡파르를 부드럽게 끊고 우승 팡파르
			announcer.text = "★ %s 우승! ★" % _player_name(int(row.get_meta("player")))
			screen_shake(6.0, 0.25)
		else:
			Sfx.play(&"card_impact")


var _last_reason: StringName = &""
## 판을 끝낸 결정적 순위 확정 (마지막 자동 순위·남은 컴퓨터 레이스 순위가 아닌 것): {player, rank, reason}.
var _decisive_rank: Dictionary = {}
## 결과 화면을 띄우기 전 [매치 종료] 브리핑 시간(초).
const END_BRIEF_SECONDS: float = 2.0


func _winner_reason_text() -> String:
	return VictoryChecker.reason_text(_last_reason)


func _close_result_overlay() -> void:
	if _result_overlay != null:
		_result_overlay.queue_free()
		_result_overlay = null


func _preview_pawn(pawn_id: int) -> void:
	_clear_highlight()
	if manager.current_state != TurnManager.State.PHASE_SELECT_PAWN or manager.move_queue.is_empty():
		return
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn == null or not _can_pick_now(pawn):
		return
	var path: Array[int] = _pawn_move_path(pawn)
	for index: int in path.size():
		var highlight: BoardSkin.Ring = _highlights[path[index]]
		highlight.visible = true
		highlight.border_width = 8.0 if index == path.size() - 1 else 5.0
	_hover_danger_tile = path.back() if not path.is_empty() else -1
	_refresh_danger_label()


func _clear_highlight() -> void:
	for highlight: BoardSkin.Ring in _highlights.values():
		highlight.visible = false
		highlight.border_width = 3.0
	_board_hover_pawn = -1
	if _hover_danger_tile != -1:
		_hover_danger_tile = -1
		_refresh_danger_label()


# ---------------------------------------------------------------------------
# 엔진 이벤트 -> 화면/로그
# ---------------------------------------------------------------------------

func _on_phase_changed(new_state: TurnManager.State, _player_id: int, _limit: float) -> void:
	if new_state == TurnManager.State.PHASE_TURN_BEGIN or new_state == TurnManager.State.PHASE_ROUND_START:
		_spotlight_turn = false  # 주목 구간은 한 턴 동안만
		sweep_oneshot_fx()  # 턴·라운드 경계: 수명이 지났는데 남은 일회성 연출 노드를 치운다
	if new_state != TurnManager.State.PHASE_ROUND_START:
		_close_augment_review()
		_draft_open = false
		_flush_draft_summary()
		_release_draft_deferred()
	_refresh_all()


## 연출을 증강 공개 뒤로 미뤄야 하는 때: 연출을 켠 판에서 드래프트 창이 열린 뒤(augment_offers를 받은 뒤)부터 드래프트가 끝날 때까지.
## 라운드 시작 상태(PHASE_ROUND_START)만 보면, 라운드 마지막 턴의 처치·NPC 페이즈처럼 드래프트 전에 일어난 일의 연출까지
## 드래프트 공개 뒤로 밀려 [증강 선택 -> 처치 -> 다음 라운드] 순서로 보였다.
func _draft_in_progress() -> bool:
	return _draft_open and _fx_on() and manager != null and manager.current_state == TurnManager.State.PHASE_ROUND_START and not manager.is_game_over


## 드래프트가 끝났다: 미뤄 둔 효과 연출을 [선택한 증강] 공개 카드 뒤에 차례로 세운다.
func _release_draft_deferred() -> void:
	if _draft_deferred.is_empty():
		return
	var batch: Array[Dictionary] = _draft_deferred.duplicate()
	_draft_deferred.clear()
	_enqueue_batch(batch)


## 드래프트 중 엔진이 낸 변화를 모아 둔다 (방금 고른 증강이 초증강이면 그 연출이 무엇을 보여 줄지 정한다).
func _note_super(change: Dictionary) -> void:
	if _draft_in_progress():
		_super_changes.append(change)


## 초증강을 골랐다: 그 선택이 만든 연출 단계들 바로 앞에 전용 보드 연출을 끼운다 (모두 [선택한 증강] 공개 뒤에 재생된다).
## 그 연출이 처치 장면을 직접 보여 주는 초증강은 늦게 붙는 처치 단계를 미리 빼낸다 (같은 장면이 두 번 나오지 않게).
func _on_super_picked(player_id: int, augment_id: StringName) -> void:
	var definition: AugmentDef = AugmentRegistry.get_def(augment_id)
	if definition == null or definition.category != GameEnums.AugmentCategory.SUPER_GAMBLE or _super_fx == null or not _draft_in_progress():
		return
	var effect: StringName = definition.payload
	if not SuperFX.handles(effect):
		return
	var changes: Array[Dictionary] = []
	for change: Dictionary in _super_changes:
		changes.append(change.duplicate(true))
	if effect==SuperAugments.RAID:
		# Synchronize the real reserved deliveries with each successful snatch.
		# Returned cards (full recipient hand) are restorations, not new rewards.
		var rewards: Array[Dictionary] = []
		var retained: Array[Dictionary] = []
		for entry: Dictionary in _draft_deferred:
			if int(entry.get("pick",-1))!=_pick_serial or not entry.has("draw_job"):
				retained.append(entry)
				continue
			var job: Dictionary = entry.draw_job
			if int(job.player)==player_id:
				rewards.append(job.duplicate(true))
			elif int(job.source)==int(job.player):
				if bool(job.local) and _draw_fx!=null:
					_draw_fx.release(int(job.player))
			else:
				retained.append(entry)
		_draft_deferred = retained
		changes.append({"kind":"raid_rewards","jobs":rewards})
	if effect==SuperAugments.BAKERY:
		var tile := BoardSpec.bakery_tiles[0] if not BoardSpec.bakery_tiles.is_empty() else -1
		var jumper := -1
		for change: Dictionary in changes:
			if change.get("kind")=="teleport" and int(change.get("tile",-1))==tile:
				var pawn: PlayerPawn = state.get_pawn(int(change.pawn))
				if pawn!=null and pawn.owner_id==player_id:
					jumper = pawn.entity_id
		var rewards: Array[Dictionary] = []
		var retained: Array[Dictionary] = []
		for entry: Dictionary in _draft_deferred:
			if int(entry.get("pick",-1))==_pick_serial:
				if entry.has("draw_job") and int(entry.draw_job.player)==player_id:
					rewards.append(entry.draw_job.duplicate(true))
					continue
				if jumper!=-1 and int(entry.get("pawn",-1))==jumper and (entry.step as Callable).get_method() in [&"_play_warp_glide",&"_stage_warp"]:
					continue  # The bakery stage owns this exact launch, once.
			retained.append(entry)
		_draft_deferred = retained
		var position := _pawn_position_at(state.get_pawn(jumper),tile) if jumper!=-1 else _tile_center(tile) if tile>=0 else Vector2.ZERO
		changes.append({"kind":"bakery_scene","tile":tile,"pawn":jumper,"position":position,"jobs":rewards})
	if effect==SuperAugments.MINEFIELD:
		# This stage owns the same pick's mine reveals; don't replay generic trap FX.
		var mine_tiles: Array[int] = []
		for change: Dictionary in changes:
			if change.get("kind")=="place" and change.get("id")=="TRP_03":
				mine_tiles.append(int(change.tile))
		_draft_deferred = _draft_deferred.filter(func(entry: Dictionary) -> bool:
			return not (int(entry.get("pick",-1))==_pick_serial and mine_tiles.has(int(entry.get("trap_tile",-1)))))
	if effect==SuperAugments.CASTLING:
		# Preserve this pick's permutation if another drafted augment changes it later.
		var poses: Array[Dictionary] = []
		for pawn: PlayerPawn in SuperAugments.board_leaders(state):
			poses.append({"pawn":pawn.entity_id,"tile":pawn.current_tile_idx,"position":_pawn_position(pawn)})
		changes.append({"kind":"castling_pose","pawns":poses})
	if effect==SuperAugments.REDISTRIBUTE:
		# Capture this pick's targets now, before another selected augment changes them.
		var poses: Array[Dictionary] = []
		for pawn: PlayerPawn in state.pawns:
			if pawn.owner_id in state.active_players(state.player_ids):
				poses.append({"pawn":pawn.entity_id,"tile":pawn.current_tile_idx,"position":_pawn_position(pawn),"visible":pawn.has_left_start and not pawn.is_finished and pawn.carrier==null})
		changes.append({"kind":"redistribution_pose","pawns":poses})
	if effect in [SuperAugments.FLIP, SuperAugments.SNIPER, SuperAugments.DEVIL]:
		var sniper_target := -1
		for change: Dictionary in changes:
			if change["kind"] == "start":
				if effect==SuperAugments.SNIPER:
					if sniper_target!=-1:
						continue  # Other real ejections retain their own queued visuals.
					sniper_target = int(change.pawn)
					var target_view: Node2D = _pawn_views.get(sniper_target)
					change["position"] = target_view.position if target_view!=null else Vector2.ZERO
				_take_late_steps_for(int(change["pawn"]))
				if effect==SuperAugments.DEVIL:
					var offering: PlayerPawn = state.get_pawn(int(change.pawn))
					change["rest_position"] = _pawn_position(offering)
					change["rest_visible"] = offering.has_left_start and not offering.is_finished and offering.carrier==null
	var hidden_key: String = "%d:%s" % [player_id, effect]
	_super_hidden[hidden_key] = true  # 지속 표시(불꽃 테두리·발밑 고리)는 연출이 나올 때 켠다
	var serial: int = _pick_serial
	var step: Callable = func() -> void:
		var generation: int = _fx_generation
		# The contract pays out only after its offering reaches the player's profile.
		if effect not in [SuperAugments.DEVIL,SuperAugments.GAMBLER]:
			_super_hidden.erase(hidden_key)
		await _super_fx.play(effect, player_id, changes)
		if effect in [SuperAugments.DEVIL,SuperAugments.GAMBLER]:
			if generation!=_fx_generation:
				return
			_super_hidden.erase(hidden_key)
		_refresh_super_marks()
	var at: int = _draft_deferred.size()
	for index: int in _draft_deferred.size():
		if int(_draft_deferred[index].get("pick", -1)) == serial:
			at = index
			break
	_draft_deferred.insert(at, {"step": step, "pawn": -1, "pick": serial})


## 초증강 연출이 아직 나오지 않아 지속 표시를 숨겨 둔 것 ("플레이어:초증강").
var _super_hidden: Dictionary = {}


## 지속 표시: 악마의 계약(보라/붉은 불꽃 테두리, 게임 끝까지)·도박사의 영혼(황금 불꽃, 그 라운드)·강제 연대책임(묶인 두 말 발밑 붉은 고리).
func _refresh_super_marks() -> void:
	if state == null:
		return
	for player_id: int in _player_ids:
		if not _profiles.has(player_id):
			continue
		SuperFX.set_flame(_profiles[player_id]["panel"], "SuperFlame", _flame_colors(player_id),true)
	var shown: int = int(_tool_board_key.get_slice(":", 0)) if _tool_board_key != "" else -1
	SuperFX.set_flame(_tool_board, "SuperFlame", _flame_colors(shown) if shown != -1 else [] as Array[Color])
	for pawn: PlayerPawn in state.pawns:
		var view: Node2D = _pawn_views.get(pawn.entity_id)
		if view != null:
			var bonded: bool = _fx_on() and state.bonds.has(pawn.entity_id) and not _super_hidden.has("%d:%s" % [pawn.owner_id, SuperAugments.GUARANTEE])
			SuperFX.set_bond_ring(view, bonded)


## 이 플레이어를 감쌀 불꽃 색 (없으면 빈 배열).
func _flame_colors(player_id: int) -> Array[Color]:
	var colors: Array[Color] = []
	if not _fx_on() or state == null or player_id == -1:
		return colors
	if int(state.permanent_roll_bonus.get(player_id, 0)) > 0 and not _super_hidden.has("%d:%s" % [player_id, SuperAugments.DEVIL]):
		colors.append_array([Color("9c36b5"), Color("e03131")])
	if int(state.gambler_round.get(player_id, -1)) == state.round_number and not _super_hidden.has("%d:%s" % [player_id, SuperAugments.GAMBLER]):
		colors.append_array([Color("ffd43b"), Color("ff922b")])
	return colors


## 도박사의 영혼이 이번 굴림을 바꿨다: 주사위 위에 x배수! 또는 그을린 과열 연기.
func _gambler_result_busy() -> bool:
	var result_fx: Node2D = get_node_or_null("GamblerResult")
	return result_fx!=null and not result_fx._complete and result_fx.generation==_fx_generation

func _show_gambler_flash(player_id: int, tool_id: StringName = &"") -> void:
	if not _gambler_flash.has(player_id):
		return
	var raw: Variant = _gambler_flash[player_id]
	var details: Dictionary = raw if raw is Dictionary else {"multiplier":int(raw)}
	var multiplier: int = int(details.multiplier)
	_gambler_flash.erase(player_id)
	if not _fx_on() or _super_fx == null:
		return
	var target: Control = _presenter if _presenter.visible else _stage_for(tool_id)
	if target!=null and not target.is_visible_in_tree():
		target = null
	var at: Vector2 = target.get_global_rect().get_center() if target!=null else get_global_transform()*_board_center()
	if target==_presenter and _presenter.tossing and is_instance_valid(_presenter._toss_view):
		at = _presenter._toss_view.get_global_rect().get_center()
	var caption := "%d칸" % int(details.get("to",0)) if multiplier>0 and details.has("to") else ("×%d" % multiplier if multiplier>0 else "과열! 0칸")
	if target==_presenter:
		_presenter.hold_augmented_result(SuperFX.GAMBLER_STAGE.RESULT_TIME*_motion_pace(),caption)
	if multiplier > 0:
		_super_fx.gambler_boost(at,multiplier,details,target)
	else:
		_profile_react(player_id,false)
		_super_fx.gambler_overheat(at,target,details)


## 이번 라운드에 모두가 고른 증강을 선택 카드 그림 그대로 한 줄에 나란히 공개한다.
func _flush_draft_summary() -> void:
	if _draft_summary.is_empty():
		return
	var row: HBoxContainer = _take_draft_summary_row()
	_announce(tr_ui("draft.reveal_tag"), tr_ui("draft.reveal"), "", Color("ffa94d"), row, 1.8)


## 모아 둔 증강 선택을 기록에 남기고, 고른 증강 카드를 한 줄로 늘어놓은 줄을 만든다 (모은 목록은 비운다).
func _take_draft_summary_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_scale: float = 0.6 if _draft_summary.size() > 2 else 0.8
	for entry: Dictionary in _draft_summary:
		var picked_id: StringName = entry["augment"]
		var picked_def: AugmentDef = AugmentRegistry.get_def(picked_id)
		var line: String = "%s 선택!" % _bq(picked_def.display_name)  # 초증강 이름에는 이미 [초증강]이 붙어 있다
		# 범용 보급·카드 패키지는 무엇이 무엇으로 바뀌었는지, 어떤 카드를 받았는지까지 남긴다
		if picked_def.category == GameEnums.AugmentCategory.UTILITY or picked_def.category == GameEnums.AugmentCategory.CARD_PACKAGE:
			line += " " + str(entry.get("text", ""))
		_record(int(entry["player"]), line, "증강", false, true)  # 고른 증강이 화면(확인 창·공개 카드)에 나오는 바로 그 순간에 적는다
	for entry: Dictionary in _draft_summary:
		var player_id: int = int(entry["player"])
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var who: Label = _make_label("P%d  %s" % [player_id, _player_name(player_id)], 18, PLAYER_COLORS[player_id].lightened(0.35))
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.add_theme_constant_override("outline_size", 4)
		who.add_theme_color_override("font_outline_color", Color("0d1018"))
		column.add_child(who)
		var holder := Control.new()
		holder.custom_minimum_size = AUGMENT_CARD_SIZE * card_scale
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card: Button = _make_augment_card(_augment_card_info(AugmentRegistry.get_def(entry["augment"]), player_id), Callable())
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pivot_offset = Vector2.ZERO
		card.scale = Vector2.ONE * card_scale
		holder.add_child(card)
		column.add_child(holder)
		row.add_child(column)
	_draft_summary.clear()
	return row


## 증강 확인 단계: [선택한 증강]을 모두에게 보여 주고, 다들 [확인]을 누르면(봇은 바로, 시간이 다 되면 자동) 라운드를 시작한다.
var _review_overlay: Control = null
var _review_chips: Dictionary = {}
var _review_button: Button = null
var _review_bar: ColorRect = null


const TOUCH_REVIEW_SCALE: float = 1.4


func _show_augment_review(players: Array) -> void:
	_close_augment_review()
	if _draft_summary.is_empty():
		return
	Sfx.play(&"review_open")
	_review_overlay = _new_overlay(0.55)
	_review_overlay.name = "AugmentReview"
	_review_overlay.z_index = 45
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_review_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("101626"), Color("ffa94d"), 4, 18, 24, 18))
	center.add_child(panel)
	MobileSupport.fit_touch_scale(panel, TOUCH_REVIEW_SCALE)  # 폰: 증강 카드 글씨가 읽히게 화면 안에서 키운다
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title: Label = _make_label(tr_ui("draft.reveal"), 30, Color("ffd8a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color("3d1f00"))
	box.add_child(title)
	var row: HBoxContainer = _take_draft_summary_row()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	# 누가 확인했는지: 이름 칩이 확인하면 그 사람 색으로 켜진다
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	box.add_child(chips)
	_review_chips.clear()
	for player_id: int in players:
		var chip := PanelContainer.new()
		chip.name = "ReviewChip%d" % player_id
		chip.pivot_offset = Vector2(60, 16)
		var chip_label: Label = _make_label(_player_name(player_id), 16, Color("ced4da"))
		chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_label.custom_minimum_size = Vector2(110, 0)
		chip.add_child(chip_label)
		chips.add_child(chip)
		_review_chips[player_id] = chip
		_paint_review_chip(player_id, false)
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 5)
	_review_bar = ColorRect.new()
	_review_bar.color = Color("ffa94d")
	track.add_child(_review_bar)
	box.add_child(track)
	_review_button = _make_button("확인", _on_review_confirm, 22, Color("2b8a3e"))
	_review_button.name = "ReviewConfirm"
	_review_button.custom_minimum_size = Vector2(260, 54)
	_review_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_review_button)
	add_child(_review_overlay)
	_refresh_review_button()


func _paint_review_chip(player_id: int, done: bool) -> void:
	var chip: PanelContainer = _review_chips.get(player_id)
	if chip == null:
		return
	var color: Color = PLAYER_COLORS.get(player_id, Color.WHITE)
	chip.add_theme_stylebox_override("panel", _style(color.darkened(0.15) if done else Color("1b2030"), color.lightened(0.35) if done else Color("495057"), 2, 16, 6, 6))
	(chip.get_child(0) as Label).add_theme_color_override("font_color", Color.WHITE if done else Color("868e96"))
	if done and _fx_on():
		chip.scale = Vector2(1.25, 1.25)
		chip.create_tween().tween_property(chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 이 화면에서 대신 [확인]을 눌러 줄 사람들: 온라인·AI 대전은 나, 같은 화면 대전(핫시트)은 봇이 아닌 모두.
func _review_local_players() -> Array[int]:
	var result: Array[int] = []
	for player_id: int in manager.review_waiting_for():
		if net != null or ai_mode:
			if player_id == local_player_id:
				result.append(player_id)
		elif not _bot.is_bot(player_id):
			result.append(player_id)
	return result


func _on_review_confirm() -> void:
	Sfx.play(&"review_confirm")
	for player_id: int in _review_local_players():
		manager.act(&"review_done", {"player_id": player_id})
	_refresh_review_button()


func _refresh_review_button() -> void:
	if _review_button == null or not is_instance_valid(_review_button):
		return
	var mine: bool = not _review_local_players().is_empty()
	_review_button.disabled = not mine
	_review_button.text = "확인" if mine else "다른 플레이어를 기다리는 중"


func _close_augment_review() -> void:
	if _review_overlay != null and is_instance_valid(_review_overlay):
		_review_overlay.queue_free()
	_review_overlay = null
	_review_button = null
	_review_bar = null
	_review_chips.clear()


func _on_action_rejected(player_id: int, action: StringName, reason: StringName) -> void:
	if net != null and (player_id != local_player_id or String(action).begins_with("__")):
		return  # 온라인: 내 행동이 거부됐을 때만 알린다 (다른 사람의 거부나 늦은 타임아웃은 조용히 넘어간다)
	_log_line("P%d %s 거부: %s" % [player_id, action, REJECT_REASONS.get(reason, str(reason))], Color("ff8787"))
	if action == &"play_card" and (player_id == local_player_id or not (ai_mode or net != null)) and not _is_bot_turn():
		_show_center_banner("카드를 쓸 수 없습니다: %s" % REJECT_REASONS.get(reason, str(reason)), Color("ff8787"))
	if action == &"reroll_augment":
		_mark_reroll_refused(reason)


## 리롤이 거절되면 그 버튼에 이유를 적고 잠근다 (아무 반응 없이 눌리기만 하던 버그).
func _mark_reroll_refused(reason: StringName) -> void:
	if _last_reroll_index < 0 or _last_reroll_index >= _draft_reroll_buttons.size():
		return
	var button: Button = _draft_reroll_buttons[_last_reroll_index]
	if not is_instance_valid(button):
		return
	match reason:
		&"no_candidate": button.text = "바꿀 증강이 없음"
		&"reroll_used": button.text = "리롤 완료"
		_: button.text = "지금은 리롤할 수 없음"
	button.disabled = true
	Sfx.play(&"bad", -6.0)


func _on_turn_order_reversed(new_direction: int) -> void:
	_log_line("[리버스] UDO 리버스! 턴 방향이 %s이 되었습니다." % ("정방향" if new_direction == 1 else "역방향"), Color("ffd43b"))
	_refresh_all()


func _on_game_over(winner_id: int, reason: StringName) -> void:
	_last_reason = reason
	if not _fx_on():
		Sfx.play(&"win")  # 연출을 켠 판은 결과 창의 1등 공개 때 우승 팡파르를 낸다 (지금 내면 졸업 팡파르와 겹친다)
	for player_id: int in _player_ids:
		_avatar_react(player_id, AvatarSlot.Emotion.CHEER if player_id == winner_id else AvatarSlot.Emotion.SAD, 0.0)
	_log_line("[승리] P%d 승리! - %s" % [winner_id, VictoryChecker.reason_text(reason)], PLAYER_COLORS[winner_id])
	_record(winner_id, "★ 게임 종료! (%s)" % _bb(VictoryChecker.reason_text(reason)))
	_close_draft_overlay()
	_cancel_tile_pick()
	if not _fx_on():
		_show_result_overlay()
		_refresh_all()
		return
	# 갑자기 결과 창으로 넘어가지 않게: 남은 연출이 끝난 뒤 [매치 종료] 사유를 1.5초 브리핑하고 결과 창을 띄운다.
	# 그 전까지는 화면 갱신(_refresh_overlays)이 결과 창을 먼저 띄우지 않는다.
	_result_hold = true
	var reason_line: String = match_end_reason()
	var tint: Color = PLAYER_COLORS.get(int(_decisive_rank.get("player", winner_id)), Color("ffd43b"))
	_enqueue_late(func() -> void:
		_announce_now("매치 종료", "[매치 종료!]", reason_line, tint, null, END_BRIEF_SECONDS)
		await get_tree().create_timer(END_BRIEF_SECONDS).timeout
		# 브리핑 카드의 퇴장 연출까지 끝난 뒤에 결과 창을 띄운다 (카드가 결과 창 위에 겹쳐 남지 않게, 최대 3초)
		var waited: float = 0.0
		while is_inside_tree() and _announcer != null and _announcer.holding() and waited < 3.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		if manager != null and manager.is_game_over and _result_overlay == null:
			_show_result_overlay()
			_refresh_all())
	# 안전장치: 남은 연출이 어떤 이유로든 멈춰도 결과 창은 반드시 뜬다 (연출이 끝난 채 조용하거나 RESULT_WATCHDOG_SECONDS가 지나면)
	_result_watchdog(Time.get_ticks_msec(), 0)
	_refresh_all()


## 결과 창 안전장치: 1초마다 확인한다. 연출·알림이 3초 연속 조용하거나 RESULT_WATCHDOG_SECONDS가 지나면 결과 창을 띄운다.
const RESULT_WATCHDOG_SECONDS: float = 30.0


func _result_watchdog(started_msec: int, quiet_seconds: int) -> void:
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if not is_inside_tree() or manager == null or not manager.is_game_over or _result_overlay != null:
			return
		var busy: bool = _presentation_active() or _ui_busy() or (_announcer != null and _announcer.holding())
		var quiet: int = 0 if busy else quiet_seconds + 1
		if quiet >= 3 or Time.get_ticks_msec() - started_msec >= int(RESULT_WATCHDOG_SECONDS * 1000.0):
			_show_result_overlay()
			_refresh_all()
		else:
			_result_watchdog(started_msec, quiet))


## 판을 끝낸 결정적 사유 한 줄: "에르핀님이 '투기장의 지배자(적 말을 6회 처치)' 법전을 달성하여 1위로 졸업했습니다!"
## 남은 컴퓨터를 레이스 순으로 매기거나 마지막 한 명을 꼴찌로 매긴 것은 사유가 아니다: 그 직전의 졸업을 쓴다.
func match_end_reason() -> String:
	var entry: Dictionary = _decisive_rank
	if entry.is_empty() and state != null and not state.rankings.is_empty():
		var first: int = state.rankings[0]
		entry = {"player": first, "rank": 1, "reason": state.rank_reasons.get(first, _last_reason)}
	if entry.is_empty():
		return VictoryChecker.reason_text(_last_reason)
	var who: String = _player_name(int(entry["player"]))
	var reason: StringName = entry["reason"]
	if LawRegistry.ALL_IDS.has(String(reason)):
		var law: LawResource = LawRegistry.create(String(reason))
		return "%s님이 '%s(%s)' 법전을 달성하여 %d위로 졸업했습니다!" % [who, law.law_name, law.description, int(entry["rank"])]
	return "%s님이 말 4개를 모두 완주하여 %d위로 졸업했습니다!" % [who, int(entry["rank"])]


func _ui_busy() -> bool:
	if _counter_gate_waiting and manager != null and manager.counter_pending():
		return false  # 처치 연출이 방어 결정을 기다리는 중: 봇·사람이 방어 카드를 고를 수 있어야 한다
	if _fx_on() and _draw_fx != null and _draw_fx.busy():
		return true
	return _turn_banner_pending() or _intro_blocks() or _presentation_active() or _fx_busy or _gambler_result_busy() or (_capture_cutin != null and _capture_cutin.busy()) or _aim_pawn != -1 or (_announcer != null and _announcer.holding()) or Time.get_ticks_msec() < _beat_until_msec or (_fx_on() and Time.get_ticks_msec() < _fx_until_msec)


## 지금부터 ms밀리초 뒤의 시각 (Time.get_ticks_msec 기준). 배속(Engine.time_scale)만큼 짧아진다: 트윈·타이머와 같은 빠르기로 풀린다.
func _msec_from_now(ms: float) -> int:
	return Time.get_ticks_msec() + int(ms / maxf(Engine.time_scale, 0.01))


## 행동이 끝난 뒤 잠깐(초) 입력과 봇 행동을 멈춰, 플레이어가 방금 일어난 일을 알아볼 틈을 준다.
func _start_beat(seconds: float) -> void:
	if instant_roll_for_test or not pacing_enabled or seconds <= 0.0:
		return
	_beat_until_msec = maxi(_beat_until_msec, _msec_from_now(seconds * _pace() * 1000.0))
	get_tree().create_timer(seconds * _pace() + 0.02).timeout.connect(func() -> void:
		if manager != null and state != null:
			_refresh_all())


## blocking=false: 띄워만 두는 안내(차례·라운드·휴식 등). 굴림·이동·봇은 이 알림을 기다리지 않고 바로 이어진다 (_announce_soft).
func _announce(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5, blocking: bool = true) -> int:
	if _announcer == null:
		if extra != null:
			extra.free()
		return -1
	# A queued preview is owned immediately; cancelling the queue must not
	# strand an unattached card tree or leave it counted as an orphan.
	if _fx_on() and (_presentation_active() or (_draw_fx != null and _draw_fx.busy())):
		if extra != null:
			if not is_instance_valid(_announcement_extras):
				_announcement_extras = Node.new()
				_announcement_extras.name = "PendingAnnouncementExtras"
				add_child(_announcement_extras)
			_announcement_extras.add_child(extra)
			extra.hide()
		enqueue_step(func() -> void:
			if is_instance_valid(extra):
				_announcement_extras.remove_child(extra)
				extra.show()
			_announce_now(tag, headline, body, color, extra, duration, blocking))
		return -1
	return _announce_now(tag, headline, body, color, extra, duration, blocking)


## 차례 배너가 늦었는가: 굴림 연출 중이거나, 굴리기 전 단계(턴 시작·굴리기 대기)를 이미 지났다.
func _turn_banner_stale() -> bool:
	if _fx_busy or manager == null:
		return _fx_busy
	return manager.current_state != TurnManager.State.PHASE_TURN_BEGIN and manager.current_state != TurnManager.State.PHASE_ROLL_WAIT


## 띄워만 두는 안내 (Fire-and-Forget): 처치 컷인·결투·방어 선택 같은 중요한 장면이 아닌 일반 안내 배너.
func _announce_soft(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5) -> int:
	return _announce(tag, headline, body, color, extra, duration, false)


func _announce_now(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5, blocking: bool = true) -> int:
	if _announcer == null:
		return -1
	if tag == "턴" and _turn_banner_stale():
		if extra != null:
			extra.free()
		return -1  # 연출 큐에서 차례가 늦게 돌아왔다: 이미 굴렸거나 다음 단계로 넘어갔으면 차례 배너는 띄우지 않는다
	_announcer.instant = instant_roll_for_test
	var serial: int = _announcer.announce(tag, headline, body, color, extra, duration * _pace(), blocking)
	if _announcer.active:
		_refresh_controls()
	return serial


## 알림 카드가 끝난 직후 말 움직임 연출이 이어지도록 이 카드를 [문]으로 등록한다 (카드가 보드를 가리는 동안에는 말이 먼저 움직이지 않는다).
func _announce_gate(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5) -> void:
	var serial: int = _announce(tag, headline, body, color, extra, minf(duration, GATE_MAX_SECONDS))
	if serial >= 0 and _fx_on():
		_fx_gates.append(serial)
		_fx_gate_open = false


## 새 교칙이 제정되면 현재 법전 전체를 중앙에 띄우고 새로 들어온 줄을 금색으로 강조한다.
func _announce_law_added(new_law: LawResource, removed_law: LawResource) -> void:
	var board := VBoxContainer.new()
	board.add_theme_constant_override("separation", 4)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for law: LawResource in state.rulebook.active_laws_queue:
		var is_new: bool = law == new_law
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size = Vector2(420, 0)
		row.add_theme_stylebox_override("panel", _style(Color("4a3d12") if is_new else Color("1b2030"), COLOR_GOLD if is_new else Color("3b4252"), 3 if is_new else 1, 8, 6, 5))
		var text: String = "%s[%s] %s - %s" % ["NEW  " if is_new else "", law.law_id, law.law_name, law.description]
		var label := _make_label(text, 13, Color("fff3bf") if is_new else Color("adb5bd"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		board.add_child(row)
	var body: String = new_law.description
	if removed_law != null:
		body += "\n(가장 오래된 [%s] %s이(가) 밀려났습니다)" % [removed_law.law_id, removed_law.law_name]
	_announce("법전 개정", "새 특수 승리 교칙: %s" % new_law.law_name, body, COLOR_GOLD, board, 2.6)


## 카드 사용 알림에 붙일 카드 앞면 (손패 카드와 같은 모양, 클릭 불가).
func _make_card_preview(card_id: StringName) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_make_card_face(card_id))
	return holder


## 앞면 카드 한 장 (140x196, 클릭 불가). 알림 미리보기가 쓴다.
func _make_card_face(card_id: StringName) -> PanelContainer:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var view := PanelContainer.new()
	view.custom_minimum_size = HAND_CARD_SIZE
	view.size = HAND_CARD_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_theme_stylebox_override("panel", _card_frame_style(card.category, false))
	view.add_child(_build_card_body(card_id, HAND_CARD_SIZE))
	return view


func _on_law_added(new_law: LawResource, removed_law: LawResource) -> void:
	_mark_spotlight()  # 법전(특수 승리 교칙)이 바뀐 턴은 보통 속도
	var text: String = "[법전] 교칙 제정: [%s] %s" % [new_law.law_id, new_law.law_name]
	if removed_law != null:
		text += "  (가장 오래된 [%s] %s이(가) 밀려났습니다)" % [removed_law.law_id, removed_law.law_name]
	_log_line(text, Color("ffe066"))
	_record(-1, "[color=#ffe066][lb]법전] %s 등록![/color]%s" % [_bb(new_law.law_name), "  (%s 밀려남)" % _bq(removed_law.law_name) if removed_law != null else ""])
	_fx_law_drop_oldest(removed_law)
	_refresh_laws()
	_fx_law_slam(new_law)
	# 증강 드래프트로 생긴 교칙은 드래프트 요약 카드에 함께 나오므로 따로 공개하지 않는다.
	if manager.current_state != TurnManager.State.PHASE_ROUND_START:
		_announce_law_added(new_law, removed_law)


## 가득 차서 밀려나는 가장 오래된 교칙 슬롯: 아래로 툭 떨어지며 사라진다 (맨 위 슬롯을 복제해 떨어뜨린다).
func _fx_law_drop_oldest(removed_law: LawResource) -> void:
	if removed_law == null or not _fx_on() or _law_slots.is_empty():
		return
	Sfx.play(&"law_drop")
	var slot: Control = _law_slots[0]
	var ghost: Control = slot.duplicate()
	ghost.z_index = 30
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	ghost.global_position = slot.global_position
	ghost.size = slot.size
	var tween: Tween = ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "position:y", ghost.position.y + 70.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.45)
	tween.tween_property(ghost, "rotation", 0.12, 0.45)
	tween.chain().tween_callback(ghost.queue_free)


## 새 교칙 슬롯이 쿵 하고 찍히며 빛난다.
func _fx_law_slam(new_law: LawResource) -> void:
	if not _fx_on():
		return
	Sfx.play(&"law")
	var index: int = state.rulebook.active_laws_queue.find(new_law)
	if index < 0 or index >= _law_slots.size():
		return
	var slot: Control = _law_slots[index]
	slot.pivot_offset = slot.size / 2.0
	slot.scale = Vector2(1.3, 1.3)
	slot.modulate = Color(1.8, 1.7, 1.1)
	var tween: Tween = slot.create_tween().set_parallel(true)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate", Color.WHITE, 0.5)
	var center: Vector2 = slot.global_position + slot.size / 2.0
	tween.chain().tween_callback(func() -> void: _impact_ring(center, Color("ffe066"), 40.0))
	screen_shake(4.0, 0.15)


func _on_law_applied(law: LawResource, timing: String, dice_before: int, dice_after: int, modified: bool) -> void:
	# 값을 실제로 바꾼 교칙만 보여 준다. 이동 계산(ON_MOVE_CALC) 교칙은 매 걸음 로그를 도배하지 않도록
	# 이동 보고서(move_resolved)의 요약 한 줄로만 남긴다 (경로·눈금이 실제로 달라졌을 때).
	if not modified:
		return
	if timing != RuleContext.ON_MOVE_CALC:
		var detail: String = ""
		if dice_before != dice_after:
			detail = "  눈금 %d → %d" % [dice_before, dice_after]
		_log_line("[법전] [%s] %s 작동 (%s)%s" % [law.law_id, law.law_name, timing, detail], Color("ffe066"))
		_announce_soft("법전 발동", "[%s] %s" % [law.law_id, law.law_name], (law.description + detail.strip_edges().insert(0, "\n") if detail != "" else law.description), Color("ffe066"), null, 1.1)
	_flash_law_ids[law.law_id] = true
	_refresh_laws()
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_flash_law_ids.erase(law.law_id)
		if state != null:
			_refresh_laws())


func _on_event(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"roll_resolved":
			_handle_roll_event(data)
			_enqueue_roll_summary(data)
			_record_roll(data)
		&"roll_boosted":
			_roll_total[int(data["player_id"])] = int(data["to"])
			_add_roll_reason(int(data["player_id"]), "가속 보너스 +%d" % (int(data["to"]) - int(data["from"])))
			_log_line("[가속 보너스] P%d: 눈금 %d → %d!" % [data["player_id"], data["from"], data["to"]], Color("ffd43b"))
			_record(int(data["player_id"]), "가속 보너스 → %d칸 → 총 %d칸 전진!" % [data["from"], data["to"]])
		&"tempo_up":
			var stage: int = int(data["level"])
			var lines: Array = data["lines"]
			_log_line("[템포 업 Lv.%d] %d라운드부터: %s" % [stage, data["round"], " / ".join(PackedStringArray(lines))], Color("ff6b6b"))
			var tempo_round: int = int(data["round"])
			# 라운드 끝(마지막 차례·NPC 페이즈)의 처치 연출이 다 끝난 뒤에 경고하고, 증강 선택 창은 그 경고 뒤에 연다.
			# (지연 큐에 넣는다: 처치 연출도 지연 큐로 들어오므로 그보다 앞서 끼어들지 않는다)
			_enqueue_late(func() -> void:
				_record(-1, "[color=#ff6b6b][b]!! 템포 업 Lv.%d[/b] - %s[/color]" % [stage, _bb(" · ".join(PackedStringArray(lines)))], "", false, true)
				if _fx_on():
					screen_shake(12.0, 0.5)
					Sfx.play(&"tempo_warning")
				_announce_now("템포 업", "템포 업 Lv.%d · %s" % [stage, TempoUp.stage_name(stage)], "%d라운드부터 게임이 빨라집니다!\n◆ %s" % [tempo_round, "\n◆ ".join(PackedStringArray(lines))], Color("ff4d4d"), null, 3.2))
		&"special_victory_judgement":
			_mark_spotlight()
			var achievers: Array = data["players"]
			_log_line("[%d라운드 특수 승리] 달성: %s" % [int(data["round"]), ", ".join(PackedStringArray(achievers.map(func(id: int) -> String: return _player_name(id))))], Color("ffd43b"))
			# 달성한 법전 카드 (판정 직후 법전에서 지워지므로 지금 슬롯 자리·이름을 잡아 둔다): 가운데로 날아와 도장이 찍힌 뒤 순위 배너
			var achieved: Array = []
			var law_ids: Array = data.get("laws", [])
			for index: int in mini(achievers.size(), law_ids.size()):
				var slot_index: int = -1
				var achieved_law: LawResource = null
				for i: int in state.rulebook.active_laws_queue.size():
					if state.rulebook.active_laws_queue[i].law_id == str(law_ids[index]):
						slot_index = i
						achieved_law = state.rulebook.active_laws_queue[i]
				if achieved_law == null:
					achieved_law = LawRegistry.create(str(law_ids[index]))
				if achieved_law == null:
					continue
				var from: Rect2 = _law_slots[slot_index].get_global_rect() if slot_index >= 0 and slot_index < _law_slots.size() else Rect2(Vector2(40, 200), Vector2(280, 66))
				achieved.append([from, achieved_law.law_name, achieved_law.description, PLAYER_COLORS.get(int(achievers[index]), Color("ffd43b"))])
			for entry: Array in achieved:
				_enqueue_late(func() -> void: _fx_law_achieved(entry[0], entry[1], entry[2], entry[3]))
		&"race_ranked":
			if bool(data.get("round_cap", false)):
				_log_line("[%d라운드 종료] 남은 플레이어는 진행 순위로 순위가 확정됩니다" % PacingDirector.HARD_CAP_ROUND, Color("ffd43b"))
		&"goal_shrunk":
			var finished_ids: Array = data["finished"]
			_refresh_tiles()
			_log_line("[템포 업] 결승선이 %d칸 당겨졌습니다 (%d번 칸부터 결승)%s" % [data["shrink"], data["zone_start"], ", 완주 %d" % finished_ids.size() if not finished_ids.is_empty() else ""], Color("ffd43b"))
			_record(-1, "결승선 %d칸 당겨짐 (%d번부터 결승)%s" % [int(data["shrink"]), int(data["zone_start"]), " - 말 %d개 즉시 완주!" % finished_ids.size() if not finished_ids.is_empty() else ""])
			if TempoUp.is_stage_round(int(data["round"])) or not finished_ids.is_empty():
				_announce("템포 업", "결승선이 당겨진다!", "%d번 칸부터 결승선 - 라운드마다 %d칸씩 더 당겨집니다%s" % [data["zone_start"], TempoUp.GOAL_SHRINK_PER_ROUND, "\n말 %d개가 그 자리에서 완주!" % finished_ids.size() if not finished_ids.is_empty() else ""], Color("ffd43b"), null, 2.0)
		&"tempo_boosted":
			_roll_total[int(data["player_id"])] = int(data["to"])
			_add_roll_reason(int(data["player_id"]), "템포 업 +%d" % (int(data["to"]) - int(data["from"])))
			_log_line("[템포 업] P%d: 이동 %d → %d" % [data["player_id"], data["from"], data["to"]], Color("ff8787"))
			_record(int(data["player_id"]), "템포 업 +%d → 총 %d칸 전진!" % [int(data["to"]) - int(data["from"]), int(data["to"])])
		&"gambler_doubled":
			_gambler_flash[int(data["player_id"])] = {"multiplier":SuperAugments.gambler_multiplier(),"from":int(data["from"]),"to":int(data["to"])}
			_roll_total[int(data["player_id"])] = int(data["to"])
			_add_roll_reason(int(data["player_id"]), "도박사의 영혼 x2")
			_log_line("[도박사의 영혼] P%d: 이동 %d → %d (x2)!" % [data["player_id"], data["from"], data["to"]], Color("ffa94d"))
			_record(int(data["player_id"]), "도박사의 영혼 x2 → %d칸 → 총 %d칸 전진!" % [data["from"], data["to"]])
		&"move_bonus":
			_on_move_bonus(int(data["pawn_id"]), data["notes"], int(data.get("revenge", 0)))
		&"gambler_busted":
			var busted: int = int(data["player_id"])
			_gambler_flash[busted] = {"multiplier":-1,"roll":int(data["roll"])}
			_log_line("[도박사의 영혼] P%d: 눈금 %d - 과열! 이동 없이 차례 끝" % [busted, data["roll"]], Color("ff6b6b"))
			_record(busted, "도박사의 영혼 과열! (눈금 %d, 이동 없이 차례 끝)" % int(data["roll"]))
			# Reveal the failure with the settled roll, instead of spoiling it mid-toss.
			if not _fx_on():
				_announce("도박사의 영혼", "[과열!]", "눈금 %d - 이번 차례는 이동 없이 바로 끝납니다" % data["roll"], Color("ff6b6b"), null, 1.1)
		&"turn_rested":
			var rested: int = int(data["player_id"])
			_log_line("[강제 턴 패스] P%d가 이번 차례를 쉽니다 (UDO 스킵)" % rested, Color("adb5bd"))
			_record(rested, "강제 턴 패스")
			if _fx_on():
				Sfx.play(&"timeout")
			_announce_soft("휴식", "강제 턴 패스!", "%s 이번 차례 쉬기" % _player_name(rested), Color("adb5bd"), null, 0.9)  # 쉬는 턴은 기다리지 않고 바로 다음 차례로
		&"stack_resolved":
			var stack_names: Array[String] = []
			for member_id: Variant in data["members"]:
				stack_names.append(_pawn_name(int(member_id)))
			if data["stacked"]:
				_log_line("[업기] P%d: %s 하나로 합체!" % [data["player_id"], ", ".join(stack_names)], Color("ffd43b"))
			else:
				_log_line("[업기] P%d: 그냥 두기 - 개별 유지" % data["player_id"], Color("adb5bd"))
		&"move_resolved":
			_follow_up_pawns.erase(int(data.get("pawn_id", -1)))
			_log_move(data)
			_start_beat(BEAT_AFTER_MOVE)
			_bakery_feedback(data)
			_corner_buff_feedback(data)
			if bool(data.get("jailed", false)) and (data.get("path", []) as Array).is_empty():
				_announce_move_failed("무인도 탈출 실패!", manager.current_player_id(), "짝수 눈금이 나와야 탈출할 수 있습니다")
		&"turn_skipped":
			_record(int(data["player_id"]), "움직일 수 있는 말이 없어 이동 실패")
			_announce_move_failed("움직일 수 있는 말이 없어", int(data["player_id"]), "구속 중이거나 선택할 수 있는 말이 없습니다")
		&"card_played":
			var card: BaseCard = CardRegistry.get_card(data["card_id"])
			var player: int = int(data["player_id"])
			_record_card(data)
			if card.category == GameEnums.CardCategory.TRAP and not card.corner_only:
				# 은신 함정: 무슨 카드인지는 숨기고 "누가 함정을 깔았다"만 알린다 (내 함정이면 로그에만 이름을 남긴다)
				var mine: bool = (ai_mode or net != null) and player == local_player_id
				_log_line("[카드] P%d 함정 카드 설치%s" % [player, " [%s]" % card.display_name if mine else ""], Color("74c0fc"))
				_announce_gate("함정 설치", "%s의 함정 카드 설치!" % _player_name(player), "어딘가에 함정이 숨겨졌습니다. 조심하세요!", PLAYER_COLORS[player], null, 1.0)
			else:
				_log_line("[카드] P%d [%s] 사용%s" % [player, card.display_name, " (개입 대기열 - 나중에 낸 카드부터 실행)" if data["queued"] else ""], Color("74c0fc"))
				if ATTACK_CARDS.has(StringName(data["card_id"])):
					# 공격 카드: 먼저 [공격 카드 발동!] 경보를 크게 띄우고, 그다음에 어떤 카드인지 공개한다
					_announce(ATTACK_TAG, "공격 카드 발동!", "%s의 공격!" % _player_name(player), Color("ff4d4d"), null, 0.6)
				_announce_gate("카드 발동", "[P%d 발동!] %s" % [player, card.display_name], ("개입 대기열 등록 (후입선출)\n" if data["queued"] else "") + card_summary(data["card_id"]), PLAYER_COLORS[player], _make_card_preview(data["card_id"]), 1.2)
		&"npc_phase_resolved":
			if not (data["reports"] as Array).is_empty():
				# 중립 기물 이동: 안내 카드가 먼저 뜨고, 기물이 한 칸씩 달린 뒤, 말을 잡았으면 그다음에 처치 알림과 사출이 이어진다.
				_announce_gate("중립 기물", "[중립 기물 이동]", NPC_ANNOUNCE_BODY, Color("fa5252"), null, 0.6)
			for report: Dictionary in data["reports"]:
				var npc_name: String = _npc_runner_name(report["display_id"])
				var caught: Array = report["caught"]
				var run_path: Array = report["path"]
				var result_text: String = ("%s %d칸 질주 - 말 %d개를 잡고 사라졌습니다!" % [npc_name, run_path.size(), caught.size()]) if not caught.is_empty() else "%s - 처치할 적이 없어 그대로 사라졌습니다" % npc_name
				_play_npc_run(report["display_id"], int(report.get("behavior", GameEnums.NpcBehavior.CHASE_NEAREST)), int(report.get("from", -1)), run_path, int(report["npc_id"]), func() -> void:
					_log_line("[중립 기물] %s" % result_text, Color("fa5252"))
					if not caught.is_empty():
						_record(-1, "%s" % result_text))  # 잡은 말은 처치 컷인·사출로 보인다 (따로 [말을 잡았습니다!] 카드는 띄우지 않는다)
		&"augment_offers":
			_super_changes.clear()
			_draft_open = true
			_log_line("[증강] 라운드 %d 증강 드래프트가 열렸습니다." % data["round"], Color("ffa94d"))
		&"augment_reshuffled":
			var fiction_players: Array = data.get("players", [])
			_log_line("[올 픽션] 모두가 고른 증강을 버리고 새 3장 중에서 다시 고릅니다", Color("4dabf7"))
			for fiction_player: Variant in fiction_players:
				_record(int(fiction_player), "[올 픽션] 전원 증강 재추첨!")
			if _fx_on():
				_floating_badge(_board_center(), str(UtilityAugments.CALLOUTS[UtilityAugments.REROLL_ALL_AUG]), AugmentDef.DISPLAY_COLORS[&"instant"], 30)
			_refresh_draft_overlay()
		&"revive_triggered":
			var revived: int = int(data["player_id"])
			_log_line("[다이스: 리바이브] P%d: 턴이 끝나도 한 턴 더 합니다" % revived, Color("4dabf7"))
			_record(revived, "[다이스: 리바이브] 발동 - 한 턴 더!")
			if _fx_on():
				_floating_badge(_board_center() + Vector2(0, -60), "[리바이브!] 한 턴 더!", AugmentDef.DISPLAY_COLORS[&"passive"], 30)
			_refresh_status_stamps(revived)
		&"augment_review":
			_show_augment_review(data["players"])
		&"augment_review_done":
			_paint_review_chip(int(data["player_id"]), true)
			_refresh_review_button()
		&"augment_picked":
			_log_line("[증강] P%d%s: %s - %s" % [data["player_id"], " (자동)" if data["auto"] else "", AugmentRegistry.get_def(data["augment_id"]).display_name, data["text"]], Color("ffa94d"))
			# 한 명씩 공개하면 늘어지므로 모아 두었다가 드래프트가 끝나면 한 장으로 한꺼번에 공개한다.
			_draft_summary.append({"player": int(data["player_id"]), "augment": data["augment_id"], "text": str(data["text"])})
			if int(data["player_id"]) == _telemetry_seat():
				var picked_def: AugmentDef = AugmentRegistry.get_def(data.get("augment_id", &""))
				_my_augments.append(picked_def.display_name if picked_def != null else str(data.get("augment_id", "")))
			_on_super_picked(int(data["player_id"]), data.get("augment_id", &""))
			_on_utility_picked(int(data["player_id"]), data.get("augment_id", &""))
			_pick_serial += 1
			_super_changes.clear()
		&"bang_resolved":
			var target_name: String = _pawn_name(int(data["target"]))
			_log_line("[BANG!] P%d가 %s을(를) 저격! 출발선으로 장외 사출!" % [data["shooter"], target_name], Color("ff6b6b"))
			_fx_bang(int(data["shooter"]), int(data["target"]))
		&"duel_started", &"duel_pick_in", &"duel_revealed", &"duel_resolved":
			if kind == &"duel_started":
				_record(int(data["challenger"]), "%s에게 일기토 데스매치 신청!" % _log_who(int(data["defender"])))
			_on_duel_event(kind, data)
			if kind == &"duel_revealed" and int(data["winner"]) != -1:
				# 결투장이 공개를 받은 뒤라 공개 연출을 기다린다
				_record(int(data["winner"]), "[결투] %s vs %s : %s %s → %s 승리!" % [_bb(_player_name(int(data["challenger"]))), _bb(_player_name(int(data["defender"]))), _bq(DuelRules.game_name(int(data["game"]))), _bb(str(data["detail"])), _bb(_player_name(int(data["winner"])))])
		&"skill_used":
			var skill_pawn: PlayerPawn = state.get_pawn(int(data["pawn_id"]))
			_record(int(data["player_id"]), "%s 필살기 사용!" % _bq("%s - %s" % [skill_pawn.display_label() if skill_pawn != null else "말", PawnCatalog.skill_name(data["skill"])]))
			_on_skill_used(data)
		&"pawn_pushed_back":
			_log_line("[백돌 방어막] 백돌에 막혀 %s이(가) %d번 → %d번으로 밀려났습니다" % [_pawn_name(int(data["pawn_id"])), data["from"], data["to"]], Color("b197fc"))
		&"bomb_applied":
			_log_line("[UDO +4] P%d의 %s이(가) 출발선으로 장외 사출! 내 이번 이동 +%d칸" % [data["victim"], _pawn_name(int(data["pawn_id"])), PenaltyBombCommand.advance_steps()], Color("ffd43b"))
			_fx_simple_shot(int(data["shooter"]), int(data["pawn_id"]))
			_react_hit_pawn(int(data["pawn_id"]))
		&"player_ranked":
			var ranked: int = int(data["player_id"])
			var rank_no: int = int(data["rank"])
			if StringName(data["reason"]) != VictoryChecker.RACE_ORDER and StringName(data["reason"]) != VictoryChecker.LAST_PLACE:
				_decisive_rank = {"player": ranked, "rank": rank_no, "reason": StringName(data["reason"])}
			_report_player_ranked(ranked, rank_no)
			_log_line("[순위 확정] %s %d위 - %s" % [_player_name(ranked), rank_no, VictoryChecker.reason_text(data["reason"])], Color("ffd43b"))
			# 순위는 라운드가 끝나는 순간(마지막 차례의 이동·처치 뒤)에 확정된다: 그 처치 연출·기록이 끝난 뒤에 알린다.
			var reason_text: String = VictoryChecker.reason_text(data["reason"])
			var rank_reason: StringName = data["reason"]
			_record(ranked, "★ %d위 확정! (%s)" % [rank_no, _bb(reason_text)], "", true)
			_enqueue_late(func() -> void:
				if rank_no < _player_ids.size() - 1:  # 3위(마지막 졸업)부터는 결과 화면이 바로 이어진다 (팡파르도 시상대에 맡긴다)
					if _fx_on():
						Sfx.play_stinger(&"graduate")
					_announce(tr_ui("rank.tag"), tr_ui("rank.banner", ["★ " if rank_no == 1 else "", _player_name(ranked), rank_no]), tr_ui("rank.body", [VictoryChecker.reason_text(rank_reason)]), PLAYER_COLORS[ranked], null, RANK_BANNER_SECONDS)
					_profile_react(ranked, true, "%d위" % rank_no)
					_start_beat(RANK_BEAT_SECONDS))
		&"counter_offer":
			_log_line("[방어 대기] %s: %s - 방어 카드 %d장" % [_player_name(int(data["victim"])), _attack_text(data), (data["cards"] as Array).size()], Color("bac8ff"))
		&"counter_passed":
			_log_line("[방어] %s이(가) 그냥 맞기로 했습니다" % _player_name(int(data["victim"])), Color("adb5bd"))
		&"counter_resolved":
			_log_line("[방어 성공] %s의 [%s]!" % [_player_name(int(data["victim"])), _card_name(data["card_id"])], Color("74c0fc"))
			_profile_react(int(data["victim"]), true)
		&"turn_rewound":
			_record(int(data["player_id"]), "이번 턴이 통째로 되감겼습니다")
			_announce("방어", "[바이츠 더 더스트!]", "%s의 턴이 통째로 되감기고 끝났습니다" % _player_name(int(data["player_id"])), Color("4c6ef5"), null, 1.3)
		&"extra_turn":
			_announce_soft("XI. The World!!", tr_ui("turn.extra", [_player_name(int(data["player_id"]))]), "시간이 멈춘 사이 한 번 더 움직입니다", PLAYER_COLORS[int(data["player_id"])], null, 1.1)
		&"game_over":
			_last_reason = data["reason"]
	_refresh_all()


func _log_roll(data: Dictionary) -> String:
	var text: String = _roll_text(data)
	_log_line("[굴림] P%d [%s] " % [data["player_id"], state.tools[data["player_id"]].display_name] + text, Color("f1f3f5"))
	return text


## 굴림 결과 한 줄 (도구별 족보·칸수).
func _roll_text(data: Dictionary) -> String:
	var result: Dictionary = data["result"]
	var details: Dictionary = result["details"]
	var text: String = ""
	match result["tool_id"]:
		&"YUT":
			if result["ends_turn"]:
				text += "낙! 윷가락이 판 밖으로 - 0칸, 턴 종료"
			else:
				text += "%s (%d칸)" % [YUT_NAMES.get(int(details.get("face", result["steps"])), "?"), result["steps"]]
		&"HOLDEM": text += "%s → %d칸" % [HAND_NAMES.get(details["hand"], "?"), result["steps"]]
		&"SLOT_777":
			var symbols: Array[String] = []
			for reel: int in details["reels"]:
				symbols.append(SLOT_SYMBOLS[reel])
			text += "%s → %d칸" % [" | ".join(symbols), result["steps"]]
		&"CHINCHIRO":
			text += "%d칸" % result["steps"] if not details["oops"] else "삐끗! 주사위가 접시 밖으로 (이번 이동 0칸)"
		&"DICE_HWATU":
			var shown_names: Array[String] = []
			for card_number: Variant in details.get("new_cards", []):
				shown_names.append(ToolHwatu.card_name(int(card_number)))
			if result["ends_turn"]:
				text += "[%s] 망통! 0칸, 턴 종료" % ", ".join(shown_names)
			else:
				text += "[%s] %s → %d칸" % [", ".join(shown_names), details["label"], result["steps"]]
		&"DICE_MAHJONG":
			var tile_names: Array[String] = []
			for tile_number: Variant in details["tiles"]:
				tile_names.append(ToolMahjong.tile_name(int(tile_number)))
			text += "%s → %s %d칸" % [" ".join(tile_names), details["label"], result["steps"]]
		&"DICE_TAROT":
			text += ("%s → 0칸, 턴 종료" % details["name"]) if result["ends_turn"] else ("%s → %d칸" % [details["name"], result["steps"]])
			if details.has("bonus"):
				text += "  (매달린 남자의 축복 +%d칸 포함)" % int(details["bonus"])
			if details.has("blessing_booked"):
				text += "  다음 굴림에 +%d칸 축복 예약!" % int(details["blessing_booked"])
		&"DICE_YACHT":
			var dice_text: String = " ".join(PackedStringArray((details["dice"] as Array).map(func(face: Variant) -> String: return str(face))))
			if bool(result.get("can_continue", false)):
				text += "[%s] %s (예상 %d칸) 남은 다시 굴리기 %d회" % [dice_text, details["label"], int(details["preview_steps"]), int(details["rerolls_left"])]
			else:
				text += "[%s] %s → %d칸 이동 확정" % [dice_text, details["label"], result["steps"]]
		&"DICE_BLACKJACK":
			var card_text: String = " ".join(PackedStringArray((details["cards"] as Array).map(func(rank: Variant) -> String: return ToolBlackjack.card_name(int(rank)))))
			if bool(details.get("bust", false)):
				text += "[%s] 합계 %d - BUST! 0칸, 턴 종료" % [card_text, int(details["total"])]
			elif bool(details.get("blackjack", false)):
				text += "[%s] 합계 21 BLACKJACK! → %d칸" % [card_text, result["steps"]]
			elif bool(result.get("can_continue", false)):
				text += "[%s] 합계 %d (스탠드하면 %d칸)" % [card_text, int(details["total"]), int(details["preview_steps"])]
			else:
				text += "[%s] 스탠드: 합계 %d → %d칸 이동 확정" % [card_text, int(details["total"]), result["steps"]]
		&"DICE_PINBALL":
			text += "구슬이 [%s] 구멍에 골인 → %d칸" % ["★10" if int(details["value"]) == 10 else str(details["value"]), result["steps"]]
		&"REVOLVER":
			if details["fired"]:
				text += "뿅! 깃발 발사 · 누적 %d칸 사라짐, 턴 종료" % details["lost"]
			else:
				text += ("%d칸 이동 확정" if details.get("voluntary",false) or not result.get("can_continue",false) else "찰칵! 누적 %d칸") % result["steps"]
		_: text += "%d칸" % result["steps"]
	if result["reroll"]:
		text += "  ★ 재굴림!"
	return text


func _log_move(data: Dictionary) -> void:
	var pawn_id: int = data["pawn_id"]
	var text: String = "[이동] %s" % _pawn_name(pawn_id)
	if data["canceled"]:
		text += " 이동 취소됨" + (" (무인도에 갇혀 있음: 짝수 눈금이 필요)" if data["jailed"] else " (교칙)")
	else:
		text += " 경로 %s" % str(data["path"])
	if data["released"]:
		text += "  무인도 탈출!"
	if data["bounced"]:
		text += "  결승선에서 튕겨 나옴"
	if data["warped"]:
		text += "  점프·옷장 워프"
	if data["stopped_early"]:
		text += "  이동 중단"
	if not (data["captured"] as Array).is_empty():
		text += "  [잡기] %s" % str(data["captured"])
	if data["extra_turn"]:
		text += "  (추가 턴)"
	if data["bonus_roll"]:
		text += "  (사기 윷: 추가 굴림)"
	if not (data["law_notes"] as Array).is_empty():
		text += "  [법전] 이동 변조: %s" % ", ".join(data["law_notes"])
	if not (data["ability_notes"] as Array).is_empty():
		text += "  [능력] %s" % ", ".join(data["ability_notes"])
	if not (data["destroyed"] as Array).is_empty():
		text += "  [증기선] 상대 설치물 파괴 %d개" % (data["destroyed"] as Array).size()
	if int(data["dog_cards"]) > 0:
		text += "  [강아지] 지나친 빵집에서 카드 %d장" % data["dog_cards"]
	if int(data.get("defused_cards", 0)) > 0:
		text += "  [지뢰찾기] 함정 해체 카드 %d장" % data["defused_cards"]
	if data["pushed_back"]:
		text += "  [백돌 방어막] 잡을 수 없어 함께 섭니다"
	if data["hotel_built"]:
		text += "  호텔 건설"
	if int(data["salary_cards"]) > 0:
		text += "  [미니카] 반환점 통과: 카드 %d장" % data["salary_cards"]
	if data["drawn_card"] != &"":
		text += "  [빵집] 카드 획득"
	if not (data["effects"] as Array).is_empty():
		text += "  교칙 효과 %s" % str(data["effects"])
	_log_line(text, PLAYER_COLORS[state.get_pawn(pawn_id).owner_id])


func _log_line(text: String, color: Color) -> void:
	text = L10n.t(text)
	if _log == null:
		return
	if text.is_empty():
		return
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	# 메모리 보호: 디버그 전체 로그도 오래된 줄부터 버린다 (RichTextLabel은 지우지 않으면 끝없이 커진다)
	while _log.get_paragraph_count() > DEBUG_LOG_LINES:
		_log.remove_paragraph(0)
	# 상단 리본의 토스트: 가장 최근 이벤트 한 줄 요약
	if _toast_label != null:
		_toast_label.text = text
		_toast_label.add_theme_color_override("font_color", color.lightened(0.25))


func _pawn_name(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return "말#%d" % pawn_id
	return "P%d-말%d" % [pawn.owner_id, pawn.slot]


# ---------------------------------------------------------------------------
# 액션 로그: 누가 무엇을 했는지 (굴림·카드·방어·함정·처치·필살기·증강·법전)
# ---------------------------------------------------------------------------

func _build_action_log() -> void:
	_action_log = ActionLogPanel.new()
	add_child(_action_log)
	_action_log.place(ACTION_LOG_POS)


## BBCode에 넣을 글자: 대괄호가 태그로 읽히지 않게 바꾼다.
func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


## [이름] 꼴로 감싼다.
func _bq(text: String) -> String:
	if text.begins_with("["):
		return _bb(text)  # 이미 [분류] 이름 꼴이면 괄호를 겹치지 않는다
	return "[lb]%s]" % _bb(text)


## 🟦 컴퓨터 2 (플레이어 색).
func _log_who(player_id: int) -> String:
	if not PLAYER_COLORS.has(player_id):
		return "[color=#ced4da]중립[/color]"
	return "%s [color=#%s]%s[/color]" % [PLAYER_MARKS.get(player_id, ""), (PLAYER_COLORS[player_id] as Color).lightened(0.3).to_html(false), _bb(_player_name(player_id))]


## 액션 로그의 ──── N라운드 ──── 구분선: 그 라운드의 어떤 줄보다 먼저, 한 번만 적는다.
## 엔진은 라운드 시작 -> 템포 업 -> 증강 드래프트 순서지만, 화면의 증강 기록은 [선택한 증강] 공개 때(연출 큐) 적히므로
## 구분선을 라운드 알림 때 바로 적으면 증강 기록이 구분선 위아래로 갈라져 보였다.
func _log_round_divider(round_number: int) -> void:
	if _action_log == null or round_number <= _divider_round:
		return
	_divider_round = round_number
	_action_log.add_entry("[color=#ffd43b]──── %d라운드 ────[/color]" % round_number)


## 액션 로그 한 줄: [R3] 🟦 컴퓨터 2 : 내용 (player_id가 -1이면 이름 없이).
## 연출을 켠 화면에서는 연출 큐를 따라 그 장면이 나올 때 적는다 (결과를 먼저 흘리지 않는다). late는 사출처럼 맨 뒤 연출과 함께 적는다.
## now: 연출 큐의 한 단계 안에서 부를 때 (그 연출과 같은 순간에 바로 적는다).
func _record(player_id: int, text: String, tag: String = "", late: bool = false, now: bool = false) -> void:
	if _action_log == null or state == null:
		return
	var round_tag: String = "[color=#868e96][lb]R%d%s][/color]" % [state.round_number, (" " + tag) if tag != "" else ""]
	var line: String = "%s %s : %s" % [round_tag, _log_who(player_id), text] if player_id >= 1 else "%s %s" % [round_tag, text]
	var log_panel: ActionLogPanel = _action_log
	var round_number: int = state.round_number
	var add: Callable = func() -> void:
		if is_instance_valid(log_panel):
			_log_round_divider(round_number)  # 그 라운드의 첫 줄보다 구분선이 먼저 (증강 공개는 라운드 알림보다 늦게 적힌다)
			log_panel.add_entry(line)
	if not _fx_on() or now:
		add.call()
	elif late:
		_enqueue_late(add)
	else:
		enqueue_step(add)


func _record_roll(data: Dictionary) -> void:
	var result: Dictionary = data["result"]
	if bool(result.get("can_continue", false)):
		return  # 이어지는 굴림(룰렛 생존·야추 다시 굴리기)은 최종 결과만 적는다
	var player_id: int = int(data["player_id"])
	_record(player_id, "%s 굴림 → %s" % [_bq(state.tools[player_id].display_name), _bb(_roll_text(data))])


func _record_card(data: Dictionary) -> void:
	var player_id: int = int(data["player_id"])
	var card: BaseCard = CardRegistry.get_card(data["card_id"])
	var params: Dictionary = data.get("params", {})
	if bool(data.get("counter", false)):
		var entry: Dictionary = state.get_attack(int(params.get("attack", -1)))
		_record(player_id, "방어 %s 발동! → %s을(를) 받아침" % [_bq(card.display_name), _bb(_attack_text(entry)) if entry.has("kind") else "공격"])
		return
	if card.category == GameEnums.CardCategory.TRAP:
		if card.corner_only:
			_record(player_id, "코너 함정 %s 설치! (%d번 코너)" % [_bq(card.display_name), int(params.get("tile", -1))])
		else:
			_record(player_id, "은신 함정 설치!")  # 은신 함정은 종류도 위치도 남기지 않는다
		return
	var detail: String = ""
	if params.has("target_player"):
		detail = " → %s" % _log_who(int(params["target_player"]))
	elif params.has("tile"):
		detail = " (%d번 타일)" % int(params["tile"])
	_record(player_id, "%s 사용!%s" % [_bq(card.display_name), detail])


## 말이 출발선으로 날아갔다: 다른 사람이 보냈으면 처치, 아니면 사출.
## now: 처치 연출 단계 안에서 부르면 그 순간 바로 적는다 (아니면 이동 연출이 끝난 뒤로 미룬다).
func _record_ejection(pawn_id: int, by_player: int, now: bool = false) -> void:
	var victim: PlayerPawn = state.get_pawn(pawn_id)
	if victim == null:
		return
	var label: String = _bq("%d번 말" % victim.slot)
	if _player_ids.has(by_player) and by_player != victim.owner_id:
		_record(by_player, "%s의 %s 처치!" % [_log_who(victim.owner_id), label], "", true, now)
	else:
		_record(victim.owner_id, "%s이(가) 출발선으로 사출" % label, "", true, now)


func _card_name(card_id: StringName) -> String:
	var card: BaseCard = CardRegistry.get_card(card_id)
	return card.display_name if card != null else str(card_id)


func _attachment_name(attachment_id: String) -> String:
	match attachment_id:
		"TRP_01": return "거울의 힘"
		"TRP_02": return "나락"
		"TRP_03": return "지뢰"
		"TRP_05": return "도미노 연쇄"
		"TRP_06": return "바나나 껍질"
		"TRP_07": return "스파이크"
		"TRP_08": return "강제 환승 포탈"
		"TRP_C01": return "무인도"
		"TRP_C02": return "우이의 소원빌기"
		"TRP_C03": return "지나가는 상인"
		"TRP_C04": return "물의 세례를 받아라"
		"HOTEL": return "호텔"
	return attachment_id


## 주사위·판정 도구 결과를 보드 한가운데에 큼직하게 띄웠다가 서서히 사라지게 한다.
func _show_center_banner(text: String, color: Color) -> void:
	if _center_banner == null:
		return
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_banner.reset_size()
	_center_banner.position = _board_center() - _center_banner.size / 2.0
	_center_banner.modulate = Color.WHITE
	_center_banner.visible = true
	if _center_banner.has_meta("fade"):
		var previous: Tween = _center_banner.get_meta("fade")
		if previous != null and previous.is_valid():
			previous.kill()
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_center_banner, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void: _center_banner.visible = false)
	_center_banner.set_meta("fade", tween)


## 굴림 결과 띠를 바로 걷는다: 중앙 알림 카드가 뜨면 같은 자리에 문구 두 개가 겹치지 않게 한다 (이동 실패·친치로 삐끗·한 번 더 등).
func _dismiss_center_banner() -> void:
	if _center_banner == null or not _center_banner.visible:
		return
	if _center_banner.has_meta("fade"):
		var previous: Tween = _center_banner.get_meta("fade")
		if previous != null and previous.is_valid():
			previous.kill()
	_center_banner.visible = false


## 파워 게이지(굴림 버튼 위)와 판정 도구 연출기를 만든다.
func _build_roll_fx() -> void:
	_build_tool_stages()
	_danger_label = _make_label("▲ 위험! 라운드 종료 시 NPC에게 잡힙니다!", 22, Color("ff3b30"))
	_danger_label.name = "DangerWarning"
	_danger_label.position = Vector2(283.0, 78.0)
	_danger_label.size = Vector2(800.0, 34.0)
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.add_theme_constant_override("outline_size", 8)
	_danger_label.add_theme_color_override("font_outline_color", Color("2b0000"))
	_danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_label.z_index = 20
	_danger_label.visible = false
	add_child(_danger_label)
	_presenter = RollPresenter.new()
	add_child(_presenter)
	_draw_fx = CardDrawFX.new()
	_draw_fx.name = "CardDrawFX"
	_draw_fx.z_index = 30
	_draw_fx.face_builder = _make_card_face
	_draw_fx.landed.connect(_on_drawn_card_landed)
	_draw_fx.drained.connect(_refresh_all)
	add_child(_draw_fx)
	_layout_card_deck()
	_super_fx = SuperFX.new(self)
	_announcer = EventAnnouncer.new()
	add_child(_announcer)
	_announcer.drained.connect(func() -> void:
		if state != null:
			_fx_gate_open = false
			_fx_gates.clear()
			_fx_after_announcer()
			_refresh_all())
	_announcer.entry_finished.connect(_on_announcer_entry_finished)
	_announcer.entry_started.connect(func(_serial: int) -> void:
		_dismiss_center_banner()
		var entry_tag: String = str(_announcer._current.get("tag", ""))
		if entry_tag == ATTACK_TAG and _fx_on():
			Sfx.play(&"attack_alert")
			screen_shake(10.0, 0.3)
		elif entry_tag == "함정 설치" and _fx_on():
			Sfx.play(&"trap_hidden"))


## 야추·블랙잭·핀볼의 중앙 오픈 스테이지를 만든다. 눈에 보이는 건 해당 도구를 쓰는 차례뿐이다.
func _build_tool_stages() -> void:
	_stage_yacht = YachtStage.new()
	_stage_yacht.position = Vector2(683.0, 335.0) - YachtStage.STAGE_SIZE / 2.0
	_stage_yacht.visible = false
	_stage_yacht.z_index = 5
	_stage_yacht.start_pressed.connect(_on_stage_start)
	_stage_yacht.reroll_pressed.connect(_on_yacht_reroll)
	_stage_yacht.confirm_pressed.connect(_on_stage_stand)
	add_child(_stage_yacht)
	_stage_blackjack = BlackjackStage.new()
	_stage_blackjack.position = Vector2(683.0, 335.0) - BlackjackStage.STAGE_SIZE / 2.0
	_stage_blackjack.visible = false
	_stage_blackjack.z_index = 5
	_stage_blackjack.start_pressed.connect(_on_stage_start)
	_stage_blackjack.hit_pressed.connect(_on_blackjack_hit)
	_stage_blackjack.stand_pressed.connect(_on_stage_stand)
	add_child(_stage_blackjack)
	_stage_pinball = PinballStage.new()
	_stage_pinball.position = Vector2(683.0, 335.0) - PinballStage.STAGE_SIZE / 2.0
	_stage_pinball.visible = false
	_stage_pinball.z_index = 5
	add_child(_stage_pinball)


## 굴림 결과 연출기(리볼버·룰렛·주사위 투척 등)가 아직 화면에 남아 있는가.
func _presenter_showing() -> bool:
	return _presenter != null and _presenter.visible


## 지금 차례가 아닌 사람의 굴림 연출이 아직 화면에 있는가: 결과 연출기, 또는 내 차례가 끝난 뒤에도 마저 도는 내 리볼버·룰렛 패드.
func _foreign_roll_fx() -> bool:
	return _presenter_showing() or (_roll_pad != null and _roll_pad.active and manager.current_player_id() != _dock_owner())


## 이 도구의 중앙 스테이지 (야추·블랙잭·핀볼이 아니면 null).
func _stage_for(tool_id: StringName) -> Control:
	match tool_id:
		&"DICE_YACHT": return _stage_yacht
		&"DICE_BLACKJACK": return _stage_blackjack
		&"DICE_PINBALL": return _stage_pinball
	return null


func _is_stage_tool(tool_id: StringName) -> bool:
	return tool_id == &"DICE_YACHT" or tool_id == &"DICE_BLACKJACK" or tool_id == &"DICE_PINBALL"


## 지금 굴리는 사람의 도구에 맞는 스테이지만 보여 주고 엔진 상태에 맞춘다 (남의 차례에도 굴리는 모습이 보인다).
func _refresh_tool_stage() -> void:
	var current: int = manager.current_player_id()
	var tool: BaseJudgmentTool = state.tools[current]
	var stage: Control = _stage_for(tool.tool_id)
	for other: Control in [_stage_yacht, _stage_blackjack, _stage_pinball]:
		if other != null and other != stage and not other.get("active"):
			other.visible = false
	if stage == null:
		return
	var turn_key: String = "%d:%d:%s" % [state.round_number, current, tool.tool_id]
	if turn_key != _stage_turn_key and not tool.has_pending_state() and not bool(stage.get("active")):
		_stage_turn_key = turn_key
		stage.call("reset")
	# 굴리기 화면은 앞선 연출이 다 끝난 뒤에만 뜬다. 이미 굴리는 중(연출·야추 중간 상태)이면 그대로 둔다.
	var in_roll: bool = _roll_view_allowed()
	# 굴림 연출(_fx_busy)이 다른 도구의 연출기(_presenter)라면 앞 사람의 굴림이다: 이 스테이지를 그 위에 겹쳐 띄우지 않는다.
	var mid_roll: bool = (_fx_busy and not _foreign_roll_fx()) or bool(stage.get("active")) or (tool.has_pending_state() and not (_announcer != null and _announcer.holding()))
	stage.set("instant", instant_roll_for_test)
	stage.visible = in_roll or mid_roll
	var acting: bool = not _roll_button.disabled
	if stage == _stage_pinball:
		_stage_pinball.set_waiting_caption(_is_bot_turn() or (net != null and current != local_player_id), _player_name(current))
	if stage == _stage_yacht:
		_stage_yacht.sync(tool as ToolYacht, acting)
	elif stage == _stage_blackjack:
		_stage_blackjack.sync(tool as ToolBlackjack, acting)


func _on_stage_start() -> void:
	_roll_with_power(0.5)


func _on_yacht_reroll(keep: Array) -> void:
	if manager.is_game_over or _ui_busy() or _is_bot_turn() or manager.current_state != TurnManager.State.PHASE_ROLL_WAIT:
		return
	Sfx.play(&"dice_roll")
	_act(&"roll", {"keep": keep})


func _on_blackjack_hit() -> void:
	if manager.is_game_over or _ui_busy() or _is_bot_turn() or manager.current_state != TurnManager.State.PHASE_ROLL_WAIT:
		return
	Sfx.play(&"card_get")
	_act(&"roll")


## 야추의 [현재 족보로 이동 확정]과 블랙잭의 [스탠드].
func _on_stage_stand() -> void:
	if manager.is_game_over or _ui_busy() or _is_bot_turn() or manager.current_state != TurnManager.State.PHASE_ROLL_WAIT:
		return
	_act(&"stop")


## 엔진이 확정한 굴림 결과를 연출한 뒤 로그·중앙 배너로 공개한다. 연출 중에는 입력을 잠가 결과가 먼저 새지 않게 한다.
func _handle_roll_event(data: Dictionary) -> void:
	var result: Dictionary = data["result"]
	var tool_id: StringName = result["tool_id"]
	if _announcer != null:
		_announcer.dismiss_soft()  # 굴림이 시작되면 남아 있는 차례·라운드 안내 배너는 걷는다 (주사위와 겹치지 않게)
	_presenter.instant = instant_roll_for_test
	_presenter.toss_from = _profile_center(int(data["player_id"]))  # 기본 주사위·친치로·윷은 굴린 사람 프로필에서 마당으로 던진다
	var details: Dictionary = result["details"]
	if _is_stage_tool(tool_id):
		_handle_stage_roll(data)
		return
	# Stopping is a cash-out, not another trigger pull or cylinder advance.
	if tool_id == &"REVOLVER" and bool(details.get("voluntary",false)):
		_fx_serial += 1
		_roll_pad.cancel_spin()
		_presenter.cancel()
		_fx_busy = false
		_roll_pad.reset_revolver()
		_reveal_roll(data)
		_refresh_all()
		return
	# A quick second pull must not be covered by the previous safe-result banner.
	if _center_banner != null:
		_center_banner.hide()
		if _center_banner.has_meta("fade"):
			var fade: Tween = _center_banner.get_meta("fade")
			if fade != null and fade.is_valid(): fade.kill()
	var on_pad: bool = int(data["player_id"]) == _dock_owner() and ((tool_id == &"LIFE_ROULETTE" and _roll_pad.kind == RollPad.Kind.ROULETTE) or (tool_id == &"REVOLVER" and _roll_pad.kind == RollPad.Kind.REVOLVER))
	if on_pad and not instant_roll_for_test:
		var pad_generation: int = _fx_generation
		_fx_serial += 1
		var pad_serial: int = _fx_serial
		_fx_busy = true
		_refresh_controls()
		if tool_id == &"LIFE_ROULETTE":
			await _roll_pad.play_spin(int(details["face"]), _pending_power)
		else:
			await _roll_pad.play_trigger(bool(details["fired"]),int(details.get("accumulated",0)),int(details.get("lost",0)),bool(result.get("can_continue",false)))
		if pad_generation != _fx_generation or pad_serial != _fx_serial:
			return
		_fx_busy = false
		_reveal_roll(data)
		_refresh_all()
		return
	if on_pad:
		if tool_id == &"LIFE_ROULETTE":
			_roll_pad.play_spin(int(details["face"]), _pending_power)
		else:
			_roll_pad.play_trigger(bool(details["fired"]),int(details.get("accumulated",0)),int(details.get("lost",0)),bool(result.get("can_continue",false)))
	if instant_roll_for_test or not RollPresenter.supports(tool_id):
		_reveal_roll(data)
		return
	var generation: int = _fx_generation
	_fx_serial += 1
	var serial: int = _fx_serial
	_fx_busy = true
	_refresh_controls()
	_presenter.hold_owner = int(data["player_id"])
	await _presenter.play(tool_id, result, _pending_power)
	if generation != _fx_generation or serial != _fx_serial:
		return
	_fx_busy = false
	_reveal_roll(data)
	_refresh_all()


## 야추·블랙잭·핀볼: 중앙 스테이지가 결과를 연출한 뒤(테스트에서는 즉시) 로그·배너로 공개한다.
func _handle_stage_roll(data: Dictionary) -> void:
	var result: Dictionary = data["result"]
	var tool_id: StringName = result["tool_id"]
	var stage: Control = _stage_for(tool_id)
	if _center_banner != null:
		_center_banner.hide()
	stage.visible = true
	stage.set("instant", instant_roll_for_test)
	if instant_roll_for_test:
		_play_stage(stage, tool_id, result)
		_reveal_roll(data)
		return
	var generation: int = _fx_generation
	_fx_serial += 1
	var serial: int = _fx_serial
	_fx_busy = true
	_refresh_controls()
	await _play_stage(stage, tool_id, result)
	if generation != _fx_generation or serial != _fx_serial:
		return
	_fx_busy = false
	_reveal_roll(data)
	_refresh_all()


func _play_stage(stage: Control, tool_id: StringName, result: Dictionary) -> void:
	if tool_id == &"DICE_PINBALL":
		await (stage as PinballStage).play(result, _pending_power)
	elif tool_id == &"DICE_YACHT":
		await (stage as YachtStage).play(result)
	else:
		await (stage as BlackjackStage).play(result)


## 블랙잭 버스트: 이동 없이 턴이 끝난다. 결과 카드를 0.9초 보여 주고 프로필이 피격 반응을 한다.
func _announce_bust(player_id: int, total: int) -> void:
	_profile_react(player_id, false)
	_announce("블랙잭", "[BUST! (21 초과 - 0칸 이동 실패)]", "카드 합계 %d" % total, Color("ff6b6b"), null, 0.9)
	_start_beat(0.9)


## 이동 실패 알림: 결과 카드를 0.9초 보여 주고 프로필이 피격 반응을 한다. 알림이 떠 있는 동안 입력과 봇 행동은 멈춰 있어 다음 차례가 먼저 시작되지 않는다.
func _announce_move_failed(headline: String, player_id: int, body: String = "") -> void:
	_profile_react(player_id, false)
	_announce("이동 실패", "[%s 이번 턴 이동 실패!]" % headline, body, Color("ff6b6b"), null, 0.9)
	_start_beat(0.9)


func _reveal_roll(data: Dictionary) -> void:
	_show_gambler_flash(int(data["player_id"]),(data["result"] as Dictionary).get("tool_id",&""))
	var roll_text: String = _log_roll(data)
	var details: Dictionary = (data["result"] as Dictionary)["details"]
	var fired: bool = bool(details.get("fired", false))
	var roller: int = int(data["player_id"])
	var roll_steps: int = int((data["result"] as Dictionary).get("steps", 0))
	var roll_tool: StringName = (data["result"] as Dictionary).get("tool_id", &"")
	if bool(details.get("oops", false)):
		_profile_react(roller, false)
	elif (roll_tool == &"SLOT_777" and roll_steps >= 20) or (roll_tool == &"DICE_MAHJONG" and roll_steps >= 12) or (roll_tool == &"HOLDEM" and roll_steps >= 15):
		_profile_react(roller, true)
	if _is_stage_tool(roll_tool):
		# 진행 중인 굴림(야추 다시 굴리기·블랙잭 히트)은 스테이지가 보여 주므로 중앙 배너를 띄우지 않는다.
		if bool((data["result"] as Dictionary).get("can_continue", false)):
			return
		if bool(details.get("bust", false)):
			_announce_bust(roller, int(details["total"]))
			return
		_show_center_banner("P%d  %s" % [data["player_id"], roll_text.strip_edges()], Color("ffd43b") if bool((data["result"] as Dictionary).get("reroll", false)) else Color("fff3bf"))
		return
	if bool((data["result"] as Dictionary).get("can_continue", false)):
		return  # 이어지는 굴림(러시안 룰렛 생존 등)은 패드가 누적을 보여 준다: 이동 칸수는 최종 결과가 나온 뒤 한 번만 띄운다
	if bool(details.get("oops", false)):
		_announce("지하노역장 친치로", "[친치로 삐끗!]", "주사위가 접시 밖으로 나갔습니다! (이번 이동 0칸)", Color("ff6b6b"), null, 1.3)
		return
	if bool((data["result"] as Dictionary).get("ends_turn", false)):
		# 이동 없이 턴이 끝나는 굴림(러시안 룰렛 실탄·화투 망통): 결과 알림과 피격 반응을 충분히 보여 준 뒤에야 다음 차례로 넘어간다.
		# 굴림 결과 띠와 실패 카드가 같은 말을 두 번 하지 않게, 결과 문구는 실패 카드 본문에만 싣는다.
		var fail_name: String = "폭죽 깃발!" if fired else ("낙!" if roll_tool == &"YUT" else ("광대!" if roll_tool == &"DICE_TAROT" else "망통!"))
		_announce_move_failed(fail_name, roller, "P%d  %s" % [roller, roll_text.strip_edges()])
		return
	if _presenter.tossing and not instant_roll_for_test and RollPresenter.TOSS_TOOLS.has(roll_tool):
		return  # 보드 위로 던진 주사위·윷이 바로 위에 "N칸 전진!"을 띄웠다: 같은 말을 띠로 또 하지 않는다
	_show_center_banner("P%d  %s" % [data["player_id"], roll_text.strip_edges()], Color("ff8787") if fired else Color("fff3bf"))


## 프로필 카드 한가운데의 화면 좌표 (투척·카드 비행의 출발·도착점). 프로필이 없으면 INF.
func _profile_center(player_id: int) -> Vector2:
	if not _profiles.has(player_id):
		return Vector2(INF, INF)
	var panel: Control = _profiles[player_id]["panel"]
	if not panel.is_visible_in_tree():
		return Vector2(INF, INF)
	return panel.get_global_rect().get_center()


## 윷놀이 기물의 [선택적 업기] 팝업: 화면 중앙에 [업기 (하나로 합체)] / [그냥 두기 (개별 유지)] 두 버튼을 띄운다.
func _refresh_stack_overlay() -> void:
	# 고르는 사람의 화면에만 띄운다 (컴퓨터는 봇이 정하고, 온라인은 그 사람 화면에만).
	var mine: bool = not _is_bot_turn() and (net == null or manager.current_player_id() == local_player_id)
	var pending: bool = manager.stack_offer_pending() and not manager.is_game_over and mine
	if not pending:
		_close_stack_overlay()
		return
	if _stack_overlay != null:
		return
	# 함정 발동 같은 알림 카드·연출이 끝난 뒤에 띄운다 (알림이 선택 창 제목을 가리지 않게). _process가 프레임마다 다시 확인한다.
	if (_announcer != null and _announcer.holding()) or _presentation_active() or _fx_busy:
		return
	var offer: Dictionary = manager.pending_stack_offer()
	var mover: PlayerPawn = state.get_pawn(int(offer["mover"]))
	var names: Array[String] = []
	for other_id: Variant in offer["others"]:
		names.append(state.get_pawn(int(other_id)).display_label())
	_stack_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stack_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("131826"), COLOR_GOLD, 4, 18, 26, 20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _make_label("아군 말 합류 - 업기", 20, COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := _make_label("%s이(가) 아군 [%s]와(과) 같은 타일에 도착했습니다.\n하나로 합체할까요?" % [mover.display_label(), ", ".join(names)], 14, Color("dee2e6"))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var stack_button: Button = _make_button("[업기 (하나로 합체)]", _on_stack_choice.bind(true), 16, Color("2b8a3e"), 12)
	stack_button.custom_minimum_size = Vector2(230, 48)
	buttons.add_child(stack_button)
	var keep_button: Button = _make_button("[그냥 두기 (개별 유지)]", _on_stack_choice.bind(false), 16, Color("495057"), 12)
	keep_button.custom_minimum_size = Vector2(230, 48)
	buttons.add_child(keep_button)
	add_child(_stack_overlay)


func _on_stack_choice(stack: bool) -> void:
	_close_stack_overlay()
	_act(&"stack_choice", {"stack": stack})


func _close_stack_overlay() -> void:
	if _stack_overlay != null:
		_stack_overlay.queue_free()
		_stack_overlay = null


## 메뉴에 들어갈 버튼들을 만든다 (모드 전환·새 게임·치트·전체 로그는 이 오버레이 안에서만 보인다).
func _build_menu() -> void:
	_mode_toggle = _make_button("", _on_mode_toggle_pressed, 13, Color("2f5d50"), 8)
	_mode_toggle.tooltip_text = "AI 대전: 내 자리만 직접 조작하고 나머지는 봇이 플레이합니다. 4P 수동 조작: 한 화면에서 모두 직접 조작합니다."
	_refresh_mode_toggle()
	# 메뉴 항목을 누르면 메뉴를 닫는다 (모드 전환은 문구만 바뀌므로 열어 둔다).
	_new_game_button.pressed.connect(_close_menu)
	_debug_toggle.pressed.connect(_close_menu)
	_log_toggle.pressed.connect(_close_menu)


func _menu_is_open() -> bool:
	return _menu_overlay != null


func _toggle_menu() -> void:
	if not _accept_tap(&"menu"):
		return
	if _menu_is_open():
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	if _menu_is_open():
		return
	_cancel_aim()
	_cancel_tile_pick()
	_menu_overlay = _new_overlay(0.6)
	_menu_overlay.z_index = 200
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	UiSkin.bind_light_text(panel)
	center.add_child(panel)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 10)
	_menu_box.custom_minimum_size = Vector2(440 if MobileSupport.touch_mode() else 380, 0)
	panel.add_child(_menu_box)
	add_child(_menu_overlay)
	_show_menu_page(&"main")


func _close_menu() -> void:
	if _menu_overlay == null:
		return
	_release_menu_buttons()
	_menu_overlay.queue_free()
	_menu_overlay = null
	_menu_box = null


## 오래 쓰는 버튼(새 게임·모드·치트·로그)은 지우지 않고 메뉴에서 떼어 둔다.
func _release_menu_buttons() -> void:
	if _menu_box == null:
		return
	for child: Node in _menu_box.get_children():
		_menu_box.remove_child(child)
		if not [_new_game_button, _mode_toggle, _debug_toggle, _log_toggle].has(child):
			child.queue_free()


func _menu_item(item: Button, font_size: int = 17) -> void:
	var touch: bool = MobileSupport.touch_mode()
	item.custom_minimum_size = Vector2(440, 64) if touch else Vector2(380, 46)  # 폰에서는 메뉴 항목을 크게 (화면이 약 0.5배로 줄어 보인다)
	item.add_theme_font_size_override("font_size", font_size + (4 if touch else 0))
	if touch:
		MobileSupport.touch_button(item, 64.0)
	_menu_box.add_child(item)


func _menu_title(text: String) -> void:
	var title: Label = _make_label(text, 26, COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(title)
	UiSkin.title(title)


func _show_menu_page(page: StringName) -> void:
	_release_menu_buttons()
	_menu_page = page
	match page:
		&"settings": _build_settings_page()
		&"confirm_exit": _build_exit_page()
		_: _build_main_page()


func _build_main_page() -> void:
	_menu_title(tr_ui("menu.title"))
	_menu_item(_make_button(tr_ui("menu.continue"), _close_menu, 17, Color("2b8a3e"), 10))
	_menu_item(_make_button(tr_ui("menu.settings"), _show_menu_page.bind(&"settings"), 17, Color("3b4766"), 10))
	_menu_item(_make_button(tr_ui("menu.rulebook"), _open_rulebook, 17, Color("8a5a0a"), 10))
	# 전체 로그·새 게임·모드 전환은 개발용이라 디버그를 켰을 때만 메뉴에 나온다 (평소엔 게임답게 숨긴다).
	if _debug_enabled:
		_menu_item(_log_toggle)
		if net == null:
			_menu_item(_new_game_button)
			_menu_item(_mode_toggle)
			_menu_item(_debug_toggle)
	_menu_item(_make_button(tr_ui("menu.exit"), _show_menu_page.bind(&"confirm_exit"), 17, Color("7a2a2a"), 10))


## 메뉴의 [규칙 책자]: 게임 위(메뉴보다 위)에 규칙 책자를 연다.
func _open_rulebook() -> void:
	var book: Rulebook = Rulebook.open(self)
	book.z_index = 250


func _build_settings_page() -> void:
	_menu_title(tr_ui("menu.settings"))
	LobbyTheme.add_settings_controls(_menu_box, LobbyTheme.INK)
	if net == null:
		var timer := CheckButton.new()
		timer.name = "TimerCheck"
		timer.text = "제한 시간 (시간이 지나면 자동 진행)"
		LobbyTheme.style_switch(timer, LobbyTheme.INK)
		timer.button_pressed = _timer_check != null and _timer_check.button_pressed
		timer.toggled.connect(_on_menu_timer_toggled)
		_menu_box.add_child(timer)
	else:
		var note: Label = _make_label("온라인 대전은 제한 시간이 항상 켜져 있습니다 (3배 길게).", 12, Color("868e96"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_menu_box.add_child(note)
	var reset: Button = _make_button(tr_ui("menu.reset"), _on_menu_reset_settings, 16, Color("495057"), 10)
	reset.name = "ResetSettings"
	_menu_item(reset)
	_menu_item(_make_button(tr_ui("menu.back"), _show_menu_page.bind(&"main"), 16, Color("4a3a66"), 10))


func _build_exit_page() -> void:
	_menu_title(tr_ui("menu.exit_title"))
	var note: Label = _make_label("나가면 시작 화면으로 돌아갑니다. 진행 중인 판은 저장되지 않으며, 온라인 대전이면 내 자리는 컴퓨터가 이어받습니다." if net != null else "나가면 시작 화면으로 돌아갑니다. 진행 중인 판은 저장되지 않습니다.", 14, Color("ced4da"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(note)
	_menu_item(_make_button(tr_ui("menu.exit_confirm"), _on_menu_pressed, 17, Color("7a2a2a"), 10))
	_menu_item(_make_button(tr_ui("btn.cancel"), _show_menu_page.bind(&"main"), 17, Color("3b4766"), 10))


## [배속] 버튼: 1x -> 2x -> 3x -> 1x. 혼자 하는 판에서만 바뀐다 (온라인은 모두가 같은 화면 속도를 보도록 1x 고정).
## 같은 버튼이 아주 짧은 시간(TAP_GUARD_MSEC) 안에 두 번 눌리면 두 번째는 무시한다 (터치 한 번이 두 번 들어오는 기기 대비: 배속이 두 칸씩 넘어가거나 메뉴가 열렸다 닫히지 않게).
const TAP_GUARD_MSEC: int = 300
var _last_tap_msec: Dictionary = {}


func _accept_tap(key: StringName) -> bool:
	if not MobileSupport.touch_mode():
		return true
	var now: int = Time.get_ticks_msec()
	if now - int(_last_tap_msec.get(key, -100000)) < TAP_GUARD_MSEC:
		return false
	_last_tap_msec[key] = now
	return true


func _on_speed_pressed() -> void:
	if net != null or not _accept_tap(&"speed"):
		return
	var speeds: Array[int] = GameSession.GAME_SPEEDS
	GameSession.game_speed = speeds[(speeds.find(GameSession.game_speed) + 1) % speeds.size()]
	GameSession.save_settings()
	_apply_game_speed()


## 배속을 엔진 전체에 건다: Engine.time_scale이 트윈·타이머·봇 대기·엔진 걸음을 함께 줄이고, 밀리초로 잡은 연출 잠금은 _msec_from_now가 맞춘다.
## 제한 시간은 TurnManager가 실제 초로 센다.
func _apply_game_speed() -> void:
	Engine.time_scale = 1.0 if net != null else float(GameSession.game_speed)
	_refresh_speed_button()


func _refresh_speed_button() -> void:
	if _speed_button == null:
		return
	var speed: int = 1 if net != null else GameSession.game_speed
	_speed_button.text = tr_ui("btn.speed", [speed])
	_speed_button.tooltip_text = tr_ui("btn.speed_online_tip") if net != null else tr_ui("btn.speed_tip")
	_speed_button.disabled = net != null
	_speed_button.modulate = Color(1.0, 0.92, 0.6) if speed > 1 else Color.WHITE


## 피드백 창을 연다 (상단 버튼 / 결과 화면). 이미 열려 있으면 그 창을 둔다.
func _open_feedback(from: String = "", initial_kind: FeedbackModal.Kind = FeedbackModal.Kind.BUG) -> FeedbackModal:
	var existing: Node = find_child("FeedbackModal", false, false)
	if existing != null and not existing.is_queued_for_deletion():
		return existing as FeedbackModal
	return FeedbackModal.open(self, _build_diagnostic_snapshot, from, initial_kind)


const SNAPSHOT_LOG_LINES: int = 15
static var _bbcode_tags: RegEx = null


## 개발자가 바로 재현할 수 있게 지금 판을 글로 요약한다: 진행 정보 / 사람별 완주·기물·도구·손패·증강 / 법전과 달성 정도 / 최근 액션 로그 15줄.
func _build_diagnostic_snapshot() -> String:
	if state == null or manager == null:
		return "(게임 상태 없음)"
	var lines: PackedStringArray = []
	var seconds: int = maxi(int((Time.get_ticks_msec() - _game_started_msec) / 1000.0), 0)
	var mode: String = "온라인" if net != null else ("AI 대전" if ai_mode else "핫시트")
	lines.append("[게임 스냅샷] 버전 %s · %s · 시드 %d · 언어 %s" % [GameSession.version(), mode, _game_seed, L10n.language_label()])
	var phase: String = _phase_name(manager.current_state) if not manager.is_game_over else "게임 종료"
	lines.append("라운드 %d (%s) · 템포 업 %d단계 · 현재 턴: %s · 플레이 타임 %02d:%02d" % [state.round_number, phase, TempoUp.level(state.round_number), _player_name(manager.current_player_id()), seconds / 60, seconds % 60])
	lines.append("-- 플레이어 --")
	for player_id: int in _player_ids:
		var rank_text: String = ""
		if state.rankings.has(player_id):
			rank_text = " [%d위 · %s]" % [state.rankings.find(player_id) + 1, VictoryChecker.short_reason(state.rank_reasons.get(player_id, &""))]
		var pawn_texts: PackedStringArray = []
		for pawn: PlayerPawn in state.pawns_of(player_id):
			var where: String = "완주" if pawn.is_finished else ("대기" if not pawn.has_left_start else "%d번" % pawn.current_tile_idx)
			pawn_texts.append("%d:%s(%s%s)" % [pawn.slot, pawn.display_label(), where, ",필살기 씀" if pawn.skill_used else ""])
		var tool: BaseJudgmentTool = state.tools.get(player_id)
		var picked: PackedStringArray = []
		for augment_id: Variant in manager.augments.get(player_id, []):
			var definition: AugmentDef = AugmentRegistry.get_def(augment_id)
			picked.append(definition.display_name if definition != null else str(augment_id))
		lines.append("P%d %s%s · 완주 %d/%d · 도구 %s · 손패 %d장" % [player_id, _player_name(player_id), rank_text, state.finished_count(player_id), GameEnums.PAWNS_PER_PLAYER, tool.display_name if tool != null else "-", (state.hands.get(player_id, []) as Array).size()])
		lines.append("   기물: %s" % ", ".join(pawn_texts))
		lines.append("   증강: %s" % (", ".join(picked) if not picked.is_empty() else "없음"))
	lines.append("-- 중앙 법전 --")
	if state.rulebook.active_laws_queue.is_empty():
		lines.append("(비어 있음)")
	for law: LawResource in state.rulebook.active_laws_queue:
		var victory: VictoryLaw = law as VictoryLaw
		if victory == null:
			lines.append("%s %s" % [law.law_id, law.law_name])
			continue
		var counts: PackedStringArray = []
		for player_id: int in _player_ids:
			counts.append("P%d %d/%d" % [player_id, victory.progress(state, player_id), victory.goal()])
		lines.append("%s %s: %s" % [law.law_id, law.law_name, " · ".join(counts)])
	lines.append("-- 최근 액션 로그 (%d줄) --" % SNAPSHOT_LOG_LINES)
	var recent: Array[String] = _action_log.lines() if _action_log != null else [] as Array[String]
	for entry: String in recent.slice(maxi(recent.size() - SNAPSHOT_LOG_LINES, 0)):
		lines.append(_plain_text(entry))
	return "\n".join(lines)


## BBCode 꾸밈을 지운 글자 (액션 로그 줄을 스냅샷에 옮길 때).
static func _plain_text(bbcode: String) -> String:
	if _bbcode_tags == null:
		_bbcode_tags = RegEx.create_from_string("\\[/?(color|b|i|u|s|font_size|bgcolor|outline_color|outline_size|url|center)(=[^\\]]*)?\\]")
	return _bbcode_tags.sub(bbcode, "", true).replace("[lb]", "[").replace("[rb]", "]")


func _on_menu_reset_settings() -> void:
	LobbyTheme.reset_settings()
	_show_menu_page(&"settings")


## 연출 속도 배율: 연출 멈춤이 켜져 있고 테스트용 즉시 모드가 아닐 때만 GameSession.pace_scale을 쓴다.
func _pace() -> float:
	if not pacing_enabled or instant_roll_for_test:
		return 1.0
	return GameSession.pace_scale * (TURBO_PACE_SCALE if _turbo_turn() else 1.0)


## 터보 AI 턴인가: 지금 차례가 AI(싱글의 컴퓨터 자리·온라인의 빈자리 봇)이고, 이번 턴에 주목할 장면(사람 말 처치·특수 승리·법전)이 없다.
func _turbo_turn() -> bool:
	if _spotlight_turn or manager == null or state == null or manager.is_game_over:
		return false
	var current: int = manager.current_player_id()
	if net != null:
		return net.is_bot(current)
	return ai_mode and _bot != null and _bot.is_bot(current)


## 처치 컷인 재생 빠르기: 터보 AI 턴(AI끼리의 처치)은 빠르게, 그 밖에는 보통.
func _cutin_speed() -> float:
	return minf(1.0 / TURBO_PACE_SCALE, 2.0) if _turbo_turn() else 1.0


## 이번 AI 턴을 주목 구간으로 돌린다 (그 턴의 남은 연출은 보통 속도). 다음 차례가 시작되면 풀린다.
func _mark_spotlight() -> void:
	_spotlight_turn = true


## 속도 설정이 바뀌면 걸음 간격·봇 대기에 바로 적용한다 (알림·호흡은 쓸 때마다 _pace()를 읽는다).
func _apply_pace() -> void:
	if manager != null:
		manager.step_delay_sec = MOVE_STEP_SECONDS if _pace() > 0.0 else 0.0
	if _bot != null:
		_bot.pace = 1.0


func _on_menu_timer_toggled(enabled: bool) -> void:
	if _timer_check != null:
		_timer_check.button_pressed = enabled  # 치트 서랍의 체크박스와 같은 값 (toggled 시그널이 manager.set_process를 켜고 끈다)


## 처음 화면(닉네임·모드 선택)으로 돌아간다.
## 온라인 대전을 설정한다: 매니저를 락스텝으로 돌리고, 방장만 봇을 돌린다.
func _setup_net() -> void:
	net = NetGame.new()
	net.name = "NetGame"
	add_child(net)
	net.setup(manager, GameSession.net_is_host, local_player_id, _player_ids, GameSession.net_bots, GameSession.net_names, GameSession.net_seed)
	_bot.bot_players.assign(GameSession.net_bots if net.is_host else [] as Array[int])
	if GameSession.net_autoplay:
		_bot.bot_players.append(local_player_id)
		_bot.wait_for_human_windows = false
	_bot.draft_waits_for_humans = false
	if GameSession.lobby_intent != &"quick":
		_bot.difficulty = int(GameSession.match_rules().get("bot_level", BotTemper.DEFAULT_LEVEL))  # 친선 방장이 고른 빈자리 컴퓨터 난이도
	_bot.enabled = _bot_active()
	net.started.connect(_on_net_started)
	net.seat_taken_over.connect(_on_net_seat_taken_over)
	net.desynced.connect(_on_net_desynced)
	net.connection_lost.connect(_on_net_connection_lost)
	net.peer_silent.connect(_on_net_peer_silent)
	net.emote_received.connect(_on_net_emote)


func _bot_active() -> bool:
	if net == null:
		return ai_mode
	return net.is_host or GameSession.net_autoplay


func _on_net_started(seed_value: int, players: Array, bots: Array) -> void:
	_game_seed = seed_value
	_player_ids.assign(players)
	if net.is_host:
		_bot.bot_players.assign(bots)
		if GameSession.net_autoplay:
			_bot.bot_players.append(local_player_id)
	_new_game()


func _on_net_seat_taken_over(seat: int) -> void:
	_log_line("[접속 끊김] %s 님이 나가 컴퓨터가 이어받습니다." % str(GameSession.net_names.get(seat, "P%d" % seat)), Color("ffa94d"))
	if net.is_host:
		_bot.bot_players.append(seat)
	if state != null:
		_refresh_all()


func _on_net_desynced(detail: String) -> void:
	push_warning("온라인 동기화 오류: %s" % detail)
	_log_line("[동기화 오류] %s" % detail, Color("ff6b6b"))


## 상대 화면이 멈췄을 때(다른 창·탭으로 이동했거나 연결이 느릴 때) 상단에 안내를 띄운다.
func _on_net_peer_silent(seat: int, silent: bool) -> void:
	_silent_seats[seat] = silent
	var names: Array[String] = []
	for silent_seat: int in _silent_seats.keys():
		if bool(_silent_seats[silent_seat]):
			names.append("방장" if silent_seat == 1 and not net.is_host else _player_name(silent_seat))
	if _net_status_label == null:
		_net_status_label = _make_label("", 14, Color("1a1d24"))
		_net_status_label.add_theme_stylebox_override("normal", _style(Color("ffd43b"), Color("fff3bf"), 2, 8, 0, 6))
		_net_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_net_status_label.position = Vector2(333, 46)
		_net_status_label.size = Vector2(700, 30)
		_net_status_label.z_index = 100
		add_child(_net_status_label)
	_net_status_label.visible = not names.is_empty()
	_net_status_label.text = "%s 화면이 멈춘 것 같습니다 (다른 창·탭·앱으로 이동했거나 연결이 느림). 돌아오면 자동으로 이어집니다." % ", ".join(names)


func _on_net_connection_lost(reason: String) -> void:
	if _net_lost_overlay != null:
		return
	_net_lost_overlay = _new_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_net_lost_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	UiSkin.bind_light_text(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(520, 0)
	panel.add_child(box)
	var title: Label = _make_label(reason, 22, Color("ff8787"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	box.add_child(_make_button("메뉴로 돌아가기", _on_menu_pressed, 20))
	add_child(_net_lost_overlay)


func _leave_net() -> void:
	if net != null:
		net.leave()
	GameSession.clear_net()


func _on_menu_pressed() -> void:
	_leave_net()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")


func _refresh_mode_toggle() -> void:
	_mode_toggle.text = "[모드: 1P vs 3AI 봇]" if ai_mode else "[모드: 4P 수동 조작]"
	_sync_race_end()


## AI 대전(혼자 하는 판)은 내가 졸업하는 즉시 끝낸다: 남은 컴퓨터는 레이스 진행 순서로 순위를 매긴다.
## 온라인·한 화면 4인 수동은 끝까지 진행한다.
func _sync_race_end() -> void:
	if manager == null:
		return
	manager.end_when_graduated.clear()
	manager.pacing_humans.clear()
	if net == null and ai_mode and not GameSession.net_active:
		manager.end_when_graduated.append(local_player_id)
		manager.pacing_humans.append(local_player_id)


func _on_mode_toggle_pressed() -> void:
	ai_mode = not ai_mode
	_bot.set_enabled(ai_mode)
	_dock_player = -1
	_log_line("[모드] %s" % ("1P vs 3AI 봇: P2~P4를 AI가 조작합니다." if ai_mode else "4P 수동 조작: 모든 플레이어를 직접 조작합니다."), Color("63e6be"))
	_refresh_mode_toggle()
	if manager != null and manager.state != null:
		_refresh_all()


## 이 자리가 컴퓨터(AI 대전의 봇·온라인의 빈자리 봇)인가.
func _is_computer_seat(player_id: int) -> bool:
	if net != null:
		return net.is_bot(player_id)
	return ai_mode and _bot != null and _bot.is_bot(player_id)


## 지금 턴이 AI 봇의 차례인가 (AI 모드에서 P2~P4).
func _is_bot_turn() -> bool:
	return ai_mode and manager.current_player_id() != local_player_id


## 사람(P1)이 지금 개입 창에서 낼 수 있는 카드를 들고 있는가.
func _human_can_intervene() -> bool:
	for card_id: StringName in state.hands[local_player_id]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card.category != GameEnums.CardCategory.COUNTER and card.is_playable_in(manager.current_state) and card.could_play(state, local_player_id):
			return true
	return false


## 봇은 화면의 굴림 연출이 끝날 때까지 기다린다.
func _bot_should_wait() -> bool:
	# 혼자 하는 판은 메뉴를 여는 동안 봇도 쉰다 (온라인은 다른 사람이 기다리므로 멈추지 않는다).
	return _ui_busy() or (net == null and _menu_is_open()) or (_duel_arena != null and _duel_arena.animating)


## 리벤지 부스터 표시: 아래쪽과 양옆에서 질감 있는 화염 그림이 제각각 일렁인다.
class RevengeFire extends Control:
	const TONGUES: int = 7

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t: float = Time.get_ticks_msec() / 1000.0
		var w: float = size.x
		var h: float = size.y
		for index: int in TONGUES:
			var phase: float = index * 1.7
			var x: float = w * (index + 0.5) / TONGUES
			var height: float = h * (0.32 + 0.18 * sin(t * 7.0 + phase) + 0.08 * sin(t * 13.0 + phase * 2.0))
			var half: float = w / TONGUES * 0.62
			var sway: float = half * 0.45 * sin(t * 5.0 + phase)
			_tongue(Vector2(x, h + 2.0), half, height, sway, Color(1.0, 0.36, 0.05, 0.78))
			_tongue(Vector2(x, h + 2.0), half * 0.55, height * 0.6, sway * 0.7, Color(1.0, 0.83, 0.25, 0.85))
		# 양옆 가장자리를 타고 오르는 작은 불꽃
		for side: int in 2:
			var edge_x: float = 3.0 if side == 0 else w - 3.0
			var flick: float = h * (0.45 + 0.15 * sin(t * 9.0 + side * 2.3))
			_tongue(Vector2(edge_x, h), 5.0, flick, 3.0 * sin(t * 6.0 + side), Color(1.0, 0.45, 0.08, 0.6))

	func _tongue(base: Vector2, half: float, height: float, sway: float, color: Color) -> void:
		PaintedFx.flame(self,base,Vector2(sway,-maxf(height,0.1)).normalized(),height,half,color,base.x*0.13+Time.get_ticks_msec()*0.006)


## 설치형 기물: 투명 호텔·지뢰 그림과 주인 색 받침. 코드 모형은 파일 누락 시에만 사용한다.
class BoardStructure extends Node2D:
	var kind: StringName = &"hotel"
	var color: Color = Color("ffd43b")
	const INK: Color = Color("2b2420")
	var artwork: Dictionary = {}

	func _ready() -> void:
		var filename: String = "MINE.png" if kind == &"mine" else "HOTEL.png"
		artwork = PawnArt.load_sprite(["res://assets/board/structures/" + filename])
		set_process(kind == &"mine")

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		_ellipse(Vector2(0, 2), Vector2(16, 6), Color(0, 0, 0, 0.28))
		if not artwork.is_empty():
			_draw_artwork()
			return
		if kind == &"mine":
			_draw_mine()
		else:
			_draw_hotel()

	func _draw_artwork() -> void:
		# The foundation stays independent of the neutral sprite so all four
		# owners remain identifiable without tinting roofs, windows or the lamp.
		_ellipse(Vector2(0, 2), Vector2(16, 5.5), color.darkened(0.5), INK)
		_ellipse(Vector2.ZERO, Vector2(16, 5), color, color.lightened(0.45))
		var region: Rect2 = artwork.region
		var bounds := Vector2(30, 27) if kind == &"mine" else Vector2(32, 40)
		var factor: float = minf(bounds.x / region.size.x, bounds.y / region.size.y)
		var size: Vector2 = region.size * factor
		var rect := Rect2(Vector2(-size.x / 2.0, -size.y), size)
		draw_texture_rect_region(artwork.texture, rect, region)
		if kind == &"mine":
			# Native image's red dome is 18% down from the visible silhouette.
			# Pulse its light only; the mine itself stays planted on the tile.
			var lamp := Vector2(0, -size.y * 0.82)
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
			_ellipse(lamp, Vector2(3.2, 2.1), Color(1.0, 0.12, 0.08, 0.18 * pulse))
			_ellipse(lamp, Vector2(1.4, 0.9), Color(1.0, 0.7, 0.5, 0.65 * pulse))

	func _draw_hotel() -> void:
		var front: Color = color.lightened(0.25)
		var side: Color = color.darkened(0.25)
		# 몸통: 앞면 + 오른쪽 옆면
		draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(5, 0), Vector2(5, -26), Vector2(-11, -26)]), front)
		draw_colored_polygon(PackedVector2Array([Vector2(5, 0), Vector2(13, -5), Vector2(13, -31), Vector2(5, -26)]), side)
		# 창문 (앞면 2열 x 3줄, 노란 불빛)
		for row: int in 3:
			for column: int in 2:
				var at := Vector2(-8 + column * 7, -22 + row * 7)
				draw_rect(Rect2(at, Vector2(4, 4)), Color("fff3bf"))
		# 지붕: 붉은 박공
		var roof := Color("e03131")
		draw_colored_polygon(PackedVector2Array([Vector2(-13, -26), Vector2(7, -26), Vector2(-3, -36)]), roof)
		draw_colored_polygon(PackedVector2Array([Vector2(7, -26), Vector2(15, -31), Vector2(5, -41), Vector2(-3, -36)]), roof.darkened(0.25))
		draw_polyline(PackedVector2Array([Vector2(-11, 0), Vector2(-11, -26), Vector2(-13, -26), Vector2(-3, -36), Vector2(5, -41), Vector2(15, -31), Vector2(13, -31), Vector2(13, -5), Vector2(5, 0), Vector2(-11, 0)]), INK, 1.2, true)
		draw_line(Vector2(5, 0), Vector2(5, -26), INK, 1.0, true)
		draw_line(Vector2(-13, -26), Vector2(7, -26), INK, 1.0, true)

	func _draw_mine() -> void:
		_ellipse(Vector2(0, 0), Vector2(12, 4.5), color, INK)
		var center := Vector2(0, -11)
		for index: int in 8:
			var direction := Vector2.RIGHT.rotated(TAU * index / 8.0)
			draw_line(center + direction * 8.0, center + direction * 13.0, INK, 2.5, true)
			draw_circle(center + direction * 13.0, 1.8, Color("495057"))
		draw_circle(center, 9.0, Color("343a40"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.25))
		var blink: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		draw_circle(center + Vector2(0, -9), 2.6, Color(1.0, 0.15, 0.1, 0.45 + 0.55 * blink))

	func _ellipse(center: Vector2, radii: Vector2, fill: Color, edge: Color = Color(0, 0, 0, 0)) -> void:
		var points := PackedVector2Array()
		for index: int in 24:
			var angle: float = TAU * index / 24.0
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		draw_colored_polygon(points, fill)
		if edge.a > 0.0:
			points.append(points[0])
			draw_polyline(points, edge, 1.2, true)


## 프로필 위에 찍히는 붓결·잉크 질감의 투명 상태 도장.
class StatusStamp extends Control:
	var kind: StringName = &"ban"
	var combined := false:
		set(value):
			if combined==value:
				return
			combined = value
			queue_redraw()
	const SKIP = preload("res://content_trickcal/illustrations/effects/profile_stamps/skip_painted.png")
	const SKIP_RING = preload("res://content_trickcal/illustrations/effects/profile_stamps/skip_ring_painted.png")
	const BAN = preload("res://content_trickcal/illustrations/effects/profile_stamps/ban_painted.png")
	const SKIP_REGION := Rect2(84.0/1254,89.0/1254,1092.0/1254,1076.0/1254)
	const BAN_REGION := Rect2(112.0/2172,105.0/724,1950.0/2172,507.0/724)

	func _ready() -> void:
		z_index = 3
		resized.connect(func() -> void:
			pivot_offset = size / 2.0
			queue_redraw())
		pivot_offset = size / 2.0

	## 위에서 크게 떨어져 쾅 찍힌다 (효과음과 짧은 화면 흔들림).
	func slam_in(board: MainBoard) -> void:
		scale = Vector2(2.6, 2.6)
		modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 1.0, 0.12)
		tween.chain().tween_callback(func() -> void:
			Sfx.play(&"slam", -3.0)
			board.screen_shake(5.0, 0.18))

	func _draw() -> void:
		var w: float = minf(size.x, size.y)
		if w <= 0.0:
			return
		var center: Vector2 = size / 2.0
		var skip: bool = kind==&"skip"
		var texture: Texture2D = SKIP if skip else BAN
		var normalized: Rect2 = SKIP_REGION if skip else BAN_REGION
		if combined and skip:
			texture = SKIP_RING
		var region := Rect2(normalized.position*texture.get_size(),normalized.size*texture.get_size())
		var width := w*(0.83 if skip else 0.96)
		var drawn := Vector2(width,width*region.size.y/region.size.x)
		var rect := Rect2(-drawn/2,drawn)
		var angle := 0.035 if skip else -0.20
		if combined and not skip:
			angle = PI / 4.0
		draw_set_transform(center+Vector2(1.0,1.5),angle)
		draw_texture_rect_region(texture,rect,region,Color(0.12,0.02,0.03,0.35))
		draw_set_transform(center,angle)
		draw_texture_rect_region(texture,rect,region,Color(1,1,1,0.94))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
