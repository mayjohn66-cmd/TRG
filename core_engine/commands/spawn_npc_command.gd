# File: res://core_engine/commands/spawn_npc_command.gd
# Class: class_name SpawnNpcCommand
# Role: 소환형 카드 실행 - 지정 타일에 중립 NPC(카탄의 도적떼/팩맨 고스트)를 소환한다
class_name SpawnNpcCommand
extends GameCommand

var tile: int = -1
var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST
var display_id: StringName = &"SUM_01"


func _init(acting_player: int = -1, target_tile: int = -1, npc_behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST, id: StringName = &"SUM_01") -> void:
	super()
	sender_id = acting_player
	tile = target_tile
	behavior = npc_behavior
	display_id = id
	command_name = "SpawnNpc"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and state.board.is_valid_tile(tile) and state.npcs.size() < GameEnums.MAX_NPCS


func _run() -> void:
	state.spawn_npc(tile, behavior, sender_id, display_id)
