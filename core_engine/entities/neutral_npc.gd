# File: res://core_engine/entities/neutral_npc.gd
# Class: class_name NeutralNPC
# Role: 중립 소환수(카탄의 도적떼·팩맨). 보드에 남아 라운드 종료마다 정해진 방향으로 3~6칸 전진하며, 말을 처음 만난 칸의 말을 모두 사출하고 소멸한다(report.vanished)
class_name NeutralNPC
extends BoardEntity

var behavior: GameEnums.NpcBehavior = GameEnums.NpcBehavior.CHASE_NEAREST
var display_id: StringName = &"SUM_01"


const MIN_STEPS: int = 3
const MAX_STEPS: int = 6


## 라운드 종료 NPC 페이즈에서 호출된다. 정해진 방향(도적떼 정방향, 팩맨 역방향)으로 3~6칸 전진하고, 말을 처음 만난 칸에서 그 칸의 말을 모두 사출한 뒤 사라진다.
## 반환: {"npc_id", "path", "caught": [말 ID], "stolen_cards": [], "vanished"}
func run_ai(state: GameState) -> Dictionary:
	var run: Dictionary = NpcSweep.advance(state, self, state.rng.randi_range(MIN_STEPS, MAX_STEPS))
	var path: Array[int] = []
	path.assign((run["path"] as Array).slice(1))
	return {"npc_id": entity_id, "path": path, "caught": run["ejected"], "stolen_cards": [] as Array[StringName], "vanished": run["vanished"]}


func direction() -> int:
	return -1 if behavior == GameEnums.NpcBehavior.PATROL_REVERSE else 1


## 이 NPC가 이번 라운드 끝에 어디를 덮칠지 미리 본다 (화면의 위험 예고용). 난수를 쓰지 않고 게임 상태도 바꾸지 않는다.
## 반환: {"tiles": 지나갈 수 있는 타일 순서(Array[int]), "catch_tiles": 말이 서 있으면 잡히는 타일(Array[int]), "chance": 지금 말이 서 있는 첫 칸에서 잡힐 확률(0~1), "direction": +1(정방향) 또는 -1(역방향)}
## 3~6칸 중 하나를 고르게 전진하므로 3칸 안은 반드시 닿고, 4·5·6칸째는 3/4·2/4·1/4 확률로 닿는다. 말을 만난 첫 칸에서 멈춘다.
func danger_preview(state: GameState) -> Dictionary:
	var preview: Dictionary = {"tiles": [] as Array[int], "catch_tiles": [] as Array[int], "chance": 0.0, "direction": direction()}
	var tiles: Array[int] = []
	var danger: Array[int] = []
	var tile: int = current_tile_idx
	for distance: int in range(1, MAX_STEPS + 1):
		tile = posmod(tile + direction(), BoardSpec.tile_count)
		tiles.append(tile)
		if tile == GameEnums.GOAL_TILE:
			continue
		danger.append(tile)
		if not NpcSweep.catchable_at(state, tile).is_empty():
			preview["chance"] = 1.0 if distance <= MIN_STEPS else float(MAX_STEPS + 1 - distance) / float(MAX_STEPS - MIN_STEPS + 1)
			break  # 그 칸에서 멈추므로 더 뒤는 안전
	preview["tiles"] = tiles
	preview["catch_tiles"] = danger
	return preview
