# File: res://core_engine/turn_snapshot.gd
# Class: class_name TurnSnapshot
# Role: 턴 시작 시점의 보드 상태(기물 위치·업기·생존, 타일 설치물, 법전 큐)를 직렬화(깊은 복사)해 보관하고 즉시 복원한다 (ACT_05 롤백 / 클라이언트 동기화)
class_name TurnSnapshot
extends RefCounted

## 순수 데이터(Dictionary/Array/int/bool/StringName)만 담으므로 그대로 RPC로 전송할 수 있다.
var data: Dictionary = {}


static func capture(state: GameState) -> TurnSnapshot:
	var snapshot := TurnSnapshot.new()
	var pawn_data: Dictionary = {}
	for pawn: PlayerPawn in state.pawns:
		var carried_ids: Array[int] = []
		for carried_pawn: PlayerPawn in pawn.carried:
			carried_ids.append(carried_pawn.entity_id)
		pawn_data[pawn.entity_id] = {
			"tile": pawn.current_tile_idx,
			"history": pawn.step_history.duplicate(),
			"started": pawn.has_left_start,
			"finished": pawn.is_finished,
			"retreated": pawn.retreated_from_start,
			"carrier": pawn.carrier.entity_id if pawn.carrier != null else -1,
			"carried": carried_ids,
		}
	var npc_data: Array[Dictionary] = []
	for npc: NeutralNPC in state.npcs:
		npc_data.append({
			"id": npc.entity_id,
			"owner": npc.owner_id,
			"tile": npc.current_tile_idx,
			"history": npc.step_history.duplicate(),
			"behavior": npc.behavior,
			"display_id": npc.display_id,
		})
	var attachment_data: Dictionary = {}
	for tile: TileNode in state.board.tiles:
		if not tile.attachments.is_empty():
			attachment_data[tile.tile_id] = tile.serialize_attachments()
	snapshot.data = {
		"pawns": pawn_data,
		"npcs": npc_data,
		"attachments": attachment_data,
		"laws": state.rulebook.law_ids(),
		"meta": {
			"current_player": state.current_player,
			"turn_direction": state.turn_direction,
			"reverse_move_rounds_left": state.reverse_move_rounds_left,
			"round_number": state.round_number,
		},
	}
	return snapshot


static func from_dict(source: Dictionary) -> TurnSnapshot:
	var snapshot := TurnSnapshot.new()
	snapshot.data = source.duplicate(true)
	return snapshot


func to_dict() -> Dictionary:
	return data.duplicate(true)


## 스냅샷을 상태에 즉시 복원한다. 손패는 스냅샷 대상이 아니므로 그대로 유지된다
## (이번 턴 도중 소모된 개입 카드와 발동한 ACT_05 자체는 복구되지 않는다).
## restore_meta가 true면 현재 플레이어·진행 방향 등 턴 메타도 함께 되돌린다 (커맨드 undo용).
func restore(state: GameState, restore_meta: bool = false) -> void:
	var pawn_data: Dictionary = data["pawns"]
	for pawn: PlayerPawn in state.pawns:
		var entry: Dictionary = pawn_data[pawn.entity_id]
		pawn.current_tile_idx = int(entry["tile"])
		pawn.step_history.assign(entry["history"])
		pawn.has_left_start = bool(entry["started"])
		pawn.is_finished = bool(entry["finished"])
		pawn.retreated_from_start = bool(entry["retreated"])
		pawn.carrier = null
		pawn.carried.clear()
	for pawn: PlayerPawn in state.pawns:
		var entry: Dictionary = pawn_data[pawn.entity_id]
		var carrier_id: int = int(entry["carrier"])
		if carrier_id != -1:
			pawn.carrier = state.get_pawn(carrier_id)
		for carried_id: Variant in entry["carried"]:
			var carried_pawn: PlayerPawn = state.get_pawn(int(carried_id))
			if carried_pawn != null:
				pawn.carried.append(carried_pawn)

	state.clear_npcs()
	for entry: Dictionary in data["npcs"]:
		var npc := NeutralNPC.new()
		npc.entity_id = int(entry["id"])
		npc.owner_id = int(entry["owner"])
		npc.current_tile_idx = int(entry["tile"])
		npc.step_history.assign(entry["history"])
		npc.behavior = entry["behavior"]
		npc.display_id = entry["display_id"]
		state.npcs.append(npc)

	for tile: TileNode in state.board.tiles:
		tile.clear_attachments()
	var attachment_data: Dictionary = data["attachments"]
	for tile_key: Variant in attachment_data.keys():
		for attachment_entry: Dictionary in attachment_data[tile_key]:
			var attachment: TileAttachment = AttachmentRegistry.from_dict(attachment_entry)
			if attachment != null:
				state.board.get_tile(int(tile_key)).add_attachment(attachment)

	state.rulebook.set_laws_from_ids(data["laws"])

	if restore_meta:
		var meta: Dictionary = data["meta"]
		state.current_player = int(meta["current_player"])
		state.turn_direction = int(meta["turn_direction"])
		state.reverse_move_rounds_left = int(meta["reverse_move_rounds_left"])
		state.round_number = int(meta["round_number"])
	state.snapshot_restored.emit()
