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
## ⚡ 부스터 발판에 멈추면 3칸 더 날아간다.
const SCORE_DASH_PAD: float = 30.0
## 점프 코너와 반환점 (정확히 멈추면 유리한 칸).
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
## 결승 완주 +100 / 적 말 잡기 +60 / 출발선 외 코너(BoardSpec.bonus_corner_tiles)·빵집에 정확히 멈춤 +40 / 새 말 꺼내기 또는 선두 말 전진 +20.
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
		if BoardSpec.bonus_corner_tiles.has(destination) or tile.tile_type == TileNode.TileType.BAKERY:
			score += SCORE_STOP_SPOT
	if state.boost_gimmicks and BoardSpec.dash_tiles.has(destination):
		score += SCORE_DASH_PAD
	if not pawn.has_left_start or is_front_most(state, pawn):
		score += SCORE_ADVANCE
	var before: int = state.pawn_progress_distance(pawn)
	var after: int = state.board.distance_to_goal(destination, true) + (0 if pawn.can_finish(state) else BoardSpec.tile_count)
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
		var offered: AugmentDef = AugmentRegistry.get_def(offers[index])
		if not offered.is_available(state, player_id):
			continue  # 제시된 뒤 조건이 바뀌어 지금은 적용되지 않는 증강(예: 보드에 내 말이 없는 초증강)은 고르지 않는다
		var score: float = score_augment(state, player_id, offered)
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
		GameEnums.AugmentCategory.SUPER_GAMBLE:
			return super_augment_score(definition.payload)
	return 30.0


## 봇의 초증강 선호: 확실히 이득인 것(영구 가속·카드+호텔·저격·재분배)은 높게, 도박성 짙은 것(판 뒤집기·도박사·캐슬링)은 낮게 본다.
static func super_augment_score(effect: StringName) -> float:
	match effect:
		SuperAugments.DEVIL, SuperAugments.BAKERY, SuperAugments.SNIPER, SuperAugments.NITRO, SuperAugments.RUNAWAY:
			return 70.0
		SuperAugments.REDISTRIBUTE, SuperAugments.GUARANTEE, SuperAugments.MINEFIELD:
			return 55.0
		SuperAugments.RAID:
			return 45.0
	return 35.0


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


## 함정·소환 카드를 놓을 타일. 선두 상대 말 바로 앞 1~4칸의 길목과 출발선 외 코너를 우선하고 (2~3칸 앞이 가장 높다),
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
	for corner: int in BoardSpec.bonus_corner_tiles:
		scores[corner] = float(scores.get(corner, 0.0)) + 20.0 if scores.has(corner) else 30.0
	var best: Array[int] = []
	var best_score: float = -INF
	for tile: int in scores:
		if not card.is_legal(state, player_id, {"tile": tile}):
			continue
		var score: float = scores[tile]
		if score > best_score:
			best_score = score
			best = [tile]
		elif score == best_score:
			best.append(tile)
	if best.is_empty():
		var any: Array[int] = []
		for tile: int in BoardSpec.tile_count:
			if card.is_legal(state, player_id, {"tile": tile}):
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
		&"ACT_07":  # 무너지는 탑: 남의 설치물이 가장 많은 변 (내 설치물보다 많을 때)
			var best_side: int = -1
			var best_gain: int = 0
			for side: int in 4:
				var gain: int = 0
				for tile: int in TowerCommand.side_tiles(side):
					for attachment: TileAttachment in state.board.get_tile(tile).attachments:
						gain += 1 if attachment.owner_id != player_id else -1
				if gain > best_gain:
					best_gain = gain
					best_side = side
			if best_side != -1 and rng.randf() < 0.7:
				return {"card_id": card.card_id, "params": {"side": best_side}}
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
		&"ACT_06":  # 이의 있음!: 목표에 가장 가까운 상대의 특수 승리 기록을 지운다
			var best_choice: Dictionary = {}
			var best_ratio: float = 0.5
			for choice: Dictionary in CardObjection.choices(state):
				var target: int = int(choice["target_player"])
				if target == player_id:
					continue
				var law: VictoryLaw = LawRegistry.create(choice["law_id"]) as VictoryLaw
				var ratio: float = float(law.progress(state, target)) / float(law.goal())
				if ratio > best_ratio:
					best_ratio = ratio
					best_choice = choice
			if not best_choice.is_empty():
				return {"card_id": card.card_id, "params": best_choice}
		&"ACT_10":  # 빠루: 앞 3칸에 적 말이 있으면
			for tile: int in CrowbarCommand.reach_tiles(state, player_id):
				for leader: PlayerPawn in state.leaders_at(tile):
					if leader.owner_id != player_id and leader.has_left_start:
						return {"card_id": card.card_id, "params": {}}
		&"ACT_11":  # 밑장빼기: 최대 눈금
			if card.could_play(state, player_id) and rng.randf() < 0.5:
				return {"card_id": card.card_id, "params": {"steps": CardStatus.MAX_STEPS}}
		&"ACT_12":  # 더 월드: 바로 쓴다
			if card.could_play(state, player_id):
				return {"card_id": card.card_id, "params": {}}
		&"ACT_13":  # 어디로든 문: 결승에 가장 가까운 빈 칸으로 (지금보다 앞일 때만)
			var traveler: PlayerPawn = DoorCommand.traveler(state, player_id)
			if traveler != null and rng.randf() < 0.6:
				var best_tile: int = -1
				var best_distance: int = state.pawn_progress_distance(traveler)
				for tile: int in BoardSpec.tile_count:
					if DoorCommand.is_empty_tile(state, tile) and state.board.distance_to_goal(tile, true) < best_distance:
						best_distance = state.board.distance_to_goal(tile, true)
						best_tile = tile
				if best_tile != -1:
					return {"card_id": card.card_id, "params": {"tile": best_tile}}
		&"ACT_14", &"ACT_15":  # 밴·스킵: 선두 상대에게
			var leader_player: int = state.race_leader(player_id)
			if leader_player != -1 and card.is_legal(state, player_id, {"target_player": leader_player}) and rng.randf() < 0.6:
				return {"card_id": card.card_id, "params": {"target_player": leader_player}}
		&"CNT_01", &"CNT_02", &"CNT_03", &"CNT_04", &"CNT_05", &"CNT_06", &"CNT_07":
			return {}  # 반격 카드는 공격당했을 때만
		_:
			if rng.randf() >= TRAP_USE_CHANCE:
				return {}
			if card.needs_tile():
				var tile: int = choose_card_tile(state, player_id, card, rng)
				if tile != -1:
					return {"card_id": card.card_id, "params": {"tile": tile}}
			elif card.is_legal(state, player_id, {}):
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
		if card.category != GameEnums.CardCategory.COUNTER and card.could_play(state, player_id):
			return {"card_id": card.card_id, "params": {}}
	return {}


## 반격 대기에서 봇이 낼 반격 카드: 되갚는 카드를 먼저 고르고(거울의 힘 > 우노 리버스 > 도굴꾼 > 싸이크론 > 포고령 > 빗나감),
## 바이츠 더 더스트는 앞서 나간 말을 잃었을 때만 쓴다. 쓰지 않으면 빈 값.
const COUNTER_PREFERENCE: Array[StringName] = [&"CNT_02", &"CNT_03", &"CNT_07", &"CNT_05", &"CNT_06", &"CNT_04", &"CNT_01"]


static func choose_counter(state: GameState, _player_id: int, cards: Array, entry: Dictionary, _rng: RandomNumberGenerator) -> StringName:
	for card_id: StringName in COUNTER_PREFERENCE:
		if not cards.has(card_id):
			continue
		if card_id == &"CNT_01":
			var lost: int = 0
			for pawn_id: Variant in (entry.get("pawns", {}) as Dictionary).keys():
				var saved: Dictionary = entry["pawns"][pawn_id]
				lost += BoardSpec.tile_count - state.board.distance_to_goal(int(saved["tile"]), bool(saved["started"]))
			if lost < BoardSpec.side:
				continue
		return card_id
	return &""


# ---------------------------------------------------------------------------
# 판정 도구
# ---------------------------------------------------------------------------

## 러시안 룰렛: 빈 총을 pull_target번 당겼으면(누적 칸수 기준) 멈춘다. pull_target은 보통 2~3.
static func should_stop_roulette(tool: BaseJudgmentTool, pull_target: int) -> bool:
	if not (tool is ToolRussianRoulette) or not tool.has_pending_state():
		return false
	return (tool as ToolRussianRoulette).accumulated >= ToolRussianRoulette.STEPS_PER_EMPTY * pull_target


## 야추 다이스: 가장 많이 겹친 눈금(동률이면 높은 눈금)을 고정한다. 겹친 게 없으면 가장 긴 연속 숫자, 그것도 없으면 가장 높은 주사위 하나를 고정한다.
static func yacht_keep_mask(dice: Array) -> Array[bool]:
	var counts: Dictionary = {}
	for face: Variant in dice:
		counts[int(face)] = int(counts.get(int(face), 0)) + 1
	var best_face: int = 0
	var best_count: int = 0
	for face: Variant in counts.keys():
		var count: int = int(counts[face])
		if count > best_count or (count == best_count and int(face) > best_face):
			best_count = count
			best_face = int(face)
	var keep_faces: Dictionary = {}
	if best_count >= 2:
		keep_faces[best_face] = true
	else:
		var faces: Array[int] = []
		for face: Variant in counts.keys():
			faces.append(int(face))
		faces.sort()
		var run: Array[int] = []
		var current: Array[int] = []
		for face: int in faces:
			if not current.is_empty() and face == current[-1] + 1:
				current.append(face)
			else:
				current = [face]
			if current.size() > run.size():
				run = current.duplicate()
		if run.size() >= 3:
			for face: int in run:
				keep_faces[face] = true
		else:
			keep_faces[faces[-1]] = true
	var mask: Array[bool] = []
	var kept_faces: Dictionary = {}
	for face: Variant in dice:
		# 연속 숫자 노림에서는 같은 눈금을 한 개씩만 고정한다
		var keep: bool = keep_faces.has(int(face)) and (best_count >= 2 or not kept_faces.has(int(face)))
		if keep:
			kept_faces[int(face)] = true
		mask.append(keep)
	return mask


## 야추: 다시 굴릴 횟수가 없거나 이미 7칸 이상 족보(스트레이트·풀하우스·포카드·야추)면 확정한다.
static func should_stop_yacht(tool: BaseJudgmentTool) -> bool:
	if not (tool is ToolYacht) or not tool.has_pending_state():
		return false
	var yacht: ToolYacht = tool as ToolYacht
	return yacht.rerolls_left <= 0 or int(ToolYacht.evaluate(yacht.dice)["steps"]) >= ToolYacht.STEPS_SMALL_OR_FULL


## 블랙잭: 합계 16 이하면 히트, 17 이상이면 스탠드.
static func should_hit_blackjack(tool: BaseJudgmentTool) -> bool:
	return tool is ToolBlackjack and tool.has_pending_state() and ToolBlackjack.total_of((tool as ToolBlackjack).cards) <= 16


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
		total += maxf(0.0, float(BoardSpec.tile_count - state.pawn_progress_distance(member)))
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
		&"fianchetto":
			var corner: int = PawnSkills.fianchetto_tile(pawn)
			if corner == -1:
				return {}
			return {"params": {}, "value": float(state.pawn_progress_distance(pawn) - state.board.distance_to_goal(corner, true))}
		&"bank_shot":
			var route: Array[int] = PawnSkills.bank_shot_path(state, pawn)
			if route.is_empty():
				return {}
			var target: float = 0.0
			for leader: PlayerPawn in state.leaders_at(route.back()):
				if leader.owner_id != pawn.owner_id and not MoveExecutor.is_capture_immune(state, leader):
					target += pawn_progress(state, leader)
			return {"params": {}, "value": target + float(route.size())} if target > 0.0 else {}
		&"slash", &"horse":
			var hits: float = 0.0
			for tile: int in PawnSkills.strike_tiles(pawn, PawnCatalog.skill_of(pawn.sub_type())):
				for leader: PlayerPawn in state.leaders_at(tile):
					if leader.owner_id != pawn.owner_id and leader.has_left_start:
						hits += pawn_progress(state, leader)
			return {"params": {}, "value": hits} if hits > 0.0 else {}
		&"quake":
			var hostile: int = PawnSkills.attachments_on(state, pawn, PawnSkills.quake_tiles(pawn), true)
			var mine: int = PawnSkills.attachments_on(state, pawn, PawnSkills.quake_tiles(pawn)) - hostile
			return {"params": {}, "value": SKILL_USE_THRESHOLD + 4.0 * float(hostile - mine)} if hostile > mine else {}
		&"plant_mine":
			return {"params": {}, "value": SKILL_USE_THRESHOLD + 1.0} if not state.board.get_tile(pawn.current_tile_idx).has_trap() else {}
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
