# File: res://scenes/fx_pool.gd
# Class: class_name FxPool
# Role: 자주 생겼다 사라지는 일회성 연출 노드(플로팅 글자·파편 파티클·충격 링 등)를 지우지 않고 숨겨 두었다가 다시 쓴다.
#       매번 새로 만들고 지우면 웹(WASM)에서 노드·리소스 할당이 쌓여 프레임이 튄다. 종류마다 MAX_IDLE개까지만 대기시키고 넘치면 지운다.
#       대기 중인 노드는 부모 아래에 visible = false로 남는다 (부모가 지워지면 함께 지워지고, 꺼낼 때 유효성을 확인한다).
class_name FxPool
extends RefCounted

const MAX_IDLE: int = 16
const KIND_META: StringName = &"fx_pool_kind"
const BUSY_META: StringName = &"fx_pool_busy"
## 이 노드를 움직이는 트윈 (돌려받을 때 멈춘다).
const TWEEN_META: StringName = &"fx_tween"

## 종류 -> 대기 중인 노드 목록.
var _idle: Dictionary = {}
var created: int = 0
var reused: int = 0


## 대기 중인 노드를 하나 꺼낸다 (없으면 null: 새로 만들어 adopt()로 등록한다).
func take(kind: StringName) -> Node:
	var waiting: Array = _idle.get(kind, [])
	while not waiting.is_empty():
		var node: Node = waiting.pop_back()
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree():
			node.set_meta(BUSY_META, true)
			reused += 1
			return node
	return null


## 새로 만든 노드를 풀에 등록한다 (다 쓰면 give_back으로 돌려준다).
func adopt(kind: StringName, node: Node) -> Node:
	node.set_meta(KIND_META, kind)
	node.set_meta(BUSY_META, true)
	created += 1
	return node


## 다 쓴 노드를 돌려받는다: 트윈을 멈추고 숨긴 뒤 다음 호출을 기다린다. 대기열이 가득 차면 지운다.
func give_back(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not bool(node.get_meta(BUSY_META, false)):
		return
	node.set_meta(BUSY_META, false)
	if node.has_meta(TWEEN_META):
		var tween: Variant = node.get_meta(TWEEN_META)
		if tween is Tween and (tween as Tween).is_valid():
			(tween as Tween).kill()
		node.remove_meta(TWEEN_META)
	if node is CPUParticles2D:
		(node as CPUParticles2D).emitting = false
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	for group: StringName in node.get_groups():
		node.remove_from_group(group)
	var kind: StringName = node.get_meta(KIND_META, &"")
	if not _idle.has(kind):
		_idle[kind] = []
	var waiting: Array = _idle[kind]
	if waiting.size() >= MAX_IDLE:
		node.queue_free()
		return
	waiting.append(node)


static func is_pooled(node: Node) -> bool:
	return node.has_meta(KIND_META)


func idle_count(kind: StringName) -> int:
	return (_idle.get(kind, []) as Array).filter(func(node: Variant) -> bool: return is_instance_valid(node)).size()


## 대기 중인 노드를 모두 지운다.
func clear() -> void:
	for waiting: Array in _idle.values():
		for node: Variant in waiting:
			if is_instance_valid(node):
				(node as Node).queue_free()
	_idle.clear()
