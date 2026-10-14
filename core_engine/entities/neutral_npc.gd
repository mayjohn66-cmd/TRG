# File: res://core_engine/entities/neutral_npc.gd
# Class: class_name NeutralNPC
# Role: 중립 소환수(카탄의 도적떼·팩맨 고스트). 라운드 종료 시 BFS 최단 경로 AI로 스스로 이동하고 기물을 사냥한다.
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


func _chase_nearest(state: GameState) -> Dictionary:
	var report: Dictionary = {"npc_id": id, "path": [] as Array[int], "caught": [] as Array[int], "stolen_cards": [] as Array[StringName]}
	var roll: int = state.rng.randi_range(1, 6)
	var target: PlayerPawn = null
	var best_path: Array[int] = []
	for pawn: PlayerPawn in state.get_active_pawns():
		if not pawn.has_left_start or pawn.carrier != null:
			continue
		if pawn.tile_index == tile_index:
			target = pawn
			best_path = []
			break
		var path: Array[int] = state.board.shortest_path(tile_index, pawn.tile_index)
		if path.is_empty():
			continue
		if target == null or path.size() < best_path.size():
			target = pawn
			best_path = path
	if target == null:
		return report
	var move_count: int = mini(roll, best_path.size())
	for i: int in move_count:
		step_history.append(tile_index)
		var from_tile: int = tile_index
		tile_index = best_path[i]
		(report["path"] as Array[int]).append(tile_index)
		state.npc_stepped.emit(id, from_tile, tile_index)
	if tile_index == target.tile_index or best_path.is_empty():
		for victim: PlayerPawn in state.leaders_at(tile_index):
			if not victim.has_left_start:
				continue
			var stolen: StringName = state.steal_random_card(victim.owner_id, state.rng)
			if stolen != &"":
				(report["stolen_cards"] as Array[StringName]).append(stolen)
			(report["caught"] as Array[int]).append(victim.id)
			state.send_to_start(victim, -1)
	return report


func _patrol_reverse(state: GameState) -> Dictionary:
	var report: Dictionary = {"npc_id": id, "path": [] as Array[int], "caught": [] as Array[int], "stolen_cards": [] as Array[StringName]}
	var cursor: PathCursor = PathCursor.from_entity(self, true)
	for i: int in 3:
		var from_tile: int = cursor.tile
		state.board.advance_backward(cursor)
		tile_index = cursor.tile
		step_history.assign(cursor.history)
		(report["path"] as Array[int]).append(tile_index)
		state.npc_stepped.emit(id, from_tile, tile_index)
		for victim: PlayerPawn in state.leaders_at(tile_index):
			if not victim.has_left_start or tile_index == GameEnums.GOAL_TILE:
				continue
			(report["caught"] as Array[int]).append(victim.id)
			state.teleport_stack(victim, GameEnums.CENTER_TILE)
	return report
