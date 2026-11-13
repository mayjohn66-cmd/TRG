shader_type canvas_item;
uniform vec4 rim_color : source_color = vec4(0.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	float distance_from_center = length(UV - vec2(0.5));
	float edge = max(fwidth(distance_from_center), 0.0001);
	COLOR = texture(TEXTURE, UV) * vertex_tint;
	float rim = smoothstep(0.5 - edge * 1.7, 0.5 - edge * 0.7, distance_from_center);
	COLOR.rgb = mix(COLOR.rgb, rim_color.rgb * vertex_tint.rgb, rim * rim_color.a);
	COLOR.a *= 1.0 - smoothstep(0.5 - edge, 0.5, distance_from_center);
}
