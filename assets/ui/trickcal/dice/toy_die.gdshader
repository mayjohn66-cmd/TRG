shader_type spatial;
render_mode unshaded;

uniform vec4 cream : source_color = vec4(1.0, 0.961, 0.843, 1.0);
varying vec3 world_normal;

void vertex() {
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	float light = dot(normalize(world_normal), normalize(vec3(-0.5, 0.85, 1.0)));
	float band = light > 0.65 ? 1.0 : (light > 0.1 ? 0.85 : 0.69);
	ALBEDO = cream.rgb * band;
}
