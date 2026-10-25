shader_type canvas_item;
render_mode unshaded;

uniform float cue_time = 0.0;

void fragment() {
	float opening = 1.0-pow(1.0-clamp((cue_time-0.055)/0.205,0.0,1.0),3.0);
	float exit_u = clamp((cue_time-0.86)/0.34,0.0,1.0);
	float exit_ease = exit_u*exit_u;
	float diagonal = UV.y-0.51+(UV.x-0.5)*0.35;
	// A narrow tear opens into a jagged oblique panel; no opacity fade on the art.
	float edge = abs(fract(UV.x*23.0)-0.5)*0.019+abs(fract(UV.x*13.0+0.2)-0.5)*0.014;
	float aperture = mix(0.003,0.46,opening)*(1.0-exit_ease);
	float band = 1.0-smoothstep(aperture+edge,aperture+edge+0.002,abs(diagonal));
	float reveal = 1.0-smoothstep(opening*1.45-0.16,opening*1.45-0.13,UV.x+0.13*UV.y);
	float cleared = smoothstep(exit_ease*1.55-0.15,exit_ease*1.55-0.13,UV.x+0.13*UV.y);
	vec2 uv = UV;
	// Fast overshoot settles in two frames, then hold still for the eye flash.
	float kick = 0.035*exp(-max(cue_time-0.24,0.0)*30.0)*sin(max(cue_time-0.24,0.0)*68.0);
	float drift = max(cue_time-0.40,0.0)*0.012;
	uv.x += (1.0-opening)*0.34+kick-drift;
	// The upper and lower slices shear in opposite directions as the panel sweeps out.
	uv.x += exit_ease*(diagonal<0.0 ? -0.75 : 0.58);
	float zoom = 1.0+0.055*opening+drift;
	uv = (uv-vec2(0.5,0.51))/zoom+vec2(0.5,0.51);
	vec4 ink = texture(TEXTURE,clamp(uv,vec2(0.0),vec2(1.0)));
	float flash = (1.0-smoothstep(0.24,0.29,cue_time))*step(0.24,cue_time);
	ink.rgb = mix(ink.rgb,vec3(1.0,0.96,0.83),flash*0.62);
	// A moving hard white glint traverses the mask, then snaps off.
	float shine_t = clamp((cue_time-0.28)/0.16,0.0,1.0);
	float shine = (1.0-smoothstep(0.008,0.025,abs(UV.x-(0.20+shine_t*0.48))))*
		(1.0-smoothstep(0.10,0.20,abs(UV.y-0.49)))*step(0.28,cue_time)*(1.0-step(0.44,cue_time));
	ink.rgb = mix(ink.rgb,vec3(1.0,0.98,0.89),shine*0.92);
	COLOR = vec4(ink.rgb,ink.a*band*reveal*cleared);
}
