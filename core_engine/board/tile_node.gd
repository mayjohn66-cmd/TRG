# File: res://core_engine/board/tile_node.gd
# Class: class_name TileNode
# Role: 보드 그래프의 한 타일(0~23번). 타입, 다음 타일 간선, 설치물(TileAttachment) 목록을 보관한다
class_name TileNode
extends RefCounted

enum TileType { START_GOAL, NORMAL, BAKERY, PORTAL }

var tile_id: int = 0
var tile_type: TileType = TileType.NORMAL
## 기본 진행 방향의 다음 타일.
var next_default: int = -1
var attachments: Array[TileAttachment] = []


func _init(id: int = 0, type: TileType = TileType.NORMAL, default_next: int = -1) -> void:
	tile_id = id
	tile_type = type
	next_default = default_next


## 이 타일에서 나갈 수 있는 모든 간선 (BFS 탐색용).
func neighbors() -> Array[int]:
	var result: Array[int] = []
	if next_default != -1:
		result.append(next_default)
	return result


func add_attachment(attachment: TileAttachment) -> void:
	attachments.append(attachment)


func remove_attachment(attachment: TileAttachment) -> void:
	attachments.erase(attachment)


func clear_attachments() -> void:
	attachments.clear()


func has_attachment(attachment_id: String) -> bool:
	for attachment: TileAttachment in attachments:
		if attachment.attachment_id == attachment_id:
			return true
	return false


func serialize_attachments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for attachment: TileAttachment in attachments:
		result.append(attachment.serialize())
	return result
