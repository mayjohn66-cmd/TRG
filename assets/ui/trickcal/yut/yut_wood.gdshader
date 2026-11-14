shader_type spatial;
render_mode unshaded;
uniform sampler2D wood : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 belly : source_color = vec4(1.0,0.90,0.69,1.0);
uniform vec4 back : source_color = vec4(0.76,0.47,0.22,1.0);
varying vec3 world_normal;
varying float is_belly;
void vertex() {
	world_normal = MODEL_NORMAL_MATRIX*NORMAL;
	is_belly = NORMAL.y < -0.9 ? 1.0 : 0.0;
}
void fragment() {
	vec3 grain = texture(wood,UV).rgb;
	vec3 base = mix(mix(grain,back.rgb,0.35),mix(grain,belly.rgb,0.65),is_belly);
	float light = dot(normalize(world_normal),normalize(vec3(-0.4,0.9,0.8)));
	float band = light>0.65 ? 1.0 : (light>0.1 ? 0.87 : 0.72);
	ALBEDO = base*band;
}
