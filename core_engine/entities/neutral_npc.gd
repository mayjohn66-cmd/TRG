# File: res://core_engine/entities/neutral_npc.gd
# Class: class_name NeutralNPC
# Role: 중립 소환수(사료스탕스·와구와구 유령). 소환된 자리에 가만히 있다가 라운드가 끝날 때 정해진 방향(정방향/역방향)으로 가장 가까운 적 말까지 달려가 그 말 하나를 처치하고 사라진다 (NpcSweep.strike)
class_name NeutralNPC
extends BoardEntity

var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST
var display_id: StringName = &"SUM_01"


## 라운드 종료 NPC 페이즈에서 호출된다. 정해진 방향(도적떼 정방향, 팩맨 역방향)으로 가장 가까운 적 말까지 달려가 그 말 하나를 처치하고 사라진다 (적이 없으면 그냥 사라진다).
## 반환: {"npc_id", "from": 출발 칸, "path": 지난 칸들, "caught": [말 ID], "stolen_cards": [], "vanished": true, "behavior"}
func run_ai(state: GameState) -> Dictionary:
	var run: Dictionary = NpcSweep.strike(state, self)
	var path: Array[int] = []
	path.assign((run["path"] as Array).slice(1))
	return {"npc_id": entity_id, "from": int((run["path"] as Array)[0]), "path": path, "caught": run["ejected"], "stolen_cards": [] as Array[StringName], "vanished": run["vanished"], "behavior": behavior}


func direction() -> int:
	return -1 if behavior == GameEnums.NpcBehavior.PATROL_REVERSE else 1


## 이 NPC가 이번 라운드 끝에 어디를 덮칠지 미리 본다 (화면의 위험 예고용). 난수를 쓰지 않고 게임 상태도 바꾸지 않는다.
## 반환: {"tiles": 달려갈 타일 순서(Array[int]), "catch_tiles": 처치할 적이 선 타일(Array[int], 0~1개), "chance": 1.0(적이 있으면) 또는 0.0, "direction": +1(정방향) 또는 -1(역방향)}
func danger_preview(state: GameState) -> Dictionary:
	var preview: Dictionary = {"tiles": [] as Array[int], "catch_tiles": [] as Array[int], "chance": 0.0, "direction": direction()}
	var target: Dictionary = NpcSweep.nearest_target(state, self)
	if target.is_empty():
		return preview
	var goal: int = int(target["tile"])
	var tiles: Array[int] = []
	var tile: int = current_tile_idx
	while tile != goal:
		tile = posmod(tile + direction(), BoardSpec.tile_count)
		tiles.append(tile)
	preview["tiles"] = tiles
	preview["catch_tiles"] = [goal] as Array[int]
	preview["chance"] = 1.0
	return preview
