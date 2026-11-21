## Screen-space lighting follows the same plane and canvas transforms as board tiles.
extends RefCounted
const FLOOR_RADIUS:=0.095

static func tile_screen(board:Node,index:int) -> Vector2:
	return board._board_layer.get_global_transform_with_canvas()*board._tile_center(index)

static func center_screen(board:Node) -> Vector2:
	return board._board_layer.get_global_transform_with_canvas()*board._surface_project(Vector2.ONE*0.5)

static func floor_axes(board:Node,overlay:CanvasItem) -> Transform2D:
	var frame:Transform2D=overlay.get_global_transform_with_canvas().affine_inverse()*board._board_layer.get_global_transform_with_canvas()
	var origin:Vector2=board._surface_project(Vector2.ONE*0.5)
	var x:Vector2=board._surface_project(Vector2(0.5+FLOOR_RADIUS,0.5))-origin
	var y:Vector2=board._surface_project(Vector2(0.5,0.5+FLOOR_RADIUS))-origin
	return Transform2D(frame.basis_xform(x),frame.basis_xform(y),Vector2.ZERO)

static func into_overlay(overlay:CanvasItem,screen:Vector2) -> Vector2:
	return overlay.get_global_transform_with_canvas().affine_inverse()*screen
