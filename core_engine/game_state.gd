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
signal pawns_stacked(leader_id: int, member_ids: Array[int])
signal pawns_swapped(pawn_a_id: int, pawn_b_id: int)
signal pawn_teleported(pawn_id: int, to_tile: int)
signal npc_spawned(npc_id: int, tile: int)
signal npc_stepped(npc_id: int, from_tile: int, to_tile: int)
signal attachment_placed(tile: int, attachment_id: StringName, owner_id: int)
signal attachment_triggered(tile: int, attachment_id: StringName, pawn_id: int, cutscene_id: StringName)
signal card_drawn(player_id: int, card_id: StringName)
signal card_stolen(player_id: int, card_id: StringName)
signal turn_order_reversed(new_direction: int)
signal snapshot_restored()
signal victory_declared(player_id: int, reason: StringName)

var board: BoardGraph = BoardGraph.new()
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
var turn_direction: int = 1
var round_number: int = 1
## 남은 '전체 역주행' 라운드 수 (ACT_01).
var reverse_move_rounds_left: int = 0
var winner: int = -1

## 이번 턴 시작 시점 스냅샷 (ACT_05 롤백 대상).
var turn_snapshot: TurnSnapshot = null
## 이번 턴에 말이 잡히거나 함정을 밟은 플레이어들 (ACT_05 발동 조건).
var hurt_players: Array[int] = []
## ACT_05가 실행되었음을 TurnManager에 알리는 플래그.
var rollback_requested: bool = false


# ---------------------------------------------------------------------------
# 초기화
# ---------------------------------------------------------------------------

## kinds_by_player: 플레이어 ID -> Array[PawnKind] (4개). 생략하면 모두 윷말.
func setup(ids: Array[int], seed_value: int = 0, kinds_by_player: Dictionary = {}) -> void:
	player_ids = ids.duplicate()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	pawns.clear()
	npcs.clear()
	hands.clear()
	tools.clear()
	for player_id: int in player_ids:
		hands[player_id] = [] as Array[StringName]
		tools[player_id] = ToolRegistry.create(&"D6")
		var kinds: Array = kinds_by_player.get(player_id, [])
		for slot: int in range(1, GameEnums.PAWNS_PER_PLAYER + 1):
			var pawn := PlayerPawn.new()
			pawn.id = player_id * 10 + slot
			pawn.owner_id = player_id
			pawn.slot = slot
			pawn.kind = kinds[slot - 1] if kinds.size() >= slot else GameEnums.PawnKind.YUT
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
		if pawn.id == pawn_id:
			return pawn
	return null


func get_npc(npc_id: int) -> NeutralNPC:
	for npc: NeutralNPC in npcs:
		if npc.id == npc_id:
			return npc
	return null


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
		if pawn.tile_index == tile and not pawn.is_finished and pawn.carrier == null:
			result.append(pawn)
	return result


func selectable_pawns(player_id: int) -> Array[PlayerPawn]:
	var result: Array[PlayerPawn] = []
	for pawn: PlayerPawn in pawns_of(player_id):
		if pawn.is_selectable():
			result.append(pawn)
	return result


func pawn_progress_distance(pawn: PlayerPawn) -> int:
	return board.distance_to_goal(pawn.tile_index, pawn.has_left_start)


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


func next_player_after(player_id: int) -> int:
	var index: int = player_ids.find(player_id)
	var next_index: int = posmod(index + turn_direction, player_ids.size())
	return player_ids[next_index]


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
		pawn_sent_to_start.emit(member.id, by_player)


func finish_stack(leader: PlayerPawn) -> void:
	for member: PlayerPawn in leader.stack_members():
		member.is_finished = true
		member.carrier = null
		member.tile_index = GameEnums.GOAL_TILE
		pawn_finished.emit(member.id)
	leader.carried.clear()


## member를 leader에 업힌 상태로 합친다 (member가 업고 있던 말들도 함께).
func stack_pawns(leader: PlayerPawn, member: PlayerPawn) -> void:
	var absorbed: Array[PlayerPawn] = member.stack_members()
	for absorbed_pawn: PlayerPawn in absorbed:
		absorbed_pawn.carried.clear()
		absorbed_pawn.carrier = leader
		absorbed_pawn.tile_index = leader.tile_index
		absorbed_pawn.step_history.assign(leader.step_history)
		absorbed_pawn.has_left_start = leader.has_left_start
		leader.carried.append(absorbed_pawn)
	var ids: Array[int] = []
	for stacked: PlayerPawn in leader.stack_members():
		ids.append(stacked.id)
	pawns_stacked.emit(leader.id, ids)


## 대표 말과 업힌 말들의 위치 정보를 한꺼번에 동기화한다.
func sync_stack_position(leader: PlayerPawn) -> void:
	for member: PlayerPawn in leader.carried:
		member.tile_index = leader.tile_index
		member.step_history.assign(leader.step_history)
		member.has_left_start = leader.has_left_start
		member.retreated_from_start = leader.retreated_from_start


## 두 대표 말(업은 말 포함)의 위치를 교환한다.
func swap_stacks(a: PlayerPawn, b: PlayerPawn) -> void:
	var a_tile: int = a.tile_index
	var a_history: Array[int] = a.step_history.duplicate()
	var a_started: bool = a.has_left_start
	a.tile_index = b.tile_index
	a.step_history.assign(b.step_history)
	a.has_left_start = b.has_left_start
	b.tile_index = a_tile
	b.step_history.assign(a_history)
	b.has_left_start = a_started
	sync_stack_position(a)
	sync_stack_position(b)
	pawns_swapped.emit(a.id, b.id)


func teleport_stack(leader: PlayerPawn, tile: int) -> void:
	leader.tile_index = tile
	leader.step_history.clear()
	sync_stack_position(leader)
	pawn_teleported.emit(leader.id, tile)


# ---------------------------------------------------------------------------
# NPC / 설치물 / 카드
# ---------------------------------------------------------------------------

func spawn_npc(tile: int, behavior: GameEnums.NpcBehavior, summoner_id: int, display_id: StringName) -> NeutralNPC:
	var npc := NeutralNPC.new()
	npc.id = _next_npc_id
	_next_npc_id += 1
	npc.owner_id = summoner_id
	npc.tile_index = tile
	npc.behavior = behavior
	npc.display_id = display_id
	npcs.append(npc)
	npc_spawned.emit(npc.id, tile)
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


func any_hand_has_cards() -> bool:
	for player_id: int in player_ids:
		if not (hands[player_id] as Array).is_empty():
			return true
	return false


# ---------------------------------------------------------------------------
# 턴 진행 방향
# ---------------------------------------------------------------------------

func reverse_turn_order() -> void:
	turn_direction *= -1
	turn_order_reversed.emit(turn_direction)


## 이번 이동에 적용할 전체 이동 방향 (+1 정방향 / -1 우노 리버스 역주행).
func movement_direction() -> int:
	return -1 if reverse_move_rounds_left > 0 else 1
