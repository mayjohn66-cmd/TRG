# File: res://core_engine/entities/neutral_npc.gd
# Class: class_name NeutralNPC
# Role: 중립 소환수(카탄의 도적떼·팩맨 고스트). 라운드 종료 시 BFS 최단 경로 AI로 스스로 이동하며, 기물을 한 번 잡으면 소멸한다(report.vanished)
class_name NeutralNPC
extends BoardEntity

var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST
var display_id: StringName = &"SUM_01"


## 라운드 종료 NPC 페이즈에서 호출된다. 이동 결과를 이벤트 딕셔너리로 반환한다.
func run_ai(state: GameState) -> Dictionary:
	match behavior:
		GameEnums.NpcBehavior.PATROL_REVERSE:
			return _patrol_reverse(state)
	return _chase_nearest(state)


func _new_report() -> Dictionary:
	return {"npc_id": entity_id, "path": [] as Array[int], "caught": [] as Array[int], "stolen_cards": [] as Array[StringName], "vanished": false}


func _chase_nearest(state: GameState) -> Dictionary:
	var report: Dictionary = _new_report()
	var roll: int = state.rng.randi_range(1, 6)
	var targets: Array[BoardEntity] = []
	var standing_on_target: bool = false
	for pawn: PlayerPawn in state.get_active_pawns():
		if not pawn.has_left_start or pawn.carrier != null:
			continue
		targets.append(pawn)
		if pawn.current_tile_idx == current_tile_idx:
			standing_on_target = true
	var route: Array[int] = state.board.find_nearest_entity_bfs(current_tile_idx, targets)
	if route.is_empty() and not standing_on_target:
		return report
	for i: int in mini(roll, route.size()):
		var from_tile: int = current_tile_idx
		current_tile_idx = route[i]
		step_history.append(current_tile_idx)
		(report["path"] as Array[int]).append(current_tile_idx)
		state.npc_stepped.emit(entity_id, from_tile, current_tile_idx)
	if route.is_empty() or current_tile_idx == route.back():
		for victim: PlayerPawn in state.leaders_at(current_tile_idx):
			if not victim.has_left_start:
				continue
			var stolen: StringName = state.steal_random_card(victim.owner_id, state.rng)
			if stolen != &"":
				(report["stolen_cards"] as Array[StringName]).append(stolen)
			(report["caught"] as Array[int]).append(victim.entity_id)
			state.send_to_start(victim, -1)
	report["vanished"] = not (report["caught"] as Array[int]).is_empty()
	return report


func _patrol_reverse(state: GameState) -> Dictionary:
	var report: Dictionary = _new_report()
	var cursor: PathCursor = PathCursor.from_entity(self, true)
	for i: int in 3:
		var from_tile: int = cursor.tile
		state.board.advance_backward(cursor)
		current_tile_idx = cursor.tile
		step_history.assign(cursor.history)
		(report["path"] as Array[int]).append(current_tile_idx)
		state.npc_stepped.emit(entity_id, from_tile, current_tile_idx)
		for victim: PlayerPawn in state.leaders_at(current_tile_idx):
			if not victim.has_left_start or current_tile_idx == GameEnums.GOAL_TILE:
				continue
			(report["caught"] as Array[int]).append(victim.entity_id)
			state.teleport_stack(victim, GameEnums.HALFWAY_TILE)
		if not (report["caught"] as Array[int]).is_empty():
			break
	report["vanished"] = not (report["caught"] as Array[int]).is_empty()
	return report
