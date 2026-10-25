shader_type canvas_item;
render_mode unshaded;

uniform float cue_time = 0.0;
uniform float frame_aspect = 1.7778;

float ink_hash(float value) {
	return fract(sin(value*127.1+311.7)*43758.5453);
}

float ragged(float x,float seed) {
	float cell = x*37.0+seed;
	return mix(ink_hash(floor(cell)),ink_hash(floor(cell)+1.0),fract(cell));
}

void fragment() {
	float opening = 1.0-pow(1.0-clamp((cue_time-0.10)/0.14,0.0,1.0),3.0);
	float closing = clamp((cue_time-0.68)/0.37,0.0,1.0);
	float pinch = 1.0-smoothstep(0.18,1.0,closing);
	float center = 0.71-UV.x*0.37;
	float d = UV.y-center;
	// A tapered, asymmetric paper tear with non-repeating brush teeth.
	float taper = smoothstep(-0.04,0.30,UV.x);
	float half_height = mix(0.006,0.122,opening)*mix(0.12,1.0,taper)*pinch;
	float upper = half_height*(0.85+0.15*sin(UV.x*8.0))+(ragged(UV.x,0.2)-0.5)*0.020*opening*pinch;
	float lower = half_height*(0.85+0.13*cos(UV.x*11.0))+(ragged(UV.x,4.7)-0.5)*0.019*opening*pinch;
	float border = (0.010+ragged(UV.x,8.3)*0.010+smoothstep(0.10,0.65,closing)*0.031)*pinch;
	float outer = smoothstep(-upper-border-0.001,-upper-border,d)*(1.0-smoothstep(lower+border,lower+border+0.001,d));
	float inner = smoothstep(-upper,-upper+0.001,d)*(1.0-smoothstep(lower-0.001,lower,d));
	float tip = clamp(cue_time/0.11,0.0,1.0)*1.25-0.05;
	outer *= 1.0-smoothstep(tip,tip+0.018,UV.x);
	// Look through a narrow window at the existing eyes, preserving their aspect.
	float kick = 0.012*exp(-max(cue_time-0.20,0.0)*32.0)*sin(max(cue_time-0.20,0.0)*55.0);
	float source_x = 0.135+UV.x*0.55+kick;
	float source_y = 0.475+d*(0.55*1.7778/frame_aspect)-(UV.x-0.5)*0.08;
	vec3 face = texture(TEXTURE,vec2(source_x,source_y)).rgb;
	vec3 red = vec3(0.96,0.045,0.018);
	face = mix(red,face,smoothstep(0.10,0.23,UV.x)*(1.0-smoothstep(0.86,0.98,UV.x)));
	// White ink precedes the eyes and consumes them from right to left on exit.
	float face_front = clamp((cue_time-0.13)/0.12,0.0,1.0)*1.35-0.15;
	float entry_white = smoothstep(face_front,face_front+0.015,UV.x);
	float exit_front = 1.14-closing*1.45+(ragged(UV.x,12.6)-0.5)*0.05;
	float exit_white = smoothstep(exit_front,exit_front+0.022,UV.x);
	float painted = max(entry_white,exit_white);
	vec3 white = vec3(1.0,0.995,0.975);
	vec3 ink = mix(white,mix(face,white,painted),inner);
	COLOR = vec4(ink,outer*step(cue_time,1.049));
}
