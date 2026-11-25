# File: res://core_engine/board/mountain_spirits.gd
# Class: class_name MountainSpirits
# Role: 정령산 보드의 정령 칸. 빵집·옷장 자리(BoardSpec.spirit_tiles)에 하급 정령이 깃들어 칸의 효과가 바뀐다.
#       판 시작과 증강 라운드마다 정령을 다시 배치한다: 네 종류가 고르게 섞이도록 무작위 (GameState.rng로 뽑아 모든 참가자가 같은 결과).
#       효과(MoveExecutor): 불 = 딱 멈추면 1칸 뒤로 / 물 = 딱 멈추면 카드 1장 / 바람 = 딱 멈추면 1칸 앞으로 / 땅 = 지나가기만 해도 그 칸에서 멈춘다.
class_name MountainSpirits
extends RefCounted

const FIRE: StringName = &"fire"
const WATER: StringName = &"water"
const EARTH: StringName = &"earth"
const WIND: StringName = &"wind"
## [{id, name, short(칸 위 글자), text(효과), preview(말 고르기 예고), good, color}] — 배치 순서의 기준이기도 하다.
const SPIRITS: Array[Dictionary] = [
	{"id": FIRE, "name": "하급 불 정령", "short": "불", "text": "딱 멈추면 1칸 뒤로", "preview": "뒤로!", "good": false, "color": Color("ff6b4a")},
	{"id": WATER, "name": "하급 물 정령", "short": "물", "text": "딱 멈추면 카드 1장", "preview": "카드!", "good": true, "color": Color("4dabf7")},
	{"id": EARTH, "name": "하급 땅 정령", "short": "땅", "text": "지나가기만 해도 그 칸에서 정지", "preview": "멈춤", "good": false, "color": Color("c9a26b")},
	{"id": WIND, "name": "하급 바람 정령", "short": "바람", "text": "딱 멈추면 1칸 앞으로", "preview": "앞으로!", "good": true, "color": Color("69db7c")},
]
const FIRE_STEPS: int = 1
const WIND_STEPS: int = 1


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for spirit: Dictionary in SPIRITS:
		result.append(spirit["id"])
	return result


static func def_of(id: StringName) -> Dictionary:
	for spirit: Dictionary in SPIRITS:
		if spirit["id"] == id:
			return spirit
	return {}


static func name_of(id: StringName) -> String:
	return str(def_of(id).get("name", ""))


static func text_of(id: StringName) -> String:
	return str(def_of(id).get("text", ""))


## 이 칸에 깃든 정령 (없으면 &"").
static func at(state: GameState, tile: int) -> StringName:
	return StringName(str(state.spirits.get(tile, ""))) if state != null else &""


## 정령 칸마다 정령을 다시 놓는다: 네 종류를 차례로 채운 뒤(6칸이면 각 1~2곳) GameState.rng로 섞는다.
## 정령 칸이 없는 보드는 아무것도 하지 않는다 (다른 보드의 무작위 결과를 바꾸지 않게 rng도 쓰지 않는다).
static func shuffle(state: GameState) -> void:
	state.spirits = {}
	var tiles: Array[int] = BoardSpec.spirit_tiles.duplicate()
	if tiles.is_empty():
		return
	var pool: Array[StringName] = []
	var kinds: Array[StringName] = ids()
	# 종류 순서도 매번 섞는다: 6칸에 4종이면 두 종류가 2곳씩인데, 늘 같은 종류가 2곳이 되지 않게
	for index: int in range(kinds.size() - 1, 0, -1):
		var swap: int = state.rng.randi_range(0, index)
		var held: StringName = kinds[index]
		kinds[index] = kinds[swap]
		kinds[swap] = held
	for index: int in tiles.size():
		pool.append(kinds[index % kinds.size()])
	for index: int in range(pool.size() - 1, 0, -1):
		var swap: int = state.rng.randi_range(0, index)
		var held: StringName = pool[index]
		pool[index] = pool[swap]
		pool[swap] = held
	for index: int in tiles.size():
		state.spirits[tiles[index]] = pool[index]
	state.spirits_shifted.emit()
