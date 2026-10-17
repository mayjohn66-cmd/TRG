# File: res://core_engine/board/hotel.gd
# Class: class_name Hotel
# Role: 모노폴리 카의 통행료 호텔 - 기물 이동이 끝난 타일에 내 턴 5번간 유지되며, 상대가 밟아 이동을 멈추면 소모된다
class_name Hotel
extends TileAttachment

const LIFETIME_TURNS: int = 5


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
	# 통행료를 거두면 호텔은 소모된다 (실행기가 만료된 설치물을 타일에서 제거).
	duration_turns = 0
	return true
