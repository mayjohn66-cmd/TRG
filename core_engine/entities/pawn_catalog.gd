# File: res://core_engine/entities/pawn_catalog.gd
# Class: class_name PawnCatalog
# Role: 기물 세트(윷/체스/장기/모노폴리/바둑/쇼기/아케이드)의 이름·약어·호기 명칭·능력·필살기 데이터. 뷰와 로그가 같은 표기를 쓰도록 한곳에 모은다
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
	GameEnums.PawnKind.ARCADE: "아케이드",
}
const EVOLVABLE_SETS: Array[GameEnums.PawnKind] = [
	GameEnums.PawnKind.YUT,
	GameEnums.PawnKind.CHESS,
	GameEnums.PawnKind.JANGGI,
	GameEnums.PawnKind.MONOPOLY,
	GameEnums.PawnKind.GO,
	GameEnums.PawnKind.SHOGI,
	GameEnums.PawnKind.ARCADE,
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
	GameEnums.PawnKind.ARCADE: [SubType.CHECKERS_KING, SubType.LUDO_AVENGER, SubType.POOL_8BALL, SubType.KART_STAR, SubType.MINESWEEPER_FLAG],
}
## 세부 기물 이름 / 보드 위 한 글자 라벨 / 한 줄 능력 설명.
const SUB_NAMES: Dictionary = {
	SubType.YUT_MAL: "윷말",
	SubType.CHESS_PAWN: "체스:폰", SubType.CHESS_KNIGHT: "체스:나이트", SubType.CHESS_BISHOP: "체스:비숍", SubType.CHESS_ROOK: "체스:룩", SubType.CHESS_QUEEN: "체스:퀸",
	SubType.JANGGI_PO: "장기:포", SubType.JANGGI_CHA: "장기:차", SubType.JANGGI_MA: "장기:마", SubType.JANGGI_SANG: "장기:상",
	SubType.MONO_CAR: "모노:미니카", SubType.MONO_PLANE: "모노:비행기", SubType.MONO_SHIP: "모노:증기선", SubType.MONO_DOG: "모노:강아지",
	SubType.BADUK_BLACK: "바둑:흑돌", SubType.BADUK_WHITE: "바둑:백돌",
	SubType.SHOGI_FU: "쇼기:보병", SubType.SHOGI_HISHA: "쇼기:비차", SubType.SHOGI_KAKU: "쇼기:각행", SubType.SHOGI_KEIMA: "쇼기:계마",
	SubType.CHECKERS_KING: "아케이드:킹 체커", SubType.LUDO_AVENGER: "아케이드:루도 복수자", SubType.POOL_8BALL: "아케이드:8번 공", SubType.KART_STAR: "아케이드:스타 카트", SubType.MINESWEEPER_FLAG: "아케이드:지뢰찾기 공병",
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
	SubType.CHECKERS_KING: "킹", SubType.LUDO_AVENGER: "루", SubType.POOL_8BALL: "8", SubType.KART_STAR: "★", SubType.MINESWEEPER_FLAG: "깃",
}
## 영어 화면의 보드판 라벨 (한두 글자).
const PROMOTED_LETTERS_EN: Dictionary = {
	SubType.SHOGI_FU: "To", SubType.SHOGI_HISHA: "DK", SubType.SHOGI_KAKU: "DH", SubType.SHOGI_KEIMA: "NK",
}
const SUB_LETTERS_EN: Dictionary = {
	SubType.YUT_MAL: "Y",
	SubType.CHESS_PAWN: "P", SubType.CHESS_KNIGHT: "N", SubType.CHESS_BISHOP: "B", SubType.CHESS_ROOK: "R", SubType.CHESS_QUEEN: "Q",
	SubType.JANGGI_PO: "Ca", SubType.JANGGI_CHA: "Ch", SubType.JANGGI_MA: "Ho", SubType.JANGGI_SANG: "El",
	SubType.MONO_CAR: "MC", SubType.MONO_PLANE: "Pl", SubType.MONO_SHIP: "Sh", SubType.MONO_DOG: "Dg",
	SubType.BADUK_BLACK: "Bk", SubType.BADUK_WHITE: "Wt",
	SubType.SHOGI_FU: "Fu", SubType.SHOGI_HISHA: "Hi", SubType.SHOGI_KAKU: "Ka", SubType.SHOGI_KEIMA: "Ke",
	SubType.CHECKERS_KING: "K", SubType.LUDO_AVENGER: "Lu", SubType.POOL_8BALL: "8", SubType.KART_STAR: "★", SubType.MINESWEEPER_FLAG: "Ms",
}
## 일본어 화면의 보드판 라벨 (한 글자, 한자·가나).
const PROMOTED_LETTERS_JA: Dictionary = {
	SubType.SHOGI_FU: "と", SubType.SHOGI_HISHA: "竜", SubType.SHOGI_KAKU: "馬", SubType.SHOGI_KEIMA: "圭",
}
const SUB_LETTERS_JA: Dictionary = {
	SubType.YUT_MAL: "ユ",
	SubType.CHESS_PAWN: "ポ", SubType.CHESS_KNIGHT: "ナ", SubType.CHESS_BISHOP: "ビ", SubType.CHESS_ROOK: "ル", SubType.CHESS_QUEEN: "ク",
	SubType.JANGGI_PO: "包", SubType.JANGGI_CHA: "車", SubType.JANGGI_MA: "馬", SubType.JANGGI_SANG: "象",
	SubType.MONO_CAR: "カ", SubType.MONO_PLANE: "飛", SubType.MONO_SHIP: "船", SubType.MONO_DOG: "犬",
	SubType.BADUK_BLACK: "黒", SubType.BADUK_WHITE: "白",
	SubType.SHOGI_FU: "歩", SubType.SHOGI_HISHA: "飛", SubType.SHOGI_KAKU: "角", SubType.SHOGI_KEIMA: "桂",
	SubType.CHECKERS_KING: "キ", SubType.LUDO_AVENGER: "ド", SubType.POOL_8BALL: "8", SubType.KART_STAR: "★", SubType.MINESWEEPER_FLAG: "旗",
}
## 언어별 보드판 라벨 표 (한국어는 SUB_LETTERS·PROMOTED_LETTERS).
const LETTERS_BY_LANG: Dictionary = {"en": [SUB_LETTERS_EN, PROMOTED_LETTERS_EN], "ja": [SUB_LETTERS_JA, PROMOTED_LETTERS_JA]}
const BASIC_LETTERS: Dictionary = {"ko": "말", "en": "P", "ja": "駒"}
const SUB_ABILITIES: Dictionary = {
	SubType.YUT_MAL: "처치 시 재굴림 +1",
	SubType.CHESS_PAWN: "반환점 이상 도달 시 퀸 승급",
	SubType.CHESS_KNIGHT: "코너 바로 앞에 멈추면 +2칸",
	SubType.CHESS_BISHOP: "코너 바로 앞에 멈추면 +1칸 코너 진입",
	SubType.CHESS_ROOK: "코너를 꺾지 않는 직진 +2칸",
	SubType.CHESS_QUEEN: "이동 +2칸 · 말·함정 관통",
	SubType.JANGGI_PO: "경로에 내 말이 있으면 +3칸",
	SubType.JANGGI_CHA: "코너를 꺾지 않는 직진 +2칸",
	SubType.JANGGI_MA: "앞 칸 비면 +2칸",
	SubType.JANGGI_SANG: "앞 칸 비면 +2칸",
	SubType.MONO_CAR: "반환점 통과 시 카드 +1",
	SubType.MONO_PLANE: "옷장 사용 시 카드 +1",
	SubType.MONO_SHIP: "첫 적 설치물 무시·파괴",
	SubType.MONO_DOG: "빵집 스침만 해도 카드 +1",
	SubType.BADUK_BLACK: "홀수 눈금으로 전진하면 +1칸",
	SubType.BADUK_WHITE: "잡기·함정 1회 방어",
	SubType.SHOGI_FU: "반환점 통과 시 승급",
	SubType.SHOGI_HISHA: "반환점 통과 시 승급",
	SubType.SHOGI_KAKU: "반환점 통과 시 승급",
	SubType.SHOGI_KEIMA: "반환점 통과 시 승급",
	SubType.CHECKERS_KING: "지나가는 칸의 적 처치",
	SubType.LUDO_AVENGER: "리벤지 부스터 발동 시 +4칸 전진",
	SubType.POOL_8BALL: "처치하면 +3칸",
	SubType.KART_STAR: "모든 추가 이동 +2칸 · 이동 중 함정 면역",
	SubType.MINESWEEPER_FLAG: "함정 면역 · 밟은 적 함정 해체 +카드 1장",
}
## 1회용 필살기: 세부 기물 -> 스킬 ID / 이름 / 설명. 필살기가 없으면 스킬 ID가 빈 값이다.
const SKILL_IDS: Dictionary = {
	SubType.BADUK_BLACK: &"shoot",
	SubType.JANGGI_CHA: &"charge",
	SubType.CHESS_ROOK: &"castle",
	SubType.MONO_PLANE: &"warp",
	SubType.SHOGI_FU: &"drop",
	SubType.CHESS_BISHOP: &"fianchetto",
	SubType.JANGGI_SANG: &"quake",
	SubType.SHOGI_HISHA: &"slash",
	SubType.SHOGI_KAKU: &"horse",
	SubType.POOL_8BALL: &"bank_shot",
	SubType.MINESWEEPER_FLAG: &"plant_mine",
	SubType.MONO_CAR: &"hotel",
	SubType.YUT_MAL: &"extra_roll",
	SubType.CHESS_KNIGHT: &"knight_guard",
	SubType.JANGGI_PO: &"cannon",
	SubType.JANGGI_MA: &"back_kick",
	SubType.SHOGI_KEIMA: &"keima_jump",
}
## 나리 승급해야 쓸 수 있는 필살기 (용왕·용마).
const PROMOTED_SKILLS: Array[StringName] = [&"slash", &"horse"]
const SKILL_NAMES: Dictionary = {
	&"shoot": "진짜 알까기 슈팅",
	&"charge": "직선 전차 저격",
	&"castle": "단독 캐슬링",
	&"warp": "직항 워프",
	&"drop": "모치고마 낙하",
	&"fianchetto": "피앙케토",
	&"quake": "코끼리 지진",
	&"slash": "용왕 베기",
	&"horse": "용마 십자 베기",
	&"bank_shot": "뱅크샷",
	&"plant_mine": "지뢰 매설",
	&"hotel": "호텔 건설",
	&"extra_roll": "한 번 더!",
	&"knight_guard": "기사의 맹세",
	&"cannon": "포격",
	&"back_kick": "뒷발차기",
	&"keima_jump": "계마 도약",
}
const SKILL_TEXTS: Dictionary = {
	&"shoot": "조준 발사 → 적 전원 출발선, 근처 안착",
	&"charge": "직선 돌진 → 선두 적 처치",
	&"castle": "굴리기 전 아군 1개와 위치 교환",
	&"warp": "반환점으로 직항",
	&"drop": "대기 말 1개를 보병 옆에 즉시 낙하",
	&"fianchetto": "대각선 코너로 즉시 이동",
	&"quake": "앞뒤 2칸의 설치물 모두 파괴",
	&"slash": "[용왕] 앞 2칸의 적 처치",
	&"horse": "[용마] 앞뒤 1칸의 적 처치",
	&"bank_shot": "앞쪽 가장 가까운 적에게 돌진",
	&"plant_mine": "지금 칸에 지뢰 설치",
	&"hotel": "지금 칸에 내 호텔 설치",
	&"extra_roll": "이번 차례에 주사위를 한 번 더 굴린다",
	&"knight_guard": "이번 차례 동안 사출 면역",
	&"cannon": "가장 앞에 있는 적의 말 처치",
	&"back_kick": "뒤 2칸의 적 처치",
	&"keima_jump": "+2칸 전진 · 처치하면 +1칸 더",
}


## 말 하나의 이름/라벨: 나리 승급한 쇼기 기물은 승급 이름·글자를 쓴다.
static func name_of_pawn(kind: GameEnums.PawnKind, unit_no: int, promoted: bool) -> String:
	var sub: GameEnums.PawnSubType = sub_type_of(kind, unit_no)
	if promoted and PROMOTED_NAMES.has(sub):
		return PROMOTED_NAMES[sub]
	return SUB_NAMES.get(sub, "기본")


static func letter_of_pawn(kind: GameEnums.PawnKind, unit_no: int, promoted: bool) -> String:
	var sub: GameEnums.PawnSubType = sub_type_of(kind, unit_no)
	var tables: Array = LETTERS_BY_LANG.get(L10n.current_lang, [SUB_LETTERS, PROMOTED_LETTERS])
	if promoted and PROMOTED_LETTERS.has(sub):
		return (tables[1] as Dictionary)[sub]
	return (tables[0] as Dictionary).get(sub, "")


## 세부 기물의 필살기 ID. 없으면 빈 StringName.
static func skill_of(sub: GameEnums.PawnSubType) -> StringName:
	return SKILL_IDS.get(sub, &"")


static func skill_name(skill_id: StringName) -> String:
	return SKILL_NAMES.get(skill_id, "")


static func skill_text(skill_id: StringName) -> String:
	return SKILL_TEXTS.get(skill_id, "")


## 필살기 한 줄 (카드·툴팁의 구분선 아래): "이름: 설명". [1회]·필살기 같은 머리말은 붙이지 않는다.
static func skill_line(skill_id: StringName) -> String:
	if skill_id == &"":
		return ""
	return "%s: %s" % [skill_name(skill_id), skill_text(skill_id)]


## 패시브 설명 (카드·툴팁의 구분선 위): 패시브가 둘이면(" · "로 이은 것) 줄을 나눈다. 패시브가 없으면 빈 글.
## "패시브:" 같은 머리말은 붙이지 않는다.
static func passive_lines(kind: GameEnums.PawnKind, unit_no: int) -> String:
	return split_passive(ability_text(kind, unit_no))


static func split_passive(text: String) -> String:
	if text == "없음" or text == "능력 없음":
		return ""
	return text.replace(" · ", "\n")


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
	return (LETTERS_BY_LANG.get(L10n.current_lang, [SUB_LETTERS])[0] as Dictionary).get(sub_type_of(kind, unit_no), "")


## 진화하지 않은 기본 말의 보드판 라벨 (한국어 "말", 영어 "P", 일본어 "駒").
static func basic_letter() -> String:
	return str(BASIC_LETTERS.get(L10n.current_lang, "말"))


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


## 세트에서 지급할 수 있는 호기 수: 대부분 4, 아케이드는 5 (체스 퀸은 승진으로만 생기므로 세지 않는다).
static func unit_count(kind: GameEnums.PawnKind) -> int:
	if not SUB_TYPES.has(kind):
		return 0
	return GameEnums.PAWNS_PER_PLAYER if kind == GameEnums.PawnKind.CHESS else (SUB_TYPES[kind] as Array).size()


## 세트의 '같은 세부 기물' 묶음: 호기 번호들을 세부 기물 종류별로 묶는다 (체스는 [[1],[2],[3],[4]], 바둑은 [[1,3],[2,4]], 윷은 [[1,2,3,4]]).
static func unit_groups(kind: GameEnums.PawnKind) -> Array:
	var groups: Array = []
	var seen: Array = []
	for unit: int in range(1, unit_count(kind) + 1):
		var sub: GameEnums.PawnSubType = sub_type_of(kind, unit)
		var index: int = seen.find(sub)
		if index == -1:
			seen.append(sub)
			groups.append([unit])
		else:
			(groups[index] as Array).append(unit)
	return groups
