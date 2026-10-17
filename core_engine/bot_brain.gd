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
## 점프 코너와 반환점 (정확히 멈추면 유리한 칸).
const STOP_SPOT_TILES: Array[int] = [6, 12, 18]
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
	for pawn: PlayerPawn in state.selectable_pawns(player_id, dice_value):
		var score: float = score_move(state, pawn, dice_value)
		if score > best_score:
			best_score = score
			best_id = pawn.entity_id
	return best_id


## 이 말이 이번 눈금으로 움직일 때의 점수:
## 결승 완주 +100 / 적 말 잡기 +60 / 코너(6, 12, 18번)·빵집에 정확히 멈춤 +40 / 새 말 꺼내기 또는 선두 말 전진 +20.
## 그 외에는 결승에 가까워진 만큼 약간의 가산점을, 눈에 보이는 상대 호텔로 들어가면 감점을 준다.
static func score_move(state: GameState, pawn: PlayerPawn, dice_value: int) -> float:
	var path: Array[int] = MoveExecutor.preview_path(state, pawn, dice_value)
	if path.is_empty():
		return -100.0
	var destination: int = path.back()
	var score: float = 0.0
	if destination == GameEnums.GOAL_TILE and pawn.can_finish(state):
		score += SCORE_GOAL
	elif has_capturable_enemy(state, pawn, destination):
		score += SCORE_CAPTURE
	if destination != GameEnums.GOAL_TILE or not pawn.can_finish(state):
		var tile: TileNode = state.board.get_tile(destination)
		if STOP_SPOT_TILES.has(destination) or tile.tile_type == TileNode.TileType.BAKERY:
			score += SCORE_STOP_SPOT
	if not pawn.has_left_start or is_front_most(state, pawn):
		score += SCORE_ADVANCE
	var before: int = state.pawn_progress_distance(pawn)
	var after: int = state.board.distance_to_goal(destination, true) + (0 if pawn.can_finish(state) else GameEnums.TILE_COUNT)
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

## offers(증강 ID들) 중 고를 인덱스. 필살기를 가진 기물 지급이 1순위이고, 없으면 윷말·다른 기물·판정 도구 교체·교칙 순으로 고른다.
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
			# 필살기를 가진 기물(룩·차·비행기·흑돌)이 1순위, 윷말(잡기 추가 굴림)이 2순위, 나머지 기물은 그다음이다.
			var sub: GameEnums.PawnSubType = PawnCatalog.sub_type_of(definition.payload, definition.units[0])
			if PawnCatalog.skill_of(sub) != &"":
				return 90.0
			if definition.payload == GameEnums.PawnKind.YUT:
				return 75.0
			return 60.0 if _evolved_count(state, player_id) < 2 else 45.0
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


## 함정·소환 카드를 놓을 타일. 선두 상대 말 바로 앞 1~4칸의 길목과 코너(6, 12, 18번)를 우선하고 (2~3칸 앞이 가장 높다),
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
		&"ACT_04":  # 긴급 로켓 부스터: 굴림 +3, 역주행 중이 아니면 60%
			if state.reverse_move_rounds_left == 0 and rng.randf() < 0.6:
				return {"card_id": card.card_id, "params": {}}
		&"ACT_02":  # 뱅! 저격: 선두 말이 결승에 가장 가까운 상대를 70%
			var victims: Array[int] = BangCommand.target_players(state, player_id)
			if not victims.is_empty() and rng.randf() < 0.7:
				var best_player: int = victims[0]
				for victim: int in victims:
					if state.pawn_progress_distance(state.front_pawn_of(victim)) < state.pawn_progress_distance(state.front_pawn_of(best_player)):
						best_player = victim
				return {"card_id": card.card_id, "params": {"target_player": best_player}}
		&"ACT_09":  # 가위바위보 결투: 상대가 있으면 55%, 가장 앞선 상대에게
			var duel_target: int = DuelRules.default_target(state, player_id)
			if duel_target != -1 and rng.randf() < 0.55:
				return {"card_id": card.card_id, "params": {"target_player": duel_target}}
		&"ACT_03":  # 우노 +4: 다음 차례의 선두 말이 보드 위에 있고 50%
			if card.could_play(state, player_id) and rng.randf() < 0.5:
				return {"card_id": card.card_id, "params": {}}
		&"ACT_07":  # 무너지는 탑: 적이 뭉쳐 있거나 가장 앞선 적이 결승 가까이 있을 때
			var tower_tile: int = TarotEffects.tower_target(state, player_id)
			if tower_tile == -1:
				return {}
			var crowd: int = 0
			var enemy_crowd: int = 0
			for pawn: PlayerPawn in TarotEffects.field_pawns(state):
				if pawn.current_tile_idx == tower_tile:
					crowd += 1
					if pawn.owner_id != player_id:
						enemy_crowd += 1
			var lead: PlayerPawn = TarotEffects.leading_enemy(state, player_id)
			var lead_close: bool = lead != null and state.pawn_progress_distance(lead) <= 8
			if enemy_crowd >= 2 or (enemy_crowd >= 1 and lead_close):
				if rng.randf() < 0.7:
					return {"card_id": card.card_id, "params": {}}
		&"ACT_08":  # 운명의 수레바퀴: 내 뒤처진 말과 앞선 적 말을 바꿔서 크게 이득일 때
			var enemy_front: PlayerPawn = TarotEffects.leading_enemy(state, player_id)
			var mine_back: PlayerPawn = TarotEffects.trailing_own(state, player_id)
			if enemy_front == null:
				return {}
			if mine_back == null:
				if state.pawn_progress_distance(enemy_front) <= 10 and rng.randf() < 0.6:
					return {"card_id": card.card_id, "params": {}}
			elif state.pawn_progress_distance(mine_back) - state.pawn_progress_distance(enemy_front) >= 6:
				return {"card_id": card.card_id, "params": {}}
		&"ACT_01":  # 우노 리버스: 이동 역주행 중이 아니면 가끔 (판을 흔든다)
			if state.reverse_move_rounds_left == 0 and rng.randf() < 0.25:
				return {"card_id": card.card_id, "params": {}}
		&"ACT_06":  # 이의 있음!: 법전에 교칙이 있으면 가끔 무작위 한 개를 파기한다
			var laws: Array[String] = state.rulebook.law_ids()
			if not laws.is_empty() and rng.randf() < 0.4:
				return {"card_id": card.card_id, "params": {"law_id": laws[rng.randi_range(0, laws.size() - 1)]}}
		&"ACT_05":
			return {}  # 피해를 입었을 때의 되돌리기 전용 (턴 시작에는 쓰지 않는다)
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


## 개입 창(지금은 피해를 입은 뒤의 RESOLUTION 창뿐)에서 이 봇이 낼 카드 하나. 없으면 빈 Dictionary.
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
	return {}


# ---------------------------------------------------------------------------
# 판정 도구
# ---------------------------------------------------------------------------

## 러시안 룰렛: 빈 총을 pull_target번 당겼으면(누적 칸수 기준) 멈춘다. pull_target은 보통 2~3.
static func should_stop_roulette(tool: BaseJudgmentTool, pull_target: int) -> bool:
	if not (tool is ToolRussianRoulette) or not tool.has_pending_state():
		return false
	return (tool as ToolRussianRoulette).accumulated >= ToolRussianRoulette.STEPS_PER_EMPTY * pull_target


# ---------------------------------------------------------------------------
# 1회용 필살기
# ---------------------------------------------------------------------------

## 필살기를 쓸 가치가 이 기준 이상이면 사용한다.
const SKILL_USE_THRESHOLD: float = 12.0
const SHOT_ANGLE_STEPS: int = 24
const SHOT_POWERS: Array[float] = [0.35, 0.65, 1.0]


## 이 기물이 결승까지 온 거리(클수록 앞선 말). 업힌 말은 함께 센다.
static func pawn_progress(state: GameState, pawn: PlayerPawn) -> float:
	var total: float = 0.0
	for member: PlayerPawn in pawn.stack_members():
		total += maxf(0.0, float(GameEnums.TILE_COUNT - state.pawn_progress_distance(member)))
	return total


## 내 필살기 중 지금 쓸 만한 것 하나: {"pawn_id": int, "params": Dictionary, "value": float}. 없으면 빈 Dictionary.
static func plan_skill(state: GameState, player_id: int) -> Dictionary:
	var best: Dictionary = {}
	var best_value: float = SKILL_USE_THRESHOLD
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not PawnSkills.is_ready(pawn):
			continue
		var option: Dictionary = skill_option(state, pawn)
		if not option.is_empty() and float(option["value"]) > best_value:
			best_value = float(option["value"])
			best = {"pawn_id": pawn.entity_id, "params": option["params"], "value": option["value"]}
	return best


static func skill_option(state: GameState, pawn: PlayerPawn) -> Dictionary:
	match PawnCatalog.skill_of(pawn.sub_type()):
		&"charge": return _charge_option(state, pawn)
		&"shoot": return _shoot_option(state, pawn)
		&"warp": return _warp_option(state, pawn)
		&"castle": return _castle_option(state, pawn)
		&"drop": return _drop_option(state, pawn)
	return {}


static func _charge_option(state: GameState, pawn: PlayerPawn) -> Dictionary:
	var path: Array[int] = PawnSkills.chariot_path(state, pawn)
	if path.is_empty():
		return {}
	var value: float = 0.0
	for leader: PlayerPawn in state.leaders_at(path.back()):
		if leader.owner_id != pawn.owner_id and leader.has_left_start and not MoveExecutor.is_capture_immune(state, leader):
			value += pawn_progress(state, leader)
	if value <= 0.0:
		return {}
	return {"params": {}, "value": value}


static func _shoot_option(state: GameState, pawn: PlayerPawn) -> Dictionary:
	var best_value: float = 0.0
	var best_params: Dictionary = {}
	for step: int in SHOT_ANGLE_STEPS:
		var angle: float = TAU * float(step) / float(SHOT_ANGLE_STEPS)
		for power: float in SHOT_POWERS:
			var shot: Dictionary = PawnSkills.shot_result(state, pawn, angle, power)
			var value: float = 0.0
			for hit_id: int in shot["hits"]:
				value += pawn_progress(state, state.get_pawn(hit_id))
			if (shot["hits"] as Array).size() >= 2:
				value += 6.0
			if value > best_value:
				best_value = value
				best_params = {"angle": angle, "power": power}
	if best_params.is_empty():
		return {}
	return {"params": best_params, "value": best_value}


static func _warp_option(state: GameState, pawn: PlayerPawn) -> Dictionary:
	var best_value: float = -INF
	var best_tile: int = -1
	var current: int = state.pawn_progress_distance(pawn)
	for tile: int in PawnSkills.plane_targets(pawn):
		var value: float = float(current - state.board.distance_to_goal(tile, true))
		if state.board.get_tile(tile).tile_type == TileNode.TileType.BAKERY:
			value += 4.0
		for leader: PlayerPawn in state.leaders_at(tile):
			if leader.owner_id != pawn.owner_id and leader.has_left_start and not MoveExecutor.is_capture_immune(state, leader):
				value += pawn_progress(state, leader)
		for attachment: TileAttachment in state.board.get_tile(tile).attachments:
			if attachment.attachment_id == "HOTEL" and attachment.owner_id != pawn.owner_id:
				value -= 15.0
		if value > best_value:
			best_value = value
			best_tile = tile
	if best_tile == -1:
		return {}
	return {"params": {"tile": best_tile}, "value": best_value}


## 모치고마 낙하: 출발선에 대기 중인 말이 있으면 보병 곁에 떨어뜨린다 (그 자리에 잡을 수 있는 적이 있으면 더 가치가 크다).
static func _drop_option(state: GameState, pawn: PlayerPawn) -> Dictionary:
	var partners: Array[PlayerPawn] = PawnSkills.drop_partners(state, pawn)
	var tile: int = PawnSkills.drop_tile(state, pawn)
	if partners.is_empty() or tile == -1:
		return {}
	var value: float = SKILL_USE_THRESHOLD + 1.5
	for leader: PlayerPawn in state.leaders_at(tile):
		if leader.owner_id != pawn.owner_id and leader.has_left_start and not MoveExecutor.is_capture_immune(state, leader):
			value += pawn_progress(state, leader)
	return {"params": {"partner": partners[0].entity_id}, "value": value}


## 캐슬링: 룩이 위험한 자리(바로 뒤에 적이 쫓아옴)에 있을 때, 더 안전한 자리의 아군 기물과 위치를 맞바꿔 피한다.
static func _castle_option(state: GameState, pawn: PlayerPawn) -> Dictionary:
	var danger_here: float = _threat_at(state, pawn)
	if danger_here <= 0.0:
		return {}
	var best_partner: PlayerPawn = null
	var best_gain: float = 0.0
	for partner: PlayerPawn in PawnSkills.rook_partners(state, pawn):
		var gain: float = danger_here - _threat_at(state, partner)
		if gain > best_gain:
			best_gain = gain
			best_partner = partner
	if best_partner == null:
		return {}
	return {"params": {"partner": best_partner.entity_id}, "value": SKILL_USE_THRESHOLD + best_gain}


## 이 기물 바로 뒤 1~6칸 안에서 쫓아오는 적 대표 말 수 x 이 기물의 전진도.
static func _threat_at(state: GameState, pawn: PlayerPawn) -> float:
	var mine: int = state.board.distance_to_goal(pawn.current_tile_idx, true)
	var chasers: int = 0
	for enemy: PlayerPawn in state.pawns:
		if enemy.owner_id == pawn.owner_id or enemy.is_finished or not enemy.has_left_start or enemy.carrier != null:
			continue
		var gap: int = state.board.distance_to_goal(enemy.current_tile_idx, true) - mine
		if gap >= 1 and gap <= 6:
			chasers += 1
	return float(chasers) * (2.0 + pawn_progress(state, pawn) * 0.3)
