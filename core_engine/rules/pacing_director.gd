# File: res://core_engine/rules/pacing_director.gd
# Class: class_name PacingDirector
# Role: 🕵️ 난이도별 히든 페이싱 디렉터. 화면에 보너스를 띄우지 않고, 판정 도구의 굴림을 몰래 다시 굴려 판 길이를 12~16라운드로 맞춘다.
#       결과는 언제나 그 도구가 실제로 굴린 결과(주사위 눈·카드·릴 그대로)라 화면과 이동이 어긋나지 않는다. 호스트 RNG만 써서 락스텝·재현이 같다.
#       MatchRules.pacing (0 = 끄기: 친선전·커스텀 기본, 1~5 = 싱글 불닭 난이도)이 정한다.
#       - Lv.1 크림 (사람 자리만, GameState.pacing_humans): 3칸 이하가 나오면 확률로 4칸 이상 재굴림. 완주한 말이 많을수록, 컴퓨터보다 먼저 완주했으면
#         확률이 더 오른다. 턴이 끝나는 결과(낙·삐끗 등)는 확률로 다시 굴리고, 턴 종료를 당할수록 다음 턴 종료는 더 잘 피한다.
#         법전은 투기장의 지배자·봉인된 에르핀의 식권 2종만 (MatchRules.law_pool). 드래프트에서 고르면 바로 이기는 법전은 등장 가중치를 크게 올린다.
#       - Lv.2~3: 11라운드부터 라운드마다 15%p씩(최대 90%) 3칸 이하를 4칸 이상으로 재굴림
#       - Lv.4~5: 잡혀서 다시 출발한 말이 반환점에 닿기 전이면, 4칸 이하가 나올 때 60%로 5칸 이상 재굴림
#       - 공통 서든데스: 15라운드부터 3칸 이하는 4칸 이상으로 재굴림(최소 4칸 보장 수준), 20라운드가 끝나면 남은 사람은 진행 순위로 확정 (TurnManager)
class_name PacingDirector
extends RefCounted

## 다시 굴려도 상태가 꼬이지 않는 도구 (한 번 굴리고 끝나는 도구만). 야추·블랙잭·러시안 룰렛(이어 굴리기)과 화투·타로(다음 굴림에 이어지는 상태)는 손대지 않는다.
const REROLL_TOOLS: Array[StringName] = [&"D6", &"YUT", &"LIFE_ROULETTE", &"HOLDEM", &"CHINCHIRO", &"SLOT_777", &"DICE_MAHJONG", &"DICE_PINBALL"]
## 목표 눈금이 나올 때까지 다시 굴리는 최대 횟수 (못 나오면 그중 가장 큰 결과).
const MAX_TRIES: int = 10
const HIGH_STEPS: int = 4
const COMEBACK_STEPS: int = 5
## 크림 고눈금: 기본 확률 + 완주한 말마다 + 컴퓨터보다 먼저 완주했으면 더 (최대 CREAM_HIGH_MAX).
const CREAM_HIGH_BASE: float = 0.4
const CREAM_HIGH_PER_FINISH: float = 0.15
const CREAM_HIGH_LEAD: float = 0.15
const CREAM_HIGH_MAX: float = 0.95
## 크림 턴 종료 회피: 기본 확률 + 이미 당한 턴 종료마다 (최대 CREAM_DODGE_MAX).
const CREAM_DODGE_BASE: float = 0.5
const CREAM_DODGE_PER_HIT: float = 0.15
const CREAM_DODGE_MAX: float = 0.95
## 크림 드래프트: 고르면 바로 이기는 법전의 등장 가중치 배수.
const CREAM_WINNING_LAW_FACTOR: float = 25.0
const LATE_FROM_ROUND: int = 11
const LATE_STEP_CHANCE: float = 0.15
const LATE_MAX_CHANCE: float = 0.9
const COMEBACK_CHANCE: float = 0.6
## 서든데스: 이 라운드부터 모두 최소 4칸 수준. HARD_CAP_ROUND가 끝나면 남은 사람은 진행 순위로 확정한다.
const SUDDEN_DEATH_ROUND: int = 15
const HARD_CAP_ROUND: int = 20
## 법전 브레이크: 이 라운드 전에는 컴퓨터가 법전 달성 직전의 수를 피한다 (BotTemper).
const LAW_BRAKE_BEFORE_ROUND: int = 11


static func level(state: GameState) -> int:
	return int(MatchRules.of(state).get("pacing", 0))


static func enabled(state: GameState) -> bool:
	return level(state) > 0


## 굴림 결과를 난이도별로 몰래 보정한다. 보정하지 않으면 그대로 돌려준다.
static func adjust(state: GameState, player_id: int, tool: BaseJudgmentTool, result: RollResult) -> RollResult:
	var lv: int = level(state)
	if lv <= 0 or result == null or result.can_continue or not REROLL_TOOLS.has(tool.tool_id):
		return result
	var cream_human: bool = lv == 1 and is_human(state, player_id)
	if cream_human and result.ends_turn:
		result = _dodge_turn_end(state, player_id, tool, result)
	var target: int = _target_steps(state, player_id, lv, result)
	if target > 0 and _steps_of(result) < target:
		result = _reroll_until(tool, state.rng, target, result)
	if cream_human and result.ends_turn:
		state.pacing_turn_ends[player_id] = int(state.pacing_turn_ends.get(player_id, 0)) + 1  # 당할수록 다음 턴 종료는 더 잘 피한다
	return result


## 사람 자리인가 (AI 대전의 내 자리). 크림 보정은 사람에게만 준다.
static func is_human(state: GameState, player_id: int) -> bool:
	return state.pacing_humans.has(player_id)


## 크림: 턴이 끝나는 결과를 확률로 다시 굴린다 (이미 당한 턴 종료가 많을수록 확률이 오른다).
static func _dodge_turn_end(state: GameState, player_id: int, tool: BaseJudgmentTool, result: RollResult) -> RollResult:
	var hits: int = int(state.pacing_turn_ends.get(player_id, 0))
	if state.rng.randf() < minf(CREAM_DODGE_BASE + CREAM_DODGE_PER_HIT * float(hits), CREAM_DODGE_MAX):
		for _try: int in MAX_TRIES:
			var next: RollResult = tool.roll(state.rng)
			if not next.ends_turn:
				return next
	return result


## 크림 고눈금 확률: 완주한 말이 많을수록, 컴퓨터보다 먼저 완주했으면 더 높다.
static func cream_high_chance(state: GameState, player_id: int) -> float:
	var finished: int = state.finished_count(player_id)
	var chance: float = CREAM_HIGH_BASE + CREAM_HIGH_PER_FINISH * float(finished)
	if finished > 0:
		var ahead: bool = true
		for other: int in state.player_ids:
			if other != player_id and not state.is_graduated(other) and state.finished_count(other) >= finished:
				ahead = false
				break
		if ahead:
			chance += CREAM_HIGH_LEAD
	return minf(chance, CREAM_HIGH_MAX)


## 크림 드래프트: 사람이 지금 고르면 바로 이기는 법전(처치 수·빵집 방문 수를 이미 채웠다)은 등장 가중치를 크게 올린다.
static func law_offer_factor(state: GameState, player_id: int, def: AugmentDef) -> float:
	if level(state) != 1 or def.category != GameEnums.AugmentCategory.LAW_ENACT or not is_human(state, player_id):
		return 1.0
	var law_id: String = String(def.payload)
	if not VictoryLaw.is_victory_id(law_id) or state.rulebook.has_law(law_id):
		return 1.0
	var law := VictoryLaw.new(law_id)
	return CREAM_WINNING_LAW_FACTOR if law.progress(state, player_id) >= law.goal() else 1.0


## 이번 굴림이 노릴 최소 눈금 (0 = 보정 없음). 확률 판정은 호스트 RNG로 한다.
static func _target_steps(state: GameState, player_id: int, lv: int, result: RollResult) -> int:
	var steps: int = _steps_of(result)
	var round_number: int = state.round_number
	var target: int = 0
	if round_number >= SUDDEN_DEATH_ROUND and steps < HIGH_STEPS:
		return HIGH_STEPS
	match lv:
		1:
			if is_human(state, player_id) and steps < HIGH_STEPS and state.rng.randf() < cream_high_chance(state, player_id):
				target = HIGH_STEPS
		2, 3:
			if round_number >= LATE_FROM_ROUND and steps < HIGH_STEPS:
				var chance: float = minf(LATE_STEP_CHANCE * float(round_number - LATE_FROM_ROUND + 1), LATE_MAX_CHANCE)
				if state.rng.randf() < chance:
					target = HIGH_STEPS
		_:
			if steps < COMEBACK_STEPS and has_comeback(state, player_id) and state.rng.randf() < COMEBACK_CHANCE:
				target = COMEBACK_STEPS
	return target


## 실제로 전진하는 칸 (낙·꽝처럼 턴이 끝나는 결과는 0칸).
static func _steps_of(result: RollResult) -> int:
	return 0 if result.ends_turn else result.steps


static func _reroll_until(tool: BaseJudgmentTool, rng: RandomNumberGenerator, target: int, original: RollResult) -> RollResult:
	var best: RollResult = original
	for _try: int in MAX_TRIES:
		var next: RollResult = tool.roll(rng)
		if _steps_of(next) >= target:
			return next
		if _steps_of(next) > _steps_of(best):
			best = next
	return best


## 잡혀서 다시 출발한 뒤 아직 반환점에 닿지 않은 내 말이 있는가. 반환점을 넘은 말은 표시를 지운다.
static func has_comeback(state: GameState, player_id: int) -> bool:
	var found: bool = false
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.comeback_run:
			continue
		if pawn.is_finished or (pawn.has_left_start and pawn.current_tile_idx >= BoardSpec.halfway_tile):
			pawn.comeback_run = false
			continue
		found = true
	return found


## 법전 브레이크 (컴퓨터 전용): 11라운드 전에는 이 말로 적을 잡으면 처치형 법전(투기장의 지배자·다크호스)을 바로 달성하는가.
static func capture_would_win_law(state: GameState, player_id: int, victim_owner: int) -> bool:
	if not enabled(state) or state.round_number >= LAW_BRAKE_BEFORE_ROUND:
		return false
	for law: LawResource in state.rulebook.active_laws_queue:
		if not law is VictoryLaw:
			continue
		var victory: VictoryLaw = law
		match victory.stat_key:
			VictoryLaw.KILLS:
				if victory.progress(state, player_id) + 1 >= victory.goal():
					return true
			VictoryLaw.UNDERDOG:
				if state.finished_count(player_id) == 0 and state.race_leader(player_id) == victim_owner and victory.progress(state, player_id) + 1 >= victory.goal():
					return true
	return false


## 법전 브레이크 (컴퓨터 전용): 11라운드 전에는 설치물 하나를 더 놓으면 부동산 재벌을 바로 달성하는가.
static func install_would_win_law(state: GameState, player_id: int) -> bool:
	if not enabled(state) or state.round_number >= LAW_BRAKE_BEFORE_ROUND:
		return false
	for law: LawResource in state.rulebook.active_laws_queue:
		if law is VictoryLaw and (law as VictoryLaw).stat_key == VictoryLaw.ESTATE and (law as VictoryLaw).progress(state, player_id) + 1 >= (law as VictoryLaw).goal():
			return true
	return false


## 연속 굴림 감쇠 (모든 판, 초전도체 무한 동력 밸런스): 이번 턴에 이미 추가 굴림을 얻은 횟수(chain)만큼 또 추가 굴림이 나올 확률을 줄인다.
## 추가 굴림 결과는 CHAIN_KEEP^chain 확률로만 그대로 두고, 아니면 추가 굴림이 아닌 결과가 나올 때까지 같은 도구로 다시 굴린다.
const CHAIN_KEEP: float = 0.6


static func damp_chain(state: GameState, tool: BaseJudgmentTool, result: RollResult, chain: int) -> RollResult:
	if chain <= 0 or result == null or not result.reroll or result.can_continue or not REROLL_TOOLS.has(tool.tool_id):
		return result
	if state.rng.randf() < pow(CHAIN_KEEP, float(chain)):
		return result
	for _try: int in MAX_TRIES:
		var next: RollResult = tool.roll(state.rng)
		if not next.reroll:
			return next
	return result

