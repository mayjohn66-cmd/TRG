shader_type spatial;
render_mode unshaded;
uniform sampler2D strip : source_color, filter_linear_mipmap, repeat_enable;
uniform float blur : hint_range(0.0,1.0) = 0.0;
varying vec3 world_normal;
void vertex() {
	world_normal = MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() {
	vec2 span = vec2(0.0,0.023*blur);
	vec3 base = texture(strip,UV).rgb*0.40;
	base += (texture(strip,UV-span).rgb+texture(strip,UV+span).rgb)*0.20;
	base += (texture(strip,UV-span*2.0).rgb+texture(strip,UV+span*2.0).rgb)*0.10;
	float light = dot(normalize(world_normal),normalize(vec3(-0.15,0.25,1.0)));
	float shade = mix(0.62,1.0,smoothstep(0.25,1.0,light));
	ALBEDO = base*shade;
}
