# File: res://core_engine/commands/cover_command.gd
# Class: class_name CoverCommand
# Role: ACT_22 긴급 엄폐 - 내 말 하나에 택배 박스를 뒤집어씌워 [지정 보호막(ward)]을 준다: 잡기·함정 사출을 1회 막고 사라진다. 이미 보호막이 있는 말에는 쓸 수 없다
class_name CoverCommand
extends GameCommand

var pawn_id: int = -1


func _init(acting_player: int = -1, target_pawn: int = -1) -> void:
	super()
	sender_id = acting_player
	pawn_id = target_pawn
	command_name = "Cover"


## 박스를 씌울 수 있는 내 말: 보드 위에 나와 있고(출발선 대기·완주 제외) 업혀 있지 않으며 보호막이 아직 없는 말.
static func targets(game: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in game.pawns_of(player_id):
		if pawn.has_left_start and not pawn.is_finished and pawn.carrier == null and not pawn.ward:
			result.append(pawn)
	return result


func can_execute(_ctx: RuleContext) -> bool:
	if state == null:
		return false
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return pawn != null and targets(state, sender_id).has(pawn)


func _run() -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	pawn.ward = true
	pawn.ward_box = true
	state.cover_applied.emit(pawn_id)
