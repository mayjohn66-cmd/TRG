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

## 락스텝으로 복제되는 내부 행동 이름.
const ACTION_TIMEOUT: StringName = &"__timeout"
const ACTION_AUTO_DRAFT: StringName = &"__auto_draft"

signal phase_changed(new_state: State, player_id: int, time_limit: float)
## 우노 리버스(ACT_01) 등으로 턴 진행 방향이 뒤집혔다. new_direction: 1 정방향 / -1 역방향.
signal turn_order_reversed(new_direction: int)
## 연출·UI용 일반 이벤트. kind: roll_resolved, move_resolved, turn_skipped, card_played, npc_phase_resolved, augment_offers, augment_picked, game_over
signal event_received(kind: StringName, data: Dictionary)
signal action_rejected(player_id: int, action: StringName, reason: StringName)
signal state_synced()
signal game_over(winner_id: int, reason: StringName)
## 외부 타임아웃 모드에서 제한 시간이 끝났다 (serial: 그 시점의 phase_serial). 방장의 NetGame이 이 신호를 받아 모두에게 같은 타임아웃 행동을 보낸다.
signal timeout_due(serial: int)
## 행동 하나(또는 시간 초과 처리)를 시작/끝냈다. 화면은 그 사이의 갱신 요청을 모아 끝날 때 한 번만 그린다 (같은 처리 안에서 짝이 맞는다).
signal processing_started()
signal processing_finished()

var state: GameState = null
var current_state: State = State.PHASE_ROUND_START
## change_state()가 불릴 때마다 1씩 늘어나는 번호 (같은 상태로 다시 들어와도 변한다). 봇 컨트롤러가 새 결정 지점을 알아채는 데 쓴다.
var phase_serial: int = 0
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
## 한 번의 이동 연출 총시간 상한(초): 칸이 많을수록 칸당 시간을 줄여 몇 칸을 가든 이 시간을 넘지 않는다 (칸당 = min(step_delay_sec, 상한 / 칸 수)).
const MOVE_TIME_CAP: float = 2.4  ## 2026-10-26: 0.75 -> 2.4 (칸마다 탁 탁 끊어 보이게)
## 이 칸 수 이상의 장거리 이동(리벤지 부스터 + 고눈금 등)은 칸당 시간을 LONG_MOVE_STEP_SECONDS로 줄여 타다닥 지나간다.
const LONG_MOVE_TILES: int = 10
const LONG_MOVE_STEP_SECONDS: float = 0.16
## 지금 이동의 칸당 시간 (화면의 한 칸 점프 길이를 엔진 걸음과 맞춘다).
var current_step_seconds: float = 0.0

## true면 모든 참가자가 같은 시드로 같은 규칙 엔진을 각자 돌린다(락스텝). 행동은 방장이 정한 순서대로 apply_replicated()로 들어오고, 네트워크로 상태·이벤트를 따로 보내지 않는다.
var lockstep: bool = false
## 설정되면 act()/force_timeout()/auto_pick_draft()가 규칙을 직접 실행하지 않고 이 Callable(action, params)로 보낸다 (락스텝 NetGame이 순서를 정해 되돌려 준다).
var action_interceptor: Callable = Callable()
## true면 제한 시간이 끝나도 스스로 처리하지 않고 timeout_due 신호만 보낸다 (락스텝에서 방장이 대표로 정한다).
var external_timeouts: bool = false
## 제한 시간 배율 (온라인 대전은 사람 속도에 맞게 늘린다).
var timer_scale: float = 1.0

## true면 호스트 로컬(피어 1)이 params["player_id"]로 모든 플레이어를 대리 조작할 수 있다 (핫시트/테스트).
var hotseat_mode: bool = false
## 1라운드부터 3라운드마다(1, 4, 7, 10, ...) 시작하는 증강 드래프트를 여는가. 헤드리스 테스트나 드래프트 없는 모드에서는 끈다.
var draft_enabled: bool = true
## true면 윷놀이 기물의 업기 가능 도착마다 PHASE_RESOLUTION 안에서 플레이어의 [업기/그냥 두기] 선택을 기다린다.
## false(기본: 헤드리스 테스트·AI 턴)면 선택을 묻지 않고 항상 [업기]를 선택한 것으로 처리한다.
var stack_choice_enabled: bool = false
## 선택 대기 중인 업기 제안 ({"mover": 이동한 말 ID, "others": 합칠 아군 ID들}).
var _stack_offer: Dictionary = {}
## ACT_09 결투 진행 상태 (없으면 빈 Dictionary): {"challenger","defender","step"(pick/strike),"picks","draws","winner","loser","candidates"}.
var _duel: Dictionary = {}
## 테스트·연출 확인용: 0 이상이면 결투 종목을 이 값으로 고정한다 (DuelRules.Game).
var duel_game_override: int = -1
## 방어 대기: {"victim": 플레이어, "attack": 공격 기록 ID, "resume": &"turn_begin"/&"resolution", "cards": [낼 수 있는 방어 카드]}. 없으면 빈 Dictionary.
var _counter_offer: Dictionary = {}
## 폭풍 전진 가속 기믹(발판·점프·복수) 사용 여부. start_game 전에만 바꿀 수 있다.
var boost_gimmicks: bool = true
## 판 규칙 설정 (MatchRules). start_game이 GameState에 넣는다. 온라인은 모든 참가자가 방장이 보낸 같은 값을 쓴다.
var match_rules: Dictionary = MatchRules.defaults()
## 도박사의 영혼이 눈금 1 이하로 과열된 플레이어 (이동이 끝나면 움직인 말이 출발선으로 사출된다). 없으면 -1.
## 플레이어 ID -> 지금까지 고른 증강 ID 목록.
var augments: Dictionary = {}
## 피어 ID -> 플레이어 좌석. NetworkService가 있으면 그쪽을 우선한다.
var peer_to_player: Dictionary = {1: 1}

var move_queue: Array[int] = []
var _roll_chain: int = 0
## 이번 라운드에 차례를 마친 플레이어 (졸업·휴식으로 건너뛴 차례 포함). 리버스로 방향이 바뀌어도 모두 정확히 한 번씩 하고 라운드가 끝난다.
var _round_done: Dictionary = {}
## 드래프트가 끝나면 고른 증강을 모두가 확인하는 단계를 둘지 (화면이 있는 판에서 MainBoard가 켠다. 엔진 단위 테스트는 바로 라운드를 시작한다).
var review_enabled: bool = false
## 증강 확인을 아직 누르지 않은 플레이어 (비어 있으면 확인 단계가 아니다).
var _review_pending: Array[int] = []
var _extra_turn_pending: bool = false
var _bonus_roll_pending: bool = false
var _draft_offers: Dictionary = {}
var _draft_picks: Dictionary = {}
## 드래프트에서 고른 증강의 추가 정보 (진화·보호막을 받을 말 pawn_id, 자동 선택 여부). 모두 고른 뒤 한꺼번에 적용한다.
var _draft_pick_params: Dictionary = {}
## 이번 턴에 이미 굴리기 전 카드를 한 장 냈는가. 카드는 굴리기 전 턴당 1장만 쓸 수 있다 (피해를 되돌리는 ACT_05만 예외).
var _card_played_this_turn: bool = false
## 이번 드래프트에서 플레이어별로 이미 리롤한 슬롯 인덱스 (슬롯당 1회).
var _draft_rerolls: Dictionary = {}
## 진행 중인 이동의 보고서와 마지막 걸음 결과 (execute_step_by_step_move가 채운다).
var _move_report: MoveReport = null
## 이번 이동의 눈금에 들어 있는 템포 업 보너스 (카이지의 한방 역전법 판정에서 뺀다).
var _move_tempo_bonus: int = 0
## AI 대전의 사람 자리: 이 사람들이 모두 졸업하면 남은 컴퓨터는 레이스 진행 순서로 순위를 매기고 판을 바로 끝낸다 (비어 있으면 끝까지 진행, 온라인·4인 수동).
var end_when_graduated: Array[int] = []
## 히든 페이싱 디렉터가 사람으로 보는 자리 (AI 대전의 내 자리). 굴림·드래프트 직전에 state.pacing_humans로 넘긴다.
var pacing_humans: Array[int] = []
var _move_outcome: MoveExecutor.StepOutcome = MoveExecutor.StepOutcome.CONTINUE



## 화면 문구 (content_trickcal/data/ui_strings.csv). TurnManager는 문구 대신 이벤트 데이터를 방송하므로(화면이 문구를 만든다) 엔진에서 문구가 꼭 필요할 때만 쓴다.
static func tr_ui(key: String, args: Array = []) -> String:
	return L10n.tr_ui(key, args)

func _process(delta: float) -> void:
	if state != null and _is_authority():
		# 제한 시간은 실제 초로 센다: 배속(Engine.time_scale)을 올려도 사람이 생각할 시간은 줄지 않는다.
		tick(delta / maxf(Engine.time_scale, 0.01))


## 규칙을 실행할 권한이 있는가: 방장(서버)이거나 락스텝 참가자.
func _is_authority() -> bool:
	return lockstep or multiplayer.is_server()


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
	if not _is_authority():
		return
	state = GameState.new()
	state.boost_gimmicks = boost_gimmicks
	state.match_rules = MatchRules.sanitize(match_rules)
	state.setup(player_ids, seed_value, loadouts)
	state.turn_order_reverse_requested.connect(reverse_turn_order)
	state.bang_resolved.connect(_on_bang_resolved)
	state.duel_requested.connect(_on_duel_requested)
	_duel = {}
	_counter_offer = {}
	state.bomb_resolved.connect(_on_bomb_resolved)
	state.pawn_pushed_back.connect(func(pawn_id: int, from_tile: int, to_tile: int) -> void: _emit_event(&"pawn_pushed_back", {"pawn_id": pawn_id, "from": from_tile, "to": to_tile}))
	_ensure_command_stack()
	command_stack.begin_turn()
	player_order = player_ids.duplicate()
	current_turn_index = 0
	turn_direction = 1
	state.turn_direction = 1
	is_game_over = false
	_sync_current_player()
	augments.clear()
	for player_id: int in player_ids:
		augments[player_id] = [] as Array[StringName]
	move_queue.clear()
	_round_done.clear()
	_extra_turn_pending = false
	_bonus_roll_pending = false
	_enter_round_start()


## 로컬에서 행동을 보낸다. 서버면 직접 처리하고, 클라이언트면 호스트(피어 1)로 RPC를 보낸다.
func act(action: StringName, params: Dictionary = {}) -> void:
	if action_interceptor.is_valid():
		action_interceptor.call(action, params)
		return
	if multiplayer.is_server():
		request_action(action, params)
	else:
		request_action.rpc_id(1, action, params)


## 모든 플레이어 행동의 단일 입구. 서버만 실행하며 발신 피어로 행동자를 검증한다.
## action: proceed / roll(야추: keep 인자) / stop / select_pawn / play_card / pick_augment / reroll_augment
@rpc("any_peer", "call_local", "reliable")
func request_action(action: StringName, params: Dictionary = {}) -> void:
	if not _is_authority() or state == null:
		return
	processing_started.emit()
	_handle_action(action, params)
	processing_finished.emit()


func _handle_action(action: StringName, params: Dictionary) -> void:
	var actor: int = _resolve_actor(int(params.get("player_id", -1)))
	if actor == -1 or not player_order.has(actor):
		action_rejected.emit(actor, action, &"unknown_player")
		return
	if is_game_over:
		action_rejected.emit(actor, action, &"game_over")
		return
	if not _duel.is_empty() and action != &"duel_pick":
		action_rejected.emit(actor, action, &"duel_pending")
		return
	# 방어 대기 중에는 피해자의 방어 카드 / 넘기기만 받는다.
	if counter_pending() and not (actor == int(_counter_offer["victim"]) and (action == &"counter_pass" or (action == &"play_card" and CardCounter.is_counter(StringName(params.get("card_id", &"")))))):
		action_rejected.emit(actor, action, &"counter_pending")
		return
	match action:
		&"proceed": _handle_proceed(actor)
		&"roll": _handle_roll(actor, params)
		&"stop": _handle_stop(actor)
		&"select_pawn": _handle_select_pawn(actor, params)
		&"play_card": _handle_play_card(actor, params)
		&"pick_augment": _handle_pick_augment(actor, params)
		&"review_done": _handle_review_done(actor)
		&"reroll_augment": _handle_reroll_augment(actor, params)
		&"use_skill": _handle_use_skill(actor, params)
		&"stack_choice": _handle_stack_choice(actor, params)
		&"duel_pick": _handle_duel_pick(actor, params)
		&"counter_pass": _handle_counter_pass(actor)
		_: action_rejected.emit(actor, action, &"unknown_action")


## 턴 진행 방향을 뒤집는다 (우노 리버스 ACT_01).
func reverse_turn_order() -> void:
	turn_direction *= -1
	state.turn_direction = turn_direction
	turn_order_reversed.emit(turn_direction)
	_broadcast_state()


## turn_direction에 따라 다음 플레이어로 인덱스를 순환시켜 새 턴을 시작한다.
## 이번이 라운드의 마지막 턴이었다면 PHASE_NEUTRAL_NPC로 진입한다.
func advance_to_next_player() -> void:
	_extra_turn_pending = false
	_bonus_roll_pending = false
	_counter_offer = {}
	var leaving: int = current_player_id()
	# 특수 승리: 한 차례의 행동(이동·처치·카드·방어)이 다 끝나 차례가 넘어가는 순간 판정한다 (행동 도중에는 기록만 오른다).
	if _judge_special_victory():
		return
	if state != null and int(state.banned_turns.get(leaving, 0)) > 0:
		state.banned_turns[leaving] = int(state.banned_turns[leaving]) - 1  # 알고리즘 밴: 밴 당한 사람의 턴이 끝날 때마다 하나씩 줄어든다
	# ACT_12 더 월드: 이 턴이 끝나면 같은 사람이 한 턴 더 한다.
	if state != null and bool(state.extra_turns.get(leaving, false)) and not state.is_graduated(leaving) and not is_game_over:
		state.extra_turns.erase(leaving)
		_emit_event(&"extra_turn", {"player_id": leaving})
		_begin_turn()
		return
	_round_done[leaving] = true
	if _round_done.size() >= player_order.size():
		_round_done.clear()
		_enter_neutral_npc_phase()
		return
	# 진행 방향으로 돌며 이번 라운드에 아직 차례가 없었던 사람에게 넘긴다 (리버스 뒤에 같은 사람이 두 번 하지 않는다).
	for _i: int in player_order.size():
		_step_turn_index()
		if not _round_done.has(current_player_id()):
			break
	_begin_turn()


## 상태를 전환하고 제한 시간을 설정한 뒤 변경을 방송한다.
func change_state(new_state: State) -> void:
	phase_serial += 1
	current_state = new_state
	match new_state:
		State.PHASE_ROUND_START: phase_time_left = GameEnums.PHASE_TIME_DRAFT * timer_scale
		State.PHASE_TURN_BEGIN: phase_time_left = GameEnums.PHASE_TIME_TURN_BEGIN * timer_scale
		State.PHASE_ROLL_WAIT: phase_time_left = GameEnums.PHASE_TIME_ROLL * timer_scale
		State.PHASE_INTERRUPT_ROLL: phase_time_left = GameEnums.PHASE_TIME_INTERRUPT * timer_scale
		State.PHASE_SELECT_PAWN: phase_time_left = GameEnums.PHASE_TIME_SELECT * timer_scale
		State.PHASE_RESOLUTION: phase_time_left = GameEnums.PHASE_TIME_RESOLUTION * timer_scale
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
		if external_timeouts:
			timeout_due.emit(phase_serial)
		else:
			_on_timeout()


## 로컬/핫시트에서 남은 대기 시간을 건너뛴다 (개입 창 닫기 등). 이동 연출 중에는 동작하지 않는다.
func force_timeout() -> void:
	if action_interceptor.is_valid():
		if state != null and not is_game_over:
			action_interceptor.call(ACTION_TIMEOUT, {"serial": phase_serial})
		return
	if state == null or is_game_over or current_state == State.PHASE_MOVING_STEP or phase_time_left <= 0.0:
		return
	phase_time_left = 0.0
	processing_started.emit()
	_on_timeout()
	processing_finished.emit()


## 이 상태에 제한 시간이 있는가 (없는 상태는 타임아웃 행동을 무시한다).
func phase_has_timer(phase: State) -> bool:
	match phase:
		State.PHASE_ROUND_START, State.PHASE_TURN_BEGIN, State.PHASE_ROLL_WAIT, State.PHASE_INTERRUPT_ROLL, State.PHASE_SELECT_PAWN, State.PHASE_RESOLUTION:
			return true
	return false


## 락스텝: 방장이 정한 순서로 모든 참가자에게 똑같이 적용되는 행동 하나. 사람 확인은 방장이 끝냈다.
## 일반 행동은 request_action과 같고, ACTION_TIMEOUT(serial이 같을 때만)과 ACTION_AUTO_DRAFT가 추가로 있다.
func apply_replicated(action: StringName, params: Dictionary) -> void:
	if state == null:
		return
	match action:
		ACTION_TIMEOUT:
			if is_game_over or int(params.get("serial", -1)) != phase_serial or current_state == State.PHASE_MOVING_STEP or not phase_has_timer(current_state):
				action_rejected.emit(-1, action, &"stale_timeout")
				return
			phase_time_left = 0.0
			processing_started.emit()
			_on_timeout()
			processing_finished.emit()
		ACTION_AUTO_DRAFT:
			auto_pick_draft_now(int(params.get("player_id", -1)))
		_:
			request_action(action, params)


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
	# 장거리 이동(부스터·후반 가속)도 한 번에 MOVE_TIME_CAP초 안에 끝난다: 칸당 시간을 칸 수로 나눠 줄인다.
	current_step_seconds = minf(step_delay_sec, MOVE_TIME_CAP / float(maxi(path.size(), 1)))
	if path.size() >= LONG_MOVE_TILES:
		current_step_seconds = minf(current_step_seconds, LONG_MOVE_STEP_SECONDS)
	for index: int in path.size():
		var is_last: bool = index == path.size() - 1
		processing_started.emit()  # 걸음마다 화면 갱신을 한 번으로 묶는다 (걸음은 await 사이에 따로 일어난다)
		_move_outcome = MoveExecutor.apply_step(state, pawn, ctx, path[index], is_last, index == 0, _move_report)
		processing_finished.emit()
		if _move_outcome != MoveExecutor.StepOutcome.CONTINUE:
			break
		if not is_last and current_step_seconds > 0.0 and is_inside_tree():
			await get_tree().create_timer(current_step_seconds).timeout


# ---------------------------------------------------------------------------
# 행동 처리
# ---------------------------------------------------------------------------

func _resolve_actor(claimed_player: int) -> int:
	if lockstep:
		return claimed_player  # 방장이 이미 보낸 사람을 확인했다
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


func _handle_roll(actor: int, params: Dictionary = {}) -> void:
	if current_state != State.PHASE_ROLL_WAIT or actor != current_player_id():
		action_rejected.emit(actor, &"roll", &"wrong_phase")
		return
	var tool: BaseJudgmentTool = state.tools[actor]
	# 야추 다이스: 다시 굴릴 때 고정할 주사위(keep: 5개 bool)를 굴림 행동에 실어 보낸다.
	if params.has("keep") and tool is ToolYacht:
		(tool as ToolYacht).set_keep(params["keep"] as Array if params["keep"] is Array else [])
	state.pacing_humans = pacing_humans
	_apply_roll_result(_roll_with_modifiers(actor, tool))


func _handle_stop(actor: int) -> void:
	if current_state != State.PHASE_ROLL_WAIT or actor != current_player_id():
		action_rejected.emit(actor, &"stop", &"wrong_phase")
		return
	var result: RollResult = (state.tools[actor] as BaseJudgmentTool).cash_out()
	if result == null:
		action_rejected.emit(actor, &"stop", &"nothing_to_cash_out")
		return
	_apply_roll_result(result)


func _handle_select_pawn(actor: int, params: Dictionary) -> void:
	if current_state != State.PHASE_SELECT_PAWN or actor != current_player_id():
		action_rejected.emit(actor, &"select_pawn", &"wrong_phase")
		return
	var pawn: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
	if pawn == null or pawn.owner_id != actor or not state.can_pick(pawn, _queued_dice()):
		action_rejected.emit(actor, &"select_pawn", &"invalid_pawn")
		return
	_execute_move(pawn)


func _handle_play_card(actor: int, params: Dictionary) -> void:
	var card_id: StringName = StringName(params.get("card_id", &""))
	var card: BaseCard = CardRegistry.get_card(card_id)
	if card != null and state.is_banned(actor):
		action_rejected.emit(actor, &"play_card", &"banned")
		return
	if card is CardCounter:
		_play_counter(actor, card, params)
		return
	if card == null or not card.is_playable_in(current_state):
		action_rejected.emit(actor, &"play_card", &"not_playable_now")
		return
	if current_state == State.PHASE_TURN_BEGIN and actor != current_player_id():
		action_rejected.emit(actor, &"play_card", &"not_your_turn")
		return
	if not state.has_card(actor, card_id):
		action_rejected.emit(actor, &"play_card", &"card_not_in_hand")
		return
	if current_state == State.PHASE_TURN_BEGIN and _card_played_this_turn:
		action_rejected.emit(actor, &"play_card", &"card_limit")
		return
	if not card.is_legal(state, actor, params):
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	var command: GameCommand = card.create_command(state, actor, params)
	var ctx: RuleContext = _make_ctx(actor)
	var accepted: bool
	var queued: bool = current_state != State.PHASE_TURN_BEGIN
	# 화면이 [카드 알림 -> 효과] 순서로 보여 줄 수 있도록 효과가 일어나기 전에 알린다 (바로 실행하는 카드는 실행 가능할 때만).
	command.bind_state(ctx.state)
	if not queued and command.can_execute(ctx):
		_emit_event(&"card_played", {"player_id": actor, "card_id": card_id, "params": params, "queued": queued})
		state.begin_attack({"kind": &"card", "card_id": card_id, "attacker": actor})  # 이 카드로 입힌 피해는 방어 대상
		accepted = command_stack.execute_command(command, ctx)
		state.end_attack()
		if not accepted:
			action_rejected.emit(actor, &"play_card", &"invalid_target")
			return
		state.consume_card(actor, card_id)
		_card_played_this_turn = true
		if _check_victory(null):
			return
		if _open_counter_offer(&"turn_begin"):
			return
		_broadcast_state()
		return
	if queued:
		accepted = command_stack.push_interrupt(command, ctx)
	else:
		accepted = command_stack.execute_command(command, ctx)
	if not accepted:
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	state.consume_card(actor, card_id)
	if not queued:
		_card_played_this_turn = true
	_emit_event(&"card_played", {"player_id": actor, "card_id": card_id, "params": params, "queued": queued})
	if not queued:
		_check_victory(null)
	_broadcast_state()


## 1회용 필살기를 지금 쓸 수 있는가: 내 턴의 TURN_BEGIN/ROLL_WAIT, 쌓인 굴림·진행 중인 판정 도구가 없고, 기물이 필살기 조건(PawnSkills.is_ready)을 만족한다.
func can_use_skill(player_id: int, pawn_id: int) -> bool:
	if state == null or is_game_over or duel_pending() or player_id != current_player_id():
		return false
	if current_state != State.PHASE_TURN_BEGIN and current_state != State.PHASE_ROLL_WAIT:
		return false
	if not move_queue.is_empty() or stack_offer_pending() or (state.tools[player_id] as BaseJudgmentTool).has_pending_state():
		return false
	if state.is_banned(player_id):
		return false  # 알고리즘 밴
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn == null or pawn.owner_id != player_id or not PawnSkills.is_ready(pawn):
		return false
	if PawnCatalog.skill_of(pawn.sub_type()) == &"plant_mine" and state.board.get_tile(pawn.current_tile_idx).has_trap():
		return false  # 한 칸에 함정은 하나만
	return true


## 필살기 사용. params: {"pawn_id": int} + 기물별 인자 - 룩 {"partner": 맞바꿀 아군 ID} / 비행기 {"tile": 목적지} / 흑돌 {"angle": 라디안, "power": 0~1} / 차 (없음) / 쇼기 보병 {"partner": 낙하시킬 대기 말 ID}.
func _handle_use_skill(actor: int, params: Dictionary) -> void:
	var pawn_id: int = int(params.get("pawn_id", -1))
	if not can_use_skill(actor, pawn_id):
		action_rejected.emit(actor, &"use_skill", &"wrong_phase")
		return
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	var skill: StringName = PawnCatalog.skill_of(pawn.sub_type())
	match skill:
		&"castle": _skill_castle(actor, pawn, params)
		&"drop": _skill_drop(actor, pawn, params)
		&"charge":
			var path: Array[int] = PawnSkills.chariot_path(state, pawn)
			if path.is_empty():
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")
				return
			_emit_skill_event(actor, pawn, skill, {"path": path})
			_execute_move(pawn, path)
		&"warp":
			var tile: int = int(params.get("tile", -1))
			if not PawnSkills.plane_targets(pawn).has(tile):
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")
				return
			_emit_skill_event(actor, pawn, skill, {"from": pawn.current_tile_idx, "tile": tile})
			_execute_instant_skill(pawn, skill, params)
		&"shoot":
			var angle: float = float(params.get("angle", NAN))
			var power: float = float(params.get("power", NAN))
			if is_nan(angle) or is_nan(power):
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")
				return
			var shot: Dictionary = PawnSkills.shot_result(state, pawn, angle, clampf(power, 0.0, 1.0))
			var victims: Array[Dictionary] = []
			for hit_id: int in shot["hits"]:
				victims.append({"pawn_id": hit_id, "from": state.get_pawn(hit_id).current_tile_idx})
			_emit_skill_event(actor, pawn, skill, {"from": pawn.current_tile_idx, "landing": shot["landing"], "angle": angle, "power": clampf(power, 0.0, 1.0), "hits": victims})
			_execute_instant_skill(pawn, skill, params)
		&"fianchetto":
			var corner: int = PawnSkills.fianchetto_tile(pawn)
			if corner == -1:
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")
				return
			_emit_skill_event(actor, pawn, skill, {"from": pawn.current_tile_idx, "tile": corner})
			_execute_instant_skill(pawn, skill, {"tile": corner})
		&"bank_shot":
			var shot_path: Array[int] = PawnSkills.bank_shot_path(state, pawn)
			if shot_path.is_empty():
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")
				return
			_emit_skill_event(actor, pawn, skill, {"path": shot_path})
			_execute_move(pawn, shot_path)
		&"plant_mine":
			if state.board.get_tile(pawn.current_tile_idx).has_trap():
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")  # 한 칸에 함정은 하나만
				return
			_skill_effect(actor, pawn, skill)
		&"hotel":
			_skill_effect(actor, pawn, skill)
		&"extra_roll":
			# 윷말 한 번 더!: 이번 차례의 이동이 끝나면 같은 사람이 한 번 더 굴린다 (추가 굴림과 같은 흐름)
			if _bonus_roll_pending:
				action_rejected.emit(actor, &"use_skill", &"invalid_skill")
				return
			pawn.skill_used = true
			_bonus_roll_pending = true
			_emit_skill_event(actor, pawn, skill, {"from": pawn.current_tile_idx})
			_broadcast_state()
		&"quake", &"slash", &"horse":
			_skill_effect(actor, pawn, skill)
		_:
			action_rejected.emit(actor, &"use_skill", &"invalid_skill")


func _emit_skill_event(actor: int, pawn: PlayerPawn, skill: StringName, detail: Dictionary) -> void:
	var data: Dictionary = detail.duplicate()
	data["player_id"] = actor
	data["pawn_id"] = pawn.entity_id
	data["skill"] = skill
	_emit_event(&"skill_used", data)


## 룩 단독 캐슬링: 주사위 굴림은 그대로 남고, 룩과 아군 한 기물의 위치만 맞바꾼다.
func _skill_castle(actor: int, rook: PlayerPawn, params: Dictionary) -> void:
	var partners: Array[PlayerPawn] = PawnSkills.rook_partners(state, rook)
	var partner: PlayerPawn = state.get_pawn(int(params.get("partner", -1)))
	if partner == null and partners.size() == 1:
		partner = partners[0]
	if partner == null or not partners.has(partner):
		action_rejected.emit(actor, &"use_skill", &"invalid_skill")
		return
	var command := CastleCommand.new(actor, rook.entity_id, partner.entity_id)
	if not command_stack.execute_command(command, _make_ctx(actor)):
		action_rejected.emit(actor, &"use_skill", &"invalid_skill")
		return
	_emit_skill_event(actor, rook, &"castle", {"partner": partner.entity_id})
	_broadcast_state()


## 굴림은 그대로 두는 즉시 필살기: 코끼리 지진 / 용왕 베기 / 용마 십자 베기 / 지뢰 매설.
func _skill_effect(actor: int, pawn: PlayerPawn, skill: StringName) -> void:
	var tiles: Array[int] = []
	match skill:
		&"quake": tiles = PawnSkills.quake_tiles(pawn)
		&"slash", &"horse": tiles = PawnSkills.strike_tiles(pawn, skill)
		&"plant_mine", &"hotel": tiles = [pawn.current_tile_idx] as Array[int]
	var from_tile: int = pawn.current_tile_idx
	var command := SkillEffectCommand.new(actor, pawn.entity_id, skill, tiles)
	state.begin_attack({"kind": &"capture", "attacker": actor, "attacker_pawn": pawn.entity_id})
	var accepted: bool = command_stack.execute_command(command, _make_ctx(actor))
	state.end_attack()
	if not accepted:
		action_rejected.emit(actor, &"use_skill", &"invalid_skill")
		return
	_emit_skill_event(actor, pawn, skill, {"from": from_tile, "tiles": tiles, "destroyed": command.destroyed, "victims": command.victims})
	if _check_victory(null):
		return
	if _open_counter_offer(&"turn_begin"):
		return
	_broadcast_state()


## 쇼기 보병 모치고마 낙하: 주사위 굴림은 그대로 남고, 출발선 대기 말 하나가 보병 곁에 즉시 놓인다.
func _skill_drop(actor: int, fu: PlayerPawn, params: Dictionary) -> void:
	var partners: Array[PlayerPawn] = PawnSkills.drop_partners(state, fu)
	var partner: PlayerPawn = state.get_pawn(int(params.get("partner", -1)))
	if partner == null and not partners.is_empty():
		partner = partners[0]
	if partner == null or not partners.has(partner):
		action_rejected.emit(actor, &"use_skill", &"invalid_skill")
		return
	var command := DropCommand.new(actor, fu.entity_id, partner.entity_id)
	if not command_stack.execute_command(command, _make_ctx(actor)):
		action_rejected.emit(actor, &"use_skill", &"invalid_skill")
		return
	_emit_skill_event(actor, fu, &"drop", {"partner": partner.entity_id, "tile": command.landing_tile})
	_check_victory(null)
	_broadcast_state()


## 주사위를 대신하는 순간 필살기(비행기 워프·흑돌 알까기): 효과를 처리하고 일반 이동처럼 정산 단계로 넘어간다.
func _execute_instant_skill(pawn: PlayerPawn, skill: StringName, params: Dictionary) -> void:
	change_state(State.PHASE_MOVING_STEP)
	var ctx: RuleContext = _make_ctx(current_player_id())
	ctx.defer_stack_choice = stack_choice_enabled
	ctx.pawn = pawn
	var record := GameCommand.new()
	record.command_name = "Skill"
	record.sender_id = current_player_id()
	record.bind_state(state)
	record.capture_before()
	command_stack.record(record)
	pawn.skill_used = true
	var report := MoveReport.new()
	report.pawn_id = pawn.entity_id
	var destination: int = pawn.current_tile_idx
	if skill == &"warp" or skill == &"fianchetto":
		destination = int(params["tile"])
	else:
		var shot: Dictionary = PawnSkills.shot_result(state, pawn, float(params["angle"]), clampf(float(params["power"]), 0.0, 1.0))
		destination = int(shot["landing"])
		var victims: Array[PlayerPawn] = []
		for hit_id: int in shot["hits"]:
			var victim: PlayerPawn = state.get_pawn(hit_id)
			if victim != null and victim.carrier == null and not victim.is_finished:
				victims.append(victim)
		state.begin_attack({"kind": &"capture", "attacker": pawn.owner_id, "attacker_pawn": pawn.entity_id})
		for victim: PlayerPawn in victims:
			for member: PlayerPawn in victim.stack_members():
				report.captured_pawn_ids.append(member.entity_id)
			state.pawn_captured.emit(pawn.entity_id, victim.entity_id)
			state.send_to_start(victim, pawn.owner_id)
		state.end_attack()
	MoveExecutor.teleport_to(state, pawn, ctx, report, destination)
	_extra_turn_pending = _extra_turn_pending or report.extra_turn
	_emit_event(&"move_resolved", report.to_dict())
	if _check_victory(report):
		return
	_stack_offer = report.stack_offer
	_enter_resolution()


func _on_bomb_resolved(shooter: int, victim: int, pawn_id: int, from_tile: int, to_tile: int) -> void:
	_emit_event(&"bomb_applied", {"shooter": shooter, "victim": victim, "pawn_id": pawn_id, "from": from_tile, "to": to_tile})


func _on_bang_resolved(shooter: int, target_pawn_id: int, from_tile: int, to_tile: int) -> void:
	_emit_event(&"bang_resolved", {"shooter": shooter, "target": target_pawn_id, "from": from_tile, "to": to_tile})


## 윷놀이 기물의 [선택적 업기]에 대한 플레이어의 답. params: {"stack": bool} (기본 true = 업기).
func _handle_stack_choice(actor: int, params: Dictionary) -> void:
	if not stack_offer_pending() or actor != current_player_id():
		action_rejected.emit(actor, &"stack_choice", &"wrong_phase")
		return
	_resolve_stack_choice(bool(params.get("stack", true)))


# ---------------------------------------------------------------------------
# ACT_09 운명의 가위바위보 결투
# ---------------------------------------------------------------------------

## 결투가 진행 중인가 (손 고르기 또는 이긴 사람이 말을 고르는 중). 이동·굴리기·카드 같은 다른 행동은 모두 잠긴다.
func counter_pending() -> bool:
	return not _counter_offer.is_empty()


func pending_counter() -> Dictionary:
	return _counter_offer


## 이 플레이어가 이 공격에 낼 수 있는 방어 카드들 (손패 순서, 중복 없이).
func counter_cards_for(player_id: int, attack_id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var entry: Dictionary = state.get_attack(attack_id)
	if entry.is_empty() or state.is_banned(player_id):
		return result
	for card_id: StringName in state.hands[player_id]:
		if not result.has(card_id) and CardCounter.answers(state, card_id, entry):
			result.append(card_id)
	return result


## 아직 묻지 않은 공격 중 피해자가 방어 카드를 쥔 것이 있으면 진행을 멈추고 방어 여부를 묻는다. 물었으면 true.
func _open_counter_offer(resume: StringName) -> bool:
	if is_game_over or state == null:
		return false
	state.discard_empty_attacks()
	for entry: Dictionary in state.attack_log:
		if bool(entry["offered"]) or bool(entry["countered"]):
			continue
		entry["offered"] = true
		var victim: int = int(entry["victim"])
		if state.is_graduated(victim):
			continue
		var cards: Array[StringName] = counter_cards_for(victim, int(entry["id"]))
		if cards.is_empty():
			continue
		_counter_offer = {"victim": victim, "attack": int(entry["id"]), "resume": resume, "cards": cards}
		phase_time_left = GameEnums.PHASE_TIME_SELECT * timer_scale
		_emit_event(&"counter_offer", {"victim": victim, "attacker": int(entry.get("attacker", -1)), "attack": int(entry["id"]), "kind": entry["kind"],
			"card_id": entry.get("card_id", &""), "trap_id": entry.get("trap_id", ""), "pawns": (entry["pawns"] as Dictionary).keys(), "cards": cards})
		_broadcast_state()
		return true
	return false


func _handle_counter_pass(actor: int) -> void:
	if not counter_pending() or actor != int(_counter_offer["victim"]):
		action_rejected.emit(actor, &"counter_pass", &"wrong_phase")
		return
	_emit_event(&"counter_passed", {"victim": actor, "attack": int(_counter_offer["attack"])})
	_finish_counter_offer()


## 방어 카드는 내가 공격받았을 때 열리는 방어 대기(피격 팝업) 동안에만, 그 공격에 대해서만 낸다. 즉시 실행된다.
## 손패에서 아무 때나 끌어 쓰거나 지난 공격에 소급해 낼 수는 없다.
func _play_counter(actor: int, card: BaseCard, params: Dictionary) -> void:
	if not counter_pending() or actor != int(_counter_offer["victim"]):
		action_rejected.emit(actor, &"play_card", &"counter_only_when_attacked")
		return
	var payload: Dictionary = params.duplicate()
	payload["attack"] = int(_counter_offer["attack"])
	if not state.has_card(actor, card.card_id):
		action_rejected.emit(actor, &"play_card", &"card_not_in_hand")
		return
	if not card.is_legal(state, actor, payload):
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	var entry: Dictionary = state.get_attack(int(payload["attack"]))
	_emit_event(&"card_played", {"player_id": actor, "card_id": card.card_id, "params": payload, "queued": false, "counter": true,
		"attacker": int(entry.get("attacker", -1)), "attacker_pawn": int(entry.get("attacker_pawn", -1)), "pawns": (entry["pawns"] as Dictionary).keys()})
	var command: GameCommand = card.create_command(state, actor, payload)
	if not command_stack.execute_command(command, _make_ctx(actor)):
		action_rejected.emit(actor, &"play_card", &"invalid_target")
		return
	state.consume_card(actor, card.card_id)
	if not entry.is_empty():
		entry["countered"] = true
	_emit_event(&"counter_resolved", {"victim": actor, "card_id": card.card_id, "attack": int(payload["attack"])})
	if counter_pending() and int(_counter_offer["attack"]) == int(payload["attack"]):
		_finish_counter_offer()
	else:
		_check_victory(null)
		_broadcast_state()


## 방어 대기를 닫고 멈췄던 흐름을 잇는다. 바이츠 더 더스트로 되감았다면 공격한 사람의 턴이 바로 끝난다.
func _finish_counter_offer() -> void:
	var resume: StringName = _counter_offer.get("resume", &"resolution")
	_counter_offer = {}
	if state.rollback_requested:
		state.rollback_requested = false
		var ends_turn: bool = state.rollback_ends_turn
		state.rollback_ends_turn = false
		move_queue.clear()
		_stack_offer = {}
		_extra_turn_pending = false
		_bonus_roll_pending = false
		if ends_turn:
			_emit_event(&"turn_rewound", {"player_id": current_player_id()})
			advance_to_next_player()
			return
		_begin_turn(false)
		return
	if _check_victory(null):
		return
	if _open_counter_offer(resume):
		return
	if resume == &"turn_begin":
		phase_time_left = GameEnums.PHASE_TIME_TURN_BEGIN * timer_scale
		_broadcast_state()
	else:
		_enter_resolution()


func duel_pending() -> bool:
	return not _duel.is_empty()


## 진행 중인 결투의 사본. 없으면 빈 Dictionary. picks에는 이미 낸 사람의 손이 들어 있지만 UI는 공개 전까지 보여 주면 안 된다.
func pending_duel() -> Dictionary:
	return _duel.duplicate(true)


func _on_duel_requested(challenger: int, defender: int) -> void:
	var game: int = duel_game_override if duel_game_override >= 0 else state.rng.randi_range(0, DuelRules.GAME_COUNT - 1)
	var setup: Dictionary = DuelRules.setup_game(game, state.rng)
	_duel = {"challenger": challenger, "defender": defender, "game": game, "setup": setup, "step": &"pick", "picks": {}, "draws": 0, "winner": -1, "loser": -1, "turn": challenger, "opened": []}
	_duel_set_timer(DuelRules.time_limit(game))
	_emit_event(&"duel_started", {"challenger": challenger, "defender": defender, "game": game, "setup": setup.duplicate(true)})


## 결투 단계가 바뀔 때마다 제한 시간을 새로 걸고 직렬 번호를 올려 지난 시간 초과 신호를 무효화한다.
func _duel_set_timer(seconds: float) -> void:
	phase_serial += 1
	phase_time_left = seconds * timer_scale
	phase_changed.emit(current_state, current_player_id(), phase_time_left)
	_broadcast_state()


## params: {"value": int} (옛 형식 {"hand": int}도 받는다). 결투 당사자만, 한 판에 한 번.
## 값: 손 0~2 / E카드 0~1 / 순발력 ms(-1 안 누름) / 컬링 BottleCapPhysics.encode(세기, 방향), 0~1150 직선 입력도 호환 / 스피키 룰렛 구멍 번호.
func _handle_duel_pick(actor: int, params: Dictionary) -> void:
	var value: int = int(params.get("value", params.get("hand", -999)))
	if _duel.is_empty() or _duel["step"] != &"pick":
		action_rejected.emit(actor, &"duel_pick", &"wrong_phase")
		return
	if actor != int(_duel["challenger"]) and actor != int(_duel["defender"]):
		action_rejected.emit(actor, &"duel_pick", &"not_your_duel")
		return
	var game: int = int(_duel["game"])
	if not DuelRules.valid_input(game, value, actor == int(_duel["challenger"]), _duel["opened"]):
		action_rejected.emit(actor, &"duel_pick", &"invalid_value")
		return
	if game == DuelRules.Game.ECARD and DuelRules.ecard_count(_duel["setup"], actor == int(_duel["challenger"]), value) <= 0:
		action_rejected.emit(actor, &"duel_pick", &"card_spent")
		return
	if game == DuelRules.Game.BARREL:
		if actor != int(_duel["turn"]):
			action_rejected.emit(actor, &"duel_pick", &"not_your_turn")
			return
		_duel_barrel_pick(actor, value)
		return
	if game == DuelRules.Game.CURLING and actor != int(_duel["turn"]):
		action_rejected.emit(actor, &"duel_pick", &"not_your_turn")
		return
	if (_duel["picks"] as Dictionary).has(actor):
		action_rejected.emit(actor, &"duel_pick", &"already_picked")
		return
	(_duel["picks"] as Dictionary)[actor] = value
	var pick_event := {"player_id": actor}
	if game == DuelRules.Game.CURLING:
		pick_event["value"] = value  # The first cap remains on the shared table.
	_emit_event(&"duel_pick_in", pick_event)
	if (_duel["picks"] as Dictionary).size() == 2:
		_duel_reveal()
	elif game == DuelRules.Game.CURLING:
		_duel["turn"] = int(_duel["defender"])
		_duel_set_timer(DuelRules.TIME_CURLING + 4.0)  # Includes first cap settlement.
	else:
		_broadcast_state()


## 스피키 룰렛: 구멍에 칼을 꽂는다. 폭탄이면 그 사람이 지고, 아니면 상대 차례.
func _duel_barrel_pick(actor: int, hole: int) -> void:
	(_duel["opened"] as Array).append(hole)
	var bomb: bool = hole == int((_duel["setup"] as Dictionary)["bomb"])
	_emit_event(&"duel_pick_in", {"player_id": actor, "hole": hole, "bomb": bomb})
	var challenger: int = int(_duel["challenger"])
	var defender: int = int(_duel["defender"])
	if not bomb:
		_duel["turn"] = defender if actor == challenger else challenger
		_duel_set_timer(DuelRules.TIME_BARREL_PICK)
		return
	var winner: int = defender if actor == challenger else challenger
	var picks: Dictionary = {"opened": (_duel["opened"] as Array).duplicate()}
	_duel_announce(winner, &"bomb", DuelRules.winner_advance(), picks)


## 둘 다 냈다: 승패를 가리고 공개한다. 가위바위보는 같은 손이면 다시 고른다.
func _duel_reveal() -> void:
	var challenger: int = int(_duel["challenger"])
	var defender: int = int(_duel["defender"])
	var game: int = int(_duel["game"])
	var picks: Dictionary = (_duel["picks"] as Dictionary).duplicate()
	var result: Dictionary = DuelRules.resolve(game, _duel["setup"], challenger, defender, picks)
	if game == DuelRules.Game.ECARD:
		DuelRules.ecard_discard(_duel["setup"], true, int(picks[challenger]))
		DuelRules.ecard_discard(_duel["setup"], false, int(picks[defender]))
	var winner: int = int(result["winner"])
	var decided_by: StringName = result["decided_by"]
	if winner == -1:
		_duel["draws"] = int(_duel["draws"]) + 1
	_duel["picks"] = {}
	if winner == -1:
		_emit_event(&"duel_revealed", _duel_reveal_data(-1, &"draw", picks, 0))
		_duel_set_timer(DuelRules.ECARD_PICK_TIME + DuelRules.ECARD_REVEAL_TIME if game == DuelRules.Game.ECARD else DuelRules.TIME_PICK)  # Reveal + new legal hand.
		return
	_duel_announce(winner, decided_by, int(result["advance"]), picks)


func _duel_reveal_data(winner: int, decided_by: StringName, picks: Dictionary, advance: int) -> Dictionary:
	var challenger: int = int(_duel["challenger"])
	var defender: int = int(_duel["defender"])
	var game: int = int(_duel["game"])
	var data := {"challenger": challenger, "defender": defender, "game": game, "picks": picks, "winner": winner, "draws": int(_duel["draws"]), "decided_by": decided_by, "advance": advance,
		"detail": DuelRules.detail_text(game, _duel["setup"], challenger, defender, picks)}
	if game == DuelRules.Game.ECARD:
		data["ecard_hands"] = (_duel["setup"]["hands"] as Array).duplicate(true)
	return data


## 승패가 났다: 공개 이벤트 뒤에 패자의 선두 말을 바로 사출하고 승자의 말을 전진시킨다.
func _duel_announce(winner: int, decided_by: StringName, advance: int, picks: Dictionary) -> void:
	var loser: int = int(_duel["defender"]) if winner == int(_duel["challenger"]) else int(_duel["challenger"])
	_duel["winner"] = winner
	_duel["loser"] = loser
	_emit_event(&"duel_revealed", _duel_reveal_data(winner, decided_by, picks, advance))
	var pawn_id: int = DuelRules.strike_target(state, loser)
	if pawn_id == -1:
		_emit_event(&"duel_resolved", {"winner": winner, "loser": loser, "pawn_id": -1, "advance": advance})
		_duel_finish()
		return
	var result: Dictionary = DuelRules.apply_strike(state, winner, state.get_pawn(pawn_id), advance)
	_emit_event(&"duel_resolved", {"winner": winner, "loser": loser, "pawn_id": pawn_id, "advance": advance, "from": result["from"], "landing": result["landing"], "to": result["to"], "sent_to_start": result["sent_to_start"], "trapped": result["trapped"], "boost_pawn_id": result["boost_pawn_id"], "boost_from": result["boost_from"], "boost_to": result["boost_to"]})
	_duel_finish()


func _duel_finish() -> void:
	_duel = {}
	phase_serial += 1
	phase_time_left = GameEnums.PHASE_TIME_TURN_BEGIN * timer_scale if current_state == State.PHASE_TURN_BEGIN else phase_time_left
	phase_changed.emit(current_state, current_player_id(), phase_time_left)
	_broadcast_state()


## 시간 초과: 아직 안 낸 사람의 값을 채운다 (손·카드 무작위, 순발력 안 누름, 컬링 추락, 스피키 룰렛 무작위 구멍).
func _duel_timeout() -> void:
	var game: int = int(_duel["game"])
	if game == DuelRules.Game.CURLING:
		_handle_duel_pick(int(_duel["turn"]), {"value": DuelRules.timeout_input(game, state.rng)})
		return
	if game == DuelRules.Game.BARREL:
		var seat: int = int(_duel["turn"])
		_duel_barrel_pick(seat, DuelRules.timeout_input(game, state.rng, _duel["opened"]))
		return
	for player_id: int in [int(_duel["challenger"]), int(_duel["defender"])]:
		if not (_duel["picks"] as Dictionary).has(player_id):
			(_duel["picks"] as Dictionary)[player_id] = DuelRules.bot_input(game, _duel["setup"], player_id == int(_duel["challenger"]), state.rng) if game == DuelRules.Game.ECARD else DuelRules.timeout_input(game, state.rng)
			_emit_event(&"duel_pick_in", {"player_id": player_id})
	_duel_reveal()


## 윷놀이 기물의 [선택적 업기] 답을 기다리는 중인가 (PHASE_RESOLUTION 안의 보조 상태).
func stack_offer_pending() -> bool:
	return current_state == State.PHASE_RESOLUTION and not _stack_offer.is_empty()


## 대기 중인 업기 제안의 사본 ({"mover": id, "others": [id...]}). 없으면 빈 Dictionary.
func pending_stack_offer() -> Dictionary:
	return _stack_offer.duplicate(true)


## 업기를 선택하면 제안된 아군 말들을 이동한 말에 합치고, 선택 대기를 끝내 정산 창을 마저 진행한다.
func _resolve_stack_choice(stack: bool) -> void:
	var offer: Dictionary = _stack_offer
	_stack_offer = {}
	var members: Array[int] = []
	if stack and not offer.is_empty():
		var mover: PlayerPawn = state.get_pawn(int(offer["mover"]))
		for other_id: Variant in offer["others"]:
			var other: PlayerPawn = state.get_pawn(int(other_id))
			# 선택을 기다리는 사이 상태가 바뀌었을 수 있으니 합칠 수 있는지 다시 확인한다.
			if mover != null and other != null and other.carrier == null and not other.is_finished and mover.current_tile_idx == other.current_tile_idx and mover.can_stack_with(other):
				state.stack_pawns(mover, other)
		if mover != null:
			for member: PlayerPawn in mover.stack_members():
				members.append(member.entity_id)
	_emit_event(&"stack_resolved", {"player_id": current_player_id(), "stacked": stack and members.size() > 1, "members": members, "offer": offer})
	phase_time_left = GameEnums.PHASE_TIME_RESOLUTION * timer_scale
	if _someone_can_intervene():
		_broadcast_state()
	else:
		_close_resolution_window()


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


## 증강 선택지 한 칸을 같은 드래프트에서 1회에 한해 다른 증강으로 바꾼다.
func _handle_reroll_augment(actor: int, params: Dictionary) -> void:
	if current_state != State.PHASE_ROUND_START or not _draft_offers.has(actor) or _draft_picks.has(actor):
		action_rejected.emit(actor, &"reroll_augment", &"wrong_phase")
		return
	var index: int = int(params.get("index", -1))
	var offers: Array = _draft_offers[actor]
	if index < 0 or index >= offers.size():
		action_rejected.emit(actor, &"reroll_augment", &"invalid_index")
		return
	if draft_reroll_used(actor, index):  # 밴은 증강 리롤을 막지 않는다 (주사위 리롤·카드·필살기만)
		action_rejected.emit(actor, &"reroll_augment", &"reroll_used")
		return
	var replacement: StringName = AugmentRegistry.reroll_candidate(state, actor, offers)
	if replacement == &"":
		action_rejected.emit(actor, &"reroll_augment", &"no_candidate")
		return
	offers[index] = replacement
	if not _draft_rerolls.has(actor):
		_draft_rerolls[actor] = []
	(_draft_rerolls[actor] as Array).append(index)
	_emit_event(&"augment_rerolled", {"player_id": actor, "index": index, "augment_id": replacement})
	_broadcast_state()


func draft_reroll_used(player_id: int, index: int) -> bool:
	return (_draft_rerolls.get(player_id, []) as Array).has(index)


## 로컬/핫시트용: 해당 플레이어의 증강을 무작위로 자동 선택한다 (기물 진화는 가장 앞 슬롯의 기본 말).
func auto_pick_draft(player_id: int) -> void:
	if action_interceptor.is_valid():
		action_interceptor.call(ACTION_AUTO_DRAFT, {"player_id": player_id})
		return
	auto_pick_draft_now(player_id)


func auto_pick_draft_now(player_id: int) -> void:
	if current_state != State.PHASE_ROUND_START or not _draft_offers.has(player_id) or _draft_picks.has(player_id):
		return
	var offers: Array = _draft_offers[player_id]
	var index: int = state.rng.randi_range(0, offers.size() - 1)
	# 고른 증강이 적용되지 않으면(손패 가득 등) 다음 선택지를 차례로 시도해 드래프트가 멈추지 않게 한다.
	for attempt: int in offers.size():
		if _pick_augment(player_id, (index + attempt) % offers.size(), {}, true):
			break
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


## 선택을 기록만 한다 (효과는 모두가 고른 뒤 _resolve_draft가 한꺼번에 적용한다). 지금 받을 수 없는 증강·잘못된 말이면 false.
func _pick_augment(player_id: int, index: int, params: Dictionary, automatic: bool) -> bool:
	var augment_id: StringName = (_draft_offers[player_id] as Array)[index]
	var definition: AugmentDef = AugmentRegistry.get_def(augment_id)
	if definition == null:
		return false
	if params.has("pawn_id"):
		var pawn: PlayerPawn = state.get_pawn(int(params["pawn_id"]))
		if pawn == null or pawn.owner_id != player_id:
			return false
		if definition.category == GameEnums.AugmentCategory.PAWN_EVOLUTION and pawn.kind != GameEnums.PawnKind.BASIC:
			return false  # 기물 진화는 기본 말만 (적용할 때와 같은 규칙)
		if definition.category == GameEnums.AugmentCategory.UTILITY and not definition.can_pick_pawn(state, player_id, pawn):
			return false
	_draft_picks[player_id] = index
	_draft_pick_params[player_id] = {"params": params.duplicate(), "auto": automatic}
	_emit_event(&"augment_locked", {"player_id": player_id, "auto": automatic})
	_broadcast_state()
	return true


## 모두 고른 뒤: 누군가 올 픽션을 골랐으면(라운드당 1회) 모두의 선택을 버리고 새 3장으로 다시 고르게 하고 true.
## 아니면 고른 증강을 플레이 순서대로 적용한다 (먼저 적용된 증강 때문에 적용할 수 없게 되면 그 사람의 다른 선택지를 차례로 시도한다).
func _resolve_draft() -> bool:
	var reshufflers: Array[int] = []
	for player_id: int in player_order:
		if _draft_picks.has(player_id) and (_draft_offers[player_id] as Array)[int(_draft_picks[player_id])] == UtilityAugments.REROLL_ALL_AUG:
			reshufflers.append(player_id)
	if not reshufflers.is_empty() and state.reshuffle_round != state.round_number:
		_reshuffle_draft(reshufflers)
		return true
	for player_id: int in player_order:
		if not _draft_picks.has(player_id):
			continue
		var offers: Array = _draft_offers[player_id]
		var picked: int = int(_draft_picks[player_id])
		var entry: Dictionary = _draft_pick_params.get(player_id, {})
		var order: Array[int] = [picked]
		for index: int in offers.size():
			if index != picked:
				order.append(index)
		for index: int in order:
			var definition: AugmentDef = AugmentRegistry.get_def(offers[index])
			if definition == null or offers[index] == UtilityAugments.REROLL_ALL_AUG:
				continue
			if definition.category == GameEnums.AugmentCategory.LAW_ENACT and (MatchRules.laws_full(state) or state.rulebook.has_law(String(definition.payload))):
				continue  # 앞사람이 법전을 채웠다
			var params: Dictionary = (entry.get("params", {}) as Dictionary) if index == picked else {}
			var result: Dictionary = definition.apply(state, player_id, params)
			if not bool(result["ok"]):
				continue
			(augments[player_id] as Array).append(offers[index])
			_emit_event(&"augment_picked", {"player_id": player_id, "augment_id": offers[index], "text": result["text"], "auto": bool(entry.get("auto", false)) or index != picked})
			break
	return false


## [범용] 올 픽션: 모두의 선택을 버리고 새 3장으로 다시 고르게 한다 (라운드당 1회, 새 선택지에는 올 픽션이 없다).
func _reshuffle_draft(pickers: Array[int]) -> void:
	state.reshuffle_round = state.round_number
	for picker: int in pickers:
		(augments[picker] as Array).append(UtilityAugments.REROLL_ALL_AUG)
		_emit_event(&"augment_picked", {"player_id": picker, "augment_id": UtilityAugments.REROLL_ALL_AUG, "text": "모두가 증강을 다시 고릅니다", "auto": false})
	_draft_picks.clear()
	_draft_pick_params.clear()
	_draft_rerolls.clear()
	state.pacing_humans = pacing_humans
	for player_id: int in player_order:
		if _draft_offers.has(player_id):
			_draft_offers[player_id] = AugmentRegistry.generate_offers(state, player_id)
	phase_serial += 1
	phase_time_left = GameEnums.PHASE_TIME_DRAFT * timer_scale
	_emit_event(&"augment_reshuffled", {"players": pickers, "offers": _draft_offers.duplicate(true)})
	_broadcast_state()


# ---------------------------------------------------------------------------
# 페이즈 진행
# ---------------------------------------------------------------------------

func _on_timeout() -> void:
	if not _duel.is_empty():
		_duel_timeout()
		return
	if counter_pending():
		_finish_counter_offer()
		return
	match current_state:
		State.PHASE_ROUND_START:
			if review_pending():
				_finish_review()
			else:
				_finish_draft()
		State.PHASE_TURN_BEGIN:
			_enter_roll_wait()
		State.PHASE_ROLL_WAIT:
			var tool: BaseJudgmentTool = state.tools[current_player_id()]
			if tool.has_pending_state():
				_apply_roll_result(tool.cash_out())
			else:
				state.pacing_humans = pacing_humans
				_apply_roll_result(_roll_with_modifiers(current_player_id(), tool))
		State.PHASE_INTERRUPT_ROLL:
			_close_interrupt_window()
		State.PHASE_SELECT_PAWN:
			_auto_select_pawn()
		State.PHASE_RESOLUTION:
			if stack_offer_pending():
				_resolve_stack_choice(true)
			else:
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
	_draft_pick_params.clear()
	_draft_rerolls.clear()
	change_state(State.PHASE_ROUND_START)
	if _apply_tempo_up():
		return
	if GameEnums.is_draft_round(state.round_number) and state.round_number > 1:
		state.recharge_shields()  # 바둑 백돌: 증강 라운드마다 방어막 재충전
	if draft_enabled and GameEnums.is_draft_round(state.round_number):
		for player_id: int in player_order:
			if not state.is_graduated(player_id):  # 졸업한 플레이어는 드래프트에서 빠진다
				state.pacing_humans = pacing_humans
				_draft_offers[player_id] = AugmentRegistry.generate_offers(state, player_id)
		_emit_event(&"augment_offers", {"round": state.round_number, "offers": _draft_offers.duplicate(true)})
	else:
		_begin_turn()


## 템포 업: 단계가 오르는 라운드(TempoUp.STAGE_ROUNDS, 7·14·20)는 라운드를 선언하기 전에 경고 이벤트를 먼저 보낸다.
## 3단계(20R)부터는 라운드마다 결승선이 당겨져 그 안에 선 말이 바로 완주한다 (법전 자동 등록은 없다, 2026-10-26).
## 완주로 게임이 끝났으면 true.
func _apply_tempo_up() -> bool:
	var round_number: int = state.round_number
	# 히든 페이싱: 20라운드가 끝나도 남은 사람은 진행 순위로 확정하고 판을 끝낸다 (싱글 불닭 난이도만, 맨 뒤 한 명은 꼴찌).
	if PacingDirector.enabled(state) and round_number > PacingDirector.HARD_CAP_ROUND and not is_game_over:
		var order: Array = VictoryChecker.sort_by_race(state, state.active_players(player_order))
		if not order.is_empty():
			_emit_event(&"race_ranked", {"players": order, "round_cap": true})
			for index: int in order.size():
				_graduate(order[index], VictoryChecker.LAST_PLACE if index == order.size() - 1 else VictoryChecker.RACE_ORDER)
			_end_game()
			return true
	if TempoUp.is_stage_round(round_number):
		var stage: int = TempoUp.level(round_number)
		var lines: Array[String] = TempoUp.effect_lines(stage)
		if not bool(state.match_rules.get("laws", true)):
			lines = lines.filter(func(line: String) -> bool: return not line.contains("법전"))  # 법전 끄기: 법전 관련 효과는 없다
		_emit_event(&"tempo_up", {"round": round_number, "level": stage, "lines": lines})

	var zone_start: int = TempoUp.zone_start_for(state)
	if zone_start < 0:
		return false
	var finished: Array[int] = []
	for pawn: PlayerPawn in state.get_active_pawns():
		if pawn.carrier == null and pawn.has_left_start and not pawn.is_finished and pawn.can_finish(state) and TempoUp.in_zone_for(state, pawn.current_tile_idx):
			for member: PlayerPawn in pawn.stack_members():
				finished.append(member.entity_id)
			state.finish_stack(pawn)
	if TempoUp.goal_shrink(round_number) > 0 or not finished.is_empty():  # 범용 단축만 있을 때는 라운드마다 알리지 않는다
		_emit_event(&"goal_shrunk", {"round": round_number, "zone_start": zone_start, "shrink": TempoUp.shrink_for(state), "finished": finished})
	if finished.is_empty():
		return false
	for entry: Dictionary in VictoryChecker.newly_qualified(state, player_order, current_player_id(), false):
		_graduate(int(entry["player"]), entry["reason"])
	return _end_if_decided()


## 시간 초과 등으로 드래프트를 마감한다. 아직 고르지 않은 플레이어는 첫 번째 선택지로 자동 선택된다.
func _finish_draft() -> void:
	for player_id: int in player_order:
		if _draft_offers.has(player_id) and not _draft_picks.has(player_id):
			for index: int in (_draft_offers[player_id] as Array).size():
				if _pick_augment(player_id, index, {}, true):
					break
	if _resolve_draft():
		return  # 올 픽션: 모두 다시 고른다
	var participants: Array[int] = []
	for player_id: int in player_order:
		if _draft_offers.has(player_id):
			participants.append(player_id)
	_draft_offers.clear()
	_draft_picks.clear()
	_draft_pick_params.clear()
	_draft_rerolls.clear()
	if review_enabled and not participants.is_empty():
		_start_review(participants)
		return
	_begin_turn()


## 증강 확인 단계: 고른 증강을 모두가 확인할 때까지(또는 시간이 다 될 때까지) 라운드를 시작하지 않는다.
func _start_review(players: Array[int]) -> void:
	_review_pending = players.duplicate()
	phase_serial += 1  # 드래프트 시간 초과와 확인 시간 초과가 섞이지 않게 새 결정 지점으로 센다
	phase_time_left = GameEnums.PHASE_TIME_REVIEW * timer_scale
	_emit_event(&"augment_review", {"round": state.round_number, "players": _review_pending.duplicate()})
	_broadcast_state()


func review_pending() -> bool:
	return not _review_pending.is_empty()


## 아직 증강 확인을 누르지 않은 플레이어.
func review_waiting_for() -> Array[int]:
	return _review_pending.duplicate()


func _handle_review_done(actor: int) -> void:
	if current_state != State.PHASE_ROUND_START or not _review_pending.has(actor):
		action_rejected.emit(actor, &"review_done", &"wrong_phase")
		return
	_review_pending.erase(actor)
	_emit_event(&"augment_review_done", {"player_id": actor, "waiting": _review_pending.duplicate()})
	if _review_pending.is_empty():
		_finish_review()
	else:
		_broadcast_state()


func _finish_review() -> void:
	_review_pending.clear()
	_begin_turn()


## new_turn: 새 플레이어의 턴이면 true (구속 카운터를 줄인다). 추가 턴·롤백 재시작은 false.
func _begin_turn(new_turn: bool = true) -> void:
	if new_turn:
		_card_played_this_turn = false
	state.hurt_players.clear()
	state.roll_bonus = 0
	state.rollback_requested = false
	move_queue.clear()
	_stack_offer = {}
	command_stack.begin_turn()
	_roll_chain = 0
	_move_report = null
	if new_turn:
		state.attack_log.clear()
	_sync_current_player()
	# 이미 순위가 확정되어 졸업한 플레이어는 턴을 건너뛴다.
	if state.is_graduated(current_player_id()) and not is_game_over:
		advance_to_next_player()
		return
	# [초증강] 판 뒤집기 실패: 이번 턴은 쉰다 (바로 다음 사람 차례). 쉬는 턴에도 내 설치물의 남은 턴은 줄어든다.
	if new_turn and bool(state.rest_next_turn.get(current_player_id(), false)):
		state.rest_next_turn[current_player_id()] = false
		_tick_owned_attachments(current_player_id())
		_emit_event(&"turn_rested", {"player_id": current_player_id()})
		advance_to_next_player()
		return
	if new_turn:
		_tick_restraints(current_player_id())
		# 특수 승리 판정은 라운드 끝에, 여기서는 말 4개 완주만 본다.
		if _check_victory(null):
			return
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
			if attachment.owner_id == player_id and not attachment.is_expiry_suspended(state) and attachment.tick_turn():
				tile.remove_attachment(attachment)


func _enter_roll_wait() -> void:
	change_state(State.PHASE_ROLL_WAIT)


## 도구를 굴리고 굴림 보정을 차례로 입힌다: 히든 페이싱(난이도) → [범용] 손은 눈보다 빨라 → 연속 굴림 감쇠.
func _roll_with_modifiers(roller: int, tool: BaseJudgmentTool) -> RollResult:
	var result: RollResult = PacingDirector.adjust(state, roller, tool, tool.roll(state.rng))
	result = UtilityAugments.lucky_roll(state, roller, tool, result)
	return PacingDirector.damp_chain(state, tool, result, _roll_chain)


## [범용] 다이스: 리바이브: 굴림이 0칸이거나 턴 종료면 장전된 리바이브를 써서 이번 차례가 끝난 뒤 같은 사람이 한 턴 더 한다.
func _try_revive(roller: int) -> void:
	if int(state.revive_charges.get(roller, 0)) <= 0 or bool(state.extra_turns.get(roller, false)):
		return
	state.revive_charges[roller] = int(state.revive_charges[roller]) - 1
	state.extra_turns[roller] = true
	_emit_event(&"revive_triggered", {"player_id": roller})


func _apply_roll_result(result: RollResult) -> void:
	ToolRegistry.adjust_result(result)  # dice_table.csv의 min/max/jackpot 칸 수
	var roller_id: int = current_player_id()
	# ACT_11 밑장빼기: 확정된 굴림 결과를 미리 고른 칸 수로 바꾼다.
	if state.forced_roll.has(roller_id) and not result.can_continue:
		result.steps = int(state.forced_roll[roller_id])
		result.ends_turn = false
		result.reroll = false
		state.forced_roll.erase(roller_id)
	if state.is_banned(roller_id):
		result.reroll = false  # 알고리즘 밴: 리롤 금지
	_emit_event(&"roll_resolved", {"player_id": current_player_id(), "result": result.to_dict()})
	if result.ends_turn or (result.steps <= 0 and not result.can_continue and not result.reroll):
		_try_revive(roller_id)
	if result.ends_turn:
		move_queue.clear()
		advance_to_next_player()
		return
	if result.can_continue:
		phase_time_left = GameEnums.PHASE_TIME_ROLL * timer_scale
		_broadcast_state()
		return
	var ctx: RuleContext = _make_ctx(current_player_id())
	ctx.raw_roll = result.steps
	ctx.dice_value = result.steps
	ctx.trigger_timing = RuleContext.ON_DICE_ROLL
	ctx = state.rulebook.process_context(ctx)
	if not ctx.is_canceled:
		var roller: int = current_player_id()
		# [초증강] 주사위 도박사의 영혼: 이번 라운드 이동 거리 2배! 단 눈금이 1 이하면 과열: 이동 없이(0칸) 이번 차례가 바로 끝난다.
		if int(state.gambler_round.get(roller, -1)) == state.round_number and ctx.dice_value <= SuperAugments.gambler_overheat_at():
			_emit_event(&"gambler_busted", {"player_id": roller, "roll": ctx.dice_value})
			_try_revive(roller)
			move_queue.clear()
			advance_to_next_player()
			return
		var permanent: int = int(state.permanent_roll_bonus.get(roller, 0))
		var corner: int = int(state.corner_buff.get(roller, 0))
		state.corner_buff.erase(roller)
		var boosted: int = maxi(ctx.dice_value + state.roll_bonus + permanent + corner, 0)
		if state.roll_bonus != 0 or permanent != 0 or corner != 0:
			_emit_event(&"roll_boosted", {"player_id": roller, "from": ctx.dice_value, "to": boosted, "corner": corner})
			state.roll_bonus = 0
		if int(state.gambler_round.get(roller, -1)) == state.round_number:
			_emit_event(&"gambler_doubled", {"player_id": roller, "from": boosted, "to": boosted * SuperAugments.gambler_multiplier()})
			boosted *= SuperAugments.gambler_multiplier()
		# 템포 업: 최종 이동 칸에 단계별 보너스 (7R +2 / 14R +4 / 20R +6)
		var tempo: int = TempoUp.move_bonus(state.round_number)
		if tempo > 0:
			_emit_event(&"tempo_boosted", {"player_id": roller, "from": boosted, "to": boosted + tempo, "level": TempoUp.level(state.round_number)})
			boosted += tempo
		move_queue.append(boosted)
	_roll_chain += 1
	SpecialVictory.note_session(state, current_player_id(), VictoryLaw.BEST_CHAIN, _roll_chain)  # 🏆 초전도체 무한 동력
	# 추가 굴림(윷·모, 야추, 역만, 블랙잭, 타로, 룰렛 대박): 이번 눈금으로 먼저 움직이고, 이동이 끝난 뒤 다시 굴린다.
	# 카드는 턴당 1장 그대로다 (추가 굴림 앞에 카드 단계가 다시 오지만, 이미 냈으면 더 낼 수 없다).
	if result.reroll and _roll_chain < GameEnums.MAX_REROLL_CHAIN:
		_bonus_roll_pending = true
	_enter_interrupt_roll()


## 이번 턴에 굴리기 전 카드를 이미 썼는가 (UI·봇이 카드 사용 가능 여부를 판단할 때 쓴다).
func card_played_this_turn() -> bool:
	return _card_played_this_turn


## 이 단계의 개입 창에서 낼 수 있는 카드를 가진 플레이어가 있는가. 없으면 창을 열지 않고 바로 진행한다.
func _someone_can_intervene() -> bool:
	for player_id: int in player_order:
		for card_id: StringName in state.hands[player_id]:
			var card: BaseCard = CardRegistry.get_card(card_id)
			if card.category != GameEnums.CardCategory.COUNTER and card.is_playable_in(current_state) and card.could_play(state, player_id):
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


## 이번에 적용할 눈금 (대기열이 비었으면 0).
func _queued_dice() -> int:
	return 0 if move_queue.is_empty() else int(move_queue[0])


func _enter_select_pawn() -> void:
	if move_queue.is_empty() or state.selectable_pawns(current_player_id(), _queued_dice()).is_empty():
		if not move_queue.is_empty():
			_emit_event(&"turn_skipped", {"player_id": current_player_id(), "reason": &"no_movable_pawn"})
		move_queue.clear()
		_enter_resolution()
		return
	change_state(State.PHASE_SELECT_PAWN)


func _auto_select_pawn() -> void:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in state.selectable_pawns(current_player_id(), _queued_dice()):
		var distance: int = state.pawn_progress_distance(pawn)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	_execute_move(best)


## PHASE_MOVING_STEP: 법전(ON_MOVE_CALC)을 통과시켜 경로를 확정하고, 한 칸씩 이동한 뒤 도착 처리를 한다.
## 이동 직전 상태를 MoveCommand로 이번 턴 이력에 등록하므로 ACT_05가 이 이동도 되감는다.
func _execute_move(pawn: PlayerPawn, forced_path: Array[int] = []) -> void:
	change_state(State.PHASE_MOVING_STEP)
	var ctx: RuleContext = _make_ctx(current_player_id())
	var forced: bool = not forced_path.is_empty()
	ctx.dice_value = forced_path.size() if forced else move_queue.pop_front()
	# 대기열의 눈금은 모두 굴림에서 왔고 템포 업 보너스가 이미 더해져 있다 (같은 라운드). 필살기 직선 이동에는 없다.
	_move_tempo_bonus = 0 if forced else TempoUp.move_bonus(state.round_number)
	ctx.raw_roll = ctx.dice_value
	ctx.direction = state.movement_direction()
	ctx.defer_stack_choice = stack_choice_enabled

	var move_command := MoveCommand.new(current_player_id(), pawn.entity_id, ctx)
	move_command.bind_state(state)
	move_command.capture_before()
	command_stack.record(move_command)
	if forced:
		pawn.skill_used = true  # 차 직선 저격: 이동 직전 스냅샷이 기록된 뒤에 사용 완료로 표시해야 ACT_05가 되돌릴 수 있다

	_move_report = MoveExecutor.begin(state, pawn, ctx)
	if not _move_report.canceled:
		var path: Array[int] = forced_path.duplicate() if forced else MoveExecutor.plan_path(state, pawn, ctx, _move_report)
		if not forced:
			_note_altering_laws(pawn, ctx, path, _move_report)
			_announce_move_bonus(pawn, _move_report)
			MoveExecutor.announce_passives(state, pawn, _move_report)
		await execute_step_by_step_move(pawn, path, ctx)
	# 도착 정산(처치·발판·법전·승리 판정)도 한 묶음으로 처리한다 (걸음 await 뒤라 행동 처리 묶음 밖이다).
	processing_started.emit()
	_finish_move(pawn, ctx)
	processing_finished.emit()


## 눈금보다 더 가는 이유(기물 능력·나리 승급 등)를 화면에 알린다 (리벤지 부스터·점프 부스트는 따로 알린다). 표시 전용 이벤트.
func _announce_move_bonus(pawn: PlayerPawn, report: MoveReport) -> void:
	var notes: Array = []
	for note: String in report.ability_notes:
		if not note.begins_with("복수 부스터") and not note.begins_with("점프 부스트"):
			notes.append(note)
	if not notes.is_empty():
		_emit_event(&"move_bonus", {"pawn_id": pawn.entity_id, "notes": notes, "revenge": report.revenge_bonus})


func _finish_move(pawn: PlayerPawn, ctx: RuleContext) -> void:
	if not _move_report.canceled:
		MoveExecutor.finalize(state, pawn, ctx, _move_report, _move_outcome)
	var report: MoveReport = _move_report
	_move_report = null
	_extra_turn_pending = _extra_turn_pending or report.extra_turn
	_emit_event(&"move_resolved", report.to_dict())
	if _check_victory(report):
		return
	_stack_offer = report.stack_offer
	_enter_resolution()


## ON_MOVE_CALC 교칙이 눈금이나 경로를 실제로 바꿨을 때만, 바꾼 교칙들을 이동 보고서에 요약으로 남긴다.
## 교칙이 없었다면 나왔을 기준 경로와 비교하므로 "작동은 했지만 결과가 같은" 교칙은 기록되지 않는다.
func _note_altering_laws(pawn: PlayerPawn, ctx: RuleContext, path: Array[int], report: MoveReport) -> void:
	var baseline := RuleContext.new()
	baseline.state = state
	baseline.actor_id = ctx.actor_id
	baseline.pawn = pawn
	baseline.dice_value = ctx.raw_roll
	baseline.raw_roll = ctx.raw_roll
	baseline.direction = ctx.direction
	baseline.is_preview = true
	var base_path: Array[int] = MoveExecutor.plan_path(state, pawn, baseline, MoveReport.new())
	if base_path == path:
		return
	for law_id: String in state.rulebook.last_modified_law_ids:
		var law: LawResource = LawRegistry.create(law_id)
		if law != null:
			report.law_notes.append("%s %s" % [law_id, law.law_name])


func _enter_resolution() -> void:
	change_state(State.PHASE_RESOLUTION)
	if _open_counter_offer(&"resolution"):
		return
	if not _stack_offer.is_empty():
		# 윷놀이 기물 업기 선택을 기다린다. 선택(또는 시간 초과 시 자동 업기) 뒤에 정산 창이 이어진다.
		phase_time_left = GameEnums.PHASE_TIME_SELECT * timer_scale
		_broadcast_state()
		return
	if not _someone_can_intervene():
		_close_resolution_window()


func _close_resolution_window() -> void:
	command_stack.resolve_interrupts(_make_ctx(current_player_id()))
	if state.rollback_requested:
		# ACT_05: CommandStack이 이번 턴 이력을 역순으로 undo했다. 같은 플레이어의 턴을 처음부터 다시 시작한다.
		state.rollback_requested = false
		_extra_turn_pending = false
		_bonus_roll_pending = false
		_begin_turn(false)
		return
	if _check_victory(null):
		return
	if not move_queue.is_empty():
		_enter_select_pawn()
	elif _bonus_roll_pending:
		# 추가 굴림: 같은 플레이어가 카드 단계부터 다시 (턴당 카드 1장 제한·연속 굴림 수는 이어진다)
		_bonus_roll_pending = false
		change_state(State.PHASE_TURN_BEGIN)
	elif _extra_turn_pending:
		_extra_turn_pending = false
		_begin_turn(false)
	else:
		advance_to_next_player()


func _enter_neutral_npc_phase() -> void:
	change_state(State.PHASE_NEUTRAL_NPC)
	var reports: Array[Dictionary] = []
	for npc: NeutralNPC in state.npcs.duplicate():
		var report: Dictionary = npc.run_ai(state)
		report["display_id"] = npc.display_id
		report["tile"] = npc.current_tile_idx
		reports.append(report)
		if bool(report["vanished"]):
			state.remove_npc(npc)
	_emit_event(&"npc_phase_resolved", {"reports": reports})
	# 라운드의 마지막 단계: 중립 기물이 움직인 뒤 한 번 더 판정한다 (NPC의 처치·사출로 채워진 조건).
	if _judge_special_victory():
		return
	if state.reverse_move_rounds_left > 0:
		state.reverse_move_rounds_left -= 1
	state.round_number += 1
	_step_turn_index()
	_enter_round_start()


## 서바이벌 순위 판정 (VictoryChecker): 승리 조건을 달성한 사람을 다음 순위로 졸업시킨다.
## 남은 사람이 1명이면 그 사람이 꼴찌로 확정되고 게임이 끝난다. 게임이 끝났거나 지금 차례인 사람이 졸업해 턴이 넘어갔으면 true (호출한 쪽은 진행을 멈춘다).
## 카이지의 한방 역전법이 세는 이번 이동 칸 수: 실제로 간 칸 - 리벤지 부스터 칸 - 템포 업 보너스(굴림으로 한 이동만).
func kaiji_steps(report: MoveReport) -> int:
	return maxi(report.path.size() - report.revenge_bonus - _move_tempo_bonus, 0)


func _check_victory(report: MoveReport) -> bool:
	if is_game_over:
		return true
	var current: int = current_player_id()
	if report != null:
		# 🏆 카이지의 한방 역전법: 출발선 리벤지 부스터 칸과 라운드 템포 업 고정 보너스는 빼고 센다
		# (순수 판정 도구 눈금 + 기물 패시브 + 카드 효과로 크게 움직였을 때만 달성되게)
		SpecialVictory.note_session(state, current, VictoryLaw.BEST_MOVE, kaiji_steps(report))
	var current_graduated: bool = false
	# 특수 승리는 차례가 끝날 때(_judge_special_victory) 판정한다. 행동 도중인 여기서는 말 4개 완주만 본다.
	for entry: Dictionary in VictoryChecker.newly_qualified(state, player_order, current, false):
		_graduate(int(entry["player"]), entry["reason"])
		current_graduated = current_graduated or int(entry["player"]) == current
	if _end_if_decided():
		return true
	if current_graduated:
		advance_to_next_player()
		return true
	return false


## 차례가 끝날 때(그리고 라운드 끝 NPC 단계 뒤): 법전의 특수 승리를 판정한다. 조건을 채운 사람은 바로 졸업하고,
## 여럿이면 레이스에서 앞선 사람(완주 수 많고 남은 거리 짧은 순)이 먼저 순위를 받는다. 이미 졸업한 사람·지워진 교칙은 보지 않는다. 게임이 끝났으면 true.
func _judge_special_victory() -> bool:
	if is_game_over or state == null:
		return is_game_over
	var qualified: Array[Dictionary] = VictoryChecker.newly_qualified(state, player_order, current_player_id(), true)
	if qualified.is_empty():
		return false
	qualified.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Dictionary = VictoryChecker.progress_of(state, int(a["player"]))
		var pb: Dictionary = VictoryChecker.progress_of(state, int(b["player"]))
		if int(pa["finished"]) != int(pb["finished"]):
			return int(pa["finished"]) > int(pb["finished"])
		return int(pa["remaining"]) < int(pb["remaining"]))
	_emit_event(&"special_victory_judgement", {"round": state.round_number, "players": qualified.map(func(e: Dictionary) -> int: return int(e["player"])),
		"laws": qualified.map(func(e: Dictionary) -> String: return String(e["reason"]))})
	for entry: Dictionary in qualified:
		if state.is_graduated(int(entry["player"])):
			continue  # 이미 순위가 확정된 사람은 다시 판정하지 않는다
		# 앞사람이 졸업하며 그 교칙이 법전에서 사라졌으면(한 교칙은 한 명만 졸업시킨다) 다시 확인한다.
		var reason: StringName = VictoryChecker.player_reason(state, int(entry["player"]), true)
		if reason == &"":
			continue
		_graduate(int(entry["player"]), reason)
		if _end_if_decided():
			return true
	return false


## 순위가 다 정해졌으면 남은 사람을 마저 매기고 판을 끝낸다 (끝냈으면 true).
## - 남은 사람이 1명 이하: 그 사람이 꼴찌.
## - end_when_graduated(AI 대전의 사람 자리)가 모두 졸업: 남은 컴퓨터는 그 순간의 레이스 진행 순서로 순위를 매기고 바로 끝낸다 (구경만 하는 시간을 없앤다).
func _end_if_decided() -> bool:
	if is_game_over:
		return true
	var active: Array[int] = state.active_players(player_order)
	if active.size() <= 1:
		for last: int in active:
			_graduate(last, VictoryChecker.LAST_PLACE)
		_end_game()
		return true
	if end_when_graduated.is_empty():
		return false
	for watcher: int in end_when_graduated:
		if not state.is_graduated(watcher):
			return false
	_emit_event(&"race_ranked", {"players": VictoryChecker.sort_by_race(state, active)})
	for rest: int in VictoryChecker.sort_by_race(state, active):
		_graduate(rest, VictoryChecker.RACE_ORDER)
	_end_game()
	return true


## 한 명을 다음 순위로 졸업시키고 알린다 (남은 말은 보드에서 철수).
func _graduate(player_id: int, reason: StringName) -> void:
	var rank: int = state.graduate(player_id, reason)
	SpecialVictory.on_graduated(state, player_id, reason)
	_emit_event(&"player_ranked", {"player_id": player_id, "rank": rank, "reason": reason})


func _end_game() -> void:
	var winner_id: int = state.rankings[0]
	var reason: StringName = state.rank_reasons.get(winner_id, VictoryChecker.ALL_HOME)
	state.winner = winner_id
	is_game_over = true
	phase_time_left = 0.0
	state.victory_declared.emit(winner_id, reason)
	_emit_event(&"game_over", {"winner": winner_id, "reason": reason, "rankings": state.rankings.duplicate()})
	_broadcast_state()
	game_over.emit(winner_id, reason)


# ---------------------------------------------------------------------------
# 네트워크 방송 (호스트 -> 클라이언트)
# ---------------------------------------------------------------------------

func _has_remote_peers() -> bool:
	return not lockstep and multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not multiplayer.get_peers().is_empty()


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
		"stack_offer": _stack_offer.duplicate(true),
		"duel": _duel.duplicate(true),
		"counter": _counter_offer.duplicate(true),
		"augments": _augments_payload(),
	}


## 플레이어별 보유 증강 (프로필의 [증강] 요약용): {플레이어: [증강 ID 문자열]}.
func _augments_payload() -> Dictionary:
	var result: Dictionary = {}
	for player_id: Variant in augments:
		result[player_id] = (augments[player_id] as Array).map(func(id: StringName) -> String: return String(id))
	return result


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
	state.turn_direction = turn_direction
	_stack_offer = (payload["stack_offer"] as Dictionary).duplicate(true)
	_duel = (payload.get("duel", {}) as Dictionary).duplicate(true)
	_counter_offer = (payload.get("counter", {}) as Dictionary).duplicate(true)
	var owned: Dictionary = payload.get("augments", {})
	for player_id: Variant in owned:
		var ids: Array[StringName] = []
		for id: Variant in owned[player_id]:
			ids.append(StringName(str(id)))
		augments[int(player_id)] = ids
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


## 락스텝 검증용 상태 지문: 같은 시드·같은 행동 순서를 거친 모든 참가자가 같은 값이어야 한다.
func state_hash() -> int:
	if state == null:
		return 0
	var payload: Dictionary = {"snapshot": TurnSnapshot.capture(state).to_dict(), "phase": current_state, "serial": phase_serial, "turn": current_turn_index, "dir": turn_direction, "queue": move_queue, "over": is_game_over, "rng": state.rng.state, "duel": _duel, "counter": _counter_offer}
	return var_to_str(payload).hash()
