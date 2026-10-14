# File: res://core_engine/rules/law_registry.gd
# Class: class_name LawRegistry
# Role: 교칙 ID -> 구현 클래스 팩토리. 스냅샷 복원과 네트워크 동기화에서 법전 큐를 재구성한다.
class_name LawRegistry
extends RefCounted

const ALL_IDS: Array[StringName] = [
	&"LAW_01", &"LAW_02", &"LAW_03", &"LAW_04", &"LAW_05", &"LAW_06", &"LAW_07", &"LAW_08",
]


static func create(law_id: StringName) -> BaseLaw:
	match law_id:
		&"LAW_01": return LawShortcutConstruction.new()
		&"LAW_02": return LawSocialDistancing.new()
		&"LAW_03": return LawCheekEquality.new()
		&"LAW_04": return LawFrogCurse.new()
		&"LAW_05": return LawRunawayTrain.new()
		&"LAW_06": return LawSpeedCamera.new()
		&"LAW_07": return LawJointGuarantee.new()
		&"LAW_08": return LawGoalThreshold.new()
	push_error("LawRegistry: 알 수 없는 교칙 ID '%s'" % law_id)
	return null
