shader_type canvas_item;

// Clip only the outermost fringe of an existing image; its colors and bevel remain.
uniform vec2 frame_size = vec2(640.0, 124.0);
uniform float edge_inset = 1.75;
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
	COLOR.a *= 1.0 - smoothstep(-antialias * 0.5, antialias * 0.5, distance_to_edge);
}
