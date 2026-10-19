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
enum PawnKind { BASIC, YUT, CHESS, JANGGI, MONOPOLY, GO, SHOGI }

## 호기별 세부 기물. (세트, 호기)에서 PawnCatalog.sub_type_of()가 정한다. 체스 퀸은 5번째 호기 번호(CHESS_QUEEN_UNIT)로 표현한다.
enum PawnSubType {
	NONE,
	YUT_MAL,
	CHESS_PAWN, CHESS_KNIGHT, CHESS_BISHOP, CHESS_ROOK, CHESS_QUEEN,
	JANGGI_PO, JANGGI_CHA, JANGGI_MA, JANGGI_SANG,
	MONO_CAR, MONO_PLANE, MONO_SHIP, MONO_DOG,
	BADUK_BLACK, BADUK_WHITE,
	SHOGI_FU, SHOGI_HISHA, SHOGI_KAKU, SHOGI_KEIMA,
}

## 체스 폰이 승진해 퀸이 된 뒤의 호기 번호.
const CHESS_QUEEN_UNIT: int = 5
## 체스 폰이 반환점(12번) 이상에 도달하거나 지나가는 순간 퀸으로 승진하는 타일.
const PROMOTION_TILES: Array[int] = [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
## 쇼기 기물이 반환점(12번) 이상에 도달하거나 지나가는 순간 나리(成り) 승급하는 타일.
const SHOGI_PROMOTION_TILES: Array[int] = PROMOTION_TILES
## 옷장 포탈(9, 16번)에 멈춘 모노폴리 비행기가 워프하는 곳 (9번 -> 18번 코너, 16번 -> 결승 직전 22번).
const PLANE_WARP_TARGETS: Dictionary = {9: 18, 16: 22}
## 옷장 포탈 일반 워프: 9번 -> 16번(보드를 가로질러), 16번 -> 20번. LAW_01 중에는 작동하지 않는다.
const PORTAL_WARP_TARGETS: Dictionary = {9: 16, 16: 20}
## 점프 코너: 정확히 멈추면 즉시 6번 -> 10번(+4칸), 18번 -> 21번(+3칸). LAW_01 중에는 작동하지 않는다.
const JUMP_CORNER_TARGETS: Dictionary = {6: 10, 18: 21}
## 비숍·각행이 스쳐 지나가거나 멈추면 이동 거리 +2칸을 얻는 코너.
const BONUS_CORNER_TILES: Array[int] = [6, 12, 18]

enum AugmentCategory { PAWN_EVOLUTION, TOOL_SWAP, LAW_ENACT, CARD_PACKAGE, SUPER_GAMBLE }

enum CardCategory { INSTANT, TRAP, SUMMON }

enum NpcBehavior { CHASE_NEAREST, PATROL_REVERSE }

## 부르마블식 24칸 사각 순환 트랙 (0 -> 1 -> ... -> 23 -> 0). 한 변 6칸, 코너는 0·6·12·18번.
const TILE_COUNT: int = 24
const GOAL_TILE: int = 0
## 반환점 코너(12번): 폰 승급 기준이자 고스트 NPC의 소환·연행 지점.
const HALFWAY_TILE: int = 12
const LAST_TILE: int = 23
const BAKERY_TILES: Array[int] = [4, 10, 14, 20]
const PORTAL_TILES: Array[int] = [9, 16]
## ⚡ 부스터 발판: 이동을 마치고 멈추면 즉시 앞으로 DASH_STEPS칸 더 날아간다 (4번은 빵집과 겹친다).
const DASH_TILES: Array[int] = [4, 11, 19]
const DASH_STEPS: int = 3
## 🔥 리벤지 부스터: 사출된 말이 다시 출발할 때 붙는 보너스 칸수.
const REVENGE_BONUS: int = 4
## 🏃 말 밟고 점프하기: 경로 중간의 말 하나마다 +1칸, 한 번의 이동에서 최대 LEAPFROG_MAX칸까지.
const LEAPFROG_MAX: int = 3

const PAWNS_PER_PLAYER: int = 4
const MAX_NPCS: int = 3
const CORNER_TILES: Array[int] = [0, 6, 12, 18]
const MAX_LAWS: int = 4
const MAX_HAND_SIZE: int = 7
const MAX_REROLL_CHAIN: int = 8
## 증강 드래프트는 1라운드부터 DRAFT_INTERVAL라운드마다 열린다 (1, 4, 7, 10, ...).
const DRAFT_INTERVAL: int = 3


static func is_draft_round(round_number: int) -> bool:
	return round_number >= 1 and (round_number - 1) % DRAFT_INTERVAL == 0
const DRAFT_OFFER_COUNT: int = 3

## 페이즈별 제한 시간(초). 0이면 타이머 없음(즉시 진행).
const PHASE_TIME_DRAFT: float = 15.0
const PHASE_TIME_TURN_BEGIN: float = 10.0
const PHASE_TIME_ROLL: float = 10.0
const PHASE_TIME_INTERRUPT: float = 3.5
const PHASE_TIME_SELECT: float = 10.0
const PHASE_TIME_RESOLUTION: float = 3.5
