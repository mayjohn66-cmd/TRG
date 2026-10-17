# File: res://core_engine/board/trap_mine.gd
# Class: class_name TrapMine
# Role: TRP_03 지뢰 - 은신 지뢰. 누구든 밟으면 반경 2칸 안의 모든 기물을 피아 구분 없이 출발선으로 날린다
class_name TrapMine
extends TileAttachment

const BLAST_RADIUS: int = 2


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_03"
	owner_id = owner


func on_step_trigger(_victim: BoardEntity, ctx: RuleContext) -> bool:
	if ctx.state == null:
		return false
	var center: int = ctx.state.board.tile_of_attachment(self)
	if center == -1:
		return false
	for tile_index: int in ctx.state.board.tiles_within(center, BLAST_RADIUS):
		if tile_index == GameEnums.GOAL_TILE:
			continue
		for leader: PlayerPawn in ctx.state.leaders_at(tile_index):
			ctx.state.send_to_start(leader, owner_id)
	ctx.metadata["cutscene_id"] = &"mine_blast"
	duration_turns = 0
	return true
