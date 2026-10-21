# File: res://core_engine/npc_sweep.gd
# Class: class_name NpcSweep
# Role: 중립 기물 이동 규칙 - run: 한 번 쓸고 사라지는 질주(초증강 폭주 기관차). advance: 보드에 남는 소환 기물(도적떼·팩맨)이 정해진 방향으로 전진하다 말을 처음 만난 칸에서 그 칸의 말을 모두 사출하고 사라진다
class_name NpcSweep
extends RefCounted


## start_tile에서 나타나 direction(+1 정방향 / -1 역방향)으로 steps칸 달린다. 출발 칸과 지나는 칸의 말(출발선·결승 제외)을 모두 사출한다.
## 반환: {"npc_id", "display_id", "path": [칸], "ejected": [말 ID]}
## destroy_traps가 true면 지나가는 칸의 함정(TRP_*)도 모두 부순다 (폭주 기관차). 반환의 "destroyed"는 부순 함정 수.
static func run(state: GameState, start_tile: int, direction: int, steps: int, display_id: StringName, by_player: int, destroy_traps: bool = false) -> Dictionary:
	# 한 번 쓸고 끝나는 질주라 보드의 중립 기물 목록에 올리지 않는다 (소환·소멸 알림도 내지 않는다).
	var npc := NeutralNPC.new()
	npc.entity_id = -1
	npc.owner_id = by_player
	npc.place_at(start_tile)
	npc.behavior = GameEnums.NpcBehavior.PATROL_REVERSE if direction < 0 else GameEnums.NpcBehavior.CHASE_NEAREST
	npc.display_id = display_id
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": display_id, "path": [start_tile] as Array[int], "ejected": [] as Array[int], "destroyed": 0, "destroy_traps": destroy_traps}
	_eject_at(state, start_tile, by_player, result)
	var tile: int = start_tile
	for i: int in steps:
		var next: int = posmod(tile + direction, BoardSpec.tile_count)
		if next == GameEnums.GOAL_TILE:
			break  # 출발선(결승)은 안전지대: 그 앞에서 멈춘다
		var from_tile: int = tile
		tile = next
		npc.current_tile_idx = tile
		npc.push_step(tile)
		(result["path"] as Array[int]).append(tile)
		state.npc_stepped.emit(npc.entity_id, from_tile, tile)
		_eject_at(state, tile, by_player, result)
	return result


static func _eject_at(state: GameState, tile: int, by_player: int, result: Dictionary) -> void:
	if tile == GameEnums.GOAL_TILE:
		return
	if bool(result.get("destroy_traps", false)):
		var node: TileNode = state.board.get_tile(tile)
		for attachment: TileAttachment in node.attachments.duplicate():
			if attachment.attachment_id.begins_with("TRP"):
				node.remove_attachment(attachment)
				result["destroyed"] = int(result["destroyed"]) + 1
	for victim: PlayerPawn in state.leaders_at(tile):
		if not victim.has_left_start or victim.is_finished:
			continue
		for member: PlayerPawn in victim.stack_members():
			(result["ejected"] as Array[int]).append(member.entity_id)
		state.send_to_start(victim, by_player)


## 보드에 남아 있는 소환 기물을 direction 방향으로 steps칸 전진시킨다. 말이 서 있는 칸을 처음 만나면 그 칸의 말(스택 포함)을 모두 출발선으로 보내고 멈춘 뒤 사라진다(vanished).
## 출발선(결승) 칸은 그냥 지나간다 (거기 있는 말은 잡지 않는다). check_start가 true면 이동 전에 지금 칸부터 확인한다 (소환 직후).
## 반환: {"npc_id", "display_id", "path": [칸], "ejected": [말 ID], "vanished": bool}. 사라진 기물은 state에서 제거하지 않는다 (호출자가 remove_npc).
static func advance(state: GameState, npc: NeutralNPC, steps: int, check_start: bool = false) -> Dictionary:
	var direction: int = -1 if npc.behavior == GameEnums.NpcBehavior.PATROL_REVERSE else 1
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": npc.display_id, "path": [npc.current_tile_idx] as Array[int], "ejected": [] as Array[int], "destroyed": 0, "vanished": false}
	if check_start and _catch_at(state, npc, result):
		return result
	for i: int in steps:
		var from_tile: int = npc.current_tile_idx
		var tile: int = posmod(from_tile + direction, BoardSpec.tile_count)
		npc.current_tile_idx = tile
		npc.push_step(tile)
		(result["path"] as Array[int]).append(tile)
		state.npc_stepped.emit(npc.entity_id, from_tile, tile)
		if _catch_at(state, npc, result):
			break
	return result


## 기물이 선 칸에 말이 있으면 모두 사출하고 사라짐으로 표시한다.
static func _catch_at(state: GameState, npc: NeutralNPC, result: Dictionary) -> bool:
	if npc.current_tile_idx == GameEnums.GOAL_TILE or catchable_at(state, npc.current_tile_idx).is_empty():
		return false
	_eject_at(state, npc.current_tile_idx, npc.owner_id, result)
	result["vanished"] = true
	return true


## 그 칸에서 기물에게 잡힐 말(보드 위 스택의 맨 아래 말들).
static func catchable_at(state: GameState, tile: int) -> Array[PlayerPawn]:
	var found: Array[PlayerPawn] = []
	if tile == GameEnums.GOAL_TILE:
		return found
	for victim: PlayerPawn in state.leaders_at(tile):
		if victim.has_left_start and not victim.is_finished:
			found.append(victim)
	return found
