# File: res://core_engine/commands/reset_stat_command.gd
# Class: class_name ResetStatCommand
# Role: ACT_06 이의 있음! - 한 플레이어의 특수 승리 기록 하나(처치·한방·사출·연속 굴림·다크호스)를 0으로 되돌린다. 우노 리버스·빗나감으로 되돌릴 수 있게 이전 값을 공격 기록에 남긴다
class_name ResetStatCommand
extends GameCommand

var target_player: int = -1
var law_id: String = ""


func _init(acting_player: int = -1, target: int = -1, law: String = "") -> void:
	super()
	sender_id = acting_player
	target_player = target
	law_id = law
	command_name = "ResetStat"


## 이 플레이어의 이 교칙 기록을 지울 수 있는가 (법전에 있고, 되돌릴 수 있는 기록이고, 0보다 크다).
static func resettable(game: GameState, target: int, law: String) -> bool:
	if not game.rulebook.has_law(law) or game.is_graduated(target):
		return false
	var victory: VictoryLaw = LawRegistry.create(law) as VictoryLaw
	return victory != null and victory.resettable() and game.stat(target, victory.stat_key) > 0


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and resettable(state, target_player, law_id)


func _run() -> void:
	var key: StringName = (LawRegistry.create(law_id) as VictoryLaw).stat_key
	state.record_effect(target_player, "stat:" + String(key), state.stat(target_player, key))
	state.reset_stat(target_player, key)
