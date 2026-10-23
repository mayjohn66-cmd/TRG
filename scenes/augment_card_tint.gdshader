shader_type canvas_item;

uniform vec4 category_tint : source_color = vec4(1.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	// One neutral painted base provides all category colors, without recolor files.
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 paint = mix(vec3(1.0), category_tint.rgb, 0.70);
	COLOR = vec4(vec3(gray) * paint, base.a) * vertex_tint;
}
