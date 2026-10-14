# File: res://core_engine/board/attachment_registry.gd
# Class: class_name AttachmentRegistry
# Role: 설치물 ID -> 구현 클래스 팩토리. 스냅샷 복원·네트워크 동기화 시 직렬화된 설치물을 재생성한다
class_name AttachmentRegistry
extends RefCounted


static func create(attachment_id: String) -> TileAttachment:
	match attachment_id:
		"TRP_01":
			return TrapMirrorForce.new()
	push_error("AttachmentRegistry: 알 수 없는 설치물 ID '%s'" % attachment_id)
	return null


static func from_dict(data: Dictionary) -> TileAttachment:
	var attachment: TileAttachment = create(String(data.get("id", "")))
	if attachment != null:
		attachment.deserialize(data)
	return attachment
