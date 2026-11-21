shader_type canvas_item;
render_mode unshaded;
#include "res://assets/fx/spotlight_floor.gdshaderinc"
uniform float contact_age=0.0;
uniform float strength=0.0;
uniform float impact=0.0;
uniform bool front_pass=true;
uniform vec2 floor_axis_x=vec2(66.36,42.12);
uniform vec2 floor_axis_y=vec2(-66.36,42.12);

float hash(float n) {return fract(sin(n*127.1+311.7)*43758.5453);}
float grain(vec2 p) {
	vec2 cell=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	float a=hash(dot(cell,vec2(17.0,59.0)));
	float b=hash(dot(cell+vec2(1.0,0.0),vec2(17.0,59.0)));
	float c=hash(dot(cell+vec2(0.0,1.0),vec2(17.0,59.0)));
	float d=hash(dot(cell+vec2(1.0,1.0),vec2(17.0,59.0)));
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

void fragment() {
	// Tips rise UP from the projected ground rim, never radially in screen space.
	vec2 pixel=UV*vec2(300.0,220.0)-vec2(150.0,140.0);
	vec2 floor_uv=spotlight_floor_uv(pixel,floor_axis_x*0.58,floor_axis_y*0.58);
	float floor_radius=length(floor_uv);
	float pass_mask=front_pass ? step(0.0,pixel.y) : 1.0-step(0.0,pixel.y);
	// A feathered, broken light bed replaces the solid oval and outlined wedges.
	float haze=exp(-floor_radius*floor_radius*2.8)*pass_mask;
	haze*=0.48+grain(pixel*0.075+vec2(0.0,contact_age*1.8))*0.35;
	float hot=exp(-floor_radius*floor_radius*4.2)*pass_mask;
	vec3 ink=mix(vec3(0.42,0.87,1.0),vec3(1.0,0.99,1.0),clamp(hot*1.8,0.0,1.0));
	float opacity=clamp(haze*0.55+hot*0.60,0.0,0.98);
	for(int i=0;i<19;i++) {
		float id=float(i);
		float angle=(id+(hash(id+41.0)-0.5)*0.65)*6.28318531/19.0+0.15;
		vec2 root=(floor_axis_x*cos(angle)+floor_axis_y*sin(angle))*(0.43+hash(id+68.0)*0.19);
		bool front=root.y>=0.0;
		if(front!=front_pass) {continue;}
		float t=contact_age*(5.4+hash(id+14.0)*1.7)+hash(id+23.0);
		float cycle=floor(t);
		float phase=fract(t);
		float strike=smoothstep(0.0,0.18,phase)*(1.0-smoothstep(0.40,1.0,phase));
		float height=(18.0+pow(hash(id+cycle*19.0),1.1)*54.0+impact*15.0)*(0.30+0.70*strike);
		float rise=(root.y-pixel.y)/max(height,1.0);
		if(rise<0.0 || rise>1.0) {continue;}
		float lean=(hash(id+cycle*11.0+5.0)-0.5)*30.0;
		float bend=lean*rise*rise+sin(rise*19.0+id)*2.8*rise*(1.0-rise);
		float erosion=grain(vec2(rise*12.0+id*9.0,contact_age*6.0));
		float width=(2.6+hash(id+7.0)*3.8)*pow(1.0-rise,1.15)*(0.55+erosion*0.80);
		float distance_x=abs(pixel.x-root.x-bend);
		float core=1.0-smoothstep(width*0.24,width+0.65,distance_x);
		float halo=exp(-pow(distance_x/max(width+3.0,1.0),2.0)*1.6)*(1.0-rise)*0.32;
		float tip=1.0-smoothstep(0.82,1.0,rise);
		float alpha=(core*(0.76+0.24*erosion)+halo)*tip*(0.55+0.45*strike);
		vec3 color=mix(vec3(0.38,0.87,1.0),vec3(1.0,0.99,1.0),core);
		float blend=clamp(alpha,0.0,1.0);
		ink=mix(ink,color,blend);
		opacity=1.0-(1.0-opacity)*(1.0-blend);
	}
	COLOR=vec4(ink,opacity*strength);
}
