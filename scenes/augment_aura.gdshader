shader_type canvas_item;

uniform vec4 aura_color : source_color = vec4(0.40, 0.86, 0.94, 1.0);

uniform vec2 aura_direction = vec2(1.0, 0.0);

float noise_at(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	vec4 offsets = vec4(0.0, 1.0, 57.0, 58.0) + dot(cell, vec2(1.0, 57.0));
	vec4 samples = fract(sin(offsets) * 4375.85);
	return mix(mix(samples.x, samples.y, blend.x), mix(samples.z, samples.w, blend.x), blend.y);
}

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	point = vec2(dot(point, aura_direction), dot(point, vec2(-aura_direction.y, aura_direction.x)));
	// Drift the broad glow and the finer wisps independently. The artwork stays still.
	float phase = mod(TIME, 6.0) * (TAU / 6.0);
	vec2 drift = vec2(sin(phase), cos(phase));
	vec2 flow = point + drift * vec2(0.19, 0.24);
	float cloud = noise_at(flow * 4.0 + vec2(6.2, 1.4));
	vec2 curl = vec2(cos(phase + point.y * 2.4), sin(phase - point.x * 2.4));
	float wisps = noise_at((flow + curl * 0.13) * 9.0 + vec2(cloud * 1.9, 8.0));
	float grain = noise_at((flow + curl * 0.13) * 22.0 + vec2(3.1, 9.7));
	float density = cloud * 0.52 + wisps * 0.36 + grain * 0.12;

	// Break up the spread so the glow leaves soft gaps around the artwork.
	float reach = mix(0.67, 0.98, smoothstep(0.18, 0.82, density));
	float falloff = 1.0 - smoothstep(0.51, reach, radius);
	float opacity = falloff * mix(0.12, 0.83, smoothstep(0.22, 0.79, density));
	vec3 tint = mix(aura_color.rgb * 0.68, mix(aura_color.rgb, vec3(1.0), 0.47), wisps);
	COLOR = vec4(tint, opacity * aura_color.a);
}
