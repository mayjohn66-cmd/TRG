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
## 폰이 밟는 즉시 퀸으로 승진하는 타일: 중앙(22번)과 외곽 마지막 사분면(15~19번).
const PROMOTION_TILES: Array[int] = [15, 16, 17, 18, 19, 22]
## 쇼기 기물이 밟거나 지나가는 순간 나리(成り) 승급하는 타일: 반환점인 10번 코너와 중앙 22번.
const SHOGI_PROMOTION_TILES: Array[int] = [10, 22]
## 옷장 포탈(7, 17번)에 멈춘 모노폴리 비행기가 워프하는 코너 (7번 -> 10번, 17번 -> 결승 직전 19번).
const PLANE_WARP_TARGETS: Dictionary = {7: 10, 17: 19}

enum AugmentCategory { PAWN_EVOLUTION, TOOL_SWAP, LAW_ENACT, CARD_PACKAGE }

enum CardCategory { INSTANT, TRAP, SUMMON }

enum NpcBehavior { CHASE_NEAREST, PATROL_REVERSE }

const TILE_COUNT: int = 29
const GOAL_TILE: int = 0
const CENTER_TILE: int = 22
const CORNER_SHORTCUT_1: int = 5
const CORNER_SHORTCUT_2: int = 10
const CORNER_MERGE: int = 15
const OUTER_TRACK_SIZE: int = 20
const LAST_OUTER_TILE: int = 19
const LAST_SHORTCUT_TILE: int = 28
const BAKERY_TILES: Array[int] = [3, 8, 13, 18]
const PORTAL_TILES: Array[int] = [7, 17]

const PAWNS_PER_PLAYER: int = 4
const MAX_NPCS: int = 3
const CORNER_TILES: Array[int] = [0, 5, 10, 15]
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
