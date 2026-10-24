# File: res://scenes/avatar_catalog.gd
# Class: class_name AvatarCatalog
# Role: 고를 수 있는 아바타 목록. 항목마다 id·이름·자리표시자 색이 있고, 실제 그림은 res://content_trickcal/avatars/<id>/ (frames.tres 또는 portrait.png)에 넣으면 AvatarSlot이 알아서 쓴다. 에셋을 추가할 때는 ENTRIES에 한 줄 더하면 선택 화면에 나타난다
class_name AvatarCatalog
extends RefCounted

const ENTRIES: Array[Dictionary] = [
	{"id": &"avatar_01", "name": "에르핀", "color": Color("f2b01e")},
	{"id": &"avatar_02", "name": "버터", "color": Color("e8903a")},
	{"id": &"avatar_03", "name": "엘레나", "color": Color("c0524a")},
	{"id": &"avatar_04", "name": "실라", "color": Color("7fc45c")},
	{"id": &"avatar_05", "name": "셰이디", "color": Color("8a909c")},
	{"id": &"avatar_06", "name": "다야", "color": Color("6fa3dc")},
	{"id": &"avatar_07", "name": "벨리타", "color": Color("b33a3a")},
	{"id": &"avatar_08", "name": "죠안", "color": Color("3a8a52")},
]
const DEFAULT_ID: StringName = &"avatar_01"


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in ENTRIES:
		result.append(entry["id"])
	return result


## 아바타를 고를 때 나오는 캐릭터 대사 파일 (없으면 빈 문자열).
static func select_voice_path(id: StringName) -> String:
	var path: String = AvatarSlot.character_path(id) + "/select_voice.ogg"
	return path if ResourceLoader.exists(path) else ""


static func is_valid(id: StringName) -> bool:
	return ids().has(id)


## 잘못된 값이면 기본 아바타로 바꿔 돌려준다.
static func sanitize(id: Variant) -> StringName:
	var candidate: StringName = StringName(str(id))
	return candidate if is_valid(candidate) else DEFAULT_ID


static func entry_of(id: StringName) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry["id"] == id:
			return entry
	return ENTRIES[0]


static func name_of(id: StringName) -> String:
	return str(entry_of(id)["name"])


static func color_of(id: StringName) -> Color:
	return entry_of(id)["color"]


## 컴퓨터(AI) 좌석에 줄 아바타: 좌석 번호로 정해져 모든 화면에서 같고, 사람이 고른 것과 겹치지 않게 taken(이미 쓰는 id 목록)을 피한다.
static func bot_avatar(seat: int, taken: Array = []) -> StringName:
	var all: Array[StringName] = ids()
	for offset: int in range(all.size()):
		var candidate: StringName = all[(seat * 3 + offset) % all.size()]
		if not taken.has(candidate):
			return candidate
	return all[(seat * 3) % all.size()]
