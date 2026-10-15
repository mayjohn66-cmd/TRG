# File: res://core_engine/turn_manager.gd
# Class: class_name TurnManager
# Role: 8단계 턴 상태 머신 + 호스트 권위 판정. 턴 순서(player_order/turn_direction)를 소유하고, CommandStack으로 개입·롤백을 처리하며, 한 칸씩 await 이동을 수행한다. 방장(Listen Server)만 규칙을 실행하고 나머지 클라이언트에는 @rpc로 결과를 브로드캐스트한다
class_name TurnManager
extends Node

enum State {
	PHASE_ROUND_START,
	PHASE_TURN_BEGIN,
	PHASE_ROLL_WAIT,
	PHASE_INTERRUPT_ROLL,
	PHASE_SELECT_PAWN,
	PHASE_MOVING_STEP,
	PHASE_RESOLUTION,
	PHASE_NEUTRAL_NPC,
}

signal phase_changed(new_state: State, player_id: int, time_limit: float)
## 우노 리버스(ACT_01) 등으로 턴 진행 방향이 뒤집혔다. new_direction: 1 정방향 / -1 역방향.
signal turn_order_reversed(new_direction: int)
## 연출·UI용 일반 이벤트. kind: roll_resolved, move_resolved, card_played, bell_result, npc_phase_resolved, augment_offers, augment_picked, game_over
signal event_received(kind: StringName, data: Dictionary)
signal action_rejected(player_id: int, action: StringName, reason: StringName)
signal state_synced()
signal game_over(winner_id: int, reason: StringName)

var state: GameState = null
var current_state: State = State.PHASE_ROUND_START
var phase_time_left: float = 0.0
var command_stack: CommandStack = null
var network: NetworkService = null

## 플레이 순서(플레이어 ID). 정방향 기준이며 start_game()이 참가자로 덮어쓴다.
var player_order: Array[int] = [1, 2, 3, 4]
var current_turn_index: int = 0
## 1: 정방향, -1: 우노 리버스 역방향.
var turn_direction: int = 1
var is_game_over: bool = false

## 한 칸 이동 사이의 연출 대기 시간(초). 0이면 await 없이 즉시 끝까지 이동한다 (헤드리스/테스트). 뷰 연결 시 올린다.
@export var step_delay_sec: float = 0.0

## true면 호스트 로컬(피어 1)이 params["player_id"]로 모든 플레이어를 대리 조작할 수 있다 (핫시트/테스트).
var hotseat_mode: bool = false
## 1, 4, 7라운드 시작 증강 드래프트를 여는가. 헤드리스 테스트나 드래프트 없는 모드에서는 끈다.
var draft_enabled: bool = true
## 플레이어 ID -> 지금까지 고른 증강 ID 목록.
var augments: Dictionary = {}
## 피어 ID -> 플레이어 좌석. NetworkService가 있으면 그쪽을 우선한다.
var peer_to_player: Dictionary = {1: 1}

var move_queue: Array[int] = []
var _roll_chain: int = 0
var _turns_in_round: int = 0
var _extra_turn_pending: bool = false
var _bonus_roll_pending: bool = false
## 현재 플레이어가 이번 턴에 연속으로 잡은 말 수 (장군멍군 판정). 턴이 넘어가거나 롤백되면 0이 된다.
var _chain_captures: int = 0
var _draft_offers: Dictionary = {}
var _draft_picks: Dictionary = {}
## 진행 중인 이동의 보고서와 마지막 걸음 결과 (execute_step_by_step_move가 채운다).
var _move_report: MoveReport = null
var _move_outcome: MoveExecutor.StepOutcome = MoveExecutor.StepOutcome.CONTINUE


func _process(delta: float) -> void:
	if state != null and multiplayer.is_server():
		tick(delta)


# ---------------------------------------------------------------------------
# 외부 진입점
# ---------------------------------------------------------------------------

func bind_network(service: NetworkService) -> void:
	network = service


## 현재 턴 플레이어 ID.
func current_player_id() -> int:
	return player_order[current_turn_index]


## 호스트 전용: 새 판을 시작한다.
func start_game(player_ids: Array[int], seed_value: int = 0, loadouts: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return
	state = GameState.new()
	state.setup(player_ids, seed_value, loadouts)
	state.turn_order_reverse_requested.connect(reverse_turn_order)
	_ensure_command_stack()
	command_stack.begin_turn()
	player_order = player_ids.duplicate()
	current_turn_index = 0
	turn_direction = 1
	is_game_over = false
	_sync_current_player()
	augments.clear()
	for player_id: int in player_ids:
		augments[player_id] = [] as Array[StringName]
	move_queue.clear()
	_turns_in_round = 0
	_extra_turn_pending = false
	_bonus_roll_pending = false
	_chain_captures = 0
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
	if actor == -1 or not player_order.has(actor):
		action_rejected.emit(actor, action, &"unknown_player")
		return
	if is_game_over:
		action_rejected.emit(actor, action, &"game_over")
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


## 턴 진행 방향을 뒤집는다 (우노 리버스 ACT_01).
func reverse_turn_order() -> void:
	turn_direction *= -1
	turn_order_reversed.emit(turn_direction)
	_broadcast_state()


## turn_direction에 따라 다음 플레이어로 인덱스를 순환시켜 새 턴을 시작한다.
## 이번이 라운드의 마지막 턴이었다면 PHASE_NEUTRAL_NPC로 진입한다.
func advance_to_next_player() -> void:
	_extra_turn_pending = false
	_bonus_roll_pending = false
	_chain_captures = 0
	_turns_in_round += 1
	if _turns_in_round >= player_order.size():
		_turns_in_round = 0
		_enter_neutral_npc_phase()
		return
	_step_turn_index()
	_begin_turn()


## 상태를 전환하고 제한 시간을 설정한 뒤 변경을 방송한다.
func change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.PHASE_ROUND_START: phase_time_left = GameEnums.PHASE_TIME_DRAFT
		State.PHASE_TURN_BEGIN: phase_time_left = GameEnums.PHASE_TIME_TURN_BEGIN
		State.PHASE_ROLL_WAIT: phase_time_left = GameEnums.PHASE_TIME_ROLL
		State.PHASE_INTERRUPT_ROLL: phase_time_left = GameEnums.PHASE_TIME_INTERRUPT
		State.PHASE_SELECT_PAWN: phase_time_left = GameEnums.PHASE_TIME_SELECT
		State.PHASE_RESOLUTION: phase_time_left = GameEnums.PHASE_TIME_RESOLUTION
		_: phase_time_left = 0.0
	phase_changed.emit(current_state, current_player_id(), phase_time_left)
	_broadcast_state()


## 시간 경과를 처리한다. _process가 호출하며, 테스트에서는 직접 호출할 수 있다.
func tick(delta: float) -> void:
	if phase_time_left <= 0.0 or is_game_over:
		return
	phase_time_left -= delta
	if phase_time_left <= 0.0:
		phase_time_left = 0.0
		_on_timeout()


## 로컬/핫시트에서 남은 대기 시간을 건너뛴다 (개입 창 닫기 등). 이동 연출 중에는 동작하지 않는다.
func force_timeout() -> void:
	if state == null or is_game_over or current_state == State.PHASE_MOVING_STEP or phase_time_left <= 0.0:
		return
	phase_time_left = 0.0
	_on_timeout()


## PHASE_MOVING_STEP 본체: path(BoardGraph.calculate_path 결과)를 한 칸씩 밟는다.
## 한 칸 이동할 때마다 그 TileNode의 TileAttachment(은신 함정) 발동 여부를 검사하고, 함정이 이동을 중단시키면
## 남은 경로를 버리고 즉시 멈춘다. 칸 사이에 step_delay_sec만큼 await 하므로 뷰가 걸음마다 연출할 수 있다.
## 결과 보고서와 마지막 걸음 결과는 _move_report / _move_outcome에 남는다.
func execute_step_by_step_move(entity: BoardEntity, path: Array[int], ctx: RuleContext) -> void:
	var pawn: PlayerPawn = entity as PlayerPawn
	if pawn == null:
		push_error("execute_step_by_step_move: PlayerPawn이 아닌 개체는 이동할 수 없습니다")
		return
	if _move_report == null:
		_move_report = MoveReport.new()
		_move_report.pawn_id = pawn.entity_id
	_move_outcome = MoveExecutor.StepOutcome.CONTINUE
	ctx.pawn = pawn
	for index: int in path.size():
		var is_last: bool = index == path.size() - 1
		_move_outcome = MoveExecutor.apply_step(state, pawn, ctx, path[index], is_last, index == 0, _move_report)
		if _move_outcome != MoveExecutor.StepOutcome.CONTINUE:
			break
		if not is_last and step_delay_sec > 0.0 and is_inside_tree():
			await get_tree().create_timer(step_delay_sec).timeout


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
	if current_state == State.PHASE_TURN_BEGIN and actor == current_player_id():
		_enter_roll_wait()
	else:
		action_rejected.emit(actor, &"proceed", &"wrong_phase")


func _handle_roll(actor: int) -> void:
	if current_state != State.PHASE_ROLL_WAIT or actor != current_player_id():
		action_rejected.emit(actor, &"roll", &"wrong_phase")
		return
	_apply_roll_result((state.tools[actor] as BaseJudgmentTool).roll(state.rng))


func _handle_stop(actor: int) -> void:
	if current_state != State.PHASE_ROLL_WAIT or actor != current_player_id():
		action_rejected.emit(actor, &"stop", &"wrong_phase")
		return
	var result: RollResult = (state.tools[actor] as BaseJudgmentTool).cash_out()
	if result == null:
		action_rejected.emit(actor, &"stop", &"nothing_to_cash_out")
		return
	_apply_roll_result(result)


func _handle_bell(actor: int) -> void:
	var tool: BaseJudgmentTool = state.tools[actor]
	if not (tool is ToolHalliGalli):
		action_rejected.emit(actor, &"bell", &"no_bell")
		return
	var success: bool = (tool as ToolHalliGalli).press_bell()
	_emit_event(&"bell_result", {"player_id": actor, "success": success})


func _handle_select_pawn(actor: int, params: Dictionary) -> void:
	if current_state != State.PHASE_SELECT_PAWN or actor != current_player_id():
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
	if card == null or not card.is_playable_in(current_state):
		action_rejected.emit(actor, &"play_card", &"not_playable_now")
		return
	if current_state == State.PHASE_TURN_BEGIN and actor != current_player_id():
		action_rejected.emit(actor, &"play_card", &"not_your_turn")
		return
	if not state.has_card(actor, card_id):
		action_rejected.emit(actor, &"play_card", &"card_not_in_hand")
		return
	if not card.can_play(state, actor, params):
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	var command: GameCommand = card.create_command(state, actor, params)
	var ctx: RuleContext = _make_ctx(actor)
	var accepted: bool
	var queued: bool = current_state != State.PHASE_TURN_BEGIN
	if queued:
		accepted = command_stack.push_interrupt(command, ctx)
	else:
		accepted = command_stack.execute_command(command, ctx)
	if not accepted:
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	state.consume_card(actor, card_id)
	_emit_event(&"card_played", {"player_id": actor, "card_id": card_id, "params": params, "queued": queued})
	if not queued:
		_check_victory(null)
	_broadcast_state()


func _handle_pick_augment(actor: int, params: Dictionary) -> void:
	if current_state != State.PHASE_ROUND_START or not _draft_offers.has(actor) or _draft_picks.has(actor):
		action_rejected.emit(actor, &"pick_augment", &"wrong_phase")
		return
	var index: int = int(params.get("index", -1))
	if index < 0 or index >= (_draft_offers[actor] as Array).size():
		action_rejected.emit(actor, &"pick_augment", &"invalid_index")
		return
	if not _pick_augment(actor, index, params, false):
		action_rejected.emit(actor, &"pick_augment", &"invalid_pawn")
		return
	if _draft_picks.size() >= _draft_offers.size():
		_finish_draft()


## 로컬/핫시트용: 해당 플레이어의 증강을 무작위로 자동 선택한다 (기물 진화는 가장 앞 슬롯의 기본 말).
func auto_pick_draft(player_id: int) -> void:
	if current_state != State.PHASE_ROUND_START or not _draft_offers.has(player_id) or _draft_picks.has(player_id):
		return
	var index: int = state.rng.randi_range(0, (_draft_offers[player_id] as Array).size() - 1)
	_pick_augment(player_id, index, {}, true)
	if _draft_picks.size() >= _draft_offers.size():
		_finish_draft()


## 드래프트 중 아직 선택하지 않은 플레이어 (플레이 순서대로).
func draft_pending_players() -> Array[int]:
	var pending: Array[int] = []
	for player_id: int in player_order:
		if _draft_offers.has(player_id) and not _draft_picks.has(player_id):
			pending.append(player_id)
	return pending


func draft_offers_for(player_id: int) -> Array[StringName]:
	var offers: Array[StringName] = []
	offers.assign(_draft_offers.get(player_id, []))
	return offers


## 선택한 증강을 즉시 적용하고 기록한다. 적용에 실패하면 false.
func _pick_augment(player_id: int, index: int, params: Dictionary, automatic: bool) -> bool:
	var augment_id: StringName = (_draft_offers[player_id] as Array)[index]
	var definition: AugmentDef = AugmentRegistry.get_def(augment_id)
	var result: Dictionary = definition.apply(state, player_id, params)
	if not bool(result["ok"]):
		return false
	_draft_picks[player_id] = index
	(augments[player_id] as Array).append(augment_id)
	_emit_event(&"augment_picked", {"player_id": player_id, "augment_id": augment_id, "text": result["text"], "auto": automatic})
	_broadcast_state()
	return true


# ---------------------------------------------------------------------------
# 페이즈 진행
# ---------------------------------------------------------------------------

func _on_timeout() -> void:
	match current_state:
		State.PHASE_ROUND_START:
			_finish_draft()
		State.PHASE_TURN_BEGIN:
			_enter_roll_wait()
		State.PHASE_ROLL_WAIT:
			var tool: BaseJudgmentTool = state.tools[current_player_id()]
			if tool.has_pending_state():
				_apply_roll_result(tool.cash_out())
			else:
				_apply_roll_result(tool.roll(state.rng))
		State.PHASE_INTERRUPT_ROLL:
			_close_interrupt_window()
		State.PHASE_SELECT_PAWN:
			_auto_select_pawn()
		State.PHASE_RESOLUTION:
			_close_resolution_window()


func _ensure_command_stack() -> void:
	if command_stack == null:
		command_stack = CommandStack.new()
		add_child(command_stack)


func _sync_current_player() -> void:
	state.current_player = current_player_id()


func _step_turn_index() -> void:
	current_turn_index = posmod(current_turn_index + turn_direction, player_order.size())
	_sync_current_player()


func _make_ctx(actor: int) -> RuleContext:
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = actor
	return ctx


func _enter_round_start() -> void:
	_draft_offers.clear()
	_draft_picks.clear()
	change_state(State.PHASE_ROUND_START)
	if draft_enabled and GameEnums.DRAFT_ROUNDS.has(state.round_number):
		for player_id: int in player_order:
			_draft_offers[player_id] = AugmentRegistry.generate_offers(state, player_id)
		_emit_event(&"augment_offers", {"round": state.round_number, "offers": _draft_offers.duplicate(true)})
	else:
		_begin_turn()


## 시간 초과 등으로 드래프트를 마감한다. 아직 고르지 않은 플레이어는 첫 번째 선택지로 자동 선택된다.
func _finish_draft() -> void:
	for player_id: int in player_order:
		if _draft_offers.has(player_id) and not _draft_picks.has(player_id):
			_pick_augment(player_id, 0, {}, true)
	_draft_offers.clear()
	_draft_picks.clear()
	_begin_turn()


## new_turn: 새 플레이어의 턴이면 true (구속 카운터를 줄인다). 추가 턴·롤백 재시작은 false.
func _begin_turn(new_turn: bool = true) -> void:
	state.hurt_players.clear()
	state.rollback_requested = false
	move_queue.clear()
	command_stack.begin_turn()
	_roll_chain = 0
	_move_report = null
	_sync_current_player()
	if new_turn:
		_tick_restraints(current_player_id())
	_tick_owned_attachments(current_player_id())
	state.turn_snapshot = TurnSnapshot.capture(state)
	(state.tools[current_player_id()] as BaseJudgmentTool).on_turn_begin(state.rng)
	change_state(State.PHASE_TURN_BEGIN)


## TRP_02 나락으로 구속된 말: 내 턴이 시작될 때마다 구속 턴을 하나씩 소모하고, 그 턴에는 선택할 수 없다.
func _tick_restraints(player_id: int) -> void:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		pawn.blocked_this_turn = pawn.restrained_turns > 0
		if pawn.restrained_turns > 0:
			pawn.restrained_turns -= 1


func _tick_owned_attachments(player_id: int) -> void:
	for tile: TileNode in state.board.tiles:
		for attachment: TileAttachment in tile.attachments.duplicate():
			if attachment.owner_id == player_id and attachment.tick_turn():
				tile.remove_attachment(attachment)


func _enter_roll_wait() -> void:
	change_state(State.PHASE_ROLL_WAIT)


func _apply_roll_result(result: RollResult) -> void:
	_emit_event(&"roll_resolved", {"player_id": current_player_id(), "result": result.to_dict()})
	if result.ends_turn:
		move_queue.clear()
		advance_to_next_player()
		return
	if result.can_continue:
		phase_time_left = GameEnums.PHASE_TIME_ROLL
		_broadcast_state()
		return
	var ctx: RuleContext = _make_ctx(current_player_id())
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


## 이 단계의 개입 창에서 낼 수 있는 카드를 가진 플레이어가 있는가. 없으면 창을 열지 않고 바로 진행한다.
func _someone_can_intervene() -> bool:
	for player_id: int in player_order:
		for card_id: StringName in state.hands[player_id]:
			var card: BaseCard = CardRegistry.get_card(card_id)
			if card.is_playable_in(current_state) and card.could_play(state, player_id):
				return true
	return false


func _enter_interrupt_roll() -> void:
	change_state(State.PHASE_INTERRUPT_ROLL)
	if not _someone_can_intervene():
		_close_interrupt_window()


func _close_interrupt_window() -> void:
	command_stack.resolve_interrupts(_make_ctx(current_player_id()))
	if _check_victory(null):
		return
	_enter_select_pawn()


func _enter_select_pawn() -> void:
	if move_queue.is_empty() or state.selectable_pawns(current_player_id()).is_empty():
		move_queue.clear()
		_enter_resolution()
		return
	change_state(State.PHASE_SELECT_PAWN)


func _auto_select_pawn() -> void:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in state.selectable_pawns(current_player_id()):
		var distance: int = state.pawn_progress_distance(pawn)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	_execute_move(best)


## PHASE_MOVING_STEP: 법전(ON_MOVE_CALC)을 통과시켜 경로를 확정하고, 한 칸씩 이동한 뒤 도착 처리를 한다.
## 이동 직전 상태를 MoveCommand로 이번 턴 이력에 등록하므로 ACT_05가 이 이동도 되감는다.
func _execute_move(pawn: PlayerPawn) -> void:
	change_state(State.PHASE_MOVING_STEP)
	var ctx: RuleContext = _make_ctx(current_player_id())
	ctx.dice_value = move_queue.pop_front()
	ctx.raw_roll = ctx.dice_value
	ctx.direction = state.movement_direction()

	var move_command := MoveCommand.new(current_player_id(), pawn.entity_id, ctx)
	move_command.bind_state(state)
	move_command.capture_before()
	command_stack.record(move_command)

	_move_report = MoveExecutor.begin(state, pawn, ctx)
	if not _move_report.canceled:
		var path: Array[int] = state.board.calculate_path(pawn, ctx.dice_value * ctx.direction, ctx)
		await execute_step_by_step_move(pawn, path, ctx)
		MoveExecutor.finalize(state, pawn, ctx, _move_report, _move_outcome)
	var report: MoveReport = _move_report
	_move_report = null
	_extra_turn_pending = _extra_turn_pending or report.extra_turn
	_chain_captures += report.captured_pawn_ids.size()
	if pawn.kind == GameEnums.PawnKind.YUT and state.set_count(pawn.owner_id, GameEnums.PawnKind.YUT) >= GameEnums.SET_SYNERGY_2 and [4, 5].has(absi(ctx.raw_roll)):
		# 윷 2세트 [사기 윷]: 4 또는 5가 나오면 무조건 추가 굴림 1회.
		report.bonus_roll = true
		_bonus_roll_pending = true
	_emit_event(&"move_resolved", report.to_dict())
	if _check_victory(report):
		return
	_enter_resolution()


func _enter_resolution() -> void:
	change_state(State.PHASE_RESOLUTION)
	if not _someone_can_intervene():
		_close_resolution_window()


func _close_resolution_window() -> void:
	command_stack.resolve_interrupts(_make_ctx(current_player_id()))
	if state.rollback_requested:
		# ACT_05: CommandStack이 이번 턴 이력을 역순으로 undo했다. 같은 플레이어의 턴을 처음부터 다시 시작한다.
		state.rollback_requested = false
		_extra_turn_pending = false
		_bonus_roll_pending = false
		_chain_captures = 0
		_begin_turn(false)
		return
	if _check_victory(null):
		return
	if not move_queue.is_empty():
		_enter_select_pawn()
	elif _bonus_roll_pending:
		_bonus_roll_pending = false
		_roll_chain = 0
		_enter_roll_wait()
	elif _extra_turn_pending:
		_extra_turn_pending = false
		_begin_turn(false)
	else:
		advance_to_next_player()


func _enter_neutral_npc_phase() -> void:
	change_state(State.PHASE_NEUTRAL_NPC)
	var reports: Array[Dictionary] = []
	for npc: NeutralNPC in state.npcs.duplicate():
		reports.append(npc.run_ai(state))
	_emit_event(&"npc_phase_resolved", {"reports": reports})
	if state.reverse_move_rounds_left > 0:
		state.reverse_move_rounds_left -= 1
	state.round_number += 1
	_step_turn_index()
	_enter_round_start()


## PHASE_RESOLUTION 승리 판정: 일반 승리와 기물 4세트 특수 승리 5종을 VictoryChecker로 검사한다.
func _check_victory(report: MoveReport) -> bool:
	var result: Dictionary = VictoryChecker.evaluate(state, player_order, current_player_id(), report, _chain_captures)
	if result.is_empty():
		return false
	var winner_id: int = int(result["winner"])
	var reason: StringName = result["reason"]
	state.winner = winner_id
	is_game_over = true
	phase_time_left = 0.0
	state.victory_declared.emit(winner_id, reason)
	_emit_event(&"game_over", {"winner": winner_id, "reason": reason})
	_broadcast_state()
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
	var hand_counts: Dictionary = {}
	for player_id: int in player_order:
		hand_counts[player_id] = (state.hands[player_id] as Array).size()
	return {
		"phase": current_state,
		"time_left": phase_time_left,
		"order": player_order,
		"turn_index": current_turn_index,
		"direction": turn_direction,
		"game_over": is_game_over,
		"snapshot": TurnSnapshot.capture(state).to_dict(),
		"winner": state.winner,
		"hand_counts": hand_counts,
		"move_queue": move_queue,
	}


## 클라이언트 전용: 호스트가 확정한 상태를 그대로 미러링한다 (규칙은 실행하지 않는다).
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(payload: Dictionary) -> void:
	player_order.assign(payload["order"])
	if state == null:
		state = GameState.new()
		state.setup(player_order, 1)
	TurnSnapshot.from_dict(payload["snapshot"]).restore(state, true)
	state.winner = int(payload["winner"])
	current_turn_index = int(payload["turn_index"])
	turn_direction = int(payload["direction"])
	is_game_over = bool(payload["game_over"])
	move_queue.assign(payload["move_queue"])
	current_state = payload["phase"]
	phase_time_left = float(payload["time_left"])
	phase_changed.emit(current_state, current_player_id(), phase_time_left)
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
