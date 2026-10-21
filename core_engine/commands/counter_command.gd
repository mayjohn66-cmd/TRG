# File: res://core_engine/commands/counter_command.gd
# Class: class_name CounterCommand
# Role: 방어 카드 CNT_02~07 실행 - 공격 기록 하나의 피해를 되돌리고(말 위치·휴식·밴·기록 복원) 카드별로 되갚는다: 공격한 말 사출 / 공격 카드 반사 / 함정 파괴 후 +3칸 / 함정 무효 + 카드 강탈 / 걸린 함정 카드를 내 패로 (도굴꾼)
class_name CounterCommand
extends GameCommand

var card_id: StringName = &""
var attack_id: int = -1


func _init(acting_player: int = -1, counter_id: StringName = &"", target_attack: int = -1) -> void:
	super()
	sender_id = acting_player
	card_id = counter_id
	attack_id = target_attack
	command_name = "Counter"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and CardCounter.answers(state, card_id, state.get_attack(attack_id))


func _run() -> void:
	var entry: Dictionary = state.get_attack(attack_id)
	var attacker: int = int(entry.get("attacker", -1))
	if entry["kind"] == CardCounter.TRAP:
		_remove_trap(entry)
	state.undo_attack(entry)
	match card_id:
		&"CNT_02":
			var striker: PlayerPawn = state.get_pawn(int(entry["attacker_pawn"]))
			if striker != null and striker.has_left_start and not striker.is_finished:
				state.send_to_start(striker, sender_id)
		&"CNT_03":
			reflect(state, entry, sender_id)
		&"CNT_05":
			var mover: PlayerPawn = _victim_leader(entry)
			if mover != null:
				MoveExecutor.forced_advance(state, mover, CardRegistry.param(&"CNT_05", CardCounter.CYCLONE_STEPS))
		&"CNT_06":
			if attacker >= 1:
				var stolen: StringName = state.steal_random_card(attacker, state.rng)
				if stolen != &"" and not state.give_card(sender_id, stolen):
					(state.hands[attacker] as Array).append(stolen)  # 내 손패가 가득 차면 돌려준다
		&"CNT_07":
			# 도굴꾼: 걸린 함정은 발동하지 않고(되돌림) 그 함정 카드를 내 패로 가져온다
			var trap_card: StringName = StringName(entry.get("trap_id", ""))
			if CardRegistry.get_card(trap_card) != null:
				state.give_card(sender_id, trap_card)


## 우노 리버스: 되돌린 공격 카드를 공격한 사람에게 돌려준다 (밴·스킵·이의 있음은 같은 효과, 그 밖의 카드는 공격자 선두 말 사출).
static func reflect(game: GameState, entry: Dictionary, reflector: int) -> void:
	var attacker: int = int(entry.get("attacker", -1))
	if attacker < 1:
		return
	match StringName(entry.get("card_id", &"")):
		&"ACT_14":
			game.banned_turns[attacker] = StatusCardCommand.ban_turns()
		&"ACT_15":
			game.rest_next_turn[attacker] = true
		&"ACT_06":
			for key: String in (entry["effects"] as Dictionary).keys():
				if key.begins_with("stat:"):
					game.reset_stat(attacker, StringName(key.trim_prefix("stat:")))
		_:
			var front: PlayerPawn = game.front_pawn_of(attacker)
			if front != null:
				game.send_to_start(front, reflector)


func _victim_leader(entry: Dictionary) -> PlayerPawn:
	for pawn_id: Variant in (entry["pawns"] as Dictionary).keys():
		var pawn: PlayerPawn = state.get_pawn(int(pawn_id))
		if pawn != null and pawn.carrier == null and pawn.has_left_start and not pawn.is_finished:
			return pawn
	return null


func _remove_trap(entry: Dictionary) -> void:
	var tile_index: int = int(entry.get("trap_tile", -1))
	if not state.board.is_valid_tile(tile_index):
		return
	var tile: TileNode = state.board.get_tile(tile_index)
	for attachment: TileAttachment in tile.attachments.duplicate():
		if attachment.attachment_id == String(entry.get("trap_id", "")) and attachment.owner_id == int(entry.get("attacker", -1)):
			tile.remove_attachment(attachment)
			return
