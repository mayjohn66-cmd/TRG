# File: res://core_engine/match_rules.gd
# Class: class_name MatchRules
# Role: 한 판의 규칙 설정 (싱글 난이도 기본값 + 커스텀 / 친선전 방장의 [방 규칙 설정]). 판을 시작할 때 GameState.match_rules에 담기고,
#       온라인은 방장이 판 시작 정보(config["rules"])에 실어 모두에게 보내 같은 규칙으로 돈다 (락스텝이라 모두 같아야 한다).
#       - trap_reveal: 함정 정체 공개(초보) / 비공개(심리전: 상대가 설치한 함정은 ❓로만 보인다)
#       - super_freq: 초증강 등장 배수 0(끄기) / 1(기본) / 3(대축제)
#       - laws: 특수 승리 법전 켜기 / 끄기(말 4개 완주로만 승부)
#       - speed: normal / speed (스피드전: 템포 업이 빨리 오르고 초반 리벤지 부스터가 커져 10~12라운드에 결판)
#       - draft_easy: 입문(Lv.1 크림) 드래프트 완화 - 글이 길고 복잡한 초증강은 덜, 기물 진화·판정 도구는 더 나온다
class_name MatchRules
extends RefCounted

const SPEED_NORMAL: StringName = &"normal"
const SPEED_FAST: StringName = &"speed"
const SUPER_FREQS: Array[int] = [0, 1, 3]
## 스피드전 템포 업 라운드 (기본 8·15·22).
const SPEED_STAGE_ROUNDS: Array[int] = [4, 8, 12]
## 스피드전 리벤지 부스터 추가 칸.
const SPEED_REVENGE_EXTRA: int = 2
## 입문 드래프트에서 덜 나오는 초증강 (설명이 길거나 판 전체를 뒤섞는 것) 배수와, 나머지 계열 배수.
const EASY_HARD_SUPERS: Array[StringName] = [&"SUPER_02", &"SUPER_12", &"SUPER_07", &"SUPER_06", &"SUPER_05"]
const EASY_HARD_SUPER_FACTOR: float = 0.15
const EASY_SUPER_FACTOR: float = 0.6
const EASY_LAW_FACTOR: float = 0.6
const EASY_FRIENDLY_FACTOR: float = 1.6


static func defaults() -> Dictionary:
	return {"trap_reveal": true, "super_freq": 1, "laws": true, "speed": SPEED_NORMAL, "draft_easy": false}


## 싱글 불닭 난이도의 기본 규칙: Lv.1~3 함정 공개, Lv.4~5 비공개. Lv.1은 입문 드래프트.
static func for_difficulty(level: int) -> Dictionary:
	var rules: Dictionary = defaults()
	rules["trap_reveal"] = level <= 3
	rules["draft_easy"] = level == 1
	return rules


## 밖(네트워크·저장)에서 온 값을 믿을 수 있는 규칙으로 고친다. 모르는 키는 버리고 빠진 키는 기본값.
static func sanitize(value: Variant) -> Dictionary:
	var rules: Dictionary = defaults()
	if not value is Dictionary:
		return rules
	var raw: Dictionary = value
	rules["trap_reveal"] = bool(raw.get("trap_reveal", true))
	var freq: int = int(raw.get("super_freq", 1))
	rules["super_freq"] = freq if SUPER_FREQS.has(freq) else 1
	rules["laws"] = bool(raw.get("laws", true))
	rules["speed"] = SPEED_FAST if str(raw.get("speed", "")) == String(SPEED_FAST) else SPEED_NORMAL
	rules["draft_easy"] = bool(raw.get("draft_easy", false))
	return rules


static func of(state: GameState) -> Dictionary:
	return state.match_rules if state != null else defaults()


static func trap_reveal(state: GameState) -> bool:
	return bool(of(state).get("trap_reveal", true))


static func is_speed(state: GameState) -> bool:
	return StringName(of(state).get("speed", SPEED_NORMAL)) == SPEED_FAST


## 드래프트 가중치에 곱할 규칙 배수 (0이면 그 증강은 나오지 않는다).
static func weight_factor(state: GameState, def: AugmentDef) -> float:
	var rules: Dictionary = of(state)
	var factor: float = 1.0
	match def.category:
		GameEnums.AugmentCategory.SUPER_GAMBLE:
			factor *= float(int(rules.get("super_freq", 1)))
			if bool(rules.get("draft_easy", false)):
				factor *= EASY_HARD_SUPER_FACTOR if EASY_HARD_SUPERS.has(StringName(str(def.payload))) else EASY_SUPER_FACTOR
		GameEnums.AugmentCategory.LAW_ENACT:
			if not bool(rules.get("laws", true)):
				return 0.0
			if bool(rules.get("draft_easy", false)):
				factor *= EASY_LAW_FACTOR
		GameEnums.AugmentCategory.PAWN_EVOLUTION, GameEnums.AugmentCategory.TOOL_SWAP:
			if bool(rules.get("draft_easy", false)):
				factor *= EASY_FRIENDLY_FACTOR
	return factor


## 기본값과 다른 규칙만 짧게 ("함정 비공개 · 초증강 대축제 · 스피드전"). 모두 기본이면 빈 문자열.
static func summary(rules: Dictionary) -> String:
	var parts: PackedStringArray = []
	if not bool(rules.get("trap_reveal", true)):
		parts.append("함정 비공개")
	match int(rules.get("super_freq", 1)):
		0: parts.append("초증강 끄기")
		3: parts.append("초증강 대축제")
	if not bool(rules.get("laws", true)):
		parts.append("법전 끄기")
	if StringName(rules.get("speed", SPEED_NORMAL)) == SPEED_FAST:
		parts.append("스피드전")
	if bool(rules.get("draft_easy", false)):
		parts.append("입문 드래프트")
	return " · ".join(parts)


## 이 규칙의 템포 업 라운드.
static func stage_rounds(rules: Dictionary) -> Array[int]:
	return SPEED_STAGE_ROUNDS.duplicate() if StringName(rules.get("speed", SPEED_NORMAL)) == SPEED_FAST else TempoUp.STAGE_ROUNDS.duplicate()
