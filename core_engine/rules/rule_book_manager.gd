# File: res://core_engine/rules/rule_book_manager.gd
# Class: class_name RuleBookManager
# Role: 중앙 법전. 패시브 교칙 최대 4개를 FIFO 큐로 보관하고, 스테이지 훅을 슬롯 순서대로 실행하는 인터셉터 파이프라인
class_name RuleBookManager
extends RefCounted

signal law_added(law_id: StringName, slot_index: int)
signal law_evicted(law_id: StringName)
signal law_repealed(law_id: StringName, slot_index: int)

var laws: Array[BaseLaw] = []


## 새 교칙을 추가한다. 슬롯이 가득 차면 가장 오래된 교칙이 밀려난다(FIFO). 중복 교칙은 거부한다.
func add_law(law: BaseLaw) -> GameEnums.AddLawResult:
	if has_law(law.law_id):
		return GameEnums.AddLawResult.REJECTED_DUPLICATE
	var result: GameEnums.AddLawResult = GameEnums.AddLawResult.ADDED
	if laws.size() >= GameEnums.MAX_LAWS:
		var evicted: BaseLaw = laws.pop_front()
		law_evicted.emit(evicted.law_id)
		result = GameEnums.AddLawResult.ADDED_EVICTED
	laws.append(law)
	law_added.emit(law.law_id, laws.size() - 1)
	return result


## ACT_06 이의 있음! 등으로 특정 슬롯의 교칙을 영구 삭제한다.
func repeal_slot(slot_index: int) -> BaseLaw:
	if slot_index < 0 or slot_index >= laws.size():
		return null
	var removed: BaseLaw = laws[slot_index]
	laws.remove_at(slot_index)
	law_repealed.emit(removed.law_id, slot_index)
	return removed


func has_law(law_id: StringName) -> bool:
	for law: BaseLaw in laws:
		if law.law_id == law_id:
			return true
	return false


func slot_of(law_id: StringName) -> int:
	for i: int in laws.size():
		if laws[i].law_id == law_id:
			return i
	return -1


## 슬롯 순서(오래된 교칙 먼저)대로 모든 교칙을 통과시킨다. 새 교칙이 늘어도 이 함수는 수정되지 않는다(OCP).
func run_stage(stage: GameEnums.HookStage, ctx: RuleContext) -> void:
	for law: BaseLaw in laws.duplicate():
		law.apply(stage, ctx)


func law_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for law: BaseLaw in laws:
		ids.append(law.law_id)
	return ids


## 시그널 없이 법전 내용을 통째로 교체한다 (스냅샷 복원·클라이언트 동기화용).
func set_laws_from_ids(ids: Array) -> void:
	laws.clear()
	for law_id: Variant in ids:
		var law: BaseLaw = LawRegistry.create(StringName(law_id))
		if law != null:
			laws.append(law)
