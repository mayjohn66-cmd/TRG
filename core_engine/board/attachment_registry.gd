# File: res://core_engine/board/attachment_registry.gd
# Class: class_name AttachmentRegistry
# Role: 설치물 ID -> 구현 클래스 팩토리. 스냅샷 복원·네트워크 동기화 시 직렬화된 설치물을 재생성한다
class_name AttachmentRegistry
extends RefCounted


static func create(attachment_id: String) -> TileAttachment:
	match attachment_id:
		"TRP_01": return TrapMirrorForce.new()  # 카드는 반격 CNT_02로 바뀌었지만, 밟으면 사출하는 기본 함정으로 남겨 둔다
		"TRP_02": return TrapPit.new()
		"TRP_03": return TrapMine.new()
		"TRP_05": return TrapDomino.new()
		"TRP_06": return TrapBanana.new()
		"TRP_07": return TrapSpike.new()
		"TRP_08": return TrapTransfer.new()
		"TRP_C01": return TrapIsland.new()
		"TRP_C02": return TrapJumpPad.new()
		"TRP_C03": return TrapToll.new()
		"TRP_C04": return TrapTar.new()
		"HOTEL": return Hotel.new()
	push_error("AttachmentRegistry: 알 수 없는 설치물 ID '%s'" % attachment_id)
	return null


static func from_dict(data: Dictionary) -> TileAttachment:
	var attachment: TileAttachment = create(String(data.get("id", "")))
	if attachment != null:
		attachment.deserialize(data)
	return attachment
