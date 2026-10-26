# File: res://tests/test_touch_slop.gd
# Class: class_name TestTouchSlop
# Role: 모바일 터치 판정 넓히기(MobileSupport.nearby_button_point): 버튼 근처를 누르면 가장 가까운 버튼 안쪽으로 옮기고,
#       버튼 위·멀리 떨어진 곳·덮은 창 뒤의 버튼·스스로 누름을 받는 칸(카드 등)은 건드리지 않는지 검사한다.
class_name TestTouchSlop
extends TestCase


func _button(parent: Node, rect: Rect2) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	parent.add_child(button)
	return button


func test_touch_near_a_button_snaps_inside_it() -> void:
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1366, 768)
	tree.root.add_child(stage)
	var left := _button(stage, Rect2(100, 100, 80, 40))
	var right := _button(stage, Rect2(300, 100, 80, 40))
	var near: Variant = MobileSupport.nearby_button_point(tree.root, Vector2(90, 110))
	check(near != null and Rect2(100, 100, 80, 40).has_point(near), "버튼 왼쪽 10px 밖을 누르면 그 버튼 안으로 (%s)" % str(near))
	check(MobileSupport.nearby_button_point(tree.root, Vector2(120, 120)) == null, "버튼 위를 누르면 그대로")
	check(MobileSupport.nearby_button_point(tree.root, Vector2(240, 120)) == null, "두 버튼 사이 먼 곳(60px)은 아무것도 누르지 않는다")
	var closer: Variant = MobileSupport.nearby_button_point(tree.root, Vector2(290, 120))
	check(closer != null and Rect2(300, 100, 80, 40).has_point(closer), "더 가까운 버튼을 고른다")
	right.disabled = true
	check(MobileSupport.nearby_button_point(tree.root, Vector2(290, 120)) == null, "꺼진 버튼은 고르지 않는다")
	right.disabled = false
	# 화면 전체를 덮는 창(딤): 그 뒤의 버튼은 고르지 않고, 창 안의 버튼만 고른다
	var modal := Control.new()
	modal.size = Vector2(1366, 768)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(modal)
	var dim := ColorRect.new()
	dim.size = Vector2(1366, 768)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	check(MobileSupport.nearby_button_point(tree.root, Vector2(90, 110)) == null, "덮은 창 뒤의 버튼은 누르지 않는다")
	var ok := _button(modal, Rect2(600, 400, 120, 50))
	var inside: Variant = MobileSupport.nearby_button_point(tree.root, Vector2(600 + 60, 400 + 70))
	check(inside != null and Rect2(600, 400, 120, 50).has_point(inside), "창 안 버튼 아래 20px을 누르면 그 버튼")
	# 스스로 누름을 받는 칸(손패 카드처럼 gui_input을 쓰는 것) 위는 옆 버튼으로 옮기지 않는다
	var card := Panel.new()
	card.position = Vector2(730, 400)
	card.size = Vector2(60, 80)
	card.gui_input.connect(func(_event: InputEvent) -> void: pass)
	modal.add_child(card)
	check(MobileSupport.nearby_button_point(tree.root, Vector2(735, 420)) == null, "카드 위 누름은 카드가 받는다")
	ok.free()
	modal.free()
	left.free()
	stage.free()
