# File: res://core_engine/board/hotel.gd
# Class: class_name Hotel
# Role: 모노폴리 카의 통행료 호텔 - 기물 이동이 끝난 타일에 2턴간 유지되며, 상대가 밟으면 이동을 멈추게 한다. 내 호텔이 동시에 6개 이상이면 부동산 독점 승리
class_name Hotel
extends TileAttachment

const LIFETIME_TURNS: int = 2


func _init(owner: int = -1) -> void:
	attachment_id = "HOTEL"
	owner_id = owner
	is_hidden_trap = false
	duration_turns = LIFETIME_TURNS


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id:
		return false
	ctx.metadata["cutscene_id"] = &"hotel_toll"
	return true
