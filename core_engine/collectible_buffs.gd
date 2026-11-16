# File: res://core_engine/collectible_buffs.gd
# Class: class_name CollectibleBuffs
# Role: 수집품 기물 세트(코롯토·치비구루미)의 공통 패시브 [완주하면 버프]. 그 말이 완주한 사람은 영구 버프를 얻는다.
#       버프는 저장하지 않고 "완주한 수집품 말이 있는가"로 그때그때 계산한다 (스냅샷·되감기에 따로 담을 것이 없다).
#       - 코롯토: 주사위 결과 +1 (영구, 말 하나당 +1)
#       - 치비구루미: 턴 종료 눈금이 나오면 일정 확률로 한 번 다시 굴린다 (판정 도구가 다시 굴려도 안전한 것만, PacingDirector.REROLL_TOOLS)
class_name CollectibleBuffs
extends RefCounted

## 치비구루미가 턴 종료 눈금을 한 번 다시 굴려 주는 확률.
const CHIBI_SAVE_CHANCE: float = 0.5
const COROTTO_ROLL_BONUS: int = 1


static func _finished_count(state: GameState, player_id: int, sub: GameEnums.PawnSubType) -> int:
	var count: int = 0
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished and pawn.kind == GameEnums.PawnKind.COLLECTIBLE and pawn.sub_type() == sub:
			count += 1
	return count


## 코롯토 완주 버프: 모든 굴림 결과에 더해지는 칸수.
static func roll_bonus(state: GameState, player_id: int) -> int:
	return _finished_count(state, player_id, GameEnums.PawnSubType.COLLECT_COROTTO) * COROTTO_ROLL_BONUS


## 치비구루미를 완주시켰는가.
static func chibi_active(state: GameState, player_id: int) -> bool:
	return _finished_count(state, player_id, GameEnums.PawnSubType.COLLECT_CHIBI) > 0


## 턴 종료 눈금이 나왔을 때 치비구루미가 한 번 구해 준다: 확률 성공 시 같은 도구를 다시 굴려 그 결과를 쓴다.
## 다시 굴려도 안전하지 않은 도구(러시안 룰렛·주식 차트 같은 상태가 있는 도구)나 턴 종료가 아닌 결과에는 아무것도 하지 않는다.
## saved가 채워지면(호출한 쪽이 넘긴 빈 사전) 구했다는 사실과 첫 결과 이름을 담아 화면이 알릴 수 있게 한다.
static func save_from_turn_end(state: GameState, player_id: int, tool: BaseJudgmentTool, result: RollResult, saved: Dictionary = {}) -> RollResult:
	if result == null or not result.ends_turn or result.can_continue:
		return result
	if not chibi_active(state, player_id) or not PacingDirector.REROLL_TOOLS.has(tool.tool_id):
		return result
	if state.rng.randf() >= CHIBI_SAVE_CHANCE:
		return result
	var second: RollResult = tool.roll(state.rng)
	saved["saved"] = true
	saved["tool_id"] = tool.tool_id
	return second
