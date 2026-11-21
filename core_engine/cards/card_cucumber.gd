# File: res://core_engine/cards/card_cucumber.gd
# Class: class_name CardCucumber
# Role: JNK_CUKE 오이 카드 - 먹을 수 있지만 게임 효과는 없는 카드. 먹는 연출은 UI가 맡는다.
class_name CardCucumber
extends BaseCard


func _init() -> void:
	card_id = &"JNK_CUKE"
	display_name = "오이 카드"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return EatCucumber.new(player_id)


## The normal card pipeline consumes one card and enforces timing/turn limits.
## This command intentionally changes no board, stats, cards, buffs or RNG.
class EatCucumber extends GameCommand:
	func _init(player_id: int) -> void:
		super()
		sender_id = player_id
		command_name = "EatCucumber"

	func _run() -> void:
		pass
