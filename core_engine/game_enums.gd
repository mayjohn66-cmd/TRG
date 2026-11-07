# File: res://core_engine/game_enums.gd
# Class: class_name GameEnums
# Role: 코어 엔진 전역 열거형·상수 (페이즈, 타일 타입, 법전 훅 스테이지, 기물 종류, 타이머 상수)
class_name GameEnums
extends RefCounted

enum Phase {
	IDLE,
	ROUND_START,
	TURN_BEGIN,
	ROLL_WAIT,
	INTERRUPT_ROLL,
	SELECT_PAWN,
	MOVING_STEP,
	RESOLUTION,
	NEUTRAL_NPC,
	GAME_OVER,
}

## 기물 세트(계열). BASIC은 아직 진화하지 않은 기본 말이다. 진화한 말은 세트 안에서 1~4호기(unit_no)를 순서대로 받는다.
enum PawnKind { BASIC, YUT, CHESS, JANGGI, MONOPOLY, GO, SHOGI, ARCADE }

## 호기별 세부 기물. (세트, 호기)에서 PawnCatalog.sub_type_of()가 정한다. 체스 퀸은 5번째 호기 번호(CHESS_QUEEN_UNIT)로 표현한다.
enum PawnSubType {
	NONE,
	YUT_MAL,
	CHESS_PAWN, CHESS_KNIGHT, CHESS_BISHOP, CHESS_ROOK, CHESS_QUEEN,
	JANGGI_PO, JANGGI_CHA, JANGGI_MA, JANGGI_SANG,
	MONO_CAR, MONO_PLANE, MONO_SHIP, MONO_DOG,
	BADUK_BLACK, BADUK_WHITE,
	SHOGI_FU, SHOGI_HISHA, SHOGI_KAKU, SHOGI_KEIMA,
	CHECKERS_KING, LUDO_AVENGER, POOL_8BALL, KART_STAR, MINESWEEPER_FLAG,
	MOB_KYUI, ODD_MELON,  # v1.1 아케이드 6·7호기
}

## 체스 폰이 승진해 퀸이 된 뒤의 호기 번호.
const CHESS_QUEEN_UNIT: int = 5

enum AugmentCategory { PAWN_EVOLUTION, TOOL_SWAP, LAW_ENACT, CARD_PACKAGE, SUPER_GAMBLE, UTILITY }

enum CardCategory { INSTANT, TRAP, SUMMON, COUNTER }

enum NpcBehavior { CHASE_NEAREST, PATROL_REVERSE }

const GOAL_TILE: int = 0
const DASH_STEPS: int = 3
## 리벤지 부스터: 사출된 말이 다시 출발할 때 붙는 보너스 칸수.
const REVENGE_BONUS: int = 4
## 말 밟고 점프하기: 경로 중간의 말 하나마다 +1칸, 한 번의 이동에서 최대 LEAPFROG_MAX칸까지.
const LEAPFROG_MAX: int = 3

const PAWNS_PER_PLAYER: int = 4
const MAX_NPCS: int = 3
const MAX_LAWS: int = 4
const MAX_HAND_SIZE: int = 7
const MAX_REROLL_CHAIN: int = 8
## 증강 드래프트는 4, 7, 10, 13, ... 라운드에 열린다 (옛 일정 1, 4, 7, ...에서 1라운드만 뺐다).
## 2026-11 온보딩 개선: 첫 증강은 4라운드부터 (1~3라운드에 기본 주사위 굴리기·말 이동·기본 규칙을 먼저 직접 겪어 본 뒤 고르게).
## 4라운드 이후의 간격·단계(도구·카드·진화 → 7라운드부터 초증강·법전)는 옛 일정과 같다.
const DRAFT_START: int = 4
const DRAFT_INTERVAL: int = 3
## 실제로 쓰는 첫 드래프트 라운드. 기본은 DRAFT_START이고, 옛 일정(1라운드 시작)을 전제로 쓴 규칙 단위 테스트는 러너가 1로 바꿔 돌린다
## (새 일정은 REAL_DRAFT_SCHEDULE을 선언한 묶음과 UI 테스트가 검증한다). 1 + 3의 배수여야 한다 (1·4·7).
static var draft_start: int = DRAFT_START


static func is_draft_round(round_number: int) -> bool:
	return round_number >= draft_start and (round_number - 1) % DRAFT_INTERVAL == 0
const DRAFT_OFFER_COUNT: int = 3

## 페이즈별 제한 시간(초). 0이면 타이머 없음(즉시 진행).
const PHASE_TIME_DRAFT: float = 15.0
## 드래프트가 끝난 뒤 모두가 고른 증강을 확인하는 시간 (모두 [확인]을 누르면 바로 넘어간다).
const PHASE_TIME_REVIEW: float = 4.0  # 2026-10-27: 20 -> 8, 2026-11 온보딩 개선: 8 -> 4 (선택 뒤 확인 창이 오래 가리지 않게. [확인]으로 바로 넘어갈 수 있다)
const PHASE_TIME_TURN_BEGIN: float = 10.0
const PHASE_TIME_ROLL: float = 10.0
const PHASE_TIME_INTERRUPT: float = 3.5
const PHASE_TIME_SELECT: float = 10.0
const PHASE_TIME_RESOLUTION: float = 3.5
