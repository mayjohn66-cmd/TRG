# File: res://core_engine/rules/rule_book_manager.gd
# Class: class_name RuleBookManager
# Role: 중앙 법전. 패시브 교칙을 최대 4개까지 FIFO 큐로 보관하고, 시점이 일치하는 교칙들에 RuleContext를 통과시키는 인터셉터 파이프라인
class_name RuleBookManager
extends Node

## 새 교칙이 들어왔다. 슬롯이 가득 차 밀려난 교칙이 있으면 removed_law에, 없으면 null이 담긴다.
signal law_added(new_law: LawResource, removed_law: LawResource)
## 역전재판 '이의 있음!' 등으로 교칙이 강제 파기되었다.
signal law_removed(removed_law: LawResource)
## process_context() 중 교칙 하나가 ctx를 가로챘다. 뷰가 어떤 교칙이 언제 작동했는지 보여 줄 때 구독한다.
signal law_applied(law: LawResource, timing: String, dice_before: int, dice_after: int)

const MAX_SLOTS: int = 4

var active_laws_queue: Array[LawResource] = []


## 새 교칙을 법전에 올린다. 슬롯이 가득 차 있으면 가장 오래된 교칙(index 0)을 밀어낸다.
func enqueue_law(new_law: LawResource) -> void:
	var removed_law: LawResource = null
	if active_laws_queue.size() >= MAX_SLOTS:
		removed_law = active_laws_queue.pop_front()
	active_laws_queue.push_back(new_law)
	law_added.emit(new_law, removed_law)


## ACT_06 '이의 있음!' 대응: law_id가 일치하는 가장 오래된 교칙 1개를 강제 파기한다. 없으면 false.
func remove_law_by_id(target_law_id: String) -> bool:
	for index: int in active_laws_queue.size():
		if active_laws_queue[index].law_id == target_law_id:
			var removed_law: LawResource = active_laws_queue[index]
			active_laws_queue.remove_at(index)
			law_removed.emit(removed_law)
			return true
	return false


## ctx.trigger_timing과 일치하는 교칙들을 priority 오름차순(동률이면 큐 순서)으로 실행해 변조된 ctx를 반환한다.
## 새 교칙이 늘어도 이 함수는 수정되지 않는다(OCP).
func process_context(ctx: RuleContext) -> RuleContext:
	var matched: Array[Dictionary] = []
	for index: int in active_laws_queue.size():
		var law: LawResource = active_laws_queue[index]
		if law.trigger_timing == ctx.trigger_timing:
			matched.append({"law": law, "index": index})
	matched.sort_custom(_compare_by_priority_then_slot)
	var current: RuleContext = ctx
	for entry: Dictionary in matched:
		var law: LawResource = entry["law"]
		var dice_before: int = current.dice_value
		var result: RuleContext = law.intercept(current)
		if result != null:
			current = result
		law_applied.emit(law, current.trigger_timing, dice_before, current.dice_value)
	return current


func has_law(law_id: String) -> bool:
	for law: LawResource in active_laws_queue:
		if law.law_id == law_id:
			return true
	return false


func law_ids() -> Array[String]:
	var ids: Array[String] = []
	for law: LawResource in active_laws_queue:
		ids.append(law.law_id)
	return ids


## 시그널 없이 법전 내용을 통째로 교체한다 (스냅샷 복원·클라이언트 동기화용).
func set_laws_from_ids(ids: Array) -> void:
	active_laws_queue.clear()
	for law_id: Variant in ids:
		var law: LawResource = LawRegistry.create(String(law_id))
		if law != null:
			active_laws_queue.append(law)


func _compare_by_priority_then_slot(a: Dictionary, b: Dictionary) -> bool:
	var law_a: LawResource = a["law"]
	var law_b: LawResource = b["law"]
	if law_a.priority != law_b.priority:
		return law_a.priority < law_b.priority
	return int(a["index"]) < int(b["index"])
