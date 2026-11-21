shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform float outline_pixels = 8.0;
uniform vec4 ink : source_color = vec4(0.2,0.13,0.16,1.0);
uniform bool silhouette = false;
uniform bool pop_art = false;
uniform float print_scale = 1.0;
varying vec4 tint;
varying vec2 print_position;
void vertex() { tint=COLOR; print_position=VERTEX/max(print_scale,0.2); }
void fragment() {
	vec4 sample_color = texture(TEXTURE,UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE*outline_pixels;
	float edge=sample_color.a;
	for(int i=0;i<8;i++) {
		float angle=float(i)*0.785398;
		edge=max(edge,texture(TEXTURE,UV+vec2(cos(angle),sin(angle))*step_uv).a);
	}
	vec3 paint = sample_color.rgb;
	if(pop_art) {
		// Flatten painted shading; anatomy and alpha come from the unchanged portrait.
		float original_value=dot(paint,vec3(0.299,0.587,0.114));
		float level=floor(original_value*5.0+0.5)/5.0;
		vec3 flat_rgb=clamp(paint*(0.08+level)/(0.08+original_value),vec3(0.0),vec3(1.0));
		paint=mix(paint,flat_rgb,0.58);
		float value=dot(paint,vec3(0.299,0.587,0.114));
		vec2 cell=fract(print_position/6.0)-vec2(0.5);
		float dots=1.0-smoothstep(0.18,0.25,length(cell));
		float shade=(1.0-smoothstep(0.32,0.52,value))*smoothstep(0.08,0.22,value);
		paint=mix(paint,vec3(0.065,0.045,0.075),dots*shade*0.32);
	}
	paint=victory_scene_tone(paint);
	vec3 edge_paper=mix(vec3(1.0,0.975,0.91),paper_tone.rgb,scene_blend);
	vec3 rgb = silhouette ? ink.rgb : mix(edge_paper,paint,smoothstep(0.0,0.85,sample_color.a));
	COLOR=vec4(rgb,edge)*tint;
}
