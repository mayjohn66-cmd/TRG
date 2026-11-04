shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/ui_buff_ink.gdshaderinc"
uniform vec4 outline_tint:source_color=vec4(0.0);
uniform float effect_time=0.0;
uniform int effects=0;
varying vec2 local_pixel;
varying vec4 vertex_tint;
void vertex() {local_pixel=VERTEX;vertex_tint=COLOR;}
float skin_alpha(sampler2D skin,vec2 uv) {
	if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) {return 0.0;}
	return texture(skin,uv).a;
}
void fragment() {
	// Erode the existing skin alpha, so its real nine-sliced corners define the rim.
	vec2 px=TEXTURE_PIXEL_SIZE*2.5;
	float outer=skin_alpha(TEXTURE,UV);
	float inner=1.0;
	inner=min(inner,skin_alpha(TEXTURE,UV+vec2(px.x,0.0)));
	inner=min(inner,skin_alpha(TEXTURE,UV-vec2(px.x,0.0)));
	inner=min(inner,skin_alpha(TEXTURE,UV+vec2(0.0,px.y)));
	inner=min(inner,skin_alpha(TEXTURE,UV-vec2(0.0,px.y)));
	inner=min(inner,skin_alpha(TEXTURE,UV+px*0.7071));
	inner=min(inner,skin_alpha(TEXTURE,UV-px*0.7071));
	inner=min(inner,skin_alpha(TEXTURE,UV+vec2(px.x,-px.y)*0.7071));
	inner=min(inner,skin_alpha(TEXTURE,UV+vec2(-px.x,px.y)*0.7071));
	float rim=smoothstep(0.38,0.75,outer)*(1.0-smoothstep(0.38,0.75,inner));
	vec4 ink=buff_ink(local_pixel,effect_time,effects,outline_tint);
	COLOR=vec4(ink.rgb*vertex_tint.rgb,ink.a*rim*vertex_tint.a);
}
