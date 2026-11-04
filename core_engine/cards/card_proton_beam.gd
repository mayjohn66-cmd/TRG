# File: res://core_engine/cards/card_proton_beam.gd
# Class: class_name CardProtonBeam
# Role: SUM_03 롤링 양성자빔 (v1.1) - 상단 코너(맨 위 꼭짓점·반환점)에 빛 기둥으로 내려앉는다. 라운드가 끝날 때마다 무작위 방향으로 3~5칸 스르륵 미끄러지며
#       지나는 칸의 말(누구 것이든)을 출발선으로 보내고 함정·설치물을 전부 태운다. 잡아도 사라지지 않고 3라운드가 지나면 스스로 소멸 (NeutralNPC._run_beam -> NpcSweep.burn)
class_name CardProtonBeam
extends BaseCard


func _init() -> void:
	card_id = NpcSweep.BEAM_ID
	display_name = "롤링 양성자빔"
	category = GameEnums.CardCategory.SUMMON
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


## 중립 기물은 보드에 하나만: 이미 판 위에 있으면 낼 수 없다.
func could_play(state: GameState, _player_id: int) -> bool:
	return SweepCommand.can_summon(state)


## params: {"tile": 상단 코너(반환점)}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return SweepCommand.can_summon(state) and SweepCommand.spawn_tiles().has(int(params.get("tile", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return SweepCommand.new(player_id, int(params["tile"]), card_id)

