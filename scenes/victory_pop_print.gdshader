shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform vec4 print_ink : source_color = vec4(0.065,0.05,0.08,1.0);
uniform vec4 print_paper : source_color = vec4(0.97,0.95,0.88,1.0);
uniform vec4 print_accent : source_color = vec4(0.9,0.15,0.25,1.0);
uniform float print_scale = 1.0;
uniform bool pixel_dots = false;
uniform float alpha_cutoff = 0.0;
varying vec2 print_position;
varying vec4 pigment;

void vertex() {
	print_position = VERTEX / max(print_scale,0.2);
	pigment = COLOR;
}

void fragment() {
	vec4 src = texture(TEXTURE,UV);
	vec2 cell = fract(print_position / 7.0) - vec2(0.5);
	float dot_shape = pixel_dots ? max(abs(cell.x),abs(cell.y)) : length(cell);
	float dot_ink = 1.0-smoothstep(0.18,0.24,dot_shape);
	vec3 rgb = pigment.rgb;
	if (TEXTURE_PIXEL_SIZE.x < 0.02) {
		float value = dot(src.rgb,vec3(0.299,0.587,0.114));
		rgb = value < 0.29 ? print_ink.rgb : (value > 0.78 ? print_paper.rgb : print_accent.rgb);
		if(value>=0.29 && value<=0.78) rgb=mix(rgb,print_ink.rgb,dot_ink*0.78);
		rgb *= pigment.rgb;
	} else {
		// Screen-tone is contained in the large coloured print plates, not the text.
		float vivid = max(rgb.r,max(rgb.g,rgb.b))-min(rgb.r,min(rgb.g,rgb.b));
		if(vivid>0.22) rgb=mix(rgb,print_ink.rgb,dot_ink*0.42);
	}
	float coverage=alpha_cutoff>0.0 ? smoothstep(alpha_cutoff,alpha_cutoff+0.10,src.a) : src.a;
	COLOR=vec4(victory_scene_tone(rgb),coverage*pigment.a);
}
