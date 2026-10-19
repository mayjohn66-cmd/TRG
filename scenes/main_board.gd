# File: res://scenes/main_board.gd
# Class: class_name MainBoard
# Role: 로컬 핫시트 플레이 화면. 24칸 사각 보드·4인 말·중앙 법전·손패·증강 드래프트·타일 선택 모드·결과창을 기본 도형으로 그리고, TurnManager의 시그널만 구독하며 act()로만 행동을 보낸다
class_name MainBoard
extends Control

const MATCH_BACKGROUND_SCRIPT: Script = preload("res://scenes/match_background.gd")

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
## 보드는 한 변 6칸의 정사각 트랙을 45도 돌려 마름모로 세운다 (0번 출발선이 아래 꼭짓점, 반시계로 오른쪽 -> 위 -> 왼쪽 꼭짓점).
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
## 한 칸 점프: 걸리는 시간(초)과 솟구치는 높이(px). 도착 직후 납작하게 찌그러졌다가 탱글하게 돌아온다.
const HOP_SECONDS: float = 0.14
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
const BEAT_AFTER_MOVE: float = 0.8
const TURN_BANNER_SECONDS: float = 0.9
const HAND_RAISED_Y: float = -92.0
## 우측 하단 기물 독에서 기물 슬롯이 놓이는 기준 y (필살기 버튼 줄 아래).
const SLOT_BASE_Y: float = 50.0
const AUGMENT_CARD_SIZE: Vector2 = Vector2(260, 390)
const AUGMENT_HOVER_SCALE: float = 1.06
## 증강 카드를 고른 뒤 다음 단계로 넘어가기 전에 선택 연출을 보여 주는 시간(초).
const AUGMENT_PICK_SECONDS: float = 0.9
const SELECT_CARD_SIZE: Vector2 = Vector2(135, 165)
const SELECT_BANNER_POS: Vector2 = Vector2(380, 568)
const SLOT_SIZE: Vector2 = Vector2(76, 88)
## 슬링샷 조준: 이 거리(px)만큼 당기면 파워 100%.
const AIM_MAX_PULL: float = 150.0
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
}
## 작은 손패 카드에 보여 주는 1줄 핵심 요약 (15자 이내). 자세한 규칙은 클릭해서 확대할 때 CARD_SUMMARIES로 본다.
const CARD_SHORT: Dictionary = {
	&"ACT_01": "순서 역전·역주행",
	&"ACT_02": "상대 선두 -2칸",
	&"ACT_03": "다음 유저 -4칸",
	&"ACT_04": "이번 굴림 결과 +3",
	&"ACT_05": "턴 시작 전으로 되감기",
	&"ACT_06": "교칙 1개 삭제",
	&"ACT_07": "뭉친 말 강제 산개",
	&"ACT_08": "꼴찌 ↔ 선두 교환",
	&"ACT_09": "가위바위보 승자가 -2칸",
	&"TRP_01": "밟은 적 출발선 추방",
	&"TRP_02": "눈금 4+ 2턴 구속",
	&"TRP_03": "반경 2칸 폭파",
	&"TRP_04": "코너 감옥화",
	&"TRP_05": "-3칸 & 연쇄 밀침",
	&"SUM_01": "최근접 말 추격",
	&"SUM_02": "역주행 순찰·연행",
}
## 카드 확대 보기에서 읽는 개조식 요약 (키워드 + 명사형 종결).
const CARD_SUMMARIES: Dictionary = {
	&"ACT_01": "턴 순서 역전 & 전원 역주행",
	&"ACT_02": "상대 선두 말 2칸 후퇴 (프로필 선택)",
	&"ACT_03": "다음 유저 선두 말 4칸 후퇴",
	&"ACT_04": "굴리기 전 사용! 눈금 +3칸",
	&"ACT_05": "이번 턴 시작 직전으로 시간 역행",
	&"ACT_06": "중앙 법전 교칙 1개 지정 삭제",
	&"TRP_01": "밟은 적 말 즉시 출발선 추방",
	&"TRP_02": "눈금 4+ 이동 말 2턴간 구속",
	&"TRP_03": "밟으면 반경 2칸 내 모든 말 폭파",
	&"TRP_04": "코너 감옥화 (짝수 눈금에 탈출)",
	&"TRP_05": "밟은 말 -3칸 & 뒷말들 연쇄 밀침",
	&"ACT_07": "가장 뭉친 타일의 말 강제 분리·산개",
	&"ACT_08": "내 꼴찌 말 ↔ 1등 적 선두 말 위치 교환",
	&"ACT_09": "적 1명과 가위바위보! 승자가 패자 말 1개를 -2칸 후퇴시킴",
	&"SUM_01": "라운드마다 최근접 말 추격\n카드 강탈",
	&"SUM_02": "12번 출발 역주행 순찰 & 연행",
}


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


const PHASE_NAMES: Dictionary = {
	TurnManager.State.PHASE_ROUND_START: "라운드 시작 - 증강 드래프트",
	TurnManager.State.PHASE_TURN_BEGIN: "턴 시작 - 카드·함정·소환 사용 가능",
	TurnManager.State.PHASE_ROLL_WAIT: "판정 도구 굴리기",
	TurnManager.State.PHASE_INTERRUPT_ROLL: "개입 타이밍 A - 카드 사용 가능",
	TurnManager.State.PHASE_SELECT_PAWN: "이동할 말 선택",
	TurnManager.State.PHASE_MOVING_STEP: "이동 중...",
	TurnManager.State.PHASE_RESOLUTION: "정산 / 개입 타이밍 B - 카드 사용 가능",
	TurnManager.State.PHASE_NEUTRAL_NPC: "중립 NPC 페이즈",
}
const YUT_NAMES: Dictionary = {-1: "빽도", 1: "도", 2: "개", 3: "걸", 4: "윷", 5: "모"}
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
const CATEGORY_COLORS: Dictionary = {
	GameEnums.AugmentCategory.PAWN_EVOLUTION: Color("ffa94d"),
	GameEnums.AugmentCategory.TOOL_SWAP: Color("74c0fc"),
	GameEnums.AugmentCategory.LAW_ENACT: Color("ffe066"),
	GameEnums.AugmentCategory.CARD_PACKAGE: Color("da77f2"),
}

## 이 화면을 보는 플레이어. 이 플레이어의 프로필·기물 독이 우측 하단에 놓인다 (멀티플레이에서 P2~P4로 접속해도 본인이 우측 하단).
var local_player_id: int = 1
## 이 판에 참여하는 좌석 (컴퓨터 대전/핫시트는 4명 전부, 온라인 대전은 로비에서 정한 2~4명).
var _player_ids: Array[int] = PLAYER_IDS.duplicate()
## 플레이어 -> 앉은 자리 앵커 (SEAT_*). 참가 인원과 내 자리로 정해진다.
var _seat_anchor: Dictionary = {}
## 온라인 대전(락스텝) 동기화. 온라인이 아니면 null.
var net: NetGame = null
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
var _aim_dragging: bool = false
var _aim_origin: Vector2 = Vector2.ZERO
var _aim_angle: float = 0.0
var _aim_power: float = 0.0
var _aim_layer: Node2D = null
var _aim_line: Line2D = null
var _aim_label: Label = null
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
var _tip_source: Variant = null
var _tip_provider: Callable = Callable()
var _tip_clock: float = 0.0
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
var _emote_row: HBoxContainer = null
var _emote_ready_msec: int = 0
## 치트/디버그 메뉴 노출 여부: 평소에는 숨기고, F9 / Ctrl+Shift+D 또는 웹 주소의 ?debug=1 일 때만 켠다.
var _debug_enabled: bool = false
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
var instant_roll_for_test: bool = false
var _presenter: RollPresenter = null
var _announcer: EventAnnouncer = null
var _power_bar: ProgressBar = null
var _power_label: Label = null
var _charging: bool = false
var _charge_by_key: bool = false
var _charge_clock: float = 0.0
var _charge_value: float = 0.0
var _pending_power: float = 0.5
var _fx_busy: bool = false
## 말 움직임 연출(PawnFx): 이 시각(msec)까지는 입력·봇을 잠가 움직임이 끝나기를 기다린다.
var _fx_until_msec: int = 0
## 말 id -> 다음 이동 연출에 쓸 힌트 {delay, arc, peak, spin, dur, drop, t(만든 시각)}. 이벤트가 어떻게 움직일지 미리 알려 준다.
var _fx_hints: Dictionary = {}
## 알림 카드가 끝난 뒤에 실행할 연출들 (알림 카드가 보드를 가리는 동안 말이 먼저 움직이지 않도록).
var _fx_pending: Array[Callable] = []
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
## 게임 필: 화면 흔들림, 말 id -> 이동 연출을 필살기 스크립트가 맡는 중(걸음 무시), 차 돌진 중 잡힌 말이 나는 시점을 늦추는 값(초).
var _shake_tween: Tween = null
var _shake_origin: Vector2 = Vector2.ZERO
var _shake_active: bool = false
var _fx_skip_steps: Dictionary = {}
var _fx_hint_bonus: float = 0.0
## 알림 카드가 떠 있는 동안 받아 둔 말의 걸음들: 말 id -> [{pos, scale}] (카드가 끝나면 한 칸씩 이어서 보여 준다).
var _fx_step_queue: Dictionary = {}
var _fx_generation: int = 0
## 점프 코너·옷장 포탈의 2단계 이동(발판에 멈춤 -> 발동 연출 -> 비행/워프)이 진행 중인 수. 0보다 크면 다른 말의 연출과 알림은 끝날 때까지 기다린다.
var _stage_warps: int = 0
## 증강 선택 창은 이동·처치·함정 연출이 모두 끝나고 0.4초 여운이 지난 뒤에 연다.
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
var _menu_button: Button = null
var _sound_button: Button = null  ## 우측 상단 소리 켜짐/꺼짐 토글
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
var _auto_draft_enabled: bool = false

var _tile_pick_active: bool = false
## 뱅! 저격: 타일 대신 상대 프로필을 눌러 고르는 모드 (_tile_pick_active와 함께 켜진다). 프로필마다 표식이 붙는다.
var _snipe_pick: bool = false
## ACT_09 결투: 중앙 스테이지 결투장, 승자가 고를 수 있는 말(보드 위 붉은 표식), 카드를 놓은 대상 플레이어.
var _duel_arena: DuelArena = null
var _duel_strike_marks: Dictionary = {}
var _duel_strike_winner: int = -1
var _duel_drop_target: int = -1
var _snipe_marks: Dictionary = {}
var _tile_pick_player: int = -1
var _tile_pick_card: StringName = &""


func _ready() -> void:
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
	manager.step_delay_sec = STEP_DELAY * _pace()
	manager.stack_choice_enabled = false  # 윷말끼리 만나면 선택창 없이 자동으로 업는다 (선택 UI는 코어에 남아 있다)
	_bot = BotController.new()
	_bot.name = "BotController"
	_bot.manager = manager
	_bot.pace = _pace()
	_bot.busy_check = _bot_should_wait
	_bot.enabled = ai_mode
	if not GameSession.net_active:
		var computer_seats: Array[int] = []
		for seat: int in _player_ids:
			if seat != local_player_id:
				computer_seats.append(seat)
		_bot.bot_players = computer_seats
	add_child(_bot)
	add_child(manager)
	manager.set_process(false)  # 제한 시간은 체크박스로 켤 때만 흐른다 (혼자 테스트할 때 자동 진행 방지)
	if GameSession.net_active:
		_setup_net()
	manager.phase_changed.connect(_on_phase_changed)
	manager.event_received.connect(_on_event)
	manager.action_rejected.connect(_on_action_rejected)
	manager.turn_order_reversed.connect(_on_turn_order_reversed)
	manager.game_over.connect(_on_game_over)
	_build_ui()
	if net != null:
		_log_line("상대를 기다리는 중입니다...", Color("ffe066"))
		net.begin.call_deferred()
	else:
		_new_game()
	var mobile := MobileSupport.new()
	mobile.button_position = Vector2(12, 10)
	add_child(mobile)


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
	if manager == null or manager.state == null or state == null:
		return
	if not manager.is_game_over:
		_phase_label.text = _phase_text()
	_bot.instant = instant_roll_for_test
	if _charging:
		# 파워 게이지: 0% ~ 100%를 빠르게 왕복한다 (손을 떼는 순간의 값이 연출 세기가 된다).
		_charge_clock += delta
		_charge_value = pingpong(_charge_clock * 1.6, 1.0)
		_power_bar.value = _charge_value * 100.0
		_power_label.text = "POWER %d%%" % int(_charge_value * 100.0)
		var fill: StyleBoxFlat = _style(Color("51cf66") if _charge_value < 0.4 else (Color("fcc419") if _charge_value < 0.75 else Color("ff6b6b")), Color("fff3bf"), 2, 7, 0, 0)
		_power_bar.add_theme_stylebox_override("fill", fill)
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
	if manager == null or state == null or _menu_is_open():
		return
	if _snipe_pick and _handle_snipe_input(event):
		get_viewport().set_input_as_handled()
		return
	if not _duel_strike_marks.is_empty() and _handle_duel_strike_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_aim_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_card_pointer(event):
		return
	if event is InputEventMouseMotion:
		_update_board_pawn_tip((event as InputEventMouseMotion).position)
	if manager.current_state != TurnManager.State.PHASE_SELECT_PAWN:
		return
	if _ui_busy() or _is_bot_turn() or _choice_overlay != null or _draft_overlay != null or _result_overlay != null or _stack_overlay != null or _tile_pick_active:
		return
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null:
		# 보드 위의 내 말 도형을 직접 클릭해 이동한다.
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT and not (_select_banner != null and _select_banner.visible and _select_banner.get_global_rect().has_point(button_event.position)):
			var clicked: int = _pawn_at(button_event.position)
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
	if key_event.pressed and (key_event.keycode == KEY_F9 or (key_event.keycode == KEY_D and key_event.ctrl_pressed and key_event.shift_pressed)):
		toggle_debug_access()
		return
	# Ctrl/Alt/Meta/Shift 조합은 브라우저·OS 단축키(예: Ctrl+Shift+R 강력 새로고침)이므로 게임 단축키로 쓰지 않는다.
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed or key_event.shift_pressed:
		return
	var roll_key: bool = key_event.keycode == KEY_R or key_event.keycode == KEY_SPACE
	if not key_event.pressed:
		# 키를 떼는 순간 굴린다 (꾹 눌러 모은 파워 게이지 확정)
		if roll_key and _charging and _charge_by_key:
			_on_roll_pressed()
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
	if _choice_overlay != null or _draft_overlay != null or _result_overlay != null or _stack_overlay != null:
		return
	if roll_key:
		_begin_charge(true)


# ---------------------------------------------------------------------------
# 새 게임
# ---------------------------------------------------------------------------

func _new_game() -> void:
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
	_toast_label.text = ""
	_dock_player = -1
	_announced_round = 0
	_announced_turn_key = ""
	_beat_until_msec = 0
	_close_reaction_popup()
	_fx_generation += 1
	_stage_warps = 0
	_trap_pending.clear()
	_trap_tiles.clear()
	_fx_busy = false
	_bot.set_enabled(_bot_active())
	_stop_charge()
	_presenter.cancel()
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
	manager.start_game(_player_ids, _game_seed)
	state = manager.state
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
	state.pawn_stepped.connect(_on_pawn_stepped)
	state.pawn_warped.connect(_on_pawn_warped)
	state.pawn_sent_to_start.connect(func(pawn_id: int, by_player: int) -> void:
		_log_line("%s 출발선으로 복귀" % _pawn_name(pawn_id), Color("ff8787"))
		var victim: PlayerPawn = state.get_pawn(pawn_id)
		if victim != null:
			_avatar_react(victim.owner_id, AvatarSlot.Emotion.ANGRY)
			if by_player != victim.owner_id and _player_ids.has(by_player):
				_avatar_react(by_player, AvatarSlot.Emotion.HAPPY)
		# 잡힌 말: [처치 컷신 0.65초] -> 보드 밖으로 홈런처럼 날아감(0.38초, 1080도 회전) -> 출발선 위에서 툭 떨어져 바운스.
		# 컷신은 잡는 말의 이동이 끝난 뒤에 뜨고, 그동안 잡힌 말은 제자리에서 기다린다.
		if victim != null and _fx_on():
			var owner_id: int = victim.owner_id
			var victim_pos: Vector2 = (_pawn_views[pawn_id] as Node2D).position if _pawn_views.has(pawn_id) else Vector2.ZERO
			var attacker_art: Texture2D = _attacker_art(by_player, victim_pos)
			_fx_when_announced(func() -> void:
				var lead: float = maxf(0.0, float(_fx_until_msec - Time.get_ticks_msec()) / 1000.0)
				var cutin_seconds: float = KillCutIn.TOTAL_SECONDS * _pace()
				_show_kill_cutin(attacker_art, lead)
				_set_hint(pawn_id, {"delay": lead + cutin_seconds + _fx_hint_bonus, "homerun": true, "land_thud": true})
				get_tree().create_timer(lead + cutin_seconds + 0.1).timeout.connect(func() -> void:
					_profile_react(owner_id, false, ["[억까!]", "[으악!]"][randi() % 2])
					if by_player != owner_id:
						_profile_react(by_player, true, "[나이스!]")))
		else:
			_set_hint(pawn_id, {"arc": 110.0, "spin": 2.0 * TAU, "dur": 0.45, "land_thud": true}))
	state.pawn_finished.connect(func(pawn_id: int) -> void:
		_log_line("[완주] %s 완주!" % _pawn_name(pawn_id), Color("69db7c"))
		var finisher: PlayerPawn = state.get_pawn(pawn_id)
		if finisher != null:
			_avatar_react(finisher.owner_id, AvatarSlot.Emotion.CHEER, 1.8)
			var finisher_owner: int = finisher.owner_id
			_fx_when_announced(func() -> void: _profile_react(finisher_owner, true, "[골인!]")))
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
	state.domino_collapsed.connect(func(pawn_id: int, passed: Array[int], chain: Array[int]) -> void:
		var chain_names: Array[String] = []
		for chained: int in chain:
			chain_names.append(_pawn_name(chained))
		_log_line("[도미노] %s 뒤로 3칸 밀림%s" % [_pawn_name(pawn_id), "  연쇄: %s (각 -2칸)" % ", ".join(chain_names) if not chain_names.is_empty() else ""], Color("ff6b6b"))
		_set_hint(pawn_id, {"arc": 0.0, "dur": 0.45, "tilt": -0.55})
		for chain_index: int in chain.size():
			_set_hint(chain[chain_index], {"arc": 0.0, "dur": 0.4, "tilt": -0.55, "delay": 0.1 * (chain_index + 1)})
		var domino_pos: Vector2 = (_pawn_views[pawn_id] as Node2D).position if _pawn_views.has(pawn_id) else Vector2.ZERO
		_fx_when_announced(func() -> void:
			screen_shake(7.0, 0.25)
			_impact_ring(domino_pos, Color("ff6b6b"), 40.0))
		_announce_gate("함정 발동", "도미노 연쇄 붕괴!", "%s이(가) 3칸 뒤로 밀려났습니다%s" % [_pawn_name(pawn_id), "\n연쇄로 %d개 말이 2칸씩 우수수 밀려납니다" % chain.size() if not chain.is_empty() else ""], Color("ff6b6b"), null, 1.4))
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
		else:
			_log_line("[타로] 운명의 수레바퀴: %s 4칸 후퇴" % _pawn_name(enemy_id), Color("ffa94d"))
			_announce_gate("타로", "X. 운명의 수레바퀴!", "%s이(가) 4칸 뒤로 밀려납니다" % _pawn_name(enemy_id), Color("ffa94d"), null, 1.5)
		_refresh_pawns())
	state.pawn_evolved.connect(func(pawn_id: int, kind: int, unit_no: int) -> void: _log_line("[진화] %s → %s" % [_pawn_name(pawn_id), PawnCatalog.unit_label(kind, unit_no)], Color("ffa94d")))
	state.pawns_stacked.connect(func(leader_id: int, member_ids: Array[int]) -> void: _log_line("%s 업기 (%d마리)" % [_pawn_name(leader_id), member_ids.size()], Color("ffd43b")))
	state.pawns_swapped.connect(func(a_id: int, b_id: int) -> void:
		_log_line("%s ↔ %s 위치 교환" % [_pawn_name(a_id), _pawn_name(b_id)], Color("ffd43b"))
		_hint_swap(a_id, b_id))
	state.pawns_castled.connect(func(a_id: int, b_id: int) -> void: _hint_swap(a_id, b_id))
	state.pawn_pushed_back.connect(func(pawn_id: int, _from: int, _to: int) -> void:
		if not _fx_hints.has(pawn_id):
			_set_hint(pawn_id, {"arc": 0.0, "dur": 0.5}))
	state.attachment_triggered.connect(func(tile: int, id: String, pawn_id: int, _cutscene: StringName) -> void:
		var trapped: PlayerPawn = state.get_pawn(pawn_id)
		if trapped != null:
			_avatar_react(trapped.owner_id, AvatarSlot.Emotion.SURPRISED)
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
					_profile_react(trapped_owner, false, ["[억까!]", "[으악!]"][randi() % 2])))
		_log_line("[설치물] %d번 타일 %s 발동! (%s)" % [tile, _attachment_name(id), _pawn_name(pawn_id)], Color("ff6b6b"))
		_announce_gate("함정 발동", "[발동!] %s" % _attachment_name(id), "%s\n%d번 타일에서 %s에게 발동" % [str(CARD_SUMMARIES.get(StringName(id), "")), tile, _pawn_name(pawn_id)], Color("ff6b6b"), null, 1.2))
	state.npc_vanished.connect(func(npc_id: int, tile: int) -> void:
		_announce("중립 기물", "NPC가 사냥을 마치고 사라졌습니다", "%d번 타일 - 중립 기물은 한 번 잡으면 사라집니다" % tile, Color("fa5252"), null, 1.3))
	state.attachment_placed.connect(func(tile: int, id: String, owner_id: int) -> void:
		if id.begins_with("TRP") and _fx_on():
			# 카드를 먼저 보여 준 뒤 발판이 짙은 보라색으로 깜빡이며 나타난다.
			_trap_pending[tile] = true
			_fx_when_announced(func() -> void:
				_trap_pending.erase(tile)
				_refresh_tiles()
				_tile_glow(tile)
				_impact_ring(_tile_center(tile) + (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO), Color("7b2cbf"), 26.0)
				Sfx.play(&"law"))
		_log_line("P%d가 %d번 타일에 [%s]을(를) 설치했습니다" % [owner_id, tile, "뒷면 카드" if id.begins_with("TRP") else _attachment_name(id)], Color("adb5bd"))
		_refresh_tiles())
	state.card_drawn.connect(func(_player_id: int, _card_id: StringName) -> void:
		if _fx_on():
			Sfx.play(&"card_get"))
	state.card_drawn.connect(func(player_id: int, card_id: StringName) -> void: _log_line("[카드] P%d 생떼 카드 획득: %s" % [player_id, _card_name(card_id)], Color("ffa94d")))
	state.card_stolen.connect(func(player_id: int, card_id: StringName) -> void: _log_line("P%d의 카드 [%s]를 도적이 빼앗았습니다" % [player_id, _card_name(card_id)], Color("ff6b6b")))
	state.npc_spawned.connect(func(_npc_id: int, tile: int) -> void:
		_log_line("중립 NPC가 %d번 타일에 소환되었습니다. 라운드가 끝날 때 움직입니다." % tile, Color("fa5252"))
		_refresh_all())
	state.rulebook.law_added.connect(_on_law_added)
	state.rulebook.law_removed.connect(func(law: LawResource) -> void:
		_log_line("[법전] 교칙 파기: [%s] %s" % [law.law_id, law.law_name], Color("ff8787"))
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
	_build_hover_tip()
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
	var left: Array = [_law_panel]
	var center: Array = [_select_banner, _dir_left, _dir_right, _board_layer, _pawn_layer, _dock, _drop_zone, _aim_layer, _pick_banner, _pick_cancel, _roll_button, _roll_pad, _gun_row, _power_bar, _power_label]
	var right: Array = [_tool_board, _action_row, _pawn_bar, _emote_row, _menu_button, _sound_button, _debug_box, _log_panel]
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
	if _announcer != null:
		_announcer.center = _board_center()
	if _presenter != null:
		_presenter.center = _board_center() + Vector2(0, -40)


## 보드 한가운데의 화면 좌표 (창 비율 오프셋 포함).
func _board_center() -> Vector2:
	return BOARD_ORIGIN + Vector2(BOARD_SIZE, BOARD_SIZE) / 2.0 + _off_center


## 상단 리본은 없앴다: 현재 턴은 프로필의 밝기·강조선, 라운드는 중앙 알림이 알려 준다. 로그 문구만 받는 숨김 라벨만 남긴다.
func _build_toast_label() -> void:
	_toast_label = _make_label("", 11, Color("ffe8a3"))
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
		var name_label := _make_label("플레이어 %d" % player_id, 18 if big else 15, color.lightened(0.3))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.add_theme_color_override("font_outline_color", Color("0d1018"))
		name_label.add_theme_constant_override("outline_size", 3)
		top.add_child(name_label)
		var count_label := _make_label("x0", 12, Color("ced4da"))
		top.add_child(count_label)
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
			_bind_tip(icon, _fill_pawn_tip.bind(player_id * 10 + slot))
			cell.add_child(icon)
			if big:
				var skill_button: Button = _make_button("필살기", _on_skill_pressed.bind(slot - 1), 11, Color("c77d0a"), 6)
				skill_button.custom_minimum_size = Vector2(slot_size, 26)
				skill_button.focus_mode = Control.FOCUS_NONE
				skill_button.add_theme_color_override("font_color", Color("fff9db"))
				skill_button.add_theme_color_override("font_outline_color", Color("5c3a00"))
				skill_button.add_theme_constant_override("outline_size", 3)
				skill_button.visible = false
				skill_button.mouse_entered.connect(_on_pawn_slot_hover.bind(slot - 1))
				skill_button.mouse_exited.connect(_tip_end.bind(skill_button))
				cell.add_child(skill_button)
				_skill_buttons.append(skill_button)
			slots.append({"panel": icon, "letter": letter, "status": status})
		_profiles[player_id] = {
			"panel": panel,
			"name": name_label,
			"count": count_label,
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
	for player_id: int in PLAYER_IDS:
		if _player_ids.has(player_id):
			(_profiles[player_id]["avatar"] as AvatarSlot).set_character(_avatar_for(player_id))


## 플레이어의 아바타가 감정을 보인다 (에셋이 있으면 그 애니메이션, 없으면 자리표시자 연출).
func _avatar_react(player_id: int, new_emotion: AvatarSlot.Emotion, seconds: float = 1.4) -> void:
	var card: Dictionary = _profiles.get(player_id, {})
	if card.is_empty() or not _player_ids.has(player_id):
		return
	(card["avatar"] as AvatarSlot).react(new_emotion, seconds)


## 좌측 중앙 '엘리아스 중앙 법전' 위젯: 4개의 둥근 카드형 슬롯 (빈 슬롯은 점선 테두리, 활성 교칙은 명패).
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
	var law_title := _make_label("엘리아스 중앙 법전", 16, Color.WHITE)
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
		var name_label := _make_label("", 14, UiSkin.INK)
		name_label.clip_text = true
		text_box.add_child(name_label)
		var desc_label := _make_label("", 12, UiSkin.SOFT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.max_lines_visible = 2
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(desc_label)
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
	_tool_main = _make_label("", 14, UiSkin.INK)
	_tool_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_main.custom_minimum_size = Vector2(184, 0)
	center.add_child(_tool_main)
	_tool_sub = _make_label("", 12, UiSkin.GREEN)
	_tool_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_sub.custom_minimum_size = Vector2(184, 0)
	center.add_child(_tool_sub)
	_tool_rules = VBoxContainer.new()
	_tool_rules.add_theme_constant_override("separation", 2)
	_tool_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_tool_rules)
	_tool_note = _make_label("", 12, UiSkin.SOFT)
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
	_phase_label = _make_label("", 13, COLOR_GOLD)
	_status_strip.add_child(_phase_label)
	_hint_label = _make_label("", 12, Color("a5d8ff"))
	_hint_label.clip_text = true
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_strip.add_child(_hint_label)
	_queue_label = _make_label("", 11, Color("adb5bd"))
	_status_strip.add_child(_queue_label)
	_pick_banner = _make_label("", 13, Color("63e6be"))
	_pick_banner.position = Vector2(423, 74)
	_pick_banner.size = Vector2(400, 26)
	_pick_banner.clip_text = true
	_pick_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_banner.add_theme_stylebox_override("normal", _style(Color("0b3b33"), Color("63e6be"), 2, 8, 0, 3))
	_pick_banner.visible = false
	add_child(_pick_banner)
	_pick_cancel = _make_button("취소", _on_pick_cancel_pressed, 12, Color("5c2b2b"), 8)
	_pick_cancel.position = Vector2(831, 58)
	_pick_cancel.size = Vector2(88, 30)
	_pick_cancel.visible = false
	_pick_cancel.z_index = 25
	add_child(_pick_cancel)
	# 상단에는 [메뉴] 버튼 하나만 둔다. 새 게임·모드·치트·전체 로그·설정·나가기는 메뉴 안에 있다 (_build_menu).
	_new_game_button = _make_button("새 게임", _new_game, 12, Color("3b4766"), 8)
	_menu_button = _make_button("메뉴", _toggle_menu, 13, Color("3b4766"), 8)
	_menu_button.position = Vector2(1270, 10)
	_menu_button.size = Vector2(84, 32)
	_menu_button.tooltip_text = "메뉴 (ESC)"
	add_child(_menu_button)
	_sound_button = _make_button("", _on_sound_toggle_pressed, 13, Color("3b4766"), 8)
	_sound_button.name = "SoundToggle"
	_sound_button.position = Vector2(1170, 10)
	_sound_button.size = Vector2(94, 32)
	_sound_button.tooltip_text = "소리 켜기/끄기 (크기는 메뉴 > 게임 설정)"
	add_child(_sound_button)
	_refresh_sound_button()


## 우측 중앙의 큼직한 둥근 [굴리기] 버튼(모두의 마블 방식)과 그 아래의 멈추기·개입 패스·폭탄 떠넘기기 버튼.
func _build_action_bar() -> void:
	_roll_button = _make_button("굴리기", _on_roll_pressed, 24, Color("2b8a3e"), 60)
	_roll_button.position = Vector2(623, 320)
	_roll_button.size = Vector2(120, 120)
	_roll_button.custom_minimum_size = Vector2(120, 120)
	_apply_round_button_style(_roll_button, Color("2b8a3e"))
	_roll_button.tooltip_text = "꾹 눌러 파워 게이지를 채우고 손을 떼면 굴러갑니다 (R / Space 키도 동일)"
	_roll_button.button_down.connect(_begin_charge.bind(false))
	_roll_button.button_up.connect(_on_roll_button_up)
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
	_log_toggle = _make_button("전체 로그", _on_log_toggle_pressed, 13, Color("2f4a66"), 8)

	var debug_drawer: Dictionary = _make_drawer("치트 / 디버그", _on_debug_toggle_pressed)
	_debug_box = debug_drawer["panel"]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(debug_drawer["body"] as VBoxContainer).add_child(scroll)
	var debug_content: VBoxContainer = _build_debug_panel()
	debug_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(debug_content)

	var log_drawer: Dictionary = _make_drawer("전체 로그", _on_log_toggle_pressed)
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
	debug_row.add_child(_make_button("도적 소환(10번)", _on_spawn_npc_pressed.bind(GameEnums.NpcBehavior.CHASE_NEAREST, 10), 12))
	debug_row.add_child(_make_button("고스트 소환(12번)", _on_spawn_npc_pressed.bind(GameEnums.NpcBehavior.PATROL_REVERSE, 12), 12))
	_timer_check = CheckBox.new()
	_timer_check.text = "제한 시간 사용"
	_timer_check.toggled.connect(func(enabled: bool) -> void: manager.set_process(enabled))
	debug_row.add_child(_timer_check)
	return box


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_section(text: String) -> Label:
	return _make_label(text, 13, Color("74c0fc"))


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
func _style(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 10, shadow: int = 0, margin: int = 8) -> StyleBoxFlat:
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


## 웹 주소에 ?debug=1 이 있거나 실행 인자에 --debug 가 있는가.
static func debug_requested() -> bool:
	if OS.get_cmdline_user_args().has("--debug"):
		return true
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('debug')", true)
		return str(value) == "1"
	return false


## F9 / Ctrl+Shift+D: 치트/디버그 메뉴 항목을 켜고 끈다 (온라인 대전에서는 쓸 수 없다). 켜면 디버그 서랍도 바로 연다.
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

## 타일 번호 -> 0~1 정규화 좌표 (BoardLayout과 같은 좌표계: 우하단 0번에서 반시계로 한 변 6칸).
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
	return center + Vector2(rotated.x * DIAMOND_KX, rotated.y * DIAMOND_KY)


## 마름모에는 원근 크기 차이가 없다.
func _depth_scale(_norm_y: float) -> float:
	return 1.0


func _tile_center(index: int) -> Vector2:
	return _project(tile_norm(index))


## 점프 코너(6·18번)의 화살표가 가리킬 타일. LAW_01 중에는 점프가 막혀 바로 다음 칸을 가리킨다.
func _jump_arrow_target(index: int) -> int:
	if not GameEnums.JUMP_CORNER_TARGETS.has(index):
		return -1
	if state != null and state.rulebook.has_law("LAW_01"):
		return index + 1
	return GameEnums.JUMP_CORNER_TARGETS[index]


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
	var direction: Vector2 = (_tile_center(target) - _tile_center(index)).normalized() if target >= 0 else Vector2.RIGHT
	tile.configure(_surface_project, BoardSkin.track(tile_norm(index)), span, _depth_scale(BoardSkin.track(tile_norm(index)).y), direction)
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


func _apply_view_mode() -> void:
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
	for index: int in GameEnums.TILE_COUNT:
		_place_tile(index)
	for line: Line2D in _track_lines:
		line.queue_free()
	_track_lines.clear()
	_add_track_lines()
	if state != null:
		_refresh_pawns()


func _build_tiles_once() -> void:
	if not _tile_views.is_empty():
		return
	_add_track_lines()
	for index: int in GameEnums.TILE_COUNT:
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
	for index: int in GameEnums.TILE_COUNT:
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
	if GameEnums.CORNER_TILES.has(index):
		return Color("495057")
	return Color("ced4da")


func _tile_tag(index: int, tile_type: TileNode.TileType) -> String:
	match tile_type:
		TileNode.TileType.START_GOAL: return "▲출발"
		TileNode.TileType.BAKERY: return "빵집"
		TileNode.TileType.PORTAL: return "옷장"
	if GameEnums.JUMP_CORNER_TARGETS.has(index):
		return "점프 코너 → %d번" % int(GameEnums.JUMP_CORNER_TARGETS[index])
	if index == GameEnums.HALFWAY_TILE:
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


func _refresh_pawns() -> void:
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
		(view.get_node("Bounce/Badge") as Label).text = badge_text
	for npc: NeutralNPC in state.npcs:
		if not _npc_views.has(npc.entity_id):
			var marker := PawnToken.new()
			marker.configure_npc(npc.behavior)
			_pawn_layer.add_child(marker)
			_npc_views[npc.entity_id] = marker
		var npc_view: Node2D = _npc_views[npc.entity_id]
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
	for index: int in GameEnums.TILE_COUNT:
		var parts: Array[String] = []
		if GameEnums.JUMP_CORNER_TARGETS.has(index):
			if (_tile_views[index] as BoardSkin.Tile).arrow_target != _jump_arrow_target(index):
				_place_tile(index)
		var tips: Array[String] = []
		var kind_label: String = _tile_tag(index, state.board.get_tile(index).tile_type)
		if not kind_label.is_empty():
			tips.append(kind_label)
		var color: Color = Color("ff6b6b")
		var has_trap: bool = false
		for attachment: TileAttachment in state.board.get_tile(index).attachments:
			match attachment.attachment_id:
				"TRP_01", "TRP_02", "TRP_03", "TRP_05":
					has_trap = true
					tips.append(_trap_tooltip(attachment))
				"TRP_04":
					has_trap = true
					tips.append("[무인도] 코너 감옥화 (짝수 눈금에 탈출)")
				"HOTEL":
					parts.append("호텔")
					color = PLAYER_COLORS.get(attachment.owner_id, Color("ffd43b"))
		var shown_trap: bool = has_trap and not _trap_pending.has(index)
		(_tile_views[index] as BoardSkin.Tile).set_trap(shown_trap)
		if shown_trap and not _trap_tiles.has(index):
			_trap_tiles.append(index)
		elif not shown_trap:
			_trap_tiles.erase(index)
		(_tile_views[index] as Control).tooltip_text = "\n".join(tips)
		var mark: Label = _tile_marks[index]
		mark.text = " ".join(parts)
		mark.position = Vector2((_tile_views[index] as Control).size.x - 2 - mark.get_minimum_size().x, 0)
		mark.add_theme_color_override("font_color", color)


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


## 함정 툴팁. AI 모드(타일 은신): P1이 설치한 함정만 이름이 보이고 봇이 설치한 함정은 뒷면 [? 함정]으로만 보인다.
func _trap_tooltip(attachment: TileAttachment) -> String:
	if ai_mode and attachment.owner_id == local_player_id:
		return "[내 함정] %s" % _attachment_name(attachment.attachment_id)
	return "[? 함정] P%d가 설치한 뒷면 함정" % attachment.owner_id if ai_mode else "[? 함정]"


func _on_pawn_stepped(pawn_id: int, _from_tile: int, _to_tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if view == null or pawn == null:
		return
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
	if _fx_holding():
		# 알림 카드가 가리는 동안의 걸음은 모아 두었다가 카드가 끝나면 한 칸씩 이어서 보여 준다.
		if not _fx_step_queue.has(pawn_id):
			_fx_step_queue[pawn_id] = []
		(_fx_step_queue[pawn_id] as Array).append({"pos": _pawn_position(pawn), "scale": target_scale, "tile": pawn.current_tile_idx})
		return
	_glide(view, _pawn_position(pawn), target_scale, {"dur": HOP_SECONDS, "arc": HOP_HEIGHT, "pace_cap": minf(_pace(), 1.5), "land_tile": pawn.current_tile_idx})


## 점프 코너(6·18번)나 옷장 포탈(9·16번)에서 시작한 워프인가: 발판에 먼저 멈춰 발동 연출을 보여 준 뒤 날아가야 한다.
func _is_stage_warp(from_tile: int, to_tile: int) -> bool:
	return from_tile != to_tile and (GameEnums.JUMP_CORNER_TARGETS.has(from_tile) or GameEnums.PORTAL_TILES.has(from_tile))


## 2단계 분리 이동: (A) 말이 발판에 도착해 멈출 때까지 기다린다 -> (B) 발판이 빛나며 [발동] 배너 0.45초 -> (C) 높은 포물선으로 날아가거나(코너) 줄었다 커지며(포탈) 목적지에 착지 -> (D) 밀려 있던 잡기·함정 연출을 이어서 재생한다.
## 그동안 다른 말의 연출·알림·입력은 _fx_holding()으로 기다린다 (_stage_warps).
func _stage_warp(pawn_id: int, from_tile: int, to_tile: int) -> void:
	var view: Node2D = _pawn_views.get(pawn_id)
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if view == null or pawn == null:
		return
	var generation: int = _fx_generation
	_stage_warps += 1
	var corner: bool = GameEnums.JUMP_CORNER_TARGETS.has(from_tile)
	var pace: float = _motion_pace()
	# A) 발판에 닿을 때까지 (밀려 있던 걸음, 알림 카드, 점프 중인 말)
	while generation == _fx_generation and is_instance_valid(view) and (_fx_running(view) or _fx_step_queue.has(pawn_id) or (_announcer != null and _announcer.active and not _fx_gate_open)):
		await get_tree().process_frame
	if generation != _fx_generation or not is_instance_valid(view):
		return
	# B) 발판 발동 연출
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int((0.45 + 0.9) * pace * 1000.0) + 150)
	_tile_glow(from_tile)
	_show_tile_banner(from_tile, "점프 코너 발동!" if corner else "옷장 포탈 워프!", Color("ffe066") if corner else Color("d0bfff"), 0.45 * pace)
	Sfx.play(&"launch" if corner else &"promote")
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
		_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int(0.5 * pace * 1000.0) + 80)
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
func _show_tile_banner(tile: int, text: String, color: Color, seconds: float) -> void:
	if not is_inside_tree():
		return
	var label := _make_label(text, 20, color)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color("2b2100"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 60
	add_child(label)
	label.reset_size()
	var anchor: Vector2 = (_pawn_layer.position if _pawn_layer != null else Vector2.ZERO) + _tile_center(tile)
	label.position = anchor - Vector2(label.size.x / 2.0, 58.0)
	label.modulate.a = 0.0
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(label, "position:y", label.position.y - 14.0, maxf(seconds, 0.2))
	tween.tween_interval(maxf(seconds - 0.3, 0.05))
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)


## 순간이동(옷장·비행기·탑 흩어짐 등): 높이 떠올라 포물선으로 날아가 내려앉는다.
func _on_pawn_warped(pawn_id: int, _from_tile: int, _to_tile: int) -> void:
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
		_stage_warp(pawn_id, _from_tile, _to_tile)
		return
	if _fx_holding():
		return  # 카드가 끝나면 _refresh_pawns가 힌트대로 날려 보낸다
	var opts: Dictionary = _take_hint(pawn_id)
	var merged: Dictionary = {"arc": 46.0, "peak": 1.35, "dur": 0.55}
	merged.merge(opts, true)
	_glide(view, _pawn_position(pawn), _depth_scale(tile_norm(pawn.current_tile_idx).y), merged)


# ---------------------------------------------------------------------------
# 갱신
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	if manager == null or manager.state == null:
		return
	state = manager.state
	_refresh_header()
	_refresh_players()
	_refresh_laws()
	_refresh_tiles()
	_refresh_pawns()
	_refresh_hands()
	_refresh_controls()
	_refresh_overlays()
	_check_round_banner()
	_check_turn_banner()


func _phase_text() -> String:
	var text: String = PHASE_NAMES[manager.current_state]
	if ((_timer_check != null and _timer_check.button_pressed) or net != null) and manager.phase_time_left > 0.0:
		text += "  (%.1f초)" % manager.phase_time_left
	return text


func _refresh_header() -> void:
	_phase_label.text = _phase_text()
	_refresh_direction()
	var queue_text: String = "남은 이동 대기열: %s" % str(manager.move_queue) if not manager.move_queue.is_empty() else ""
	if state.reverse_move_rounds_left > 0:
		queue_text += "   이동 역주행 %d라운드 남음" % state.reverse_move_rounds_left
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
	start_tag.text = "▼역주행" if reversed else "▲출발"
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
	if _stage_warps > 0:
		return true
	# 굴림 연출·실패 알림이 진행 중이면 아직 이전 플레이어의 턴이다 (결과를 다 보여 준 뒤에야 다음 턴으로 넘어간다).
	if _fx_busy or (_announcer != null and _announcer.active):
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


## 라운드가 시작될 때(증강 선택이 끝나고 첫 플레이어의 턴이 오기 직전) 중앙에 크게 알린다.
func _check_round_banner() -> void:
	if _announcer == null or manager.is_game_over or manager.current_state == TurnManager.State.PHASE_ROUND_START:
		return
	if _defer_for_motion():
		return
	if state.round_number == _announced_round:
		return
	_announced_round = state.round_number
	_announced_turn_key = "%d:%d" % [state.round_number, manager.current_player_id()]
	_announce("라운드", "%d라운드 시작!" % state.round_number, "", COLOR_GOLD, null, 1.2)


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
	var who: String = "내 차례!" if (not ai_mode or player_id == local_player_id) and ai_mode else "%s 차례" % _player_name(player_id)
	_announce("턴", who, "", PLAYER_COLORS[player_id], null, TURN_BANNER_SECONDS)


## 프로필에 보여 줄 이름: AI 대전에서는 내 닉네임과 "컴퓨터 n", 4P 수동 조작에서는 "플레이어 n".
func _player_name(player_id: int) -> String:
	if net != null:
		return net.display_name(player_id)
	if ai_mode:
		return GameSession.display_nickname() if player_id == local_player_id else "컴퓨터 %d" % player_id
	return "플레이어 %d" % player_id


func _refresh_players() -> void:
	for player_id: int in _player_ids:
		var card: Dictionary = _profiles[player_id]
		var color: Color = PLAYER_COLORS[player_id]
		(card["name"] as Label).text = _player_name(player_id)
		(card["count"] as Label).text = "x%d" % (state.hands[player_id] as Array).size()
		var slots: Array = card["slots"]
		for index: int in slots.size():
			_paint_pawn_slot(slots[index], state.get_pawn(player_id * 10 + index + 1), color)
		var panel: PanelContainer = card["panel"]
		# 스포트라이트: 현재 턴 플레이어만 환하게 밝고 살짝 커지며 외곽 광채가 켜지고, 나머지는 어둡게 가라앉는다.
		var is_turn: bool = player_id == _shown_turn_player() and not manager.is_game_over
		var game_over: bool = manager.is_game_over
		var margin: int = 8
		if is_turn:
			panel.add_theme_stylebox_override("panel", _style(Color("273049"), Color("fff3bf"), 4, 14, 26, margin))
		else:
			panel.add_theme_stylebox_override("panel", _style(COLOR_PANEL, color.darkened(0.35), 2, 14, 4, margin))
		_set_profile_light(panel, PROFILE_LIT if (is_turn or game_over) else PROFILE_DIM, Vector2(1.05, 1.05) if is_turn else Vector2.ONE)


## 프로필 패널의 명암(modulate)과 크기를 목표로 보낸다 (테스트·초기화 때는 즉시, 평소에는 짧은 트윈).
func _set_profile_light(panel: Control, tint: Color, target_scale: Vector2) -> void:
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
	var reflow: Callable = _fit_profile_token.bind(panel)
	if not panel.resized.is_connected(reflow):
		panel.resized.connect(reflow)
	_fit_profile_token(panel)
	var shown: String = pawn.letter()
	letter.text = shown if shown != "" else "말"
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
		panel.modulate = Color(1, 1, 1, 0.6)


func _fit_profile_token(host: Control) -> void:
	var token: PawnToken = host.get_node_or_null("PawnToken") as PawnToken
	if token == null:
		return
	var extent: Vector2 = host.size.max(host.custom_minimum_size)
	token.position = Vector2(extent.x/2.0,extent.y*0.79)
	token.scale = Vector2.ONE*(1.12 if extent.y>=46 else 0.88)


func _refresh_laws() -> void:
	for slot: int in _law_labels.size():
		var active: bool = slot < state.rulebook.active_laws_queue.size()
		_law_dashes[slot].visible = not active
		_law_badges[slot].visible = active
		if active:
			var law: LawResource = state.rulebook.active_laws_queue[slot]
			var flashing: bool = _flash_law_ids.has(law.law_id)
			_law_slots[slot].add_theme_stylebox_override("panel", UiSkin.panel("inset_flash" if flashing else "inset_active", 8.0))
			_law_badge_labels[slot].text = law.law_id.trim_prefix("LAW_")
			_law_labels[slot].text = law.law_name
			_law_labels[slot].add_theme_color_override("font_color", UiSkin.INK)
			_law_descs[slot].text = law.description
			_law_slots[slot].tooltip_text = "[%s] %s\n%s" % [law.law_id, law.law_name, law.description]
		else:
			_law_slots[slot].add_theme_stylebox_override("panel", UiSkin.panel("inset", 8.0))
			_law_labels[slot].text = ""
			_law_labels[slot].add_theme_color_override("font_color", UiSkin.SOFT)
			_law_descs[slot].text = ""
			_law_slots[slot].tooltip_text = ""


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
	var step: float = minf(HAND_CARD_SIZE.x - 14.0, (_dock.size.x - HAND_CARD_SIZE.x) / maxf(count - 1, 1))
	var total: float = HAND_CARD_SIZE.x + step * (count - 1)
	var start_x: float = (_dock.size.x - total) / 2.0
	for index: int in count:
		var card_id: StringName = hand[index]
		var card_view: PanelContainer = _make_card_view(player_id, card_id)
		var offset: float = float(index) - float(count - 1) / 2.0
		var home_rot: float = clampf(offset * HAND_FAN_DEGREES, -16.0, 16.0)
		var home_y: float = DOCK_CARD_Y + minf(offset * offset * 2.0, 16.0)
		card_view.position = Vector2(start_x + step * index, home_y)
		card_view.rotation = deg_to_rad(home_rot)
		card_view.set_meta("home_y", home_y)
		card_view.set_meta("home_rot", home_rot)
		_dock.add_child(card_view)


## 피해 되돌리기 팝업: 카드는 굴리기 전 1장이 기본이고, 유일한 예외인 [바이츠 더 더스트](내 말이 피해를 입었을 때)만 정산 창에서 쓴다.
## 가운데에 팝업이 뜨고 REACTION_SECONDS 동안 [지금 발동!]을 누르지 않으면 자동으로 넘어간다.
func _reaction_holder() -> int:
	if manager.is_game_over or manager.stack_offer_pending() or not _in_intervention_window() or _ui_busy():
		return -1
	if ai_mode:
		return local_player_id if _human_can_intervene() else -1
	var holders: Array[int] = _window_holders()
	return holders[0] if not holders.is_empty() else -1


func _reaction_card_for(holder: int) -> StringName:
	for card_id: StringName in state.hands[holder]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card.is_playable_in(manager.current_state) and card.could_play(state, holder):
			return card_id
	return &""


func _update_reaction_popup(delta: float) -> void:
	var holder: int = _reaction_holder()
	if holder == -1:
		_close_reaction_popup()
		return
	var key: String = "%d:%d" % [holder, manager.phase_serial]
	if _reaction_popup == null or _reaction_key != key:
		_build_reaction_popup(holder, key)
	_reaction_left -= delta
	_reaction_bar.value = maxf(_reaction_left, 0.0) / REACTION_SECONDS * 100.0
	if _reaction_left <= 0.0:
		_close_reaction_popup()
		manager.force_timeout()
		_refresh_all()


func _build_reaction_popup(holder: int, key: String) -> void:
	_close_reaction_popup()
	var card_id: StringName = _reaction_card_for(holder)
	if card_id == &"":
		return
	var card: BaseCard = CardRegistry.get_card(card_id)
	_reaction_key = key
	_reaction_left = REACTION_SECONDS
	_reaction_popup = PanelContainer.new()
	_reaction_popup.z_index = 60
	_reaction_popup.add_theme_stylebox_override("panel", _style(Color("101626"), Color("ff6b6b"), 4, 18, 26, 16))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_reaction_popup.add_child(box)
	var title := _make_label("P%d의 말이 피해를 입었습니다!" % holder, 22, Color("ffa8a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var ask := _make_label("[%s]를 지금 발동할까요?" % card.display_name, 16, Color("f8f9fa"))
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ask)
	var preview: Control = _make_card_preview(card_id)
	box.add_child(preview)
	_reaction_bar = ProgressBar.new()
	_reaction_bar.custom_minimum_size = Vector2(300, 10)
	_reaction_bar.show_percentage = false
	_reaction_bar.value = 100.0
	_reaction_bar.add_theme_stylebox_override("fill", _style(Color("ff6b6b"), Color(0, 0, 0, 0), 0, 5, 0, 0))
	_reaction_bar.add_theme_stylebox_override("background", _style(Color("2b2f3a"), Color(0, 0, 0, 0), 0, 5, 0, 0))
	box.add_child(_reaction_bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	_reaction_use_button = _make_button("지금 발동!", _on_reaction_use.bind(holder, card_id), 18, Color("c77d0a"), 10)
	_reaction_use_button.custom_minimum_size = Vector2(150, 44)
	row.add_child(_reaction_use_button)
	_reaction_pass_button = _make_button("넘기기", _on_reaction_pass, 16, Color("495a85"), 10)
	_reaction_pass_button.custom_minimum_size = Vector2(110, 44)
	row.add_child(_reaction_pass_button)
	add_child(_reaction_popup)
	_reaction_popup.reset_size()
	_reaction_popup.position = _board_center() - _reaction_popup.size / 2.0
	_reaction_popup.pivot_offset = _reaction_popup.size / 2.0
	_reaction_popup.scale = Vector2(0.85, 0.85)
	_reaction_popup.create_tween().tween_property(_reaction_popup, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_reaction_popup() -> void:
	if _reaction_popup != null:
		_reaction_popup.queue_free()
		_reaction_popup = null
		_reaction_use_button = null
		_reaction_pass_button = null
	_reaction_key = ""


func _on_reaction_use(holder: int, card_id: StringName) -> void:
	_close_reaction_popup()
	_act(&"play_card", {"player_id": holder, "card_id": card_id})


func _on_reaction_pass() -> void:
	_close_reaction_popup()
	manager.force_timeout()
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
			if card.is_playable_in(manager.current_state) and card.could_play(state, player_id):
				holders.append(player_id)
				break
	return holders


## 종류색 프레임. 손패와 알림 앞면은 같은 재현 가능한 스킨을 쓴다.
func _card_frame_style(category: GameEnums.CardCategory, glow: bool, radius: int = 8) -> StyleBoxFlat:
	return CardSkin.frame(category, glow, radius)


## 크기가 다른 손패와 상세 카드는 텍스트 영역을 각각 배치한다.
func _build_card_body(card_id: StringName, card_size: Vector2, detail_mode: bool = false) -> Control:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var summary: String = str(CARD_SUMMARIES.get(card_id, "")) if detail_mode else str(CARD_SHORT.get(card_id, ""))
	return CardSkin.body(card, card_size, summary, CARD_CATEGORY_NAMES[card.category], detail_mode)


## 한 장짜리 전체 카드 (140x196). 손패에서는 아래 절반이 화면 밖에 가려져 이름과 일러스트가 보이고, 호버하면 올라와 전체가 보인다.
func _make_card_view(player_id: int, card_id: StringName) -> PanelContainer:
	var card: BaseCard = CardRegistry.get_card(card_id)
	var usable: bool = _card_usable_now(player_id, card)
	var view := PanelContainer.new()
	view.custom_minimum_size = HAND_CARD_SIZE
	view.size = HAND_CARD_SIZE
	view.pivot_offset = Vector2(HAND_CARD_SIZE.x / 2.0, HAND_CARD_SIZE.y)
	var idle_style: StyleBoxFlat = _card_frame_style(card.category, false)
	var glow_style: StyleBoxFlat = _card_frame_style(card.category, true)
	view.add_theme_stylebox_override("panel", idle_style)
	view.modulate = Color.WHITE if usable else Color(0.62, 0.62, 0.68)
	view.tooltip_text = "%s (%s) - %s\n%s" % [card.display_name, card_id, _category_text(card.category), CARD_SUMMARIES.get(card_id, "")]
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
	if not _card_usable_now(player_id, card):
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
	var timing := _make_label("발동: %s\n방법: %s" % [_card_timing_text(card), how], 14, UiSkin.INK)
	timing.name = "CardTiming"
	timing.custom_minimum_size = Vector2(card_size.x - 24.0, 0)
	timing.size = Vector2(card_size.x - 24.0, 40)
	timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_box.add_child(timing)
	var usable: bool = _card_usable_now(player_id, card)
	var status := _make_label("지금 사용 가능" if usable else "지금은 사용 불가", 14, Color("416c2b") if usable else Color("747c64"))
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
	var names: Array[String] = []
	for phase: int in card.playable_phases:
		var full: String = PHASE_NAMES.get(phase, "")
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
	_tip_title.text = "%s  - P%d%s" % [PawnCatalog.full_name(pawn.kind, pawn.unit_no), pawn.owner_id, status]
	_tip_ability.text = "◆ 패시브: %s" % PawnCatalog.ability_text(pawn.kind, pawn.unit_no)
	var skill: StringName = PawnCatalog.skill_of(pawn.sub_type())
	_tip_skill.visible = skill != &""
	if skill != &"":
		_tip_skill.text = "◆ [1회] %s%s\n   %s" % [PawnCatalog.skill_name(skill), "  (사용됨)" if pawn.skill_used else "", PawnCatalog.skill_text(skill)]


func _bind_tip(control: Control, provider: Callable) -> void:
	control.mouse_entered.connect(_tip_begin.bind(control, provider))
	control.mouse_exited.connect(_tip_end.bind(control))


func _tip_begin(source: Variant, provider: Callable) -> void:
	_tip_source = source
	_tip_provider = provider
	_tip_clock = 0.0
	_tip_panel.visible = false


func _tip_end(source: Variant = null) -> void:
	if source != null and _tip_source != source:
		return
	_tip_source = null
	_tip_clock = 0.0
	if _tip_panel != null:
		_tip_panel.visible = false


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
		_tip_provider.call()
		_tip_panel.visible = true
		_tip_panel.reset_size()
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var spot: Vector2 = pointer + Vector2(16, 18)
	var limit: Vector2 = Vector2(1366, 768) - _tip_panel.size - Vector2(4, 4)
	if spot.x > limit.x:
		spot.x = pointer.x - _tip_panel.size.x - 12.0
	_tip_panel.position = Vector2(clampf(spot.x, 4.0, limit.x), clampf(spot.y, 4.0, limit.y))


## 보드 위의 아무 말(상대 말 포함) 위에 커서가 있으면 그 말의 툴팁을 예약한다.
func _update_board_pawn_tip(pointer: Vector2) -> void:
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
	var key: String = "board:%d" % found
	if found == -1:
		if _tip_source is String and str(_tip_source).begins_with("board:"):
			_tip_end()
	elif _tip_source != key:
		_tip_begin(key, _fill_pawn_tip.bind(found))


## 기물 설명 텍스트(테스트·로그용): 이름 / 고유 능력 / 필살기.
func _pawn_info_text(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return ""
	var lines: Array[String] = [PawnCatalog.full_name(pawn.kind, pawn.unit_no), "◆ 패시브: %s" % PawnCatalog.ability_text(pawn.kind, pawn.unit_no)]
	if pawn.is_promoted_shogi():
		lines.append("나리(成り) 승급 상태: %s - 이동할 때마다 +1칸" % pawn.display_label())
	var skill: StringName = PawnCatalog.skill_of(pawn.sub_type())
	if skill != &"":
		lines.append("◆ [1회] %s: %s%s" % [PawnCatalog.skill_name(skill), PawnCatalog.skill_text(skill), " (사용됨)" if pawn.skill_used else ""])
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
		skill_button.mouse_exited.connect(_tip_end.bind(skill_button))
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
		_pawn_bar.add_child(button)
		_pawn_buttons.append(button)
		_pawn_slot_parts.append({"letter": letter, "place": place, "badge": badge})


## 내 프로필 위의 감정 표현 버튼 5개: 누르면 내 아바타가 반응하고, 온라인이면 상대 화면의 내 아바타도 같은 반응을 한다.
const EMOTE_BUTTONS: Array[Dictionary] = [
	{"emotion": AvatarSlot.Emotion.HAPPY, "text": "웃음", "color": Color("e0a100")},
	{"emotion": AvatarSlot.Emotion.ANGRY, "text": "분노", "color": Color("c92a2a")},
	{"emotion": AvatarSlot.Emotion.SURPRISED, "text": "놀람", "color": Color("1971c2")},
	{"emotion": AvatarSlot.Emotion.SAD, "text": "낙담", "color": Color("5f6b7a")},
	{"emotion": AvatarSlot.Emotion.CHEER, "text": "환호", "color": Color("2b8a3e")},
]
const EMOTE_COOLDOWN_MSEC: int = 1200


func _build_emote_row() -> void:
	_emote_row = HBoxContainer.new()
	_emote_row.name = "EmoteRow"
	_emote_row.position = Vector2(1030, 554)
	_emote_row.size = Vector2(320, 32)
	_emote_row.add_theme_constant_override("separation", 6)
	add_child(_emote_row)
	for entry: Dictionary in EMOTE_BUTTONS:
		var button: Button = _make_button(str(entry["text"]), _on_emote_pressed.bind(int(entry["emotion"])), 13, entry["color"], 8)
		button.custom_minimum_size = Vector2(58, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "내 아바타로 감정 표현 (상대에게도 보입니다)"
		_emote_row.add_child(button)


## 감정 표현은 내 자리를 직접 조작하는 판(AI 대전·온라인)에서만 쓴다. 4인 수동 조작은 기물 독이 같은 자리를 쓴다.
func _refresh_emote_row() -> void:
	if _emote_row != null:
		_emote_row.visible = (ai_mode or net != null) and not manager.is_game_over and _player_ids.has(local_player_id)


func _on_emote_pressed(emotion: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _emote_ready_msec or manager.is_game_over:
		return
	_emote_ready_msec = now + EMOTE_COOLDOWN_MSEC
	_avatar_react(local_player_id, emotion as AvatarSlot.Emotion, 2.0)
	if net != null:
		net.send_emote(emotion)


func _on_net_emote(seat: int, emotion: int) -> void:
	if not _player_ids.has(seat) or seat == local_player_id:
		return
	_avatar_react(seat, emotion as AvatarSlot.Emotion, 2.0)


## 기물 독이 보여 주는 주인: AI 모드는 항상 로컬 플레이어, 4P 수동 모드는 현재 턴 플레이어.
func _dock_owner() -> int:
	return local_player_id if ai_mode else manager.current_player_id()


## 지금 모드에서 실제로 쓰는 필살기 버튼들 (슬롯 순서): AI·온라인은 내 프로필 카드, 수동 4인은 기물 독.
func active_skill_buttons() -> Array[Button]:
	return _skill_buttons if ai_mode else _dock_skill_buttons


func _on_pawn_slot_hover(slot: int) -> void:
	var pawn_id: int = _dock_owner() * 10 + slot + 1
	_preview_pawn(pawn_id)
	_tip_begin(_pawn_buttons[slot], _fill_pawn_tip.bind(pawn_id))


func _on_pawn_slot_unhover(button: Button) -> void:
	_clear_highlight()
	_tip_end(button)


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
		(parts["letter"] as Label).text = letter if letter != "" else "말"
		(parts["letter"] as Label).add_theme_color_override("font_color", Color("ff6b6b") if pawn.is_promoted_shogi() else Color("f8f9fa"))
		var place: String = "완주" if pawn.is_finished else ("대기" if not pawn.has_left_start else "%d번" % pawn.current_tile_idx)
		if pawn.blocked_this_turn or pawn.restrained_turns > 0:
			place = "구속"
		elif pawn.is_imprisoned:
			place = "감옥"
		(parts["place"] as Label).text = place
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
		profile_button.text = "사용됨" if pawn.skill_used else "필살기"
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
		var result := _make_label("", 13, Color("8ce99a"))
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


## 선택 결과 예고: {"text": 카드에 적을 문구, "good": 초록(좋은 결과)/노랑(보통)}.
func _pawn_prediction(pawn: PlayerPawn) -> Dictionary:
	if pawn.is_finished:
		return {"text": "이미 완주했습니다", "good": false}
	if not pawn.is_selectable():
		return {"text": "움직일 수 없음", "good": false}
	if not _can_pick_now(pawn):
		return {"text": "출발 전 말은 후퇴할 수 없음", "good": false}
	var path: Array[int] = _pawn_move_path(pawn)
	if path.is_empty():
		return {"text": "→ 제자리 (이동 없음)", "good": false}
	if path.has(GameEnums.GOAL_TILE) and pawn.has_left_start and pawn.can_finish(state):
		return {"text": "→ 결승선 완주!", "good": true}
	var dest: int = path.back()
	var tile: TileNode = state.board.get_tile(dest)
	var promote_hint: String = ""
	if pawn.kind == GameEnums.PawnKind.SHOGI and not pawn.promoted:
		for step_tile: int in path:
			if GameEnums.SHOGI_PROMOTION_TILES.has(step_tile):
				promote_hint = " +나리!"
				break
	if not state.rulebook.has_law("LAW_01") and GameEnums.JUMP_CORNER_TARGETS.has(dest):
		return {"text": "→ %d번 (점프!)" % int(GameEnums.JUMP_CORNER_TARGETS[dest]), "good": true}
	if tile.tile_type == TileNode.TileType.PORTAL and not state.rulebook.has_law("LAW_01"):
		var warp_target: int = GameEnums.PORTAL_WARP_TARGETS[dest]
		if pawn.sub_type() == GameEnums.PawnSubType.MONO_PLANE:
			warp_target = GameEnums.PLANE_WARP_TARGETS[dest]
		return {"text": "→ %d번 (옷장 워프!)" % warp_target, "good": true}
	var enemies: Array[PlayerPawn] = []
	var allies: Array[PlayerPawn] = []
	for leader: PlayerPawn in state.leaders_at(dest):
		if leader.owner_id != pawn.owner_id:
			enemies.append(leader)
		elif leader != pawn:
			allies.append(leader)
	for enemy: PlayerPawn in enemies:
		if not MoveExecutor.is_capture_immune(state, enemy):
			return {"text": "→ %d번 (적 말 처치!%s)" % [dest, promote_hint], "good": true}
	if tile.tile_type == TileNode.TileType.BAKERY:
		return {"text": "→ %d번 (빵집 카드 획득!%s)" % [dest, promote_hint], "good": true}
	if not allies.is_empty():
		return {"text": "→ %d번 (아군과 합류)%s" % [dest, promote_hint], "good": false}
	return {"text": "→ %d번%s" % [dest, promote_hint], "good": promote_hint != ""}


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
		elif not pawn.has_left_start:
			status = "출발 대기"
		else:
			status = "출전 중 (%d번)" % pawn.current_tile_idx
		(parts["status"] as Label).text = status
		var letter: String = pawn.letter()
		(parts["mark"] as Label).text = letter if letter != "" else "말"
		(parts["disc"] as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		(parts["mark"] as Label).visible = false
		_token_in(parts["disc"], pawn, color, Vector2(22,34),0.95)
		var sub_name: String = "기본 말" if pawn.kind == GameEnums.PawnKind.BASIC else pawn.display_label().split(":")[-1]
		(parts["sub"] as Label).text = sub_name
		var prediction: Dictionary = _pawn_prediction(pawn)
		var result: Label = parts["result"]
		result.text = str(prediction["text"])
		result.add_theme_color_override("font_color", Color("8ce99a") if bool(prediction["good"]) else (Color("ffe066") if can_pick else Color("868e96")))
		var base: Color = Color("1b2236") if can_pick else Color("101319")
		card.disabled = not can_pick
		card.modulate = Color.WHITE if can_pick else Color(1, 1, 1, 0.5)
		card.add_theme_stylebox_override("normal", _style(base, color.lightened(0.1), 3, 12, 6, 0))
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
}


## 도구별 전체 규칙표: [항목, 전진 결과] 행들과 보충 설명. 새로운 방식의 도구는 유저가 모르므로 족보·확률을 전부 보여 준다.
const TOOL_RULES: Dictionary = {
	&"D6": {"rows": [["1 ~ 6 눈금", "나온 눈금만큼"]], "note": "각 눈금 1/6"},
	&"YUT": {"rows": [["빽도 (-1)", "1칸 후퇴"], ["도 (1)", "1칸"], ["개 (2)", "2칸"], ["걸 (3)", "3칸"], ["윷 (4)", "4칸 + 한 번 더!"], ["모 (5)", "5칸 + 한 번 더!"]], "note": "6가지 각 1/6"},
	&"LIFE_ROULETTE": {"rows": [["1 ~ 6, 8 ~ 10", "나온 숫자만큼"], ["7 당첨", "7칸 + 한 번 더!"]], "note": "1 ~ 10 균등 · 원판 돌리기"},
	&"HOLDEM": {"rows": [["노페어", "1칸"], ["원페어", "3칸"], ["투페어", "5칸"], ["트리플", "7칸"], ["스트레이트", "10칸"], ["플러시 이상", "15칸"]], "note": "5장 드로우 · 플러시 이상 15칸"},
	&"CHINCHIRO": {"rows": [["4 눈금", "4칸 (2/6)"], ["5 눈금", "5칸 (2/6)"], ["6 눈금", "6칸 (1/6)"], ["삐끗!", "6칸 후퇴 (1/6)"]], "note": "접시 밖 이탈 = 삐끗"},
	&"SLOT_777": {"rows": [["3개 모두 다름", "1칸"], ["2개 일치", "4칸"], ["3개 일치", "8칸"], ["7 7 7 잭팟", "20칸"]], "note": "릴 3개 · 그림 6종"},
	&"DICE_HWATU": {"rows": [["망통", "0칸, 턴 종료"], ["1~3 / 4~6 / 7~9끗", "2 / 3 / 4칸"], ["1~6 / 7~9땡", "6 / 7칸"], ["장땡·광땡", "8칸"]], "note": "월 합 끝자리 (망통 = 끝자리 0)"},
	&"DICE_MAHJONG": {"rows": [["핑후 (불일치)", "2칸"], ["또이츠 (같은 패 2개)", "3칸"], ["슌쯔 (연속 숫자)", "5칸"], ["커쯔 (같은 패 3개)", "8칸"], ["역만 (8%)", "12칸 + 한 번 더!"]], "note": "역만 = 국사무쌍·대삼원"},
	&"DICE_TAROT": {"rows": [["0. 광대", "-2칸 또는 +7칸"], ["VII. 전차", "6칸"], ["X. 운명의 수레바퀴", "4칸 + 한 번 더!"], ["XII. 매달린 남자", "1칸, 다음 굴림 +8칸"], ["XXI. 세계", "9칸"]], "note": "5장 중 1장 · 축복은 다음 굴림"},
	&"REVOLVER": {"rows": [["방아쇠 1회", "+3칸 누적"], ["최대 누적", "15칸"], ["폭죽 (6칸 중 1칸)", "누적 0칸, 턴 종료"], ["멈추기", "누적한 칸만큼 이동"]], "note": "6칸 중 1칸은 폭죽 · 깃발이 나오면 누적 소멸"},
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
	_tool_main.text = card[2]
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
		var name_label := _make_label(str(pair[0]), 12, UiSkin.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(name_label)
		var value_label := _make_label(str(pair[1]), 12, UiSkin.GREEN)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(value_label)
		_tool_rules.add_child(row)
	_tool_note.text = str(rules.get("note", ""))
	_apply_tool_expand()


func _category_text(category: GameEnums.CardCategory) -> String:
	match category:
		GameEnums.CardCategory.TRAP: return "타일 설치형 (사용 후 보드판의 타일을 클릭)"
		GameEnums.CardCategory.SUMMON: return "중립 NPC 소환형"
	return "즉발·개입형"


func _card_usable_now(player_id: int, card: BaseCard) -> bool:
	if manager.is_game_over or _ui_busy() or manager.stack_offer_pending() or manager.duel_pending() or not card.is_playable_in(manager.current_state):
		return false
	if ai_mode and player_id != local_player_id:
		return false
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and (player_id != manager.current_player_id() or manager.card_played_this_turn()):
		return false
	return true


func _refresh_controls() -> void:
	var player_id: int = manager.current_player_id()
	var current_phase: TurnManager.State = manager.current_state
	var tool: BaseJudgmentTool = state.tools[player_id]
	var over: bool = manager.is_game_over
	var can_roll: bool = not over and (current_phase == TurnManager.State.PHASE_TURN_BEGIN or current_phase == TurnManager.State.PHASE_ROLL_WAIT)
	_roll_button.disabled = not can_roll or _tile_pick_active or _ui_busy() or manager.stack_offer_pending() or manager.duel_pending() or _is_bot_turn()
	_refresh_roll_pad()
	var can_stop: bool = not over and tool.has_pending_state() and current_phase == TurnManager.State.PHASE_ROLL_WAIT
	if tool is ToolRussianRoulette:
		# 러시안 룰렛: [방아쇠 당기기]와 [멈추고 N칸 이동 확정]을 한 세트로 상시 노출한다. 1발도 못 당겼으면 멈추기는 비활성(회색)이고,
		# 누적이 생기면 초록색으로 바뀐다.
		_roll_button.text = "방아쇠\n당기기"
		_set_gun_buttons(true)
		_stop_button.visible = not over
		_stop_button.text = "정지"
		_fire_button.disabled = _roll_button.disabled or _roll_pad.active
		_stop_button.disabled = not can_stop or _tile_pick_active or _is_bot_turn() or _ui_busy() or _roll_pad.active
		_stop_button.modulate = Color(0.55, 1.0, 0.62) if can_stop else Color.WHITE
	else:
		_set_gun_buttons(false)
		_roll_button.text = _roll_button_label(tool)
		_stop_button.visible = can_stop
		_stop_button.text = "멈추고 이동 확정"
		_stop_button.disabled = false
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


func _on_sound_toggle_pressed() -> void:
	GameSession.audio_muted = not GameSession.audio_muted
	GameSession.save_settings()
	Sfx.unlock()
	Sfx.apply_settings()
	_refresh_sound_button()
	Sfx.play(&"ui_click")  # 켜질 때만 들린다 (꺼져 있으면 재생되지 않음)


func _refresh_sound_button() -> void:
	if _sound_button != null:
		_sound_button.text = "소리 꺼짐" if GameSession.audio_muted else "소리 켜짐"
		_sound_button.modulate = Color(1.0, 0.75, 0.75) if GameSession.audio_muted else Color.WHITE


## 주사위 계열 도구인가 (굴림 소리가 주사위 던지는 소리다).
func _is_dice_family(tool: BaseJudgmentTool) -> bool:
	return tool.tool_id == &"D6" or tool.tool_id == &"CHINCHIRO" or tool.tool_id == &"YUT" or String(tool.tool_id).begins_with("DICE_")


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
	return "굴리기"


## 굴림 조작 방식: 차징형(기본 주사위·윷·친치로)은 보드 아래 작은 굴리기 버튼+파워 게이지, 그 외(룰렛 원판·리볼버·홀덤/슬롯 큰 버튼)는 보드 한가운데에 크게 보여 준다.
func _roll_mode_for(tool: BaseJudgmentTool) -> StringName:
	if tool is ToolLifeRoulette:
		return &"wheel"
	if tool is ToolRussianRoulette:
		return &"gun"
	if tool is ToolHoldem or tool is ToolSlot777 or tool is ToolHwatu or tool is ToolMahjong or tool is ToolTarot:
		return &"big"
	return &"charge"


## 내 판정 도구에 맞는 굴림 위젯을 보여 준다.
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
	if mode == &"big" or mode == &"charge":
		_roll_button.text = _roll_button_label(owner_tool)  # 글자를 먼저 바꿔야 새 크기가 이전 글자 폭에 눌리지 않는다
	if mode != _roll_geometry:
		_set_roll_geometry(mode)
	# 굴림 위젯은 굴릴 차례에만 보인다. 굴림이 끝나면 지워서 보드 한가운데가 가리지 않게 한다 (룰렛·리볼버 패드는 돌아가는 연출 중에는 남긴다).
	var roll_phase: bool = not manager.is_game_over and (manager.current_state == TurnManager.State.PHASE_TURN_BEGIN or manager.current_state == TurnManager.State.PHASE_ROLL_WAIT) and not _is_bot_turn()
	_roll_button.visible = wanted == RollPad.Kind.NONE and roll_phase
	if wanted != RollPad.Kind.NONE:
		_roll_pad.visible = roll_phase or _fx_busy or _roll_pad.active
	_gun_row.visible = wanted == RollPad.Kind.REVOLVER and (roll_phase or _fx_busy or _roll_pad.active)
	if mode == &"big" or mode == &"charge":
		_roll_button.text = _roll_button_label(owner_tool)
	_roll_pad.set_enabled(not _roll_button.disabled)
	if wanted == RollPad.Kind.REVOLVER and roll_phase and not _ui_busy():
		var gun_key: String = "%d:%d:%d:%d" % [state.get_instance_id(),state.round_number,_dock_owner(),owner_tool.get_instance_id()]
		_roll_pad.ensure_revolver_prepared(gun_key,owner_tool.has_pending_state())


## 굴림 위젯의 크기·위치를 방식에 맞춘다: charge는 중앙 무대 아래쪽에 작게(120px), 그 외는 보드 한가운데 크게(버튼 190px / 패드 1.9배).
func _set_roll_geometry(mode: StringName) -> void:
	_roll_geometry = mode
	var big: bool = mode != &"charge"
	var diameter: float = 190.0 if mode == &"big" else 120.0
	var center: Vector2 = Vector2(683.0, 335.0) if mode == &"big" else Vector2(683.0, 380.0)
	_roll_button.custom_minimum_size = Vector2(diameter, diameter)
	_roll_button.size = Vector2(diameter, diameter)
	_roll_button.add_theme_font_size_override("font_size", 32 if mode == &"big" else 24)
	_apply_round_button_style(_roll_button, Color("2b8a3e"))
	_set_layout_base(_roll_button, center - Vector2(diameter, diameter) / 2.0)
	_roll_pad.pivot_offset = _roll_pad.size / 2.0
	_roll_pad.scale = Vector2(1.9, 1.9) if big else Vector2.ONE
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
	if _is_bot_turn() and not manager.stack_offer_pending() and current_phase != TurnManager.State.PHASE_INTERRUPT_ROLL and current_phase != TurnManager.State.PHASE_RESOLUTION:
		if net != null and not net.is_bot(manager.current_player_id()):
			return "%s 님의 차례입니다. 기다려 주세요..." % _player_name(manager.current_player_id())
		return "P%d (AI 봇)가 생각하는 중입니다..." % manager.current_player_id()
	if (current_phase == TurnManager.State.PHASE_INTERRUPT_ROLL or current_phase == TurnManager.State.PHASE_RESOLUTION) and not manager.stack_offer_pending():
		return "피해를 입었습니다! 가운데 팝업에서 [바이츠 더 더스트] 발동 여부를 고르세요. 시간이 지나면 자동으로 넘어갑니다."
	if manager.stack_offer_pending():
		return "윷놀이 기물 업기: [업기 (하나로 합체)] 또는 [그냥 두기 (개별 유지)]를 고르세요. (시간이 지나면 자동으로 업기)"
	if _tile_pick_active:
		return "타일 선택 모드: 보드판에서 사용할 타일(초록 테두리)을 클릭하세요. 취소는 ESC 또는 오른쪽 클릭."
	match current_phase:
		TurnManager.State.PHASE_TURN_BEGIN:
			if _tool_has_gauge():
				return "굴리기 버튼(또는 R/Space)을 꾹 눌러 파워 게이지를 채우고 손을 떼면 굴러갑니다. 카드(▣ 표시는 타일 클릭)도 쓸 수 있습니다. (판정 도구: %s)" % tool.display_name
			return "카드(▣ 표시는 타일을 클릭해 설치/소환)를 쓰거나 [굴리기]를 누르세요. (판정 도구: %s)" % tool.display_name
		TurnManager.State.PHASE_ROLL_WAIT:
			if tool.has_pending_state():
				return "계속 당기거나, 멈추고 누적 칸수만큼 이동하세요. 깃발이 나오면 누적이 사라져요!"
			return "다시 굴려야 합니다 (재굴림)." if not manager.move_queue.is_empty() else ("굴리기 버튼을 꾹 눌렀다 떼서 굴리세요." if _tool_has_gauge() else "굴리세요.")
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
	# 손을 뗀 순간의 파워 게이지 값을 연출에 넘긴다 (게이지가 없는 도구·클릭은 0.5).
	_pending_power = _charge_value if _charging and _tool_has_gauge() else 0.5
	_stop_charge()
	if manager.is_game_over or _roll_button.disabled or _ui_busy() or _is_bot_turn():
		return
	var tool: BaseJudgmentTool = state.tools[_dock_owner()]
	# Yut, Mahjong, cards, roulette, slots and the toy gun emit their own
	# material sounds at animation cues. Only dice need the generic clatter.
	if _is_dice_family(tool) and tool.tool_id != &"YUT":
		Sfx.play(&"dice_roll")
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN:
		_act(&"proceed")
	if manager.current_state == TurnManager.State.PHASE_ROLL_WAIT:
		_act(&"roll")


## 굴림 버튼/키를 누르기 시작했다. 주사위·윷이면 파워 게이지가 좌우로 왕복하기 시작한다.
func _begin_charge(by_key: bool) -> void:
	if _charging or _roll_button.disabled or _ui_busy() or manager.is_game_over or _stack_overlay != null or _is_bot_turn():
		return
	if _tile_pick_active:
		return
	_charging = true
	_charge_by_key = by_key
	_charge_clock = 0.0
	_charge_value = 0.0
	_power_bar.visible = _tool_has_gauge() and not instant_roll_for_test
	_power_label.visible = _power_bar.visible
	if _power_bar.visible:
		Sfx.play(&"charge", -4.0, 0.0)


func _on_roll_button_up() -> void:
	# pressed(굴리기 확정)가 먼저 처리된 뒤에도 게이지가 남아 있으면(버튼 밖에서 뗌) 취소한다.
	call_deferred("_stop_charge_if_unconfirmed")


func _stop_charge_if_unconfirmed() -> void:
	if _charging and not _charge_by_key:
		_stop_charge()


func _stop_charge() -> void:
	_charging = false
	_charge_by_key = false
	if _power_bar != null:
		_power_bar.visible = false
		_power_label.visible = false


## 현재 판정 도구가 홀드 & 릴리즈 파워 게이지를 쓰는가 (기본 D6, 친치로, 박달나무 윷).
func _tool_has_gauge() -> bool:
	if state == null:
		return false
	var tool: BaseJudgmentTool = state.tools[manager.current_player_id()]
	return tool.tool_id == &"D6" or tool.tool_id == &"CHINCHIRO" or tool.tool_id == &"YUT"


func _on_stop_pressed() -> void:
	if _stop_button.disabled:
		return
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
	if manager.current_state == TurnManager.State.PHASE_TURN_BEGIN and manager.card_played_this_turn():
		_log_line("카드는 굴리기 전에 턴당 1장만 쓸 수 있습니다.", Color("868e96"))
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
			for law: LawResource in state.rulebook.active_laws_queue:
				options.append({"label": "[%s] %s" % [law.law_id, law.law_name], "value": law.law_id})
			if options.is_empty():
				_log_line("파기할 교칙이 법전에 없습니다.", Color("868e96"))
				return
			_show_choice("이의 있음! 파기할 교칙을 고르세요", options, _play_card_with.bind(player_id, card_id, "law_id"))
		_:
			_act(&"play_card", {"player_id": player_id, "card_id": card_id})


func _play_card_with(value: Variant, player_id: int, card_id: StringName, param_name: String) -> void:
	_act(&"play_card", {"player_id": player_id, "card_id": card_id, param_name: value})


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
	for index: int in GameEnums.TILE_COUNT:
		(_pick_marks[index] as BoardSkin.Ring).visible = targets.has(index)
	_pick_banner.text = "[직항 워프] 날아갈 빵집·코너 고르기"
	_pick_banner.visible = true
	_pick_cancel.visible = true
	_refresh_controls()


## 흑돌 알까기 조준 모드: 마우스를 누른 채 뒤로 당겼다 놓으면 당긴 반대 방향으로 파워만큼 날아간다 (슬링샷).
func _begin_aim(pawn: PlayerPawn) -> void:
	_aim_pawn = pawn.entity_id
	_aim_dragging = false
	_aim_power = 0.0
	_aim_layer.visible = true
	_aim_line.clear_points()
	_aim_label.text = ""
	_pick_banner.text = "[알까기] 누른 채 뒤로 당겼다 놓기 (ESC 취소)"
	_pick_banner.visible = true
	_pick_cancel.visible = true
	_refresh_controls()


func _cancel_aim() -> void:
	if _aim_pawn == -1:
		return
	_aim_pawn = -1
	_aim_dragging = false
	if _aim_layer != null:
		_aim_layer.visible = false
	if _pick_banner != null and not _tile_pick_active:
		_pick_banner.visible = false
		_pick_cancel.visible = false
	if manager != null and manager.state != null:
		_refresh_controls()


## 조준 모드의 마우스 입력. 처리했으면 true.
func _handle_aim_input(event: InputEvent) -> bool:
	if _aim_pawn == -1:
		return false
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_cancel_aim()
			return true
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if _pick_cancel.visible and _pick_cancel.get_global_rect().has_point(button.position):
			return false  # [취소] 버튼은 그대로 눌리게 둔다
		if button.pressed:
			_aim_dragging = true
			_aim_origin = button.position
			_aim_update(button.position)
		elif _aim_dragging:
			_aim_dragging = false
			_aim_fire()
		return true
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _aim_dragging:
		_aim_update(motion.position)
		return true
	return false


## 당긴 벡터(누른 자리 - 현재 자리)로 발사 각도와 파워를 정하고 예상 궤적을 그린다.
func _aim_update(pointer: Vector2) -> void:
	var pull: Vector2 = _aim_origin - pointer
	_aim_power = clampf(pull.length() / AIM_MAX_PULL, 0.0, 1.0)
	if pull.length() > 1.0:
		_aim_angle = pull.angle()
	var pawn: PlayerPawn = state.get_pawn(_aim_pawn)
	if pawn == null:
		return
	var shot: Dictionary = PawnSkills.shot_result(state, pawn, _aim_angle, _aim_power)
	_aim_line.clear_points()
	_aim_line.add_point(_tile_center(pawn.current_tile_idx))
	_aim_line.add_point(_project(shot["to"] as Vector2))
	_aim_line.default_color = Color("ffd43b") if (shot["hits"] as Array).is_empty() else Color("ff6b6b")
	_aim_label.text = "파워 %d%%  명중 %d" % [int(_aim_power * 100.0), (shot["hits"] as Array).size()]
	_aim_label.position = _tile_center(pawn.current_tile_idx) + Vector2(14, -34)


func _aim_fire() -> void:
	if _aim_power < 0.08:
		_aim_label.text = "더 길게 당기세요"
		return
	var pawn_id: int = _aim_pawn
	var angle: float = _aim_angle
	var power: float = _aim_power
	_cancel_aim()
	_act(&"use_skill", {"pawn_id": pawn_id, "angle": angle, "power": power})


func _build_aim_layer() -> void:
	_aim_layer = Node2D.new()
	_aim_layer.z_index = 15
	_aim_layer.visible = false
	add_child(_aim_layer)
	_aim_line = Line2D.new()
	_aim_line.width = 6.0
	_aim_line.default_color = Color("ffd43b")
	_aim_layer.add_child(_aim_line)
	_aim_label = _make_label("", 16, Color("fff3bf"))
	_aim_label.add_theme_constant_override("outline_size", 5)
	_aim_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_aim_layer.add_child(_aim_label)


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
	_log_line("[필살기] %s: %s - %s" % [who, PawnCatalog.skill_name(skill), body.replace("\n", " ")], Color("ffa94d"))
	_announce_gate("1회용 필살기", "[P%d 발동!] %s" % [player_id, PawnCatalog.skill_name(skill)], body, PLAYER_COLORS[player_id], null, 1.3)


## 말을 잡은 쪽(by_player)의 말 중 잡힌 말 자리에 있던 말의 그림. 못 찾으면(함정·중립 기물 등) null.
func _attacker_art(by_player: int, victim_pos: Vector2) -> Texture2D:
	for pawn: PlayerPawn in state.pawns:
		if pawn.owner_id != by_player:
			continue
		if _pawn_views.has(pawn.entity_id) and _pawn_position(pawn).distance_to(victim_pos) <= 40.0:
			return PawnArt.sprite(pawn).get("texture") as Texture2D
	return null


## 처치 컷신을 lead초 뒤에 띄운다 (잡는 말이 먼저 도착해야 하므로).
func _show_kill_cutin(attacker_art: Texture2D, lead: float) -> void:
	var start_cutin: Callable = func() -> void:
		if not is_inside_tree():
			return
		var cutin := KillCutIn.new()
		add_child(cutin)
		cutin.play(self, attacker_art, _pace())
	if lead <= 0.01:
		start_cutin.call()
	else:
		get_tree().create_timer(lead).timeout.connect(start_cutin)


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
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int(1.1 * pace * 1000.0))


## 맞은 말의 주인 프로필이 억울해한다.
func _react_hit_pawn(pawn_id: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn == null:
		return
	var owner_id: int = pawn.owner_id
	# 총알이 날아가(0.35초) 맞은 뒤에 반응한다
	_fx_when_announced(func() -> void:
		get_tree().create_timer(0.35 * _motion_pace() + 0.1).timeout.connect(func() -> void:
			_profile_react(owner_id, false, ["[억까!]", "[으악!]"][randi() % 2])))


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
	_fx_pending.append(func() -> void:
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
		_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int((0.3 * pace + 0.5) * 1000.0)))


## 흑돌 알까기 연출을 미리 만들어 둔다 (이 시점에는 말들이 아직 옛 자리에 있다):
## 뒤로 살짝 당김 -> 직선으로 발사(맞은 말은 닿는 순간 튕겨 나감) -> 멈춘 자리에서 가까운 타일로 자리를 다시 잡음.
func _prepare_shoot_fx(data: Dictionary) -> void:
	if not _fx_on():
		return
	var shooter_id: int = int(data["pawn_id"])
	var shooter: PlayerPawn = state.get_pawn(shooter_id)
	var view: Node2D = _pawn_views.get(shooter_id)
	if shooter == null or view == null:
		return
	var shot: Dictionary = PawnSkills.shot_result(state, shooter, float(data["angle"]), float(data["power"]))
	var start: Vector2 = view.position
	var free_end: Vector2 = _project(shot["to"] as Vector2)
	var distance: float = maxf(start.distance_to(free_end), 1.0)
	var direction: Vector2 = (free_end - start) / distance
	var victims: Array[Dictionary] = []
	for hit: Variant in data["hits"]:
		var victim_id: int = int((hit as Dictionary)["pawn_id"])
		var victim_view: Node2D = _pawn_views.get(victim_id)
		var victim: PlayerPawn = state.get_pawn(victim_id)
		if victim_view == null or victim == null:
			continue
		var along: float = clampf((victim_view.position - start).dot(direction) / distance, 0.08, 1.0)
		victims.append({"id": victim_id, "pos": victim_view.position, "frac": along, "color": PLAYER_COLORS[victim.owner_id]})
	_fx_pending.append(func() -> void: _play_shoot_fx(shooter_id, start, free_end, direction, distance, victims))


func _play_shoot_fx(shooter_id: int, start: Vector2, free_end: Vector2, direction: Vector2, distance: float, victims: Array[Dictionary]) -> void:
	var view: Node2D = _pawn_views.get(shooter_id)
	if view == null:
		return
	var pace: float = _motion_pace()
	var t_pull: float = 0.25 * pace
	var t_fly: float = clampf(0.4 + distance / 1000.0, 0.45, 0.85) * pace
	var t_settle: float = 0.3 * pace
	var base_scale: float = view.scale.x
	_kill_fx(view)
	view.visible = true
	view.position = start
	view.z_index = 6
	var tween: Tween = create_tween()
	tween.tween_property(view, "position", start - direction * 16.0, t_pull).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(view, "scale", Vector2.ONE * base_scale * 1.3, t_pull)
	tween.tween_callback(func() -> void: _fx_trail(view, t_fly, Color("ced4da")))
	tween.tween_property(view, "position", free_end, t_fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(view, "scale", Vector2.ONE * base_scale, t_fly)
	tween.tween_interval(t_settle)
	tween.tween_callback(_fx_script_done.bind(view))
	view.set_meta("fx", tween)
	view.set_meta("fx_script", true)
	var total: float = t_pull + t_fly + t_settle
	for victim: Dictionary in victims:
		var victim_view: Node2D = _pawn_views.get(int(victim["id"]))
		if victim_view == null:
			continue
		var hit_at: float = t_pull + t_fly * (1.0 - sqrt(1.0 - float(victim["frac"])))
		var vpos: Vector2 = victim["pos"]
		_kill_fx(victim_view)
		victim_view.visible = true
		victim_view.position = vpos
		victim_view.z_index = 5
		var vt: Tween = create_tween()
		vt.tween_interval(hit_at)
		vt.tween_callback(func() -> void:
			_impact_ring(vpos, victim["color"], 30.0)
			screen_shake(7.0, 0.2))
		# 당구공처럼 충돌 방향과 화면 가장자리 방향이 섞인 쪽으로 튕겨 나간다
		var outward: Vector2 = (vpos - _board_center()).normalized()
		var knock: Vector2 = (direction * 0.6 + outward * 0.4).normalized() * 72.0
		vt.tween_property(victim_view, "position", vpos + knock, 0.22 * pace).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		vt.parallel().tween_property(victim_view, "rotation", TAU, 0.22 * pace)
		vt.tween_interval(0.12 * pace)
		vt.tween_callback(_fx_script_done.bind(victim_view))
		victim_view.set_meta("fx", vt)
		victim_view.set_meta("fx_script", true)
		_set_hint(int(victim["id"]), {"arc": 110.0, "spin": -2.0 * TAU, "dur": 0.45, "land_thud": true})
		total = maxf(total, hit_at + 0.34 * pace)
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int(total * 1000.0) + 80)


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


## 알림 카드가 끝난 뒤(문이 열린 뒤, 카드가 없으면 바로) 실행한다.
func _fx_when_announced(action: Callable) -> void:
	if not _fx_on():
		return
	if _fx_holding():
		_fx_pending.append(action)
	else:
		action.call()


## 알림 카드가 가리고 있어서 말을 움직이면 안 되는 때인가.
func _fx_holding() -> bool:
	return _stage_warps > 0 or (_announcer != null and _announcer.active and not _fx_gate_open)


## 문으로 등록한 알림 한 건이 끝났다: 말 움직임 연출을 시작하고, 다음 알림은 그 연출이 끝난 뒤에 띄운다.
func _on_announcer_entry_finished(serial: int) -> void:
	if state == null or not _fx_gates.has(serial):
		return
	_fx_gates.erase(serial)
	_fx_gate_open = true
	_fx_after_announcer()
	_refresh_pawns()
	_announcer.hold_until_msec = maxi(_announcer.hold_until_msec, _fx_until_msec)


## 알림 카드가 끝났다: 모아 둔 걸음을 이어서 보여 주고, 예약된 연출(필살기 등)을 시작한다.
func _fx_after_announcer() -> void:
	if not _fx_on():
		_fx_pending.clear()
		_fx_step_queue.clear()
		return
	for pawn_id: int in _fx_step_queue.keys():
		var view: Node2D = _pawn_views.get(pawn_id)
		var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
		if view == null or pawn == null:
			continue
		_play_queued_steps(view, _fx_step_queue[pawn_id])
	_fx_step_queue.clear()
	var pending: Array[Callable] = _fx_pending.duplicate()
	_fx_pending.clear()
	for action: Callable in pending:
		action.call()
	_fx_hint_bonus = 0.0


## 모아 둔 걸음들을 한 칸씩 통통 튀며 이어서 보여 준다.
func _play_queued_steps(view: Node2D, steps: Array) -> void:
	if steps.is_empty() or view.has_meta("fx_script"):
		return
	_kill_fx(view)
	view.visible = true
	var step_time: float = HOP_SECONDS * minf(_motion_pace(), 1.5)
	var tween: Tween = create_tween()
	var origin: Vector2 = view.position
	for step: Dictionary in steps:
		var target: Vector2 = step["pos"]
		var from_pos: Vector2 = origin
		tween.tween_method(_apply_hop.bind(view, from_pos, target, view.scale.x, float(step["scale"]), HOP_HEIGHT, 1.0, 0.0, 0.0), 0.0, 1.0, step_time)
		tween.tween_callback(_fx_land.bind(view, int(step.get("tile", -1)), false))
		origin = target
	tween.tween_callback(_fx_script_done.bind(view))
	view.set_meta("fx", tween)
	view.set_meta("fx_script", true)
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int(step_time * steps.size() * 1000.0) + 80)


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
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int((delay + duration) * 1000.0) + 60)


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
	var drop_seconds: float = 0.55 * _motion_pace()
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int((delay + duration + drop_seconds) * 1000.0) + 120)


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


## 홈런 뒤: 화면 밖에 있던 말을 출발선 타일 위에서 위로부터 떨어뜨린다.
func _homerun_return(view: Node2D, to_pos: Vector2, to_scale: float, land_thud: bool) -> void:
	if not is_instance_valid(view):
		return
	if view.has_meta("trail_step"):
		view.remove_meta("trail_step")
	view.rotation = 0.0
	_glide.call_deferred(view, to_pos, to_scale, {"drop": true, "land_thud": land_thud})


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
	_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int(duration * 1000.0) + 60)


## 상태가 바뀐 뒤 말의 화면 자리를 맞춘다: 자리가 달라졌으면 순간이동 대신 포물선으로 움직이고(힌트가 있으면 그 모양으로), 끝나면 보이기/숨기기를 정한다.
func _settle_pawn_view(view: Node2D, pawn: PlayerPawn) -> void:
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


## 뱅! 저격 연출: 쏜 사람의 프로필에서 총알이 날아가 맞는 말에 충격 링이 번쩍이고, 그 말이 2칸 뒤로 밀려난다 (카드가 끝난 뒤).
func _fx_bang(shooter: int, target_pawn_id: int) -> void:
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
	_set_hint(target_pawn_id, {"arc": 0.0, "dur": 0.5, "delay": 0.45})
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
		_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int((flight + 0.5 * _motion_pace()) * 1000.0) + 120))


# ---------------------------------------------------------------------------
# 게임 필(타격감): 화면 흔들림 / 착지 찌그러짐 / 발자국 파동 / 파편 / 플로팅 배지
# ---------------------------------------------------------------------------

## 보드 화면 전체가 intensity(px)만큼 duration초 동안 점점 약해지며 흔들린다.
func screen_shake(intensity: float, duration: float) -> void:
	if not _fx_on():
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
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.z_index = 18
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 110.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2(0.0, 320.0)
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.0
	particles.color = color
	_pawn_layer.add_child(particles)
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free())


## 말이 지나간 자리에 남는 잔상: seconds 동안 짧은 간격으로 흐려지는 원을 남긴다.
func _fx_trail(view: Node2D, seconds: float, color: Color) -> void:
	if not _fx_on():
		return
	var loops: int = maxi(int(seconds / 0.03), 1)
	var tween: Tween = create_tween().set_loops(loops)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(view):
			return
		var ghost := Polygon2D.new()
		ghost.polygon = _circle_points(PAWN_RADIUS, 14)
		ghost.color = Color(color.r, color.g, color.b, 0.55)
		ghost.position = view.position
		ghost.scale = view.scale
		ghost.z_index = 3
		_pawn_layer.add_child(ghost)
		var fade: Tween = ghost.create_tween().set_parallel(true)
		fade.tween_property(ghost, "modulate:a", 0.0, 0.28)
		fade.tween_property(ghost, "scale", view.scale * 0.4, 0.28)
		fade.chain().tween_callback(ghost.queue_free))
	tween.tween_interval(0.03)


## 모서리 프로필의 즉각 반응: 좋은 일이면 경쾌하게 점프 + 축하 파편 + 칭찬 배지, 나쁜 일이면 붉게 점멸 + 좌우로 격하게 흔들림 + 억울 배지.
func _profile_react(player_id: int, good: bool, text: String) -> void:
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
	_floating_badge(rect.position + Vector2(rect.size.x * 0.5, 6.0), text, Color("ffe066") if good else Color("ff8787"))


## 위로 솟아올랐다 사라지는 플로팅 텍스트 배지.
func _floating_badge(at: Vector2, text: String, color: Color) -> void:
	var label := _make_label(text, 24, color)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color("1b1405"))
	label.z_index = 60
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = at - label.get_minimum_size() / 2.0
	label.pivot_offset = label.get_minimum_size() / 2.0
	label.scale = Vector2(0.4, 0.4)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 56.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.75)
	tween.chain().tween_callback(label.queue_free)


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


## 번쩍 커지며 사라지는 원 (충돌·벼락 표시).
func _impact_ring(at: Vector2, color: Color, radius: float) -> void:
	if not is_inside_tree():
		return
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = color.lightened(0.4)
	ring.closed = true
	for point: Vector2 in _circle_points(1.0, 24):
		ring.add_point(point)
	ring.position = at
	ring.scale = Vector2.ONE * (PAWN_RADIUS * 0.6)
	ring.z_index = 17
	_pawn_layer.add_child(ring)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * radius, 0.3 * _motion_pace()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3 * _motion_pace())
	tween.chain().tween_callback(ring.queue_free)


## 맞은 말의 자리에서 화면 밖으로 튕겨 나가는 원형 잔상.
func _fly_away(from: Vector2, direction: Vector2, color: Color) -> void:
	var ghost := Polygon2D.new()
	ghost.polygon = _circle_points(PAWN_RADIUS * 2.0, 16)
	ghost.color = color
	ghost.position = from
	ghost.z_index = 18
	_pawn_layer.add_child(ghost)
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
# ACT_09 가위바위보 결투 (중앙 오픈 스테이지)
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
			_log_line("[결투] %s가 %s에게 가위바위보 결투를 신청했습니다!" % [_player_name(int(data["challenger"])), _player_name(int(data["defender"]))], Color("ffd43b"))
			if _fx_on():
				_open_duel_arena(int(data["challenger"]), int(data["defender"]))
		&"duel_revealed":
			var picks: Dictionary = data["picks"]
			_log_line("[결투] %s %s : %s %s → %s" % [_player_name(int(data["challenger"])), DuelRules.HAND_NAMES[int(picks[int(data["challenger"])])], DuelRules.HAND_NAMES[int(picks[int(data["defender"])])], _player_name(int(data["defender"])), "무승부" if int(data["winner"]) == -1 else "%s 승" % _player_name(int(data["winner"]))], Color("ffd43b"))
		&"duel_resolved":
			_on_duel_resolved(data)
	if _duel_arena != null and is_instance_valid(_duel_arena):
		_duel_arena.push_event(kind, data)
	elif not _fx_on():
		_duel_auto_drive.call_deferred()


func _open_duel_arena(challenger: int, defender: int) -> void:
	if _duel_arena != null and is_instance_valid(_duel_arena):
		_duel_arena.queue_free()
	var seats: Array[int] = []
	for seat: int in [challenger, defender]:
		if _duel_local(seat):
			seats.append(seat)
	_duel_arena = DuelArena.new()
	_duel_arena.setup(self, challenger, defender, seats)
	_duel_arena.hand_chosen.connect(func(player_id: int, hand: int) -> void: _act(&"duel_pick", {"player_id": player_id, "hand": hand}))
	_duel_arena.timed_out.connect(_on_duel_timed_out)
	_duel_arena.strike_started.connect(_on_duel_strike_started)
	_duel_arena.strike_ended.connect(_clear_duel_strike_marks)
	_duel_arena.closed.connect(func() -> void:
		_clear_duel_strike_marks()
		_duel_arena = null
		_refresh_all())
	add_child(_duel_arena)
	# 카드 발동 알림이 끝난 뒤 열린다 (그 전에 온 이벤트는 결투장 큐에 쌓인다).
	_fx_when_announced(_duel_arena.open)
	if not _fx_holding():
		_duel_arena.open()


## 결투 중 시간이 다 됐다: 손은 무작위로, 말은 가장 앞선 말을 민다.
func _on_duel_timed_out(step: StringName, seat: int) -> void:
	if not manager.duel_pending():
		return
	if step == &"pick" and seat != -1:
		_act(&"duel_pick", {"player_id": seat, "hand": randi() % 3})
	elif step == &"strike":
		var duel: Dictionary = manager.pending_duel()
		var front: PlayerPawn = state.front_pawn_of(int(duel["loser"]))
		var candidates: Array = duel["candidates"]
		var pawn_id: int = front.entity_id if front != null and candidates.has(front.entity_id) else int(candidates[0])
		_act(&"duel_strike", {"player_id": int(duel["winner"]), "pawn_id": pawn_id})


## 승자가 내 자리라면 진 사람의 말들이 붉게 깜빡이고 눌러서 고른다.
func _on_duel_strike_started(winner: int, candidates: Array, is_local: bool) -> void:
	_clear_duel_strike_marks()
	if not is_local:
		return
	_duel_strike_winner = winner
	for pawn_id: Variant in candidates:
		var view: Node2D = _pawn_views.get(int(pawn_id))
		if view == null:
			continue
		var ring := Line2D.new()
		ring.points = _circle_points(PAWN_RADIUS * 1.9, 24)
		ring.closed = true
		ring.width = 4.0
		ring.default_color = Color("ff4d4f")
		ring.z_index = 30
		view.add_child(ring)
		var pulse: Tween = ring.create_tween().set_loops()
		pulse.tween_property(ring, "modulate:a", 0.25, 0.3)
		pulse.tween_property(ring, "modulate:a", 1.0, 0.3)
		_duel_strike_marks[int(pawn_id)] = ring


func _clear_duel_strike_marks() -> void:
	for ring: Variant in _duel_strike_marks.values():
		if is_instance_valid(ring):
			(ring as Node).queue_free()
	_duel_strike_marks.clear()
	_duel_strike_winner = -1


func _duel_strike_pawn_at(pointer: Vector2) -> int:
	var best: int = -1
	var best_distance: float = 30.0
	for pawn_id: int in _duel_strike_marks.keys():
		var view: Node2D = _pawn_views.get(pawn_id)
		if view == null:
			continue
		var distance: float = (view.position + _pawn_layer.position).distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = pawn_id
	if best != -1:
		return best
	var tile: int = _tile_at(pointer)
	if tile != -1:
		for pawn_id: int in _duel_strike_marks.keys():
			if state.get_pawn(pawn_id).current_tile_idx == tile:
				return pawn_id
	return -1


func _handle_duel_strike_input(event: InputEvent) -> bool:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return false
	var pawn_id: int = _duel_strike_pawn_at(click.position)
	if pawn_id == -1:
		return false
	var winner: int = _duel_strike_winner
	_clear_duel_strike_marks()
	_act(&"duel_strike", {"player_id": winner, "pawn_id": pawn_id})
	return true


## 결투 결과: 진 사람의 말이 맞아 뒤로 밀린다 (주먹 충격파 -> 반응 -> 미끄러짐). 도착 칸의 함정은 attachment_triggered가 따로 연출한다.
func _on_duel_resolved(data: Dictionary) -> void:
	var pawn_id: int = int(data["pawn_id"])
	if pawn_id == -1:
		return
	var winner: int = int(data["winner"])
	var loser: int = int(data["loser"])
	_log_line("[결투] %s이(가) %s의 %s을(를) %d번 → %d번으로 %d칸 밀어냈습니다!%s" % [_player_name(winner), _player_name(loser), _pawn_name(pawn_id), int(data["from"]), int(data["to"]), DuelRules.RETREAT_STEPS, " (출발선으로 복귀)" if data["sent_to_start"] else ""], Color("ff6b6b"))
	if not _fx_on():
		return
	Sfx.play(&"shot")
	var view: Node2D = _pawn_views.get(pawn_id)
	if view != null:
		var hit_pos: Vector2 = view.position
		_set_hint(pawn_id, {"arc": 0.0, "dur": 0.5, "delay": 0.55})
		_fx_until_msec = maxi(_fx_until_msec, Time.get_ticks_msec() + int(1100.0 * _motion_pace()))
		get_tree().create_timer(0.3 * _motion_pace()).timeout.connect(func() -> void:
			screen_shake(9.0, 0.25)
			_impact_ring(hit_pos, Color("ff6b6b"), 54.0)
			_impact_ring(hit_pos, Color.WHITE, 30.0)
			_burst_shards(hit_pos, Color("ff8787"), 12)
			_floating_badge(hit_pos + Vector2(0, -26), "-%d칸!" % DuelRules.RETREAT_STEPS, Color("ff8787"))
			_profile_react(loser, false, "[억까!]")
			_profile_react(winner, true, "[승리!]"))


## 즉시 모드(테스트·ui_smoke): 결투장 없이 내 자리의 손과 밀어낼 말을 바로 고른다.
func _duel_auto_drive() -> void:
	if manager == null or not manager.duel_pending():
		return
	var duel: Dictionary = manager.pending_duel()
	if duel["step"] == &"pick":
		for seat: int in [int(duel["challenger"]), int(duel["defender"])]:
			if _duel_local(seat) and not (duel["picks"] as Dictionary).has(seat):
				_act(&"duel_pick", {"player_id": seat, "hand": randi() % 3})
				break
	elif _duel_local(int(duel["winner"])):
		var front: PlayerPawn = state.front_pawn_of(int(duel["loser"]))
		var candidates: Array = duel["candidates"]
		var pawn_id: int = front.entity_id if front != null and candidates.has(front.entity_id) else int(candidates[0])
		_act(&"duel_strike", {"player_id": int(duel["winner"]), "pawn_id": pawn_id})


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
	_pick_banner.text = "[뱅! 저격] 쏠 상대의 프로필을 눌러 주세요"
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
	for index: int in GameEnums.TILE_COUNT:
		var valid: bool = card.can_play(state, player_id, {"tile": index})
		(_pick_marks[index] as BoardSkin.Ring).visible = valid
		if valid:
			valid_count += 1
	if valid_count == 0:
		_log_line("[%s]를 놓을 수 있는 타일이 없습니다." % card.display_name, Color("868e96"))
		_cancel_tile_pick()
		return
	_pick_banner.text = "[%s] P%d - %s 타일을 고르세요 (초록 테두리)" % [card.display_name, player_id, "함정을 설치할" if card.category == GameEnums.CardCategory.TRAP else "소환할"]
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
	if not card.can_play(state, _tile_pick_player, {"tile": tile}):
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
	if manager.is_game_over and _result_overlay == null:
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
			_start_beat(0.4 / maxf(_pace(), 0.01))
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
	var glyph: String = "?"
	var color: Color = Color("20c997")
	var title: String = definition.display_name
	match definition.category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			var kind: GameEnums.PawnKind = definition.payload
			var unit_no: int = definition.units[0]
			glyph = PawnCatalog.unit_letter(kind, unit_no)
			color = Color("20c997")
			title = "[기물 진화] %s: %s" % [PawnCatalog.display_set_name(kind), PawnCatalog.unit_label(kind, unit_no).split(":")[-1]]
		GameEnums.AugmentCategory.TOOL_SWAP:
			var tool: BaseJudgmentTool = ToolRegistry.create(definition.payload)
			glyph = str((TOOL_CARDS.get(tool.tool_id, ["?"]) as Array)[0])
			color = Color("9775fa")
			title = "[판정 도구] %s" % tool.display_name
		GameEnums.AugmentCategory.LAW_ENACT:
			var law: LawResource = LawRegistry.create(definition.payload)
			glyph = "법"
			color = Color("ffd43b")
			title = "[교칙 제정] %s" % law.law_name
		_:
			glyph = "J"
			color = Color("ff6b6b")
			title = "[카드 패키지] 생떼 카드 2장"
	var lines: PackedStringArray = []
	for line: String in definition.describe(state, player_id).split("\n"):
		if not line.begins_with("※"):
			lines.append(line)
	return {"glyph": glyph, "color": color, "title": title, "desc": "\n".join(lines), "category": AugmentDef.category_name(definition.category), "art": AugmentArt.load_first(AugmentArt.candidates(definition))}


## 150px 후광 / 120px 네온 메달 / 110px 원형 이미지. 이미지가 없으면 글자.
func _make_emblem(glyph: String, color: Color, texture: Texture2D = null) -> Control:
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
	var color: Color = info["color"]
	var card := Button.new()
	card.custom_minimum_size = AUGMENT_CARD_SIZE
	card.size = AUGMENT_CARD_SIZE
	card.pivot_offset = AUGMENT_CARD_SIZE / 2.0
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = false
	var box: StyleBoxFlat = _style(Color("12151f"), color, 3, 16, 8, 0)
	box.shadow_color = Color(color.r, color.g, color.b, 0.35)
	box.shadow_offset = Vector2.ZERO
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(style_name, box)
	var top := Panel.new()
	top.position = Vector2(4, 4)
	top.size = Vector2(AUGMENT_CARD_SIZE.x - 8.0, 172)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _style(color.darkened(0.8), Color(0, 0, 0, 0), 0, 13, 0, 0))
	card.add_child(top)
	var tag := _make_label(str(info["category"]), 12, color.lightened(0.3))
	tag.position = Vector2(12, 8)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tag)
	var emblem: Control = _make_emblem(str(info["glyph"]), color, info.get("art") as Texture2D)
	emblem.position = Vector2((AUGMENT_CARD_SIZE.x - 150.0) / 2.0, 14)
	card.add_child(emblem)
	var title := _make_label(str(info["title"]), 21, Color("ffffff"))
	title.position = Vector2(10, 182)
	title.size = Vector2(AUGMENT_CARD_SIZE.x - 20.0, 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	card.add_child(title)
	var desc := _make_label("", 17, Color("dee2e6"))
	desc.position = Vector2(14, 240)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(AUGMENT_CARD_SIZE.x - 28.0, 0)
	desc.size = Vector2(AUGMENT_CARD_SIZE.x - 28.0, 140)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.text = str(info["desc"])  # 줄바꿈 폭이 정해진 뒤에 글자를 넣어야 라벨이 글자 폭만큼 늘어나지 않는다
	card.add_child(desc)
	if on_pick.is_valid():
		card.pressed.connect(on_pick)
	card.mouse_entered.connect(_hover_augment_card.bind(card, box, color, true))
	card.mouse_exited.connect(_hover_augment_card.bind(card, box, color, false))
	return card


func _hover_augment_card(card: Button, box: StyleBoxFlat, color: Color, entered: bool) -> void:
	var tween: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * (AUGMENT_HOVER_SCALE if entered else 1.0), 0.14)
	tween.tween_property(box, "shadow_size", 34 if entered else 8, 0.14)
	tween.tween_property(box, "shadow_color", Color(1.0, 0.82, 0.25, 0.95) if entered else Color(color.r, color.g, color.b, 0.35), 0.14)
	tween.tween_property(box, "border_color", Color("ffe066") if entered else color, 0.14)
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
		var reroll: Button = _make_button("리롤 완료" if used else "[ 리롤 (1회) ]", _on_augment_reroll.bind(player_id, index), 15, Color("495a85"), 10)
		reroll.custom_minimum_size = Vector2(AUGMENT_CARD_SIZE.x, 40)
		reroll.disabled = used
		reroll.focus_mode = Control.FOCUS_NONE
		slot.add_child(reroll)
		_draft_reroll_buttons.append(reroll)
	if net != null:
		# 온라인에서만 [무작위로 자동 선택]을 둔다 (혼자 하는 판은 군더더기라 뺐다).
		var footer := HBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(footer)
		footer.add_child(_make_button("무작위로 자동 선택", _on_draft_auto_pressed, 13))
	add_child(_draft_overlay)
	if _draft_entrance and _fx_on():
		_draft_entrance = false
		_draft_overlay.position = Vector2(0, 110)
		_draft_overlay.modulate.a = 0.0
		var rise: Tween = _draft_overlay.create_tween().set_parallel(true)
		rise.tween_property(_draft_overlay, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(_draft_overlay, "modulate:a", 1.0, 0.3)


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
	var title := _make_label("어느 말을 [%s]로 진화시킬까요?" % str(info["title"]).split("] ")[-1], 24, Color("ffe066"))
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
		var can_pick: bool = pawn.kind == GameEnums.PawnKind.BASIC and not pawn.is_finished
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
		var action := _make_label("→ %s 진화!" % str(info["glyph"]) if can_pick else "진화 불가", 15, evo_color.lightened(0.4) if can_pick else Color("868e96"))
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
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	var winner_id: int = state.winner
	var title: Label = _make_label("게임 종료!", 34, Color("ffd43b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var summary: Label = _make_label("승리자: %s (P%d)" % [_player_name(winner_id), winner_id], 22, PLAYER_COLORS.get(winner_id, Color.WHITE))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 4)
	box.add_child(facts)
	var rounds: Label = _make_label("플레이한 라운드: %d라운드" % state.round_number, 17, Color("f1f3f5"))
	rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	facts.add_child(rounds)
	var reason: Label = _make_label("승리 요인: %s" % _winner_reason_text().trim_prefix("승리 (").trim_suffix(")"), 17, Color("f1f3f5"))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_child(reason)
	var standings: PackedStringArray = []
	for player_id: int in _player_ids:
		var done: int = 0
		for pawn: PlayerPawn in state.pawns_of(player_id):
			if pawn.is_finished:
				done += 1
		standings.append("P%d %d/%d" % [player_id, done, GameEnums.PAWNS_PER_PLAYER])
	var progress: Label = _make_label("완주한 말  " + "   ".join(standings), 15, Color("adb5bd"))
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	facts.add_child(progress)
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
	add_child(_result_overlay)


var _last_reason: StringName = &""


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


func _clear_highlight() -> void:
	for highlight: BoardSkin.Ring in _highlights.values():
		highlight.visible = false
		highlight.border_width = 3.0
	_board_hover_pawn = -1


# ---------------------------------------------------------------------------
# 엔진 이벤트 -> 화면/로그
# ---------------------------------------------------------------------------

func _on_phase_changed(new_state: TurnManager.State, _player_id: int, _limit: float) -> void:
	if new_state != TurnManager.State.PHASE_ROUND_START:
		_flush_draft_summary()
	_refresh_all()


## 이번 라운드에 모두가 고른 증강을 선택 카드 그림 그대로 한 줄에 나란히 공개한다.
func _flush_draft_summary() -> void:
	if _draft_summary.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_scale: float = 0.6 if _draft_summary.size() > 2 else 0.8
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
	_announce("증강 공개", "선택한 증강", "", Color("ffa94d"), row, 2.8)


func _on_action_rejected(player_id: int, action: StringName, reason: StringName) -> void:
	if net != null and (player_id != local_player_id or String(action).begins_with("__")):
		return  # 온라인: 내 행동이 거부됐을 때만 알린다 (다른 사람의 거부나 늦은 타임아웃은 조용히 넘어간다)
	_log_line("P%d %s 거부: %s" % [player_id, action, REJECT_REASONS.get(reason, str(reason))], Color("ff8787"))


func _on_turn_order_reversed(new_direction: int) -> void:
	_log_line("[리버스] 우노 리버스! 턴 방향이 %s이 되었습니다." % ("정방향" if new_direction == 1 else "역방향"), Color("ffd43b"))
	_refresh_all()


func _on_game_over(winner_id: int, reason: StringName) -> void:
	_last_reason = reason
	Sfx.play(&"win")
	for player_id: int in _player_ids:
		_avatar_react(player_id, AvatarSlot.Emotion.CHEER if player_id == winner_id else AvatarSlot.Emotion.SAD, 0.0)
	_log_line("[승리] P%d 승리! - %s" % [winner_id, VictoryChecker.reason_text(reason)], PLAYER_COLORS[winner_id])
	_close_draft_overlay()
	_cancel_tile_pick()
	_show_result_overlay()
	_refresh_all()


func _ui_busy() -> bool:
	return _intro_blocks() or _fx_busy or _aim_pawn != -1 or (_announcer != null and _announcer.active) or Time.get_ticks_msec() < _beat_until_msec or (_fx_on() and Time.get_ticks_msec() < _fx_until_msec)


## 행동이 끝난 뒤 잠깐(초) 입력과 봇 행동을 멈춰, 플레이어가 방금 일어난 일을 알아볼 틈을 준다.
func _start_beat(seconds: float) -> void:
	if instant_roll_for_test or not pacing_enabled or seconds <= 0.0:
		return
	_beat_until_msec = maxi(_beat_until_msec, Time.get_ticks_msec() + int(seconds * _pace() * 1000.0))
	get_tree().create_timer(seconds * _pace() + 0.02).timeout.connect(func() -> void:
		if manager != null and state != null:
			_refresh_all())


func _announce(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5) -> int:
	if _announcer == null:
		return -1
	_announcer.instant = instant_roll_for_test
	var serial: int = _announcer.announce(tag, headline, body, color, extra, duration * _pace())
	if _announcer.active:
		_refresh_controls()
	return serial


## 알림 카드가 끝난 직후 말 움직임 연출이 이어지도록 이 카드를 [문]으로 등록한다 (카드가 보드를 가리는 동안에는 말이 먼저 움직이지 않는다).
func _announce_gate(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5) -> void:
	var serial: int = _announce(tag, headline, body, color, extra, duration)
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
	_announce("법전 개정", "새 교칙: %s" % new_law.law_name, body, COLOR_GOLD, board, 2.6)


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
	var text: String = "[법전] 교칙 제정: [%s] %s" % [new_law.law_id, new_law.law_name]
	if removed_law != null:
		text += "  (가장 오래된 [%s] %s이(가) 밀려났습니다)" % [removed_law.law_id, removed_law.law_name]
	_log_line(text, Color("ffe066"))
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
		_announce("법전 발동", "[%s] %s" % [law.law_id, law.law_name], (law.description + detail.strip_edges().insert(0, "\n") if detail != "" else law.description), Color("ffe066"), null, 1.1)
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
		&"roll_boosted":
			_log_line("[긴급 로켓 부스터] P%d: 눈금 %d → %d!" % [data["player_id"], data["from"], data["to"]], Color("ffd43b"))
		&"stack_resolved":
			var stack_names: Array[String] = []
			for member_id: Variant in data["members"]:
				stack_names.append(_pawn_name(int(member_id)))
			if data["stacked"]:
				_log_line("[업기] P%d: %s 하나로 합체!" % [data["player_id"], ", ".join(stack_names)], Color("ffd43b"))
			else:
				_log_line("[업기] P%d: 그냥 두기 - 개별 유지" % data["player_id"], Color("adb5bd"))
		&"move_resolved":
			_log_move(data)
			_start_beat(BEAT_AFTER_MOVE)
			if bool(data.get("jailed", false)) and (data.get("path", []) as Array).is_empty():
				_announce_move_failed("무인도 탈출 실패!", manager.current_player_id(), "짝수 눈금이 나와야 탈출할 수 있습니다")
		&"turn_skipped":
			_announce_move_failed("움직일 수 있는 말이 없어", int(data["player_id"]), "구속 중이거나 선택할 수 있는 말이 없습니다")
		&"card_played":
			_avatar_react(int(data["player_id"]), AvatarSlot.Emotion.HAPPY)
			var card: BaseCard = CardRegistry.get_card(data["card_id"])
			_log_line("[카드] P%d [%s] 사용%s" % [data["player_id"], card.display_name, " (개입 대기열 - 나중에 낸 카드부터 실행)" if data["queued"] else ""], Color("74c0fc"))
			_announce_gate("카드 발동", "[P%d 발동!] %s" % [data["player_id"], card.display_name], ("개입 대기열 등록 (후입선출)\n" if data["queued"] else "") + str(CARD_SUMMARIES.get(data["card_id"], "")), PLAYER_COLORS[int(data["player_id"])], _make_card_preview(data["card_id"]), 1.2)
		&"npc_phase_resolved":
			if not (data["reports"] as Array).is_empty():
				# 중립 NPC 이동: 안내 카드가 먼저 뜨고(0.6초), 카드가 끝난 뒤 한 칸 점프(0.35초)하며, 말을 잡으면 처치 알림이 이어진다.
				_announce_gate("중립 기물", "[중립 NPC 이동]", "도적·고스트가 한 칸 움직입니다", Color("fa5252"), null, 0.6)
			for report: Dictionary in data["reports"]:
				_log_line("[NPC] NPC가 %s로 이동 (잡힌 말: %s)" % [str(report["path"]), str(report["caught"])], Color("fa5252"))
				if not (report["caught"] as Array).is_empty():
					var npc_name: String = "도적" if report["display_id"] == &"SUM_01" else "고스트"
					var stolen: String = ""
					if not (report["stolen_cards"] as Array).is_empty():
						stolen = " / 카드 %d장 강탈" % (report["stolen_cards"] as Array).size()
					_announce("중립 기물", "%s가 말을 잡았습니다!" % npc_name, "잡힌 말 %d개%s" % [(report["caught"] as Array).size(), stolen], Color("fa5252"), null, 1.5)
		&"augment_offers":
			_log_line("[증강] 라운드 %d 증강 드래프트가 열렸습니다." % data["round"], Color("ffa94d"))
		&"augment_picked":
			_log_line("[증강] P%d%s: %s - %s" % [data["player_id"], " (자동)" if data["auto"] else "", AugmentRegistry.get_def(data["augment_id"]).display_name, data["text"]], Color("ffa94d"))
			# 한 명씩 공개하면 늘어지므로 모아 두었다가 드래프트가 끝나면 한 장으로 한꺼번에 공개한다.
			_draft_summary.append({"player": int(data["player_id"]), "augment": data["augment_id"]})
		&"bang_resolved":
			var target_name: String = _pawn_name(int(data["target"]))
			_log_line("[뱅!] P%d가 %s을(를) 저격! %d번 → %d번 타일로 2칸 밀려납니다." % [data["shooter"], target_name, data["from"], data["to"]], Color("ff6b6b"))
			_fx_bang(int(data["shooter"]), int(data["target"]))
			_react_hit_pawn(int(data["target"]))
		&"duel_started", &"duel_pick_in", &"duel_revealed", &"duel_strike_wait", &"duel_resolved":
			_on_duel_event(kind, data)
		&"skill_used": _on_skill_used(data)
		&"pawn_pushed_back":
			_log_line("[백돌 무적] 백돌에 막혀 %s이(가) %d번 → %d번으로 밀려났습니다" % [_pawn_name(int(data["pawn_id"])), data["from"], data["to"]], Color("b197fc"))
		&"bomb_applied":
			_log_line("[우노 +4] P%d의 %s이(가) 4칸 후퇴 (%d번 → %d번)" % [data["victim"], _pawn_name(int(data["pawn_id"])), data["from"], data["to"]], Color("ffd43b"))
			_fx_bang(int(data["shooter"]), int(data["pawn_id"]))
			_react_hit_pawn(int(data["pawn_id"]))
		&"game_over":
			_last_reason = data["reason"]
	_refresh_all()


func _log_roll(data: Dictionary) -> String:
	var result: Dictionary = data["result"]
	var details: Dictionary = result["details"]
	var prefix: String = "[굴림] P%d [%s] " % [data["player_id"], state.tools[data["player_id"]].display_name]
	var text: String = ""
	match result["tool_id"]:
		&"YUT": text += "%s (%d칸)" % [YUT_NAMES.get(result["steps"], "?"), result["steps"]]
		&"HOLDEM": text += "%s → %d칸" % [HAND_NAMES.get(details["hand"], "?"), result["steps"]]
		&"SLOT_777":
			var symbols: Array[String] = []
			for reel: int in details["reels"]:
				symbols.append(SLOT_SYMBOLS[reel])
			text += "%s → %d칸" % [" | ".join(symbols), result["steps"]]
		&"CHINCHIRO":
			text += "%d칸" % result["steps"] if not details["oops"] else "삐끗! 주사위가 접시 밖으로 (-6칸 후퇴)"
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
			text += "%s → %d칸" % [details["name"], result["steps"]]
			if details.has("bonus"):
				text += "  (매달린 남자의 축복 +%d칸 포함)" % int(details["bonus"])
			if details.has("blessing_booked"):
				text += "  다음 굴림에 +%d칸 축복 예약!" % int(details["blessing_booked"])
		&"REVOLVER":
			if details["fired"]:
				text += "뿅! 깃발 발사 · 누적 %d칸 사라짐, 턴 종료" % details["lost"]
			else:
				text += ("%d칸 이동 확정" if details.get("voluntary",false) or not result.get("can_continue",false) else "찰칵! 누적 %d칸") % result["steps"]
		_: text += "%d칸" % result["steps"]
	if result["reroll"]:
		text += "  ★ 재굴림!"
	_log_line(prefix + text, Color("f1f3f5"))
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
	if data["pushed_back"]:
		text += "  [백돌 무적] 막혀서 한 칸 후퇴"
	if data["hotel_built"]:
		text += "  호텔 건설"
	if int(data["salary_cards"]) > 0:
		text += "  [미니카] 출발선 통과: 카드 %d장" % data["salary_cards"]
	if data["drawn_card"] != &"":
		text += "  [빵집] 카드 획득"
	if not (data["effects"] as Array).is_empty():
		text += "  교칙 효과 %s" % str(data["effects"])
	_log_line(text, PLAYER_COLORS[state.get_pawn(pawn_id).owner_id])


func _log_line(text: String, color: Color) -> void:
	if _log == null:
		return
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	# 상단 리본의 토스트: 가장 최근 이벤트 한 줄 요약
	if _toast_label != null:
		_toast_label.text = text
		_toast_label.add_theme_color_override("font_color", color.lightened(0.25))


func _pawn_name(pawn_id: int) -> String:
	var pawn: PlayerPawn = state.get_pawn(pawn_id) if state != null else null
	if pawn == null:
		return "말#%d" % pawn_id
	return "P%d-말%d" % [pawn.owner_id, pawn.slot]


func _card_name(card_id: StringName) -> String:
	var card: BaseCard = CardRegistry.get_card(card_id)
	return card.display_name if card != null else str(card_id)


func _attachment_name(attachment_id: String) -> String:
	match attachment_id:
		"TRP_01": return "거울의 힘"
		"TRP_02": return "나락"
		"TRP_03": return "지뢰"
		"TRP_04": return "무인도"
		"TRP_05": return "도미노"
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


## 파워 게이지(굴림 버튼 위)와 판정 도구 연출기를 만든다.
func _build_roll_fx() -> void:
	_power_bar = ProgressBar.new()
	_power_bar.position = Vector2(623, 447)
	_power_bar.size = Vector2(120, 12)
	_power_bar.min_value = 0.0
	_power_bar.max_value = 100.0
	_power_bar.show_percentage = false
	_power_bar.visible = false
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bar.add_theme_stylebox_override("background", _style(Color("0b0e16"), Color("5c6b94"), 2, 9, 0, 0))
	_power_bar.add_theme_stylebox_override("fill", _style(Color("51cf66"), Color("fff3bf"), 2, 7, 0, 0))
	add_child(_power_bar)
	_power_label = _make_label("POWER 0%", 12, Color("fff3bf"))
	_power_label.position = Vector2(623, 462)
	_power_label.size = Vector2(120, 16)
	_power_label.z_index = 2
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.visible = false
	add_child(_power_label)
	_presenter = RollPresenter.new()
	add_child(_presenter)
	_announcer = EventAnnouncer.new()
	add_child(_announcer)
	_announcer.drained.connect(func() -> void:
		if state != null:
			_fx_gate_open = false
			_fx_gates.clear()
			_fx_after_announcer()
			_refresh_all())
	_announcer.entry_finished.connect(_on_announcer_entry_finished)


## 엔진이 확정한 굴림 결과를 연출한 뒤 로그·중앙 배너로 공개한다. 연출 중에는 입력을 잠가 결과가 먼저 새지 않게 한다.
func _handle_roll_event(data: Dictionary) -> void:
	var result: Dictionary = data["result"]
	var tool_id: StringName = result["tool_id"]
	_presenter.instant = instant_roll_for_test
	var details: Dictionary = result["details"]
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
	await _presenter.play(tool_id, result, _pending_power)
	if generation != _fx_generation or serial != _fx_serial:
		return
	_fx_busy = false
	_reveal_roll(data)
	_refresh_all()


## 이동 실패 알림: 결과 카드를 0.9초 보여 주고 프로필이 피격 반응을 한다. 알림이 떠 있는 동안 입력과 봇 행동은 멈춰 있어 다음 차례가 먼저 시작되지 않는다.
func _announce_move_failed(headline: String, player_id: int, body: String = "") -> void:
	_profile_react(player_id, false, "[으악!]")
	_avatar_react(player_id, AvatarSlot.Emotion.SAD, 1.2)
	_announce("이동 실패", "[%s 이번 턴 이동 실패!]" % headline, body, Color("ff6b6b"), null, 0.9)
	_start_beat(0.9)


func _reveal_roll(data: Dictionary) -> void:
	var roll_text: String = _log_roll(data)
	var details: Dictionary = (data["result"] as Dictionary)["details"]
	var fired: bool = bool(details.get("fired", false))
	var roller: int = int(data["player_id"])
	var roll_steps: int = int((data["result"] as Dictionary).get("steps", 0))
	var roll_tool: StringName = (data["result"] as Dictionary).get("tool_id", &"")
	if bool(details.get("oops", false)):
		_profile_react(roller, false, "[으악!]")
	elif (roll_tool == &"SLOT_777" and roll_steps >= 20) or (roll_tool == &"DICE_MAHJONG" and roll_steps >= 12) or (roll_tool == &"HOLDEM" and roll_steps >= 15):
		_profile_react(roller, true, "[나이스!]")
	if bool(details.get("oops", false)):
		_show_center_banner("[친치로 삐끗!] 주사위가 접시 밖으로 나갔습니다! (-6칸 후퇴)", Color("ff6b6b"))
		_announce("지하노역장 친치로", "[친치로 삐끗!]", "주사위가 접시 밖으로 나갔습니다! (-6칸 후퇴)", Color("ff6b6b"), null, 1.3)
		return
	_show_center_banner("P%d  %s" % [data["player_id"], roll_text.strip_edges()], Color("ff8787") if fired else Color("fff3bf"))
	if bool((data["result"] as Dictionary).get("ends_turn", false)):
		# 이동 없이 턴이 끝나는 굴림(러시안 룰렛 실탄·화투 망통): 결과 알림과 피격 반응을 충분히 보여 준 뒤에야 다음 차례로 넘어간다.
		_announce_move_failed("폭죽 깃발!" if fired else "망통!", roller)


## 윷놀이 기물의 [선택적 업기] 팝업: 화면 중앙에 [업기 (하나로 합체)] / [그냥 두기 (개별 유지)] 두 버튼을 띄운다.
func _refresh_stack_overlay() -> void:
	var pending: bool = manager.stack_offer_pending() and not manager.is_game_over
	if not pending:
		_close_stack_overlay()
		return
	if _stack_overlay != null:
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
	var title := _make_label("윷놀이 기물 - 선택적 업기", 20, COLOR_GOLD)
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
	if _menu_is_open():
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	if _menu_is_open():
		return
	_cancel_aim()
	_cancel_tile_pick()
	_stop_charge()
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
	_menu_box.custom_minimum_size = Vector2(380, 0)
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
	item.custom_minimum_size = Vector2(380, 46)
	item.add_theme_font_size_override("font_size", font_size)
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
	_menu_title("메뉴")
	_menu_item(_make_button("계속하기", _close_menu, 17, Color("2b8a3e"), 10))
	_menu_item(_make_button("게임 설정", _show_menu_page.bind(&"settings"), 17, Color("3b4766"), 10))
	_menu_item(_make_button("규칙 책자", _open_rulebook, 17, Color("8a5a0a"), 10))
	# 전체 로그·새 게임·모드 전환은 개발용이라 디버그를 켰을 때만 메뉴에 나온다 (평소엔 게임답게 숨긴다).
	if _debug_enabled:
		_menu_item(_log_toggle)
		if net == null:
			_menu_item(_new_game_button)
			_menu_item(_mode_toggle)
			_menu_item(_debug_toggle)
	_menu_item(_make_button("게임 나가기", _show_menu_page.bind(&"confirm_exit"), 17, Color("7a2a2a"), 10))


## 메뉴의 [규칙 책자]: 게임 위(메뉴보다 위)에 규칙 책자를 연다.
func _open_rulebook() -> void:
	var book: Rulebook = Rulebook.open(self)
	book.z_index = 250


func _build_settings_page() -> void:
	_menu_title("게임 설정")
	var fullscreen_text: String = "전체화면 끄기" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "전체화면 켜기"
	_menu_item(_make_button(fullscreen_text, _on_menu_fullscreen_pressed, 16, Color("3b4766"), 10))
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 8)
	_menu_box.add_child(view_row)
	view_row.add_child(_make_label("보드 시점", 15, Color("ced4da")))
	var view_option := OptionButton.new()
	view_option.name = "ViewMode"
	view_option.add_item("탑뷰 (위에서 내려다봄)")
	view_option.add_item("기울인 탑뷰 (테이블)")
	view_option.select(view_mode)
	view_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_option.item_selected.connect(_on_view_mode_selected)
	view_row.add_child(view_option)
	var pacing := CheckBox.new()
	pacing.name = "PacingCheck"
	pacing.text = "행동 사이에 잠깐 멈춰 보여 주기 (턴 알림·이동 뒤 호흡)"
	pacing.button_pressed = pacing_enabled
	pacing.toggled.connect(_on_pacing_toggled)
	_menu_box.add_child(pacing)
	var pace_row := HBoxContainer.new()
	pace_row.add_child(_make_label("연출 속도", 15, Color("ced4da")))
	var pace_option := OptionButton.new()
	pace_option.name = "PaceOption"
	pace_option.add_item("빠르게")
	pace_option.add_item("보통")
	pace_option.add_item("느리게")
	pace_option.select(0 if GameSession.pace_scale <= 1.2 else (2 if GameSession.pace_scale >= 2.1 else 1))
	pace_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pace_option.item_selected.connect(_on_pace_selected)
	pace_row.add_child(pace_option)
	_menu_box.add_child(pace_row)
	if net == null:
		var timer := CheckBox.new()
		timer.name = "TimerCheck"
		timer.text = "제한 시간 사용 (시간이 지나면 자동 진행)"
		timer.button_pressed = _timer_check != null and _timer_check.button_pressed
		timer.toggled.connect(_on_menu_timer_toggled)
		_menu_box.add_child(timer)
	else:
		var note: Label = _make_label("온라인 대전은 제한 시간이 항상 켜져 있습니다 (3배 길게).", 12, Color("868e96"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_menu_box.add_child(note)
	LobbyTheme.add_audio_controls(_menu_box, Color("ced4da"))
	_menu_item(_make_button("뒤로", _show_menu_page.bind(&"main"), 16, Color("4a3a66"), 10))


func _build_exit_page() -> void:
	_menu_title("게임을 나갈까요?")
	var note: Label = _make_label("나가면 시작 화면으로 돌아갑니다. 진행 중인 판은 저장되지 않으며, 온라인 대전이면 내 자리는 컴퓨터가 이어받습니다." if net != null else "나가면 시작 화면으로 돌아갑니다. 진행 중인 판은 저장되지 않습니다.", 14, Color("ced4da"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(note)
	_menu_item(_make_button("나가기", _on_menu_pressed, 17, Color("7a2a2a"), 10))
	_menu_item(_make_button("취소", _show_menu_page.bind(&"main"), 17, Color("3b4766"), 10))


func _on_menu_fullscreen_pressed() -> void:
	MobileSupport.toggle_fullscreen()
	_show_menu_page(&"settings")


func _on_view_mode_selected(index: int) -> void:
	set_view_mode(index)
	GameSession.save_settings()


func _on_pacing_toggled(enabled: bool) -> void:
	pacing_enabled = enabled
	GameSession.pacing_enabled = enabled
	GameSession.save_settings()
	_apply_pace()


## 연출 속도 배율: 연출 멈춤이 켜져 있고 테스트용 즉시 모드가 아닐 때만 GameSession.pace_scale을 쓴다.
func _pace() -> float:
	return GameSession.pace_scale if pacing_enabled and not instant_roll_for_test else 1.0


## 속도 설정이 바뀌면 걸음 간격·봇 대기에 바로 적용한다 (알림·호흡은 쓸 때마다 _pace()를 읽는다).
func _apply_pace() -> void:
	if manager != null:
		manager.step_delay_sec = STEP_DELAY * _pace()
	if _bot != null:
		_bot.pace = _pace()


func _on_pace_selected(index: int) -> void:
	GameSession.pace_scale = [GameSession.PACE_FAST, GameSession.PACE_NORMAL, GameSession.PACE_SLOW][index]
	GameSession.save_settings()
	_apply_pace()


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


func _on_mode_toggle_pressed() -> void:
	ai_mode = not ai_mode
	_bot.set_enabled(ai_mode)
	_dock_player = -1
	_log_line("[모드] %s" % ("1P vs 3AI 봇: P2~P4를 AI가 조작합니다." if ai_mode else "4P 수동 조작: 모든 플레이어를 직접 조작합니다."), Color("63e6be"))
	_refresh_mode_toggle()
	if manager != null and manager.state != null:
		_refresh_all()


## 지금 턴이 AI 봇의 차례인가 (AI 모드에서 P2~P4).
func _is_bot_turn() -> bool:
	return ai_mode and manager.current_player_id() != local_player_id


## 사람(P1)이 지금 개입 창에서 낼 수 있는 카드를 들고 있는가.
func _human_can_intervene() -> bool:
	for card_id: StringName in state.hands[local_player_id]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card.is_playable_in(manager.current_state) and card.could_play(state, local_player_id):
			return true
	return false


## 봇은 화면의 굴림 연출이 끝날 때까지 기다린다.
func _bot_should_wait() -> bool:
	# 혼자 하는 판은 메뉴를 여는 동안 봇도 쉰다 (온라인은 다른 사람이 기다리므로 멈추지 않는다).
	return _ui_busy() or (net == null and _menu_is_open()) or (_duel_arena != null and _duel_arena.animating)
