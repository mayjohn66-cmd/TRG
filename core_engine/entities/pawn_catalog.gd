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
## 보드판 위 말에 붙이는 한 글자 라벨.
const SET_LETTERS: Dictionary = {
	GameEnums.PawnKind.BASIC: "",
	GameEnums.PawnKind.YUT: "윷",
	GameEnums.PawnKind.CHESS: "체",
	GameEnums.PawnKind.JANGGI: "장",
	GameEnums.PawnKind.MONOPOLY: "카",
	GameEnums.PawnKind.GO: "바",
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
const UNIT_NAMES: Dictionary = {
	GameEnums.PawnKind.YUT: ["도", "개", "걸", "윷"],
	GameEnums.PawnKind.CHESS: ["폰", "나이트", "비숍", "룩"],
	GameEnums.PawnKind.JANGGI: ["졸", "마", "상", "포"],
	GameEnums.PawnKind.MONOPOLY: ["자동차", "모자", "신발", "골무"],
	GameEnums.PawnKind.GO: ["백돌", "흑돌", "양패", "대마"],
}


static func display_set_name(kind: GameEnums.PawnKind) -> String:
	return SET_NAMES[kind]


static func letter(kind: GameEnums.PawnKind) -> String:
	return SET_LETTERS[kind]


## "체스:폰" 형태의 말 표기. 기본 말은 "기본".
static func unit_label(kind: GameEnums.PawnKind, unit_no: int) -> String:
	if kind == GameEnums.PawnKind.BASIC:
		return "기본"
	var names: Array = UNIT_NAMES[kind]
	return "%s:%s" % [SET_NAMES[kind], names[clampi(unit_no - 1, 0, names.size() - 1)]]
