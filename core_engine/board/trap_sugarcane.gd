# File: res://core_engine/board/trap_sugarcane.gd
# Class: class_name TrapSugarcane
# Role: TRP_09 목둔 : 사탕수수밭 - 사탕수수를 심어 두면 그 칸을 밟는 모든 말(내 말도)이 그 자리에서 강제로 멈춘다. 한 번 발동해도 사라지지 않고, 설치자의 턴이 3번 지나면 시든다
class_name TrapSugarcane
extends TileAttachment

const LIFETIME_TURNS: int = 3


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_09"
	owner_id = owner
	duration_turns = LIFETIME_TURNS


func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null:
		return false
	ctx.metadata["cutscene_id"] = &"trap_sugarcane"
	return true  # 이동이 이 칸에서 멈춘다 (함정은 그대로 남는다)
