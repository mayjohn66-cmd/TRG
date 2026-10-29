# File: res://core_engine/match_rules.gd
# Class: class_name MatchRules
# Role: 한 판의 규칙 설정 (싱글 난이도 기본값 + 커스텀 / 친선전 방장의 [방 규칙 설정]). 판을 시작할 때 GameState.match_rules에 담기고,
#       온라인은 방장이 판 시작 정보(config["rules"])에 실어 모두에게 보내 같은 규칙으로 돈다 (락스텝이라 모두 같아야 한다).
#       - trap_reveal: 함정 정체 공개(초보) / 비공개(심리전: 상대가 설치한 함정은 ❓로만 보인다)
#       - super_freq: 초증강 등장 배수 0(끄기) / 1(기본) / 2(축제) / 3(대축제)
#       - laws: 특수 승리 법전 켜기 / 끄기(말 4개 완주로만 승부)
#       - law_pool: 드래프트·템포 업에 나오는 법전을 이 목록으로 제한 (빈 배열 = 모두. Lv.1 크림은 laws 끄기)
#       - pacing: 히든 페이싱 디렉터 단계 (0 끄기 = 친선전·커스텀 기본, 1~5 = 싱글 불닭 난이도, PacingDirector)
#       - speed: normal / speed (스피드전: 템포 업이 빨리 오르고 초반 리벤지 부스터가 커져 10~12라운드에 결판)
#       - draft_easy: 입문(Lv.1 크림) 드래프트 완화 - 글이 길고 복잡한 초증강은 덜, 기물 진화·판정 도구는 더 나온다
#       - bot_level: 친선전 빈자리 컴퓨터의 불닭 난이도 Lv.1~5 (놀이터는 따로 고른 불닭 난이도를 쓴다)
#       친선전 원클릭 프리셋 3종(PRESETS)은 법전·함정·초증강 세 값을 한 번에 맞춘다.
class_name MatchRules
extends RefCounted

const SPEED_NORMAL: StringName = &"normal"
const SPEED_FAST: StringName = &"speed"
const SUPER_FREQS: Array[int] = [0, 1, 2, 3]
## 친선전 원클릭 프리셋: [키, 이름, 설명, 규칙 값]. 고르면 세 값을 한 번에 맞춘다 (속도·봇 난이도는 그대로).
const PRESET_CLASSIC: StringName = &"classic"
const PRESET_STANDARD: StringName = &"standard"
const PRESET_MIND: StringName = &"mind_games"
const PRESETS: Array = [
	[PRESET_CLASSIC, "입문/클래식 완주전", "법전 끄기 · 함정 공개 · 초증강 끄기", {"laws": false, "trap_reveal": true, "super_freq": 0}],
	[PRESET_STANDARD, "오리지널 표준", "법전 켜기 · 함정 공개 · 초증강 기본", {"laws": true, "trap_reveal": true, "super_freq": 1}],
	[PRESET_MIND, "우정파괴 심리전", "법전 켜기 · 함정 비공개 · 초증강 축제 (확률 2배)", {"laws": true, "trap_reveal": false, "super_freq": 2}],
]
## 스피드전 템포 업 라운드 (기본 7·14·20).
const SPEED_STAGE_ROUNDS: Array[int] = [4, 8, 12]
## 스피드전 리벤지 부스터 추가 칸.
const SPEED_REVENGE_EXTRA: int = 2
## 입문 드래프트에서 덜 나오는 초증강 (설명이 길거나 판 전체를 뒤섞는 것) 배수와, 나머지 계열 배수.
const EASY_HARD_SUPERS: Array[StringName] = [&"SUPER_02", &"SUPER_12", &"SUPER_07", &"SUPER_06", &"SUPER_05"]
const EASY_HARD_SUPER_FACTOR: float = 0.15
const EASY_SUPER_FACTOR: float = 0.6
const EASY_LAW_FACTOR: float = 0.6
const EASY_FRIENDLY_FACTOR: float = 1.6
## 드래프트에서 법전(LAW) 계열 가중치에 곱하는 배수 (2026-10-26 법전 1위 72/100판 → 1/3, 2026-10-27 법전 14/100판 → 1/2,
## 2026-10-29 코어 유저 "여러 판 해도 법전을 한 번도 못 봤다" → 2.5배 상향 복구 1.25).
const LAW_DRAFT_FACTOR: float = 1.25
## 중반 법전 보장: 이 난이도(불닭 Lv.) 이상 싱글과 친선·핫시트(페이싱 없음)에서, 1단계 템포 업 라운드(기본 7R = 6라운드 동안)까지
## 법전이 하나도 없으면 무작위 특수 승리 법전 1개를 자동 제정한다 (법전 켜기일 때만, 최대 개수 max_laws는 그대로).
const AUTO_LAW_MIN_LEVEL: int = 2
## 한 판에 법전에 동시에 올라 있을 수 있는 특수 승리 수: 기본 2개, 싱글 Lv.1~2는 1개. 가득 차면 드래프트·템포 업에 법전이 나오지 않는다.
const MAX_LAWS: int = 2
const MAX_LAWS_EASY: int = 1
## 쉬운 법전 2종 (투기장의 지배자·봉인된 에르핀의 식권). Lv.1 크림은 2026-10-27부터 법전을 아예 끈다.
const EASY_LAWS: Array[String] = ["LAW_01", "LAW_02"]


static func defaults() -> Dictionary:
	return {"trap_reveal": true, "super_freq": 1, "laws": true, "speed": SPEED_NORMAL, "draft_easy": false, "law_pool": [], "pacing": 0, "bot_level": BotTemper.DEFAULT_LEVEL}


## 싱글 불닭 난이도의 기본 규칙: Lv.1~3 함정 공개, Lv.4~5 비공개. Lv.1은 입문 드래프트 + 법전 끄기 (말 4개 완주로만 승부).
## 난이도마다 히든 페이싱 디렉터(PacingDirector)가 켜진다.
static func for_difficulty(level: int) -> Dictionary:
	var rules: Dictionary = defaults()
	rules["trap_reveal"] = level <= 3
	rules["draft_easy"] = level == 1
	if level == 1:
		rules["laws"] = false  # Lv.1 크림: 특수 승리(법전)는 나오지 않는다 (2026-10-27)
	rules["pacing"] = clampi(level, 1, 5)
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
	rules["law_pool"] = []
	var raw_pool: Variant = raw.get("law_pool", [])
	if raw_pool is Array:
		for law_id: Variant in raw_pool:
			if VictoryLaw.is_victory_id(str(law_id)) and not (rules["law_pool"] as Array).has(str(law_id)):
				(rules["law_pool"] as Array).append(str(law_id))
	rules["pacing"] = clampi(int(raw.get("pacing", 0)), 0, 5)
	rules["bot_level"] = BotTemper.sanitize(raw.get("bot_level", BotTemper.DEFAULT_LEVEL))
	return rules


## 규칙이 꼭 맞는 프리셋 키 (없으면 &"").
static func preset_of(rules: Dictionary) -> StringName:
	for preset: Array in PRESETS:
		var values: Dictionary = preset[3]
		var same: bool = true
		for key: String in values.keys():
			if str(rules.get(key)) != str(values[key]):
				same = false
				break
		if same:
			return preset[0]
	return &""


## 프리셋 이름 (한국어 원문).
static func preset_name(key: StringName) -> String:
	for preset: Array in PRESETS:
		if preset[0] == key:
			return preset[1]
	return ""


## 프리셋의 규칙 값 (모르는 키면 빈 사전).
static func preset_values(key: StringName) -> Dictionary:
	for preset: Array in PRESETS:
		if preset[0] == key:
			return (preset[3] as Dictionary).duplicate()
	return {}


static func of(state: GameState) -> Dictionary:
	return state.match_rules if state != null else defaults()


## 이 판에 법전에 동시에 올라 있을 수 있는 특수 승리 수 (싱글 Lv.1~2 = 1, 그 밖 = 2).
static func max_laws(state: GameState) -> int:
	var pacing: int = int(of(state).get("pacing", 0))
	return MAX_LAWS_EASY if pacing == 1 or pacing == 2 else MAX_LAWS


## 이 판에 중반 법전 보장(자동 제정)을 쓰는가: 법전 켜기 + (싱글 Lv.2 로제 이상 또는 친선·핫시트).
static func auto_law_enabled(state: GameState) -> bool:
	var rules: Dictionary = of(state)
	if not bool(rules.get("laws", true)):
		return false
	var pacing: int = int(rules.get("pacing", 0))
	return pacing == 0 or pacing >= AUTO_LAW_MIN_LEVEL


## 법전에 올라 있는 특수 승리 교칙 수.
static func victory_law_count(state: GameState) -> int:
	if state == null or state.rulebook == null:
		return 0
	var count: int = 0
	for law: LawResource in state.rulebook.active_laws_queue:
		if law is VictoryLaw:
			count += 1
	return count


## 법전 자리가 가득 찼는가 (특수 승리 교칙만 센다).
static func laws_full(state: GameState) -> bool:
	if state == null or state.rulebook == null:
		return false
	return victory_law_count(state) >= max_laws(state)


## 이 법전이 이번 판에 나올 수 있는가 (law_pool이 비어 있으면 모두).
static func law_allowed(state: GameState, law_id: String) -> bool:
	var pool: Array = of(state).get("law_pool", [])
	return pool.is_empty() or pool.has(law_id)


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
			if not bool(rules.get("laws", true)) or not law_allowed(state, String(def.payload)) or laws_full(state):
				return 0.0
			factor *= LAW_DRAFT_FACTOR
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
		2: parts.append("초증강 축제")
		3: parts.append("초증강 대축제")
	if not bool(rules.get("laws", true)):
		parts.append("법전 끄기")
	if StringName(rules.get("speed", SPEED_NORMAL)) == SPEED_FAST:
		parts.append("스피드전")
	if bool(rules.get("draft_easy", false)):
		parts.append("입문 드래프트")
	return " · ".join(parts)


## 대기실 한 줄 설명 (번역된 조각을 " · "로 잇는다): 프리셋 이름(또는 사용자 설정) + 함정 · 초증강 · 법전 · 속도 + 빈자리 컴퓨터 난이도.
static func describe(rules: Dictionary) -> String:
	var parts: PackedStringArray = []
	var preset: StringName = preset_of(rules)
	parts.append(L10n.t(preset_name(preset) if preset != &"" else "사용자 설정"))
	parts.append(L10n.t("함정 공개" if bool(rules.get("trap_reveal", true)) else "함정 비공개"))
	match int(rules.get("super_freq", 1)):
		0: parts.append(L10n.t("초증강 끄기"))
		2: parts.append(L10n.t("초증강 축제"))
		3: parts.append(L10n.t("초증강 대축제"))
		_: parts.append(L10n.t("초증강 기본"))
	parts.append(L10n.t("법전 켜기" if bool(rules.get("laws", true)) else "법전 끄기"))
	if StringName(rules.get("speed", SPEED_NORMAL)) == SPEED_FAST:
		parts.append(L10n.t("스피드전"))
	parts.append(L10n.tf("빈자리 컴퓨터 %s", [BotTemper.label(int(rules.get("bot_level", BotTemper.DEFAULT_LEVEL)))]))
	return L10n.tf("[방 규칙] %s", [" · ".join(parts)])


## 이 규칙의 템포 업 라운드.
static func stage_rounds(rules: Dictionary) -> Array[int]:
	return SPEED_STAGE_ROUNDS.duplicate() if StringName(rules.get("speed", SPEED_NORMAL)) == SPEED_FAST else TempoUp.STAGE_ROUNDS.duplicate()
