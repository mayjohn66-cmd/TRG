shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform float wind_time = 0.0;
uniform float print_lock : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec2 uv = UV;
	float sway = sin(uv.y*30.0-wind_time*12.0)*0.012 + sin(uv.y*14.0+wind_time*7.0)*0.007;
	uv.x += sway*sin(UV.y*3.14159265)*(1.0-print_lock);
	vec4 cloud = texture(TEXTURE,uv);
	float ribbon = sin(UV.y*47.0-wind_time*14.0+UV.x*5.0);
	cloud.rgb *= 1.0+ribbon*0.045;
	cloud.rgb = victory_scene_tone(cloud.rgb);
	COLOR = cloud*COLOR;
	COLOR.a = victory_backdrop_alpha(COLOR.a,SCREEN_UV);
}
