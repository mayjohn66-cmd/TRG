shader_type canvas_item;
render_mode unshaded;

uniform float front_layer = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float fracture : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * 1.14;
	float angle = atan(p.y, p.x);
	// Separate a few curved glass fragments only while the shield is consumed.
	float sector = floor((angle + 3.141593) * 7.0 / 6.283185);
	float direction = (sector + 0.5) * 6.283185 / 7.0 - 3.141593;
	p -= vec2(cos(direction), sin(direction)) * fracture * 0.16;
	float radius = length(p);
	float aa = max(fwidth(radius), 0.008);
	float inside = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, radius);
	float normal_z = sqrt(max(1.0 - radius * radius, 0.0));
	vec3 normal = normalize(vec3(p, max(normal_z, 0.001)));
	float fresnel = pow(1.0 - normal_z, 2.0);
	float rim = smoothstep(0.87, 0.97, radius) * inside;
	float halo = exp(-pow((radius - 0.98) / 0.09, 2.0));
	float sheen = pow(max(dot(normal, normalize(vec3(-0.55, -0.68, 0.65))), 0.0), 34.0);
	float small_glint = exp(-dot((p - vec2(0.49, -0.43)) / vec2(0.065, 0.15), (p - vec2(0.49, -0.43)) / vec2(0.065, 0.15)));
	float breath = 0.94 + 0.06 * sin(TIME * 1.7 + phase);
	float cracks = smoothstep(0.0, max(0.001, fracture * 0.16), abs(sin((angle + 3.141593) * 3.5)));
	float intact = mix(1.0, cracks, smoothstep(0.0, 0.15, fracture));
	float alpha;
	vec3 tint;
	if (front_layer > 0.5) {
		// An almost-clear centre keeps the pawn and its owner-coloured base legible.
		alpha = inside * (0.025 + fresnel * 0.13 + rim * 0.36 + sheen * 0.65 + small_glint * 0.32);
		alpha += halo * 0.065;
		alpha += hit_flash * inside * (rim * 0.45 + sheen * 0.2);
		tint = mix(vec3(0.25, 0.77, 1.0), vec3(0.87, 0.99, 1.0), clamp(rim * 0.55 + sheen + small_glint, 0.0, 1.0));
	} else {
		alpha = inside * (0.065 + fresnel * 0.13) + halo * 0.09;
		tint = vec3(0.16, 0.65, 0.92);
	}
	COLOR *= vec4(tint, clamp(alpha * strength * breath * intact, 0.0, 0.9));
}
