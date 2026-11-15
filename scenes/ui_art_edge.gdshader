shader_type canvas_item;

// Clip only the outermost fringe of an existing image; its colors and bevel remain.
uniform vec2 frame_size = vec2(640.0, 124.0);
uniform float edge_inset = 1.75;
uniform vec4 rim_tint : source_color = vec4(0.0);
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 half_size = frame_size * 0.5 - vec2(edge_inset);
	float radius = min(half_size.x, half_size.y);
	vec2 q = abs(local_position - frame_size * 0.5) - half_size + vec2(radius);
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float antialias = max(fwidth(distance_to_edge), 0.5);
	// Recolor the green rim while preserving the painted cream center and highlights.
	float rim_mask = smoothstep(0.03, 0.12, COLOR.g - COLOR.r) * rim_tint.a;
	COLOR.rgb = mix(COLOR.rgb, rim_tint.rgb * (0.55 + COLOR.g * 0.75), rim_mask);
	COLOR.a *= 1.0 - smoothstep(-antialias * 0.5, antialias * 0.5, distance_to_edge);
}
