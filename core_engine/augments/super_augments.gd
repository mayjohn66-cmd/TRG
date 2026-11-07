# File: res://core_engine/augments/super_augments.gd
# Class: class_name SuperAugments
# Role: [초증강 : 하이리스크 하이리턴] 12종 - 드래프트에서만 나오는, 판을 크게 뒤집지만 나도 크게 다칠 수 있는 증강의 조건·효과. 모든 난수는 호스트 RNG(state.rng)를 쓰고 효과는 GameState 시그널로 방송되어 화면이 연출한다
class_name SuperAugments
extends RefCounted

const FLIP: StringName = &"SUPER_01"          # 판 뒤집기 (모 아니면 도)
const REDISTRIBUTE: StringName = &"SUPER_02"   # 공산주의 재분배
const DEVIL: StringName = &"SUPER_03"          # 악마의 계약 (영구 가속)
const MINEFIELD: StringName = &"SUPER_04"      # 광란의 지뢰밭
const RAID: StringName = &"SUPER_05"           # 도적단 대습격
const GAMBLER: StringName = &"SUPER_06"        # 주사위 도박사의 영혼
const CASTLING: StringName = &"SUPER_07"       # 강제 캐슬링 룰렛
const BAKERY: StringName = &"SUPER_08"         # 에르핀의 빵집 털이
const SNIPER: StringName = &"SUPER_09"         # 저격수의 표적
const NITRO: StringName = &"SUPER_10"          # 아우토반 니트로 (선두 말 코너까지 직진, 길을 막은 칸의 말 전부 사출)
const RUNAWAY: StringName = &"SUPER_11"        # 폭주 기관차 (무작위 한 변 쓸기)
const GUARANTEE: StringName = &"SUPER_12"      # 강제 연대책임 (선두·후방 말 일심동체)

const ALL_IDS: Array[StringName] = [FLIP, REDISTRIBUTE, DEVIL, MINEFIELD, RAID, GAMBLER, CASTLING, BAKERY, SNIPER, NITRO, RUNAWAY, GUARANTEE]
## 고른 사람의 말도 휘말려 출발선으로 사출될 수 있는 초증강: 증강 카드 왼쪽 위에 경고 아이콘(커서를 대면 SELF_RISK_NOTE)을 띄운다.
## 판 뒤집기(실패하면 내 말 추방) / 지뢰밭(누구든 밟으면 반경 안 전원) / 니트로(멈춘 칸의 말 전부) / 기관차(그 변의 말 전부) / 연대책임(하나가 탈락하면 둘 다).
## 악마의 계약은 완주한 말을 되돌리는 정해진 대가라 넣지 않는다.
const SELF_RISK: Array[StringName] = [FLIP, MINEFIELD, NITRO, RUNAWAY, GUARANTEE]
const SELF_RISK_NOTE: String = "주의: 본인의 말이 사출될 수 있음"
## 남은 게임 내내 그 플레이어에게만 작동하는 패시브 (RuleBookManager.personal_laws, 법전 슬롯을 차지하지 않는다). 지금은 없다 (아우토반 니트로는 즉시 효과로 바뀌었다).
const PERSONAL: Array[StringName] = []

## 수치 기본값 (content_trickcal/data/augments_table.csv의 param_1·param_2가 비어 있을 때만 쓴다).
const FLIP_FINISH_CHANCE_PERCENT: int = 50
const DEVIL_BONUS: int = 3
const REDISTRIBUTE_CARDS: int = 2
const MINEFIELD_COUNT: int = 2
const MINEFIELD_TRAP_CARDS: int = 1
const RAID_SUMMON_CARDS: int = 1
const RAID_STEAL_EACH: int = 1
const BAKERY_CARDS: int = 3
const SNIPER_ADVANCE: int = 4
const GAMBLER_MULTIPLIER: int = 2
const GAMBLER_OVERHEAT_AT: int = 1


## CSV 수치 (param_index 1·2). 표에 없거나 비어 있으면 default.
static func param(effect: StringName, param_index: int, default: int) -> int:
	return GameData.param("augments", effect, param_index, default)


static func flip_chance() -> int:
	return clampi(param(FLIP, 1, FLIP_FINISH_CHANCE_PERCENT), 0, 100)


static func devil_bonus() -> int:
	return param(DEVIL, 1, DEVIL_BONUS)


static func redistribute_cards() -> int:
	return maxi(param(REDISTRIBUTE, 1, REDISTRIBUTE_CARDS), 0)


static func minefield_count() -> int:
	return maxi(param(MINEFIELD, 1, MINEFIELD_COUNT), 0)


static func minefield_trap_cards() -> int:
	return maxi(param(MINEFIELD, 2, MINEFIELD_TRAP_CARDS), 0)


## 도적단 대습격: 받는 중립 기물(소환) 카드 수와, 다른 사람마다 빼앗는 카드 수.
static func raid_summon_cards() -> int:
	return maxi(param(RAID, 1, RAID_SUMMON_CARDS), 0)


static func raid_steal_each() -> int:
	return maxi(param(RAID, 2, RAID_STEAL_EACH), 0)


static func bakery_cards() -> int:
	return maxi(param(BAKERY, 1, BAKERY_CARDS), 0)


static func sniper_advance() -> int:
	return maxi(param(SNIPER, 1, SNIPER_ADVANCE), 0)


## 도박사의 영혼: 이동 거리 배수와, 이 눈금 이하면 과열되는 기준.
static func gambler_multiplier() -> int:
	return maxi(param(GAMBLER, 1, GAMBLER_MULTIPLIER), 1)


static func gambler_overheat_at() -> int:
	return param(GAMBLER, 2, GAMBLER_OVERHEAT_AT)


## 효과 ID -> [이름, 카드 설명].
const INFO: Dictionary = {
	FLIP: ["판 뒤집기 (모 아니면 도)", "◆ 보드 위 내 말 1개를 무작위로 골라\n◆ 50% 즉시 결승선 완주!\n◆ 실패하면 출발선 추방"],
	REDISTRIBUTE: ["공산주의 재분배", "◆ 모두의 진도를 꼴찌와 똑같이 맞춘다\n◆ 모든 손패를 회수해 섞은 뒤 2장씩 다시 나눠 준다"],
	DEVIL: ["악마의 계약 (영구 가속)", "◆ 완주한 내 말 1개를 출발선으로 되돌리고\n◆ 남은 게임 내내 내 모든 굴림 결과에 +3칸"],
	MINEFIELD: ["광란의 지뢰밭", "◆ 빈 일반 타일 2곳에 지뢰 매설\n◆ 함정 카드 1장 획득"],
	RAID: ["도적단 대습격", "◆ 중립 기물 카드 1장 획득\n◆ 나를 뺀 모든 플레이어의 카드 1장씩을 내 패로"],
	GAMBLER: ["주사위 도박사의 영혼", "◆ 이번 라운드 이동 거리 x2\n◆ 단 눈금 1 이하면 과열: 0칸·차례 끝"],
	CASTLING: ["강제 캐슬링 룰렛", "◆ 보드 위 모든 플레이어 말의 위치를 무작위로 전부 섞는다"],
	BAKERY: ["에르핀의 빵집 털이", "◆ 무작위 생떼 카드 3장 획득\n◆ 대기 중인 내 말 1개를 첫 빵집으로 출격"],
	SNIPER: ["저격수의 표적", "◆ 가장 앞선 적 말 1개 장외 사출\n◆ 내 말 1개 +4칸 전진"],
	NITRO: ["아우토반 니트로", "◆ 내 선두 말이 다음 코너까지 일직선으로 질주!\n◆ 길에 말이 있으면 그 칸에서 멈추고 그 칸의 말을 전부 장외 사출"],
	RUNAWAY: ["폭주 기관차", "◆ 무작위 한 변을 기관차가 질주!\n◆ 그 변의 모든 말 출발선으로 · 함정 카드 전부 파괴"],
	GUARANTEE: ["강제 연대책임", "◆ 내 선두 말과 가장 뒤 말이 일심동체\n◆ 하나가 골인하면 둘 다 골인 · 탈락하면 둘 다 탈락"],
}


static func display_name(effect: StringName) -> String:
	return "[초증강] %s" % str((INFO[effect] as Array)[0])


static func describe(effect: StringName) -> String:
	return str((INFO[effect] as Array)[1])


## 보드 위에 나와 있는 대표 말들 (출발 전·완주·업힌 말·결승 칸 제외). owner_id가 -1이면 모든 플레이어, enemies_of가 있으면 그 플레이어를 뺀 모두.
static func board_leaders(state: GameState, owner_id: int = -1, enemies_of: int = -1) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in state.pawns:
		if pawn.is_finished or pawn.carrier != null or not pawn.has_left_start or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		if owner_id != -1 and pawn.owner_id != owner_id:
			continue
		if enemies_of != -1 and pawn.owner_id == enemies_of:
			continue
		result.append(pawn)
	return result


## 결승까지 거리가 가장 짧은(1등에 가까운) 순으로 정렬한 대표 말들.
static func sorted_by_progress(state: GameState, pawns: Array[PlayerPawn]) -> Array[PlayerPawn]:
	var sorted: Array[PlayerPawn] = pawns.duplicate()
	sorted.sort_custom(func(a: PlayerPawn, b: PlayerPawn) -> bool:
		var da: int = state.pawn_progress_distance(a)
		var db: int = state.pawn_progress_distance(b)
		return da < db if da != db else a.entity_id < b.entity_id)
	return sorted


static func is_available(effect: StringName, state: GameState, player_id: int) -> bool:
	match effect:
		FLIP:
			return not board_leaders(state, player_id).is_empty()
		DEVIL:
			return state.finished_count(player_id) >= 1  # 되돌릴 완주 말이 있어야 한다
		MINEFIELD:
			return not empty_normal_tiles(state).is_empty()
		CASTLING:
			return board_leaders(state).size() >= 2
		SNIPER:
			return not board_leaders(state, -1, player_id).is_empty()
		NITRO:
			return state.front_pawn_of(player_id) != null  # 보드 위에 내 말이 있어야 달린다
		GUARANTEE:
			return bond_pair(state, player_id).size() == 2  # 보드 위에 내 말이 둘 이상이어야 묶을 수 있다
	return true  # 재분배·대습격·도박사·빵집 털이·폭주 기관차는 언제든


## 효과를 적용한다. 반환: {"ok": bool, "text": String}
static func apply(effect: StringName, state: GameState, player_id: int) -> Dictionary:
	match effect:
		FLIP: return _apply_flip(state, player_id)
		REDISTRIBUTE: return _apply_redistribute(state, player_id)
		DEVIL: return _apply_devil(state, player_id)
		MINEFIELD: return _apply_minefield(state, player_id)
		RAID: return _apply_raid(state, player_id)
		GAMBLER: return _apply_gambler(state, player_id)
		CASTLING: return _apply_castling(state)
		BAKERY: return _apply_bakery(state, player_id)
		SNIPER: return _apply_sniper(state, player_id)
		RUNAWAY: return _apply_runaway(state, player_id)
		GUARANTEE: return _apply_guarantee(state, player_id)
		NITRO: return _apply_nitro(state, player_id)
	return {"ok": false, "text": "알 수 없는 초증강입니다"}


static func _apply_flip(state: GameState, player_id: int) -> Dictionary:
	var mine: Array[PlayerPawn] = board_leaders(state, player_id)
	if mine.is_empty():
		return {"ok": false, "text": "보드 위에 내 말이 없습니다"}
	var pawn: PlayerPawn = mine[state.rng.randi_range(0, mine.size() - 1)]
	if state.rng.randi_range(0, 99) < flip_chance():
		state.finish_stack(pawn)
		return {"ok": true, "text": "판 뒤집기 성공! 말 %d번이 즉시 결승선에 완주했습니다" % pawn.slot}
	state.send_to_start(pawn, player_id)
	return {"ok": true, "text": "판 뒤집기 실패... 말 %d번이 출발선으로 추방되었습니다" % pawn.slot}


## 공산주의 재분배: 레이스에 남은 사람 모두의 말 배치를 꼴찌(4등)의 배치와 똑같이 맞추고(앞선 말끼리 짝지어 같은 칸·같은 완주 여부),
## 모든 손패를 덱에 섞어 넣은 뒤 각자 N장씩 다시 받는다.
static func _apply_redistribute(state: GameState, player_id: int) -> Dictionary:
	var active: Array[int] = state.active_players(state.player_ids)
	var laggard: int = -1
	var worst: Array = []
	for candidate: int in active:
		var key: Array = [state.finished_count(candidate), -_remaining(state, candidate)]
		if laggard == -1 or key < worst:
			laggard = candidate
			worst = key
	var template: Array[Dictionary] = []
	var hand_counts: Dictionary = {}
	for owner: int in active:
		hand_counts[owner] = (state.hands[owner] as Array).size()
	state.redistribution_started.emit(hand_counts,laggard)
	for pawn: PlayerPawn in _by_progress(state, state.pawns_of(laggard)):
		template.append({"tile": pawn.current_tile_idx, "history": pawn.step_history.duplicate(), "started": pawn.has_left_start, "finished": pawn.is_finished})
	for owner: int in active:
		for pawn: PlayerPawn in state.pawns_of(owner):
			pawn.carrier = null
			pawn.carried.clear()
	for owner: int in active:
		if owner == laggard:
			continue
		var mine: Array[PlayerPawn] = _by_progress(state, state.pawns_of(owner))
		for index: int in mini(mine.size(), template.size()):
			var pawn: PlayerPawn = mine[index]
			var spot: Dictionary = template[index]
			var from_tile: int = pawn.current_tile_idx
			pawn.current_tile_idx = int(spot["tile"])
			pawn.step_history.assign(spot["history"])
			pawn.has_left_start = bool(spot["started"])
			pawn.is_finished = bool(spot["finished"])
			if from_tile != pawn.current_tile_idx:
				state.pawn_teleported.emit(pawn.entity_id, pawn.current_tile_idx)
	var pool: Array[StringName] = []
	for owner: int in active:
		pool.append_array(state.hands[owner] as Array)
		(state.hands[owner] as Array).clear()
	state.card_deck.append_array(pool)
	state._shuffle(state.card_deck)
	for owner: int in active:
		for i: int in redistribute_cards():
			state.draw_card(owner)
	return {"ok": true, "text": "모두의 진도를 P%d(꼴찌)와 똑같이 맞추고, 손패 %d장을 회수해 %d장씩 다시 나눴습니다" % [laggard, pool.size(), redistribute_cards()]}


static func _remaining(state: GameState, player_id: int) -> int:
	var total: int = 0
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.is_finished:
			total += state.pawn_progress_distance(pawn)
	return total


## 앞선 순서(완주 → 결승까지 가까운 말 → 슬롯 번호)로 정렬한 말들.
static func _by_progress(state: GameState, pawns: Array[PlayerPawn]) -> Array[PlayerPawn]:
	var sorted: Array[PlayerPawn] = pawns.duplicate()
	sorted.sort_custom(func(a: PlayerPawn, b: PlayerPawn) -> bool:
		if a.is_finished != b.is_finished:
			return a.is_finished
		var da: int = 0 if a.is_finished else state.pawn_progress_distance(a)
		var db: int = 0 if b.is_finished else state.pawn_progress_distance(b)
		return da < db if da != db else a.slot < b.slot)
	return sorted


## 악마의 계약: 완주한 내 말 1개를 출발선으로 되돌리고 남은 게임 내내 모든 굴림 +N.
static func _apply_devil(state: GameState, player_id: int) -> Dictionary:
	var sacrifice: PlayerPawn = null
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished:
			sacrifice = pawn
			break
	if sacrifice == null:
		return {"ok": false, "text": "되돌릴 완주 말이 없습니다"}
	sacrifice.is_finished = false
	sacrifice.reset_to_start()
	state.pawn_sent_to_start.emit(sacrifice.entity_id, player_id)
	state.permanent_roll_bonus[player_id] = int(state.permanent_roll_bonus.get(player_id, 0)) + devil_bonus()
	return {"ok": true, "text": "완주한 말 %d번을 제물로 되돌리고 영구 +%d칸 가속 계약!" % [sacrifice.slot, devil_bonus()]}


## 빈 일반 타일: 코너·빵집·옷장·부스터 발판·결승이 아니고 설치물이 없는 칸.
static func empty_normal_tiles(state: GameState) -> Array[int]:
	var tiles: Array[int] = []
	for index: int in BoardSpec.tile_count:
		if index == GameEnums.GOAL_TILE or BoardSpec.corner_tiles.has(index) or BoardSpec.bakery_tiles.has(index) \
				or BoardSpec.portal_tiles.has(index) or BoardSpec.dash_tiles.has(index):
			continue
		if state.board.get_tile(index).attachments.is_empty():
			tiles.append(index)
	return tiles


static func _apply_minefield(state: GameState, player_id: int) -> Dictionary:
	var empty: Array[int] = empty_normal_tiles(state)
	var placed: Array[int] = []
	for i: int in mini(minefield_count(), empty.size()):
		var pick: int = state.rng.randi_range(0, empty.size() - 1)
		var tile: int = empty[pick]
		empty.remove_at(pick)
		var mine := TrapMine.new(player_id)
		mine.always_revealed = true  # 광란의 지뢰밭은 공개적으로 깔린다: 함정 비공개 규칙에서도 모두가 정체를 안다
		state.place_attachment(tile, mine)
		placed.append(tile)
	placed.sort()
	var traps: Array[StringName] = []
	for card_id: StringName in CardRegistry.all_ids():
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card.category == GameEnums.CardCategory.TRAP and not card.corner_only:
			traps.append(card_id)
	var got: Array[String] = []
	for i: int in minefield_trap_cards():
		if traps.is_empty():
			break
		var picked: StringName = traps[state.rng.randi_range(0, traps.size() - 1)]
		if state.give_card(player_id, picked):
			got.append(CardRegistry.get_card(picked).display_name)
	return {"ok": not placed.is_empty() or not got.is_empty(), "text": "빈 타일 %d곳(%s)에 지뢰 매설 + 함정 카드 %s" % [placed.size(), ", ".join(PackedStringArray(placed.map(func(tile: int) -> String: return "%d번" % tile))), ", ".join(got) if not got.is_empty() else "없음 (손패 가득)"]}


## 도적단 대습격: 중립 기물(소환) 카드를 받고, 나를 뺀 모든 플레이어에게서 카드를 무작위로 1장씩 빼앗아 온다.
## 내 손패가 가득 차서 못 받는 카드는 주인에게 돌려준다. 어떤 카드인지는 알리지 않는다.
static func _apply_raid(state: GameState, player_id: int) -> Dictionary:
	var summons: Array[StringName] = []
	for card_id: StringName in CardRegistry.all_ids():
		if CardRegistry.get_card(card_id).category == GameEnums.CardCategory.SUMMON:
			summons.append(card_id)
	var got_summon: int = 0
	for i: int in raid_summon_cards():
		if summons.is_empty():
			break
		if state.give_card(player_id, summons[state.rng.randi_range(0, summons.size() - 1)]):
			got_summon += 1
	var stolen: int = 0
	for victim: int in state.active_players(state.player_ids):
		if victim == player_id:
			continue
		for i: int in raid_steal_each():
			var card_id: StringName = state.steal_random_card(victim, state.rng)
			if card_id == &"":
				break
			if state.give_card(player_id, card_id):
				stolen += 1
			else:
				state.give_card(victim, card_id)  # 내 손패가 가득: 돌려준다
	return {"ok": true, "text": "중립 기물 카드 %d장 획득, 다른 플레이어에게서 카드 %d장을 빼앗았습니다" % [got_summon, stolen]}


## 폭주 기관차: 무작위 한 변(코너에서 다음 코너까지)을 기관차가 질주하며 그 변의 모든 말을 출발선으로 보내고 함정 카드를 전부 부순다 (내 말도 예외 없음).
static func _apply_runaway(state: GameState, player_id: int) -> Dictionary:
	var side_index: int = state.rng.randi_range(0, 3)
	var run: Dictionary = NpcSweep.run(state, side_index * BoardSpec.side, 1, BoardSpec.side, &"TRAIN", player_id, true)
	var path: Array = run["path"]
	state.npc_swept.emit(&"TRAIN", run["path"], run["ejected"])
	return {"ok": true, "text": "폭주 기관차가 %d번 → %d번 변을 질주! 말 %d개 사출, 함정 %d개 파괴" % [int(path[0]), int(path[-1]), (run["ejected"] as Array).size(), int(run["destroyed"])]}


## 강제 연대책임으로 묶을 내 두 말: 보드 위 내 말 중 가장 앞선 말과 가장 뒤처진 말. 둘이 안 되면 빈 배열.
static func bond_pair(state: GameState, player_id: int) -> Array[PlayerPawn]:
	var mine: Array[PlayerPawn] = []
	for pawn: PlayerPawn in sorted_by_progress(state, board_leaders(state, player_id)):
		if not state.bonds.has(pawn.entity_id):
			mine.append(pawn)
	if mine.size() < 2:
		return [] as Array[PlayerPawn]
	return [mine[0], mine[-1]] as Array[PlayerPawn]


static func _apply_guarantee(state: GameState, player_id: int) -> Dictionary:
	var pair: Array[PlayerPawn] = bond_pair(state, player_id)
	if pair.size() < 2:
		return {"ok": false, "text": "보드 위에 내 말이 둘 이상 있어야 합니다"}
	state.bind_pawns(pair[0], pair[1])
	return {"ok": true, "text": "말 %d번(선두)과 말 %d번(후방)이 일심동체! 하나가 골인하면 둘 다 골인, 탈락하면 둘 다 탈락" % [pair[0].slot, pair[1].slot]}


static func _apply_gambler(state: GameState, player_id: int) -> Dictionary:
	state.gambler_round[player_id] = state.round_number
	return {"ok": true, "text": "이번 라운드 이동 거리 %d배! (눈금 %d 이하면 과열: 이동 없이 차례가 바로 끝남)" % [gambler_multiplier(), gambler_overheat_at()]}


static func _apply_castling(state: GameState) -> Dictionary:
	var leaders: Array[PlayerPawn] = board_leaders(state)
	if leaders.size() < 2:
		return {"ok": false, "text": "섞을 말이 부족합니다"}
	# 피셔-예이츠: 자리(위치)를 말들 사이에서 무작위로 맞바꾼다
	for i: int in range(leaders.size() - 1, 0, -1):
		var j: int = state.rng.randi_range(0, i)
		if i != j and leaders[i].current_tile_idx != leaders[j].current_tile_idx:
			state.swap_stacks(leaders[i], leaders[j])
	return {"ok": true, "text": "보드 위 말 %d개의 위치를 전부 섞었습니다!" % leaders.size()}


static func _apply_bakery(state: GameState, player_id: int) -> Dictionary:
	var pool: Array[StringName] = CardRegistry.all_ids()
	var names: Array[String] = []
	for i: int in bakery_cards():
		var picked: StringName = pool[state.rng.randi_range(0, pool.size() - 1)]
		if state.give_card(player_id, picked):
			names.append(CardRegistry.get_card(picked).display_name)
	var launched: PlayerPawn = null
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.has_left_start and not pawn.is_finished:
			launched = pawn
			break
	var text: String = "빵집 털이! 생떼 카드 %d장(%s)" % [names.size(), ", ".join(names)]
	if launched != null and not BoardSpec.bakery_tiles.is_empty():
		var ctx := RuleContext.new()
		ctx.state = state
		ctx.actor_id = player_id
		ctx.pawn = launched
		launched.has_left_start = true
		launched.revenge_boost = false
		MoveExecutor.teleport_to(state, launched, ctx, MoveReport.new(), BoardSpec.bakery_tiles[0])
		text += " + 말 %d번을 %d번 빵집으로 출격" % [launched.slot, BoardSpec.bakery_tiles[0]]
	return {"ok": true, "text": text}


static func _apply_sniper(state: GameState, player_id: int) -> Dictionary:
	var targets: Array[PlayerPawn] = sorted_by_progress(state, board_leaders(state, -1, player_id))
	if targets.is_empty():
		return {"ok": false, "text": "저격할 적 말이 없습니다"}
	state.send_to_start(targets[0], player_id)
	var booster: PlayerPawn = state.front_pawn_of(player_id)
	if booster == null:
		for candidate: PlayerPawn in state.pawns_of(player_id):
			if candidate.is_selectable():
				booster = candidate
				break
	if booster != null:
		MoveExecutor.forced_advance(state, booster, sniper_advance())
	return {"ok": true, "text": "선두 적 말을 출발선으로 사출하고 내 말 +%d칸!" % sniper_advance()}


## 아우토반 니트로가 달릴 길: 선두 말 다음 칸부터 다음 코너까지 (결승선이면 0번까지). 말이 서 있는 칸을 만나면 거기서 끊는다.
## 반환: {"path": [칸], "blocked": 말이 있어 멈춘 칸 또는 -1}
static func nitro_route(state: GameState, pawn: PlayerPawn) -> Dictionary:
	var path: Array[int] = []
	var tile: int = pawn.current_tile_idx
	for _i: int in BoardSpec.tile_count:
		tile = posmod(tile + 1, BoardSpec.tile_count)
		path.append(tile)
		if tile == GameEnums.GOAL_TILE:
			return {"path": path, "blocked": -1}  # 결승선까지 막힘 없이 달렸다
		for other: PlayerPawn in state.leaders_at(tile):
			if other != pawn and other.has_left_start:
				return {"path": path, "blocked": tile}
		if BoardSpec.corner_tiles.has(tile):
			break
	return {"path": path, "blocked": -1}


## 아우토반 니트로: 내 선두 말(업힌 말과 함께)이 다음 코너까지 설치물 판정 없이 일직선으로 질주한다.
## 길에 어떤 말이든 서 있으면 그 칸에서 멈추고 그 칸의 말을 전부 출발선으로 장외 사출한다. 다음 코너가 결승선이면 완주한다.
static func _apply_nitro(state: GameState, player_id: int) -> Dictionary:
	var pawn: PlayerPawn = state.front_pawn_of(player_id)
	if pawn == null:
		return {"ok": false, "text": "보드 위에 내 말이 없습니다"}
	var route: Dictionary = nitro_route(state, pawn)
	var path: Array[int] = route["path"]
	var blocked: int = int(route["blocked"])
	state.nitro_dashed.emit(pawn.entity_id, path.duplicate(), blocked)
	for destination: int in path:
		if destination == GameEnums.GOAL_TILE:
			state.finish_stack(pawn)
			return {"ok": true, "text": "아우토반 니트로! 말 %d번이 결승선까지 질주해 완주했습니다" % pawn.slot}
		var from_tile: int = pawn.current_tile_idx
		state.board.commit_step(pawn, destination)
		state.sync_stack_position(pawn)
		state.pawn_stepped.emit(pawn.entity_id, from_tile, destination)
	if blocked == -1:
		return {"ok": true, "text": "아우토반 니트로! 말 %d번이 %d번 코너까지 질주했습니다" % [pawn.slot, path.back()]}
	var ejected: int = 0
	for victim: PlayerPawn in state.leaders_at(blocked):
		if victim == pawn or not victim.has_left_start:
			continue
		ejected += victim.stack_members().size()
		state.send_to_start(victim, player_id)
	return {"ok": true, "text": "아우토반 니트로! %d번 칸에서 말 %d개를 장외 사출했습니다" % [blocked, ejected]}


static func _apply_personal(effect: StringName, state: GameState, player_id: int) -> Dictionary:
	if not state.rulebook.add_personal(String(effect), player_id):
		return {"ok": false, "text": "이미 가진 패시브입니다"}
	var law: LawResource = LawRegistry.create(String(effect))
	return {"ok": true, "text": "[%s] 남은 게임 내내: %s" % [law.law_name, law.description]}
