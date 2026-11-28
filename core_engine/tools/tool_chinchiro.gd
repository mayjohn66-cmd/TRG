# File: res://core_engine/tools/tool_chinchiro.gd
# Class: class_name ToolChinchiro
# Role: 지하노역장 친치로 (1.3.1 리워크, 기획서 GDD 4.2 · 예외 규칙 1.8 · HANDOFF-010).
#       카이지 4·5·6 사기 주사위(6면 = 4·4·5·5·6·6) 3개를 그릇에 던진다. 먼저 1/6로 쇼벤(낙: 주사위 1개가 그릇 밖으로)을 정하고,
#       아니면 3개의 족보로 칸을 정한다: 4·5·6의 눈(페어 + 나머지 눈 n → n칸) / 시고로 4·5·6(8칸) / 아라시 444·555(10칸) / ★666 아라시(12칸 + 한 번 더).
#       4·5·6만 있는 주사위 3개는 언제나 족보가 생기므로 메나시(족보 없음)·다시 굴리기는 없다.
class_name ToolChinchiro
extends BaseJudgmentTool

## 사기 주사위 한 개의 여섯 면.
const FACES: Array[int] = [4, 4, 5, 5, 6, 6]
const DICE_COUNT: int = 3
## 쇼벤(낙) 확률의 분모 (1/6).
const SHOBEN_ODDS: int = 6

const HAND_SHOBEN: StringName = &"shoben"
const HAND_EYE: StringName = &"eye"
const HAND_SHIGORO: StringName = &"shigoro"
const HAND_STORM: StringName = &"storm"
const HAND_STORM_SIX: StringName = &"storm_six"

const SHIGORO_STEPS: int = 8
const STORM_STEPS: int = 10
const STORM_SIX_STEPS: int = 12


func _init() -> void:
	tool_id = &"CHINCHIRO"
	display_name = "지하노역장 친치로"


## 엔진 난수 순서: 쇼벤 판정 1회 → 주사위 3개 → (쇼벤이면) 그릇 밖으로 나간 주사위 번호.
func roll(rng: RandomNumberGenerator) -> RollResult:
	var shoben: bool = rng.randi_range(1, SHOBEN_ODDS) == 1
	var dice: Array[int] = []
	for _i: int in DICE_COUNT:
		dice.append(FACES[rng.randi_range(0, FACES.size() - 1)])
	var out_index: int = rng.randi_range(0, DICE_COUNT - 1) if shoben else -1
	var hand: StringName = HAND_SHOBEN if shoben else hand_of(dice)
	var steps: int = 0 if shoben else steps_of(dice)
	var result: RollResult = RollResult.make(tool_id, steps, {"dice": dice, "hand": hand, "shoben": shoben, "out_index": out_index, "eye": eye_of(dice)})
	result.ends_turn = shoben
	result.reroll = hand == HAND_STORM_SIX
	return result


## 주사위 3개의 족보 (쇼벤은 따로 정한다).
static func hand_of(dice: Array[int]) -> StringName:
	var sorted: Array[int] = dice.duplicate()
	sorted.sort()
	if sorted[0] == sorted[2]:
		return HAND_STORM_SIX if sorted[0] == 6 else HAND_STORM
	if sorted[0] == 4 and sorted[1] == 5 and sorted[2] == 6:
		return HAND_SHIGORO
	return HAND_EYE


## 페어 + 나머지 하나일 때 그 나머지 눈 (눈 족보가 아니면 0).
static func eye_of(dice: Array[int]) -> int:
	if hand_of(dice) != HAND_EYE:
		return 0
	for value: int in dice:
		if dice.count(value) == 1:
			return value
	return 0


## 족보의 칸 수 (쇼벤이 아닐 때).
static func steps_of(dice: Array[int]) -> int:
	match hand_of(dice):
		HAND_STORM_SIX: return STORM_SIX_STEPS
		HAND_STORM: return STORM_STEPS
		HAND_SHIGORO: return SHIGORO_STEPS
	return eye_of(dice)


## 결과 이름 (한국어 원문, 화면에서 번역한다).
static func hand_name(details: Dictionary) -> String:
	match StringName(details.get("hand", &"")):
		HAND_SHOBEN: return "쇼벤! (낙)"
		HAND_STORM_SIX: return "★666 아라시!"
		HAND_STORM: return "아라시!"
		HAND_SHIGORO: return "시고로!"
	return "%d의 눈" % int(details.get("eye", 0))
