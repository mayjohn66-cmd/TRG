shader_type canvas_item;

uniform vec4 category_tint : source_color = vec4(1.0);
uniform vec2 card_size = vec2(254.0, 384.0);
uniform float corner_radius = 13.0;
const vec2 SOURCE_ORIGIN = vec2(13.0, 13.0);
const vec2 SOURCE_SIZE = vec2(999.0, 1492.0);
varying vec4 vertex_tint;

// Warp only the four corner patches; straight edges and corner ornaments keep
// their full painted width instead of being compressed into a thin strip.
vec2 fit_corners(vec2 uv) {
	vec2 source_corner = vec2(128.0) / SOURCE_SIZE;
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
	vec2 fitted = fit_corners(UV);
	vec2 source_pixel = SOURCE_ORIGIN + fitted * SOURCE_SIZE;
	// Repeat a single straight profile rather than stretching the painted bow.
	// Corner patches stay intact; the center's paper grain stays untouched.
	vec2 source_uv = source_pixel / vec2(1024.0, 1536.0);
	vec2 edge = min(fitted, vec2(1.0) - fitted) * SOURCE_SIZE;
	float horizontal_weight = smoothstep(128.0, 160.0, edge.x);
	float horizontal_strip = max(1.0 - smoothstep(40.0, 56.0, edge.y), max(1.0 - smoothstep(16.0, 24.0, abs(source_pixel.y - 656.0)), 1.0 - smoothstep(6.0, 10.0, abs(source_pixel.y - 854.0))));
	float vertical_weight = smoothstep(128.0, 160.0, edge.y) * (1.0 - smoothstep(40.0, 56.0, edge.x));
	// Explicit LOD avoids mip seams where a repeated profile meets a corner.
	vec2 texels_per_pixel = fwidth(UV) / TEXTURE_PIXEL_SIZE;
	float lod = max(0.0, log2(max(texels_per_pixel.x, texels_per_pixel.y)));
	vec4 base = textureLod(TEXTURE, source_uv, lod);
	vec4 horizontal = textureLod(TEXTURE, vec2(0.5, source_uv.y), lod);
	vec4 vertical = textureLod(TEXTURE, vec2(source_uv.x, 0.5), lod);
	base = mix(base, horizontal, horizontal_weight * horizontal_strip);
	base = mix(base, vertical, vertical_weight);
	// One neutral painted base provides all category colors, without recolor files.
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 paint = mix(vec3(1.0), category_tint.rgb, 0.70);
	vec2 q = abs((UV - 0.5) * card_size) - card_size * 0.5 + vec2(corner_radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float mask = 1.0 - smoothstep(-0.5, 0.5, distance_to_edge);
	COLOR = vec4(vec3(gray) * paint, base.a * mask) * vertex_tint;
}
