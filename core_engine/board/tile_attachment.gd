# File: res://core_engine/board/tile_attachment.gd
# Class: class_name TileAttachment
# Role: 타일 설치물(유희왕 함정·지뢰·호텔 등) 부모 클래스. 기물이 진입/통과할 때 발동 여부를 판정한다.
class_name TileAttachment
extends RefCounted

var attachment_id: StringName = &""
var owner_id: int = -1
## true면 상대 화면에는 뒷면 카드로만 표시된다 (View 계층이 참조).
var hidden: bool = true
## 남은 유지 턴 수. -1이면 영구 유지.
var turns_left: int = -1


## 기물이 이 타일에 진입(통과 포함)할 때 호출된다. 발동하지 않으면 null을 반환한다.
## is_landing: 이번 이동의 마지막 칸(도착)인지 여부.
func on_pawn_enter(_state: GameState, _pawn: PlayerPawn, _ctx: RuleContext, _is_landing: bool) -> AttachmentEffect:
	return null


## 턴이 한 번 지날 때마다 호출된다. 만료되면 true를 반환한다.
func tick_turn() -> bool:
	if turns_left < 0:
		return false
	turns_left -= 1
	return turns_left <= 0


func serialize() -> Dictionary:
	return {
		"id": attachment_id,
		"owner": owner_id,
		"hidden": hidden,
		"turns_left": turns_left,
	}


func deserialize(data: Dictionary) -> void:
	owner_id = int(data.get("owner", -1))
	hidden = bool(data.get("hidden", true))
	turns_left = int(data.get("turns_left", -1))
