# File: res://core_engine/rules/laws/victory_law.gd
# Class: class_name VictoryLaw
# Role: 🏆 중앙 법전의 특수 승리 교칙 8종 (LAW_01~08). 판을 변조하지 않고, 조건을 먼저 달성한 사람이 다음 순위로 졸업한다 (SpecialVictory)
class_name VictoryLaw
extends LawResource

const KILLS: StringName = &"kills"
const HAND: StringName = &"turn_hand"
const ESTATE: StringName = &"estate"
const BEST_MOVE: StringName = &"best_move"
const SPREAD: StringName = &"spread"
const EJECTED: StringName = &"ejected"
const BEST_CHAIN: StringName = &"best_chain"
const UNDERDOG: StringName = &"underdog"
## 사도 포위망: 말 사이에 필요한 최소 간격.
const SPREAD_GAP: int = 3

## 교칙 ID -> [이름, 조건 문구({p1}=목표), 기본 목표, 기록 키, 단위]
const DEFS: Dictionary = {
	"LAW_01": ["투기장의 지배자", "적 말을 {p1}회 처치", 6, KILLS, "처치"],
	"LAW_02": ["봉인된 에르핀의 식권", "내 턴 시작 시 손패 {p1}장 이상", 5, HAND, "장"],
	"LAW_03": ["엘리아스 부동산 재벌", "내 설치물(호텔·함정) {p1}개를 보드에 동시 유지", 5, ESTATE, "개"],
	"LAW_04": ["카이지의 한방 역전법", "한 번의 이동으로 {p1}칸 이상 전진", 16, BEST_MOVE, "칸"],
	"LAW_05": ["사도 포위망", "말 {p1}개 모두 트랙 위에서 서로 3칸 이상 간격", 4, SPREAD, "개"],
	"LAW_06": ["해탈한 동네북의 역습", "내 말이 {p1}회 장외 사출당함", 8, EJECTED, "회"],
	"LAW_07": ["초전도체 무한 동력", "한 턴에 주사위 {p1}연속 굴림", 4, BEST_CHAIN, "연속"],
	"LAW_08": ["다크호스의 하극상", "완주 0개인 채로 선두의 말을 {p1}회 처치", 3, UNDERDOG, "처치"],
}
## 법전에 있는 동안만 세는 순간 기록 (교칙이 제정되면 모두 0부터 다시 센다).
const SESSION_KEYS: Array[StringName] = [HAND, BEST_MOVE, BEST_CHAIN]
## ACT_06 이의 있음으로 0으로 되돌릴 수 있는 기록 (지금 보드 상태로 정해지는 손패·설치물·포위망은 제외).
const RESETTABLE_KEYS: Array[StringName] = [KILLS, BEST_MOVE, EJECTED, BEST_CHAIN, UNDERDOG]

var stat_key: StringName = &""


func _init(id: String = "LAW_01") -> void:
	law_id = id
	var row: Array = DEFS[id]
	law_name = str(row[0])
	stat_key = row[3]
	description = condition_text()
	trigger_timing = ""  # 판을 변조하지 않는다


static func is_victory_id(id: String) -> bool:
	return DEFS.has(id)


## 목표 수치 (augments_table.csv AUG_LAW_0N param_1).
func goal() -> int:
	return maxi(GameData.param("augments", "AUG_%s" % law_id, 1, int(DEFS[law_id][2])), 1)


func condition_text() -> String:
	return str(DEFS[law_id][1]).replace("{p1}", str(goal()))


func unit() -> String:
	return str(DEFS[law_id][4])


func resettable() -> bool:
	return RESETTABLE_KEYS.has(stat_key)


## 지금 진행도 (0~goal로 자르지 않는다).
func progress(state: GameState, player_id: int) -> int:
	match stat_key:
		ESTATE:
			return state.owned_attachment_count(player_id)
		SPREAD:
			return spread_count(state, player_id)
		HAND:
			return (state.hands.get(player_id, []) as Array).size()  # 화면에는 지금 손패를 보여 준다
	return state.stat(player_id, stat_key)


## 달성 여부. 식권은 내 턴이 시작될 때 기록한 손패로 판정한다 (남의 턴에 카드를 받아 넘겨도 바로 이기지 않는다).
func achieved(state: GameState, player_id: int) -> bool:
	if stat_key == HAND:
		return state.stat(player_id, HAND) >= goal()
	return progress(state, player_id) >= goal()


## 위험 표시: 목표까지 한 걸음(목표의 80% 이상 또는 1 남음).
func is_danger(state: GameState, player_id: int) -> bool:
	var value: int = progress(state, player_id)
	return value < goal() and (value >= goal() - 1 or value * 5 >= goal() * 4)


## 사도 포위망: 트랙 위(출발선·결승 제외)에 따로 서 있는 내 말 중 서로 SPREAD_GAP칸 이상 떨어진 말의 최대 수 (앞에서부터 욕심껏 센다).
static func spread_count(state: GameState, player_id: int) -> int:
	var tiles: Array[int] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished or not pawn.has_left_start or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		if pawn.carrier != null or not pawn.carried.is_empty():
			continue  # 업힌 말은 한 칸에 겹쳐 있으니 포위망이 아니다
		tiles.append(pawn.current_tile_idx)
	tiles.sort()
	var count: int = 0
	var last: int = -SPREAD_GAP
	for tile: int in tiles:
		if tile - last >= SPREAD_GAP:
			count += 1
			last = tile
	return count
