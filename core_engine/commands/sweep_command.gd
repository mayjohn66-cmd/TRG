# File: res://core_engine/commands/sweep_command.gd
# Class: class_name SweepCommand
# Role: 소환 카드 실행 - 고른 상단 코너(오른쪽 위·반환점)에 도적떼(정방향)나 팩맨(역방향)을 소환만 한다 (소환 즉시 움직이지 않는다). 라운드가 끝날 때 가장 가까운 적 말 하나를 처치하고 사라진다 (NeutralNPC.run_ai -> NpcSweep.strike)
class_name SweepCommand
extends GameCommand

var tile: int = -1
var display_id: StringName = &"SUM_01"
## 실행 뒤 읽는다: {"npc_id", "display_id", "path": [소환 칸], "ejected": [], "vanished": false} (소환만 하므로 움직임·사출 없음).
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
	result = {"npc_id": npc.entity_id, "display_id": display_id, "path": [tile] as Array[int], "ejected": [] as Array[int], "vanished": false}
