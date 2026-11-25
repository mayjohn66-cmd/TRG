shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

float grain(vec2 point) {
	return fract(sin(dot(point, vec2(12.99, 78.23))) * 43758.55);
}

void fragment() {
	vec2 uv = UV;
	float torn = sin(uv.x * 29.0) * 0.032 + sin(uv.x * 77.0) * 0.016
		+ (grain(vec2(floor(uv.x * 105.0), floor(uv.y * 55.0))) - 0.5) * 0.049;
	float front = progress * 1.14 - 0.07 + torn;
	float foil = smoothstep(front - 0.009, front + 0.009, uv.y);
	float torn_edge = 1.0 - smoothstep(0.002, 0.022, abs(uv.y - front));
	vec2 corner = max(abs(uv - 0.5) - vec2(0.406, 0.397), vec2(0.0));
	float round_corners = 1.0 - smoothstep(0.088, 0.103, length(corner));

	float speckle = grain(floor(uv * vec2(167.0, 144.0)));
	float brushed = 0.045 * sin(uv.y * 420.0 + uv.x * 43.0) + 0.085 * (speckle - 0.5);
	float highlight = (uv.x + uv.y * 0.62 - 0.64) * 6.0;
	float sheen = exp(-highlight * highlight);
	float lattice = pow(max(0.0, cos((uv.x - uv.y) * 46.0) * cos((uv.x + uv.y) * 41.0)), 6.0) * 0.055;
	vec3 silver = mix(vec3(0.52, 0.55, 0.62), vec3(0.86, 0.88, 0.90), sheen * 0.75);
	silver += brushed + lattice + torn_edge * 0.13;
	COLOR = vec4(silver, foil * round_corners);
}
