# File: res://core_engine/board/board_catalog.gd
# Class: class_name BoardCatalog
# Role: 고를 수 있는 보드판 목록 (보드판 선택). 규칙(MatchRules "board")에 보드 id가 실리고, 판을 시작할 때 GameState.setup이 apply로 BoardSpec에 적용한다.
#       지금은 기본 보드 하나뿐이다. 새 보드는 BOARDS에 한 줄 더하고 (칸 수가 24·32가 아니면 BoardSpec.layout_for도 확장) 이름·설명 번역 행을 넣으면
#       방 규칙·싱글 시작 화면·도감의 선택 목록에 저절로 나온다. 모든 참가자가 같은 보드를 써야 하므로 판 도중에는 바꾸지 않는다.
class_name BoardCatalog
extends RefCounted

const DEFAULT_ID: StringName = &"classic"
## [{id, name(한국어 원문), desc(한 줄 설명), tiles(칸 수)}]
const BOARDS: Array[Dictionary] = [
	{"id": &"classic", "name": "기본 보드", "desc": "32칸 사각 순환 트랙 · 반시계 한 바퀴", "tiles": 32},
]


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for board: Dictionary in BOARDS:
		result.append(board["id"])
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
	BoardSpec.apply(tiles_of(current_id))


## 판을 시작할 때 부른다: 고른 보드가 마지막으로 적용한 보드와 다를 때만 적용한다
## (그대로면 건드리지 않아, 단위 테스트가 BoardSpec.apply(24)로 직접 정한 배치를 판 시작이 덮어쓰지 않는다).
static func apply_for_match(id: Variant) -> void:
	if sanitize(id) != current_id:
		apply(id)


## 선택 화면·도감의 특수 칸 요약 (전역 값을 바꾸지 않고 layout_for로 센다): [[이름, 값], ...]
static func facts_of(id: Variant) -> Array:
	var tiles: int = tiles_of(id)
	var layout: Dictionary = BoardSpec.layout_for(tiles)
	return [
		["칸 수", "%d칸 (한 변 %d칸)" % [tiles, tiles / 4]],
		["코너", "%d곳" % (layout["corner_tiles"] as Array).size()],
		["반환점", "%d번" % int(layout["halfway_tile"])],
		["빵집", "%d곳" % (layout["bakery_tiles"] as Array).size()],
		["옷장", "%d곳" % (layout["portal_tiles"] as Array).size()],
		["부스터 발판", "%d곳" % (layout["dash_tiles"] as Array).size()],
	]
