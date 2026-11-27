## One 3D table: thirteen face-down candidates, three pickups, one simultaneous reveal.
class_name MahjongPick3D
extends MahjongSlam3D

signal selected(index: int)
var candidates: Array[Node3D] = []
var selected_indices: Array[int] = []
var values: Array = [0,1,2]
var flipped := false

func _ready() -> void:
	super._ready()
	size=Vector2(600,312)
	custom_minimum_size=size
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	begin(values)
	_camera.size=5.2
	_camera.position=Vector3(0,8.4,9.3)
	_camera.look_at(Vector3(0,.5,.4))
	for child: Node in render_view.get_children():
		if child is MeshInstance3D:
			child.hide() # Use the live board as the table, without an opaque second mat.
			break
	for i: int in 13:
		var tile:=tiles[0].duplicate() as Node3D
		render_view.add_child(tile)
		tile.name="FaceDownCandidate%d" % i
		tile.scale=Vector3.ONE*.42
		tile.rotation.x=PI
		tile.position=Vector3((i-6)*.57,.19,-1.1)
		candidates.append(tile)
		tile.show()
	for tile: Node3D in tiles: tile.hide()
	for shadow: MeshInstance3D in shadows: shadow.hide()

func screen_position(index: int) -> Vector2:
	return _camera.unproject_position(candidates[index].global_position)/Vector2(render_view.size)*size

func pick(index: int) -> void:
	if selected_indices.has(index) or selected_indices.size()>=3: return
	var slot:=selected_indices.size()
	selected_indices.append(index)
	var tile:=tiles[slot]
	tile.transform=candidates[index].transform
	candidates[index].hide()
	tile.show()
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(tile,"position",Vector3((slot-1)*1.7,.34,1.6),.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile,"scale",Vector3.ONE*.8,.32)
	Sfx.play(&"mahjong_tap",-6)

func reveal(progress: float) -> void:
	flipped=progress>=1
	var angle:=PI*(1-smoothstep(0,1,progress))
	for tile: Node3D in tiles:
		tile.rotation.x=angle
		tile.position.y=.34+sin(progress*PI)*.6

func _gui_input(event: InputEvent) -> void:
	var at:=Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: at=event.position
	elif event is InputEventScreenTouch and event.pressed: at=event.position
	else: return
	var nearest:=-1
	var distance:=INF
	for i: int in candidates.size():
		if not candidates[i].visible: continue
		var point:=screen_position(i)
		var delta:=point.distance_to(at)
		if delta<distance and absf(point.x-at.x)<20 and absf(point.y-at.y)<36:
			distance=delta
			nearest=i
	if nearest>=0:
		accept_event()
		selected.emit(nearest)
