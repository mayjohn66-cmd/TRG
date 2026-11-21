# File: res://core_engine/augments/super_status.gd
# Class: class_name SuperStatus
# Role: 기간이 있는 초증강 4종의 상태와 규칙 - 평화주의자(SUPER_13) · 날조와 선동(SUPER_14) · 눈먼 자의 도시(SUPER_15) · 사출 목걸이(SUPER_16).
#       상태는 GameState.super_status 한 곳에 모아 두고(스냅샷에 담긴다) 이동·잡기·카드·라운드 끝 규칙이 이 파일의 조회 함수로 묻는다.
#       "다음 증강전까지"는 지금 라운드보다 뒤에 오는 첫 증강 라운드가 오기 전까지다 (그 라운드의 증강 선택이 시작되면 끝난다).
class_name SuperStatus
extends RefCounted

## 평화주의자가 쓸 수 없는 카드: 말을 출발선으로 보내는 카드 (뱅·UDO +4·운명의 수레바퀴·내 앞을 막지마·일기토·슈팡 특급 배송).
const KILL_CARDS: Array[StringName] = [&"ACT_02", &"ACT_03", &"ACT_08", &"ACT_09", &"ACT_10", &"ACT_13"]
## 사출 목걸이: 이동 거리 배수.
const NECKLACE_MOVE_MULTIPLIER: int = 2


static func _bucket(state: GameState, key: String) -> Dictionary:
	if not state.super_status.has(key):
		state.super_status[key] = {}
	return state.super_status[key]


## 지금 라운드 뒤에 오는 첫 증강 라운드 번호 (효과는 그 라운드가 되기 전까지 이어진다).
static func next_draft_round(round_number: int) -> int:
	var next: int = round_number + 1
	for _i: int in 80:
		if GameEnums.is_draft_round(next):
			return next
		next += 1
	return next


## 증강전까지 남은 라운드 수 (효과가 이미 끝났으면 0).
static func rounds_left(state: GameState, until_round: int) -> int:
	return maxi(until_round - state.round_number, 0)


# --- 평화주의자: 내 모든 말은 잡기 면역, 내 말은 아무도 잡을 수 없다 -----------------------------------------

static func set_pacifist(state: GameState, player_id: int) -> int:
	var until: int = next_draft_round(state.round_number)
	_bucket(state, "pacifist")[player_id] = until
	return until


static func pacifist_active(state: GameState, player_id: int) -> bool:
	return state != null and int((state.super_status.get("pacifist", {}) as Dictionary).get(player_id, -1)) > state.round_number


static func pacifist_until(state: GameState, player_id: int) -> int:
	return int((state.super_status.get("pacifist", {}) as Dictionary).get(player_id, -1))


## 평화주의자가 쓸 수 없는 카드인가 (말을 출발선으로 보내는 카드).
static func card_blocked(state: GameState, player_id: int, card_id: StringName) -> bool:
	return pacifist_active(state, player_id) and KILL_CARDS.has(card_id)


# --- 날조와 선동: 지정 대상이 모든 공격 카드를 받는다 -----------------------------------------------------

static func set_agitation(state: GameState, by_player: int, target: int) -> int:
	var until: int = next_draft_round(state.round_number)
	_bucket(state, "agitate")[by_player] = {"target": target, "until": until}
	return until


static func agitation_active_by(state: GameState, by_player: int) -> bool:
	var entry: Dictionary = (state.super_status.get("agitate", {}) as Dictionary).get(by_player, {})
	return not entry.is_empty() and int(entry.get("until", -1)) > state.round_number


## 지금 효과가 살아 있는 선동들: [{by, target, until}] (선동한 사람 순서).
static func active_agitations(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var all: Dictionary = state.super_status.get("agitate", {})
	var keys: Array = all.keys()
	keys.sort()
	for by_player: Variant in keys:
		var entry: Dictionary = all[by_player]
		if int(entry.get("until", -1)) > state.round_number:
			result.append({"by": int(by_player), "target": int(entry["target"]), "until": int(entry["until"])})
	return result


## 공격 카드의 대상 목록을 걸러 준다: 선동이 살아 있으면 대상 말고는 겨눌 수 없다 (대상 본인의 카드는 그대로).
## 평화주의자는 공격 카드를 쓸 수 없으므로 대상이 없다.
static func filter_attack_targets(state: GameState, actor: int, targets: Array[int]) -> Array[int]:
	if state == null:
		return targets
	for entry: Dictionary in active_agitations(state):
		var target: int = int(entry["target"])
		if target == actor:
			continue
		var forced: Array[int] = []
		if targets.has(target):
			forced.append(target)
		return forced
	return targets


## 지금 actor의 공격이 향해야 하는 사람 (선동이 없거나 본인이 대상이면 -1).
static func forced_target(state: GameState, actor: int) -> int:
	for entry: Dictionary in active_agitations(state):
		if int(entry["target"]) != actor:
			return int(entry["target"])
	return -1


# --- 눈먼 자의 도시: 이번 라운드 모든 함정과 말이 가려지고 아군 말도 잡는다 ----------------------------------

static func set_blind(state: GameState) -> void:
	state.super_status["blind"] = state.round_number


static func blind_active(state: GameState) -> bool:
	return state != null and int(state.super_status.get("blind", -1)) == state.round_number


# --- 사출 목걸이: 고른 말은 모든 공격을 막고 이동 거리 2배, 라운드가 끝나면 터져 출발선으로 ----------------------

static func set_necklace(state: GameState, owner_id: int, pawn_id: int) -> void:
	_bucket(state, "necklace")[owner_id] = {"pawn": pawn_id, "round": state.round_number}


## 목걸이를 차고 있는 말인가 (업혀 있는 말은 그 대표 말이 찬 것으로 본다).
static func is_necklace(state: GameState, pawn: PlayerPawn) -> bool:
	if state == null or pawn == null or state.super_status.is_empty():
		return false
	var lead: PlayerPawn = pawn.carrier if pawn.carrier != null else pawn
	var all: Dictionary = state.super_status.get("necklace", {})
	for owner_id: Variant in all.keys():
		var entry: Dictionary = all[owner_id]
		if int(entry.get("round", -1)) == state.round_number and int(entry.get("pawn", -1)) == lead.entity_id:
			return true
	return false


## 목걸이를 찰 수 있는 말: 보드 위에 나와 있는 내 대표 말.
static func necklace_candidates(state: GameState, player_id: int) -> Array[PlayerPawn]:
	return SuperAugments.board_leaders(state, player_id)


# --- 잡기 규칙 연결 -----------------------------------------------------------------------------------------

## 이 말은 지금 잡기·사출 면역인가 (평화주의자의 말 · 목걸이를 찬 말).
static func pawn_protected(state: GameState, pawn: PlayerPawn) -> bool:
	if state == null or pawn == null or state.super_status.is_empty():
		return false
	return pacifist_active(state, pawn.owner_id) or is_necklace(state, pawn)


## 이 사출은 막아야 하는가: 평화주의자는 남을 잡을 수 없다 (면역은 break_shield가 막는다).
static func blocks_capture_by(state: GameState, by_player: int, victim: PlayerPawn) -> bool:
	return victim != null and by_player != victim.owner_id and pacifist_active(state, by_player)


# --- 라운드 끝 ------------------------------------------------------------------------------------------------

## 라운드가 끝나면 이번 라운드의 목걸이가 터져 그 말(과 업힌 말)이 출발선으로 사출된다. 터진 말 ID들을 돌려준다.
static func explode_necklaces(state: GameState) -> Array[int]:
	var exploded: Array[int] = []
	var all: Dictionary = state.super_status.get("necklace", {})
	var keys: Array = all.keys()
	keys.sort()
	for owner_id: Variant in keys:
		var entry: Dictionary = all[owner_id]
		if int(entry.get("round", -1)) != state.round_number:
			continue
		var pawn: PlayerPawn = state.get_pawn(int(entry["pawn"]))
		all.erase(owner_id)
		if pawn == null or pawn.is_finished or not pawn.has_left_start or pawn.carrier != null:
			continue
		exploded.append(pawn.entity_id)
		state.necklace_exploded.emit(pawn.entity_id, pawn.current_tile_idx)
		state.send_to_start(pawn, int(owner_id))
	return exploded
