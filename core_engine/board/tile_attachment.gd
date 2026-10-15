# File: res://core_engine/board/tile_attachment.gd
# Class: class_name TileAttachment
# Role: 타일 설치물(유희왕 함정·부르마블 호텔·지뢰 등) 부모 리소스. 기물이 타일을 밟을 때 발동 여부와 이동 중단 여부를 판정한다
class_name TileAttachment
extends Resource

@export var attachment_id: String = ""
@export var owner_id: int = -1
## true면 상대 화면에는 뒷면 카드로만 표시된다 (View 계층이 참조).
@export var is_hidden_trap: bool = true
## 남은 유지 턴 수. -1이면 영구 유지, 0이면 만료(소모)되어 이동 실행기가 타일에서 제거한다.
@export var duration_turns: int = -1


## 기물이 이 타일을 한 칸 밟을 때(통과 포함) 호출된다.
## 함정이 발동해 이동이 즉시 중단되어야 하면 true를 반환한다. 출발선 복귀 같은 부수 효과는
## ctx.state를 통해 직접 일으키고, 연출 ID는 ctx.metadata["cutscene_id"]에 담는다.
## ctx.metadata["is_landing"]은 이번 걸음이 이동의 마지막 칸인지 알려 준다.
func on_step_trigger(_victim: BoardEntity, _ctx: RuleContext) -> bool:
	return false


func is_expired() -> bool:
	return duration_turns == 0


## true면 턴이 지나도 유지 턴이 줄지 않는다 (예: 모노폴리 4세트 호텔). 기본은 항상 줄어든다.
func is_expiry_suspended(_state: GameState) -> bool:
	return false


## 턴이 한 번 지날 때마다 호출된다. 만료되면 true를 반환한다.
func tick_turn() -> bool:
	if duration_turns > 0:
		duration_turns -= 1
	return is_expired()


func serialize() -> Dictionary:
	return {
		"id": attachment_id,
		"owner": owner_id,
		"hidden": is_hidden_trap,
		"duration": duration_turns,
	}


func deserialize(data: Dictionary) -> void:
	owner_id = int(data.get("owner", -1))
	is_hidden_trap = bool(data.get("hidden", true))
	duration_turns = int(data.get("duration", -1))
