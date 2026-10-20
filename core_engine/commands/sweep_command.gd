# File: res://core_engine/commands/sweep_command.gd
# Class: class_name SweepCommand
# Role: 소환 카드 실행 - 고른 상단 코너(오른쪽 위·반환점)에 도적떼(정방향)나 팩맨(역방향)을 소환해 바로 3~6칸 전진시킨다. 말을 만나면 그 칸의 말을 모두 사출하고 사라지고, 못 만나면 보드에 남아 라운드가 끝날 때마다 다시 3~6칸 전진한다 (NpcSweep.advance)
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


## 중립 기물은 보드에 하나만 있을 수 있다.
static func can_summon(game_state: GameState) -> bool:
	return game_state != null and game_state.npcs.is_empty()


func can_execute(_ctx: RuleContext) -> bool:
	return can_summon(state) and spawn_tiles().has(tile)


func _run() -> void:
	var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.PATROL_REVERSE if display_id == &"SUM_02" else GameEnums.NpcBehavior.CHASE_NEAREST
	var npc: NeutralNPC = state.spawn_npc(tile, behavior, sender_id, display_id)
	result = NpcSweep.advance(state, npc, state.rng.randi_range(MIN_STEPS, MAX_STEPS), true)
	if bool(result["vanished"]):
		state.remove_npc(npc)
	state.npc_swept.emit(display_id, result["path"], result["ejected"])
