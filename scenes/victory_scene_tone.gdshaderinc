// Shared paper and ink gently unify the illustration with its victory backdrop.
uniform float scene_blend : hint_range(0.0,1.0) = 0.0;
uniform float backdrop_mix : hint_range(0.0,1.0) = 0.0;
uniform vec4 paper_tone : source_color = vec4(0.97,0.95,0.88,1.0);
uniform vec4 ink_tone : source_color = vec4(0.12,0.08,0.15,1.0);
vec3 victory_scene_tone(vec3 source) {
	float value=dot(source,vec3(0.299,0.587,0.114));
	vec3 paint=mix(vec3(value),source,0.90);
	paint=mix(paint,ink_tone.rgb,(1.0-smoothstep(0.10,0.42,value))*0.22);
	paint=mix(paint,paper_tone.rgb,smoothstep(0.48,0.96,value)*0.20);
	paint=mix(source,paint,scene_blend);
	vec3 plate=mix(ink_tone.rgb,paper_tone.rgb,smoothstep(0.12,0.90,value));
	return mix(paint,plate,backdrop_mix*0.65);
}
float victory_backdrop_alpha(float alpha, vec2 screen_uv) {
	// Printed motifs merge into the caption edge; foreground portraits never use this mask.
	float field=1.0-smoothstep(0.62,0.72,screen_uv.y);
	return alpha*mix(1.0,field,backdrop_mix);
}
