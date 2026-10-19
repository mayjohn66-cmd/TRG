# File: res://core_engine/board/trap_island.gd
# Class: class_name TrapIsland
# Role: TRP_04 부르마블 무인도 감옥 - 코너 타일을 무인도로 바꾼다. 상대 말이 도착하면 짝수 눈금이 나올 때까지 갇힌다 (설치자 기준 3턴간 유지)
class_name TrapIsland
extends TileAttachment

const LIFETIME_TURNS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_04"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = CardRegistry.param(&"TRP_04", LIFETIME_TURNS)  # cards_table.csv TRP_04 param_1


## 도착(이동의 마지막 칸)한 상대 말만 가둔다. 이미 도착했으므로 이동을 끊지는 않는다(false 반환).
func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id or not bool(ctx.metadata.get("is_landing", false)):
		return false
	if pawn.is_imprisoned or ctx.state == null:
		return false
	pawn.is_imprisoned = true
	var tile_index: int = ctx.state.board.tile_of_attachment(self)
	ctx.state.attachment_triggered.emit(tile_index, attachment_id, pawn.entity_id, &"island_prison")
	return false
