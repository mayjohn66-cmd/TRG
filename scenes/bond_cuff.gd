## Painted metal band, hinge and interlocking links; no geometric halo.
extends Node2D
const ART = preload("res://scenes/bond_art.gd")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pulse := 0.7+sin(Time.get_ticks_msec()*0.004)*0.16
	ART.cuff(self,Vector2(0,2),Vector2(37,17),1.0)
	ART.link(self,Vector2(17,7),Vector2(1,0.2).normalized(),true,1.0)
	ART.link(self,Vector2(23,8),Vector2.RIGHT,false,1.0)
	ART.light(self,Vector2(-10,-1),5,Color(1,0.83,0.6,pulse*0.6))
