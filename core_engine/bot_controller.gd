# File: res://core_engine/bot_controller.gd
# Class: class_name BotController
# Role: AI 대전 모드의 봇 구동기. P2~P4(bot_players)의 차례에 TurnManager.act()로만 행동하며, 사람이 따라갈 수 있도록 단계마다 대기 시간을 둔다. 판단은 BotBrain이 맡는다
class_name BotController
extends Node

## 봇이 행동했다 (UI 로그·테스트용).
signal bot_acted(player_id: int, action: StringName, detail: Dictionary)

## 단계별 대기 시간(초). instant가 켜지면(헤드리스·ui_smoke) 모두 0초로 건너뛴다.
const DELAY_TURN_START: float = 0.8   # 봇 턴 시작 -> 카드/함정 사용 판단
const DELAY_PRE_ROLL: float = 0.6     # 굴리기 직전
const DELAY_ROLL_RESULT: float = 1.0  # 굴림 연출 뒤 결과를 확인하는 호흡
const DELAY_MOVE: float = 0.9         # 이동할 말 선택 및 이동
const DELAY_WINDOW: float = 0.7       # 개입 창에서 봇이 카드를 고민하는 시간
const DELAY_AUTO_PASS: float = 0.8    # 사람이 낼 카드가 없을 때 개입 창이 자동으로 넘어가기까지
const DELAY_DRAFT: float = 0.6        # 봇의 증강 선택 간격
const DELAY_DUEL_THINK: float = 0.8   # 봇이 가위바위보 손을 고민하는 시간 (사람이 상대일 때)
const DELAY_DUEL_RELAY: float = 1.2   # 봇끼리의 결투는 중앙 스테이지 중계를 볼 시간을 준다
const DELAY_DUEL_STRIKE: float = 0.9  # 이긴 봇이 밀어낼 말을 고르는 시간

var manager: TurnManager = null
var bot_players: Array[int] = [2, 3, 4]
var enabled: bool = false
var instant: bool = false
## true(AI 대전)면 증강 드래프트에서 사람이 먼저 고르고 그 뒤 봇이 고른다. false(온라인)면 봇은 기다리지 않고 바로 고른다.
var draft_waits_for_humans: bool = true
## true(기본)면 개입 창에서 사람이 낼 수 있는 카드를 들고 있는 동안 기다린다. false(자동 플레이 테스트)면 기다리지 않고 넘긴다.
var wait_for_human_windows: bool = true
## true를 돌려주면 봇은 잠시 기다린다 (화면의 굴림 연출 중 등).
var busy_check: Callable = Callable()
var rng := RandomNumberGenerator.new()

## 대기 시간 배율 (연출 속도 설정: 1.0이 기본 길이)
var pace: float = 1.0
var _wait: float = 0.0
var _seen_serial: int = -1
var _tried: Dictionary = {}
## 이미 필살기를 시도한 기물 ID (필살기는 게임당 1회라 같은 기물을 다시 시도하지 않는다).
var _tried_skills: Dictionary = {}
var _roulette_pull_target: int = 2
var _auto_pass_armed: bool = false
## 마지막으로 반격 여부를 고민하기 시작한 공격 기록 ID.
var _counter_seen: int = -1


func _init() -> void:
	rng.randomize()


## 봇을 켜거나 끈다. 켜는 즉시 지금 차례에 맞춰 행동하기 시작한다.
func set_enabled(value: bool) -> void:
	enabled = value
	_tried_skills.clear()
	_seen_serial = -1
	_wait = 0.0


func is_bot(player_id: int) -> bool:
	return bot_players.has(player_id)


func _process(delta: float) -> void:
	tick(delta)


## 시간 delta만큼 진행한다 (테스트는 이 함수를 직접 부른다).
func tick(delta: float) -> void:
	if not enabled or manager == null or manager.state == null or manager.is_game_over:
		return
	if busy_check.is_valid() and bool(busy_check.call()):
		return
	if manager.phase_serial != _seen_serial:
		_seen_serial = manager.phase_serial
		_on_phase_entered()
	if _wait > 0.0:
		if instant:
			_wait = 0.0
		else:
			_wait -= delta
			if _wait > 0.0:
				return
	_step()


func _bot_turn() -> bool:
	return is_bot(manager.current_player_id())


## 대기 시간을 더한다 (이미 남은 대기가 있으면 그 뒤에 이어진다: 굴림 결과 확인 0.6초 -> 말 선택 0.5초).
func _delay(seconds: float) -> void:
	if not instant:
		_wait += seconds * pace


## 새 결정 지점에 들어왔다: 이번 단계에서 쓸 대기 시간과 기억을 초기화한다.
func _on_phase_entered() -> void:
	_tried.clear()
	_auto_pass_armed = false
	if manager.duel_pending():
		var duel: Dictionary = manager.pending_duel()
		var both_bots: bool = is_bot(int(duel["challenger"])) and is_bot(int(duel["defender"]))
		_delay(DELAY_DUEL_STRIKE if duel["step"] == &"strike" else (DELAY_DUEL_RELAY if both_bots else DELAY_DUEL_THINK))
		return
	match manager.current_state:
		TurnManager.State.PHASE_ROUND_START:
			_delay(DELAY_DRAFT)
		TurnManager.State.PHASE_TURN_BEGIN:
			_roulette_pull_target = rng.randi_range(2, 3)
			if _bot_turn():
				_delay(DELAY_TURN_START)
		TurnManager.State.PHASE_ROLL_WAIT:
			if _bot_turn():
				_delay(DELAY_PRE_ROLL)
		TurnManager.State.PHASE_INTERRUPT_ROLL, TurnManager.State.PHASE_RESOLUTION:
			_delay(DELAY_WINDOW)
		TurnManager.State.PHASE_SELECT_PAWN:
			if _bot_turn():
				_delay(DELAY_MOVE)


func _step() -> void:
	if manager.duel_pending():
		_step_duel()
		return
	if manager.counter_pending():
		_step_counter()
		return
	match manager.current_state:
		TurnManager.State.PHASE_ROUND_START: _step_draft()
		TurnManager.State.PHASE_TURN_BEGIN:
			if _bot_turn():
				_step_turn_begin()
		TurnManager.State.PHASE_ROLL_WAIT:
			if _bot_turn():
				_step_roll()
		TurnManager.State.PHASE_INTERRUPT_ROLL, TurnManager.State.PHASE_RESOLUTION: _step_window()
		TurnManager.State.PHASE_SELECT_PAWN:
			if _bot_turn():
				_step_select()


func _act(player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)
	bot_acted.emit(player_id, action, params)


# ---------------------------------------------------------------------------
# 단계별 행동
# ---------------------------------------------------------------------------

## 반격 대기: 맞은 봇은 반격 카드를 고르거나 그냥 맞는다. 사람이 맞았으면 화면의 반격 팝업을 기다린다 (자동 플레이 테스트는 넘긴다).
func _step_counter() -> void:
	var offer: Dictionary = manager.pending_counter()
	var victim: int = int(offer["victim"])
	var key: int = int(offer["attack"])
	if _counter_seen != key:
		_counter_seen = key
		_delay(DELAY_WINDOW)
		if _wait > 0.0:
			return
	if not is_bot(victim):
		if not wait_for_human_windows:
			_act(victim, &"counter_pass")
		return
	var card_id: StringName = BotBrain.choose_counter(manager.state, victim, offer.get("cards", []), manager.state.get_attack(key), rng)
	if card_id != &"":
		_act(victim, &"play_card", {"card_id": card_id})
	else:
		_act(victim, &"counter_pass")


## ACT_09 결투: 봇은 손을 무작위로 내고, 이겼다면 진 사람의 선두 말을 민다. 사람 차례는 화면이 입력을 받는다.
func _step_duel() -> void:
	var duel: Dictionary = manager.pending_duel()
	if duel["step"] == &"pick":
		for player_id: int in [int(duel["challenger"]), int(duel["defender"])]:
			if is_bot(player_id) and not (duel["picks"] as Dictionary).has(player_id):
				_act(player_id, &"duel_pick", {"hand": rng.randi_range(0, 2)})
				return
		return
	var winner: int = int(duel["winner"])
	if not is_bot(winner):
		return
	var front: PlayerPawn = manager.state.front_pawn_of(int(duel["loser"]))
	var candidates: Array = duel["candidates"]
	var pawn_id: int = front.entity_id if front != null and candidates.has(front.entity_id) else int(candidates[0])
	_act(winner, &"duel_strike", {"pawn_id": pawn_id})


## 증강 드래프트: 사람(P1)이 아직 고르는 중이면 기다리고, 다 고른 뒤 봇들이 차례로 고른다.
func _step_draft() -> void:
	var pending: Array[int] = manager.draft_pending_players()
	if pending.is_empty():
		return
	var bot_id: int = -1
	for player_id: int in pending:
		if is_bot(player_id):
			if bot_id == -1:
				bot_id = player_id
		elif draft_waits_for_humans:
			return
	if bot_id == -1:
		return
	var offers: Array[StringName] = manager.draft_offers_for(bot_id)
	var index: int = BotBrain.choose_augment(manager.state, bot_id, offers, rng)
	var params: Dictionary = {"index": index}
	var definition: AugmentDef = AugmentRegistry.get_def(offers[index])
	if definition.category == GameEnums.AugmentCategory.PAWN_EVOLUTION:
		params["pawn_id"] = BotBrain.choose_evolution_pawn(manager.state, bot_id)
	_act(bot_id, &"pick_augment", params)
	_delay(DELAY_DRAFT)


## 턴 시작: 카드/함정 사용 판단 -> 굴리러 진행.
func _step_turn_begin() -> void:
	var player_id: int = manager.current_player_id()
	# 카드는 굴리기 전 턴당 1장만 쓸 수 있다.
	var plan: Dictionary = {} if manager.card_played_this_turn() else BotBrain.plan_turn_card(manager.state, player_id, _tried, rng)
	if not plan.is_empty():
		var params: Dictionary = (plan["params"] as Dictionary).duplicate()
		params["card_id"] = plan["card_id"]
		_act(player_id, &"play_card", params)
		_delay(DELAY_TURN_START)
		return
	# 1회용 필살기: 유리한 각이 나오면 주사위 대신(룩은 굴리기 전에) 쓴다.
	var skill: Dictionary = BotBrain.plan_skill(manager.state, player_id)
	if not skill.is_empty() and not _tried_skills.has(skill["pawn_id"]) and manager.can_use_skill(player_id, int(skill["pawn_id"])):
		_tried_skills[skill["pawn_id"]] = true
		var skill_params: Dictionary = (skill["params"] as Dictionary).duplicate()
		skill_params["pawn_id"] = skill["pawn_id"]
		_act(player_id, &"use_skill", skill_params)
		_delay(DELAY_TURN_START)
		return
	_act(player_id, &"proceed")


## 굴리기: 러시안 룰렛은 2~3번 당긴 뒤 멈추고, 야추는 고정·다시 굴리기, 블랙잭은 16 이하 히트·17 이상 스탠드, 나머지는 그냥 굴린다.
func _step_roll() -> void:
	var player_id: int = manager.current_player_id()
	var tool: BaseJudgmentTool = manager.state.tools[player_id]
	if BotBrain.should_stop_roulette(tool, _roulette_pull_target):
		_act(player_id, &"stop")
	elif tool is ToolYacht and tool.has_pending_state():
		# 야추: 가장 많이 겹친 눈금을 고정하고 1~2번 다시 굴린 뒤 확정한다.
		if BotBrain.should_stop_yacht(tool):
			_act(player_id, &"stop")
		else:
			_act(player_id, &"roll", {"keep": BotBrain.yacht_keep_mask((tool as ToolYacht).dice)})
	elif tool is ToolBlackjack and tool.has_pending_state():
		_act(player_id, &"roll" if BotBrain.should_hit_blackjack(tool) else &"stop")
	else:
		_act(player_id, &"roll")
	_delay(DELAY_ROLL_RESULT)


## 이동할 말 선택: BotBrain의 점수가 가장 높은 말.
func _step_select() -> void:
	var player_id: int = manager.current_player_id()
	if manager.move_queue.is_empty():
		manager.force_timeout()
		return
	var pawn_id: int = BotBrain.choose_pawn(manager.state, player_id, manager.move_queue[0])
	if pawn_id == -1:
		manager.force_timeout()
		return
	_act(player_id, &"select_pawn", {"pawn_id": pawn_id})


## 개입 창: 윷놀이 업기 선택은 [업기], 봇들은 낼 카드가 있으면 내고, 사람이 낼 카드가 없으면 0.8초 뒤 자동으로 넘긴다.
func _step_window() -> void:
	if manager.stack_offer_pending():
		if _bot_turn():
			_act(manager.current_player_id(), &"stack_choice", {"stack": true})
		return
	var phase: int = manager.current_state
	var roll_value: int = manager.move_queue.back() if not manager.move_queue.is_empty() else 0
	for player_id: int in manager.player_order:
		if not is_bot(player_id):
			continue
		var tried_for_bot: Dictionary = _tried.get(player_id, {})
		_tried[player_id] = tried_for_bot
		var plan: Dictionary = BotBrain.plan_window_card(manager.state, player_id, phase, roll_value, _bot_turn(), manager.current_player_id(), tried_for_bot, rng)
		if not plan.is_empty():
			var params: Dictionary = (plan["params"] as Dictionary).duplicate()
			params["card_id"] = plan["card_id"]
			_act(player_id, &"play_card", params)
			_delay(DELAY_WINDOW)
			return
	if _human_can_intervene():
		return  # 사람이 [개입 카드 사용 / 패스]를 고르는 시간
	if not _auto_pass_armed:
		_auto_pass_armed = true
		_delay(DELAY_AUTO_PASS)
		if _wait > 0.0:
			return
	manager.force_timeout()


## 사람(봇이 아닌) 플레이어가 지금 개입 창에서 낼 수 있는 카드를 들고 있는가.
func _human_can_intervene() -> bool:
	if not wait_for_human_windows:
		return false
	for player_id: int in manager.player_order:
		if is_bot(player_id):
			continue
		for card_id: StringName in manager.state.hands[player_id]:
			var card: BaseCard = CardRegistry.get_card(card_id)
			if card.is_playable_in(manager.current_state) and card.could_play(manager.state, player_id):
				return true
	return false
