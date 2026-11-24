# File: res://core_engine/board/trap_ifrit.gd
# Class: class_name TrapIfrit
# Role: TRP_C05 이프리트의 분노 (코너 전용) - 코너에 불꽃을 깐다. 상대 말이 지나가거나 멈출 때마다 그 말 주인의 손패 1장을 태운다 (말은 멈추지 않는다).
#       공개 함정이고 설치자의 턴 3번(3라운드) 동안 남는다. 여러 번 발동한다 (태울 카드가 없으면 아무 일도 없다).
class_name TrapIfrit
extends TileAttachment

const LIFETIME_TURNS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_C05"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = CardRegistry.param(&"TRP_C05", LIFETIME_TURNS)


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null or pawn.owner_id == owner_id:
		return false
	var state: GameState = ctx.state
	var burned: StringName = state.discard_random_card(pawn.owner_id, state.rng)
	if burned != &"":
		state.card_deck.push_front(burned)  # 태운 카드는 덱 맨 밑으로 돌아간다 (덱이 마르지 않게)
		state.card_burned.emit(pawn.owner_id, burned, state.board.tile_of_attachment(self))
	return false  # 불꽃은 길을 막지 않는다
