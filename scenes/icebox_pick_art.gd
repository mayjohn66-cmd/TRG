## Layered 2D still life. Packets remain independent nodes for later pickup.
## Reuses the unmodified artwork for the ice and front-wall occlusion masks.
class_name IceboxPickArt
extends Control

signal selected(index: int)

const DIR := "res://assets/fx/judgment/icebox_2d/v1/"
const CONTENTS := [
	{"flavor":"mint",      "at":Vector2(.24,.735),"height":.37,"angle":-15.0},
	{"flavor":"strawberry","at":Vector2(.39,.735),"height":.40,"angle":8.0},
	{"flavor":"chocolate", "at":Vector2(.60,.735),"height":.365,"angle":16.0},
	{"flavor":"mint",      "at":Vector2(.76,.735),"height":.36,"angle":22.0},
	{"flavor":"chocolate", "at":Vector2(.29,.79), "height":.34,"angle":-24.0},
	{"flavor":"strawberry","at":Vector2(.49,.79), "height":.335,"angle":-8.0},
	{"flavor":"mint",      "at":Vector2(.68,.79), "height":.35,"angle":10.0},
]
# Follow the silhouettes of the existing ice bed, rather than hiding packet
# bottoms behind a single straight crop. UVs stay in the original box image.
const ICE_EDGE: Array[Vector2] = [
	Vector2(.125,.655),Vector2(.15,.625),Vector2(.18,.61),Vector2(.205,.645),
	Vector2(.24,.61),Vector2(.28,.60),Vector2(.315,.64),Vector2(.35,.615),
	Vector2(.39,.605),Vector2(.425,.637),Vector2(.46,.61),Vector2(.50,.605),
	Vector2(.535,.63),Vector2(.57,.61),Vector2(.61,.60),Vector2(.65,.635),
	Vector2(.69,.61),Vector2(.73,.605),Vector2(.77,.64),Vector2(.80,.61),
	Vector2(.835,.625),Vector2(.865,.62),Vector2(.89,.66),
	Vector2(.90,.705),Vector2(.10,.705),
]

var packets: Array[TextureRect] = []
var _box: Texture2D
var _foreground: Foreground
var interactive := false
var chosen := -1
var eating: IceCreamView
var take_clock := -1.0
var _bite_played := false
var _reveal_played := false
var _stick_played := false
var _details: Dictionary = {}
var _stock_alpha := 1.0
const SELECTED_WRAPPER_SIZE := Vector2(160,225)
var focus_point := Vector2.INF

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_layers)

static func _load_art(path: String) -> Texture2D:
	# Also allow standalone art review before the new PNGs are editor-imported.
	if FileAccess.file_exists(path+".import") or not FileAccess.file_exists(path):
		return load(path) as Texture2D
	return ImageTexture.create_from_image(Image.load_from_file(path))

func _ready() -> void:
	_box=_load_art(DIR+"icebox_ice.png")
	for index: int in CONTENTS.size():
		var data: Dictionary=CONTENTS[index]
		var picture:=TextureRect.new()
		picture.name="Packet%d_%s" % [index+1,data.flavor]
		picture.texture=_load_art(DIR+"wrapper_"+data.flavor+".png")
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.z_index=2+index
		if interactive:
			picture.mouse_filter=Control.MOUSE_FILTER_STOP
			picture.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
			picture.gui_input.connect(func(event: InputEvent) -> void:
				if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
					picture.accept_event()
					selected.emit(index))
		add_child(picture)
		packets.append(picture)
	_foreground=Foreground.new()
	_foreground.name="ForegroundIceAndRim"
	_foreground.texture=_box
	_foreground.z_index=30
	add_child(_foreground)
	_layout_layers()
	queue_redraw()

func flavor_at(index: int) -> String:
	return str(CONTENTS[index].flavor)

func prepare_result(details: Dictionary) -> void:
	_details=details.duplicate()

func take(index: int) -> void:
	if chosen>=0 or index<0 or index>=packets.size(): return
	chosen=index
	take_clock=0
	var packet:=packets[index]
	packet.z_index=40
	packet.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for other: TextureRect in packets:
		other.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if other!=packet:
			var clear:=create_tween()
			clear.tween_property(other,"modulate:a",0.0,.22)
			clear.tween_callback(other.hide)
	var clear_box:=create_tween().set_parallel(true)
	clear_box.tween_property(self,"_stock_alpha",0.0,.25)
	clear_box.tween_property(_foreground,"modulate:a",0.0,.25)
	clear_box.chain().tween_callback(_foreground.hide)
	var center:=packet.position+packet.pivot_offset+(packet.size*.5-packet.pivot_offset).rotated(packet.rotation)
	packet.pivot_offset=packet.size*.5
	packet.position=center-packet.pivot_offset
	var target:=focus_point if focus_point.is_finite() else size*.5
	var destination:=target+Vector2(0,12)-SELECTED_WRAPPER_SIZE*.5
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(packet,"position",destination,.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(packet,"rotation",0.0,.4)
	tween.tween_property(packet,"size",SELECTED_WRAPPER_SIZE,.45)
	tween.tween_property(packet,"pivot_offset",SELECTED_WRAPPER_SIZE*.5,.45)
	# Keep the same scale and position all the way from wrapper to bare ice cream.
	eating=IceCreamView.new()
	eating.in_place=true
	eating.set_flavor(flavor_at(index))
	eating.scale=Vector2.ONE*.8
	eating.position=target-IceCreamView.CENTER*.8
	eating.z_index=39
	eating.hide()
	add_child(eating)
	eating.begin(_details,int(_details.get("_kept_count",0)))
	eating.apply_time(.3)
	var tear:=create_tween()
	tear.tween_interval(.5)
	tear.tween_callback(func() -> void:
		packet.hide()
		eating.show()
		Sfx.play(&"wrapper_tear",-7)
		for top: bool in [true,false]:
			var fragment:=TextureRect.new()
			var atlas:=AtlasTexture.new()
			atlas.atlas=packet.texture
			var image_size:=packet.texture.get_size()
			atlas.region=Rect2(Vector2(0,0 if top else image_size.y*.24),image_size*Vector2(1,.24 if top else .76))
			fragment.texture=atlas
			fragment.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			fragment.size=packet.size*Vector2(1,.24 if top else .76)
			fragment.position=destination+Vector2(0,0 if top else packet.size.y*.24)
			fragment.pivot_offset=fragment.size*.5
			fragment.z_index=42
			fragment.mouse_filter=Control.MOUSE_FILTER_IGNORE
			add_child(fragment)
			var peel:=create_tween().set_parallel(true)
			peel.tween_property(fragment,"position",fragment.position+Vector2(-50,-55) if top else fragment.position+Vector2(10,100),.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			peel.tween_property(fragment,"rotation",-.55 if top else .18,.65)
			peel.tween_property(fragment,"modulate:a",0.0,.3).set_delay(.4)
	)

func _process(delta: float) -> void:
	if take_clock<0: return
	queue_redraw()
	take_clock+=delta
	if eating!=null:
		var native:=.3+maxf(0,take_clock-1.3)
		eating.apply_time(native)
		if native>=IceCreamView.BITE_AT and not _bite_played:
			_bite_played=true
			Sfx.play(&"icecream_snap",-5)
		if native>=IceCreamView.REVEAL_AT and not _reveal_played:
			_reveal_played=true
			Sfx.play(&"icecream_reveal",-7)
			if bool(_details.get("again",false)): Sfx.play(&"good",-9)
		if bool(_details.get("again",false)) and native>=IceCreamView.STICK_LAND_AT and not _stick_played:
			_stick_played=true
			Sfx.play(&"stick_land",-8)

func _layout_layers() -> void:
	for index: int in packets.size():
		var picture:=packets[index]
		var data: Dictionary=CONTENTS[index]
		var height: float=size.y*float(data.height)
		var source_size:=picture.texture.get_size()
		# Whitespace stays part of the source; use a cropped display atlas only.
		if not picture.texture is AtlasTexture:
			var pixels:=picture.texture.get_image()
			if pixels.is_compressed(): pixels.decompress()
			var used: Rect2i=pixels.get_used_rect()
			var atlas:=AtlasTexture.new()
			atlas.atlas=picture.texture
			atlas.region=Rect2(used)
			picture.texture=atlas
			source_size=Vector2(used.size)
		picture.size=Vector2(height*source_size.x/source_size.y,height)
		picture.pivot_offset=Vector2(picture.size.x*.5,picture.size.y)
		picture.position=size*(data.at as Vector2)-picture.pivot_offset
		picture.rotation=deg_to_rad(float(data.angle))
	if is_instance_valid(_foreground):
		_foreground.size=size
		_foreground.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if _box!=null and _stock_alpha>0: draw_texture_rect(_box,Rect2(Vector2.ZERO,size),false,Color(1,1,1,_stock_alpha))

class Foreground extends Control:
	var texture: Texture2D
	func _init() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if texture==null: return
		var points:=PackedVector2Array()
		for uv: Vector2 in ICE_EDGE: points.append(uv*size)
		draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array(ICE_EDGE),texture)
		var cut:=.69
		draw_texture_rect_region(texture,Rect2(Vector2(0,size.y*cut),size*Vector2(1,1-cut)),Rect2(Vector2(0,texture.get_height()*cut),texture.get_size()*Vector2(1,1-cut)))
