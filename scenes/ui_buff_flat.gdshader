shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/ui_buff_ink.gdshaderinc"
uniform vec4 outline_tint:source_color=vec4(0.0);
uniform float effect_time=0.0;
uniform int effects=0;
varying vec2 local_pixel;
void vertex() {local_pixel=VERTEX;}
void fragment() {
	vec4 ink=buff_ink(local_pixel,effect_time,effects,outline_tint);
	COLOR=vec4(ink.rgb*COLOR.rgb,ink.a*COLOR.a);
}
