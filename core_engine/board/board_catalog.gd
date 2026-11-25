# File: res://core_engine/board/board_catalog.gd
# Class: class_name BoardCatalog
# Role: 고를 수 있는 보드판 목록과 보드마다 다른 것 전부의 단일 출처 (보드판 선택). 규칙(MatchRules "board")에 보드 id가 실리고,
#       판을 시작할 때 GameState.setup이 apply로 BoardSpec에 적용한다. 모든 참가자가 같은 보드를 써야 하므로 판 도중에는 바꾸지 않는다.
#
#       새 보드 만들기 (코드 분기 없이 이 파일만):
#       1. BOARDS에 한 줄: id·이름·설명·칸 수, 빵집 자리(shop)와 옷장 자리(portal)에 둘 칸 종류, 판 바닥 그림(surface)·색(palette)
#       2. 그림: 판 바닥 그림(surface 경로), 선택 화면 미리보기 assets/ui/trickcal/board_preview/<id>.webp
#       3. 번역: translations.csv에 이름·설명 행 (도감 화살표 "<이름> 보기" 행 포함)
#       4. (선택) law_variants: 특수 승리를 이 보드에 맞게 바꿔 쓰기 (이름·조건·카드 문구·아이콘·승리 연출·결과 문구)
#       빵집 자리·옷장 자리에 새로운 종류의 칸(새 규칙)이 필요할 때만 SHOP_KINDS/PORTAL_KINDS에 종류를 더하고 그 칸의 규칙 코드를 짠다.
class_name BoardCatalog
extends RefCounted

const DEFAULT_ID: StringName = &"classic"

## 빵집 자리(bakery_tiles) 칸 종류: 규칙은 모두 같다 (딱 멈추면 카드 1장). 보이는 이름·알림·법전 표시·색 띠·칸 그림만 다르다.
## name: 칸 이름 / toast: 도착 알림 / law_tag: LAW_02 목표 칸 표시 / visit_stamp: LAW_02 진행 도장("" = 기본 식권 문구)
## legend·legend_color: 도감 미니 보드 범례 글·색 / words: 특수 승리 카드 문구에서 "빵집"을 바꿔 쓸 말 / band·edge·ink: 칸 색 / decal: 칸 그림
## rulebook: 도감 "보드" 장의 칸 설명 (art·tone·summary, 제목은 "<칸 이름> (<이 칸을 쓰는 보드들>)")
## (선택) tiles_key: 빵집 자리에 다른 칸이 설 때 BoardSpec의 목록 이름 (정령 칸 = "spirit_tiles", 기본은 빵집)
## (선택) decal_bounds: 그림에서 쓸 영역(1254px 원본 기준, 없으면 전체) / decal_span: 칸 대비 그림 크기(기본 0.74) / decal_cutout: 어두운 선을 뚫어 그린다
const SHOP_KINDS: Dictionary = {
	&"bakery": {"rulebook": {"art": &"bread", "tone": Color("d9822b"), "summary": "딱 멈추면 [b]생떼 카드 1장[/b]! 어떤 카드인지는 본인만 알아요."},
		"name": "빵집", "toast": "빵집!", "law_tag": "[식권 목표]", "visit_stamp": "", "legend": "빵집 (카드 1장)", "legend_color": Color("ffd98a"),
		"words": {"ko": "빵집", "en": "bakery", "ja": "パン屋"},
		"band": Color("f4bd55"), "edge": Color("b68b43"), "ink": Color("845221"), "decal": "res://assets/board/decals/BOARD_BAKERY.png", "decal_bounds": Rect2(196, 409, 862, 482)},
	&"store": {"rulebook": {"art": &"store", "tone": Color("3f86b8"), "summary": "에르핀 왕국의 빵집 자리예요. 딱 멈추면 [b]생떼 카드 1장[/b]! 어떤 카드인지는 본인만 알아요."},
		"name": "편의점", "toast": "편의점!", "law_tag": "[편의점 목표]", "visit_stamp": "편의점 방문! (%d/%d)", "legend": "편의점 (카드 1장)", "legend_color": Color("ffd98a"),
		"words": {"ko": "편의점", "en": "convenience store", "ja": "コンビニ"},
		"band": Color("7cc4f2"), "edge": Color("3f86b8"), "ink": Color("245b86"), "decal": "res://assets/board/decals/BOARD_STORE_MONATIUM_v3.png", "decal_bounds": Rect2(19, 34, 1221, 1170), "decal_span": 0.86},
	&"witch_shop": {"rulebook": {"art": &"witch_shop", "tone": Color("8a5a34"), "summary": "에르핀 왕국의 빵집 자리예요. 딱 멈추면 [b]생떼 카드 1장[/b]! 어떤 카드인지는 본인만 알아요."},
		"name": "마녀 상점", "toast": "상점!", "law_tag": "[단골 목표]", "visit_stamp": "마녀 상점 방문! (%d/%d)", "legend": "마녀 상점 (카드 1장)", "legend_color": Color("ffd98a"),
		"words": {"ko": "마녀 상점", "en": "witch shop", "ja": "魔女の店"},
		"band": Color("d8a25e"), "edge": Color("8a5a34"), "ink": Color("5e3a1c"), "decal": "res://assets/board/decals/BOARD_CARROT_FRIES_INK.png", "decal_span": 0.86},
	&"spirit": {"rulebook": {"art": &"spirit", "tone": Color("2f9e8f"), "summary": "증강 라운드마다 [b]하급 정령[/b]이 자리를 바꿔 깃들어요. 불은 1칸 뒤로, 물은 카드 1장, 바람은 1칸 앞으로 (딱 멈추면), 땅은 [b]지나가기만 해도[/b] 그 칸에서 멈춰요."},
		"name": "정령 칸", "toast": "정령!", "law_tag": "[순례 목표]", "visit_stamp": "정령 칸 순례! (%d/%d)", "legend": "정령 칸 (증강 라운드마다 정령이 바뀜)", "legend_color": Color("bfe7df"),
		"tiles_key": "spirit_tiles", "words": {"ko": "정령 칸", "en": "spirit tile", "ja": "精霊マス"},  # 일본어(ja) 값은 일본어 화면에서 _JA 글꼴(Mochiy Pop One)로 그린다
		"band": Color("63c7b2"), "edge": Color("2f7f73"), "ink": Color("1d5a51"), "decal": "res://assets/board/decals/BOARD_SPIRIT.png", "decal_span": 0.8},
}
## 옷장 자리(portal_tiles) 칸 종류: 종류마다 규칙이 다르다 (옷장 = 왕복 워프, 자판기 = 랜덤 음료 버프, 가마솥 = 랜덤 물약).
## tiles_key: BoardSpec에서 이 칸들을 담는 목록 이름 / warps: 옷장처럼 워프가 있는가 / legend: 도감 미니 보드 범례 / 색·그림 키는 SHOP_KINDS와 같다
const PORTAL_KINDS: Dictionary = {
	&"portal": {"rulebook": {"art": &"wardrobe", "tone": Color("2f9aa3"), "summary": "딱 멈추면 [b]순간이동[/b]! 두 옷장은 [b]왕복[/b]이라 밟은 쪽의 반대편으로 가요. 지나가기만 하면 아무 일도 없어요."},
		"name": "옷장", "tiles_key": "portal_tiles", "warps": true, "legend": "옷장", "legend_color": Color("c8eef0"),
		"band": Color("5fc4c9"), "edge": Color("3f8f96"), "ink": Color("24636b"), "decal": "res://assets/board/decals/BOARD_PORTAL.png", "decal_bounds": Rect2(296, 268, 662, 739)},
	&"vending": {"rulebook": {"art": &"vending", "tone": Color("c4574a"), "summary": "옷장 자리에 서요. 딱 멈추면 [b]음료수가 랜덤으로 한 캔[/b] 나와요. 지나가기만 하면 아무 일도 없고, 순간이동은 없어요."},
		"name": "자판기", "tiles_key": "vending_tiles", "warps": false, "legend": "자판기 (랜덤 음료 버프)", "legend_color": Color("ffd0c8"),
		"band": Color("ff8f7a"), "edge": Color("c4574a"), "ink": Color("8c2f26"), "decal": "res://assets/board/decals/BOARD_VENDING_v2.png", "decal_bounds": Rect2(207, 86, 841, 1105), "decal_span": 0.86},
	&"cauldron": {"rulebook": {"art": &"cauldron", "tone": Color("6b4a8f"), "summary": "옷장 자리에 서요. 딱 멈추면 [b]물약이 랜덤으로 끓어요[/b]. 좋은 물약 3종과 [b]나쁜 물약 2종[/b]이 같은 확률로 나와요. 지나가기만 하면 아무 일도 없어요."},
		"name": "마녀의 가마솥", "tiles_key": "cauldron_tiles", "warps": false, "legend": "마녀의 가마솥 (랜덤 물약)", "legend_color": Color("d9c8f2"),
		"band": Color("7fd18b"), "edge": Color("5b3a8a"), "ink": Color("3e2366"), "decal": "res://assets/board/decals/BOARD_CAULDRON.png", "decal_span": 0.86, "decal_cutout": true},
	&"spirit": {"rulebook": {"art": &"spirit", "tone": Color("2f9e8f"), "summary": "증강 라운드마다 [b]하급 정령[/b]이 자리를 바꿔 깃들어요."},
		"name": "정령 칸", "tiles_key": "spirit_tiles", "warps": false, "legend": "정령 칸 (증강 라운드마다 정령이 바뀜)", "legend_color": Color("bfe7df"),
		"band": Color("63c7b2"), "edge": Color("2f7f73"), "ink": Color("1d5a51"), "decal": "res://assets/board/decals/BOARD_SPIRIT.png", "decal_span": 0.8},
}

## 보드 목록. 키:
## id·name(한국어 원문)·desc(한 줄 설명)·tiles(칸 수) / shop·portal: 위 칸 종류 / surface: 판 바닥 그림 / palette: 기본 색(BoardSkin.PALETTE_DEFAULT)에서 바꿀 색
## city_buttons: 굴림 버튼을 도시풍으로 / law_variants: {교칙 ID: 바꿔 쓰는 판} (키 설명은 VictoryLaw.variant 참고)
const BOARDS: Array[Dictionary] = [
	{"id": &"classic", "settings_note": "빵집에서 카드를 얻고 옷장으로 순간이동해요.", "name": "에르핀 왕국", "desc": "32칸 사각 순환 트랙 · 빵집(카드)과 옷장(순간이동)", "tiles": 32,
		"shop": &"bakery", "portal": &"portal", "surface": "res://assets/board/trickcal/board_surface_symbols_v1.png", "palette": {}},
	{"id": &"monatium", "settings_note": "편의점에서 카드를, 자판기에서 음료를 얻어요.", "name": "모나티엄 도시", "desc": "32칸 사각 순환 트랙 · 편의점(카드)과 자판기(랜덤 음료 버프)", "tiles": 32,
		"shop": &"store", "portal": &"vending", "surface": "res://assets/board/monatium/board_surface_symbols_v1.png", "city_buttons": true,
		"palette": {  # 도시: 차가운 회청색 타일, 네이비 테두리, 네온 청록 부스터 발판
			"fill": Color("f2f5fb"), "edge": Color("4f5d7a"), "ink": Color("2f3b57"), "band": Color("9db0cf"),
			"corner_edge": Color("377f94"), "corner_ink": Color("17677c"), "corner_fill": Color("e4f4f8"),
			"half_edge": Color("8170bf"), "half_ink": Color("59428e"), "half_fill": Color("eee8fc"),
			"shadow": Color(0.08, 0.1, 0.2, 0.16),
			"dash_base": Color("1f2a55"), "dash_inner": Color("2fd6d0"), "dash_pulse": Color("8a7bff"), "dash_rim": Color("e6fbff")},
		"law_variants": {
			"LAW_02": {"name": "와라! 모나티엄 25", "condition": "편의점에 {p1}회 방문",
				"card_title": {"ko": "[특수 승리] 와라! 모나티엄 25", "en": "[Special Win] Wara! Monatium 25", "ja": "[特殊勝利] ワラ！モナティウム25"},
				"icon": "laws/LAW_02_MONATIUM.png", "stage": &"monatium_cash",
				"win_reason": "편의점 %d회 방문 · 와라! 모나티엄 25 완성!", "result_phrase": "MONATIUM DAYS", "geometry_key": "LAW_02:M",
				"theme": {"font": "bungee", "headline": "MONATIUM DAYS", "lines": "MONATIUM\nDAYS", "ink": "10223d", "accent": "2f86d6", "tilt": -0.055},
				"paper": "e6f1fb", "comic_title": {"upper": "ffe391", "lower": "ffffff", "shadow": "1f5fa8"}},
		}},
	{"id": &"belatien", "settings_note": "마녀 상점에서 카드를, 가마솥에서 물약을 얻어요.", "name": "벨라티엔 왕국", "desc": "마녀들의 도시 · 마녀 상점(카드)과 마녀의 가마솥(랜덤 물약, 나쁜 물약도 있다)", "tiles": 32,
		"shop": &"witch_shop", "portal": &"cauldron", "surface": "res://assets/board/belatien/board_surface_symbols_v2.png",
		"palette": {  # 마녀 도시: 연보라 타일·짙은 보라 테두리, 코너·반환점은 갈색 나무, 보라 마법빛 부스터 발판
			"fill": Color("f5effb"), "edge": Color("6b4a8f"), "ink": Color("4a2f6b"), "band": Color("b99be0"),
			"corner_edge": Color("7a5232"), "corner_ink": Color("5a3a20"), "corner_fill": Color("f4e8d8"),
			"half_edge": Color("8a5a34"), "half_ink": Color("5e3a1c"), "half_fill": Color("efe0cc"),
			"shadow": Color(0.2, 0.1, 0.3, 0.16),
			"dash_base": Color("3b1f5c"), "dash_inner": Color("b56cff"), "dash_pulse": Color("e08cff"), "dash_rim": Color("f5e6ff")},
		"law_variants": {
			"LAW_02": {"name": "Bad Carrot", "condition": "마녀 상점에 {p1}회 방문",
				"card_title": {"ko": "[특수 승리] Bad Carrot", "en": "[Special Win] Bad Carrot", "ja": "[特殊勝利] Bad Carrot"},
				"icon": "laws/LAW_02_BAD_CARROT.png", "stage": &"bad_carrot",
				"win_reason": "마녀는 엄청난 것을 훔쳐갔습니다.", "result_phrase": "BAD CARROT", "geometry_key": "LAW_02:W",  # 「마리사는 엄청난 것을 훔쳐갔습니다」 패러디
				"theme": {"font": "bangers", "headline": "BAD CARROT", "lines": "BAD\nCARROT", "ink": "1f1233", "accent": "8a4fc4", "tilt": -0.05},
				"paper": "efe4f7", "comic_title": {"upper": "e9ccff", "lower": "ffffff", "shadow": "5a2a8a"}},
		}},
	{"id": &"spirit_mountain", "settings_note": "증강 라운드에 정령 발판의 속성이 바뀌어요.", "since": "1.3.0", "name": "정령산", "desc": "정령들의 산 · 증강 라운드마다 빵집·옷장 자리 6곳에 하급 정령(불·물·땅·바람)이 깃들어 효과가 바뀐다", "tiles": 32,
		"shop": &"spirit", "portal": &"spirit", "surface": "res://assets/board/spirit_mountain/board_surface.png",
		"palette": {
			"fill": Color("e9f5f3"), "edge": Color("508984"), "ink": Color("285a55"), "band": Color("a9d2c9"),
			"corner_edge": Color("507f79"), "corner_ink": Color("2b5c56"), "corner_fill": Color("edf5ee"),
			"half_edge": Color("4b847e"), "half_ink": Color("2b5c56"), "half_fill": Color("d9ede7"),
			"shadow": Color(0.1, 0.2, 0.18, 0.16),
			"dash_base": Color("1f4f48"), "dash_inner": Color("63e6be"), "dash_pulse": Color("a5d8ff"), "dash_rim": Color("e6fcf5")},
		"law_variants": {
			"LAW_02": {"name": "정령산 순례", "condition": "정령 칸에 {p1}회 멈춤",
				"card_title": {"ko": "[특수 승리] 정령산 순례", "en": "[Special Win] Spirit Mountain Pilgrimage", "ja": "[特殊勝利] 精霊山巡礼"},  # 일본어(ja) 값은 일본어 화면에서 _JA 글꼴(Mochiy Pop One)로 그린다
				"win_reason": "정령 칸 %d회 순례 · 정령산 순례 완성!", "result_phrase": "SPIRIT PILGRIMAGE", "geometry_key": "LAW_02:S",
				# 아이콘·도입 무대(icon·stage)는 아직 없어 원래 식권 것을 쓴다 (전용 그림이 생기면 넣는다)
				"theme": {"font": "bungee", "headline": "SPIRIT PILGRIMAGE", "lines": "SPIRIT\nPILGRIMAGE", "ink": "14332d", "accent": "2f9e8f", "tilt": -0.05},
				"paper": "e6f4ef", "comic_title": {"upper": "c3fae8", "lower": "ffffff", "shadow": "1d6b5f"}},
		}},
]


## 고를 수 있는 보드 id (다음 버전용 보드("since")는 그 버전이 되기 전까지 빠진다: 놀이터·방 규칙·도감·저장된 선택 모두).
static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for board: Dictionary in available():
		result.append(board["id"])
	return result


## 공개된 보드 데이터 (BOARDS 순서). 화면은 BOARDS 대신 이것을 돈다.
static func available() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for board: Dictionary in BOARDS:
		if ReleaseGate.is_open(str(board.get("since", ""))):
			result.append(board)
	return result


static func is_valid(id: Variant) -> bool:
	return ids().has(StringName(str(id)))


## 밖(네트워크·저장)에서 온 값을 고른 보드 id로 고친다 (모르는 값은 기본 보드).
static func sanitize(value: Variant) -> StringName:
	var id: StringName = StringName(str(value))
	return id if is_valid(id) else DEFAULT_ID


static func def_of(id: Variant) -> Dictionary:
	var wanted: StringName = sanitize(id)
	for board: Dictionary in BOARDS:
		if board["id"] == wanted:
			return board
	return BOARDS[0]


static func name_of(id: Variant) -> String:
	return str(def_of(id)["name"])


static func tiles_of(id: Variant) -> int:
	return int(def_of(id)["tiles"])


## 마지막으로 이 목록에서 적용한 보드 (처음 값은 BoardSpec 기본 배치와 같은 기본 보드).
static var current_id: StringName = DEFAULT_ID


## 이 보드를 BoardSpec(전역 보드 모양)에 적용한다.
static func apply(id: Variant) -> void:
	current_id = sanitize(id)
	var board: Dictionary = def_of(current_id)
	BoardSpec.apply(tiles_of(current_id), board["portal"], board["shop"], current_id)
	AugmentRegistry.apply_board_variants()  # 바꿔 쓰는 특수 승리의 선택 카드 문구도 이 보드에 맞춘다


## 판을 시작할 때 부른다: 고른 보드가 마지막으로 적용한 보드와 다를 때만 적용한다
## (그대로면 건드리지 않아, 단위 테스트가 BoardSpec.apply(24)로 직접 정한 배치를 판 시작이 덮어쓰지 않는다).
static func apply_for_match(id: Variant) -> void:
	if sanitize(id) != current_id:
		apply(id)


## 이 보드의 특수 칸 배치 (전역 값을 바꾸지 않는다: 선택 화면·도감용).
static func layout_of(id: Variant) -> Dictionary:
	return BoardSpec.layout_for(tiles_of(id), def_of(id)["portal"], def_of(id)["shop"])


## 선택 화면·도감의 특수 칸 요약 (전역 값을 바꾸지 않고 layout_for로 센다): [[이름, 값], ...]
static func facts_of(id: Variant) -> Array:
	var board: Dictionary = def_of(id)
	var tiles: int = tiles_of(id)
	var layout: Dictionary = layout_of(id)
	var facts: Array = [
		["칸 수", "%d칸 (한 변 %d칸)" % [tiles, tiles / 4]],
		["코너", "%d곳" % (layout["corner_tiles"] as Array).size()],
		["반환점", "%d번" % int(layout["halfway_tile"])],
	]
	for kind_id: StringName in board_kinds(id):  # 빵집 자리·옷장 자리가 같은 칸 종류(정령 칸)면 한 줄로
		var kind: Dictionary = tile_kind(kind_id)
		facts.append([str(kind["name"]), "%d곳" % (layout.get(str(kind.get("tiles_key", "bakery_tiles")), []) as Array).size()])
	facts.append(["부스터 발판", "%d곳" % (layout["dash_tiles"] as Array).size()])
	return facts


## 이 보드의 빵집 자리·옷장 자리 칸 종류 (같은 종류면 하나).
static func board_kinds(id: Variant) -> Array[StringName]:
	var board: Dictionary = def_of(id)
	var kinds: Array[StringName] = [board["shop"]]
	if board["portal"] != board["shop"]:
		kinds.append(board["portal"])
	return kinds


## 빵집 자리·옷장 자리 칸 종류 하나의 정의 (보드 그림의 칸 kind 문자열로 찾는다, 없으면 {}).
static func tile_kind(kind: Variant) -> Dictionary:
	var key: StringName = StringName(str(kind))
	return SHOP_KINDS.get(key, PORTAL_KINDS.get(key, {}))


## 지금 판(BoardSpec)의 보드 정의.
static func current() -> Dictionary:
	return def_of(BoardSpec.board_id)


## 지금 판의 빵집 자리 칸 종류 정의 (SHOP_KINDS 항목).
static func current_shop() -> Dictionary:
	return SHOP_KINDS.get(BoardSpec.shop_kind, SHOP_KINDS[&"bakery"])


## 지금 판의 옷장 자리 칸 종류 정의 (PORTAL_KINDS 항목).
static func current_portal() -> Dictionary:
	return PORTAL_KINDS.get(BoardSpec.portal_kind, PORTAL_KINDS[&"portal"])


## 이 보드가 이 교칙을 바꿔 쓰는 판 ({} = 원래 교칙 그대로).
static func law_variant(board_id: Variant, law_id: String) -> Dictionary:
	return (def_of(board_id).get("law_variants", {}) as Dictionary).get(law_id, {})


## 어느 보드든 이 교칙을 바꿔 쓰는가 (도감의 보드 넘기기 화살표).
static func has_law_variant(law_id: String) -> bool:
	for board: Dictionary in BOARDS:
		if (board.get("law_variants", {}) as Dictionary).has(law_id):
			return true
	return false
