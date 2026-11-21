# File: res://core_engine/tools/tool_mahjong.gd
# Class: class_name ToolMahjong
# Role: 리치 마작 만리장성 - 마작패 3개를 동시에 쯔모해 조합으로 칸수를 정한다 (핑후 2 / 또이츠 3 / 슌쯔 5 / 커쯔 8 / 역만(국사무쌍·대삼원) 12칸 + 한 번 더). 걷기 전용 판정 도구
class_name ToolMahjong
extends BaseJudgmentTool

## 패 번호: 0~8 만수(1~9) / 9~17 통수(1~9) / 18~26 삭수(1~9) / 27 백 / 28 발 / 29 중.
const TILE_KINDS: int = 30
const HONOR_START: int = 27
const TERMINALS: Array[int] = [0, 8, 9, 17, 18, 26, 27, 28, 29]
const YAKUMAN_CHANCE: float = 0.08
## 누적 확률 경계: 역만 8% / 커쯔 10% / 슌쯔 22% / 또이츠 25% / 핑후 35%.
const CHANCE_KOTSU: float = 0.18
const CHANCE_SHUNTSU: float = 0.40
const CHANCE_TOITSU: float = 0.65
const STEPS: Dictionary = {&"pinfu": 2, &"toitsu": 3, &"shuntsu": 5, &"kotsu": 8, &"yakuman": 12}
const LABELS: Dictionary = {&"pinfu": "핑후", &"toitsu": "또이츠", &"shuntsu": "슌쯔", &"kotsu": "커쯔", &"yakuman": "역만"}
const SUIT_NAMES: Array[String] = ["만", "통", "삭"]
const HONOR_NAMES: Array[String] = ["백", "발", "중"]


func _init() -> void:
	tool_id = &"DICE_MAHJONG"
	display_name = "리치 마작 만리장성"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var chance: float = rng.randf()
	var category: StringName = &"pinfu"
	if chance < YAKUMAN_CHANCE:
		category = &"yakuman"
	elif chance < CHANCE_KOTSU:
		category = &"kotsu"
	elif chance < CHANCE_SHUNTSU:
		category = &"shuntsu"
	elif chance < CHANCE_TOITSU:
		category = &"toitsu"
	return roll_category(category, rng)


## 조합 종류를 정해 놓고 실제 패 3개를 만든다 (테스트가 직접 부른다).
func roll_category(category: StringName, rng: RandomNumberGenerator) -> RollResult:
	var tiles: Array[int] = build_tiles(category, rng)
	var yakuman_name: String = ""
	if category == &"yakuman":
		yakuman_name = "대삼원" if tiles.has(HONOR_START) and tiles.has(HONOR_START + 1) and tiles.has(HONOR_START + 2) else "국사무쌍"
	var label: String = yakuman_name if yakuman_name != "" else str(LABELS[category])
	var result: RollResult = RollResult.make(tool_id, int(STEPS[category]), {"tiles": tiles, "hand": category, "label": label})
	result.reroll = category == &"yakuman"
	return result


static func build_tiles(category: StringName, rng: RandomNumberGenerator) -> Array[int]:
	var tiles: Array[int] = []
	match category:
		&"yakuman":
			if rng.randi_range(0, 1) == 0:
				tiles = [HONOR_START, HONOR_START + 1, HONOR_START + 2]
			else:
				tiles = _distinct(rng, TERMINALS, 3)
		&"kotsu":
			var kind: int = rng.randi_range(0, TILE_KINDS - 1)
			tiles = [kind, kind, kind]
		&"shuntsu":
			var suit: int = rng.randi_range(0, 2)
			var start: int = rng.randi_range(0, 6)
			tiles = [suit * 9 + start, suit * 9 + start + 1, suit * 9 + start + 2]
		&"toitsu":
			var pair: int = rng.randi_range(0, TILE_KINDS - 1)
			var other: int = rng.randi_range(0, TILE_KINDS - 1)
			while other == pair:
				other = rng.randi_range(0, TILE_KINDS - 1)
			tiles = [pair, pair, other]
		_:
			var all_kinds: Array[int] = []
			for kind: int in TILE_KINDS:
				all_kinds.append(kind)
			tiles = _distinct(rng, all_kinds, 3)
			while evaluate(tiles) != &"pinfu":
				tiles = _distinct(rng, all_kinds, 3)
	# 보여 주는 순서는 섞는다 (쯔모 연출).
	for i: int in range(tiles.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = tiles[i]
		tiles[i] = tiles[j]
		tiles[j] = swap
	return tiles


## 패 3개의 조합 판정. 역만(대삼원·국사무쌍)은 확률로 정하므로 여기서도 알아본다.
static func evaluate(tiles: Array) -> StringName:
	var sorted: Array = tiles.duplicate()
	sorted.sort()
	if sorted[0] == sorted[1] and sorted[1] == sorted[2]:
		return &"kotsu"
	if sorted == [HONOR_START, HONOR_START + 1, HONOR_START + 2]:
		return &"yakuman"
	var distinct_terminals: bool = sorted[0] != sorted[1] and sorted[1] != sorted[2]
	if distinct_terminals:
		var all_terminal: bool = true
		for tile: Variant in sorted:
			if not TERMINALS.has(int(tile)):
				all_terminal = false
		if all_terminal:
			return &"yakuman"
		if int(sorted[2]) < HONOR_START and int(sorted[1]) == int(sorted[0]) + 1 and int(sorted[2]) == int(sorted[1]) + 1 and int(sorted[0]) / 9 == int(sorted[2]) / 9:
			return &"shuntsu"
	if sorted[0] == sorted[1] or sorted[1] == sorted[2]:
		return &"toitsu"
	return &"pinfu"


static func _distinct(rng: RandomNumberGenerator, pool: Array[int], count: int) -> Array[int]:
	var copy: Array[int] = pool.duplicate()
	var picked: Array[int] = []
	for i: int in count:
		var index: int = rng.randi_range(0, copy.size() - 1)
		picked.append(copy[index])
		copy.remove_at(index)
	return picked


## 패 이름: "3만", "7통", "9삭", "백/발/중".
static func tile_name(tile: int) -> String:
	if tile >= HONOR_START:
		return HONOR_NAMES[tile - HONOR_START]
	return "%d%s" % [tile % 9 + 1, SUIT_NAMES[tile / 9]]
