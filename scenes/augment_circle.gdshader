shader_type canvas_item;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	float distance_from_center = length(UV - vec2(0.5));
	float edge = max(fwidth(distance_from_center), 0.0001);
	COLOR = texture(TEXTURE, UV) * vertex_tint;
	COLOR.a *= 1.0 - smoothstep(0.5 - edge, 0.5, distance_from_center);
}
