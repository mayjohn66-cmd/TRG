shader_type canvas_item;

uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float eaten : hint_range(0.0, 1.1) = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 local_uv = (UV - region_uv.xy) / region_uv.zw;
	vec4 fruit = texture(TEXTURE, UV) * vertex_tint;
	if (eaten > 0.001) {
		// Three rounded tooth impressions at the exposed, freshly bitten edge.
		float edge = eaten + 0.018 * cos(local_uv.x * 18.849556);
		fruit.a *= smoothstep(edge - 0.002, edge + 0.002, local_uv.y);
		float flesh = 1.0 - smoothstep(0.008, 0.026, local_uv.y - edge);
		fruit.rgb = mix(fruit.rgb, vec3(0.84, 0.94, 0.61), flesh * 0.9);
	}
	COLOR = fruit;
}
