# File: res://core_engine/augments/utility_augments.gd
# Class: class_name UtilityAugments
# Role: [범용 보급] 증강 3종 - 기물 변이·전군 돌연변이·필살기 리필. 드래프트 선택지의 유연성을 높이는 증강의 조건·효과. 모든 난수는 호스트 RNG(state.rng)를 쓴다
class_name UtilityAugments
extends RefCounted

const MUTATE_ONE: StringName = &"UTIL_01"   # [기물 재연성] 랜덤 변이 물약
const MUTATE_ALL: StringName = &"UTIL_02"   # [기물 대개조] 전군 돌연변이
const SKILL_REFILL: StringName = &"UTIL_03" # [전술 재장전] 필살기 리필 주사

const ALL_IDS: Array[StringName] = [MUTATE_ONE, MUTATE_ALL, SKILL_REFILL]

## 수치 기본값 (augments_table.csv param_1이 비어 있을 때만 쓴다).
const MUTATE_ADVANCE: int = 3
const REFILL_CARDS: int = 1

## 표에 행이 없을 때 쓰는 이름·설명.
const INFO: Dictionary = {
	MUTATE_ONE: ["[기물 재연성] 랜덤 변이 물약", "◆ 이미 진화한 내 기물 1개를 무작위 다른 진화 기물로 변경하고 +%d칸 전진!\n◆ 변경된 새 기물의 [1회용 필살기]도 즉시 사용 가능 상태로 충전됩니다."],
	MUTATE_ALL: ["[기물 대개조] 전군 돌연변이", "◆ 내 모든 말(4개 전원)을 각각 서로 다른 무작위 진화 기물로 일제히 변경!\n◆ 대기석·보드 위 모든 내 기물이 새 진화 기물로 바뀌며 필살기가 재충전됩니다."],
	SKILL_REFILL: ["[전술 재장전] 필살기 리필 주사", "◆ 이미 사용한 내 모든 기물의 [1회용 필살기]를 100%% 재충전 + 생떼 카드 %d장 획득!\n◆ 알까기·직선 저격·피앙케토 등 소모한 기물 액티브 스킬을 다시 쏠 수 있습니다."],
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
				or (state.hands[player_id] as Array).size() < GameEnums.MAX_HAND_SIZE
	return false


static func apply(effect: StringName, state: GameState, player_id: int) -> Dictionary:
	match effect:
		MUTATE_ONE: return _apply_mutate_one(state, player_id)
		MUTATE_ALL: return _apply_mutate_all(state, player_id)
		SKILL_REFILL: return _apply_refill(state, player_id)
	return {"ok": false, "text": "알 수 없는 범용 증강입니다"}


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
