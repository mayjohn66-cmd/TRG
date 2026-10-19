# File: res://core_engine/board/trap_domino.gd
# Class: class_name TrapDomino
# Role: TRP_05 스프링 인간 대포(옛 도미노 연쇄 붕괴) - 어떤 말이든 밟거나 멈추면 그 말이 앞으로 +5칸 강제 사출되고, 착지 지점에 서 있는 말은 들이받혀 출발선으로 날아가는 은신 가속 함정 (1회용). 내부 ID는 호환을 위해 TrapDomino로 둔다
class_name TrapDomino
extends TileAttachment

const LAUNCH_STEPS: int = 5


func _init(owner: int = -1) -> void:
	attachment_id = "TRP_05"
	owner_id = owner


## 설치한 사람의 말도 대포는 피하지 못한다 (어떤 말이든). 발동하면 설치물은 소모된다.
## 날아간 자리의 잡기·설치물·발판 판정은 이 함정이 이동을 중단시킨 뒤 이어지는 도착 처리가 한다.
func on_step_trigger(victim: BoardEntity, ctx: RuleContext) -> bool:
	var pawn: PlayerPawn = victim as PlayerPawn
	if pawn == null or ctx.state == null:
		return false
	var state: GameState = ctx.state
	ctx.metadata["cutscene_id"] = &"trap_domino"
	var passed: Array[int] = MoveExecutor.fling(state, pawn, LAUNCH_STEPS)
	var chain: Array[int] = []
	ctx.metadata["domino_chain"] = chain
	state.domino_collapsed.emit(pawn.entity_id, passed, chain)
	duration_turns = 0
	return true
