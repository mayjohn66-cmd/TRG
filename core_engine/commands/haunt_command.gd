# File: res://core_engine/commands/haunt_command.gd
# Class: class_name HauntCommand
# Role: 방해령 삼총사 (v1.1) - ACT_18 방해령 베루(적 말 1개 뒤로 1칸) / ACT_19 방해령 사리(내 말 1개 앞으로 1칸) / ACT_20 방해령 메죵(적의 다음 눈금 -1).
#       하나씩은 미미하지만 셋을 손패에 모으면 특수 승리 [방해령 허리케인 포스!!](LAW_09)의 재료가 된다. 공격 카드가 아니라서 방어 카드로 막지 못한다.
class_name HauntCommand
extends GameCommand

const BERU: StringName = &"ACT_18"
const SARI: StringName = &"ACT_19"
const MEJONG: StringName = &"ACT_20"
const IDS: Array[StringName] = [BERU, SARI, MEJONG]
## 메죵이 한 번에 깎는 눈금.
const ROLL_PENALTY: int = 1

var card_id: StringName = &""
var pawn_id: int = -1
var target_player: int = -1
## 실행 뒤 UI가 읽는다: 옮겨진 말 ID / 옮겨 간 칸.
var moved_pawn_id: int = -1
var moved_to: int = -1


func _init(acting_player: int = -1, id: StringName = &"", pawn: int = -1, target: int = -1) -> void:
	super()
	sender_id = acting_player
	card_id = id
	pawn_id = pawn
	target_player = target
	command_name = "Haunt"


static func is_haunt(id: StringName) -> bool:
	return IDS.has(id)


## 손패에 모인 방해령 종류 수 (0~3, 같은 종류 여러 장은 1종). 법전 진행도 표기가 이 값을 쓴다.
static func held_kinds(game: GameState, player_id: int) -> int:
	var hand: Array = game.hands.get(player_id, [])
	var kinds: int = 0
	for id: StringName in IDS:
		if hand.has(id):
			kinds += 1
	return kinds


## 손패에 없는 방해령 종류.
static func missing_kinds(game: GameState, player_id: int) -> Array[StringName]:
	var hand: Array = game.hands.get(player_id, [])
	var result: Array[StringName] = []
	for id: StringName in IDS:
		if not hand.has(id):
			result.append(id)
	return result


## 말을 direction(-1 뒤 / +1 앞)으로 1칸 옮길 수 있는가: 트랙 위(출발선·결승 제외)에 서 있는 맨 위 말이고, 도착 칸이 트랙 위의 빈 칸일 때.
static func can_shift(game: GameState, pawn: PlayerPawn, direction: int) -> bool:
	if pawn == null or pawn.is_finished or not pawn.has_left_start or pawn.carrier != null:
		return false
	if pawn.current_tile_idx == GameEnums.GOAL_TILE:
		return false
	var dest: int = pawn.current_tile_idx + direction
	if dest < 1 or dest > BoardSpec.tile_count - 1:
		return false
	return game.leaders_at(dest).is_empty()


## 베루로 뒤로 밀 수 있는 적 말들.
static func shove_targets(game: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in game.pawns:
		if pawn.owner_id != player_id and not game.is_graduated(pawn.owner_id) and can_shift(game, pawn, -1):
			result.append(pawn)
	return result


## 사리로 앞으로 당길 수 있는 내 말들.
static func pull_targets(game: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in game.pawns_of(player_id):
		if can_shift(game, pawn, 1):
			result.append(pawn)
	return result


## 메죵을 걸 수 있는 적 (레이스에 남은 다른 플레이어).
static func penalty_targets(game: GameState, player_id: int) -> Array[int]:
	return StatusCardCommand.targets(game, player_id)


func can_execute(_ctx: RuleContext) -> bool:
	if state == null:
		return false
	match card_id:
		BERU:
			var victim: PlayerPawn = state.get_pawn(pawn_id)
			return victim != null and victim.owner_id != sender_id and not state.is_graduated(victim.owner_id) and can_shift(state, victim, -1)
		SARI:
			var mine: PlayerPawn = state.get_pawn(pawn_id)
			return mine != null and mine.owner_id == sender_id and can_shift(state, mine, 1)
		MEJONG:
			return penalty_targets(state, sender_id).has(target_player)
	return false


func _run() -> void:
	match card_id:
		BERU:
			_shift(-1)
		SARI:
			_shift(1)
		MEJONG:
			state.roll_penalty[target_player] = int(state.roll_penalty.get(target_player, 0)) + ROLL_PENALTY
			state.roll_penalty_set.emit(target_player, int(state.roll_penalty[target_player]))


## 도착 칸의 설치물·빵집은 평소 도착처럼 판정한다 (밀려 간 칸의 함정을 밟을 수 있다). 도착 칸은 빈 칸이라 잡기·업기는 없다.
func _shift(direction: int) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = pawn.owner_id
	ctx.pawn = pawn
	moved_pawn_id = pawn.entity_id
	moved_to = pawn.current_tile_idx + direction
	state.haunt_shifted.emit(pawn.entity_id, direction)
	MoveExecutor.teleport_to(state, pawn, ctx, MoveReport.new(), moved_to)
