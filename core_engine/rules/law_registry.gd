# File: res://core_engine/rules/law_registry.gd
# Class: class_name LawRegistry
# Role: 교칙 ID -> 구현 클래스 팩토리. 중앙 법전의 특수 승리 교칙(LAW_01~08)과 초증강 개인 패시브(SUPER_10~12)를 만든다. 스냅샷 복원과 네트워크 동기화에서 법전을 재구성한다
class_name LawRegistry
extends RefCounted

## 중앙 법전에 오르는 특수 승리 교칙.
const ALL_IDS: Array[String] = [
	"LAW_01", "LAW_02", "LAW_03", "LAW_04", "LAW_05", "LAW_06", "LAW_07", "LAW_08",
]
## 초증강으로 얻는 개인 영구 패시브 (그 플레이어에게만 작동한다).
const PERSONAL_IDS: Array[String] = ["SUPER_10", "SUPER_11", "SUPER_12"]


static func create(law_id: String) -> LawResource:
	if VictoryLaw.is_victory_id(law_id):
		return VictoryLaw.new(law_id)
	match law_id:
		"SUPER_10": return LawAutobahn.new()
		"SUPER_11": return LawRunawayTrain.new()
		"SUPER_12": return LawJointGuarantee.new()
	push_error("LawRegistry: 알 수 없는 교칙 ID '%s'" % law_id)
	return null


## 개인 패시브를 만든다 (owner_id를 붙여서).
static func create_personal(law_id: String, owner: int) -> LawResource:
	var law: LawResource = create(law_id)
	if law != null:
		law.owner_id = owner
	return law
