shader_type canvas_item;

uniform vec2 window_size;
uniform float radius;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 q = abs(UV * window_size - window_size * 0.5) - (window_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = texture(TEXTURE, UV) * vertex_tint;
	COLOR.a *= 1.0 - smoothstep(-0.5, 0.5, d);
}
