# File: res://core_engine/commands/sweep_command.gd
# Class: class_name SweepCommand
# Role: 소환 카드 실행 - 고른 상단 코너(오른쪽 위·반환점)에서 도적떼(정방향)나 팩맨(역방향)이 3~6칸 무작위로 달리며 길 위의 모든 말을 사출하고 사라진다 (NpcSweep)
class_name SweepCommand
extends GameCommand

const MIN_STEPS: int = 3
const MAX_STEPS: int = 6

var tile: int = -1
var display_id: StringName = &"SUM_01"
## 실행 뒤 UI가 읽는다: NpcSweep 결과 {"npc_id", "display_id", "path", "ejected"}.
var result: Dictionary = {}


func _init(acting_player: int = -1, start_tile: int = -1, id: StringName = &"SUM_01") -> void:
	super()
	sender_id = acting_player
	tile = start_tile
	display_id = id
	command_name = "Sweep"


## 소환할 수 있는 칸: 상단 코너 두 곳 (오른쪽 위 코너, 반환점).
static func spawn_tiles() -> Array[int]:
	return [BoardSpec.side, BoardSpec.halfway_tile] as Array[int]


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and spawn_tiles().has(tile)


func _run() -> void:
	var steps: int = state.rng.randi_range(MIN_STEPS, MAX_STEPS)
	result = NpcSweep.run(state, tile, -1 if display_id == &"SUM_02" else 1, steps, display_id, sender_id)
	state.npc_swept.emit(display_id, result["path"], result["ejected"])
