# File: res://core_engine/rules/tempo_up.gd
# Class: class_name TempoUp
# Role: 판이 길어지면 라운드 단위로 게임을 가속한다 (템포 업). 11·21·31라운드에 단계가 오르고, 단계가 오르는 라운드가 시작될 때 크게 경고한다.
#       1단계(11R): 최종 이동 +1칸 · 리벤지 부스터 +6칸 · 법전·초증강 등장 확률 상승
#       2단계(21R): 최종 이동 +3칸 · 리벤지 부스터 +8칸 · 법전 빈자리에 무작위 특수 승리 1개 등록
#       3단계(31R): 전원 이동 +5칸 · 결승선이 라운드마다 2칸씩 당겨진다
#       라운드 번호만으로 정해지는 순수 함수라 스냅샷·네트워크 동기화가 따로 필요 없다.
class_name TempoUp
extends RefCounted

## 단계가 오르는 라운드 (1단계, 2단계, 3단계).
const STAGE_ROUNDS: Array[int] = [11, 21, 31]
## 단계별 부제 (경고 배너에 붙는다): 1단계 과열 · 2단계 광기 · 3단계 대붕괴.
const STAGE_NAMES: Array[String] = ["", "과열", "광기", "대붕괴"]
## 단계별 최종 이동 보너스 (0단계 = 없음).
const MOVE_BONUS: Array[int] = [0, 1, 3, 5]
## 단계별 리벤지 부스터 칸 수 (0이면 기본값 그대로).
const REVENGE_BONUS: Array[int] = [0, 6, 8, 8]
## 1단계부터 법전(특수 승리)·초증강 가중치에 곱하는 배수.
const RARE_WEIGHT_MULTIPLIER: int = 3
## 3단계부터 라운드마다 결승선이 당겨지는 칸 수.
const GOAL_SHRINK_PER_ROUND: int = 2


## 이 라운드의 템포 업 단계 (0~3).
static func level(round_number: int) -> int:
	var result: int = 0
	for stage_round: int in STAGE_ROUNDS:
		if round_number >= stage_round:
			result += 1
	return result


## 단계가 새로 오르는 라운드인가 (경고 연출 시점).
static func is_stage_round(round_number: int) -> bool:
	return STAGE_ROUNDS.has(round_number)


## 모든 굴림의 최종 이동 칸에 더하는 값.
static func move_bonus(round_number: int) -> int:
	return MOVE_BONUS[level(round_number)]


## 이 라운드의 리벤지 부스터 칸 수 (0이면 기본값을 쓴다).
static func revenge_bonus(round_number: int) -> int:
	return REVENGE_BONUS[level(round_number)]


## 드래프트에서 이 카테고리의 가중치에 곱할 배수.
static func weight_multiplier(round_number: int, category: GameEnums.AugmentCategory) -> int:
	if level(round_number) >= 1 and (category == GameEnums.AugmentCategory.LAW_ENACT or category == GameEnums.AugmentCategory.SUPER_GAMBLE):
		return RARE_WEIGHT_MULTIPLIER
	return 1


## 결승선이 당겨진 칸 수 (31라운드 2칸, 32라운드 4칸 …). 반환점 뒤쪽 절반을 넘지 않게 막는다.
static func goal_shrink(round_number: int) -> int:
	if level(round_number) < 3:
		return 0
	var limit: int = maxi(BoardSpec.tile_count - BoardSpec.halfway_tile - 4, 0)
	return mini((round_number - STAGE_ROUNDS[2] + 1) * GOAL_SHRINK_PER_ROUND, limit)


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
		1: return ["모든 굴림 최종 이동 +1칸", "리벤지 부스터 +6칸", "법전·초증강 증강 등장 확률 상승"] as Array[String]
		2: return ["모든 굴림 최종 이동 +3칸", "리벤지 부스터 +8칸", "법전에 무작위 특수 승리 1개 등록"] as Array[String]
		3: return ["전원 이동 +5칸", "결승선이 라운드마다 %d칸씩 당겨진다" % GOAL_SHRINK_PER_ROUND] as Array[String]
	return [] as Array[String]
