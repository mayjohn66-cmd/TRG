# File: res://core_engine/board/trap_transfer.gd
# Class: class_name TrapTransfer
# Role: TRP_08 강제 환승 포탈 - 밟은 상대 말이 보드 위 꼴찌 말(자기 말 제외, 출발 전 말 제외)과 자리를 맞바꾼다
class_name TrapTransfer
extends TileAttachment


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_08"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null or pawn.owner_id == owner_id:
		return false
	var last: PlayerPawn = _last_on_board(ctx.state, pawn)
	if last == null:
		return false
	ctx.metadata["cutscene_id"] = &"trap_transfer"
	ctx.state.swap_stacks(pawn, last)
	duration_turns = 0
	return true


## 보드 위(출발한) 말 중 결승에서 가장 먼 대표 말 (밟은 말의 주인 것과 같은 칸의 말은 뺀다).
static func _last_on_board(state: GameState, victim: PlayerPawn) -> PlayerPawn:
	var last: PlayerPawn = null
	var last_distance: int = -1
	for other: PlayerPawn in state.pawns:
		if other.owner_id == victim.owner_id or other.is_finished or other.carrier != null or not other.has_left_start:
			continue
		if other.current_tile_idx == victim.current_tile_idx or other.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		var distance: int = state.pawn_progress_distance(other)
		if distance > last_distance:
			last_distance = distance
			last = other
	return last

