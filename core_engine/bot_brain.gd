# File: res://core_engine/bot_brain.gd
# Class: class_name BotBrain
# Role: AI 봇의 의사결정 휴리스틱(순수 함수). 증강 드래프트·말 선택(점수제)·함정/소환 카드 타일 고르기·개입 카드·러시안 룰렛 멈춤을 판단하며 게임 상태를 바꾸지 않는다
class_name BotBrain
extends RefCounted

## 말 선택 점수표.
const SCORE_GOAL: float = 100.0
const SCORE_CAPTURE: float = 60.0
const SCORE_STOP_SPOT: float = 40.0
const SCORE_ADVANCE: float = 20.0
## 지름길 코너와 중앙 (정확히 멈추면 유리한 칸).
const STOP_SPOT_TILES: Array[int] = [5, 10, 22]
## 턴 시작에 함정·소환 카드를 쓸 확률.
const TRAP_USE_CHANCE: float = 0.6
## 고눈금 개입 기준: 이 값 이상이면 끼어든다.
const HIGH_ROLL: int = 5


# ---------------------------------------------------------------------------
# 말 선택
# ---------------------------------------------------------------------------

## 이동할 말 ID. 선택 가능한 말이 없으면 -1. 점수가 같으면 ID가 낮은 말.
static func choose_pawn(state: GameState, player_id: int, dice_value: int) -> int:
	var best_id: int = -1
	var best_score: float = -INF
	for pawn: PlayerPawn in state.selectable_pawns(player_id):
		var score: float = score_move(state, pawn, dice_value)
		if score > best_score:
			best_score = score
			best_id = pawn.entity_id
	return best_id


## 이 말이 이번 눈금으로 움직일 때의 점수:
## 결승 완주 +100 / 적 말 잡기 +60 / 코너(5, 10, 22번)·빵집에 정확히 멈춤 +40 / 새 말 꺼내기 또는 선두 말 전진 +20.
## 그 외에는 결승에 가까워진 만큼 약간의 가산점을, 눈에 보이는 상대 호텔로 들어가면 감점을 준다.
static func score_move(state: GameState, pawn: PlayerPawn, dice_value: int) -> float:
	var path: Array[int] = MoveExecutor.preview_path(state, pawn, dice_value)
	if path.is_empty():
		return -100.0
	var destination: int = path.back()
	var score: float = 0.0
	if destination == GameEnums.GOAL_TILE:
		score += SCORE_GOAL
	elif has_capturable_enemy(state, pawn, destination):
		score += SCORE_CAPTURE
	if destination != GameEnums.GOAL_TILE:
		var tile: TileNode = state.board.get_tile(destination)
		if STOP_SPOT_TILES.has(destination) or tile.tile_type == TileNode.TileType.BAKERY:
			score += SCORE_STOP_SPOT
	if not pawn.has_left_start or is_front_most(state, pawn):
		score += SCORE_ADVANCE
	var before: int = state.pawn_progress_distance(pawn)
	var after: int = state.board.distance_to_goal(destination, true)
	score += float(before - after) * 0.5
	if pawn.is_imprisoned and absi(dice_value) % 2 == 1:
		score -= 30.0
	for step_tile: int in path:
		for attachment: TileAttachment in state.board.get_tile(step_tile).attachments:
			if attachment.attachment_id == "HOTEL" and attachment.owner_id != pawn.owner_id:
				score -= 15.0
	return score


## 그 타일에 이 말이 잡을 수 있는 적 대표 말이 있는가 (출발선 제외, 잡기 면역 제외).
static func has_capturable_enemy(state: GameState, pawn: PlayerPawn, tile: int) -> bool:
	if tile == GameEnums.GOAL_TILE:
		return false
	for other: PlayerPawn in state.leaders_at(tile):
		if other.owner_id != pawn.owner_id and not MoveExecutor.is_capture_immune(state, other):
			return true
	return false


## 내 말들 중 결승에 가장 가까이 나가 있는 말인가 (출발한 말만).
static func is_front_most(state: GameState, pawn: PlayerPawn) -> bool:
	return pawn.has_left_start and state.front_pawn_of(pawn.owner_id) == pawn


# ---------------------------------------------------------------------------
# 증강 드래프트
# ---------------------------------------------------------------------------

## offers(증강 ID들) 중 고를 인덱스. 이미 가진 세트를 2세트/4세트로 완성하는 기물 진화가 1순위이고, 없으면 판정 도구 교체나 교칙을 고른다.
static func choose_augment(state: GameState, player_id: int, offers: Array[StringName], rng: RandomNumberGenerator) -> int:
	var best: Array[int] = []
	var best_score: float = -INF
	for index: int in offers.size():
		var score: float = score_augment(state, player_id, AugmentRegistry.get_def(offers[index]))
		if score > best_score + 0.001:
			best_score = score
			best = [index]
		elif absf(score - best_score) <= 0.001:
			best.append(index)
	return best[rng.randi_range(0, best.size() - 1)] if not best.is_empty() else 0


static func score_augment(state: GameState, player_id: int, definition: AugmentDef) -> float:
	match definition.category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			var owned: int = state.set_count(player_id, definition.payload)
			if owned >= 1 and (owned + 1 == GameEnums.SET_SYNERGY_2 or owned + 1 == GameEnums.PAWNS_PER_PLAYER):
				return 100.0  # 2세트/4세트 시너지 완성
			if owned >= 1:
				return 80.0  # 세트를 키우는 중 (3호기)
			return 55.0 if _evolved_count(state, player_id) == 0 else 25.0  # 첫 세트 시작은 괜찮고, 세트를 흩뿌리는 것은 낮게
		GameEnums.AugmentCategory.TOOL_SWAP:
			return 50.0
		GameEnums.AugmentCategory.LAW_ENACT:
			return 40.0
	return 30.0


static func _evolved_count(state: GameState, player_id: int) -> int:
	var count: int = 0
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.kind != GameEnums.PawnKind.BASIC:
			count += 1
	return count


## 진화시킬 기본 말: 가장 앞에 나가 있는(결승에 가까운) 기본 말.
static func choose_evolution_pawn(state: GameState, player_id: int) -> int:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in state.basic_pawns_of(player_id):
		var distance: int = state.pawn_progress_distance(pawn)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	return best.entity_id if best != null else -1


# ---------------------------------------------------------------------------
# 카드
# ---------------------------------------------------------------------------

## 결승에 가장 가까운 상대 대표 말 (동률이면 낮은 플레이어 번호 = P1 우선). 없으면 null.
static func leading_enemy(state: GameState, player_id: int) -> PlayerPawn:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in state.pawns:
		if pawn.owner_id == player_id or pawn.is_finished or pawn.carrier != null or not pawn.has_left_start:
			continue
		var distance: int = state.pawn_progress_distance(pawn)
		if distance < best_distance or (distance == best_distance and pawn.owner_id < best.owner_id):
			best_distance = distance
			best = pawn
	return best


## 함정·소환 카드를 놓을 타일. 선두 상대 말 바로 앞 1~4칸의 길목과 코너(5, 10, 22번)를 우선하고 (2~3칸 앞이 가장 높다),
## 카드가 허용하는 타일이 하나도 없으면 -1.
static func choose_card_tile(state: GameState, player_id: int, card: BaseCard, rng: RandomNumberGenerator) -> int:
	var scores: Dictionary = {}
	var target: PlayerPawn = leading_enemy(state, player_id)
	if target != null:
		for ahead: int in range(1, 5):
			var path: Array[int] = state.board.calculate_path(target, ahead, RuleContext.new())
			if path.is_empty():
				continue
			var tile: int = path.back()
			var value: float = 60.0 if ahead == 2 or ahead == 3 else 50.0
			scores[tile] = maxf(float(scores.get(tile, 0.0)), value)
	for corner: int in STOP_SPOT_TILES:
		scores[corner] = float(scores.get(corner, 0.0)) + 20.0 if scores.has(corner) else 30.0
	var best: Array[int] = []
	var best_score: float = -INF
	for tile: int in scores:
		if not card.can_play(state, player_id, {"tile": tile}):
			continue
		var score: float = scores[tile]
		if score > best_score:
			best_score = score
			best = [tile]
		elif score == best_score:
			best.append(tile)
	if best.is_empty():
		var any: Array[int] = []
		for tile: int in GameEnums.TILE_COUNT:
			if card.can_play(state, player_id, {"tile": tile}):
				any.append(tile)
		return any[rng.randi_range(0, any.size() - 1)] if not any.is_empty() else -1
	return best[rng.randi_range(0, best.size() - 1)]


## 내 턴 시작에 쓸 카드 하나: {"card_id": StringName, "params": Dictionary}. 쓸 카드가 없으면 빈 Dictionary.
## tried: 이번 턴에 이미 검토한 카드 ID (같은 카드를 두 번 검토하지 않는다). 검토한 카드는 tried에 추가된다.
static func plan_turn_card(state: GameState, player_id: int, tried: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hand: Array = state.hands[player_id]
	for card_id: StringName in hand:
		if tried.has(card_id):
			continue
		var card: BaseCard = CardRegistry.get_card(card_id)
		if not card.is_playable_in(TurnManager.State.PHASE_TURN_BEGIN):
			continue
		tried[card_id] = true
		var plan: Dictionary = _plan_one_turn_card(state, player_id, card, rng)
		if not plan.is_empty():
			return plan
	return {}


static func _plan_one_turn_card(state: GameState, player_id: int, card: BaseCard, rng: RandomNumberGenerator) -> Dictionary:
	match card.card_id:
		&"ACT_04":  # 빽도로 19/28번에 선 말을 즉시 완주: 항상
			for pawn: PlayerPawn in state.pawns_of(player_id):
				var params: Dictionary = {"pawn_id": pawn.entity_id}
				if card.can_play(state, player_id, params):
					return {"card_id": card.card_id, "params": params}
		&"ACT_02":  # 뱅!: 사정거리에 적이 있으면 70%
			if card.could_play(state, player_id) and rng.randf() < 0.7:
				return {"card_id": card.card_id, "params": {}}
		&"ACT_03":  # 우노 +4: 다음 차례가 나 자신이 아니고 50%
			if state.next_player_after(player_id) != player_id and rng.randf() < 0.5:
				return {"card_id": card.card_id, "params": {}}
		&"ACT_01", &"ACT_05", &"ACT_06":
			return {}  # 개입 전용 (턴 시작에는 쓰지 않는다)
		_:
			if rng.randf() >= TRAP_USE_CHANCE:
				return {}
			if card.needs_tile():
				var tile: int = choose_card_tile(state, player_id, card, rng)
				if tile != -1:
					return {"card_id": card.card_id, "params": {"tile": tile}}
			elif card.can_play(state, player_id, {}):
				return {"card_id": card.card_id, "params": {}}
	return {}


## 개입 창(INTERRUPT_ROLL / RESOLUTION)에서 이 봇이 낼 카드 하나. 없으면 빈 Dictionary.
## roll_value: 방금 확정된 눈금 (INTERRUPT_ROLL에서만 의미 있음). actor_is_bot: 지금 턴인 플레이어가 봇인가.
static func plan_window_card(state: GameState, player_id: int, phase: int, roll_value: int, actor_is_bot: bool, current_player: int, tried: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hand: Array = state.hands[player_id]
	for card_id: StringName in hand:
		if tried.has(card_id):
			continue
		var card: BaseCard = CardRegistry.get_card(card_id)
		if not card.is_playable_in(phase):
			continue
		tried[card_id] = true
		match card.card_id:
			&"ACT_05":  # 말이 잡히거나 함정에 걸렸다면 되감기
				if card.could_play(state, player_id):
					return {"card_id": card.card_id, "params": {}}
			&"ACT_04":
				for pawn: PlayerPawn in state.pawns_of(player_id):
					var params: Dictionary = {"pawn_id": pawn.entity_id}
					if card.can_play(state, player_id, params):
						return {"card_id": card.card_id, "params": params}
			&"ACT_01":  # 사람(상대)이 고눈금을 굴렸을 때 역주행으로 눈금을 뒤집는다
				if phase == TurnManager.State.PHASE_INTERRUPT_ROLL and current_player != player_id and not actor_is_bot \
						and absi(roll_value) >= HIGH_ROLL and state.reverse_move_rounds_left == 0 and rng.randf() < 0.7:
					return {"card_id": card.card_id, "params": {}}
	return {}


# ---------------------------------------------------------------------------
# 판정 도구
# ---------------------------------------------------------------------------

## 러시안 룰렛: 빈 총을 pull_target번 당겼으면(누적 칸수 기준) 멈춘다. pull_target은 보통 2~3.
static func should_stop_roulette(tool: BaseJudgmentTool, pull_target: int) -> bool:
	if not (tool is ToolRussianRoulette) or not tool.has_pending_state():
		return false
	return (tool as ToolRussianRoulette).accumulated >= ToolRussianRoulette.STEPS_PER_EMPTY * pull_target
