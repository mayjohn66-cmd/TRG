## Keep the presentation centered even if the phone rotates during playback.
extends Panel
var opening_scale := 1.0:
	set(value):
		opening_scale = value
		fit_window()

func _ready() -> void:
	get_viewport().size_changed.connect(fit_window)
	fit_window()

func fit_window() -> void:
	if not is_inside_tree(): return
	var view: Vector2 = get_viewport_rect().size
	var fit: float = minf(1.0,minf((view.x-24.0)/size.x,(view.y-24.0)/size.y))
	pivot_offset = size/2.0
	position = (view-size)/2.0
	scale = Vector2.ONE*fit*opening_scale
