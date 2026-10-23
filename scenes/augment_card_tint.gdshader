shader_type canvas_item;

uniform vec4 category_tint : source_color = vec4(1.0);
uniform vec2 card_size = vec2(254.0, 384.0);
uniform float corner_radius = 13.0;
varying vec4 vertex_tint;

// Warp only the four corner patches; straight edges and corner ornaments keep
// their full painted width instead of being compressed into a thin strip.
vec2 fit_corners(vec2 uv) {
	vec2 source_corner = vec2(128.0) / vec2(1003.0, 1498.0);
	vec2 patch = card_size * source_corner;
	vec2 edge = min(uv, vec2(1.0) - uv) * card_size;
	if (edge.x >= patch.x || edge.y >= patch.y) {
		return uv;
	}
	vec2 delta = vec2(1.0) - edge / patch;
	float radius = length(delta);
	vec2 direction = delta / max(radius, 0.0001);
	float boundary = 1.0 / max(max(direction.x, direction.y), 0.0001);
	vec2 hit = patch - direction * patch * boundary;
	if (min(hit.x, hit.y) < corner_radius && max(hit.x, hit.y) < corner_radius) {
		vec2 origin = patch - vec2(corner_radius);
		vec2 ray = direction * patch;
		float a = dot(ray, ray);
		float b = dot(origin, ray);
		float c = dot(origin, origin) - corner_radius * corner_radius;
		boundary = (b + sqrt(max(b * b - a * c, 0.0))) / max(a, 0.0001);
	}
	vec2 local = vec2(1.0) - direction * radius / boundary;
	vec2 mapped = local * source_corner;
	return mix(mapped, vec2(1.0) - mapped, step(vec2(0.5), uv));
}

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	// Visible source bounds omit the asymmetric transparent canvas padding.
	vec2 fitted = fit_corners(UV);
	vec2 source_uv = (vec2(11.0, 8.0) + fitted * vec2(1003.0, 1498.0)) / vec2(1024.0, 1536.0);
	vec4 base = texture(TEXTURE, source_uv);
	// One neutral painted base provides all category colors, without recolor files.
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 paint = mix(vec3(1.0), category_tint.rgb, 0.70);
	vec2 q = abs((UV - 0.5) * card_size) - card_size * 0.5 + vec2(corner_radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float mask = 1.0 - smoothstep(-0.5, 0.5, distance_to_edge);
	COLOR = vec4(vec3(gray) * paint, base.a * mask) * vertex_tint;
}
