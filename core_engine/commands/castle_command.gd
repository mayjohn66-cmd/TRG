# File: res://core_engine/commands/castle_command.gd
# Class: class_name CastleCommand
# Role: 체스 2세트 [캐슬링] 실행 - 내 체스 기물 두 개(업은 말 포함)의 타일 위치를 맞바꾼다. 턴 시작 시 1회, 스냅샷으로 undo 가능
class_name CastleCommand
extends GameCommand

var pawn_a_id: int = -1
var pawn_b_id: int = -1


func _init(acting_player: int = -1, first_pawn_id: int = -1, second_pawn_id: int = -1) -> void:
	super()
	sender_id = acting_player
	pawn_a_id = first_pawn_id
	pawn_b_id = second_pawn_id
	command_name = "Castle"


## 캐슬링에 쓸 수 있는 내 체스 기물: 출발했고 완주하지 않았으며 업혀 있지 않은 말.
static func candidates(game_state: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in game_state.pawns_of(player_id):
		if pawn.kind == GameEnums.PawnKind.CHESS and pawn.has_left_start and not pawn.is_finished and pawn.carrier == null:
			result.append(pawn)
	return result


## 서로 다른 타일에 있는 후보 쌍들을 [a, b] 형태로 나열한다.
static func valid_pairs(game_state: GameState, player_id: int) -> Array[Array]:
	var pairs: Array[Array] = []
	var list: Array[PlayerPawn] = candidates(game_state, player_id)
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			if list[i].current_tile_idx != list[j].current_tile_idx:
				pairs.append([list[i], list[j]])
	return pairs


func can_execute(_ctx: RuleContext) -> bool:
	if state == null or pawn_a_id == pawn_b_id:
		return false
	var a: PlayerPawn = state.get_pawn(pawn_a_id)
	var b: PlayerPawn = state.get_pawn(pawn_b_id)
	if a == null or b == null or a.owner_id != sender_id or b.owner_id != sender_id:
		return false
	var list: Array[PlayerPawn] = candidates(state, sender_id)
	return list.has(a) and list.has(b) and a.current_tile_idx != b.current_tile_idx


func _run() -> void:
	state.swap_stacks(state.get_pawn(pawn_a_id), state.get_pawn(pawn_b_id))
	state.pawns_castled.emit(pawn_a_id, pawn_b_id)
