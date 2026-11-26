## 모바일 끌어서 스크롤: 터치 기기에서는 스크롤바를 정확히 잡지 않아도 스크롤 칸 안 아무 데나 끌면 내용이 움직이고,
## 끌다 뗀 자리의 버튼은 눌리지 않으며, 제자리 탭은 그대로 버튼을 누른다.
extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func frames(count: int = 3) -> void:
	for index: int in count:
		await process_frame


func press(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(event)
	await frames(1)


func move(at: Vector2, previous: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - previous
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(event)
	await frames(1)


func drag(from: Vector2, to: Vector2) -> void:
	await press(from, true)
	var last: Vector2 = from
	for step: int in range(1, 7):
		var at: Vector2 = from.lerp(to, step / 6.0)
		await move(at, last)
		last = at
	await press(to, false)


func center_of(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


func run() -> void:
	MobileSupport.force_touch = true
	root.size = Vector2i(1366, 768)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var mobile := MobileSupport.new()
	host.add_child(mobile)
	var popup: Control = UpdateNotes.open(host)
	await frames(6)
	var scroll: ScrollContainer = popup.find_child("NotesScroll", true, false)
	check(scroll != null, "공지 스크롤 칸을 찾지 못했다")
	if scroll != null:
		check(MobileSupport.drag_scroll_target(root, center_of(scroll)) == scroll, "공지 본문 위를 누르면 공지 스크롤 칸을 끌어야 한다")
		var row0: Button = popup.find_child("NotesRow0", true, false)
		var body0: Control = popup.find_child("NotesBody0", true, false)
		var start: Vector2 = center_of(scroll)
		await drag(start, start - Vector2(0, 180))
		check(scroll.scroll_vertical > 100, "공지 본문을 위로 끌면 아래로 스크롤되어야 한다 (지금 %d)" % scroll.scroll_vertical)
		var after_drag: int = scroll.scroll_vertical
		await drag(start, start + Vector2(0, 120))
		check(scroll.scroll_vertical < after_drag - 60, "아래로 끌면 다시 위로 스크롤되어야 한다")
		# 버튼(공지 줄) 위에서 시작해 끌고 떼면 그 줄은 눌리지 않는다
		scroll.scroll_vertical = 0
		await frames(2)
		var opened: bool = body0.visible
		var on_row: Vector2 = center_of(row0)
		await drag(on_row, on_row - Vector2(0, 40))
		check(body0.visible == opened, "끌어서 스크롤한 뒤 손을 뗀 줄이 펼쳐지거나 접히면 안 된다")
		check(scroll.scroll_vertical > 20, "공지 줄 버튼 위에서 시작해도 끌면 스크롤되어야 한다")
		# 제자리 탭은 그대로 줄을 누른다
		scroll.scroll_vertical = 0
		await frames(2)
		on_row = center_of(row0)
		await press(on_row, true)
		await press(on_row, false)
		check(body0.visible != opened, "제자리 탭은 공지 줄을 눌러야 한다")
		# 스크롤바를 직접 잡은 것은 원래대로 (끌기 스크롤로 가로채지 않는다)
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		check(MobileSupport.drag_scroll_target(root, center_of(bar)) == null, "스크롤바를 잡은 것은 가로채지 않아야 한다")
	# PC(마우스)에서는 끌기 스크롤을 하지 않는다
	MobileSupport.force_touch = false
	if scroll != null:
		scroll.scroll_vertical = 0
		await frames(2)
		var start2: Vector2 = center_of(scroll)
		await drag(start2, start2 - Vector2(0, 180))
		check(scroll.scroll_vertical == 0, "PC 마우스 끌기는 스크롤하지 않는다")
	popup.queue_free()
	host.queue_free()
	await frames(2)
	if failures.is_empty():
		print("UI touch scroll test passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
