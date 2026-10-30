# File: res://core_engine/bot_temper.gd
# Class: class_name BotTemper
# Role: 놀이터(컴퓨터 대전) 난이도 = 불닭 매운맛 지표 Fire Level 1~5. BotBrain이 고른 최선의 수를 단계별 파라미터 표(LEVELS)대로 다듬는다.
#       게임 상태는 바꾸지 않는다. 단계마다 다른 것은 표의 숫자뿐이고, 판단 함수는 하나다.
#       Lv.1 크림: 사람 말을 잡을 수 있어도 70%는 다른 말을 전진, 사람을 노리는 공격 카드 80% 거름, 법전 증강을 앞세우지 않음.
#       Lv.2 로제: 자비 35%. 사람이 1등이 아니면 사람 말을 덜 노리고(공격 카드는 1위 봇에게 돌림) AI끼리 고르게 싸운다.
#       Lv.3 오리지널: 자비 0%, 보정 없는 공정 경쟁 + 지금 1등(사람이든 봇이든) 최우선 견제.
#       Lv.4 마라: 자비 0% + 공격 카드·함정·필살기 적극성 최대 (카드 계획을 여러 번 검토, 필살기 문턱을 낮춤, 잡는 수에 가산).
#       Lv.5 핵불닭: Lv.4 + 사람(P1)에 대한 공격 가중치 2배 (잡는 수·대상 카드·함정 위치·이의 있음을 사람에게 몰아준다).
#       Lv.0(RAW)은 고를 수 없는 내부 값으로 BotBrain 그대로다 (온라인 빈자리 봇·테스트).
class_name BotTemper
extends RefCounted

const RAW: int = 0
const LEVEL_MIN: int = 1
const LEVEL_MAX: int = 5
const DEFAULT_LEVEL: int = 2
## 히든 법전 브레이크 감점 (PacingDirector.capture_would_win_law): 다른 말을 움직일 수 있으면 그쪽을 고른다.
const LAW_BRAKE_PENALTY: float = 400.0
## 드래프트에서 가장 좋은 선택지가 법전일 때 그대로 고르는 확률 (나머지는 법전이 아닌 가장 좋은 증강). 2026-10-27: 0.25 → 1.5배.
const LAW_PICK_CHANCE: float = 0.375
const ALL: Array[int] = [1, 2, 3, 4, 5]

## 단계 이름 (원문 한국어, 화면에서 번역).
const NAMES: Dictionary = {1: "크림", 2: "로제", 3: "오리지널", 4: "마라", 5: "핵불닭"}
## 디스코드 통계에 쓰는 이름 (번역하지 않는다).
const TAGS: Dictionary = {0: "AI", 1: "Lv.1 크림", 2: "Lv.2 로제", 3: "Lv.3 오리지널", 4: "Lv.4 마라", 5: "Lv.5 핵불닭"}

## 단계별 파라미터 표.
##  spare        사람 말을 잡는 수가 최선이어도 다른 말을 전진할 확률 (자비 확률)
##  card_spare   사람을 노리는 공격 카드를 거를 확률
##  recent_mercy 사람 말이 방금(MERCY_ROUNDS 안) 잡혔으면 봐줄 확률 (spare·card_spare와 큰 쪽)
##  protect_rank 사람이 이 순위 이하(2 = 1등이 아니면)면 사람 말을 잡는 수를 깎고 공격 카드를 1위 봇에게 돌린다 (0이면 보호 없음)
##  leader_bonus 1위의 말을 잡는 수에 더하는 점수
##  kill_bonus   아무 적 말이나 잡는 수에 더하는 점수 (킬각 우선)
##  human_weight 사람에 대한 공격 가중치 (2.0이면 사람을 두 배로 위협적으로 본다)
##  card_passes  턴 시작 카드 계획을 검토하는 횟수 (확률로 미룬 카드를 다시 굴린다 = 카드 사용 확률 증가)
##  skill_bar    1회용 필살기를 쓰는 최소 가치 (낮을수록 적극적)
##  avoid_law    드래프트에서 특수 승리(법전) 증강을 앞세우지 않는다
const LEVELS: Dictionary = {
	0: {"spare": 0.0, "card_spare": 0.0, "recent_mercy": 0.0, "protect_rank": 0, "leader_bonus": 0.0, "kill_bonus": 0.0, "human_weight": 1.0, "card_passes": 1, "skill_bar": 12.0, "avoid_law": false},
	1: {"spare": 0.70, "card_spare": 0.80, "recent_mercy": 0.8, "protect_rank": 2, "leader_bonus": 15.0, "kill_bonus": 0.0, "human_weight": 1.0, "card_passes": 1, "skill_bar": 12.0, "avoid_law": true},
	2: {"spare": 0.35, "card_spare": 0.35, "recent_mercy": 0.5, "protect_rank": 2, "leader_bonus": 15.0, "kill_bonus": 0.0, "human_weight": 1.0, "card_passes": 1, "skill_bar": 12.0, "avoid_law": false},
	3: {"spare": 0.0, "card_spare": 0.0, "recent_mercy": 0.0, "protect_rank": 0, "leader_bonus": 25.0, "kill_bonus": 0.0, "human_weight": 1.0, "card_passes": 1, "skill_bar": 12.0, "avoid_law": false},
	4: {"spare": 0.0, "card_spare": 0.0, "recent_mercy": 0.0, "protect_rank": 0, "leader_bonus": 25.0, "kill_bonus": 20.0, "human_weight": 1.0, "card_passes": 3, "skill_bar": 6.0, "avoid_law": false},
	5: {"spare": 0.0, "card_spare": 0.0, "recent_mercy": 0.0, "protect_rank": 0, "leader_bonus": 25.0, "kill_bonus": 20.0, "human_weight": 2.0, "card_passes": 3, "skill_bar": 6.0, "avoid_law": false},
}

## 연속 처치 자비: 사람 말이 잡힌 뒤 이 라운드 수 안에는 봐준다.
const MERCY_ROUNDS: int = 2
## 보호받는 사람의 말을 잡는 수에서 깎는 점수.
const PROTECT_PENALTY: float = 45.0
## 보호받는 사람이 3위 이하로 처져 있으면 사람을 노리는 카드를 이 확률로 거른다.
const TRAILING_RANK: int = 3
const TRAILING_CARD_SPARE: float = 0.6
## 대상을 고르는 공격 카드.
const TARGETED_ATTACKS: Array[StringName] = [&"ACT_02", &"ACT_09", &"ACT_14", &"ACT_15"]


## 저장값·옛 값(mild/normal/spicy)을 1~5로. 모르는 값은 기본 단계.
static func sanitize(value: Variant) -> int:
	match str(value):
		"mild":
			return 1
		"normal":
			return 2
		"spicy":
			return 4
	var level: int = int(value) if (value is int or value is float or str(value).is_valid_int()) else DEFAULT_LEVEL
	return level if ALL.has(level) else DEFAULT_LEVEL


static func params(level: int) -> Dictionary:
	return LEVELS.get(level, LEVELS[RAW])


## 화면 이름 "Lv.3 오리지널" (Lv.과 이름을 따로 번역해 붙인다).
static func label(level: int) -> String:
	var safe: int = sanitize(level)
	return "Lv.%d %s" % [safe, L10n.t(str(NAMES[safe]))]


## 디스코드 통계 태그 "[Lv.3 오리지널]" (언어와 상관없이 한국어).
static func tag(level: int) -> String:
	return "[%s]" % str(TAGS.get(level, TAGS[RAW]))


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


## 이 사람을 노리는 행동을 거를 확률. key: "spare"(말 잡기) 또는 "card_spare"(공격 카드).
static func spare_chance(state: GameState, level: int, human: int, key: String) -> float:
	var table: Dictionary = params(level)
	var chance: float = float(table[key])
	if recently_hit(state, human):
		chance = maxf(chance, float(table["recent_mercy"]))
	return chance


## 사람이 보호받는 순위인가 (Lv.1·2: 1등이 아니면).
static func protected(state: GameState, level: int, human: int) -> bool:
	var rank_limit: int = int(params(level)["protect_rank"])
	return rank_limit > 0 and race_rank(state, human) >= rank_limit


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


## 말 고르기: BotBrain 점수에 표의 보정(보호·1위 견제·킬각·사람 가중치)을 더하고, 사람 말을 잡는 수면 자비 확률로 다른 말을 움직인다.
static func choose_pawn(state: GameState, player_id: int, dice_value: int, level: int, humans: Array[int], rng: RandomNumberGenerator) -> int:
	var table: Dictionary = params(level)
	if level == RAW:
		return BotBrain.choose_pawn(state, player_id, dice_value)
	var leader: int = state.race_leader(player_id)
	var options: Array[Dictionary] = []
	for pawn: PlayerPawn in state.selectable_pawns(player_id, dice_value):
		var score: float = BotBrain.score_move(state, pawn, dice_value)
		var caught: Array[int] = humans_caught_by(state, pawn, dice_value, humans)
		for human: int in caught:
			if protected(state, level, human):
				score -= PROTECT_PENALTY  # 처진 사람을 더 밟지 않는다
			# 사람 가중치: 사람 말을 잡는 값(잡기 점수 + 1위 견제 점수)을 가중치 배로 본다
			score += (BotBrain.SCORE_CAPTURE + float(table["leader_bonus"])) * (float(table["human_weight"]) - 1.0)
		var path: Array[int] = MoveExecutor.preview_path(state, pawn, dice_value)
		if not path.is_empty() and BotBrain.has_capturable_enemy(state, pawn, path.back()):
			score += float(table["kill_bonus"])
			for victim: PlayerPawn in state.leaders_at(path.back()):
				if victim.owner_id != player_id and PacingDirector.capture_would_win_law(state, player_id, victim.owner_id):
					score -= LAW_BRAKE_PENALTY  # 히든 법전 브레이크: 11라운드 전에는 처치형 법전을 끝내는 잡기를 피한다
					break
			if leader != -1:
				for other: PlayerPawn in state.leaders_at(path.back()):
					if other.owner_id == leader:
						score += float(table["leader_bonus"])
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
		chance = maxf(chance, spare_chance(state, level, human, "spare"))
	if chance > 0.0 and rng.randf() < chance:
		for option: Dictionary in options:
			if (option["caught"] as Array).is_empty():
				return int(option["id"])  # 사람 말을 잡지 않는 다음 수 (단순 전진)
	return int(best["id"])


## 턴 시작 카드 계획: 표의 card_passes만큼 BotBrain에게 다시 물어본다 (확률로 미룬 카드를 다시 굴려 사용 확률을 올린다).
## tried: 이번 턴에 이미 검토한 카드 (BotBrain.plan_turn_card와 같음). 앞서 시도한 카드는 다시 굴리지 않는다.
static func plan_turn_card(state: GameState, player_id: int, level: int, tried: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var before: Dictionary = tried.duplicate()
	var plan: Dictionary = BotBrain.plan_turn_card(state, player_id, tried, rng)
	for _pass: int in int(params(level)["card_passes"]) - 1:
		if not plan.is_empty():
			break
		plan = BotBrain.plan_turn_card(state, player_id, before.duplicate(), rng)
	return plan


## 이 카드 계획이 노리는 사람들.
static func humans_targeted(state: GameState, player_id: int, plan: Dictionary, humans: Array[int]) -> Array[int]:
	var targets: Array[int] = []
	var plan_params: Dictionary = plan.get("params", {})
	var card_id: StringName = plan.get("card_id", &"")
	if plan_params.has("target_player") and humans.has(int(plan_params["target_player"])):
		targets.append(int(plan_params["target_player"]))
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


## 턴 시작 카드 계획 다듬기. 사람 가중치가 1배를 넘으면 사람에게 몰아주고(focus_human),
## 보호받는 사람을 노리면 1위 봇에게 돌리거나, 자비 확률로 거른다. 거르면 빈 Dictionary.
static func filter_card_plan(state: GameState, player_id: int, plan: Dictionary, level: int, humans: Array[int], rng: RandomNumberGenerator) -> Dictionary:
	if humans.is_empty() or level == RAW:
		return plan
	if float(params(level)["human_weight"]) > 1.0:
		return focus_human(state, player_id, plan, level, humans)
	if plan.is_empty():
		return plan
	var targets: Array[int] = humans_targeted(state, player_id, plan, humans)
	if targets.is_empty():
		return plan
	var card_id: StringName = plan["card_id"]
	var card: BaseCard = CardRegistry.get_card(card_id)
	var leader: int = state.race_leader(player_id)
	if TARGETED_ATTACKS.has(card_id) and leader != -1 and not humans.has(leader) and protected(state, level, targets[0]):
		var retarget: Dictionary = plan.duplicate(true)
		(retarget["params"] as Dictionary)["target_player"] = leader
		if card.is_legal(state, player_id, retarget["params"]):
			return retarget  # 사람 대신 1위(다른 봇)를 노린다
	var chance: float = 0.0
	for human: int in targets:
		var trailing: float = TRAILING_CARD_SPARE if protected(state, level, human) and race_rank(state, human) >= TRAILING_RANK else 0.0
		chance = maxf(chance, maxf(trailing, spare_chance(state, level, human, "card_spare")))
	if chance > 0.0 and rng.randf() < chance:
		return {}
	return plan


## 사람 가중치(핵불닭): 대상 카드는 사람이 (가중치로 나눈) 거리로도 가장 앞서면 사람에게, 함정·소환은 사람 선두 말 2~3칸 앞에,
## 사람이 법전 목표에 다가가면(가중치를 곱한 진행률이 절반을 넘으면) 들고 있는 [이의 있음!]으로 사람의 기록을 지운다.
static func focus_human(state: GameState, player_id: int, plan: Dictionary, level: int, humans: Array[int]) -> Dictionary:
	var weight: float = float(params(level)["human_weight"])
	var objection: Dictionary = _objection_on_human(state, player_id, weight, humans)
	if not objection.is_empty() and (plan.is_empty() or plan["card_id"] != &"ACT_06"):
		return objection
	if plan.is_empty():
		return plan
	var card_id: StringName = plan["card_id"]
	var card: BaseCard = CardRegistry.get_card(card_id)
	var plan_params: Dictionary = plan.get("params", {})
	if TARGETED_ATTACKS.has(card_id) and plan_params.has("target_player"):
		var current: int = int(plan_params["target_player"])
		for human: int in humans:
			if human == current or human == player_id:
				continue
			var human_front: PlayerPawn = state.front_pawn_of(human)
			var current_front: PlayerPawn = state.front_pawn_of(current)
			if human_front == null:
				continue
			var human_threat: float = float(state.pawn_progress_distance(human_front)) / weight
			var current_threat: float = float(state.pawn_progress_distance(current_front)) if current_front != null else INF
			var retarget: Dictionary = {"card_id": card_id, "params": plan_params.duplicate(true)}
			(retarget["params"] as Dictionary)["target_player"] = human
			if human_threat <= current_threat and card.is_legal(state, player_id, retarget["params"]):
				return retarget
	elif card.needs_tile() and plan_params.has("tile"):
		for human: int in humans:
			var front: PlayerPawn = state.front_pawn_of(human)
			if front == null or front.is_finished or not front.has_left_start:
				continue
			for ahead: int in [2, 3, 1, 4]:
				var path: Array[int] = state.board.calculate_path(front, ahead, RuleContext.new())
				if path.is_empty():
					continue
				if card.is_legal(state, player_id, {"tile": path.back()}):
					return {"card_id": card_id, "params": {"tile": path.back()}}
	return plan


static func _objection_on_human(state: GameState, player_id: int, weight: float, humans: Array[int]) -> Dictionary:
	if not (state.hands[player_id] as Array).has(&"ACT_06") or state.is_banned(player_id):
		return {}
	var card: BaseCard = CardRegistry.get_card(&"ACT_06")
	var best: Dictionary = {}
	var best_ratio: float = 0.5
	for choice: Dictionary in CardObjection.choices(state):
		var target: int = int(choice["target_player"])
		if not humans.has(target) or target == player_id:
			continue
		var law: VictoryLaw = LawRegistry.create(choice["law_id"]) as VictoryLaw
		var ratio: float = float(law.progress(state, target)) / float(law.goal()) * weight
		if ratio > best_ratio and card.is_legal(state, player_id, choice):
			best_ratio = ratio
			best = {"card_id": &"ACT_06", "params": choice}
	return best


## 1회용 필살기 계획: 표의 skill_bar보다 가치가 높을 때만.
static func plan_skill(state: GameState, player_id: int, level: int) -> Dictionary:
	return BotBrain.plan_skill(state, player_id, float(params(level)["skill_bar"]))


## 드래프트: avoid_law 단계는 특수 승리(법전) 증강을 앞세우지 않는다 (다른 선택지가 있으면 그중에서 고른다).
static func choose_augment(state: GameState, player_id: int, offers: Array[StringName], level: int, rng: RandomNumberGenerator) -> int:
	var index: int = BotBrain.choose_augment(state, player_id, offers, rng)
	if offers.is_empty():
		return index
	var chosen: AugmentDef = AugmentRegistry.get_def(offers[index])
	if chosen == null or chosen.category != GameEnums.AugmentCategory.LAW_ENACT:
		return index
	# 법전은 가끔만: avoid_law 단계는 안 고르고, 나머지도 LAW_PICK_CHANCE 확률로만 고른다 (기물 진화·도구 교체가 먼저)
	if not bool(params(level)["avoid_law"]) and rng.randf() < LAW_PICK_CHANCE:
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
