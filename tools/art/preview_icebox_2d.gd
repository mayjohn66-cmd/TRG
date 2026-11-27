extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(960,760)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var scene := Display.new()
	scene.size=Vector2(960,760)
	root.add_child(scene)
	for i: int in 5: await RenderingServer.frame_post_draw
	var folder:=OS.get_cmdline_user_args()[0]
	root.get_texture().get_image().save_png(folder.path_join("icebox-stocked-2d.png"))
	scene.flavors=true
	scene.get_node("LayeredIcebox").visible=false
	scene.queue_redraw()
	for i: int in 3: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("icecream-flavors-2d.png"))
	print("ICEBOX_2D_PREVIEW_OK")
	quit()

class Display extends Control:
	const PICK_ART = preload("res://scenes/icebox_pick_art.gd")
	var flavors:=false
	var art: Dictionary={}
	const DIR: String="res://assets/fx/judgment/icebox_2d/v1/"
	const BARS: String="res://assets/fx/judgment/icecream_variants/v2/"
	const FONT: Font=preload("res://assets/fonts/game_ui_font.tres")
	func _ready() -> void:
		var display:=PICK_ART.new()
		display.name="LayeredIcebox"
		display.position=Vector2(50,135)
		display.size=Vector2(860,860.0*1024/1536)
		add_child(display)
	func texture(path: String, crop: bool=true) -> Texture2D:
		if not art.has(path):
			var img:=Image.load_from_file(path)
			assert(img!=null,"Missing art: "+path)
			var tex:=ImageTexture.create_from_image(img)
			if crop:
				var atlas:=AtlasTexture.new()
				atlas.atlas=tex
				atlas.region=Rect2(img.get_used_rect())
				art[path]=atlas
			else: art[path]=tex
		return art[path]
	func sprite(path: String, center: Vector2, height: float, angle: float=0) -> void:
		var tex:=texture(path)
		var extent:=tex.get_size()*(height/tex.get_height())
		draw_set_transform(center,angle)
		draw_texture_rect(tex,Rect2(Vector2(-extent.x/2,-height),extent),false)
		draw_set_transform(Vector2.ZERO)
	func caption(text: String,at: Vector2,px: int=24) -> void:
		var w:=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		draw_string(FONT,at-Vector2(w/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color("523426"))
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("fff9ed"))
		var names: Array[String]=["strawberry","chocolate","mint"]
		if not flavors:
			caption("2D 아이스박스 · 포장 아이스크림",Vector2(480,70),30)
		else:
			var labels: Array[String]=["딸기초코","초코","민트초코"]
			var bar_names: Array[String]=["strawberry_chocolate","chocolate","mint_chocolate"]
			for i: int in 3:
				var x:=190+i*290
				caption(labels[i],Vector2(x,70),28)
				var stick:=UiSkin.surface(Color("eac18e"),Color("523426"),2,8)
				draw_style_box(stick,Rect2(x-10,315,20,104))
				sprite(BARS+bar_names[i]+".png",Vector2(x,340),235)
				sprite(DIR+"wrapper_"+names[i]+".png",Vector2(x,710),240)
