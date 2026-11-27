extends SceneTree
func _initialize() -> void:
	var image:=Image.create(512,512,false,Image.FORMAT_RGB8)
	var broad:=FastNoiseLite.new()
	broad.seed=131
	broad.frequency=.014
	var fine:=FastNoiseLite.new()
	fine.seed=27
	fine.frequency=.32
	for y: int in 512:
		for x: int in 512:
			var grain:=y*.35+broad.get_noise_2d(x*.28,y*.9)*8.0
			var fiber:=pow(absf(sin(grain)),14.0)
			var rings:=sin(grain*.29)*.5+.5
			var pores:=fine.get_noise_2d(x*.27,y*2.4)
			var shade:=.57+rings*.17-fiber*.15+pores*.055
			var light:=Color("9d673c").lerp(Color("d4a16b"),clampf(shade,0,1))
			image.set_pixel(x,y,light)
	image.save_png("res://art_source/card_mats/v1/wood-oak-source.png")
	image.save_webp("res://assets/ui/trickcal/card_mats/v1/wood-oak.webp",true,.86)
	quit()
