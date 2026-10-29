# File: res://core_engine/rules/tempo_up.gd
# Class: class_name TempoUp
# Role: 판이 길어지면 라운드 단위로 게임을 가속한다 (템포 업). 7·14·20라운드에 단계가 오르고 (2026-10: 8·15·22에서 당겨 20라운드 안에 결판이 나게), 단계가 오르는 라운드가 시작될 때 크게 경고한다.
#       1단계(7R, 과열): 차례 첫 이동 +2칸 · 리벤지 부스터 +6칸 · 초증강 등장 확률 상승
#       2단계(14R, 광기): 차례 첫 이동 +4칸 · 리벤지 부스터 +8칸 · 법전 등장 확률 상승
#       3단계(20R, 대붕괴): 전원 이동 +6칸
#       서든데스(2단계 라운드 + 2 = 16R 이후, 17R부터): 결승선이 라운드마다 1칸씩 완만하게 당겨진다 (출발선 4칸 앞까지).
#       (2026-10-29 코어 유저 피드백) 예전 "2단계부터 라운드마다 3칸" 자동 단축은 트랙을 너무 빨리 줄여 기물·함정·역전 빌드업을
#       써 보기도 전에 판이 끝났다. 이제 결승선은 플레이어가 [범용] 슬슬 지루한데...(goal_shrink_bonus)를 쓸 때와 서든데스에서만 당겨진다.
#       싱글 라운드 상한(PacingDirector.HARD_CAP_ROUND)은 30라운드 안전장치다.
#       라운드 번호만으로 정해지는 순수 함수라 스냅샷·네트워크 동기화가 따로 필요 없다.
class_name TempoUp
extends RefCounted

## 단계가 오르는 라운드 (1단계, 2단계, 3단계).
const STAGE_ROUNDS: Array[int] = [7, 14, 20]
## 단계별 부제 (경고 배너에 붙는다): 1단계 과열 · 2단계 광기 · 3단계 대붕괴.
const STAGE_NAMES: Array[String] = ["", "과열", "광기", "대붕괴"]
## 단계별 최종 이동 보너스 (0단계 = 없음).
const MOVE_BONUS: Array[int] = [0, 2, 4, 6]
## 단계별 리벤지 부스터 칸 수 (0이면 기본값 그대로).
const REVENGE_BONUS: Array[int] = [0, 6, 8, 8]
## 이번 판의 템포 업 라운드 (규칙 설정: 기본 STAGE_ROUNDS / 스피드전 MatchRules.SPEED_STAGE_ROUNDS). GameState.setup이 넣는다.
static var stage_rounds: Array[int] = [7, 14, 20]
## 초증강(1단계부터)·법전(2단계부터) 가중치에 곱하는 배수.
const RARE_WEIGHT_MULTIPLIER: int = 3
## 서든데스(sudden_death_round() 이후)에 라운드마다 결승선이 당겨지는 칸 수 (2026-10-29: 2단계부터 3칸 → 16R 이후 1칸).
const GOAL_SHRINK_PER_ROUND: int = 1
## 서든데스가 시작되기 전 마지막 라운드 = 2단계 라운드 + 이 값 (기본 14 + 2 = 16, 스피드전 8 + 2 = 10).
const SUDDEN_DEATH_AFTER_STAGE2: int = 2


## 이 라운드의 템포 업 단계 (0~3).
static func level(round_number: int) -> int:
	var result: int = 0
	for stage_round: int in stage_rounds:
		if round_number >= stage_round:
			result += 1
	return result


## 단계가 새로 오르는 라운드인가 (경고 연출 시점).
static func is_stage_round(round_number: int) -> bool:
	return stage_rounds.has(round_number)


## 차례의 첫 이동 칸에 더하는 값 (추가 굴림에는 붙지 않는다).
static func move_bonus(round_number: int) -> int:
	return MOVE_BONUS[level(round_number)]


## 이 라운드의 리벤지 부스터 칸 수 (0이면 기본값을 쓴다).
static func revenge_bonus(round_number: int) -> int:
	return REVENGE_BONUS[level(round_number)]


## 드래프트에서 이 카테고리의 가중치에 곱할 배수.
static func weight_multiplier(round_number: int, category: GameEnums.AugmentCategory) -> int:
	var stage: int = level(round_number)
	if (stage >= 1 and category == GameEnums.AugmentCategory.SUPER_GAMBLE) or (stage >= 2 and category == GameEnums.AugmentCategory.LAW_ENACT):
		return RARE_WEIGHT_MULTIPLIER
	return 1


## 서든데스 직전 라운드 (기본 16). 이 라운드까지는 시스템이 결승선을 당기지 않는다.
static func sudden_death_round() -> int:
	return stage_rounds[1] + SUDDEN_DEATH_AFTER_STAGE2


## 서든데스가 시작되는 라운드인가 (결승선이 처음 당겨지는 라운드: 기본 17R).
static func is_sudden_death_start(round_number: int) -> bool:
	return round_number == sudden_death_round() + 1


## 시스템이 당긴 결승선 칸 수: 서든데스(sudden_death_round() 다음 라운드)부터 라운드마다 GOAL_SHRINK_PER_ROUND칸, 출발선 4칸 앞(max_shrink)까지.
static func goal_shrink(round_number: int) -> int:
	if round_number <= sudden_death_round():
		return 0
	return mini((round_number - sudden_death_round()) * GOAL_SHRINK_PER_ROUND, max_shrink(round_number))


## 반환점 뒤쪽 절반까지의 당기기 한도 (2단계).
static func half_shrink_limit() -> int:
	return maxi(BoardSpec.tile_count - BoardSpec.halfway_tile - 4, 0)


## 이 라운드에 결승선을 당길 수 있는 최대 칸 수: 서든데스부터는 출발선 4칸 앞까지, 그 전(범용 증강으로만 당길 때)은 반환점 뒤 절반까지.
static func max_shrink(round_number: int) -> int:
	return maxi(BoardSpec.tile_count - 4, 0) if round_number > sudden_death_round() else half_shrink_limit()


## 이 판에 결승선이 당겨진 칸 수: 템포 업 당기기 + [범용] 슬슬 지루한데...(GameState.goal_shrink_bonus). 이 라운드의 한도(max_shrink)를 넘지 않는다.
static func shrink_for(state: GameState) -> int:
	if state == null:
		return 0
	return mini(goal_shrink(state.round_number) + state.goal_shrink_bonus, max_shrink(state.round_number))


## 이 판의 결승선 첫 칸 (당겨지지 않았으면 -1).
static func zone_start_for(state: GameState) -> int:
	var shrink: int = shrink_for(state)
	return BoardSpec.tile_count - shrink if shrink > 0 else -1


## 이 칸이 이 판의 당겨진 결승선 안인가 (0번 결승선 자체는 포함하지 않는다).
static func in_zone_for(state: GameState, tile: int) -> bool:
	var start: int = zone_start_for(state)
	return start > 0 and tile >= start and tile < BoardSpec.tile_count


## 결승선으로 치는 첫 칸 (당겨지지 않았으면 -1). 이 칸부터 마지막 칸까지 들어서면 완주한다.
static func goal_zone_start(round_number: int) -> int:
	var shrink: int = goal_shrink(round_number)
	return BoardSpec.tile_count - shrink if shrink > 0 else -1


## 이 칸이 당겨진 결승선 안인가 (0번 결승선 자체는 포함하지 않는다).
static func in_goal_zone(round_number: int, tile: int) -> bool:
	var start: int = goal_zone_start(round_number)
	return start > 0 and tile >= start and tile < BoardSpec.tile_count


## 단계 부제 (0단계는 빈 문자열).
static func stage_name(stage: int) -> String:
	return STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)]


## 경고 화면에 보여 줄 단계별 효과 문구.
static func effect_lines(stage: int) -> Array[String]:
	match stage:
		1: return ["차례 첫 이동 +%d칸" % MOVE_BONUS[1], "리벤지 부스터 +6칸", "초증강 등장 확률 상승"] as Array[String]
		2: return ["차례 첫 이동 +%d칸" % MOVE_BONUS[2], "리벤지 부스터 +8칸", "법전 증강 등장 확률 상승", "%d라운드부터 서든데스: 결승선이 라운드마다 1칸씩 당겨진다" % (sudden_death_round() + 1)] as Array[String]
		3: return ["전원 차례 첫 이동 +%d칸" % MOVE_BONUS[3], "서든데스: 결승선이 라운드마다 1칸씩 계속 당겨진다"] as Array[String]
	return [] as Array[String]
