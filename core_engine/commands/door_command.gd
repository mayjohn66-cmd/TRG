# File: res://core_engine/commands/door_command.gd
# Class: class_name DoorCommand
# Role: ACT_13 슈팡 특급 배송 - 내 선두 말(보드에 없으면 대기 말 하나)을 반환점까지의 빈 칸 중 고른 칸으로 순간이동시킨다 (결승선 바로 앞으로는 못 간다). 도착 칸의 빵집·설치물·잡기는 평소처럼 판정한다
class_name DoorCommand
extends GameCommand

var tile: int = -1
## 실행 뒤 UI가 읽는다: 순간이동한 말 ID.
var moved_pawn_id: int = -1


func _init(acting_player: int = -1, destination: int = -1) -> void:
	super()
	sender_id = acting_player
	tile = destination
	command_name = "Door"


## 문을 열 말: 보드 위 선두 말, 없으면 출발선에서 기다리는 말.
static func traveler(game: GameState, player_id: int) -> PlayerPawn:
	var front: PlayerPawn = game.front_pawn_of(player_id)
	if front != null:
		return front
	for pawn: PlayerPawn in game.pawns_of(player_id):
		if pawn.is_selectable() and not pawn.has_left_start:
			return pawn
	return null


## 빈 칸: 출발선이 아니고, 말도 설치물도 없는 칸.
static func is_empty_tile(game: GameState, index: int) -> bool:
	if not game.board.is_valid_tile(index) or index == GameEnums.GOAL_TILE:
		return false
	return game.leaders_at(index).is_empty() and game.board.get_tile(index).attachments.is_empty()


## 배송할 수 있는 칸: 1번부터 반환점(BoardSpec.halfway_tile)까지의 빈 칸.
static func is_target_tile(game: GameState, index: int) -> bool:
	return index >= 1 and index <= BoardSpec.halfway_tile and is_empty_tile(game, index)


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and traveler(state, sender_id) != null and is_target_tile(state, tile)


func _run() -> void:
	var pawn: PlayerPawn = traveler(state, sender_id)
	moved_pawn_id = pawn.entity_id
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = sender_id
	ctx.pawn = pawn
	pawn.has_left_start = true
	pawn.revenge_boost = false
	MoveExecutor.teleport_to(state, pawn, ctx, MoveReport.new(), tile)
