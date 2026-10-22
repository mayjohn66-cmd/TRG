# File: res://core_engine/game_state.gd
# Class: class_name GameState
# Role: 한 판의 모든 권위 상태(보드·기물·NPC·법전·손패·판정 도구)와 상태 변경 헬퍼. 모든 변화는 시그널로만 외부에 알린다.
class_name GameState
extends RefCounted

# --- 뷰/네트워크 계층이 구독하는 시그널 (코어는 UI를 직접 참조하지 않는다) ---
signal pawn_stepped(pawn_id: int, from_tile: int, to_tile: int)
signal pawn_warped(pawn_id: int, from_tile: int, to_tile: int)
signal pawn_sent_to_start(pawn_id: int, by_player: int)
## A real player-pawn capture, once per victim stack, before reset signals.
## Traps, self-recalls and NPC attacks deliberately do not emit this.
signal pawn_captured(attacker_pawn_id: int, victim_pawn_id: int)
signal pawn_finished(pawn_id: int)
signal pawn_evolved(pawn_id: int, kind: int, unit_no: int)
## 체스 폰이 반환점(BoardSpec.halfway_tile) 이상에 도달해 퀸으로 영구 승진했다.
signal pawn_promoted(pawn_id: int)
signal pawns_stacked(leader_id: int, member_ids: Array[int])
signal pawns_swapped(pawn_a_id: int, pawn_b_id: int)
signal pawn_teleported(pawn_id: int, to_tile: int)
signal npc_spawned(npc_id: int, tile: int)
signal npc_vanished(npc_id: int, tile: int)
signal npc_stepped(npc_id: int, from_tile: int, to_tile: int)
signal attachment_placed(tile: int, attachment_id: String, owner_id: int)
signal attachment_triggered(tile: int, attachment_id: String, pawn_id: int, cutscene_id: StringName)
signal card_drawn(player_id: int, card_id: StringName)
signal card_stolen(player_id: int, card_id: StringName)
## ACT_01이 턴 순서 반전을 요청했다. 턴 순서는 TurnManager가 소유하므로 TurnManager가 구독해 처리한다.
signal turn_order_reverse_requested()
## ACT_03 우노 +4 결과: victim 플레이어의 선두 말이 from_tile에서 to_tile로 4칸 후퇴했다.
signal bomb_resolved(shooter: int, victim: int, pawn_id: int, from_tile: int, to_tile: int)
## ACT_02 뱅! 저격 결과: 저격당한 선두 말이 from_tile에서 to_tile로 2칸 밀려났다.
signal bang_resolved(shooter: int, target_pawn_id: int, from_tile: int, to_tile: int)
## 기물 능력 알림: 룩 캐슬링(위치 교환) / 백돌 무적에 막혀 밀려남.
signal pawns_castled(pawn_a_id: int, pawn_b_id: int)
signal dash_pad_triggered(pawn_id: int, tile: int)
## 리벤지 부스터가 장전된 말이 출발한다 (첫 걸음 직전). base: 기본 눈금, bonus: 추가 칸, total: 최종 계획 칸 수.
signal revenge_boost_fired(pawn_id: int, base_steps: int, bonus: int, total: int)
signal pawn_pushed_back(pawn_id: int, from_tile: int, to_tile: int)
## 바둑 백돌 방어막이 잡기·함정을 막고 깨졌다 / 다시 차올랐다.
signal shield_broken(pawn_id: int, tile: int)
signal shield_recharged(pawn_id: int)
## 지뢰찾기 공병이 적 함정을 해체했다.
signal trap_defused(tile: int, attachment_id: String, pawn_id: int)
## TRP_05 도미노 연쇄: 밟은 말(pawn_id)이 멈췄고 chain 칸들의 함정이 연쇄로 터졌다. passed는 예전 형식 호환용(항상 빈 배열).
signal domino_collapsed(pawn_id: int, passed: Array[int], chain: Array[int])
## ACT_07 무너지는 탑이 tile에 벼락을 쳐 말들을 흩어 놓았다 (scattered: {"pawn_id", "from", "to"}).
signal tower_struck(tile: int, scattered: Array[Dictionary])
## ACT_07 무너지는 탑: 한 변의 설치물이 무너졌다. / ACT_10 빠루를 휘둘렀다.
signal side_collapsed(side: int, tiles: Array[int], destroyed: int)
signal crowbar_swung(player_id: int, tiles: Array[int])
## 소환 카드·폭주 기관차: 사료스탕스·와구와구 유령·기관차가 길을 쓸었다.
signal npc_swept(display_id: StringName, path: Array[int], ejected: Array[int])
## Presentation snapshot point, before the one-shot sweep resets pawns or removes traps.
signal npc_sweep_started(display_id: StringName, path: Array[int])
## ACT_08 운명의 수레바퀴: outcome은 "swap"(내 말 mine_id와 적 말 enemy_id의 위치 교환) 또는 "retreat"(적 말 후퇴, mine_id = -1).
signal wheel_turned(player_id: int, mine_id: int, enemy_id: int, outcome: StringName)
## ACT_09 일기토 데스매치 신청: challenger가 defender에게 결투를 걸었다 (진행은 TurnManager가 입력을 받아 한다).
signal duel_requested(challenger: int, defender: int)
signal snapshot_restored()
signal victory_declared(player_id: int, reason: StringName)
## 강제 연대책임: 두 말이 묶였다 / 묶인 짝이 같이 골인(&"finish")·탈락(&"eject")했다.
signal pawns_bonded(pawn_a_id: int, pawn_b_id: int)
signal bond_resolved(kind: StringName, pawn_id: int, partner_id: int)

var board: BoardGraph = BoardGraph.new()
## Node 기반 법전. 씬 트리에 붙이지 않고 GameState가 수명을 관리한다.
var rulebook: RuleBookManager = RuleBookManager.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var player_ids: Array[int] = []
var pawns: Array[PlayerPawn] = []
var npcs: Array[NeutralNPC] = []
var _next_npc_id: int = 100

## 플레이어 ID -> Array[StringName] 손패 / 플레이어 ID -> BaseJudgmentTool. (스냅샷에 포함되지 않는다.)
var hands: Dictionary = {}
var tools: Dictionary = {}
var card_deck: Array[StringName] = []

## 폭풍 전진 가속 기믹(부스터 발판 · 말 밟고 점프 · 리벤지 부스터)을 켠다. 규칙 판정용 스위치라 단위 테스트가 기본 이동 규칙만 따로 검증할 때 끈다.
var boost_gimmicks: bool = true
var current_player: int = -1
var round_number: int = 1
## 남은 '전체 역주행' 라운드 수 (ACT_01).
var reverse_move_rounds_left: int = 0
## 이번 턴 첫 굴림 결과에 더할 값 (ACT_04 긴급 로켓 부스터). 굴림에 쓰이거나 턴이 시작되면 0으로 돌아간다.
var roll_bonus: int = 0
## 코너에 정확히 도착해 얻은 버프: 플레이어 -> 다음 굴림 결과에 더할 칸 수 (굴림에 쓰이면 사라진다).
var corner_buff: Dictionary = {}
## [초증강] 악마의 계약: 플레이어별 영구 굴림 보너스 칸수.
var permanent_roll_bonus: Dictionary = {}
## [초증강] 주사위 도박사의 영혼: 플레이어 -> 효과가 켜진 라운드 번호 (그 라운드 동안만 이동 2배).
var gambler_round: Dictionary = {}
## UDO 스킵(ACT_15)으로 다음 내 턴을 쉬어야 하는 플레이어들 (강제 턴 패스).
var rest_next_turn: Dictionary = {}
var winner: int = -1
## 서바이벌 순위제: 승리 조건을 먼저 달성한 순서대로 쌓이는 플레이어 ID (0번째 = 1위). 졸업한 플레이어는 레이스에서 빠지고 턴을 건너뛴다.
var rankings: Array[int] = []
## 플레이어 ID -> 순위를 확정한 사유 (all_home / 특수 승리 교칙 ID / last_place)
var rank_reasons: Dictionary = {}
## 순위가 확정된 순간의 레이스 진행 (말을 철수하기 전): 플레이어 ID -> {"finished", "remaining", "progress"}. 결과 화면이 쓴다.
var rank_stats: Dictionary = {}
## 이번 턴의 공격 기록 (방어 카드 대상). 턴이 시작될 때 비운다. 원소: {id, kind(capture/card/trap), victim, attacker, attacker_pawn,
## card_id, trap_id, trap_tile, trap_owner, trap_data, pawns: {말 ID: 피해 직전 상태}, stats: {kills, ejected, underdog}, effects: {}, offered, countered}
var attack_log: Array[Dictionary] = []
## 지금 진행 중인 공격의 출처 (begin_attack ~ end_attack 사이). 비어 있으면 공격으로 기록하지 않는다.
var attack_source: Dictionary = {}
var _attack_stack: Array[Dictionary] = []
var _attack_serial: int = 0
var _attack_next_id: int = 1
## ACT_14 알고리즘 밴: 플레이어 ID -> 남은 내 턴 수 (카드·필살기·리롤 금지).
var banned_turns: Dictionary = {}
## ACT_11 밑장빼기: 플레이어 ID -> 다음 굴림 결과로 쓸 칸 수.
var forced_roll: Dictionary = {}
## ACT_12 더 월드: 이번 턴이 끝나면 한 턴을 더 하는 플레이어들.
var extra_turns: Dictionary = {}
## 🏆 특수 승리 교칙 진행도: 플레이어 ID -> {kills, ejected, underdog, best_move, best_chain, turn_hand}.
## 누적 기록(kills·ejected·underdog)은 게임 시작부터 세고, 순간 기록(best_*·turn_hand)은 해당 교칙이 법전에 있는 동안만 센다.
var law_stats: Dictionary = {}

## 이번 턴 시작 시점 스냅샷 (ACT_05 롤백 대상).
var turn_snapshot: TurnSnapshot = null
## 이번 턴에 말이 잡히거나 함정을 밟은 플레이어들 (ACT_05 발동 조건).
var hurt_players: Array[int] = []
## 초증강 강제 연대책임: 일심동체로 묶인 두 말 (말 ID -> 짝 말 ID, 양쪽 모두 적는다). 하나가 골인·탈락하면 짝도 같이, 그 뒤 풀린다.
var bonds: Dictionary = {}
## 턴 진행 방향 미러 (TurnManager가 소유·갱신한다): 1 정방향 / -1 역방향. next_player_after가 사용한다.
var turn_direction: int = 1
## ACT_03 우노 +4: 플레이어 ID -> 다음 자기 턴 시작에 받을 후퇴 페널티(음수 칸 수). 0이면 없음.
## ACT_05가 실행되었음을 TurnManager에 알리는 플래그.
var rollback_requested: bool = false
## CNT_01: 되감은 뒤 그 턴을 바로 끝낸다 (공격한 사람의 턴 종료).
var rollback_ends_turn: bool = false


## BoardGraph·RuleBookManager·기물·NPC는 Node라 씬 트리에 붙이지 않고 GameState가 수명을 관리한다.
## (PREDELETE 중에는 자기 메서드를 호출할 수 없으므로 멤버만 직접 정리한다.)
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for npc: NeutralNPC in npcs:
		if is_instance_valid(npc):
			npc.free()
	for pawn: PlayerPawn in pawns:
		if is_instance_valid(pawn):
			pawn.free()
	if is_instance_valid(rulebook):
		rulebook.free()
	if is_instance_valid(board):
		board.free()


func clear_npcs() -> void:
	for npc: NeutralNPC in npcs:
		if is_instance_valid(npc):
			npc.free()
	npcs.clear()


# ---------------------------------------------------------------------------
# 초기화
# ---------------------------------------------------------------------------

## loadouts: 플레이어 ID -> 말 4개의 시작 구성(테스트·시나리오용). 각 원소는 PawnKind 정수 또는 Vector2i(세트, 호기).
## 생략하면 모두 진화하지 않은 기본 말이다.
func setup(ids: Array[int], seed_value: int = 0, loadouts: Dictionary = {}) -> void:
	player_ids = ids.duplicate()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for old_pawn: PlayerPawn in pawns:
		old_pawn.free()
	pawns.clear()
	clear_npcs()
	hands.clear()
	tools.clear()
	for player_id: int in player_ids:
		hands[player_id] = [] as Array[StringName]
		tools[player_id] = ToolRegistry.create(&"D6")
		var kinds: Array = loadouts.get(player_id, [])
		for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
			var pawn := PlayerPawn.new()
			pawn.entity_id = player_id * 10 + slot
			pawn.owner_id = player_id
			pawn.slot = slot
			if kinds.size() >= slot:
				var entry: Variant = kinds[slot - 1]
				if entry is Vector2i:
					pawn.evolve(entry.x, entry.y)
				else:
					pawn.evolve(int(entry), 0 if int(entry) == GameEnums.PawnKind.BASIC else 1)
			pawns.append(pawn)
	current_player = player_ids[0] if not player_ids.is_empty() else -1
	card_deck = CardRegistry.default_deck()
	_shuffle(card_deck)


func _shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap


# ---------------------------------------------------------------------------
# 조회
# ---------------------------------------------------------------------------

func get_pawn(pawn_id: int) -> PlayerPawn:
	for pawn: PlayerPawn in pawns:
		if pawn.entity_id == pawn_id:
			return pawn
	return null


## 기물을 한 번 잡은 NPC를 판에서 제거한다.
func remove_npc(npc: NeutralNPC) -> void:
	if npc == null or not npcs.has(npc):
		return
	npcs.erase(npc)
	npc_vanished.emit(npc.entity_id, npc.current_tile_idx)
	if is_instance_valid(npc):
		npc.free()


func get_npc(npc_id: int) -> NeutralNPC:
	for npc: NeutralNPC in npcs:
		if npc.entity_id == npc_id:
			return npc
	return null


## 플레이어가 소유한 해당 세트의 말 수 (세트 시너지 판정). 완주한 말도 세트에 포함한다.
func set_count(player_id: int, kind: GameEnums.PawnKind) -> int:
	var count: int = 0
	for pawn: PlayerPawn in pawns:
		if pawn.owner_id == player_id and pawn.kind == kind:
			count += 1
	return count


## 아직 진화하지 않은 플레이어의 기본 말들.
func basic_pawns_of(player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns:
		if pawn.owner_id == player_id and pawn.kind == GameEnums.PawnKind.BASIC:
			result.append(pawn)
	return result


## 기본 말 하나를 세트의 다음 호기로 영구 진화시킨다. 기본 말이 아니거나 세트가 이미 4호기까지 찼으면 false.
func evolve_pawn(pawn: PlayerPawn, kind: GameEnums.PawnKind) -> bool:
	if pawn == null or pawn.kind != GameEnums.PawnKind.BASIC or kind == GameEnums.PawnKind.BASIC:
		return false
	var next_unit: int = set_count(pawn.owner_id, kind) + 1
	if next_unit > GameEnums.PAWNS_PER_PLAYER:
		return false
	pawn.evolve(kind, next_unit)
	pawn_evolved.emit(pawn.entity_id, kind, next_unit)
	return true


## 이 플레이어가 이 세트에서 아직 받지 않은 호기 목록 (대부분 1~4, 아케이드는 1~5). 승진한 퀸(5호기)은 세지 않는다.
func free_units(player_id: int, kind: GameEnums.PawnKind) -> Array[int]:
	var taken: Array[int] = []
	for pawn: PlayerPawn in pawns:
		if pawn.owner_id == player_id and pawn.kind == kind:
			taken.append(pawn.unit_no)
	var result: Array[int] = []
	for unit: int in range(1, PawnCatalog.unit_count(kind) + 1):
		if not taken.has(unit):
			result.append(unit)
	return result


## 기본 말 하나를 지정한 세부 기물로 영구 교체해 지급한다 (candidates 중 첫 호기). 이미 받은 호기뿐이면 false.
func give_unit(pawn: PlayerPawn, kind: GameEnums.PawnKind, candidates: Array[int]) -> bool:
	if pawn == null or pawn.kind != GameEnums.PawnKind.BASIC or kind == GameEnums.PawnKind.BASIC:
		return false
	var free: Array[int] = free_units(pawn.owner_id, kind)
	for unit: int in candidates:
		if free.has(unit):
			pawn.evolve(kind, unit)
			pawn_evolved.emit(pawn.entity_id, kind, unit)
			return true
	return false


func pawns_of(player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns:
		if pawn.owner_id == player_id:
			result.append(pawn)
	return result


func get_active_pawns() -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns:
		if not pawn.is_finished:
			result.append(pawn)
	return result


## 해당 타일의 '업은 말(대표 말)'들. 완주한 말·업혀 있는 말은 제외한다.
func leaders_at(tile: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns:
		if pawn.current_tile_idx == tile and not pawn.is_finished and pawn.carrier == null:
			result.append(pawn)
	return result


## dice_value는 이번에 적용할 눈금이다 (0이면 눈금 제한 없이 고른다).
func selectable_pawns(player_id: int, dice_value: int = 0) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns_of(player_id):
		if can_pick(pawn, dice_value):
			result.append(pawn)
	return result


## 지금 눈금으로 이 말을 고를 수 있는가 (후퇴가 없어서 눈금과 상관없이 움직일 수 있는 말이면 누구나 가능).
func can_pick(pawn: PlayerPawn, _dice_value: int) -> bool:
	return pawn.is_selectable()


func pawn_progress_distance(pawn: PlayerPawn) -> int:
	var distance: int = board.distance_to_goal(pawn.current_tile_idx, pawn.has_left_start)
	if not pawn.can_finish(self):
		distance += BoardSpec.tile_count
	return distance


## 꼴찌(결승까지 가장 먼) 대표 말. excluding_owner의 말은 제외한다. 없으면 null.
func last_place_pawn(excluding_owner: int) -> PlayerPawn:
	var last: PlayerPawn = null
	var last_distance: int = -1
	for pawn: PlayerPawn in pawns:
		if pawn.is_finished or pawn.carrier != null or pawn.owner_id == excluding_owner:
			continue
		var distance: int = pawn_progress_distance(pawn)
		if distance > last_distance:
			last_distance = distance
			last = pawn
	return last


# ---------------------------------------------------------------------------
# 기물 상태 변경
# ---------------------------------------------------------------------------

func send_to_start(pawn: PlayerPawn, by_player: int) -> void:
	var members: Array[PlayerPawn] = pawn.stack_members()
	# 특수 승리 기록: 다크호스 판정은 사출 전에 선두를 정한다.
	var enemy_kill: bool = by_player >= 1 and by_player != pawn.owner_id
	var underdog: bool = enemy_kill and finished_count(by_player) == 0 and race_leader(by_player) == pawn.owner_id
	var entry: Dictionary = record_hit(pawn) if enemy_kill else {}
	for member: PlayerPawn in members:
		# 보드 위에 나와 있던 말만 복수심을 얻는다 (이미 출발선에 있던 말은 해당 없음).
		var was_out: bool = member.has_left_start and not member.is_finished
		member.reset_to_start()
		member.revenge_boost = member.revenge_boost or was_out
		if member.sub_type() == GameEnums.PawnSubType.BADUK_WHITE and not member.shield:
			member.shield_broken_hit = true  # 방어막이 깨진 채로 잡혔다: 다음 증강 라운드에 재충전되지 않는다
		if was_out:
			add_stat(pawn.owner_id, &"ejected")
			_note_entry_stat(entry, &"ejected")
			if enemy_kill:
				add_stat(by_player, &"kills")
				_note_entry_stat(entry, &"kills")
			if underdog:
				add_stat(by_player, &"underdog")
				_note_entry_stat(entry, &"underdog")
	if not hurt_players.has(pawn.owner_id):
		hurt_players.append(pawn.owner_id)
	for member: PlayerPawn in members:
		pawn_sent_to_start.emit(member.entity_id, by_player)
	# 강제 연대책임: 묶인 짝도 함께 탈락한다
	for member: PlayerPawn in members:
		var partner: PlayerPawn = _take_bond(member)
		if partner != null and partner.has_left_start and not partner.is_finished:
			bond_resolved.emit(&"eject", member.entity_id, partner.entity_id)
			send_to_start(partner.carrier if partner.carrier != null else partner, by_player)


func finish_stack(leader: PlayerPawn) -> void:
	var members: Array[PlayerPawn] = leader.stack_members()
	for member: PlayerPawn in members:
		member.is_finished = true
		member.carrier = null
		member.current_tile_idx = GameEnums.GOAL_TILE
		pawn_finished.emit(member.entity_id)
	leader.carried.clear()
	# 강제 연대책임: 묶인 짝도 함께 골인한다
	for member: PlayerPawn in members:
		var partner: PlayerPawn = _take_bond(member)
		if partner != null and not partner.is_finished:
			bond_resolved.emit(&"finish", member.entity_id, partner.entity_id)
			finish_stack(partner.carrier if partner.carrier != null else partner)


## 두 말을 일심동체로 묶는다 (강제 연대책임).
func bind_pawns(a: PlayerPawn, b: PlayerPawn) -> void:
	bonds[a.entity_id] = b.entity_id
	bonds[b.entity_id] = a.entity_id
	pawns_bonded.emit(a.entity_id, b.entity_id)


## 이 말의 짝을 돌려주고 묶음을 푼다 (없으면 null).
func _take_bond(pawn: PlayerPawn) -> PlayerPawn:
	if not bonds.has(pawn.entity_id):
		return null
	var partner_id: int = int(bonds[pawn.entity_id])
	bonds.erase(pawn.entity_id)
	bonds.erase(partner_id)
	return get_pawn(partner_id)


## member를 leader에 업힌 상태로 합친다 (member가 업고 있던 말들도 함께).
func stack_pawns(leader: PlayerPawn, member: PlayerPawn) -> void:
	var absorbed: Array[PlayerPawn] = member.stack_members()
	for absorbed_pawn: PlayerPawn in absorbed:
		absorbed_pawn.carried.clear()
		absorbed_pawn.carrier = leader
		absorbed_pawn.current_tile_idx = leader.current_tile_idx
		absorbed_pawn.step_history.assign(leader.step_history)
		absorbed_pawn.has_left_start = leader.has_left_start
		leader.carried.append(absorbed_pawn)
	var ids: Array[int] = []
	for stacked: PlayerPawn in leader.stack_members():
		ids.append(stacked.entity_id)
	pawns_stacked.emit(leader.entity_id, ids)


## 대표 말과 업힌 말들의 위치 정보를 한꺼번에 동기화한다.
func sync_stack_position(leader: PlayerPawn) -> void:
	for member: PlayerPawn in leader.carried:
		member.current_tile_idx = leader.current_tile_idx
		member.step_history.assign(leader.step_history)
		member.has_left_start = leader.has_left_start
		member.retreated_run = leader.retreated_run


## 두 대표 말(업은 말 포함)의 위치를 교환한다.
func swap_stacks(a: PlayerPawn, b: PlayerPawn) -> void:
	var a_tile: int = a.current_tile_idx
	var a_history: Array[int] = a.step_history.duplicate()
	var a_started: bool = a.has_left_start
	a.current_tile_idx = b.current_tile_idx
	a.step_history.assign(b.step_history)
	a.has_left_start = b.has_left_start
	b.current_tile_idx = a_tile
	b.step_history.assign(a_history)
	b.has_left_start = a_started
	sync_stack_position(a)
	sync_stack_position(b)
	pawns_swapped.emit(a.entity_id, b.entity_id)


func teleport_stack(leader: PlayerPawn, tile: int) -> void:
	leader.place_at(tile)
	sync_stack_position(leader)
	pawn_teleported.emit(leader.entity_id, tile)


# ---------------------------------------------------------------------------
# NPC / 설치물 / 카드
# ---------------------------------------------------------------------------

func spawn_npc(tile: int, behavior: GameEnums.NpcBehavior, summoner_id: int, display_id: StringName) -> NeutralNPC:
	var npc := NeutralNPC.new()
	npc.entity_id = _next_npc_id
	_next_npc_id += 1
	npc.owner_id = summoner_id
	npc.place_at(tile)
	npc.behavior = behavior
	npc.display_id = display_id
	npcs.append(npc)
	npc_spawned.emit(npc.entity_id, tile)
	return npc


func place_attachment(tile: int, attachment: TileAttachment) -> void:
	board.get_tile(tile).add_attachment(attachment)
	attachment_placed.emit(tile, attachment.attachment_id, attachment.owner_id)


func give_card(player_id: int, card_id: StringName) -> bool:
	var hand: Array = hands[player_id]
	if hand.size() >= GameEnums.MAX_HAND_SIZE:
		return false
	hand.append(card_id)
	card_drawn.emit(player_id, card_id)
	return true


func draw_card(player_id: int) -> StringName:
	if card_deck.is_empty():
		return &""
	var card_id: StringName = card_deck.pop_back()
	if not give_card(player_id, card_id):
		card_deck.push_front(card_id)
		return &""
	return card_id


func has_card(player_id: int, card_id: StringName) -> bool:
	return (hands[player_id] as Array).has(card_id)


## 손패에서 카드 1장을 소모한다. 스냅샷 롤백으로도 복구되지 않는다.
func consume_card(player_id: int, card_id: StringName) -> bool:
	var hand: Array = hands[player_id]
	var index: int = hand.find(card_id)
	if index == -1:
		return false
	hand.remove_at(index)
	return true


func steal_random_card(player_id: int, source_rng: RandomNumberGenerator) -> StringName:
	var hand: Array = hands.get(player_id, [])
	if hand.is_empty():
		return &""
	var index: int = source_rng.randi_range(0, hand.size() - 1)
	var card_id: StringName = hand[index]
	hand.remove_at(index)
	card_stolen.emit(player_id, card_id)
	return card_id


## 손패에서 무작위 1장을 버린다 (ACT_02 회피). 손패가 비었으면 &"".
func discard_random_card(player_id: int, source_rng: RandomNumberGenerator) -> StringName:
	var hand: Array = hands.get(player_id, [])
	if hand.is_empty():
		return &""
	var index: int = source_rng.randi_range(0, hand.size() - 1)
	var card_id: StringName = hand[index]
	hand.remove_at(index)
	return card_id


func hand_has_category(player_id: int, category: GameEnums.CardCategory) -> bool:
	return first_card_of_category(player_id, category) != &""


## 손패에서 해당 분류의 첫 카드 ID (없으면 &"").
func first_card_of_category(player_id: int, category: GameEnums.CardCategory) -> StringName:
	for card_id: StringName in hands.get(player_id, []):
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card != null and card.category == category:
			return card_id
	return &""


func any_hand_has_cards() -> bool:
	for player_id: int in player_ids:
		if not (hands[player_id] as Array).is_empty():
			return true
	return false


# ---------------------------------------------------------------------------
# 턴 진행 방향
# ---------------------------------------------------------------------------

## 이번 이동에 적용할 전체 이동 방향. 말은 절대 뒤로 가지 않으므로 언제나 +1이다 (우노 리버스는 턴 순서만 뒤집는다).
func movement_direction() -> int:
	return 1


## 현재 진행 방향 기준으로 player_id 다음에 턴을 잡는 플레이어.
func next_player_after(player_id: int) -> int:
	var index: int = player_ids.find(player_id)
	if index == -1:
		return -1
	return player_ids[posmod(index + turn_direction, player_ids.size())]


## 가장 앞선(결승에 가장 가까운) 출발한 내 대표 말. 없으면 null.
func front_pawn_of(player_id: int) -> PlayerPawn:
	var best: PlayerPawn = null
	var best_distance: int = 1 << 30
	for pawn: PlayerPawn in pawns_of(player_id):
		if pawn.is_finished or pawn.carrier != null or not pawn.has_left_start or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		var distance: int = pawn_progress_distance(pawn)
		if distance < best_distance:
			best_distance = distance
			best = pawn
	return best




## 대표 말 하나를 한 칸 뒤로 물린다 (포석 무적에 막힌 침입자). 이동 이력의 마지막 걸음을 취소한다.
func step_back_one(pawn: PlayerPawn) -> int:
	var from_tile: int = pawn.current_tile_idx
	var to_tile: int = board.step_back(pawn)
	sync_stack_position(pawn)
	pawn_pushed_back.emit(pawn.entity_id, from_tile, to_tile)
	return to_tile


# ---------------------------------------------------------------------------
# 서바이벌 순위제
# ---------------------------------------------------------------------------

func is_graduated(player_id: int) -> bool:
	return rankings.has(player_id)


## 다음 순위로 졸업시킨다: 남은 말은 보드에서 철수(완주 처리)하고 업기·구속을 푼다. 확정된 순위(1부터)를 돌려준다.
func graduate(player_id: int, reason: StringName) -> int:
	if rankings.has(player_id):
		return rankings.find(player_id) + 1
	rankings.append(player_id)
	rank_reasons[player_id] = reason
	rank_stats[player_id] = VictoryChecker.progress_of(self, player_id)
	# 레이스에서 빠진다: 내 설치물(호텔·함정)은 보드에서 치우고(내 턴이 다시 오지 않아 남은 턴이 줄지 않는다), 강제 연대책임 묶음도 푼다.
	for tile: TileNode in board.tiles:
		for attachment: TileAttachment in tile.attachments.duplicate():
			if attachment.owner_id == player_id:
				tile.remove_attachment(attachment)
	for pawn: PlayerPawn in pawns_of(player_id):
		_take_bond(pawn)
	for pawn: PlayerPawn in pawns_of(player_id):
		if pawn.carrier != null:
			pawn.carrier.carried.erase(pawn)
			pawn.carrier = null
		pawn.carried.clear()
		pawn.is_finished = true
		pawn.has_left_start = true
		pawn.is_imprisoned = false
		pawn.restrained_turns = 0
		pawn.blocked_this_turn = false
		pawn.revenge_boost = false
		pawn.current_tile_idx = GameEnums.GOAL_TILE
	return rankings.size()


## 아직 레이스 중인 플레이어 (주어진 순서 그대로).
func active_players(order: Array[int]) -> Array[int]:
	var active: Array[int] = []
	for player_id: int in order:
		if not rankings.has(player_id):
			active.append(player_id)
	return active


# ---------------------------------------------------------------------------
# 🏆 특수 승리 기록
# ---------------------------------------------------------------------------

func stat(player_id: int, key: StringName) -> int:
	return int((law_stats.get(player_id, {}) as Dictionary).get(key, 0))


func add_stat(player_id: int, key: StringName, amount: int = 1) -> void:
	if not law_stats.has(player_id):
		law_stats[player_id] = {}
	law_stats[player_id][key] = stat(player_id, key) + amount


## 최고 기록을 갱신한다 (더 클 때만).
func max_stat(player_id: int, key: StringName, value: int) -> void:
	if value > stat(player_id, key):
		add_stat(player_id, key, value - stat(player_id, key))


func reset_stat(player_id: int, key: StringName) -> void:
	if law_stats.has(player_id):
		(law_stats[player_id] as Dictionary).erase(key)


func finished_count(player_id: int) -> int:
	var count: int = 0
	for pawn: PlayerPawn in pawns_of(player_id):
		if pawn.is_finished:
			count += 1
	return count


## 레이스 선두 플레이어 (excluding을 뺀, 아직 졸업하지 않은 사람 중 완주 수가 많고 → 남은 거리 합이 작은 사람). 없으면 -1.
func race_leader(excluding: int) -> int:
	var best: int = -1
	var best_finished: int = -1
	var best_remaining: int = 0
	for player_id: int in player_ids:
		if player_id == excluding or rankings.has(player_id):
			continue
		var finished: int = finished_count(player_id)
		var remaining: int = 0
		for pawn: PlayerPawn in pawns_of(player_id):
			if not pawn.is_finished:
				remaining += pawn_progress_distance(pawn)
		if finished > best_finished or (finished == best_finished and remaining < best_remaining):
			best = player_id
			best_finished = finished
			best_remaining = remaining
	return best


## 이 플레이어가 보드에 깔아 둔 설치물(호텔·함정) 수.
func owned_attachment_count(player_id: int) -> int:
	var count: int = 0
	for tile: TileNode in board.tiles:
		for attachment: TileAttachment in tile.attachments:
			if attachment.owner_id == player_id:
				count += 1
	return count


## 바둑 백돌 방어막이 있으면 깨뜨리고 true (잡기·함정을 막았다).
func break_shield(pawn: PlayerPawn) -> bool:
	if pawn == null or not pawn.shield or pawn.sub_type() != GameEnums.PawnSubType.BADUK_WHITE:
		return false
	pawn.shield = false
	pawn.shield_broken_hit = false
	shield_broken.emit(pawn.entity_id, pawn.current_tile_idx)
	return true


## 증강 라운드: 방어막이 깨진 뒤 잡히지 않은 백돌은 방어막이 다시 차오른다.
func recharge_shields() -> void:
	for pawn: PlayerPawn in pawns:
		if pawn.sub_type() != GameEnums.PawnSubType.BADUK_WHITE or pawn.shield:
			continue
		if not pawn.shield_broken_hit:
			pawn.shield = true
			shield_recharged.emit(pawn.entity_id)
		pawn.shield_broken_hit = false


# ---------------------------------------------------------------------------
# 공격 기록 (방어 카드)
# ---------------------------------------------------------------------------

## 공격 출처를 연다: {"kind": &"capture"/&"card"/&"trap", "attacker": 플레이어, ...}. 같은 출처 안의 피해는 피해자별로 한 기록에 모인다.
func begin_attack(source: Dictionary) -> void:
	_attack_serial += 1
	_attack_stack.append(attack_source)
	attack_source = source.duplicate()
	attack_source["serial"] = _attack_serial


## 출처를 닫고 바깥 출처(카드가 일으킨 이동 속의 잡기 등)로 돌아간다.
func end_attack() -> void:
	attack_source = _attack_stack.pop_back() if not _attack_stack.is_empty() else {}


## 피해 직전에 부른다: 지금 출처 아래에서 pawn(과 업힌 말)의 상태를 피해자 기록에 담는다. 출처가 없거나 자기 공격이면 빈 값.
func record_hit(pawn: PlayerPawn) -> Dictionary:
	if attack_source.is_empty() or pawn == null or int(attack_source.get("attacker", -1)) == pawn.owner_id:
		return {}
	var entry: Dictionary = _entry_for(pawn.owner_id)
	var saved: Dictionary = entry["pawns"]
	for member: PlayerPawn in pawn.stack_members():
		if not saved.has(member.entity_id):
			saved[member.entity_id] = pawn_state(member)
	return entry


## 지금 출처 아래에서 피해자 플레이어의 말 이외의 피해(휴식·밴·기록 초기화)를 기록에 남긴다. 되돌릴 때 previous 값으로 복원한다.
func record_effect(victim: int, key: String, previous: Variant) -> void:
	if attack_source.is_empty() or int(attack_source.get("attacker", -1)) == victim:
		return
	var effects: Dictionary = _entry_for(victim)["effects"]
	if not effects.has(key):
		effects[key] = previous


func _entry_for(victim: int) -> Dictionary:
	for entry: Dictionary in attack_log:
		if int(entry["serial"]) == int(attack_source["serial"]) and int(entry["victim"]) == victim:
			return entry
	var entry: Dictionary = attack_source.duplicate()
	entry["id"] = _attack_next_id
	_attack_next_id += 1
	entry["victim"] = victim
	entry["pawns"] = {}
	entry["stats"] = {}
	entry["effects"] = {}
	entry["offered"] = false
	entry["countered"] = false
	attack_log.append(entry)
	return entry


func _note_entry_stat(entry: Dictionary, key: StringName) -> void:
	if entry.is_empty():
		return
	var stats: Dictionary = entry["stats"]
	stats[key] = int(stats.get(key, 0)) + 1


## 아무 피해도 남지 않은 기록(발동하지 않은 함정 등)을 지운다.
func discard_empty_attacks() -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in attack_log:
		if not (entry["pawns"] as Dictionary).is_empty() or not (entry["effects"] as Dictionary).is_empty() or bool(entry.get("keep", false)):
			kept.append(entry)
	attack_log = kept


func get_attack(attack_id: int) -> Dictionary:
	for entry: Dictionary in attack_log:
		if int(entry["id"]) == attack_id:
			return entry
	return {}


## 말 하나의 위치·상태 (공격 직전 저장용).
func pawn_state(pawn: PlayerPawn) -> Dictionary:
	var carried_ids: Array[int] = []
	for carried_pawn: PlayerPawn in pawn.carried:
		carried_ids.append(carried_pawn.entity_id)
	return {"tile": pawn.current_tile_idx, "history": pawn.step_history.duplicate(), "started": pawn.has_left_start,
		"finished": pawn.is_finished, "revenge": pawn.revenge_boost, "restrained": pawn.restrained_turns,
		"imprisoned": pawn.is_imprisoned, "shield": pawn.shield, "carrier": pawn.carrier.entity_id if pawn.carrier != null else -1, "carried": carried_ids}


## 방어으로 피해를 되돌린다: 저장한 말 상태·휴식·밴·기록을 복원하고, 공격으로 오른 특수 승리 기록을 되돌린다.
func undo_attack(entry: Dictionary) -> void:
	var saved: Dictionary = entry["pawns"]
	for pawn_id: Variant in saved.keys():
		var pawn: PlayerPawn = get_pawn(int(pawn_id))
		var data: Dictionary = saved[pawn_id]
		if pawn.carrier != null:
			pawn.carrier.carried.erase(pawn)
		pawn.carrier = null
		pawn.carried.clear()
		var from_tile: int = pawn.current_tile_idx
		pawn.current_tile_idx = int(data["tile"])
		pawn.step_history.assign(data["history"])
		pawn.has_left_start = bool(data["started"])
		pawn.is_finished = bool(data["finished"])
		pawn.revenge_boost = bool(data["revenge"])
		pawn.restrained_turns = int(data["restrained"])
		pawn.is_imprisoned = bool(data["imprisoned"])
		pawn.shield = bool(data["shield"])
		if from_tile != pawn.current_tile_idx:
			pawn_teleported.emit(pawn.entity_id, pawn.current_tile_idx)
	for pawn_id: Variant in saved.keys():
		var data: Dictionary = saved[pawn_id]
		var pawn: PlayerPawn = get_pawn(int(pawn_id))
		var carrier: PlayerPawn = get_pawn(int(data["carrier"]))
		if carrier != null and not carrier.carried.has(pawn):
			pawn.carrier = carrier
			carrier.carried.append(pawn)
	var victim: int = int(entry["victim"])
	var attacker: int = int(entry.get("attacker", -1))
	var stats: Dictionary = entry["stats"]
	add_stat(victim, &"ejected", -int(stats.get(&"ejected", 0)))
	if attacker >= 1:
		add_stat(attacker, &"kills", -int(stats.get(&"kills", 0)))
		add_stat(attacker, &"underdog", -int(stats.get(&"underdog", 0)))
	var effects: Dictionary = entry["effects"]
	if effects.has("rest"):
		rest_next_turn[victim] = bool(effects["rest"])
	if effects.has("ban"):
		banned_turns[victim] = int(effects["ban"])
	for key: String in effects.keys():
		if key.begins_with("stat:"):
			law_stats[victim] = law_stats.get(victim, {})
			(law_stats[victim] as Dictionary)[StringName(key.trim_prefix("stat:"))] = int(effects[key])
	stats.clear()
	entry["countered"] = true


func is_banned(player_id: int) -> bool:
	return int(banned_turns.get(player_id, 0)) > 0

