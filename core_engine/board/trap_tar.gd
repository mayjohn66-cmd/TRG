# File: res://core_engine/board/trap_tar.gd
# Class: class_name TrapTar
# Role: TRP_C04 타르 (코너 전용) - 상대 말이 코너를 밟으면 그 자리에 들러붙고, 코너 앞뒤 2칸 안의 상대 말도 모두 코너로 끌려온다. 설치자의 턴 3번(3라운드) 동안 유지, 한 번 발동하면 사라진다
class_name TrapTar
extends TileAttachment

const PULL_RADIUS: int = 2
const LIFETIME_TURNS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_C04"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = LIFETIME_TURNS


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null or pawn.owner_id == owner_id:
		return false
	var state: GameState = ctx.state
	var corner: int = state.board.tile_of_attachment(self)
	for tile_index: int in state.board.tiles_within(corner, CardRegistry.param(&"TRP_C04", PULL_RADIUS)):
		if tile_index == corner or tile_index == GameEnums.GOAL_TILE:
			continue
		for leader: PlayerPawn in state.leaders_at(tile_index):
			if leader.owner_id != owner_id and leader.has_left_start:
				state.record_hit(leader)
				state.teleport_stack(leader, corner)
	ctx.metadata["cutscene_id"] = &"trap_tar"
	duration_turns = 0
	return true
