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

## Every judgment action uses the same cream face, green edge and gray disabled
## state. Use the existing game button skin so hover/focus and click SFX agree.
static func button(item: Button, width: float = 150.0) -> void:
	item.custom_minimum_size=Vector2(width,48)
	item.add_theme_font_size_override("font_size",MobileSupport.text_px(18))
	UiSkin.button(item,false,12,8)
	item.add_theme_color_override("font_outline_color",Color.BLACK)
	item.add_theme_constant_override("outline_size",1)

## Keep cards/props and their action buttons visually separate on every table.
static func button_row(column: VBoxContainer) -> HBoxContainer:
	var space:=MarginContainer.new()
	space.name="ActionButtonSpacing"
	space.add_theme_constant_override("margin_top",24)
	column.add_child(space)
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",16)
	space.add_child(row)
	return row

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
