# File: res://core_engine/tools/tool_yut.gd
# Class: class_name ToolYut
# Role: 전통 박달나무 윷 - [낙, 도, 개, 걸, 윷, 모] 가중 추첨 (윷·모는 절반, 히든). 낙(윷가락이 판 밖으로)은 0칸 + 턴 종료, 윷·모는 재굴림 (한 차례 최대 3번, 그다음 던지기는 도·개·걸 중 하나)
class_name ToolYut
extends BaseJudgmentTool

## 윷가락이 판 밖으로 떨어진 낙(落)의 면 번호. 0칸 이동이고 턴이 끝난다.
const NAK_FACE: int = 0
const FACES: Array[int] = [0, 1, 2, 3, 4, 5]
## 한 차례 재굴림 상한 (2026-10 QA: 윷 1위율 49%로 과강). 상한에 닿은 다음 던지기는 끊지 않고 도·개·걸 중 하나만 나온다.
const MAX_REROLLS: int = 3
const CAPPED_FACES: Array[int] = [1, 2, 3]
## 히든 보정: 면별 가중치 [낙, 도, 개, 걸, 윷, 모]. 윷·모는 절반 (윷·모 확률 1/3 → 1/5, 2026-10-28 윷 1위율 과강 대응).
const FACE_WEIGHTS: Array[int] = [2, 2, 2, 2, 1, 1]
## 윷·모로 얻은 추가 던지기에서는 낙 가중치가 이 배수다.
const NAK_WEIGHT_AFTER_BONUS: int = 3
## 이번 던지기가 윷·모로 얻은 추가 던지기인가 (TurnManager가 굴리기 직전에 정한다).
var bonus_throw: bool = false


func _init() -> void:
	tool_id = &"YUT"
	display_name = "전통 박달나무 윷"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var weights: Array[int] = FACE_WEIGHTS.duplicate()
	if bonus_throw:
		weights[NAK_FACE] *= NAK_WEIGHT_AFTER_BONUS
	var total: int = 0
	for weight: int in weights:
		total += weight
	var pick: int = rng.randi_range(0, total - 1)
	var face: int = FACES[0]
	for index: int in FACES.size():
		if pick < weights[index]:
			face = FACES[index]
			break
		pick -= weights[index]
	var nak: bool = face == NAK_FACE
	var result: RollResult = RollResult.make(tool_id, 0 if nak else face, {"face": face, "nak": nak})
	result.ends_turn = nak
	result.reroll = face >= 4
	return result


## 재굴림 상한에 닿은 다음 던지기: 도·개·걸 중 하나 (낙·윷·모 없음).
func roll_capped(rng: RandomNumberGenerator) -> RollResult:
	var face: int = CAPPED_FACES[rng.randi_range(0, CAPPED_FACES.size() - 1)]
	return RollResult.make(tool_id, face, {"face": face, "nak": false, "capped": true})
