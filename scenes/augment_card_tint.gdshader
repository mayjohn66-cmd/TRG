shader_type canvas_item;

uniform vec4 category_tint : source_color = vec4(1.0);
uniform vec2 card_size = vec2(254.0, 384.0);
uniform float corner_radius = 13.0;
const vec2 SOURCE_ORIGIN = vec2(13.0, 13.0);
const vec2 SOURCE_SIZE = vec2(999.0, 1492.0);
varying vec4 vertex_tint;

float rounded_rect_distance(vec2 p, vec2 size, float radius) {
	vec2 q = abs(p - size * 0.5) - size * 0.5 + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 pixel = UV * card_size;
	vec2 source_pixel = SOURCE_ORIGIN + UV * SOURCE_SIZE;
	// Use only the blank reading surfaces from the illustration. Its painted
	// rim (including the concave corner joins) must not leak into the live rim.
	vec2 paper_pixel = vec2(mix(160.0, 864.0, UV.x), source_pixel.y);
	paper_pixel.y = 160.0 + abs(paper_pixel.y - 160.0);
	paper_pixel.y = 1376.0 - abs(paper_pixel.y - 1376.0);
	vec2 texels_per_pixel = fwidth(UV) / TEXTURE_PIXEL_SIZE;
	float lod = max(0.0, log2(max(texels_per_pixel.x, texels_per_pixel.y)));
	vec4 base = textureLod(TEXTURE, paper_pixel / vec2(1024.0, 1536.0), lod);
	float separators = max(1.0 - smoothstep(16.0, 24.0, abs(source_pixel.y - 656.0)), 1.0 - smoothstep(6.0, 10.0, abs(source_pixel.y - 854.0)));
	base = mix(base, textureLod(TEXTURE, vec2(0.5, paper_pixel.y / 1536.0), lod), separators);
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	// Two concentric rounded rectangles share the live outline's geometry.
	// Every straight span has exactly the same width; only the corners curve.
	float rim_width = 4.5;
	float distance_to_edge = rounded_rect_distance(pixel, card_size, corner_radius);
	float depth = -distance_to_edge;
	float inner_distance = rounded_rect_distance(pixel - vec2(rim_width), card_size - vec2(rim_width * 2.0), max(1.0, corner_radius - rim_width));
	float rim = smoothstep(-0.4, 0.4, inner_distance);
	float rim_gray = 0.48 + 0.16 * (1.0 - smoothstep(0.0, 1.0, depth));
	gray = mix(gray, rim_gray, rim);
	float inner_line = (1.0 - smoothstep(0.0, 0.7, abs(inner_distance))) * (1.0 - rim);
	gray = mix(gray, 0.12, inner_line);
	// Keep just the three embossed leaves, not the bowed frame behind them.
	vec2 corner = min(UV, vec2(1.0) - UV) * SOURCE_SIZE + SOURCE_ORIGIN;
	float leaf_a = length((corner - vec2(79.0, 56.0)) / vec2(17.0, 23.0));
	float leaf_b = length((corner - vec2(49.0, 85.0)) / vec2(22.0, 15.0));
	vec2 diagonal = corner - vec2(81.0, 92.0);
	float leaf_c = length(vec2((diagonal.x + diagonal.y) * 0.7071, (diagonal.y - diagonal.x) * 0.7071) / vec2(24.0, 11.0));
	float leaves = 1.0 - smoothstep(0.95, 1.10, min(leaf_a, min(leaf_b, leaf_c)));
	vec4 ornament = textureLod(TEXTURE, corner / vec2(1024.0, 1536.0), lod);
	gray = mix(gray, dot(ornament.rgb, vec3(0.299, 0.587, 0.114)), leaves);
	vec3 paint = mix(vec3(1.0), category_tint.rgb, 0.70);
	float mask = 1.0 - smoothstep(-0.5, 0.5, distance_to_edge);
	COLOR = vec4(vec3(gray) * paint, mask) * vertex_tint;
}
