# File: res://core_engine/augments/utility_augments.gd
# Class: class_name UtilityAugments
# Role: [범용 보급] 증강 - 기물 변이·전군 돌연변이·필살기 리필 + 2026-10 범용 10종(영구 패시브 4·즉발 6). 드래프트 선택지의 유연성을 높이는 증강의 조건·효과.
#       모든 난수는 호스트 RNG(state.rng)를 쓴다. 영구 효과의 기록은 GameState(utility_*)에 있고 TurnSnapshot에 실린다.
class_name UtilityAugments
extends RefCounted

const MUTATE_ONE: StringName = &"UTIL_01"   # [기물 재연성] 랜덤 변이 물약
const MUTATE_ALL: StringName = &"UTIL_02"   # [기물 대개조] 전군 돌연변이
const SKILL_REFILL: StringName = &"UTIL_03" # [전술 재장전] 필살기 리필 주사

## 2026-10 범용 10종 (법전 비중을 줄인 자리를 채운다).
const MOVE_PLUS: StringName = &"AUG_UTIL_MOVE_PLUS"           # [상시 보급] 슈파볼트 탑승: 모든 굴림 영구 +1칸
const HAND_EXPAND: StringName = &"AUG_UTIL_HAND_EXPAND"       # [상시 보급] 에심당 뽈사탕: 카드 1장 + 손패 상한 +1
const LUCKY_DICE: StringName = &"AUG_UTIL_LUCKY_DICE"         # [상시 보급] 손은 눈보다 빨라: 굴림이 높게 나올 확률 상승
const EXTRA_TURN: StringName = &"AUG_UTIL_EXTRA_TURN"         # [1회용 보급] 다이스 리바이브: 0칸·턴 종료 굴림이면 한 턴 더
const CARD_PACK2: StringName = &"AUG_UTIL_CARD_PACK2"         # [카드 보급] 즉발 카드 2장
const SELECT_SHIELD: StringName = &"AUG_UTIL_SELECT_SHIELD"   # [기물 보급] 관심사도 지정: 내 말 1개에 보호막
const TRAP_CLEAR1: StringName = &"AUG_UTIL_TRAP_CLEAR1"       # [즉발 보급] 간의영역: 상대 함정 1개 철거 (없으면 카드 1장)
const CATCH_UP: StringName = &"AUG_UTIL_CATCH_UP"             # [즉발 보급] 순보: 가장 뒤처진 내 말을 선두 바로 뒤로
const SHORTEN_GOAL: StringName = &"AUG_UTIL_SHORTEN_GOAL"     # [즉발 보급] 슬슬 지루한데...: 모두의 결승선 2칸 영구 단축
const REROLL_ALL_AUG: StringName = &"AUG_UTIL_REROLL_ALL_AUG" # [랜덤 보급] 올 픽션: 이번 드래프트를 모두 다시 뽑는다 (라운드당 1회)

const ALL_IDS: Array[StringName] = [MUTATE_ONE, MUTATE_ALL, SKILL_REFILL, MOVE_PLUS, HAND_EXPAND, LUCKY_DICE, EXTRA_TURN, CARD_PACK2, SELECT_SHIELD, TRAP_CLEAR1, CATCH_UP, SHORTEN_GOAL, REROLL_ALL_AUG]
## 2026-10 범용 10종 (도감·테스트용).
const NEW_IDS: Array[StringName] = [MOVE_PLUS, HAND_EXPAND, LUCKY_DICE, EXTRA_TURN, CARD_PACK2, SELECT_SHIELD, TRAP_CLEAR1, CATCH_UP, SHORTEN_GOAL, REROLL_ALL_AUG]
## 영구 패시브: 한 사람이 같은 증강을 겹쳐 받을 수 있는 최대 횟수 (손패 상한·행운은 한 번만, 이동 +1은 두 번까지).
const MOVE_PLUS_MAX: int = 2
const HAND_EXPAND_MAX: int = 1
const LUCKY_MAX: int = 1
## 손은 눈보다 빨라: 굴림을 한 번 더 굴려 큰 쪽을 쓰는 확률.
const LUCKY_CHANCE: float = 0.5
## 결승선 단축 칸 수와 총 상한.
const SHORTEN_STEPS: int = 2
const SHORTEN_MAX: int = 4
## 증강 화면의 콜아웃 글자 (원문 한국어, 화면에서 번역).
const CALLOUTS: Dictionary = {
	MOVE_PLUS: "[이동 +1칸 영구!]",
	HAND_EXPAND: "[손패 상한 +1!]",
	LUCKY_DICE: "[굴림 운 상승!]",
	EXTRA_TURN: "[리바이브 장전!]",
	CARD_PACK2: "[즉발 카드 2장!]",
	SELECT_SHIELD: "[보호막!]",
	TRAP_CLEAR1: "[함정 1개 철거!]",
	CATCH_UP: "[선두 바로 뒤로!]",
	SHORTEN_GOAL: "[결승선 2칸 단축!]",
	REROLL_ALL_AUG: "[전원 증강 재추첨!]",
}

## 수치 기본값 (augments_table.csv param_1이 비어 있을 때만 쓴다).
const MUTATE_ADVANCE: int = 3
const REFILL_CARDS: int = 1

## 표에 행이 없을 때 쓰는 이름·설명.
const INFO: Dictionary = {
	MUTATE_ONE: ["[기물 재연성] 랜덤 변이 물약", "◆ 진화한 내 기물 1개를 다른 진화 기물로 바꾸고 +%d칸 전진\n◆ 새 기물의 필살기는 바로 사용 가능"],
	MUTATE_ALL: ["[기물 대개조] 전군 돌연변이", "◆ 내 말 4개를 모두 서로 다른 진화 기물로 변경\n◆ 필살기 재충전"],
	SKILL_REFILL: ["[전술 재장전] 필살기 리필 주사", "◆ 사용한 필살기 모두 재충전 + 생떼 카드 %d장"],
	MOVE_PLUS: ["[상시 보급] 슈파볼트 탑승", "◆ 이번 판 동안 내 모든 굴림 이동 +1칸 (영구)"],
	HAND_EXPAND: ["[상시 보급] 에심당 뽈사탕", "◆ 무작위 카드 1장 획득\n◆ 최대 손패 +1장 (영구)"],
	LUCKY_DICE: ["[상시 보급] 손은 눈보다 빨라", "◆ 이번 판 동안 내 굴림이 높게 나올 확률 상승 (영구)"],
	EXTRA_TURN: ["[1회용 보급] 다이스: 리바이브", "◆ 굴림이 0칸·턴 종료면 내 턴을 한 번 더 (1회)"],
	CARD_PACK2: ["[카드 보급] 즉발 카드 패키지", "◆ 무작위 즉발 카드 2장 획득"],
	SELECT_SHIELD: ["[기물 보급] 관심사도 지정", "◆ 내 말 1개에 보호막 (잡기·함정 1회 방어)"],
	TRAP_CLEAR1: ["[즉발 보급] 간의영역", "◆ 상대 함정 1개를 무작위로 철거\n◆ 철거할 함정이 없으면 카드 1장"],
	CATCH_UP: ["[즉발 보급] 순보", "◆ 가장 뒤처진 내 말을 보드 전체 선두 말의 바로 뒤 칸으로 이동"],
	SHORTEN_GOAL: ["[즉발 보급] 슬슬 지루한데...", "◆ 모든 플레이어의 결승선이 2칸 당겨진다 (영구)"],
	REROLL_ALL_AUG: ["[랜덤 보급] 올 픽션", "◆ 아직 고르지 않은 모두와 나의 증강 선택지를 새 3장으로 다시 뽑는다 (라운드당 1회)"],
}


static func mutate_advance() -> int:
	return maxi(GameData.param("augments", MUTATE_ONE, 1, MUTATE_ADVANCE), 0)


static func refill_cards() -> int:
	return maxi(GameData.param("augments", SKILL_REFILL, 1, REFILL_CARDS), 0)


static func display_name(effect: StringName) -> String:
	return str((INFO[effect] as Array)[0])


static func describe(effect: StringName) -> String:
	match effect:
		MUTATE_ONE: return str((INFO[effect] as Array)[1]) % mutate_advance()
		SKILL_REFILL: return str((INFO[effect] as Array)[1]) % refill_cards()
	return str((INFO[effect] as Array)[1])


static func is_available(effect: StringName, state: GameState, player_id: int) -> bool:
	var racing: Array[PlayerPawn] = _racing_pawns(state, player_id)
	match effect:
		MUTATE_ONE:
			# 조건 검사는 난수를 쓰지 않는다 (화면·봇이 따로 불러도 온라인 판이 어긋나지 않게)
			for pawn: PlayerPawn in _target_pool(state, player_id):
				if not _options(state, player_id, [pawn], []).is_empty():
					return true
			return false
		MUTATE_ALL:
			return not racing.is_empty()
		SKILL_REFILL:
			return racing.any(func(pawn: PlayerPawn) -> bool: return pawn.skill_used and PawnSkills.has_skill(pawn)) \
				or (state.hands[player_id] as Array).size() < state.hand_limit(player_id)
		MOVE_PLUS:
			return int(state.utility_move_plus.get(player_id, 0)) < MOVE_PLUS_MAX
		HAND_EXPAND:
			return int(state.hand_bonus.get(player_id, 0)) < HAND_EXPAND_MAX
		LUCKY_DICE:
			return int(state.lucky_dice.get(player_id, 0)) < LUCKY_MAX
		EXTRA_TURN:
			return int(state.revive_charges.get(player_id, 0)) == 0
		CARD_PACK2:
			return (state.hands[player_id] as Array).size() < state.hand_limit(player_id) and not CardRegistry.ids_of_type("INSTANT").is_empty()
		SELECT_SHIELD:
			return not shield_candidates(state, player_id).is_empty()
		TRAP_CLEAR1:
			return not enemy_traps(state, player_id).is_empty() or (state.hands[player_id] as Array).size() < state.hand_limit(player_id)
		CATCH_UP:
			return catch_up_plan(state, player_id).size() == 2
		SHORTEN_GOAL:
			return state.goal_shrink_bonus + SHORTEN_STEPS <= SHORTEN_MAX
		REROLL_ALL_AUG:
			return state.reshuffle_round != state.round_number
	return false


static func apply(effect: StringName, state: GameState, player_id: int) -> Dictionary:
	match effect:
		MUTATE_ONE: return _apply_mutate_one(state, player_id)
		MUTATE_ALL: return _apply_mutate_all(state, player_id)
		SKILL_REFILL: return _apply_refill(state, player_id)
		MOVE_PLUS:
			state.utility_move_plus[player_id] = int(state.utility_move_plus.get(player_id, 0)) + 1
			state.permanent_roll_bonus[player_id] = int(state.permanent_roll_bonus.get(player_id, 0)) + 1
			return {"ok": true, "text": "이번 판 동안 모든 굴림 이동 +1칸 (영구)"}
		HAND_EXPAND:
			state.hand_bonus[player_id] = int(state.hand_bonus.get(player_id, 0)) + 1
			var drawn: Array[String] = _give_random_cards(state, player_id, CardRegistry.all_ids(), 1)
			return {"ok": true, "text": "최대 손패 +1장 (%d장)%s" % [state.hand_limit(player_id), (" · 카드 획득: %s" % ", ".join(drawn)) if not drawn.is_empty() else ""]}
		LUCKY_DICE:
			state.lucky_dice[player_id] = int(state.lucky_dice.get(player_id, 0)) + 1
			return {"ok": true, "text": "이번 판 동안 굴림이 높게 나올 확률 상승"}
		EXTRA_TURN:
			state.revive_charges[player_id] = 1
			return {"ok": true, "text": "리바이브 장전: 0칸·턴 종료 굴림이 나오면 한 턴 더"}
		CARD_PACK2:
			var cards: Array[String] = _give_random_cards(state, player_id, CardRegistry.ids_of_type("INSTANT"), 2)
			return {"ok": not cards.is_empty(), "text": "즉발 카드 획득: %s" % ", ".join(cards)}
		SELECT_SHIELD: return _apply_shield(state, player_id, -1)
		TRAP_CLEAR1: return _apply_trap_clear(state, player_id)
		CATCH_UP: return _apply_catch_up(state, player_id)
		SHORTEN_GOAL:
			state.goal_shrink_bonus = mini(state.goal_shrink_bonus + SHORTEN_STEPS, SHORTEN_MAX)
			return {"ok": true, "text": "모든 플레이어의 결승선이 %d칸 당겨졌습니다 (%d번 칸부터 결승)" % [SHORTEN_STEPS, TempoUp.zone_start_for(state)]}
		REROLL_ALL_AUG:
			state.reshuffle_round = state.round_number  # 실제 재추첨은 TurnManager가 한다 (드래프트 상태를 가진 쪽)
			return {"ok": true, "text": "이번 드래프트를 다시 뽑습니다"}
	return {"ok": false, "text": "알 수 없는 범용 증강입니다"}


## 고르는 순간 대상 말을 직접 고를 수 있는 범용 증강인가 (관심사도 지정: 보드 위 내 말이 둘 이상).
static func needs_pawn_choice(effect: StringName, state: GameState, player_id: int) -> bool:
	return effect == SELECT_SHIELD and shield_candidates(state, player_id).size() > 1


## 관심사도 지정 후보: 보드 위의 내 말(보호막이 없는 것), 없으면 다음에 출격할 대기 말 하나.
static func shield_candidates(state: GameState, player_id: int) -> Array[PlayerPawn]:
	var on_board: Array[PlayerPawn] = []
	var waiting: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished or pawn.ward or pawn.carrier != null:
			continue
		if pawn.has_left_start and pawn.current_tile_idx != GameEnums.GOAL_TILE:
			on_board.append(pawn)
		else:
			waiting.append(pawn)
	if not on_board.is_empty():
		return on_board
	return [waiting[0]] as Array[PlayerPawn] if not waiting.is_empty() else [] as Array[PlayerPawn]


## 컴퓨터·자동 선택이 보호막을 씌울 말: 결승에 가장 가까운 선두 말.
static func default_shield_target(state: GameState, player_id: int) -> PlayerPawn:
	var best: PlayerPawn = null
	for pawn: PlayerPawn in shield_candidates(state, player_id):
		if best == null or state.pawn_progress_distance(pawn) < state.pawn_progress_distance(best):
			best = pawn
	return best


static func _apply_shield(state: GameState, player_id: int, pawn_id: int) -> Dictionary:
	var target: PlayerPawn = null
	var candidates: Array[PlayerPawn] = shield_candidates(state, player_id)
	for pawn: PlayerPawn in candidates:
		if pawn.entity_id == pawn_id:
			target = pawn
	if target == null:
		target = default_shield_target(state, player_id)
	if target == null:
		return {"ok": false, "text": "보호막을 씌울 말이 없습니다"}
	target.ward = true
	state.utility_fx.append({"kind": "shield", "pawn_id": target.entity_id, "player_id": player_id})
	return {"ok": true, "text": "말 %d번 [%s]에 보호막" % [target.slot, target.display_label()]}


## 관심사도 지정을 고른 말에 적용한다 (증강을 고를 때 pawn_id를 넘기면 AugmentDef가 부른다).
static func apply_shield_to(state: GameState, player_id: int, pawn_id: int) -> Dictionary:
	return _apply_shield(state, player_id, pawn_id)


## 상대가 설치한 함정 (호텔은 함정이 아니다): [[칸, 설치물]] 칸 순.
static func enemy_traps(state: GameState, player_id: int) -> Array:
	var found: Array = []
	for tile: TileNode in state.board.tiles:
		for attachment: TileAttachment in tile.attachments:
			if attachment.owner_id != player_id and attachment.attachment_id != "HOTEL":
				found.append([tile.tile_id, attachment])
	return found


static func _apply_trap_clear(state: GameState, player_id: int) -> Dictionary:
	var traps: Array = enemy_traps(state, player_id)
	if traps.is_empty():
		var cards: Array[String] = _give_random_cards(state, player_id, CardRegistry.all_ids(), 1)
		return {"ok": not cards.is_empty(), "text": "철거할 상대 함정이 없어 카드 획득: %s" % ", ".join(cards)}
	var picked: Array = traps[state.rng.randi_range(0, traps.size() - 1)]
	var tile_index: int = int(picked[0])
	state.board.get_tile(tile_index).remove_attachment(picked[1] as TileAttachment)
	state.utility_fx.append({"kind": "trap_clear", "tile": tile_index, "player_id": player_id})
	return {"ok": true, "text": "%d번 칸의 상대 함정 1개 철거" % tile_index}


## 순보 계획: [옮길 내 말, 도착 칸]. 옮길 수 없으면 빈 배열 (난수 없음).
## 옮길 말: 보드 위에서 가장 뒤처진 내 말, 보드에 없으면 대기 말. 도착: 보드 전체 선두 말(적 포함)의 한 칸 뒤 (내 말이 지금보다 앞으로 갈 때만).
static func catch_up_plan(state: GameState, player_id: int) -> Array:
	var leader: PlayerPawn = null
	for pawn: PlayerPawn in state.get_active_pawns():
		if pawn.is_finished or not pawn.has_left_start or pawn.carrier != null or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		if leader == null or state.pawn_progress_distance(pawn) < state.pawn_progress_distance(leader):
			leader = pawn
	if leader == null:
		return []
	var target: int = leader.current_tile_idx - 1
	if target < 1:
		return []
	var mover: PlayerPawn = null
	var waiting: PlayerPawn = null
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished or pawn.carrier != null or not pawn.is_selectable():
			continue
		if pawn.has_left_start and pawn.current_tile_idx != GameEnums.GOAL_TILE:
			if mover == null or state.pawn_progress_distance(pawn) > state.pawn_progress_distance(mover):
				mover = pawn
		elif waiting == null:
			waiting = pawn
	if mover == null:
		mover = waiting
	if mover == null or mover == leader:
		return []
	if mover.has_left_start and state.board.distance_to_goal(target, true) >= state.pawn_progress_distance(mover):
		return []  # 이미 선두 바로 뒤보다 앞서 있다
	return [mover, target]


static func _apply_catch_up(state: GameState, player_id: int) -> Dictionary:
	var plan: Array = catch_up_plan(state, player_id)
	if plan.size() != 2:
		return {"ok": false, "text": "옮길 말이 없습니다"}
	var pawn: PlayerPawn = plan[0]
	var from: int = pawn.current_tile_idx if pawn.has_left_start else -1
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = player_id
	ctx.pawn = pawn
	pawn.has_left_start = true
	pawn.revenge_boost = false
	MoveExecutor.teleport_to(state, pawn, ctx, MoveReport.new(), int(plan[1]))
	state.utility_fx.append({"kind": "catch_up", "pawn_id": pawn.entity_id, "from": from, "tile": int(plan[1]), "player_id": player_id})
	return {"ok": true, "text": "말 %d번이 선두 바로 뒤 %d번 칸으로 이동" % [pawn.slot, int(plan[1])]}


## pool에서 무작위 카드 count장을 준다 (손패 상한까지). 받은 카드 이름 목록.
static func _give_random_cards(state: GameState, player_id: int, pool: Array[StringName], count: int) -> Array[String]:
	var given: Array[String] = []
	for i: int in count:
		if pool.is_empty():
			break
		var picked: StringName = pool[state.rng.randi_range(0, pool.size() - 1)]
		if state.give_card(player_id, picked):
			given.append(CardRegistry.get_card(picked).display_name)
	return given


## 손은 눈보다 빨라: 확률로 같은 도구를 한 번 더 굴려 큰 쪽을 쓴다 (다시 굴려도 상태가 꼬이지 않는 도구만).
static func lucky_roll(state: GameState, player_id: int, tool: BaseJudgmentTool, result: RollResult) -> RollResult:
	if result == null or result.can_continue or int(state.lucky_dice.get(player_id, 0)) <= 0 or not PacingDirector.REROLL_TOOLS.has(tool.tool_id):
		return result
	if state.rng.randf() >= LUCKY_CHANCE:
		return result
	var second: RollResult = tool.roll(state.rng)
	var first_steps: int = 0 if result.ends_turn else result.steps
	var second_steps: int = 0 if second.ends_turn else second.steps
	return second if second_steps > first_steps else result


## 변이 물약이 바꿀 말: 필살기를 이미 쓴 진화 기물 → 아무 진화 기물 → 기본 말 순. 같은 순위 안에서는 무작위.
static func mutate_target(state: GameState, player_id: int) -> PlayerPawn:
	var pool: Array[PlayerPawn] = _target_pool(state, player_id)
	return pool[state.rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


## 변이 물약 후보 중 가장 높은 순위의 묶음 (난수 없이).
static func _target_pool(state: GameState, player_id: int) -> Array[PlayerPawn]:
	var racing: Array[PlayerPawn] = _racing_pawns(state, player_id)
	var spent: Array[PlayerPawn] = []
	var evolved: Array[PlayerPawn] = []
	for pawn: PlayerPawn in racing:
		if pawn.kind == GameEnums.PawnKind.BASIC:
			continue
		evolved.append(pawn)
		if pawn.skill_used:
			spent.append(pawn)
	for group: Array[PlayerPawn] in [spent, evolved]:
		if not group.is_empty():
			return group
	return racing


## 완주하지 않은 내 말들 (슬롯 순).
static func _racing_pawns(state: GameState, player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.is_finished:
			result.append(pawn)
	return result


## 바꿀 수 있는 세부 기물 후보 [kind, unit]. changing(이번에 바꾸는 말들)을 뺀 내 말이 가진 세부 기물·호기와,
## 이번에 이미 고른 세부 기물(picked = [kind, unit] 목록)은 피한다. 바꾸는 말의 지금 세부 기물도 피한다 (다른 기물로).
static func _options(state: GameState, player_id: int, changing: Array[PlayerPawn], picked: Array) -> Array:
	var owned_subs: Array = []
	var taken: Array = []  # [kind, unit]
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.kind != GameEnums.PawnKind.BASIC:
			owned_subs.append(pawn.sub_type())  # 바꾸는 말도 지금 기물과 다른 기물로
		if not changing.has(pawn):
			taken.append([pawn.kind, pawn.unit_no])  # 바꾸는 말의 호기는 비워진다
	for entry: Variant in picked:
		owned_subs.append(PawnCatalog.sub_type_of((entry as Array)[0], (entry as Array)[1]))
		taken.append(entry)
	var result: Array = []
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		for units: Variant in PawnCatalog.unit_groups(kind):
			var sub: GameEnums.PawnSubType = PawnCatalog.sub_type_of(kind, int((units as Array)[0]))
			if owned_subs.has(sub):
				continue
			for unit: Variant in units:
				if not taken.has([kind, int(unit)]):
					result.append([kind, int(unit)])
					break
	return result


## 말 하나를 새 세부 기물로 바꾼다: 승급·필살기 사용 기록을 지우고(필살기 재충전) 진화 신호를 보낸다.
static func _transform(state: GameState, pawn: PlayerPawn, kind: GameEnums.PawnKind, unit: int) -> void:
	pawn.promoted = false
	pawn.evolve(kind, unit)
	pawn.skill_used = false
	state.pawn_evolved.emit(pawn.entity_id, kind, unit)


static func _apply_mutate_one(state: GameState, player_id: int) -> Dictionary:
	var pawn: PlayerPawn = mutate_target(state, player_id)
	if pawn == null:
		return {"ok": false, "text": "바꿀 말이 없습니다"}
	var options: Array = _options(state, player_id, [pawn], [])
	if options.is_empty():
		return {"ok": false, "text": "바꿀 수 있는 다른 기물이 없습니다"}
	var before: String = pawn.display_label()
	var chosen: Array = options[state.rng.randi_range(0, options.size() - 1)]
	_transform(state, pawn, chosen[0], chosen[1])
	var text: String = "말 %d번 [%s] → [%s] 변이 (필살기 충전)" % [pawn.slot, before, pawn.display_label()]
	if pawn.has_left_start and pawn.carrier == null and pawn.current_tile_idx != GameEnums.GOAL_TILE and mutate_advance() > 0:
		MoveExecutor.forced_advance(state, pawn, mutate_advance())
		text += " · +%d칸 전진" % mutate_advance()
	return {"ok": true, "text": text}


static func _apply_mutate_all(state: GameState, player_id: int) -> Dictionary:
	var racing: Array[PlayerPawn] = _racing_pawns(state, player_id)
	if racing.is_empty():
		return {"ok": false, "text": "바꿀 말이 없습니다"}
	var picked: Array = []
	var plan: Array = []  # [pawn, kind, unit]
	for pawn: PlayerPawn in racing:
		var options: Array = _options(state, player_id, racing, picked)
		if options.is_empty():
			continue
		var chosen: Array = options[state.rng.randi_range(0, options.size() - 1)]
		picked.append(chosen)
		plan.append([pawn, chosen[0], chosen[1]])
	var changes: Array[String] = []
	for entry: Array in plan:
		var pawn: PlayerPawn = entry[0]
		var before: String = pawn.display_label()
		_transform(state, pawn, entry[1], entry[2])
		changes.append("%d번 [%s]→[%s]" % [pawn.slot, before, pawn.display_label()])
	return {"ok": not changes.is_empty(), "text": "전군 돌연변이: %s (필살기 충전)" % ", ".join(changes)}


static func _apply_refill(state: GameState, player_id: int) -> Dictionary:
	var refilled: Array[String] = []
	for pawn: PlayerPawn in _racing_pawns(state, player_id):
		if pawn.skill_used and PawnSkills.has_skill(pawn):
			pawn.skill_used = false
			refilled.append(pawn.display_label())
	var cards: Array[String] = []
	var pool: Array[StringName] = CardRegistry.all_ids()
	for i: int in refill_cards():
		if pool.is_empty():
			break
		var picked: StringName = pool[state.rng.randi_range(0, pool.size() - 1)]
		if state.give_card(player_id, picked):
			cards.append(CardRegistry.get_card(picked).display_name)
	var text: String = "필살기 재충전: %s" % (", ".join(refilled) if not refilled.is_empty() else "없음")
	if not cards.is_empty():
		text += " · 생떼 카드 획득: %s" % ", ".join(cards)
	return {"ok": true, "text": text}
