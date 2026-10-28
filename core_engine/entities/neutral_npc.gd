# File: res://core_engine/entities/neutral_npc.gd
# Class: class_name NeutralNPC
# Role: 중립 소환수(사료스탕스·와구와구 유령). 소환된 자리에서 라운드가 끝날 때마다 정해진 방향(정방향/역방향)으로 1~3칸 걷다가 적 말을 만나면 그 말 하나를 처치하고 사라진다 (NpcSweep.wander)
class_name NeutralNPC
extends BoardEntity

var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST
var display_id: StringName = &"SUM_01"


## 라운드 종료 NPC 페이즈에서 호출된다. 정해진 방향(도적떼 정방향, 팩맨 역방향)으로 1~3칸(state.rng) 걷다가 적 말을 만나면 그 말 하나를 처치하고 사라진다.
## 아무도 못 만나면 보드에 남는다 (vanished=false). steps를 주면 그 칸 수만큼 걷는다 (테스트용).
## 반환: {"npc_id", "from": 출발 칸, "path": 지난 칸들, "caught": [말 ID], "stolen_cards": [], "vanished": bool, "behavior"}
func run_ai(state: GameState, steps: int = 0) -> Dictionary:
	if steps <= 0:
		steps = state.rng.randi_range(NpcSweep.WANDER_MIN, NpcSweep.WANDER_MAX)
	var run: Dictionary = NpcSweep.wander(state, self, steps)
	var path: Array[int] = []
	path.assign((run["path"] as Array).slice(1))
	return {"npc_id": entity_id, "from": int((run["path"] as Array)[0]), "path": path, "caught": run["ejected"], "stolen_cards": [] as Array[StringName], "vanished": run["vanished"], "behavior": behavior}


func direction() -> int:
	return -1 if behavior == GameEnums.NpcBehavior.PATROL_REVERSE else 1


## 이 NPC가 이번 라운드 끝에 어디를 덮칠 수 있는지 미리 본다 (화면의 위험 예고용). 난수를 쓰지 않고 게임 상태도 바꾸지 않는다.
## 걸음 수가 1~3칸 무작위라 최대 3칸 앞까지(그 사이 처음 만나는 적 칸에서 멈춘다)를 예고한다.
## 반환: {"tiles": 걸을 수 있는 타일 순서(Array[int]), "catch_tiles": 덮칠 수 있는 적 칸(Array[int], 0~1개), "chance": 그 적이 잡힐 확률(0~1), "direction": +1(정방향) 또는 -1(역방향)}
func danger_preview(state: GameState) -> Dictionary:
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
