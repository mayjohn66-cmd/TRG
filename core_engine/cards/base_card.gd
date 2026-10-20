# File: res://core_engine/cards/base_card.gd
# Class: class_name BaseCard
# Role: 생떼 카드 추상 리소스. 사용 가능 페이즈·사용 조건 검증과 실행 커맨드 생성을 정의한다.
class_name BaseCard
extends Resource

@export var card_id: StringName = &""
@export var display_name: String = ""
@export var category: GameEnums.CardCategory = GameEnums.CardCategory.INSTANT
## 사용 가능한 TurnManager.State 값들.
var playable_phases: Array[int] = []
## 코너 전용 함정인가. 코너(출발선 제외)는 코너 전용 함정만 받고, 일반 함정은 코너에 설치할 수 없다.
var corner_only: bool = false


func is_playable_in(phase: int) -> bool:
	return playable_phases.has(phase)


## 이 카드는 보드판의 타일을 직접 골라야 하는가 (타일 설치형·소환형).
func needs_tile() -> bool:
	return false


## params 없이, 개입 창에서 이 플레이어가 이 카드를 낼 만한 상황인가. 창을 불필요하게 열지 않기 위해 TurnManager가 쓴다.
func could_play(_state: GameState, _player_id: int) -> bool:
	return true


## 카드별 사용 조건(대상 유효성 등). 기본은 항상 사용 가능.
func can_play(_state: GameState, _player_id: int, _params: Dictionary) -> bool:
	return true


## 실제 사용 판정: 함정 슬롯 규칙(코너 ↔ 코너 전용 함정) + 카드별 조건. 모든 호출자(턴 매니저·봇·UI)는 이것을 쓴다.
func is_legal(state: GameState, player_id: int, params: Dictionary) -> bool:
	if category == GameEnums.CardCategory.TRAP and params.has("tile"):
		if BoardSpec.bonus_corner_tiles.has(int(params["tile"])) != corner_only:
			return false
	return can_play(state, player_id, params)


## 카드 효과를 캡슐화한 커맨드를 만든다. 서브클래스가 반드시 구현한다.
func create_command(_state: GameState, _player_id: int, _params: Dictionary) -> GameCommand:
	push_error("BaseCard.create_command()은 서브클래스에서 구현해야 합니다: %s" % card_id)
	return null
