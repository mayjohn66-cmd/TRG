shader_type canvas_item;
render_mode unshaded;
uniform float age = 0.0;
void fragment() {
	vec2 p = UV;
	float density = 0.0;
	for (int i = 0; i < 5; i++) {
		float n = float(i);
		vec2 center = vec2(0.13 + age * (0.42 + n * 0.08), 0.50 - age * (0.14 + n * 0.12));
		center += vec2(sin(n * 2.4 + age * 5.0), cos(n * 3.7 + age * 4.0)) * age * 0.07;
		float radius = 0.035 + age * (0.15 + n * 0.022);
		density += exp(-dot((p - center) / vec2(1.0, 1.4), (p - center) / vec2(1.0, 1.4)) / (radius * radius)) * 0.18;
	}
	float fade = smoothstep(0.0, 0.045, age) * (1.0 - smoothstep(0.16, 0.54, age));
	COLOR = vec4(mix(vec3(0.89, 0.86, 0.77), vec3(1.0, 0.96, 0.83), UV.y), min(density, 0.45) * fade);
}
