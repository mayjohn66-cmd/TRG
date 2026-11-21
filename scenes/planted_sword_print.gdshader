shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform float amount : hint_range(0.0,1.0) = 0.0;
uniform bool erase = false;
uniform bool whole_surface = false;
uniform float visible_fraction : hint_range(0.0,1.0) = 1.0;
uniform float print_scale = 1.0;
uniform vec2 dimensions = vec2(1.0);
varying vec4 pigment;
varying vec2 print_position;
varying vec2 local_uv;
void vertex(){pigment=COLOR;print_position=VERTEX/max(print_scale,0.2);local_uv=VERTEX/max(dimensions,vec2(1.0));}
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	float value=dot(source.rgb,vec3(0.299,0.587,0.114));
	vec3 ink=vec3(0.13,0.09,0.12);
	vec3 paint=value<0.23?ink:(value<0.55?vec3(0.49,0.47,0.48):(value<0.82?vec3(0.78,0.80,0.77):vec3(0.98,0.96,0.88)));
	if(source.r>0.45 && source.g>0.28 && source.b<min(source.r,source.g)*0.75)
		paint=mix(vec3(0.58,0.27,0.08),vec3(1.0,0.82,0.27),step(0.55,value));
	vec2 cell=fract(print_position/5.0)-0.5;
	float dots=(1.0-smoothstep(0.12,0.20,length(cell)))*step(0.25,value)*(1.0-step(0.80,value));
	paint=mix(paint,ink,dots*0.22);
	vec2 p=whole_surface?UV:local_uv;
	float edge=p.x+sin(p.y*29.0)*0.015;
	float coverage=amount>=1.0?1.0:(amount<=0.0?0.0:1.0-smoothstep(amount*1.10-0.06,amount*1.10,edge));
	vec3 color=whole_surface?mix(source.rgb,paint,coverage):(erase?source.rgb:paint);
	float alpha=source.a*(whole_surface?1.0:(erase?1.0-coverage:coverage));
	if(!whole_surface)alpha*=1.0-smoothstep(visible_fraction-0.001,visible_fraction,local_uv.y);
	COLOR=vec4(victory_scene_tone(color),alpha)*pigment;
	COLOR.a=victory_backdrop_alpha(COLOR.a,SCREEN_UV);
}
