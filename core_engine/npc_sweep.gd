# File: res://core_engine/npc_sweep.gd
# Class: class_name NpcSweep
# Role: 도적떼·팩맨 쓸고 지나가기 - 코너에서 나타나 한 줄로 달리며 지나가는 칸의 모든 말을 출발선으로 사출하고 사라진다 (초증강 도적단 대습격, 소환 카드). 즉시 끝나는 효과라 라운드 NPC 페이즈에 남지 않는다
class_name NpcSweep
extends RefCounted


## start_tile에서 나타나 direction(+1 정방향 / -1 역방향)으로 steps칸 달린다. 출발 칸과 지나는 칸의 말(출발선·결승 제외)을 모두 사출한다.
## 반환: {"npc_id", "display_id", "path": [칸], "ejected": [말 ID]}
static func run(state: GameState, start_tile: int, direction: int, steps: int, display_id: StringName, by_player: int) -> Dictionary:
	var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.PATROL_REVERSE if direction < 0 else GameEnums.NpcBehavior.CHASE_NEAREST
	var npc: NeutralNPC = state.spawn_npc(start_tile, behavior, by_player, display_id)
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": display_id, "path": [start_tile] as Array[int], "ejected": [] as Array[int]}
	_eject_at(state, start_tile, by_player, result)
	var tile: int = start_tile
	for i: int in steps:
		var next: int = posmod(tile + direction, BoardSpec.tile_count)
		if next == GameEnums.GOAL_TILE:
			break  # 출발선(결승)은 안전지대: 그 앞에서 멈춘다
		var from_tile: int = tile
		tile = next
		npc.current_tile_idx = tile
		npc.step_history.append(tile)
		(result["path"] as Array[int]).append(tile)
		state.npc_stepped.emit(npc.entity_id, from_tile, tile)
		_eject_at(state, tile, by_player, result)
	state.remove_npc(npc)
	return result


static func _eject_at(state: GameState, tile: int, by_player: int, result: Dictionary) -> void:
	if tile == GameEnums.GOAL_TILE:
		return
	for victim: PlayerPawn in state.leaders_at(tile):
		if not victim.has_left_start or victim.is_finished:
			continue
		for member: PlayerPawn in victim.stack_members():
			(result["ejected"] as Array[int]).append(member.entity_id)
		state.send_to_start(victim, by_player)
