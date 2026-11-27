## Shared table chrome for Mahjong, hold'em and Hwatu.
class_name JudgmentTableStyle
extends RefCounted

const FILL := Color("245c46")
const EDGE := Color("d7bc6b")
const TEXT := Color("fff3bf")
const DIM := Color(0.025,0.07,0.065,0.58)
const WIDTH := 640.0
const PADDING := 20.0
const LAYER := 80

static func surface() -> StyleBoxFlat:
	return UiSkin.surface(FILL,EDGE,3,20,8,20,Color(0,0,0,.28))

static func backdrop(owner: Control) -> ColorRect:
	owner.z_index=LAYER
	owner.z_as_relative=false
	var dim:=ColorRect.new()
	dim.name="TableDim"
	dim.color=DIM
	dim.mouse_filter=Control.MOUSE_FILTER_STOP
	owner.add_child(dim)
	owner.move_child(dim,0)
	return dim

static func layout_backdrop(owner: Control, dim: ColorRect) -> void:
	dim.position=-owner.global_position
	dim.size=owner.get_viewport_rect().size
