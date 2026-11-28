shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform float printed : hint_range(0.0, 1.0) = 0.0;
uniform float print_scale = 1.0;
uniform vec4 accent : source_color = vec4(0.173, 0.780, 0.761, 1.0);
varying vec2 print_position;
varying vec4 tint;
void vertex() {
	print_position = VERTEX / max(print_scale, 0.2);
	tint = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec2 cell = fract(print_position / 7.0) - vec2(0.5);
	float dots = 1.0 - smoothstep(0.18, 0.24, length(cell));
	vec3 middle = mix(accent.rgb, ink_tone.rgb, dots * 0.65);
	vec3 plate = value < 0.35 ? ink_tone.rgb : (value > 0.78 ? paper_tone.rgb : middle);
	COLOR = vec4(mix(source.rgb, plate, printed), victory_backdrop_alpha(source.a, SCREEN_UV)) * tint;
}
