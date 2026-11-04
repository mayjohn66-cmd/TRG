shader_type canvas_item;
render_mode unshaded;
#include "res://assets/fx/spotlight_floor.gdshaderinc"

uniform vec2 frame_size = vec2(1366.0,768.0);
uniform vec2 foot = vec2(683.0,380.0);
uniform vec2 source = vec2(548.0,-45.0);
uniform vec2 floor_axis_x = vec2(34.93,22.17);
uniform vec2 floor_axis_y = vec2(-34.93,22.17);
uniform vec4 light_tint : source_color = vec4(1.0,0.97,0.75,1.0);

void fragment() {
	vec2 pixel = UV*frame_size;
	float along=clamp((pixel.y-source.y)/max(foot.y-source.y,1.0),0.0,1.0);
	float cone=spotlight_cone(pixel,source,foot,floor_axis_x,floor_axis_y);
	// The selected pawn is above the dimmer. Only a flattened floor pool is lit.
	float pool=spotlight_pool(pixel,foot,floor_axis_x,floor_axis_y);
	float dim = 0.64*(1.0-pool*0.55);
	float glow = clamp(cone*mix(0.10,0.28,clamp(along,0.0,1.0))+pool*0.16,0.0,0.40);
	float alpha = dim+glow*(1.0-dim);
	vec3 colour = (vec3(0.025,0.019,0.04)*dim*(1.0-glow)+light_tint.rgb*glow)/max(alpha,0.001);
	COLOR = vec4(colour,alpha)*COLOR;
}
