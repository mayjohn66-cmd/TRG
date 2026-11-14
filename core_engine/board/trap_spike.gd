# File: res://core_engine/board/trap_spike.gd
# Class: class_name TrapSpike
# Role: TRP_07 스파이크 - 지나가던 상대 말을 그 칸에 강제로 멈춰 세운다 (1회)
class_name TrapSpike
extends TileAttachment


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_07"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id or bool(ctx.metadata.get("is_landing", false)):
		return false  # 도착 칸이면 멈출 필요가 없다
	ctx.metadata["cutscene_id"] = &"trap_spike"
	duration_turns = 0
	return true
