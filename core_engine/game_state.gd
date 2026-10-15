# File: res://core_engine/game_state.gd
# Class: class_name GameState
# Role: 한 판의 모든 권위 상태(보드·기물·NPC·법전·손패·판정 도구)와 상태 변경 헬퍼. 모든 변화는 시그널로만 외부에 알린다.
class_name GameState
extends RefCounted

# --- 뷰/네트워크 계층이 구독하는 시그널 (코어는 UI를 직접 참조하지 않는다) ---
signal pawn_stepped(pawn_id: int, from_tile: int, to_tile: int)
signal pawn_warped(pawn_id: int, from_tile: int, to_tile: int)
signal pawn_sent_to_start(pawn_id: int, by_player: int)
signal pawn_finished(pawn_id: int)
signal pawn_evolved(pawn_id: int, kind: int, unit_no: int)
signal pawns_stacked(leader_id: int, member_ids: Array[int])
signal pawns_swapped(pawn_a_id: int, pawn_b_id: int)
signal pawn_teleported(pawn_id: int, to_tile: int)
signal npc_spawned(npc_id: int, tile: int)
signal npc_stepped(npc_id: int, from_tile: int, to_tile: int)
signal attachment_placed(tile: int, attachment_id: String, owner_id: int)
signal attachment_triggered(tile: int, attachment_id: String, pawn_id: int, cutscene_id: StringName)
signal card_drawn(player_id: int, card_id: StringName)
signal card_stolen(player_id: int, card_id: StringName)
## ACT_01이 턴 순서 반전을 요청했다. 턴 순서는 TurnManager가 소유하므로 TurnManager가 구독해 처리한다.
signal turn_order_reverse_requested()
## ACT_02 뱅! 결과. dodged가 true면 상대가 카드를 버려 회피했다(빗나감).
signal bang_resolved(shooter: int, target_pawn_id: int, dodged: bool, discarded_card: StringName)
## 기물 능력 알림: 캐슬링(위치 교환) / 알까기로 튕겨 나감 / 포석 무적에 막혀 밀려남.
signal pawns_castled(pawn_a_id: int, pawn_b_id: int)
signal pawn_knocked(pawn_id: int, from_tile: int, to_tile: int)
signal pawn_pushed_back(pawn_id: int, from_tile: int, to_tile: int)
signal snapshot_restored()
signal victory_declared(player_id: int, reason: StringName)

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

var current_player: int = -1
var round_number: int = 1
## 남은 '전체 역주행' 라운드 수 (ACT_01).
var reverse_move_rounds_left: int = 0
var winner: int = -1

## 이번 턴 시작 시점 스냅샷 (ACT_05 롤백 대상).
var turn_snapshot: TurnSnapshot = null
## 이번 턴에 말이 잡히거나 함정을 밟은 플레이어들 (ACT_05 발동 조건).
var hurt_players: Array[int] = []
## 턴 진행 방향 미러 (TurnManager가 소유·갱신한다): 1 정방향 / -1 역방향. next_player_after가 사용한다.
var turn_direction: int = 1
## ACT_03 우노 +4: 플레이어 ID -> 다음 자기 턴 시작에 받을 후퇴 페널티(음수 칸 수). 0이면 없음.
var pending_penalty: Dictionary = {}
## ACT_05가 실행되었음을 TurnManager에 알리는 플래그.
var rollback_requested: bool = false


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


func selectable_pawns(player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns_of(player_id):
		if pawn.is_selectable():
			result.append(pawn)
	return result


func pawn_progress_distance(pawn: PlayerPawn) -> int:
	return board.distance_to_goal(pawn.current_tile_idx, pawn.has_left_start)


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
	for member: PlayerPawn in members:
		member.reset_to_start()
	if not hurt_players.has(pawn.owner_id):
		hurt_players.append(pawn.owner_id)
	for member: PlayerPawn in members:
		pawn_sent_to_start.emit(member.entity_id, by_player)


func finish_stack(leader: PlayerPawn) -> void:
	for member: PlayerPawn in leader.stack_members():
		member.is_finished = true
		member.carrier = null
		member.current_tile_idx = GameEnums.GOAL_TILE
		pawn_finished.emit(member.entity_id)
	leader.carried.clear()


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
		member.retreated_from_start = leader.retreated_from_start


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

## 이번 이동에 적용할 전체 이동 방향 (+1 정방향 / -1 우노 리버스 역주행).
func movement_direction() -> int:
	return -1 if reverse_move_rounds_left > 0 else 1


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


func penalty_of(player_id: int) -> int:
	return int(pending_penalty.get(player_id, 0))


## 대표 말 하나를 한 칸 뒤로 물린다 (포석 무적에 막힌 침입자). 이동 이력의 마지막 걸음을 취소한다.
func step_back_one(pawn: PlayerPawn) -> int:
	var from_tile: int = pawn.current_tile_idx
	var to_tile: int = board.step_back(pawn)
	sync_stack_position(pawn)
	pawn_pushed_back.emit(pawn.entity_id, from_tile, to_tile)
	return to_tile
