# File: res://core_engine/commands/bang_command.gd
# Class: class_name BangCommand
# Role: ACT_02 뱅! 실행 - 내 말 앞뒤 3칸 안의 가장 앞선 상대 말을 자동 조준한다. 상대가 손패를 한 장 버리면 회피(빗나감), 손패가 없으면 출발선으로 보낸다
class_name BangCommand
extends GameCommand

const RANGE: int = 3

var target_pawn_id: int = -1
var dodged: bool = false
var discarded_card: StringName = &""


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "Bang"


## 사정거리 안에서 결승에 가장 가까운(가장 앞선) 상대 대표 말. 동률이면 ID가 낮은 말. 없으면 null.
## 출발선(0번)에 대기 중이거나 완주한 말은 맞힐 수 없다.
static func find_target(game_state: GameState, shooter_id: int) -> PlayerPawn:
	var in_range: Dictionary = {}
	for mine: PlayerPawn in game_state.pawns_of(shooter_id):
		if mine.is_finished or not mine.has_left_start or mine.carrier != null:
			continue
		for tile: int in game_state.board.tiles_within(mine.current_tile_idx, RANGE):
			in_range[tile] = true
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in game_state.pawns:
		if pawn.owner_id == shooter_id or pawn.is_finished or pawn.carrier != null or not pawn.has_left_start:
			continue
		if pawn.current_tile_idx == GameEnums.GOAL_TILE or not in_range.has(pawn.current_tile_idx):
			continue
		var distance: int = game_state.pawn_progress_distance(pawn)
		if distance < best_distance or (distance == best_distance and pawn.entity_id < best.entity_id):
			best_distance = distance
			best = pawn
	return best


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and find_target(state, sender_id) != null


func _run() -> void:
	var target: PlayerPawn = find_target(state, sender_id)
	if target == null:
		return
	target_pawn_id = target.entity_id
	discarded_card = state.discard_random_card(target.owner_id, state.rng)
	dodged = discarded_card != &""
	if not dodged:
		state.send_to_start(target, sender_id)
	state.bang_resolved.emit(sender_id, target_pawn_id, dodged, discarded_card)
