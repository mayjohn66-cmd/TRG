# File: res://core_engine/turn_manager.gd
# Class: class_name TurnManager
# Role: 8단계 턴 상태 머신 + 호스트 권위 판정. 방장(Listen Server)의 TurnManager만 규칙을 실행하고, 나머지 클라이언트에는 @rpc로 결과 상태를 브로드캐스트한다
class_name TurnManager
extends Node

signal phase_changed(phase: int, player_id: int, time_limit: float)
## 연출·UI용 일반 이벤트. kind: roll_resolved, move_resolved, card_played, bell_result, npc_phase_resolved, augment_offers, augment_picked, game_over
signal event_received(kind: StringName, data: Dictionary)
signal action_rejected(player_id: int, action: StringName, reason: StringName)
signal state_synced()
signal game_over(winner_id: int, reason: StringName)

var state: GameState = null
var phase: GameEnums.Phase = GameEnums.Phase.IDLE
var phase_time_left: float = 0.0
var command_stack: CommandStack = CommandStack.new()
var network: NetworkService = null

## true면 호스트 로컬(피어 1)이 params["player_id"]로 모든 플레이어를 대리 조작할 수 있다 (핫시트/테스트).
var hotseat_mode: bool = false
## 증강 드래프트 후보 풀 (content 계층이 채운다). 후보가 3개 미만이면 드래프트는 건너뛴다.
var draft_pool: Array[StringName] = []
var augments: Dictionary = {}
## 피어 ID -> 플레이어 좌석. NetworkService가 있으면 그쪽을 우선한다.
var peer_to_player: Dictionary = {1: 1}

var move_queue: Array[int] = []
var _roll_chain: int = 0
var _turns_in_round: int = 0
var _extra_turn_pending: bool = false
var _draft_offers: Dictionary = {}
var _draft_picks: Dictionary = {}


func _process(delta: float) -> void:
	if state != null and multiplayer.is_server():
		tick(delta)


# ---------------------------------------------------------------------------
# 외부 진입점
# ---------------------------------------------------------------------------

func bind_network(service: NetworkService) -> void:
	network = service


## 호스트 전용: 새 판을 시작한다.
func start_game(player_ids: Array[int], seed_value: int = 0, kinds_by_player: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return
	state = GameState.new()
	state.setup(player_ids, seed_value, kinds_by_player)
	command_stack = CommandStack.new()
	augments.clear()
	for player_id: int in player_ids:
		augments[player_id] = [] as Array[StringName]
	move_queue.clear()
	_turns_in_round = 0
	_extra_turn_pending = false
	_enter_round_start()


## 로컬에서 행동을 보낸다. 서버면 직접 처리하고, 클라이언트면 호스트(피어 1)로 RPC를 보낸다.
func act(action: StringName, params: Dictionary = {}) -> void:
	if multiplayer.is_server():
		request_action(action, params)
	else:
		request_action.rpc_id(1, action, params)


## 모든 플레이어 행동의 단일 입구. 서버만 실행하며 발신 피어로 행동자를 검증한다.
## action: proceed / roll / stop / bell / select_pawn / play_card / pick_augment
@rpc("any_peer", "call_local", "reliable")
func request_action(action: StringName, params: Dictionary = {}) -> void:
	if not multiplayer.is_server() or state == null:
		return
	var actor: int = _resolve_actor(int(params.get("player_id", -1)))
	if actor == -1 or not state.player_ids.has(actor):
		action_rejected.emit(actor, action, &"unknown_player")
		return
	match action:
		&"proceed": _handle_proceed(actor)
		&"roll": _handle_roll(actor)
		&"stop": _handle_stop(actor)
		&"bell": _handle_bell(actor)
		&"select_pawn": _handle_select_pawn(actor, params)
		&"play_card": _handle_play_card(actor, params)
		&"pick_augment": _handle_pick_augment(actor, params)
		_: action_rejected.emit(actor, action, &"unknown_action")


func reverse_turn_order() -> void:
	state.reverse_turn_order()


## 상태를 전환하고 제한 시간을 설정한 뒤 변경을 방송한다.
func change_state(new_phase: GameEnums.Phase) -> void:
	phase = new_phase
	match new_phase:
		GameEnums.Phase.ROUND_START: phase_time_left = GameEnums.PHASE_TIME_DRAFT
		GameEnums.Phase.TURN_BEGIN: phase_time_left = GameEnums.PHASE_TIME_TURN_BEGIN
		GameEnums.Phase.ROLL_WAIT: phase_time_left = GameEnums.PHASE_TIME_ROLL
		GameEnums.Phase.INTERRUPT_ROLL: phase_time_left = GameEnums.PHASE_TIME_INTERRUPT
		GameEnums.Phase.SELECT_PAWN: phase_time_left = GameEnums.PHASE_TIME_SELECT
		GameEnums.Phase.RESOLUTION: phase_time_left = GameEnums.PHASE_TIME_RESOLUTION
		_: phase_time_left = 0.0
	phase_changed.emit(phase, state.current_player, phase_time_left)
	_broadcast_state()


## 시간 경과를 처리한다. _process가 호출하며, 테스트에서는 직접 호출할 수 있다.
func tick(delta: float) -> void:
	if phase_time_left <= 0.0:
		return
	phase_time_left -= delta
	if phase_time_left <= 0.0:
		phase_time_left = 0.0
		_on_timeout()


# ---------------------------------------------------------------------------
# 행동 처리
# ---------------------------------------------------------------------------

func _resolve_actor(claimed_player: int) -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = NetworkService.HOST_PEER_ID
	if hotseat_mode and sender == NetworkService.HOST_PEER_ID:
		return claimed_player
	if network != null:
		return network.player_for_peer(sender)
	return int(peer_to_player.get(sender, -1))


func _handle_proceed(actor: int) -> void:
	if phase == GameEnums.Phase.TURN_BEGIN and actor == state.current_player:
		_enter_roll_wait()
	else:
		action_rejected.emit(actor, &"proceed", &"wrong_phase")


func _handle_roll(actor: int) -> void:
	if phase != GameEnums.Phase.ROLL_WAIT or actor != state.current_player:
		action_rejected.emit(actor, &"roll", &"wrong_phase")
		return
	_apply_roll_result((state.tools[actor] as BaseJudgmentTool).roll(state.rng))


func _handle_stop(actor: int) -> void:
	if phase != GameEnums.Phase.ROLL_WAIT or actor != state.current_player:
		action_rejected.emit(actor, &"stop", &"wrong_phase")
		return
	var result: RollResult = (state.tools[actor] as BaseJudgmentTool).cash_out()
	if result == null:
		action_rejected.emit(actor, &"stop", &"nothing_to_cash_out")
		return
	_apply_roll_result(result)


func _handle_bell(actor: int) -> void:
	var tool: BaseJudgmentTool = state.tools[actor]
	if not (tool is ToolHalliGalli) or phase == GameEnums.Phase.IDLE or phase == GameEnums.Phase.GAME_OVER:
		action_rejected.emit(actor, &"bell", &"no_bell")
		return
	var success: bool = (tool as ToolHalliGalli).press_bell()
	_emit_event(&"bell_result", {"player_id": actor, "success": success})


func _handle_select_pawn(actor: int, params: Dictionary) -> void:
	if phase != GameEnums.Phase.SELECT_PAWN or actor != state.current_player:
		action_rejected.emit(actor, &"select_pawn", &"wrong_phase")
		return
	var pawn: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
	if pawn == null or pawn.owner_id != actor or not pawn.is_selectable():
		action_rejected.emit(actor, &"select_pawn", &"invalid_pawn")
		return
	_execute_move(pawn)


func _handle_play_card(actor: int, params: Dictionary) -> void:
	var card_id: StringName = StringName(params.get("card_id", &""))
	var card: BaseCard = CardRegistry.get_card(card_id)
	if card == null or not card.is_playable_in(phase):
		action_rejected.emit(actor, &"play_card", &"not_playable_now")
		return
	if phase == GameEnums.Phase.TURN_BEGIN and actor != state.current_player:
		action_rejected.emit(actor, &"play_card", &"not_your_turn")
		return
	if not state.has_card(actor, card_id):
		action_rejected.emit(actor, &"play_card", &"card_not_in_hand")
		return
	if not card.can_play(state, actor, params):
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	state.consume_card(actor, card_id)
	var command: GameCommand = card.create_command(state, actor, params)
	if phase == GameEnums.Phase.TURN_BEGIN:
		command_stack.execute(command, state)
		_check_victory(null)
	else:
		command_stack.queue_interrupt(command)
	_emit_event(&"card_played", {"player_id": actor, "card_id": card_id, "params": params, "queued": phase != GameEnums.Phase.TURN_BEGIN})
	_broadcast_state()


func _handle_pick_augment(actor: int, params: Dictionary) -> void:
	if phase != GameEnums.Phase.ROUND_START or not _draft_offers.has(actor) or _draft_picks.has(actor):
		action_rejected.emit(actor, &"pick_augment", &"wrong_phase")
		return
	var index: int = int(params.get("index", -1))
	if index < 0 or index >= (_draft_offers[actor] as Array).size():
		action_rejected.emit(actor, &"pick_augment", &"invalid_index")
		return
	_draft_picks[actor] = index
	if _draft_picks.size() >= _draft_offers.size():
		_finish_draft()


# ---------------------------------------------------------------------------
# 페이즈 진행
# ---------------------------------------------------------------------------

func _on_timeout() -> void:
	match phase:
		GameEnums.Phase.ROUND_START:
			_finish_draft()
		GameEnums.Phase.TURN_BEGIN:
			_enter_roll_wait()
		GameEnums.Phase.ROLL_WAIT:
			var tool: BaseJudgmentTool = state.tools[state.current_player]
			if tool.has_pending_state():
				_apply_roll_result(tool.cash_out())
			else:
				_apply_roll_result(tool.roll(state.rng))
		GameEnums.Phase.INTERRUPT_ROLL:
			_close_interrupt_window()
		GameEnums.Phase.SELECT_PAWN:
			_auto_select_pawn()
		GameEnums.Phase.RESOLUTION:
			_close_resolution_window()


func _enter_round_start() -> void:
	_draft_offers.clear()
	_draft_picks.clear()
	change_state(GameEnums.Phase.ROUND_START)
	if GameEnums.DRAFT_ROUNDS.has(state.round_number) and draft_pool.size() >= GameEnums.DRAFT_OFFER_COUNT:
		for player_id: int in state.player_ids:
			var offers: Array[StringName] = []
			for index: int in BaseJudgmentTool.sample_distinct(state.rng, draft_pool.size(), GameEnums.DRAFT_OFFER_COUNT):
				offers.append(draft_pool[index])
			_draft_offers[player_id] = offers
		_emit_event(&"augment_offers", {"offers": _draft_offers.duplicate(true)})
	else:
		_begin_turn()


func _finish_draft() -> void:
	for player_id: int in _draft_offers:
		var index: int = int(_draft_picks.get(player_id, 0))
		var chosen: StringName = (_draft_offers[player_id] as Array)[index]
		(augments[player_id] as Array).append(chosen)
		_emit_event(&"augment_picked", {"player_id": player_id, "augment_id": chosen, "auto": not _draft_picks.has(player_id)})
	_draft_offers.clear()
	_draft_picks.clear()
	_begin_turn()


func _begin_turn() -> void:
	state.hurt_players.clear()
	state.rollback_requested = false
	move_queue.clear()
	command_stack.clear_interrupts()
	_roll_chain = 0
	_tick_owned_attachments(state.current_player)
	state.turn_snapshot = TurnSnapshot.capture(state)
	(state.tools[state.current_player] as BaseJudgmentTool).on_turn_begin(state.rng)
	change_state(GameEnums.Phase.TURN_BEGIN)


func _tick_owned_attachments(player_id: int) -> void:
	for tile: TileNode in state.board.tiles:
		for attachment: TileAttachment in tile.attachments.duplicate():
			if attachment.owner_id == player_id and attachment.tick_turn():
				tile.remove_attachment(attachment)


func _enter_roll_wait() -> void:
	change_state(GameEnums.Phase.ROLL_WAIT)


func _apply_roll_result(result: RollResult) -> void:
	_emit_event(&"roll_resolved", {"player_id": state.current_player, "result": result.to_dict()})
	if result.ends_turn:
		move_queue.clear()
		_end_turn()
		return
	if result.can_continue:
		phase_time_left = GameEnums.PHASE_TIME_ROLL
		_broadcast_state()
		return
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = state.current_player
	ctx.raw_roll = result.steps
	ctx.dice_value = result.steps
	ctx.trigger_timing = RuleContext.ON_DICE_ROLL
	ctx = state.rulebook.process_context(ctx)
	if not ctx.is_canceled:
		move_queue.append(ctx.dice_value)
	_roll_chain += 1
	if result.reroll and _roll_chain < GameEnums.MAX_REROLL_CHAIN:
		phase_time_left = GameEnums.PHASE_TIME_ROLL
		_broadcast_state()
	else:
		_enter_interrupt_roll()


func _enter_interrupt_roll() -> void:
	change_state(GameEnums.Phase.INTERRUPT_ROLL)
	if not state.any_hand_has_cards():
		_close_interrupt_window()


func _close_interrupt_window() -> void:
	command_stack.resolve_interrupts(state)
	if _check_victory(null):
		return
	_enter_select_pawn()


func _enter_select_pawn() -> void:
	if move_queue.is_empty() or state.selectable_pawns(state.current_player).is_empty():
		move_queue.clear()
		_enter_resolution(null)
		return
	change_state(GameEnums.Phase.SELECT_PAWN)


func _auto_select_pawn() -> void:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in state.selectable_pawns(state.current_player):
		var distance: int = state.pawn_progress_distance(pawn)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	_execute_move(best)


func _execute_move(pawn: PlayerPawn) -> void:
	change_state(GameEnums.Phase.MOVING_STEP)
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = state.current_player
	ctx.dice_value = move_queue.pop_front()
	ctx.raw_roll = ctx.dice_value
	ctx.direction = state.movement_direction()
	var report: MoveReport = MoveExecutor.execute(state, pawn, ctx)
	_extra_turn_pending = _extra_turn_pending or report.extra_turn
	_emit_event(&"move_resolved", report.to_dict())
	if _check_victory(report):
		return
	_enter_resolution(report)


func _enter_resolution(_report: MoveReport) -> void:
	change_state(GameEnums.Phase.RESOLUTION)
	if not state.any_hand_has_cards():
		_close_resolution_window()


func _close_resolution_window() -> void:
	command_stack.resolve_interrupts(state)
	if state.rollback_requested:
		# ACT_05: 보드는 이미 TurnSnapshot으로 복원되었다. 같은 플레이어의 턴을 처음부터 다시 시작한다.
		state.rollback_requested = false
		_extra_turn_pending = false
		_begin_turn()
		return
	if _check_victory(null):
		return
	if not move_queue.is_empty():
		_enter_select_pawn()
	elif _extra_turn_pending:
		_extra_turn_pending = false
		_begin_turn()
	else:
		_end_turn()


func _end_turn() -> void:
	_extra_turn_pending = false
	_turns_in_round += 1
	if _turns_in_round >= state.player_ids.size():
		_turns_in_round = 0
		_enter_npc_phase()
	else:
		state.current_player = state.next_player_after(state.current_player)
		_begin_turn()


func _enter_npc_phase() -> void:
	change_state(GameEnums.Phase.NEUTRAL_NPC)
	var reports: Array[Dictionary] = []
	for npc: NeutralNPC in state.npcs.duplicate():
		reports.append(npc.run_ai(state))
	_emit_event(&"npc_phase_resolved", {"reports": reports})
	if state.reverse_move_rounds_left > 0:
		state.reverse_move_rounds_left -= 1
	state.round_number += 1
	state.current_player = state.next_player_after(state.current_player)
	_enter_round_start()


## 승리 조건: 4개 말을 모두 완주하거나 기물 세트의 특수 승리(report.special_victory).
func _check_victory(report: MoveReport) -> bool:
	var winner_id: int = -1
	var reason: StringName = &""
	if report != null and report.special_victory != &"":
		winner_id = state.current_player
		reason = report.special_victory
	else:
		for player_id: int in state.player_ids:
			var all_home: bool = true
			for pawn: PlayerPawn in state.pawns_of(player_id):
				if not pawn.is_finished:
					all_home = false
			if all_home:
				winner_id = player_id
				reason = &"all_home"
				break
	if winner_id == -1:
		return false
	state.winner = winner_id
	state.victory_declared.emit(winner_id, reason)
	change_state(GameEnums.Phase.GAME_OVER)
	_emit_event(&"game_over", {"winner": winner_id, "reason": reason})
	game_over.emit(winner_id, reason)
	return true


# ---------------------------------------------------------------------------
# 네트워크 방송 (호스트 -> 클라이언트)
# ---------------------------------------------------------------------------

func _has_remote_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not multiplayer.get_peers().is_empty()


func _emit_event(kind: StringName, data: Dictionary) -> void:
	event_received.emit(kind, data)
	if _has_remote_peers():
		_rpc_event.rpc(kind, data)


func _broadcast_state() -> void:
	if not _has_remote_peers():
		return
	_rpc_sync_state.rpc(_build_sync_payload())
	for peer_id: int in multiplayer.get_peers():
		var seat: int = network.player_for_peer(peer_id) if network != null else int(peer_to_player.get(peer_id, -1))
		if seat != -1 and state.hands.has(seat):
			_rpc_sync_hand.rpc_id(peer_id, seat, state.hands[seat])


func _build_sync_payload() -> Dictionary:
	var kinds: Dictionary = {}
	for pawn: PlayerPawn in state.pawns:
		kinds[pawn.id] = pawn.kind
	var hand_counts: Dictionary = {}
	for player_id: int in state.player_ids:
		hand_counts[player_id] = (state.hands[player_id] as Array).size()
	return {
		"phase": phase,
		"time_left": phase_time_left,
		"players": state.player_ids,
		"kinds": kinds,
		"snapshot": TurnSnapshot.capture(state).to_dict(),
		"winner": state.winner,
		"hand_counts": hand_counts,
		"move_queue": move_queue,
	}


## 클라이언트 전용: 호스트가 확정한 상태를 그대로 미러링한다 (규칙은 실행하지 않는다).
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(payload: Dictionary) -> void:
	if state == null:
		var ids: Array[int] = []
		ids.assign(payload["players"])
		var kinds_by_player: Dictionary = {}
		for player_id: int in ids:
			var kinds: Array = []
			for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
				kinds.append(payload["kinds"].get(player_id * 10 + slot, GameEnums.PawnKind.YUT))
			kinds_by_player[player_id] = kinds
		state = GameState.new()
		state.setup(ids, 1, kinds_by_player)
	TurnSnapshot.from_dict(payload["snapshot"]).restore(state, true)
	state.winner = int(payload["winner"])
	move_queue.assign(payload["move_queue"])
	phase = payload["phase"]
	phase_time_left = float(payload["time_left"])
	phase_changed.emit(phase, state.current_player, phase_time_left)
	state_synced.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_hand(player_id: int, cards: Array) -> void:
	if state == null:
		return
	var hand: Array[StringName] = []
	for card_id: Variant in cards:
		hand.append(StringName(card_id))
	state.hands[player_id] = hand


@rpc("authority", "call_remote", "reliable")
func _rpc_event(kind: StringName, data: Dictionary) -> void:
	event_received.emit(kind, data)
