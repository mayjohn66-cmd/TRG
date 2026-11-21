# File: res://core_engine/commands/penguin_command.gd
# Class: class_name PenguinCommand
# Role: ACT_21 펭짱 8호 - 내 말 하나가 선 자리에서 펭귄이 알까기처럼 날아가(각도·세기) 길목에서 부딪힌 적 말을 모두 출발선으로 날려 버린다. 내 말은 움직이지 않는다
class_name PenguinCommand
extends GameCommand

var pawn_id: int = -1
var angle: float = 0.0
var power: float = 0.5
## 실행 뒤 UI가 읽는다: 날아간 경로와 날려 버린 말.
var result: Dictionary = {}


func _init(acting_player: int = -1, origin_pawn: int = -1, shot_angle: float = 0.0, shot_power: float = 0.5) -> void:
	super()
	sender_id = acting_player
	pawn_id = origin_pawn
	angle = shot_angle
	power = clampf(shot_power, 0.0, 1.0)
	command_name = "Penguin"


## 펭귄을 날릴 수 있는 내 말 (보드 위에 나와 있고 업혀 있지 않은 말).
static func origins(game: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in game.pawns_of(player_id):
		if pawn.has_left_start and not pawn.is_finished and pawn.carrier == null:
			result.append(pawn)
	return result


func can_execute(_ctx: RuleContext) -> bool:
	if state == null or is_nan(angle):
		return false
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return pawn != null and origins(state, sender_id).has(pawn)


func _run() -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	var shot: Dictionary = PawnSkills.shot_result(state, pawn, angle, power)  # 흑돌 알까기와 같은 궤적·적중 판정
	var hit_ids: Array[int] = []
	for hit_id: Variant in shot["hits"]:
		var victim: PlayerPawn = state.get_pawn(int(hit_id))
		if victim == null:
			continue
		var members: Array[PlayerPawn] = victim.stack_members()
		state.send_to_start(victim, sender_id)
		for member: PlayerPawn in members:
			if not member.has_left_start and not member.is_finished:  # 보호막이 막은 말은 빠진다
				hit_ids.append(member.entity_id)
	result = {"from": shot["from"], "to": shot["to"], "hits": hit_ids}
	state.penguin_flew.emit(sender_id, pawn_id, shot["from"], shot["to"], hit_ids)
