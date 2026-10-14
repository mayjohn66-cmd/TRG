# File: res://core_engine/cards/base_card.gd
# Class: class_name BaseCard
# Role: 생떼 카드 추상 리소스. 사용 가능 페이즈·사용 조건 검증과 실행 커맨드 생성을 정의한다.
class_name BaseCard
extends Resource

@export var card_id: StringName = &""
@export var display_name: String = ""
@export var category: GameEnums.CardCategory = GameEnums.CardCategory.INSTANT
## 사용 가능한 GameEnums.Phase 값들.
var playable_phases: Array[int] = []


func is_playable_in(phase: int) -> bool:
	return playable_phases.has(phase)


## 카드별 사용 조건(대상 유효성 등). 기본은 항상 사용 가능.
func can_play(_state: GameState, _player_id: int, _params: Dictionary) -> bool:
	return true


## 카드 효과를 캡슐화한 커맨드를 만든다. 서브클래스가 반드시 구현한다.
func create_command(_state: GameState, _player_id: int, _params: Dictionary) -> GameCommand:
	push_error("BaseCard.create_command()은 서브클래스에서 구현해야 합니다: %s" % card_id)
	return null
