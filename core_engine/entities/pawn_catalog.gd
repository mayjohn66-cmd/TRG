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


## 세부 기물의 한 줄 능력 설명. 기본 말은 "능력 없음".
static func ability_text(kind: GameEnums.PawnKind, unit_no: int) -> String:
	return SUB_ABILITIES.get(sub_type_of(kind, unit_no), "능력 없음")
