# File: res://core_engine/commands/draw_cards_command.gd
# Class: class_name DrawCardsCommand
# Role: 후속 효과 - 지정한 플레이어가 덱에서 생떼 카드를 N장 뽑는다 (연대보증·지뢰찾기 공병 등)
class_name DrawCardsCommand
extends GameCommand

var count: int = 1


func _init(player_id: int = -1, amount: int = 1) -> void:
	super()
	sender_id = player_id
	count = amount
	command_name = "DrawCards"


func _run() -> void:
	for i: int in count:
		state.draw_card(sender_id)
