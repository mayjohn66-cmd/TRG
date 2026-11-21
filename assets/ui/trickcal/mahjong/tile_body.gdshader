shader_type spatial;
render_mode unshaded;
varying vec3 world_normal;
varying float local_y;
void vertex() {
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
	local_y = VERTEX.y;
}
void fragment() {
	float light = dot(normalize(world_normal),normalize(vec3(-0.4,0.85,0.8)));
	float band = light>0.65 ? 1.0 : (light>0.1 ? 0.86 : 0.70);
	vec3 base = local_y < -0.11 ? vec3(0.294,0.592,0.384) : vec3(1.0,0.961,0.843);
	ALBEDO = base * band;
}
