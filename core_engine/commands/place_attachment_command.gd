# File: res://core_engine/commands/place_attachment_command.gd
# Class: class_name PlaceAttachmentCommand
# Role: 타일 설치형 카드 실행 - 지정 타일에 은신 설치물(TileAttachment)을 생성·설치
class_name PlaceAttachmentCommand
extends GameCommand

var tile: int = -1
var attachment_id: StringName = &""


func _init(acting_player: int = -1, target_tile: int = -1, id: StringName = &"") -> void:
	player_id = acting_player
	tile = target_tile
	attachment_id = id
	command_name = &"PlaceAttachment"


func _run(state: GameState) -> void:
	var attachment: TileAttachment = AttachmentRegistry.create(attachment_id)
	if attachment == null:
		return
	attachment.owner_id = player_id
	state.place_attachment(tile, attachment)
