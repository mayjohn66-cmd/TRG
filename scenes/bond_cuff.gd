## Painted metal band, hinge and interlocking links; no geometric halo.
extends Node2D
const ART = preload("res://scenes/bond_art.gd")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## 불빛은 1.5초 주기로 천천히 오르내려서 초당 20번만 다시 그려도 눈에 차이가 없다 (예전: 매 프레임). 안 보일 때는 그리지 않는다.
const REDRAW_INTERVAL: float = 1.0 / 20.0
var _since_redraw: float = 0.0

func _process(delta: float) -> void:
	_since_redraw += delta
	if _since_redraw >= REDRAW_INTERVAL and is_visible_in_tree():
		_since_redraw = 0.0
		queue_redraw()

func _draw() -> void:
	var pulse := 0.7+sin(Time.get_ticks_msec()*0.004)*0.16
	ART.cuff(self,Vector2(0,2),Vector2(37,17),1.0)
	ART.link(self,Vector2(17,7),Vector2(1,0.2).normalized(),true,1.0)
	ART.link(self,Vector2(23,8),Vector2.RIGHT,false,1.0)
	ART.light(self,Vector2(-10,-1),5,Color(1,0.83,0.6,pulse*0.6))
