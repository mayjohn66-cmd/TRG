## Shared painted difficulty faces and the previously approved status icons.
class_name DifficultyArt
extends RefCounted

const FACES: Texture2D = preload("res://assets/ui/trickcal/difficulty/faces_v01.png")
const FLAME: Texture2D = preload("res://assets/ui/trickcal/difficulty/flame_v01.png")
const CROWN: Texture2D = preload("res://assets/ui/trickcal/difficulty/crown_v01.png")
const LOCK: Texture2D = preload("res://assets/ui/trickcal/difficulty/lock_v01.png")
const MUTED: Shader = preload("res://assets/ui/trickcal/difficulty/muted_icon.gdshader")
static var _regions: Dictionary = {}
static var _faces: Dictionary = {}
static var _muted_material: ShaderMaterial

static func region(texture: Texture2D) -> Rect2:
	var key := texture.get_instance_id()
	if not _regions.has(key):
		_regions[key] = Rect2(PawnArt.visible_region(texture.get_image()))
	return _regions[key]

static func icon(canvas: CanvasItem, texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var source := region(texture)
	var extent := source.size*minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	canvas.draw_texture_rect_region(texture,Rect2(rect.get_center()-extent*0.5,extent),source,tint)

static func face_region(level: int, alternate: bool) -> Rect2:
	var column := clampi(level,1,5)-1
	var row := 1 if alternate else 0
	var key := column+row*5
	if not _faces.has(key):
		var image := FACES.get_image()
		var frame_size := FACES.get_size()/Vector2(5,2)
		var start := Vector2i((Vector2(column,row)*frame_size).round())
		var end := Vector2i((Vector2(column+1,row+1)*frame_size).round())
		var crop := PawnArt.visible_region(image.get_region(Rect2i(start,end-start)))
		_faces[key] = Rect2(crop.position+start,crop.size)
	return _faces[key]

static func muted_material() -> ShaderMaterial:
	if _muted_material==null:
		_muted_material = ShaderMaterial.new()
		_muted_material.shader = MUTED
	return _muted_material
