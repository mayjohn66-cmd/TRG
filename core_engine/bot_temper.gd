# File: res://core_engine/bot_temper.gd
# Class: class_name BotTemper
# Role: 놀이터(컴퓨터 대전) 난이도에 따른 봇 판단 보정 (억까 방지). BotBrain이 고른 최선의 수를 사람에게 덜 맵게 다듬는다. 게임 상태는 바꾸지 않는다.
#       순한맛(MILD): 사람 말을 잡을 수 있어도 45%는 다른 말을 전진, 사람을 노리는 공격 카드는 70% 덜 쓰고, 특수 승리(법전) 증강을 앞세우지 않는다.
#       보통맛(NORMAL): 1위 우선 견제 + 연속 처치 자비만 (표준).
#       마라맛(SPICY): 보정 없이 BotBrain 그대로 (예전 봇).
#       공통(순한맛·보통맛): ① 1위 우선 견제 - 사람이 3~4위로 처져 있으면 사람 말을 잡는 수·사람을 노리는 카드의 우선순위를 크게 낮추고, 대상을 고르는 카드는 1위에게 돌린다.
#                          ② 연속 처치 자비 - 사람 말이 잡힌 뒤 2라운드 안에는 사람 말을 또 잡는 수·카드를 보통맛 50% / 순한맛 80%로 거른다.
class_name BotTemper
extends RefCounted

const MILD: StringName = &"mild"
const NORMAL: StringName = &"normal"
const SPICY: StringName = &"spicy"
const ALL: Array[StringName] = [MILD, NORMAL, SPICY]
const LABELS: Dictionary = {MILD: "순한맛", NORMAL: "보통맛", SPICY: "마라맛"}

## 순한맛: 사람 말을 잡을 수 있어도 다른 말을 전진할 확률.
const MILD_SPARE_CHANCE: float = 0.45
## 순한맛: 사람을 노리는 공격 카드를 거르는 확률.
const MILD_CARD_SPARE_CHANCE: float = 0.7
## 연속 처치 자비: 사람 말이 잡힌 뒤 이 라운드 수 안에는 봐준다.
const MERCY_ROUNDS: int = 2
const MERCY_CHANCE: Dictionary = {MILD: 0.8, NORMAL: 0.5}
## 1위 우선 견제: 사람이 이 순위 이하(3·4위)로 처져 있으면 사람 말을 잡는 수의 점수를 이만큼 깎는다.
const TRAILING_RANK: int = 3
const TRAILING_CAPTURE_PENALTY: float = 45.0
## 1위의 말을 잡는 수에 더하는 점수.
const LEADER_CAPTURE_BONUS: float = 15.0
## 대상을 고르는 공격 카드.
const TARGETED_ATTACKS: Array[StringName] = [&"ACT_02", &"ACT_09", &"ACT_14", &"ACT_15"]


static func sanitize(value: StringName) -> StringName:
	return value if ALL.has(value) else NORMAL


static func label(value: StringName) -> String:
	return str(LABELS.get(sanitize(value), "보통맛"))


static func softened(difficulty: StringName) -> bool:
	return difficulty == MILD or difficulty == NORMAL


## 레이스 순위 (1부터): 완주한 말이 많을수록, 남은 거리 합이 짧을수록 앞. 졸업한 사람은 뺀다. 레이스에 없으면 0.
static func race_rank(state: GameState, player_id: int) -> int:
	var standings: Array = []
	for candidate: int in state.player_ids:
		if state.rankings.has(candidate):
			continue
		var remaining: int = 0
		for pawn: PlayerPawn in state.pawns_of(candidate):
			if not pawn.is_finished:
				remaining += state.pawn_progress_distance(pawn)
		standings.append([-state.finished_count(candidate), remaining, candidate])
	standings.sort()
	for index: int in standings.size():
		if int(standings[index][2]) == player_id:
			return index + 1
	return 0


## 사람 말이 최근(MERCY_ROUNDS 라운드 안)에 적에게 잡혔는가.
static func recently_hit(state: GameState, player_id: int) -> bool:
	var stats: Dictionary = state.law_stats.get(player_id, {})
	if not stats.has(GameState.LAST_HIT_ROUND):
		return false
	return state.round_number - int(stats[GameState.LAST_HIT_ROUND]) <= MERCY_ROUNDS


## 이 사람을 노리는 행동을 거를 확률 (0이면 거르지 않는다).
static func spare_chance(state: GameState, difficulty: StringName, human: int, base: float) -> float:
	if not softened(difficulty):
		return 0.0
	var chance: float = base if difficulty == MILD else 0.0
	if recently_hit(state, human):
		chance = maxf(chance, float(MERCY_CHANCE.get(difficulty, 0.0)))
	return chance


## 이 말이 이번 눈금으로 도착하는 칸에서 잡게 될 사람들 (잡기 면역 제외).
static func humans_caught_by(state: GameState, pawn: PlayerPawn, dice_value: int, humans: Array[int]) -> Array[int]:
	var caught: Array[int] = []
	var path: Array[int] = MoveExecutor.preview_path(state, pawn, dice_value)
	if path.is_empty() or path.back() == GameEnums.GOAL_TILE:
		return caught
	for other: PlayerPawn in state.leaders_at(path.back()):
		if other.owner_id != pawn.owner_id and humans.has(other.owner_id) and not MoveExecutor.is_capture_immune(state, other) and not caught.has(other.owner_id):
			caught.append(other.owner_id)
	return caught


## 말 고르기: 마라맛이면 BotBrain 그대로. 아니면 1위 우선 견제로 점수를 다듬고, 사람 말을 잡는 수면 확률로 다른 말을 움직인다.
static func choose_pawn(state: GameState, player_id: int, dice_value: int, difficulty: StringName, humans: Array[int], rng: RandomNumberGenerator) -> int:
	if not softened(difficulty) or humans.is_empty():
		return BotBrain.choose_pawn(state, player_id, dice_value)
	var leader: int = state.race_leader(player_id)
	var options: Array[Dictionary] = []
	for pawn: PlayerPawn in state.selectable_pawns(player_id, dice_value):
		var score: float = BotBrain.score_move(state, pawn, dice_value)
		var caught: Array[int] = humans_caught_by(state, pawn, dice_value, humans)
		for human: int in caught:
			if race_rank(state, human) >= TRAILING_RANK:
				score -= TRAILING_CAPTURE_PENALTY  # 뒤처진 사람을 더 밟지 않는다
		var path: Array[int] = MoveExecutor.preview_path(state, pawn, dice_value)
		if not path.is_empty() and leader != -1 and BotBrain.has_capturable_enemy(state, pawn, path.back()):
			for other: PlayerPawn in state.leaders_at(path.back()):
				if other.owner_id == leader:
					score += LEADER_CAPTURE_BONUS
					break
		options.append({"id": pawn.entity_id, "score": score, "caught": caught})
	if options.is_empty():
		return -1
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]) if float(a["score"]) != float(b["score"]) else int(a["id"]) < int(b["id"]))
	var best: Dictionary = options[0]
	var caught_best: Array = best["caught"]
	if caught_best.is_empty():
		return int(best["id"])
	var chance: float = 0.0
	for human: int in caught_best:
		chance = maxf(chance, spare_chance(state, difficulty, human, MILD_SPARE_CHANCE))
	if chance > 0.0 and rng.randf() < chance:
		for option: Dictionary in options:
			if (option["caught"] as Array).is_empty():
				return int(option["id"])  # 사람 말을 잡지 않는 다음 수 (단순 전진)
	return int(best["id"])


## 이 카드 계획이 노리는 사람들.
static func humans_targeted(state: GameState, player_id: int, plan: Dictionary, humans: Array[int]) -> Array[int]:
	var targets: Array[int] = []
	var params: Dictionary = plan.get("params", {})
	var card_id: StringName = plan.get("card_id", &"")
	if params.has("target_player") and humans.has(int(params["target_player"])):
		targets.append(int(params["target_player"]))
	elif card_id == &"ACT_03":
		var victim: int = PenaltyBombCommand.victim_of(state, player_id)
		if humans.has(victim):
			targets.append(victim)
	elif card_id == &"ACT_10":
		for tile: int in CrowbarCommand.reach_tiles(state, player_id):
			for leader: PlayerPawn in state.leaders_at(tile):
				if humans.has(leader.owner_id) and leader.has_left_start and not targets.has(leader.owner_id):
					targets.append(leader.owner_id)
	return targets


## 턴 시작 카드 계획 다듬기: 사람을 노리면 1위 우선 견제(대상을 고르는 카드는 1위에게 돌린다)와 순한맛·자비 확률로 거른다. 거르면 빈 Dictionary.
static func filter_card_plan(state: GameState, player_id: int, plan: Dictionary, difficulty: StringName, humans: Array[int], rng: RandomNumberGenerator) -> Dictionary:
	if plan.is_empty() or not softened(difficulty) or humans.is_empty():
		return plan
	var targets: Array[int] = humans_targeted(state, player_id, plan, humans)
	if targets.is_empty():
		return plan
	var card_id: StringName = plan["card_id"]
	var card: BaseCard = CardRegistry.get_card(card_id)
	var leader: int = state.race_leader(player_id)
	if TARGETED_ATTACKS.has(card_id) and leader != -1 and not humans.has(leader) and race_rank(state, targets[0]) != 1:
		var retarget: Dictionary = plan.duplicate(true)
		(retarget["params"] as Dictionary)["target_player"] = leader
		if card.is_legal(state, player_id, retarget["params"]):
			return retarget  # 사람 대신 1위(다른 봇)를 노린다
	var chance: float = 0.0
	for human: int in targets:
		var trailing: float = 0.6 if race_rank(state, human) >= TRAILING_RANK else 0.0
		chance = maxf(chance, maxf(trailing, spare_chance(state, difficulty, human, MILD_CARD_SPARE_CHANCE)))
	if chance > 0.0 and rng.randf() < chance:
		return {}
	return plan


## 순한맛 드래프트: 특수 승리(법전) 증강을 앞세우지 않는다 (다른 선택지가 있으면 그중에서 고른다).
static func choose_augment(state: GameState, player_id: int, offers: Array[StringName], difficulty: StringName, rng: RandomNumberGenerator) -> int:
	var index: int = BotBrain.choose_augment(state, player_id, offers, rng)
	if difficulty != MILD or offers.is_empty():
		return index
	var chosen: AugmentDef = AugmentRegistry.get_def(offers[index])
	if chosen == null or chosen.category != GameEnums.AugmentCategory.LAW_ENACT:
		return index
	var best: int = -1
	var best_score: float = -INF
	for candidate: int in offers.size():
		var definition: AugmentDef = AugmentRegistry.get_def(offers[candidate])
		if definition == null or definition.category == GameEnums.AugmentCategory.LAW_ENACT:
			continue
		var score: float = BotBrain.score_augment(state, player_id, definition)
		if score > best_score:
			best_score = score
			best = candidate
	return best if best != -1 else index
