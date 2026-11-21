## Cosmetic only: bring a cucumber to the user's avatar and eat it in three bites.
## No gameplay callbacks, labels, rewards, screen shake or global time changes.
extends Control

const BITE: Shader = preload("res://assets/fx/cucumber_bite.gdshader")
const DURATION: float = 1.48
var active: bool = false
var elapsed: float = 0.0
var eaten: float = 0.0
var bite_count: int = 0
var _pace: float = 1.0
var _mouth := Vector2.ZERO
var _direction := Vector2.UP
var _height: float = 140.0
var _scale: float = 1.0
var _fruit: Sprite2D
var _audio:=PresentationAudio.new()
var _bite_material: ShaderMaterial

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	set_process(false)
	hide()

func begin(art: Dictionary, mouth: Vector2, toward: Vector2, height: float, pace: float = 1.0) -> void:
	cancel()
	if art.is_empty():
		return
	_mouth = mouth
	_direction = (toward - mouth).normalized()
	if _direction == Vector2.ZERO: _direction = Vector2.UP
	_height = height
	_pace = maxf(pace, 0.1)
	elapsed = 0.0
	var texture: Texture2D = art.texture
	var region: Rect2 = art.region
	_scale = height / region.size.y
	_fruit = Sprite2D.new()
	_fruit.texture = texture
	_fruit.region_enabled = true
	_fruit.region_rect = region
	_fruit.centered = false
	_fruit.offset = Vector2(-region.size.x * 0.5, 0)
	_bite_material = ShaderMaterial.new()
	_bite_material.shader = BITE
	_bite_material.set_shader_parameter("region_uv", Vector4(region.position.x / texture.get_width(), region.position.y / texture.get_height(), region.size.x / texture.get_width(), region.size.y / texture.get_height()))
	_fruit.material = _bite_material
	add_child(_fruit)
	active = true
	show()
	_audio.start(self,[PresentationAudio.cue(0.48,&"cucumber_bite"),PresentationAudio.cue(0.80,&"cucumber_bite"),PresentationAudio.cue(1.12,&"cucumber_bite")])
	sample(0.0)
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta / _pace
	_audio.advance(elapsed)
	sample(elapsed)
	if elapsed >= DURATION:
		cancel()

## One presentation clock drives approach, bite cutouts and withdrawal together.
func sample(seconds: float) -> void:
	if not is_instance_valid(_fruit): return
	var approach: float = smoothstep(0.0, 0.28, seconds)
	bite_count = 0
	for time: float in [0.48, 0.80, 1.12]:
		if seconds >= time: bite_count += 1
	eaten = [0.0, 0.29, 0.60, 1.05][bite_count]
	var chew: float = 0.0
	if seconds >= 0.48 and seconds < 1.32:
		chew = sin(clampf(fmod(seconds - 0.48, 0.32) / 0.22, 0.0, 1.0) * PI)
	_fruit.position = _mouth + _direction * (3.0 + (1.0 - approach) * 80.0 + chew * 9.0 - eaten * _height)
	_fruit.rotation = _direction.angle() - PI * 0.5 + (1.0 - approach) * 0.2 + chew * 0.035
	_fruit.scale = Vector2.ONE * _scale
	_fruit.modulate.a = minf(1.0, seconds / 0.14)
	_bite_material.set_shader_parameter("eaten", eaten)

func busy() -> bool:
	return active

func cancel() -> void:
	_audio.cancel()
	active = false
	set_process(false)
	hide()
	if is_instance_valid(_fruit):
		_fruit.queue_free()
	_fruit = null
