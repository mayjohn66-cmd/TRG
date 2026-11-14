# File: res://core_engine/npc_sweep.gd
# Class: class_name NpcSweep
# Role: 중립 기물 이동 규칙 - run: 한 번 쓸고 사라지는 질주(초증강 폭주 기관차). wander: 소환 기물(도적떼·팩맨)이 라운드가 끝날 때마다 정해진 방향으로 1~3칸 걷다가 적 말을 만나면 그 말 하나(업힌 말 포함)를 처치하고 사라진다. advance: 정해진 칸수만큼 전진하다 처음 만난 칸의 말을 모두 사출 (예전 규칙, 테스트용으로 남김)
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
	var route: Array[int] = [start_tile]
	for step: int in steps:
		var next: int = posmod(route[-1]+direction,BoardSpec.tile_count)
		if next==GameEnums.GOAL_TILE:
			break
		route.append(next)
	state.npc_sweep_started.emit(display_id,route.duplicate())
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": display_id, "path": [start_tile] as Array[int], "ejected": [] as Array[int], "destroyed": 0, "destroy_traps": destroy_traps}
	_eject_at(state, start_tile, by_player, result)
	var tile: int = start_tile
	for next: int in route.slice(1):
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


## 소환 기물이 진행 방향으로 가장 가까운 적 말(소환한 사람의 말이 아닌, 보드 위 대표 말)을 찾는다. 반환: {"tile", "pawn"} 또는 빈 Dictionary.
## 출발선(결승) 칸은 지나가기만 한다. 같은 칸에 적 말이 여럿이면 말 ID가 작은 쪽.
static func nearest_target(state: GameState, npc: NeutralNPC) -> Dictionary:
	var direction: int = npc.direction()
	var tile: int = npc.current_tile_idx
	for _distance: int in range(1, BoardSpec.tile_count):
		tile = posmod(tile + direction, BoardSpec.tile_count)
		var best: PlayerPawn = enemy_at(state, npc, tile)
		if best != null:
			return {"tile": tile, "pawn": best}
	return {}


## 황금장방형 팽이(SUM_04): 카드 ID. 라운드 끝마다 가장 가까운 적 말 쪽으로 한 칸씩 다가가, 말이 있는 칸에 부딪히면 그 칸의 모든 말을 날려 버리고 사라진다.
const TOP_ID: StringName = &"SUM_04"


## 팽이가 향할 방향: 지금 서 있는 칸을 뺀 보드 위 가장 가까운 적 말(소환한 사람의 말이 아닌 말) 쪽 (+1 정방향 / -1 역방향, 거리가 같으면 정방향). 적 말이 없으면 0.
static func top_direction(state: GameState, npc: NeutralNPC) -> int:
	var best_distance: int = 1 << 30
	var direction: int = 0
	for tile: int in range(1, BoardSpec.tile_count):
		if tile == npc.current_tile_idx or enemy_at(state, npc, tile) == null:
			continue
		var forward: int = posmod(tile - npc.current_tile_idx, BoardSpec.tile_count)
		var backward: int = BoardSpec.tile_count - forward
		var distance: int = mini(forward, backward)
		if distance < best_distance:
			best_distance = distance
			direction = 1 if forward <= backward else -1
	return direction


## 팽이의 라운드 끝 한 걸음. 반환: wander와 같은 모양 ({"npc_id","display_id","path","ejected","destroyed","vanished"}) + "direction".
## 도착한 칸에 (누구 것이든) 말이 있으면 그 칸의 말을 모두(업힌 말 포함) 출발선으로 날려 보내고 사라진다. 출발선(결승) 칸은 지나가기만 한다.
static func top_step(state: GameState, npc: NeutralNPC) -> Dictionary:
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": npc.display_id, "path": [npc.current_tile_idx] as Array[int], "ejected": [] as Array[int], "destroyed": 0, "vanished": false, "direction": 0}
	var direction: int = top_direction(state, npc)
	result["direction"] = direction
	if direction == 0:
		return result
	npc.behavior = GameEnums.NpcBehavior.PATROL_REVERSE if direction < 0 else GameEnums.NpcBehavior.CHASE_NEAREST
	var from_tile: int = npc.current_tile_idx
	var tile: int = posmod(from_tile + direction, BoardSpec.tile_count)
	npc.current_tile_idx = tile
	npc.push_step(tile)
	(result["path"] as Array[int]).append(tile)
	state.npc_stepped.emit(npc.entity_id, from_tile, tile)
	if tile == GameEnums.GOAL_TILE:
		return result
	var victims: Array[PlayerPawn] = catchable_at(state, tile)
	if victims.is_empty():
		return result
	for victim: PlayerPawn in victims:
		var members: Array[PlayerPawn] = victim.stack_members()
		state.send_to_start(victim, npc.owner_id)
		for member: PlayerPawn in members:
			if not member.has_left_start and not member.is_finished:  # 보호막이 막은 말은 빠진다
				(result["ejected"] as Array[int]).append(member.entity_id)
	result["vanished"] = true
	return result


## 롤링 양성자빔(SUM_03): 카드 ID, 라운드 끝마다 미끄러지는 칸 수(BEAM_MIN~BEAM_MAX), 수명(라운드).
const BEAM_ID: StringName = &"SUM_03"
const BEAM_MIN: int = 3
const BEAM_MAX: int = 5
const BEAM_ROUNDS: int = 3


## 양성자빔이 direction(+1/-1)으로 steps칸 미끄러지며 지나는 칸을 전부 태운다: 그 칸의 설치물(함정·건물 누구 것이든)을 없애고,
## 보드 위 말을 (소환한 사람의 말까지) 모두 출발선으로 보낸다. 잡아도 멈추거나 사라지지 않는다. 출발선(결승) 칸은 지나가기만 한다.
## 반환: {"path": [칸], "ejected": [말 ID], "destroyed": 없앤 설치물 수, "burned": [설치물이 사라진 칸]}
static func burn(state: GameState, npc: NeutralNPC, direction: int, steps: int) -> Dictionary:
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": npc.display_id, "path": [npc.current_tile_idx] as Array[int], "ejected": [] as Array[int], "destroyed": 0, "burned": [] as Array[int], "vanished": false}
	# 화면이 태우기 전 모습(말·함정 자리)을 붙잡아 두도록 지나갈 길을 먼저 알린다 (폭주 기관차와 같은 신호).
	var route: Array[int] = [npc.current_tile_idx]
	for _i: int in steps:
		route.append(posmod(route[-1] + direction, BoardSpec.tile_count))
	state.npc_sweep_started.emit(npc.display_id, route)
	for _i: int in steps:
		var from_tile: int = npc.current_tile_idx
		var tile: int = posmod(from_tile + direction, BoardSpec.tile_count)
		npc.current_tile_idx = tile
		npc.push_step(tile)
		(result["path"] as Array[int]).append(tile)
		state.npc_stepped.emit(npc.entity_id, from_tile, tile)
		if tile == GameEnums.GOAL_TILE:
			continue
		var node: TileNode = state.board.get_tile(tile)
		if not node.attachments.is_empty():
			result["destroyed"] = int(result["destroyed"]) + node.attachments.size()
			(result["burned"] as Array[int]).append(tile)
			node.clear_attachments()
		for victim: PlayerPawn in catchable_at(state, tile):
			var members:Array[PlayerPawn]=victim.stack_members()
			state.send_to_start(victim,npc.owner_id)
			# Shields and amnesia can keep a target alive; report only real ejections.
			for member:PlayerPawn in members:
				if not member.has_left_start and not member.is_finished:
					(result["ejected"] as Array[int]).append(member.entity_id)
	return result


## 소환 기물이 라운드 끝마다 움직이는 칸 수 (WANDER_MIN~WANDER_MAX 중 무작위).
const WANDER_MIN: int = 1
const WANDER_MAX: int = 3


## 라운드 끝: 진행 방향으로 steps칸(1~3칸 무작위) 한 칸씩 걷는다. 지나는 칸에서 (지금 서 있는 칸은 보지 않는다) 적 말(소환한 사람의 말이 아닌 보드 위 대표 말)을
## 처음 만나면 그 말 하나(업힌 말 포함)를 출발선으로 보내고 그 자리에서 사라진다. 아무도 못 만나면 보드에 남아 다음 라운드에 또 걷는다.
## 출발선(결승) 칸은 지나가기만 한다. 반환: {"npc_id", "display_id", "path": [칸], "ejected": [말 ID], "vanished": bool}
static func wander(state: GameState, npc: NeutralNPC, steps: int) -> Dictionary:
	var result: Dictionary = {"npc_id": npc.entity_id, "display_id": npc.display_id, "path": [npc.current_tile_idx] as Array[int], "ejected": [] as Array[int], "destroyed": 0, "vanished": false}
	var direction: int = npc.direction()
	for _i: int in steps:
		var from_tile: int = npc.current_tile_idx
		var tile: int = posmod(from_tile + direction, BoardSpec.tile_count)
		npc.current_tile_idx = tile
		npc.push_step(tile)
		(result["path"] as Array[int]).append(tile)
		state.npc_stepped.emit(npc.entity_id, from_tile, tile)
		if _catch_enemy(state, npc, result):
			break
	return result


## 그 칸에서 기물이 덮칠 적 말 (같은 칸에 여럿이면 말 ID가 작은 쪽). 없으면 null.
static func enemy_at(state: GameState, npc: NeutralNPC, tile: int) -> PlayerPawn:
	var best: PlayerPawn = null
	for victim: PlayerPawn in catchable_at(state, tile):
		if victim.owner_id == npc.owner_id:
			continue
		if best == null or victim.entity_id < best.entity_id:
			best = victim
	return best


static func _catch_enemy(state: GameState, npc: NeutralNPC, result: Dictionary) -> bool:
	var victim: PlayerPawn = enemy_at(state, npc, npc.current_tile_idx)
	if victim == null:
		return false
	for member: PlayerPawn in victim.stack_members():
		(result["ejected"] as Array[int]).append(member.entity_id)
	state.send_to_start(victim, npc.owner_id)
	result["vanished"] = true
	return true


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
