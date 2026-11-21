shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float lightness = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(vec3(0.54, 0.52, 0.62), vec3(0.87, 0.86, 0.92), lightness);
	COLOR = vec4(muted, source.a) * vertex_tint;
}
