# File: res://core_engine/board/tile_node.gd
# Class: class_name TileNode
# Role: 보드 그래프의 한 타일(0~28번). 타입, 진행 간선, 설치물(TileAttachment) 목록을 관리한다.
class_name TileNode
extends RefCounted

var index: int = 0
var tile_type: GameEnums.TileType = GameEnums.TileType.NORMAL
## 이 타일에서 나갈 수 있는 간선들 (BFS 탐색용. 실제 이동 분기는 BoardGraph가 판정).
var next_tiles: Array[int] = []
var attachments: Array[TileAttachment] = []


func _init(tile_index: int = 0, type: GameEnums.TileType = GameEnums.TileType.NORMAL) -> void:
	index = tile_index
	tile_type = type


func add_attachment(attachment: TileAttachment) -> void:
	attachments.append(attachment)


func remove_attachment(attachment: TileAttachment) -> void:
	attachments.erase(attachment)


func clear_attachments() -> void:
	attachments.clear()


func has_attachment(attachment_id: StringName) -> bool:
	for attachment: TileAttachment in attachments:
		if attachment.attachment_id == attachment_id:
			return true
	return false


func serialize_attachments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for attachment: TileAttachment in attachments:
		result.append(attachment.serialize())
	return result
