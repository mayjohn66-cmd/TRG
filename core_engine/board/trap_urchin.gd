# File: res://core_engine/board/trap_urchin.gd
# Class: class_name TrapUrchin
# Role: TRP_10 뾰족한 성게 - 눈금 4 이상으로 지나가는 상대 말을 그 칸에 강제로 멈춰 세운다 (1회). 스파이크(TRP_07)에 나락(TRP_02)의 눈금 조건을 더한 함정
class_name TrapUrchin
extends TileAttachment

const MIN_DICE: int = 4


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_10"
	owner_id = owner


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or pawn.owner_id == owner_id or bool(ctx.metadata.get("is_landing", false)):
		return false  # 도착 칸이면 멈출 필요가 없다
	if absi(ctx.dice_value) < CardRegistry.param(&"TRP_10", MIN_DICE):  # cards_table.csv TRP_10 param_1
		return false  # 느리게 지나가면 성게 가시에 걸리지 않는다
	ctx.metadata["cutscene_id"] = &"trap_spike"
	duration_turns = 0
	return true
