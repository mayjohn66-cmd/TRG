# File: res://core_engine/entities/neutral_npc.gd
# Class: class_name NeutralNPC
# Role: 중립 소환수(사료스탕스·와구와구 유령). 소환된 자리에서 라운드가 끝날 때마다 정해진 방향(정방향/역방향)으로 1~3칸 걷다가 적 말을 만나면 그 말 하나를 처치하고 사라진다 (NpcSweep.wander)
class_name NeutralNPC
extends BoardEntity

var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST
var display_id: StringName = &"SUM_01"
## 롤링 양성자빔(SUM_03)처럼 수명이 있는 기물: 남은 이동 라운드 수 (0이면 수명 없음 - 잡으면 사라지는 사료스탕스·와구와구 유령).
var rounds_left: int = 0


## 라운드 종료 NPC 페이즈에서 호출된다. 정해진 방향(도적떼 정방향, 팩맨 역방향)으로 1~3칸(state.rng) 걷다가 적 말을 만나면 그 말 하나를 처치하고 사라진다.
## 아무도 못 만나면 보드에 남는다 (vanished=false). steps를 주면 그 칸 수만큼 걷는다 (테스트용).
## 반환: {"npc_id", "from": 출발 칸, "path": 지난 칸들, "caught": [말 ID], "stolen_cards": [], "vanished": bool, "behavior"}
func run_ai(state: GameState, steps: int = 0) -> Dictionary:
	if is_beam():
		return _run_beam(state, steps)
	if steps <= 0:
		steps = state.rng.randi_range(NpcSweep.WANDER_MIN, NpcSweep.WANDER_MAX)
	var run: Dictionary = NpcSweep.wander(state, self, steps)
	var path: Array[int] = []
	path.assign((run["path"] as Array).slice(1))
	return {"npc_id": entity_id, "from": int((run["path"] as Array)[0]), "path": path, "caught": run["ejected"], "stolen_cards": [] as Array[StringName], "vanished": run["vanished"], "behavior": behavior}


## 롤링 양성자빔(SUM_03)인가: 라운드마다 무작위 방향으로 3~5칸 스르륵 미끄러지며 지나는 칸의 말·설치물을 전부 태운다. 잡아도 사라지지 않고 3라운드 뒤 스스로 소멸.
func is_beam() -> bool:
	return display_id == NpcSweep.BEAM_ID


## 양성자빔의 라운드 끝 이동: 방향(state.rng)을 먼저 정하고, 칸 수(state.rng 3~5)만큼 태우며 미끄러진다. 남은 수명을 하나 줄여 0이 되면 사라진다(vanished).
func _run_beam(state: GameState, steps: int) -> Dictionary:
	var dir: int = -1 if state.rng.randi_range(0, 1) == 0 else 1
	if steps <= 0:
		steps = state.rng.randi_range(NpcSweep.BEAM_MIN, NpcSweep.BEAM_MAX)
	behavior = GameEnums.NpcBehavior.PATROL_REVERSE if dir < 0 else GameEnums.NpcBehavior.CHASE_NEAREST
	var run: Dictionary = NpcSweep.burn(state, self, dir, steps)
	rounds_left = maxi(rounds_left - 1, 0)
	var path: Array[int] = []
	path.assign((run["path"] as Array).slice(1))
	return {"npc_id": entity_id, "from": int((run["path"] as Array)[0]), "path": path, "caught": run["ejected"], "stolen_cards": [] as Array[StringName],
		"vanished": rounds_left <= 0, "behavior": behavior, "direction": dir, "destroyed": run["destroyed"], "burned": run["burned"], "rounds_left": rounds_left}


func direction() -> int:
	return -1 if behavior == GameEnums.NpcBehavior.PATROL_REVERSE else 1


## 이 NPC가 이번 라운드 끝에 어디를 덮칠 수 있는지 미리 본다 (화면의 위험 예고용). 난수를 쓰지 않고 게임 상태도 바꾸지 않는다.
## 걸음 수가 1~3칸 무작위라 최대 3칸 앞까지(그 사이 처음 만나는 적 칸에서 멈춘다)를 예고한다.
## 반환: {"tiles": 걸을 수 있는 타일 순서(Array[int]), "catch_tiles": 덮칠 수 있는 적 칸(Array[int], 0~1개), "chance": 그 적이 잡힐 확률(0~1), "direction": +1(정방향) 또는 -1(역방향)}
func danger_preview(state: GameState) -> Dictionary:
	if is_beam():
		return _beam_preview(state)
	var preview: Dictionary = {"tiles": [] as Array[int], "catch_tiles": [] as Array[int], "chance": 0.0, "direction": direction()}
	var tiles: Array[int] = []
	var tile: int = current_tile_idx
	var reach: int = NpcSweep.WANDER_MAX - NpcSweep.WANDER_MIN + 1
	for distance: int in range(1, NpcSweep.WANDER_MAX + 1):
		tile = posmod(tile + direction(), BoardSpec.tile_count)
		tiles.append(tile)
		if NpcSweep.enemy_at(state, self, tile) != null:
			preview["catch_tiles"] = [tile] as Array[int]
			preview["chance"] = float(NpcSweep.WANDER_MAX - maxi(distance, NpcSweep.WANDER_MIN) + 1) / float(reach)
			break
	preview["tiles"] = tiles
	return preview


## 양성자빔 예고: 방향을 모르니 양쪽으로 최대 BEAM_MAX칸을 위험 칸으로 보인다. 말이 있는 칸은 잡힐 수 있는 칸(catch_tiles).
## 확률: 그 방향(1/2) × 그 거리까지 닿을 확률(3~5칸 중).
func _beam_preview(state: GameState) -> Dictionary:
	var preview: Dictionary = {"tiles": [] as Array[int], "catch_tiles": [] as Array[int], "chance": 0.0, "direction": 0}
	var tiles: Array[int] = []
	var catches: Array[int] = []
	var best: float = 0.0
	var reach: int = NpcSweep.BEAM_MAX - NpcSweep.BEAM_MIN + 1
	for dir: int in [1, -1]:
		var tile: int = current_tile_idx
		for distance: int in range(1, NpcSweep.BEAM_MAX + 1):
			tile = posmod(tile + dir, BoardSpec.tile_count)
			if tile == GameEnums.GOAL_TILE:
				continue
			tiles.append(tile)
			if not NpcSweep.catchable_at(state, tile).is_empty():
				catches.append(tile)
				best = maxf(best, 0.5 * float(NpcSweep.BEAM_MAX - maxi(distance, NpcSweep.BEAM_MIN) + 1) / float(reach))
	preview["tiles"] = tiles
	preview["catch_tiles"] = catches
	preview["chance"] = best
	return preview
