shader_type canvas_item;
render_mode unshaded;
#include "res://assets/fx/spotlight_floor.gdshaderinc"
uniform float flow_time=0.0;
uniform float drop=1.0;
uniform float retract=0.0;
uniform float impact=0.0;
uniform vec2 column_size=vec2(300.0,430.0);
uniform float foot_y=375.0;
uniform vec2 floor_axis_x=vec2(66.36,42.12);
uniform vec2 floor_axis_y=vec2(-66.36,42.12);
uniform float contact=1.0;
varying vec4 vertex_tint;
void vertex(){vertex_tint=COLOR;}
void fragment() {
	vec2 pixel=UV*column_size;
	vec2 uv=vec2(UV.x,clamp(pixel.y/max(foot_y,1.0),0.001,0.999));
	// Keep energy flowing while limiting the column's soft, snake-like warping.
	float wiggle=sin(UV.y*19.0-flow_time*5.0)*0.0035+sin(UV.y*37.0+flow_time*3.2)*0.0012;
	uv.x+=wiggle*sin(UV.x*3.14159265);
	uv.y=clamp(uv.y+sin(UV.y*28.0-flow_time*9.0)*0.003,0.001,0.999);
	vec4 energy=texture(TEXTURE,uv);
	float rush=0.97+sin(UV.y*90.0-flow_time*32.0+UV.x*9.0)*0.035;
	energy.rgb*=rush;
	float runner=pow(max(0.0,sin(uv.y*44.0-flow_time*21.0+uv.x*5.0)),10.0);
	energy.rgb=mix(energy.rgb,vec3(0.95,0.99,1.0),runner*0.16);
	energy.rgb=mix(energy.rgb,vec3(1.0,0.98,1.0),impact*0.20);
	float fringe=sin(UV.x*43.0+flow_time*2.0)*7.0+sin(UV.x*17.0-flow_time)*5.0;
	float arrival=(1.0-smoothstep(foot_y*drop-10.0,foot_y*drop+12.0,pixel.y+fringe))*step(0.001,drop);
	arrival=mix(arrival,1.0,contact);
	float side_fade=smoothstep(0.02,0.15,UV.x)*(1.0-smoothstep(0.85,0.98,UV.x));
	vec2 delta=pixel-vec2(column_size.x*0.5,foot_y);
	float r=length(spotlight_floor_uv(delta,floor_axis_x,floor_axis_y));
	float flare=exp(-r*r*4.6)*contact;
	float body=energy.a*arrival*side_fade*(1.0-smoothstep(-5.0,17.0,delta.y));
	float alpha=clamp(body+flare*0.96,0.0,0.995);
	vec3 color=mix(energy.rgb,vec3(1.0,0.98,1.0),clamp(flare*1.5,0.0,1.0));
	// Width is compressed around the beam axis by the view; only the final thread fades.
	COLOR=vec4(color,alpha*(1.0-smoothstep(0.90,1.0,retract)))*vertex_tint;
}
