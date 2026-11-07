# File: res://core_engine/commands/move_command.gd
# Class: class_name MoveCommand
# Role: 기물 이동 한 번을 캡슐화한 커맨드. 동기 실행(execute)도 가능하고, TurnManager의 비동기 이동 루프가 대신 수행할 때는 이력 등록용으로 쓴다
class_name MoveCommand
extends GameCommand

var pawn_id: int = -1
var move_ctx: RuleContext = null
var report: MoveReport = null


func _init(acting_player: int = -1, target_pawn_id: int = -1, ctx: RuleContext = null) -> void:
	super()
	sender_id = acting_player
	pawn_id = target_pawn_id
	move_ctx = ctx
	command_name = "Move"


func can_execute(_ctx: RuleContext) -> bool:
	if state == null or move_ctx == null:
		return false
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return pawn != null and pawn.is_selectable()


func _run() -> void:
	report = MoveExecutor.execute(state, state.get_pawn(pawn_id), move_ctx)
