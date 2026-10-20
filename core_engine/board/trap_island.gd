# File: res://core_engine/board/trap_island.gd
# Class: class_name TrapIsland
# Role: TRP_C01 무인도 감옥 (코너 전용) - 코너에 멈춘 상대 말을 가둔다. 짝수 눈금이 나오거나 카드 1장을 내면 탈출한다. 설치자의 턴 3번 동안 유지
class_name TrapIsland
extends TileAttachment

const LIFETIME_TURNS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_C01"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = CardRegistry.param(&"TRP_C01", LIFETIME_TURNS)  # cards_table.csv TRP_C01 param_1


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
