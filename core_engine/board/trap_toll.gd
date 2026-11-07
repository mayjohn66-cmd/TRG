# File: res://core_engine/board/trap_toll.gd
# Class: class_name TrapToll
# Role: TRP_C03 톨게이트 (코너 전용) - 지나가거나 멈추는 상대 말은 설치자에게 카드 1장을 바쳐야 하고, 낼 카드가 없으면 그 칸에 강제로 멈춘다. 설치자의 턴 3번(3라운드) 동안 유지, 한 번 발동하면 사라진다
class_name TrapToll
extends TileAttachment

const LIFETIME_TURNS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_C03"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = CardRegistry.param(&"TRP_C03", LIFETIME_TURNS)


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null or pawn.owner_id == owner_id:
		return false
	var state: GameState = ctx.state
	duration_turns = 0
	var tribute: StringName = state.steal_random_card(pawn.owner_id, state.rng)
	if tribute != &"":
		if not state.give_card(owner_id, tribute):
			state.card_deck.push_front(tribute)  # 설치자의 손패가 가득 차면 덱 밑으로
		state.attachment_triggered.emit(state.board.tile_of_attachment(self), attachment_id, pawn.entity_id, &"toll_paid")
		return false
	ctx.metadata["cutscene_id"] = &"toll_blocked"
	return not bool(ctx.metadata.get("is_landing", false))
