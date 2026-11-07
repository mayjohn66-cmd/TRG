shader_type canvas_item;

uniform vec4 seat_color : source_color = vec4(0.11, 0.49, 0.84, 1.0);
varying vec4 node_tint;

void vertex() { node_tint = COLOR; }

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float value = max(src.r, max(src.g, src.b));
	float saturation = (value - min(src.r, min(src.g, src.b))) / max(value, 0.001);
	float blue = smoothstep(0.015, 0.10, src.b - max(src.r, src.g));
	vec3 hue = seat_color.rgb / max(max(seat_color.r, max(seat_color.g, seat_color.b)), 0.001);
	vec3 colored = mix(vec3(value), hue * value, saturation);
	COLOR = vec4(mix(src.rgb, colored, blue), src.a) * node_tint;
}
