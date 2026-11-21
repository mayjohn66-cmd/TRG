shader_type spatial;
render_mode unshaded;
varying vec3 world_normal;
void vertex() {
	world_normal = MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() {
	float light = dot(normalize(world_normal),normalize(vec3(-0.4,0.9,0.7)));
	float band = light>0.65 ? 1.0 : (light>0.1 ? 0.86 : 0.67);
	ALBEDO = COLOR.rgb*band;
}
