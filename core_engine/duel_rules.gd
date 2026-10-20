# File: res://core_engine/duel_rules.gd
# Class: class_name DuelRules
# Role: ACT_09 일기토 데스매치(운명의 데스매치 결투장)의 순수 규칙 - 6종 미니게임 추첨·준비값(카드 순서·신호 시각·폭탄 구멍), 입력 검증, 승패 판정, 결과 문구,
#       승자 +3칸 전진과 패자 선두 말 사출 실행. 입력 대기와 타이머는 TurnManager가, 화면은 DuelArena가 맡는다.
#       순발력 게임은 각자 자기 화면에서 잰 [미니게임 시작부터 누른 시각(ms)]을 한 번 보내고, 엔진은 둘 다 모이면 판정한다 (락스텝·봇 공통).
class_name DuelRules
extends RefCounted

enum Game { RPS, HALLI, CURLING, QUICKDRAW, ECARD, BARREL }
enum Hand { ROCK, SCISSORS, PAPER }

const GAME_COUNT: int = 6
const GAME_NAMES: Array[String] = ["묵찌빠 단두대", "할리갈리 디럭스", "병뚜껑 절벽 컬링", "석양의 무법자", "엘리아스 E카드", "스피키 룰렛"]
const GAME_ICONS: Array[String] = ["✊", "🔔", "🍾", "🔫", "👑", "🛢️"]
const GAME_RULES: Array[String] = [
	"3초 안에 가위·바위·보! 비기면 한 번 더, 또 비기면 신청자 승",
	"두 더미 맨 위 카드의 그림 합이 정확히 5개일 때 먼저 종을 쳐라! (아닐 때 치면 반칙패)",
	"게이지를 멈춰 100%에 가장 가깝게! 100%를 넘으면 절벽 아래로 추락",
	"정적 뒤 [뽑아라!] 신호에 먼저 쏴라! 신호 전에 쏘면 부정출발 패배",
	"신청자는 여왕·평민, 수비자는 반란군·평민 중 한 장! 반란군이 여왕을 잡으면 하극상 +5칸",
	"구멍 5개 중 하나에 폭탄! 번갈아 칼을 꽂아 사도를 튀어 오르게 한 쪽이 패배",
]

const HAND_NAMES: Array[String] = ["바위", "가위", "보"]
## E카드: 신청자 0 여왕 / 1 평민, 수비자 0 반란군 / 1 평민.
const ECARD_CHALLENGER: Array[String] = ["👑 여왕", "🍞 평민"]
const ECARD_DEFENDER: Array[String] = ["💣 반란군", "🍞 평민"]
const ECARD_QUEEN: int = 0
const ECARD_REBEL: int = 0

## 결투 승자의 말이 앞으로 날아가는 칸수 (패자의 선두 말은 출발선으로 사출된다).
const WINNER_ADVANCE: int = 3
## E카드에서 반란군이 여왕을 잡은 하극상 보너스 칸수.
const UPSET_ADVANCE: int = 5
## 가위바위보: 비기면 다시 겨루는 최대 횟수 (이 횟수만큼 연달아 비기면 신청자의 판정승).
const MAX_DRAWS: int = 2

## 할리갈리: 카드가 깔리는 간격(초), 카드 그림 수 범위, 합계 목표.
const HALLI_INTERVAL: float = 0.55
const HALLI_TARGET: int = 5
const HALLI_MAX_CARDS: int = 5
## 순발력 게임: 정답 순간 뒤로 이만큼(초) 지나도 아무도 안 누르면 끝난다.
const REACTION_WINDOW: float = 2.5
## 석양의 무법자: 신호까지의 정적(초) 범위.
const DRAW_MIN: float = 1.5
const DRAW_MAX: float = 3.0
## 병뚜껑 컬링: 게이지 끝(115%)과 한 번 차오르는 시간(초). 값은 0.1% 단위 정수(0~1150)로 주고받는다.
const CURLING_MAX: int = 1150
const CURLING_EDGE: int = 1000
const CURLING_FILL_TIME: float = 1.6
## 스피키 룰렛 구멍 수.
const BARREL_HOLES: int = 5

## 엔진 제한 시간(초, TurnManager.timer_scale이 곱해진다). 화면의 룰렛·안내 시간까지 넉넉히 포함한다.
const TIME_PICK: float = 12.0
const TIME_REACTION: float = 14.0
const TIME_CURLING: float = 16.0
const TIME_BARREL_PICK: float = 8.0
## 화면: 종목 추첨 룰렛과 종목 안내 시간(초).
const ROULETTE_TIME: float = 0.5
const INTRO_TIME: float = 1.1

## 봇 밸런스: 순발력 반응 딜레이(초), 컬링 정밀도(%)와 실수 확률.
const BOT_REACT_MIN: float = 0.38
const BOT_REACT_MAX: float = 0.68
const BOT_CURL_MIN: int = 720
const BOT_CURL_MAX: int = 960
const BOT_CURL_FAIL: float = 0.15


## 승자 말이 앞으로 날아가는 칸 수 (cards_table.csv ACT_09 param_1).
static func winner_advance() -> int:
	return CardRegistry.param(&"ACT_09", WINNER_ADVANCE)


static func game_name(game: int) -> String:
	return GAME_NAMES[clampi(game, 0, GAME_COUNT - 1)]


static func game_title(game: int) -> String:
	return "%s %s" % [GAME_ICONS[clampi(game, 0, GAME_COUNT - 1)], game_name(game)]


## 종목을 고르고 준비값을 만든다. 모든 참가자가 같은 결과를 얻도록 호스트 RNG만 쓴다.
static func setup_game(game: int, rng: RandomNumberGenerator) -> Dictionary:
	match game:
		Game.HALLI:
			return {"cards": halli_cards(rng), "interval": HALLI_INTERVAL}
		Game.QUICKDRAW:
			var signal_at: float = snappedf(rng.randf_range(DRAW_MIN, DRAW_MAX), 0.01)
			var fake_at: float = -1.0
			if rng.randf() < 0.5:
				fake_at = snappedf(rng.randf_range(0.6, maxf(signal_at - 0.5, 0.7)), 0.01)  # 💨 트림! 가짜 신호
			return {"signal": signal_at, "fake": fake_at}
		Game.CURLING:
			return {"fill_time": CURLING_FILL_TIME}
		Game.BARREL:
			return {"bomb": rng.randi_range(0, BARREL_HOLES - 1), "holes": BARREL_HOLES}
	return {}


## 할리갈리 카드 순서: 신청자·수비자 더미에 번갈아 한 장씩 깔린다. 두 더미 맨 위 카드의 그림 합이 처음 5가 되는 순간이 정답이며
## HALLI_MAX_CARDS장 안에 반드시 나온다 (그 뒤로는 더 깔지 않는다). 카드 값은 그림 수 1~4.
static func halli_cards(rng: RandomNumberGenerator) -> Array[int]:
	var hit_at: int = rng.randi_range(2, HALLI_MAX_CARDS) - 1  # 0부터 센 정답 카드 번호 (최소 두 번째 카드)
	var cards: Array[int] = []
	for index: int in hit_at + 1:
		if index == 0:
			cards.append(rng.randi_range(1, 4))
			continue
		var previous: int = cards[index - 1]
		if index == hit_at:
			cards.append(HALLI_TARGET - previous)
			continue
		var options: Array[int] = []
		for value: int in range(1, 5):
			if value + previous != HALLI_TARGET:
				options.append(value)
		cards.append(options[rng.randi_range(0, options.size() - 1)])
	# 정답 카드 값이 1~4를 벗어나지 않게: 앞 카드가 4를 넘을 일은 없으므로 5-앞카드는 언제나 1~4다.
	return cards


## 정답 순간(초): 할리갈리는 마지막 카드가 깔리는 시각, 석양의 무법자는 신호 시각.
static func reaction_mark(game: int, setup: Dictionary) -> float:
	if game == Game.HALLI:
		return float((setup["cards"] as Array).size() - 1) * float(setup.get("interval", HALLI_INTERVAL))
	if game == Game.QUICKDRAW:
		return float(setup["signal"])
	return 0.0


## 순발력 게임에서 아무도 안 누를 때 끝나는 시각(초).
static func reaction_deadline(game: int, setup: Dictionary) -> float:
	return reaction_mark(game, setup) + REACTION_WINDOW


static func time_limit(game: int) -> float:
	match game:
		Game.HALLI, Game.QUICKDRAW: return TIME_REACTION
		Game.CURLING: return TIME_CURLING
		Game.BARREL: return TIME_BARREL_PICK + ROULETTE_TIME + INTRO_TIME
	return TIME_PICK


## 동시에 내는 게임인가 (스피키 룰렛만 번갈아 둔다).
static func is_simultaneous(game: int) -> bool:
	return game != Game.BARREL


## 이 자리가 보낸 값이 올바른가.
static func valid_input(game: int, value: int, is_challenger: bool, opened: Array = []) -> bool:
	match game:
		Game.RPS: return value >= 0 and value <= 2
		Game.ECARD: return value == 0 or value == 1
		Game.HALLI, Game.QUICKDRAW: return value >= -1 and value <= 60000
		Game.CURLING: return value >= 0 and value <= CURLING_MAX
		Game.BARREL: return value >= 0 and value < BARREL_HOLES and not opened.has(value)
	return false


## 시간 초과로 못 낸 사람의 값: 손·카드는 무작위, 순발력은 안 누름(-1), 컬링은 끝까지 차서 추락.
static func timeout_input(game: int, rng: RandomNumberGenerator, opened: Array = []) -> int:
	match game:
		Game.RPS: return rng.randi_range(0, 2)
		Game.ECARD: return rng.randi_range(0, 1)
		Game.CURLING: return CURLING_MAX
		Game.BARREL:
			var free: Array[int] = []
			for hole: int in BARREL_HOLES:
				if not opened.has(hole):
					free.append(hole)
			return free[rng.randi_range(0, free.size() - 1)] if not free.is_empty() else 0
	return -1


## 가위바위보: a가 b를 이기면 1, 지면 -1, 비기면 0.
static func compare(a: int, b: int) -> int:
	if a == b:
		return 0
	return 1 if (a - b + 3) % 3 == 2 else -1


## 동시 게임 판정. picks: {player_id: 값}. 반환: {"winner": id(-1이면 비김·재대결), "decided_by": StringName, "advance": int}
static func resolve(game: int, setup: Dictionary, challenger: int, defender: int, picks: Dictionary) -> Dictionary:
	var a: int = int(picks.get(challenger, -1))
	var b: int = int(picks.get(defender, -1))
	var result: Dictionary = {"winner": challenger, "decided_by": &"game", "advance": winner_advance()}
	match game:
		Game.RPS:
			var outcome: int = compare(a, b)
			result["winner"] = challenger if outcome > 0 else (defender if outcome < 0 else -1)
		Game.ECARD:
			# 여왕 > 평민 > 반란군 > 여왕. 둘 다 평민이면 신청자 승.
			if a == ECARD_QUEEN and b == ECARD_REBEL:
				result["winner"] = defender
				result["decided_by"] = &"upset"
				result["advance"] = UPSET_ADVANCE
			else:
				result["winner"] = challenger
		Game.HALLI, Game.QUICKDRAW:
			var mark_ms: int = int(round(reaction_mark(game, setup) * 1000.0))
			var first: int = -1
			var first_time: int = 1 << 30
			for player_id: int in [challenger, defender]:
				var pressed: int = int(picks.get(player_id, -1))
				if pressed >= 0 and pressed < first_time:
					first_time = pressed
					first = player_id
			if first == -1:
				result["decided_by"] = &"nobody"  # 아무도 안 눌렀다: 신청자 판정승
			elif first_time < mark_ms:
				result["winner"] = defender if first == challenger else challenger  # 먼저 누른 쪽이 반칙
				result["decided_by"] = &"foul"
			else:
				result["winner"] = first
		Game.CURLING:
			var a_ok: bool = a <= CURLING_EDGE
			var b_ok: bool = b <= CURLING_EDGE
			if a_ok and b_ok:
				result["winner"] = defender if b > a else challenger
			elif a_ok != b_ok:
				result["winner"] = challenger if a_ok else defender
				result["decided_by"] = &"fall"
			else:
				result["decided_by"] = &"both_fell"  # 둘 다 추락: 신청자 판정승
	return result


## 결과 한 줄 (로그·결투장): 예) (96.0% vs 88.0%), (0.42초 vs 반칙), (바위 vs 가위)
static func detail_text(game: int, setup: Dictionary, challenger: int, defender: int, picks: Dictionary) -> String:
	var a: int = int(picks.get(challenger, -1))
	var b: int = int(picks.get(defender, -1))
	match game:
		Game.RPS:
			return "(%s vs %s)" % [HAND_NAMES[clampi(a, 0, 2)], HAND_NAMES[clampi(b, 0, 2)]]
		Game.ECARD:
			return "(%s vs %s)" % [ECARD_CHALLENGER[clampi(a, 0, 1)], ECARD_DEFENDER[clampi(b, 0, 1)]]
		Game.CURLING:
			return "(%s vs %s)" % [curling_text(a), curling_text(b)]
		Game.HALLI, Game.QUICKDRAW:
			var mark_ms: int = int(round(reaction_mark(game, setup) * 1000.0))
			return "(%s vs %s)" % [reaction_text(a, mark_ms), reaction_text(b, mark_ms)]
		Game.BARREL:
			return "(구멍 %d개째에 폭탄)" % (picks.get("opened", []) as Array).size()
	return ""


static func curling_text(value: int) -> String:
	return "%.1f%%%s" % [float(value) / 10.0, " 추락" if value > CURLING_EDGE else ""]


static func reaction_text(pressed_ms: int, mark_ms: int) -> String:
	if pressed_ms < 0:
		return "못 누름"
	if pressed_ms < mark_ms:
		return "반칙"
	return "%.2f초" % (float(pressed_ms - mark_ms) / 1000.0)


## 봇이 낼 값. 순발력은 사람 같은 반응 딜레이, 컬링은 72~96% 정밀도에 15% 확률로 100% 초과 실수.
static func bot_input(game: int, setup: Dictionary, is_challenger: bool, rng: RandomNumberGenerator, opened: Array = []) -> int:
	match game:
		Game.RPS: return rng.randi_range(0, 2)
		Game.ECARD:
			# 신청자는 여왕을 반쯤, 수비자는 반란군을 40% 정도로 노린다.
			return (0 if rng.randf() < 0.5 else 1) if is_challenger else (0 if rng.randf() < 0.4 else 1)
		Game.HALLI, Game.QUICKDRAW:
			return int(round((reaction_mark(game, setup) + rng.randf_range(BOT_REACT_MIN, BOT_REACT_MAX)) * 1000.0))
		Game.CURLING:
			if rng.randf() < BOT_CURL_FAIL:
				return rng.randi_range(CURLING_EDGE + 5, 1100)
			return rng.randi_range(BOT_CURL_MIN, BOT_CURL_MAX)
		Game.BARREL:
			return timeout_input(game, rng, opened)
	return 0


## 결투를 걸 수 있는 상대: 보드 위에 나와 있는 말이 있는 상대 플레이어들.
static func targets(state: GameState, challenger: int) -> Array[int]:
	return BangCommand.target_players(state, challenger)


## 대상을 안 골랐을 때(그냥 보드에 던짐) 자동 지목: 선두 말이 결승에 가장 가까운 상대. 없으면 -1.
static func default_target(state: GameState, challenger: int) -> int:
	var best_player: int = -1
	var best_distance: int = 1 << 30
	for player_id: int in targets(state, challenger):
		var distance: int = state.pawn_progress_distance(state.front_pawn_of(player_id))
		if distance < best_distance:
			best_distance = distance
			best_player = player_id
	return best_player


## 패자의 말 중 사출시킬 수 있는 대표 말 ID들 (보드 위에 나와 있고 업히지 않은 말).
static func strike_candidates(state: GameState, loser: int) -> Array[int]:
	var result: Array[int] = []
	for pawn: PlayerPawn in state.pawns_of(loser):
		if pawn.is_finished or pawn.carrier != null or not pawn.has_left_start or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		result.append(pawn.entity_id)
	return result


## 패자의 사출 대상: 선두 말 (선두 말이 후보가 아니면 첫 후보). 없으면 -1.
static func strike_target(state: GameState, loser: int) -> int:
	var candidates: Array[int] = strike_candidates(state, loser)
	if candidates.is_empty():
		return -1
	var front: PlayerPawn = state.front_pawn_of(loser)
	return front.entity_id if front != null and candidates.has(front.entity_id) else candidates[0]


## 승자의 보상: 패자의 말은 그 자리에서 즉시 출발선으로 사출되고, 승자의 선두 말(없으면 출발 대기 말 하나)은 앞으로 advance칸 날아간다.
## 반환: {"from", "landing", "to", "sent_to_start", "trapped", "boost_pawn_id", "boost_from", "boost_to"}.
static func apply_strike(state: GameState, winner: int, pawn: PlayerPawn, advance: int = -1) -> Dictionary:
	var from_tile: int = pawn.current_tile_idx
	state.send_to_start(pawn, winner)
	var result: Dictionary = {"from": from_tile, "landing": GameEnums.GOAL_TILE, "to": pawn.current_tile_idx, "sent_to_start": true, "trapped": false, "boost_pawn_id": -1, "boost_from": -1, "boost_to": -1}
	var booster: PlayerPawn = state.front_pawn_of(winner)
	if booster == null:
		for candidate: PlayerPawn in state.pawns_of(winner):
			if candidate.is_selectable():
				booster = candidate
				break
	if booster != null:
		result["boost_pawn_id"] = booster.entity_id
		result["boost_from"] = booster.current_tile_idx
		MoveExecutor.forced_advance(state, booster, advance if advance > 0 else winner_advance())
		result["boost_to"] = booster.current_tile_idx
	return result
