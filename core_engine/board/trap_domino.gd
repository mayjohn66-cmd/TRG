# File: res://core_engine/board/trap_domino.gd
# Class: class_name TrapDomino
# Role: TRP_05 도미노 연쇄 붕괴 - 어떤 말이든 밟거나 멈추면 그 말이 뒤로 3칸 밀려나고, 밀려난 경로(뒤쪽 1~3칸)에 서 있던 다른 말들도 도미노처럼 2칸씩 뒤로 밀려나는 은신 함정 (1회용)
class_name TrapDomino
extends TileAttachment

const PUSH_BACK: int = 3
const CHAIN_PUSH: int = 2


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_05"
	owner_id = owner


## 설치한 사람의 말도 무너지는 도미노는 피하지 못한다 (어떤 말이든). 발동하면 설치물은 소모된다.
func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null:
		return false
	var state: GameState = ctx.state
	ctx.metadata["cutscene_id"] = &"trap_domino"
	var passed: Array[int] = MoveExecutor.retreat(state, pawn, PUSH_BACK)
	var chain: Array[int] = []
	for other: PlayerPawn in state.pawns:
		if other == pawn or other.is_finished or other.carrier != null or not other.has_left_start or pawn.carried.has(other):
			continue
		if other.current_tile_idx != GameEnums.GOAL_TILE and passed.has(other.current_tile_idx):
			chain.append(other.entity_id)
	for other_id: int in chain:
		MoveExecutor.retreat(state, state.get_pawn(other_id), CHAIN_PUSH)
	ctx.metadata["domino_chain"] = chain
	state.domino_collapsed.emit(pawn.entity_id, passed, chain)
	duration_turns = 0
	return true
