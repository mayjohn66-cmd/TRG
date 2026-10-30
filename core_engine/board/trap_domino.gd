# File: res://core_engine/board/trap_domino.gd
# Class: class_name TrapDomino
# Role: TRP_05 도미노 연쇄 - 어떤 말이든 밟거나 멈추면 그 자리에 멈추고, 반경 2칸 안에 깔린 다른 함정이 도미노처럼 전부 발동한다 (1회용).
#       연쇄로 터진 함정은 그 칸에 서 있는 말에게 효과를 주고(설치자 본인 말은 각 함정 규칙대로 면제) 모두 소모된다. 서 있는 말이 없어도 터져서 사라진다
class_name TrapDomino
extends TileAttachment

const CHAIN_RADIUS: int = 2


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_05"
	owner_id = owner


## 연쇄 반경 (cards_table.csv TRP_05 param_1).
static func chain_radius() -> int:
	return maxi(CardRegistry.param(&"TRP_05", CHAIN_RADIUS), 0)


## 설치한 사람의 말도 도미노는 피하지 못한다 (어떤 말이든). 발동하면 설치물은 소모된다.
func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null:
		return false
	var state: GameState = ctx.state
	ctx.metadata["cutscene_id"] = &"trap_domino"
	duration_turns = 0
	var center: int = state.board.tile_of_attachment(self)
	# 연출 순서: [도미노 연쇄!] 알림이 먼저, 그다음 연쇄로 터지는 함정들 (알림은 터질 칸 목록을 미리 담는다)
	state.domino_collapsed.emit(pawn.entity_id, [] as Array[int], chain_tiles(state, center, self))
	var chain: Array[int] = chain_reaction(state, center, self)
	ctx.metadata["domino_chain"] = chain
	return true


## 연쇄로 터질 함정이 있는 칸들 (가까운 칸부터, 같은 칸의 함정 수만큼 반복).
static func chain_tiles(state: GameState, center: int, skip: TileAttachment) -> Array[int]:
	var tiles: Array[int] = []
	if not state.board.is_valid_tile(center):
		return tiles
	for tile_index: int in state.board.tiles_within(center, chain_radius()):
		for attachment: TileAttachment in state.board.get_tile(tile_index).attachments:
			if attachment != skip and attachment.attachment_id.begins_with("TRP"):
				tiles.append(tile_index)
	return tiles


## center 반경 안의 함정(skip 제외)을 가까운 칸부터 모두 터뜨린다. 반환: 함정이 터진 칸 목록.
static func chain_reaction(state: GameState, center: int, skip: TileAttachment) -> Array[int]:
	var chain: Array[int] = []
	if not state.board.is_valid_tile(center):
		return chain
	var queue: Array[Array] = []
	for tile_index: int in state.board.tiles_within(center, chain_radius()):
		for attachment: TileAttachment in state.board.get_tile(tile_index).attachments:
			if attachment != skip and attachment.attachment_id.begins_with("TRP"):
				queue.append([tile_index, attachment])
	for entry: Array in queue:
		var tile: TileNode = state.board.get_tile(int(entry[0]))
		var attachment: TileAttachment = entry[1]
		if not tile.attachments.has(attachment):
			continue  # 이어진 다른 도미노가 이미 터뜨렸다
		chain.append(int(entry[0]))
		_fire(state, attachment, int(entry[0]))  # 지뢰처럼 제 위치를 찾는 함정이 있어 보드에 둔 채로 터뜨린 뒤 치운다
		if tile.attachments.has(attachment):
			tile.remove_attachment(attachment)
	return chain


## 함정 하나를 그 칸에 선 말들에게 발동시킨다. 말이 없으면 빈 발동(지뢰 같은 범위 함정은 그래도 터진다).
static func _fire(state: GameState, attachment: TileAttachment, tile_index: int) -> void:
	var standing: Array[PlayerPawn] = []
	for leader: PlayerPawn in state.leaders_at(tile_index):
		if leader.has_left_start and not leader.is_finished:
			standing.append(leader)
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.dice_value = 6  # 눈금 조건이 있는 함정(나락)도 연쇄에는 무조건 걸린다
	ctx.metadata["is_landing"] = true
	if standing.is_empty():
		attachment.on_step_trigger(null, ctx)
		return
	for leader: PlayerPawn in standing:
		ctx.pawn = leader
		ctx.metadata.erase("cutscene_id")
		if attachment.on_step_trigger(leader, ctx):
			state.attachment_triggered.emit(tile_index, attachment.attachment_id, leader.entity_id, ctx.metadata.get("cutscene_id", &""))
