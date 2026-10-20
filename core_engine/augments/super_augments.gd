# File: res://core_engine/augments/super_augments.gd
# Class: class_name SuperAugments
# Role: [초증강 : 도박 & 억까] 10종 - 드래프트에서만 나오는 하이리스크 증강의 조건·효과. 모든 난수는 호스트 RNG(state.rng)를 쓰고 효과는 GameState 시그널로 방송되어 화면이 연출한다
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
const NITRO: StringName = &"SUPER_10"          # 아우토반 니트로 (개인 영구 패시브)
const RUNAWAY: StringName = &"SUPER_11"        # 폭주 기관차 (개인 영구 패시브)
const GUARANTEE: StringName = &"SUPER_12"      # 강제 연대보증 (개인 영구 패시브)

const ALL_IDS: Array[StringName] = [FLIP, REDISTRIBUTE, DEVIL, MINEFIELD, RAID, GAMBLER, CASTLING, BAKERY, SNIPER, NITRO, RUNAWAY, GUARANTEE]
## 남은 게임 내내 그 플레이어에게만 작동하는 패시브 (RuleBookManager.personal_laws, 법전 슬롯을 차지하지 않는다).
const PERSONAL: Array[StringName] = [NITRO, RUNAWAY, GUARANTEE]

## 수치 기본값 (content_trickcal/data/augments_table.csv의 param_1·param_2가 비어 있을 때만 쓴다).
const FLIP_FINISH_CHANCE_PERCENT: int = 50
const DEVIL_BONUS: int = 3
const MINEFIELD_COUNT: int = 5
const RAID_ROBBERS: int = 2
const RAID_GHOSTS: int = 1
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


static func minefield_count() -> int:
	return maxi(param(MINEFIELD, 1, MINEFIELD_COUNT), 0)


static func raid_robbers() -> int:
	return maxi(param(RAID, 1, RAID_ROBBERS), 0)


static func raid_ghosts() -> int:
	return maxi(param(RAID, 2, RAID_GHOSTS), 0)


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
	FLIP: ["판 뒤집기 (모 아니면 도)", "◆ 보드 위 내 말 1개를 무작위로 골라\n◆ 50% 즉시 결승선 완주!\n◆ 실패하면 출발선 추방 + 다음 턴 휴식"],
	REDISTRIBUTE: ["공산주의 재분배", "◆ 1등의 가장 앞선 말 ↔ 내 가장 뒤처진 말 위치 강제 교환\n◆ 1등의 손패 카드 1장 강탈"],
	DEVIL: ["악마의 계약 (영구 가속)", "◆ 내 말 1개를 출발선으로 제물\n◆ 남은 게임 내내 내 모든 굴림 결과에 +3칸"],
	MINEFIELD: ["광란의 지뢰밭", "◆ 빈 타일 5곳에 은신 함정(거울의 힘 또는 지뢰) 일제 살포\n◆ 설치한 내 눈에는 위치가 보인다"],
	RAID: ["도적단 대습격", "◆ 카탄의 도적떼 2마리 + 팩맨 고스트 1마리 동시 소환\n◆ 판 전체가 아수라장!"],
	GAMBLER: ["주사위 도박사의 영혼", "◆ 이번 라운드 이동 거리 2배(x2) 증폭!
◆ 단 눈금 1 이하면 이동한 내 말이 과열되어 0번 출발선으로 사출"],
	CASTLING: ["강제 캐슬링 룰렛", "◆ 보드 위 모든 플레이어 말의 위치를 무작위로 전부 섞는다"],
	BAKERY: ["에르핀의 빵집 털이", "◆ 무작위 생떼 카드 3장 획득\n◆ 모든 빵집 타일에 내 통행료 호텔 설치"],
	SNIPER: ["저격수의 표적", "◆ 가장 앞선 적 말 1개를 즉시 0번 출발선으로 장외 사출
◆ 내 말 1개를 +4칸 전진 + 그 자리에 스프링 대포 설치"],
	NITRO: ["아우토반 니트로", "◆ 남은 게임 내내 내 눈금이 짝수이거나 5 이상이면 +3칸!"],
	RUNAWAY: ["폭주 기관차", "◆ 남은 게임 내내 내 말이 적을 처치하면 그 자리에서 +4칸 돌진!"],
	GUARANTEE: ["강제 연대보증", "◆ 남은 게임 내내 내 말이 잡히면\n◆ 공격자의 다른 말 1개 동반 처치 + 카드 1장"],
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


## 1등 플레이어의 가장 앞선 말 (player_id를 뺀 상대 중). 없으면 null.
static func leader_pawn(state: GameState, player_id: int) -> PlayerPawn:
	var enemies: Array[PlayerPawn] = sorted_by_progress(state, board_leaders(state, -1, player_id))
	return enemies[0] if not enemies.is_empty() else null


## 출발 전 말까지 포함해 내 대표 말 중 결승에서 가장 먼(가장 뒤처진) 말.
static func laggard_pawn(state: GameState, player_id: int) -> PlayerPawn:
	var worst: PlayerPawn = null
	var worst_distance: int = -1
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished or pawn.carrier != null:
			continue
		var distance: int = state.pawn_progress_distance(pawn)
		if distance > worst_distance:
			worst_distance = distance
			worst = pawn
	return worst


static func is_available(effect: StringName, state: GameState, player_id: int) -> bool:
	match effect:
		FLIP, DEVIL:
			return not board_leaders(state, player_id).is_empty()
		REDISTRIBUTE:
			var first: PlayerPawn = leader_pawn(state, player_id)
			var last: PlayerPawn = laggard_pawn(state, player_id)
			return first != null and last != null and state.pawn_progress_distance(last) > state.pawn_progress_distance(first)
		MINEFIELD:
			return not _empty_tiles(state).is_empty()
		RAID:
			return state.npcs.size() < GameEnums.MAX_NPCS
		CASTLING:
			return board_leaders(state).size() >= 2
		SNIPER:
			return not board_leaders(state, -1, player_id).is_empty()
		NITRO, RUNAWAY, GUARANTEE:
			return not state.rulebook.has_personal(String(effect), player_id)
	return true  # 도박사·빵집 털이는 언제든


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
		NITRO, RUNAWAY, GUARANTEE: return _apply_personal(effect, state, player_id)
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
	state.rest_next_turn[player_id] = true
	return {"ok": true, "text": "판 뒤집기 실패... 말 %d번이 출발선으로 추방되고 다음 턴을 쉽니다" % pawn.slot}


static func _apply_redistribute(state: GameState, player_id: int) -> Dictionary:
	var first: PlayerPawn = leader_pawn(state, player_id)
	var last: PlayerPawn = laggard_pawn(state, player_id)
	if first == null or last == null or state.pawn_progress_distance(last) <= state.pawn_progress_distance(first):
		return {"ok": false, "text": "재분배할 대상이 없습니다"}
	var victim_player: int = first.owner_id
	state.swap_stacks(last, first)
	var stolen: StringName = state.steal_random_card(victim_player, state.rng)
	var text: String = "P%d의 선두 말과 내 꼴찌 말의 위치를 맞바꿨습니다" % victim_player
	if stolen != &"":
		if state.give_card(player_id, stolen):
			text += " (카드 [%s] 강탈)" % CardRegistry.get_card(stolen).display_name
		else:
			(state.hands[victim_player] as Array).append(stolen)  # 내 손패가 가득 차면 카드는 주인에게 돌려준다
			text += " (내 손패가 가득 차 카드는 돌려줌)"
	return {"ok": true, "text": text}


static func _apply_devil(state: GameState, player_id: int) -> Dictionary:
	var mine: Array[PlayerPawn] = board_leaders(state, player_id)
	if mine.is_empty():
		return {"ok": false, "text": "제물로 바칠 말이 없습니다"}
	# 가장 뒤처진(결승에서 먼) 보드 위 말을 바친다
	var sacrifice: PlayerPawn = sorted_by_progress(state, mine)[mine.size() - 1]
	state.send_to_start(sacrifice, player_id)
	state.permanent_roll_bonus[player_id] = int(state.permanent_roll_bonus.get(player_id, 0)) + devil_bonus()
	return {"ok": true, "text": "말 %d번을 제물로 바치고 영구 +%d칸 가속 계약!" % [sacrifice.slot, devil_bonus()]}


## 빈 타일: 결승 칸이 아니고 설치물이 없는 칸.
static func _empty_tiles(state: GameState) -> Array[int]:
	var tiles: Array[int] = []
	for index: int in BoardSpec.tile_count:
		if index == GameEnums.GOAL_TILE:
			continue
		if state.board.get_tile(index).attachments.is_empty():
			tiles.append(index)
	return tiles


static func _apply_minefield(state: GameState, player_id: int) -> Dictionary:
	var empty: Array[int] = _empty_tiles(state)
	if empty.is_empty():
		return {"ok": false, "text": "함정을 깔 빈 타일이 없습니다"}
	var placed: Array[int] = []
	for i: int in mini(minefield_count(), empty.size()):
		var pick: int = state.rng.randi_range(0, empty.size() - 1)
		var tile: int = empty[pick]
		empty.remove_at(pick)
		var trap: TileAttachment = TrapMine.new(player_id) if state.rng.randi_range(0, 1) == 0 else TrapMirrorForce.new(player_id)
		state.place_attachment(tile, trap)
		placed.append(tile)
	placed.sort()
	return {"ok": true, "text": "빈 타일 %d곳(%s)에 은신 함정을 살포했습니다" % [placed.size(), ", ".join(PackedStringArray(placed.map(func(tile: int) -> String: return "%d번" % tile)))]}


static func _apply_raid(state: GameState, player_id: int) -> Dictionary:
	var room: int = GameEnums.MAX_NPCS - state.npcs.size()
	if room <= 0:
		return {"ok": false, "text": "더 소환할 자리가 없습니다"}
	var spawned_robbers: int = 0
	var spawned_ghost: int = 0
	var order: Array[StringName] = []
	for i: int in raid_robbers():
		order.append(&"SUM_01")
	for i: int in raid_ghosts():
		order.append(&"SUM_02")
	for id: StringName in order:
		if state.npcs.size() >= GameEnums.MAX_NPCS:
			break
		if id == &"SUM_02":
			state.spawn_npc(BoardSpec.halfway_tile, GameEnums.NpcBehavior.PATROL_REVERSE, player_id, id)
			spawned_ghost += 1
		else:
			var tile: int = state.rng.randi_range(1, BoardSpec.tile_count - 1)
			state.spawn_npc(tile, GameEnums.NpcBehavior.CHASE_NEAREST, player_id, id)
			spawned_robbers += 1
	return {"ok": true, "text": "도적떼 %d마리와 팩맨 고스트 %d마리가 판에 나타났습니다!" % [spawned_robbers, spawned_ghost]}


static func _apply_gambler(state: GameState, player_id: int) -> Dictionary:
	state.gambler_round[player_id] = state.round_number
	return {"ok": true, "text": "이번 라운드 이동 거리 %d배! (눈금 %d 이하면 이동한 말이 과열되어 출발선으로 사출)" % [gambler_multiplier(), gambler_overheat_at()]}


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
	var hotels: int = 0
	for tile: int in BoardSpec.bakery_tiles:
		var has_mine: bool = false
		for attachment: TileAttachment in state.board.get_tile(tile).attachments:
			if attachment.attachment_id == "HOTEL" and attachment.owner_id == player_id:
				has_mine = true
		if not has_mine:
			state.place_attachment(tile, Hotel.new(player_id))
			hotels += 1
	return {"ok": true, "text": "빵집 털이! 생떼 카드 %d장(%s) + 호텔 %d채" % [names.size(), ", ".join(names), hotels]}


static func _apply_sniper(state: GameState, player_id: int) -> Dictionary:
	var targets: Array[PlayerPawn] = sorted_by_progress(state, board_leaders(state, -1, player_id))
	if targets.is_empty():
		return {"ok": false, "text": "저격할 적 말이 없습니다"}
	var victim: PlayerPawn = targets[0]
	var origin: int = victim.current_tile_idx
	state.send_to_start(victim, player_id)
	state.place_attachment(origin, TrapDomino.new(player_id))
	var booster: PlayerPawn = state.front_pawn_of(player_id)
	if booster == null:
		for candidate: PlayerPawn in state.pawns_of(player_id):
			if candidate.is_selectable():
				booster = candidate
				break
	if booster != null:
		MoveExecutor.forced_advance(state, booster, sniper_advance())
	return {"ok": true, "text": "선두 적 말을 출발선으로 사출하고 내 말 +%d칸! 그 자리에 스프링 대포를 깔았습니다" % sniper_advance()}


static func _apply_personal(effect: StringName, state: GameState, player_id: int) -> Dictionary:
	if not state.rulebook.add_personal(String(effect), player_id):
		return {"ok": false, "text": "이미 가진 패시브입니다"}
	var law: LawResource = LawRegistry.create(String(effect))
	return {"ok": true, "text": "[%s] 남은 게임 내내: %s" % [law.law_name, law.description]}
