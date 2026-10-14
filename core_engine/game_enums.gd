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

enum TileType { NORMAL, START_GOAL, CORNER, BAKERY, PORTAL, CENTER, SHORTCUT }

enum PawnKind { YUT, CHESS_KNIGHT, CHESS_BISHOP, JANGGI_PO, MONOPOLY_CAR, GO_STONE }

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
const MAX_LAWS: int = 4
const MAX_HAND_SIZE: int = 7
const MAX_REROLL_CHAIN: int = 8
const DRAFT_ROUNDS: Array[int] = [1, 4, 7]
const DRAFT_OFFER_COUNT: int = 3

## 페이즈별 제한 시간(초). 0이면 타이머 없음(즉시 진행).
const PHASE_TIME_DRAFT: float = 15.0
const PHASE_TIME_TURN_BEGIN: float = 10.0
const PHASE_TIME_ROLL: float = 10.0
const PHASE_TIME_INTERRUPT: float = 3.5
const PHASE_TIME_SELECT: float = 10.0
const PHASE_TIME_RESOLUTION: float = 3.5
