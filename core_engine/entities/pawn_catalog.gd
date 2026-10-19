# File: res://core_engine/entities/pawn_catalog.gd
# Class: class_name PawnCatalog
# Role: 기물 세트(윷/체스/장기/모노폴리/바둑)의 이름·약어·1~4호기 명칭 데이터. 뷰와 로그가 같은 표기를 쓰도록 한곳에 모은다
class_name PawnCatalog
extends RefCounted

const SET_NAMES: Dictionary = {
	GameEnums.PawnKind.BASIC: "기본",
	GameEnums.PawnKind.YUT: "윷",
	GameEnums.PawnKind.CHESS: "체스",
	GameEnums.PawnKind.JANGGI: "장기",
	GameEnums.PawnKind.MONOPOLY: "모노폴리",
	GameEnums.PawnKind.GO: "바둑",
	GameEnums.PawnKind.SHOGI: "쇼기",
}
const EVOLVABLE_SETS: Array[GameEnums.PawnKind] = [
	GameEnums.PawnKind.YUT,
	GameEnums.PawnKind.CHESS,
	GameEnums.PawnKind.JANGGI,
	GameEnums.PawnKind.MONOPOLY,
	GameEnums.PawnKind.GO,
	GameEnums.PawnKind.SHOGI,
]
const SubType := GameEnums.PawnSubType
## 세트별 1~4호기(체스는 5번째 = 승진한 퀸)의 세부 기물.
const SUB_TYPES: Dictionary = {
	GameEnums.PawnKind.YUT: [SubType.YUT_MAL, SubType.YUT_MAL, SubType.YUT_MAL, SubType.YUT_MAL],
	GameEnums.PawnKind.CHESS: [SubType.CHESS_PAWN, SubType.CHESS_KNIGHT, SubType.CHESS_BISHOP, SubType.CHESS_ROOK, SubType.CHESS_QUEEN],
	GameEnums.PawnKind.JANGGI: [SubType.JANGGI_PO, SubType.JANGGI_CHA, SubType.JANGGI_MA, SubType.JANGGI_SANG],
	GameEnums.PawnKind.MONOPOLY: [SubType.MONO_CAR, SubType.MONO_PLANE, SubType.MONO_SHIP, SubType.MONO_DOG],
	GameEnums.PawnKind.GO: [SubType.BADUK_BLACK, SubType.BADUK_WHITE, SubType.BADUK_BLACK, SubType.BADUK_WHITE],
	GameEnums.PawnKind.SHOGI: [SubType.SHOGI_FU, SubType.SHOGI_HISHA, SubType.SHOGI_KAKU, SubType.SHOGI_KEIMA],
}
## 세부 기물 이름 / 보드 위 한 글자 라벨 / 한 줄 능력 설명.
const SUB_NAMES: Dictionary = {
	SubType.YUT_MAL: "윷말",
	SubType.CHESS_PAWN: "체스:폰", SubType.CHESS_KNIGHT: "체스:나이트", SubType.CHESS_BISHOP: "체스:비숍", SubType.CHESS_ROOK: "체스:룩", SubType.CHESS_QUEEN: "체스:퀸",
	SubType.JANGGI_PO: "장기:포", SubType.JANGGI_CHA: "장기:차", SubType.JANGGI_MA: "장기:마", SubType.JANGGI_SANG: "장기:상",
	SubType.MONO_CAR: "모노:미니카", SubType.MONO_PLANE: "모노:비행기", SubType.MONO_SHIP: "모노:증기선", SubType.MONO_DOG: "모노:강아지",
	SubType.BADUK_BLACK: "바둑:흑돌", SubType.BADUK_WHITE: "바둑:백돌",
	SubType.SHOGI_FU: "쇼기:보병", SubType.SHOGI_HISHA: "쇼기:비차", SubType.SHOGI_KAKU: "쇼기:각행", SubType.SHOGI_KEIMA: "쇼기:계마",
}
## 나리(成り) 승급 뒤 이름 / 한 글자 라벨 (보병 -> 토금, 비차 -> 용왕, 각행 -> 용마, 계마 -> 성계).
const PROMOTED_NAMES: Dictionary = {
	SubType.SHOGI_FU: "쇼기:토금", SubType.SHOGI_HISHA: "쇼기:용왕", SubType.SHOGI_KAKU: "쇼기:용마", SubType.SHOGI_KEIMA: "쇼기:성계",
}
const PROMOTED_LETTERS: Dictionary = {
	SubType.SHOGI_FU: "토", SubType.SHOGI_HISHA: "용", SubType.SHOGI_KAKU: "마", SubType.SHOGI_KEIMA: "금",
}
const SUB_LETTERS: Dictionary = {
	SubType.YUT_MAL: "윷",
	SubType.CHESS_PAWN: "폰", SubType.CHESS_KNIGHT: "나", SubType.CHESS_BISHOP: "비", SubType.CHESS_ROOK: "룩", SubType.CHESS_QUEEN: "퀸",
	SubType.JANGGI_PO: "포", SubType.JANGGI_CHA: "차", SubType.JANGGI_MA: "마", SubType.JANGGI_SANG: "상",
	SubType.MONO_CAR: "카", SubType.MONO_PLANE: "비", SubType.MONO_SHIP: "배", SubType.MONO_DOG: "개",
	SubType.BADUK_BLACK: "흑", SubType.BADUK_WHITE: "백",
	SubType.SHOGI_FU: "보", SubType.SHOGI_HISHA: "비", SubType.SHOGI_KAKU: "각", SubType.SHOGI_KEIMA: "계",
}
const SUB_ABILITIES: Dictionary = {
	SubType.YUT_MAL: "처치·눈금 4/5 시 재굴림 +1 · 자동 업기",
	SubType.CHESS_PAWN: "반환점 이상 도달 시 퀸 승급",
	SubType.CHESS_KNIGHT: "경로 말·함정 관통 (도착 칸만 판정)",
	SubType.CHESS_BISHOP: "코너 스치면 +2칸",
	SubType.CHESS_ROOK: "없음",
	SubType.CHESS_QUEEN: "이동 +2칸 · 말·함정 관통",
	SubType.JANGGI_PO: "경로에 말 있으면 넘어서 +3칸",
	SubType.JANGGI_CHA: "없음",
	SubType.JANGGI_MA: "앞 칸 비면 +2칸",
	SubType.JANGGI_SANG: "앞 칸 비면 +3칸",
	SubType.MONO_CAR: "도착 칸 호텔 5턴 · 출발선 통과 시 카드 +1",
	SubType.MONO_PLANE: "옷장 → 더 먼 곳으로 워프",
	SubType.MONO_SHIP: "첫 적 설치물 무시·파괴",
	SubType.MONO_DOG: "빵집 스침만 해도 카드 +1",
	SubType.BADUK_BLACK: "없음",
	SubType.BADUK_WHITE: "처치 면역 · 아군 보호 (눈금 -1)",
	SubType.SHOGI_FU: "반환점 이상 통과 시 토금 승급 (+1칸)",
	SubType.SHOGI_HISHA: "이동 +2칸",
	SubType.SHOGI_KAKU: "코너 스치면 +2칸 · 승급 시 앞 1칸 처치",
	SubType.SHOGI_KEIMA: "첫 2칸 함정·말 관통 · 승급 시 +1칸",
}
## 1회용 필살기: 세부 기물 -> 스킬 ID / 이름 / 설명. 필살기가 없으면 스킬 ID가 빈 값이다.
const SKILL_IDS: Dictionary = {
	SubType.BADUK_BLACK: &"shoot",
	SubType.JANGGI_CHA: &"charge",
	SubType.CHESS_ROOK: &"castle",
	SubType.MONO_PLANE: &"warp",
	SubType.SHOGI_FU: &"drop",
}
const SKILL_NAMES: Dictionary = {
	&"shoot": "진짜 알까기 슈팅",
	&"charge": "직선 전차 저격",
	&"castle": "단독 캐슬링",
	&"warp": "직항 워프",
	&"drop": "모치고마 낙하",
}
const SKILL_TEXTS: Dictionary = {
	&"shoot": "조준 발사 → 적 전원 출발선, 근처 안착",
	&"charge": "직선 돌진 → 선두 적 처치 (없으면 다음 코너)",
	&"castle": "굴리기 전 아군 1개와 위치 교환",
	&"warp": "빵집·코너 중 1곳으로 직항",
	&"drop": "대기 말 1개를 보병 옆에 즉시 낙하",
}


## 말 하나의 이름/라벨: 나리 승급한 쇼기 기물은 승급 이름·글자를 쓴다.
static func name_of_pawn(kind: GameEnums.PawnKind, unit_no: int, promoted: bool) -> String:
	var sub: GameEnums.PawnSubType = sub_type_of(kind, unit_no)
	if promoted and PROMOTED_NAMES.has(sub):
		return PROMOTED_NAMES[sub]
	return SUB_NAMES.get(sub, "기본")


static func letter_of_pawn(kind: GameEnums.PawnKind, unit_no: int, promoted: bool) -> String:
	var sub: GameEnums.PawnSubType = sub_type_of(kind, unit_no)
	if promoted and PROMOTED_LETTERS.has(sub):
		return PROMOTED_LETTERS[sub]
	return SUB_LETTERS.get(sub, "")


## 세부 기물의 필살기 ID. 없으면 빈 StringName.
static func skill_of(sub: GameEnums.PawnSubType) -> StringName:
	return SKILL_IDS.get(sub, &"")


static func skill_name(skill_id: StringName) -> String:
	return SKILL_NAMES.get(skill_id, "")


static func skill_text(skill_id: StringName) -> String:
	return SKILL_TEXTS.get(skill_id, "")


## (세트, 호기)의 세부 기물. 기본 말은 NONE.
static func sub_type_of(kind: GameEnums.PawnKind, unit_no: int) -> GameEnums.PawnSubType:
	if not SUB_TYPES.has(kind):
		return SubType.NONE
	var list: Array = SUB_TYPES[kind]
	return list[clampi(unit_no - 1, 0, list.size() - 1)]


static func display_set_name(kind: GameEnums.PawnKind) -> String:
	return SET_NAMES[kind]


## 보드판 위 말에 붙이는 라벨 (폰·나·비·룩·퀸 / 포·차·마·상 / 카·비·배·개 / 흑·백 / 윷). 기본 말은 빈 문자열.
static func unit_letter(kind: GameEnums.PawnKind, unit_no: int) -> String:
	return SUB_LETTERS.get(sub_type_of(kind, unit_no), "")


## "체스:폰" 형태의 말 표기 (윷은 "윷말"). 기본 말은 "기본".
static func unit_label(kind: GameEnums.PawnKind, unit_no: int) -> String:
	return SUB_NAMES.get(sub_type_of(kind, unit_no), "기본")


## 세부 기물의 한 줄 능력 설명. 기본 말은 "능력 없음".
static func ability_text(kind: GameEnums.PawnKind, unit_no: int) -> String:
	return SUB_ABILITIES.get(sub_type_of(kind, unit_no), "능력 없음")


## 툴팁용 기물 전체 이름: "[체스 3호기 - 비숍]", 기본 말은 "[기본 말]".
static func full_name(kind: GameEnums.PawnKind, unit_no: int) -> String:
	if kind == GameEnums.PawnKind.BASIC:
		return "[기본 말]"
	var sub_name: String = unit_label(kind, unit_no)
	if ":" in sub_name:
		sub_name = sub_name.split(":")[1]
	return "[%s %d호기 - %s]" % [display_set_name(kind), unit_no, sub_name]


## 세트의 '같은 세부 기물' 묶음: 호기 번호들을 세부 기물 종류별로 묶는다 (체스는 [[1],[2],[3],[4]], 바둑은 [[1,3],[2,4]], 윷은 [[1,2,3,4]]).
static func unit_groups(kind: GameEnums.PawnKind) -> Array:
	var groups: Array = []
	var seen: Array = []
	for unit: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
		var sub: GameEnums.PawnSubType = sub_type_of(kind, unit)
		var index: int = seen.find(sub)
		if index == -1:
			seen.append(sub)
			groups.append([unit])
		else:
			(groups[index] as Array).append(unit)
	return groups
