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
}
## 4세트 완성 시 달성하는 특수 승리 이름.
const SPECIAL_VICTORY_NAMES: Dictionary = {
	GameEnums.PawnKind.YUT: "천하제일 4업",
	GameEnums.PawnKind.CHESS: "체크메이트",
	GameEnums.PawnKind.JANGGI: "장군멍군",
	GameEnums.PawnKind.MONOPOLY: "부동산 독점",
	GameEnums.PawnKind.GO: "대마 불사",
}
const EVOLVABLE_SETS: Array[GameEnums.PawnKind] = [
	GameEnums.PawnKind.YUT,
	GameEnums.PawnKind.CHESS,
	GameEnums.PawnKind.JANGGI,
	GameEnums.PawnKind.MONOPOLY,
	GameEnums.PawnKind.GO,
]
const SubType := GameEnums.PawnSubType
## 세트별 1~4호기(체스는 5번째 = 승진한 퀸)의 세부 기물.
const SUB_TYPES: Dictionary = {
	GameEnums.PawnKind.YUT: [SubType.YUT_MAL, SubType.YUT_MAL, SubType.YUT_MAL, SubType.YUT_MAL],
	GameEnums.PawnKind.CHESS: [SubType.CHESS_PAWN, SubType.CHESS_KNIGHT, SubType.CHESS_BISHOP, SubType.CHESS_ROOK, SubType.CHESS_QUEEN],
	GameEnums.PawnKind.JANGGI: [SubType.JANGGI_PO, SubType.JANGGI_CHA, SubType.JANGGI_MA, SubType.JANGGI_SANG],
	GameEnums.PawnKind.MONOPOLY: [SubType.MONO_CAR, SubType.MONO_PLANE, SubType.MONO_SHIP, SubType.MONO_DOG],
	GameEnums.PawnKind.GO: [SubType.BADUK_BLACK, SubType.BADUK_WHITE, SubType.BADUK_BLACK, SubType.BADUK_WHITE],
}
## 세부 기물 이름 / 보드 위 한 글자 라벨 / 한 줄 능력 설명.
const SUB_NAMES: Dictionary = {
	SubType.YUT_MAL: "윷말",
	SubType.CHESS_PAWN: "체스:폰", SubType.CHESS_KNIGHT: "체스:나이트", SubType.CHESS_BISHOP: "체스:비숍", SubType.CHESS_ROOK: "체스:룩", SubType.CHESS_QUEEN: "체스:퀸",
	SubType.JANGGI_PO: "장기:포", SubType.JANGGI_CHA: "장기:차", SubType.JANGGI_MA: "장기:마", SubType.JANGGI_SANG: "장기:상",
	SubType.MONO_CAR: "모노:미니카", SubType.MONO_PLANE: "모노:비행기", SubType.MONO_SHIP: "모노:증기선", SubType.MONO_DOG: "모노:강아지",
	SubType.BADUK_BLACK: "바둑:흑돌", SubType.BADUK_WHITE: "바둑:백돌",
}
const SUB_LETTERS: Dictionary = {
	SubType.YUT_MAL: "윷",
	SubType.CHESS_PAWN: "폰", SubType.CHESS_KNIGHT: "나", SubType.CHESS_BISHOP: "비", SubType.CHESS_ROOK: "룩", SubType.CHESS_QUEEN: "퀸",
	SubType.JANGGI_PO: "포", SubType.JANGGI_CHA: "차", SubType.JANGGI_MA: "마", SubType.JANGGI_SANG: "상",
	SubType.MONO_CAR: "카", SubType.MONO_PLANE: "비", SubType.MONO_SHIP: "배", SubType.MONO_DOG: "개",
	SubType.BADUK_BLACK: "흑", SubType.BADUK_WHITE: "백",
}
const SUB_ABILITIES: Dictionary = {
	SubType.YUT_MAL: "잡으면 추가 굴림 · 아군 조우 시 업기 선택",
	SubType.CHESS_PAWN: "중앙(22번)·15번 이후 도달 시 퀸 승진",
	SubType.CHESS_KNIGHT: "경로 중간의 말·함정 무시 점프",
	SubType.CHESS_BISHOP: "코너 스침 지름길",
	SubType.CHESS_ROOK: "외곽 트랙 출발 시 +1칸",
	SubType.CHESS_QUEEN: "나이트 점프 + 코너 스침 지름길 + 룩 +1칸",
	SubType.JANGGI_PO: "경로 중간에 말이 있으면 +2칸",
	SubType.JANGGI_CHA: "경로 중간의 첫 적을 들이받아 추방",
	SubType.JANGGI_MA: "앞 1칸이 비면 +1칸, 막히면 1칸만 이동",
	SubType.JANGGI_SANG: "앞 2칸이 비면 +2칸",
	SubType.MONO_CAR: "도착 타일에 호텔 건설",
	SubType.MONO_PLANE: "옷장에서 다음 코너로 워프",
	SubType.MONO_SHIP: "처음 만나는 상대 함정을 무시하고 파괴",
	SubType.MONO_DOG: "빵집을 스쳐도 카드 1장",
	SubType.BADUK_BLACK: "알까기: 도착 칸의 적을 2칸 튕겨냄",
	SubType.BADUK_WHITE: "같은 칸 아군에게 잡기 방어막",
}


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


## 세트별 2세트 활성 효과 이름.
const SET_BONUS_2_NAMES: Dictionary = {
	GameEnums.PawnKind.YUT: "사기 윷",
	GameEnums.PawnKind.CHESS: "캐슬링",
	GameEnums.PawnKind.JANGGI: "초나라 포진",
	GameEnums.PawnKind.MONOPOLY: "월급날",
	GameEnums.PawnKind.GO: "포석",
}


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


## 세트 시너지 현황 한 줄: "체스 세트 (2/4) - [2세트 활성: 캐슬링] / [4세트: 체크메이트 특수 승리]". 기본 말은 빈 문자열.
static func synergy_line(kind: GameEnums.PawnKind, count: int) -> String:
	if kind == GameEnums.PawnKind.BASIC:
		return ""
	var two: String = "2세트 %s: %s" % ["활성" if count >= GameEnums.SET_SYNERGY_2 else "대기", SET_BONUS_2_NAMES.get(kind, "-")]
	var four: String = "4세트%s: %s 특수 승리" % [" 달성" if count >= GameEnums.PAWNS_PER_PLAYER else "", SPECIAL_VICTORY_NAMES.get(kind, "-")]
	return "%s 세트 (%d/%d) - [%s] / [%s]" % [display_set_name(kind), count, GameEnums.PAWNS_PER_PLAYER, two, four]


## 세트 효과 설명 (던전앤파이터식 세트 툴팁용).
const SET_BONUS_2_TEXT: Dictionary = {
	GameEnums.PawnKind.YUT: "이 말이 이동할 때 눈금 4 또는 5가 나오면 추가 굴림 1회",
	GameEnums.PawnKind.CHESS: "내 턴 시작 시 내 체스 말 2개의 위치를 맞바꿈 (턴당 1회)",
	GameEnums.PawnKind.JANGGI: "장기 말로 잡으면 출발선 대신 그 자리에서 1턴 구속",
	GameEnums.PawnKind.MONOPOLY: "출발선(0번)을 지나거나 밟을 때마다 생떼 카드 2장 보충",
	GameEnums.PawnKind.GO: "바둑돌은 잡히지 않는 무적 (이동 눈금 -1, 최소 1칸)",
}
const SET_BONUS_4_TEXT: Dictionary = {
	GameEnums.PawnKind.YUT: "4개를 하나로 업은 채 결승선 통과 시 즉시 승리",
	GameEnums.PawnKind.CHESS: "1등 말을 내 체스 말로 앞뒤 타일에서 동시 포위 시 승리",
	GameEnums.PawnKind.JANGGI: "한 턴에 연속 잡기로 말 3개를 잡으면 승리 + 잡기 추가 굴림",
	GameEnums.PawnKind.MONOPOLY: "호텔 6개 동시 유지 시 승리 + 4개 전원이 호텔 건설",
	GameEnums.PawnKind.GO: "네 모서리(0, 5, 10, 15번)를 내 바둑돌 4개로 점령 시 승리",
}


## 세트 툴팁 오른쪽 칸 데이터: 세트 이름·보유 수·호기별 보유 여부와 2/4세트 효과의 이름·설명·작동 여부.
static func set_panel_data(kind: GameEnums.PawnKind, owned_units: Array[int]) -> Dictionary:
	var members: Array[Dictionary] = []
	for index: int in GameEnums.PAWNS_PER_PLAYER:
		var unit: int = index + 1
		var sub_name: String = unit_label(kind, unit).split(":")[-1]
		members.append({"name": sub_name, "owned": owned_units.has(unit)})
	var count: int = owned_units.size()
	return {
		"set_name": display_set_name(kind),
		"count": count,
		"members": members,
		"bonus2": {"label": "2세트: %s" % SET_BONUS_2_NAMES.get(kind, "-"), "text": SET_BONUS_2_TEXT.get(kind, ""), "active": count >= GameEnums.SET_SYNERGY_2},
		"bonus4": {"label": "4세트: %s" % SPECIAL_VICTORY_NAMES.get(kind, "-"), "text": SET_BONUS_4_TEXT.get(kind, ""), "active": count >= GameEnums.PAWNS_PER_PLAYER},
	}


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
