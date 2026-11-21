shader_type canvas_item;
render_mode unshaded;
varying vec4 bolt_color;

void vertex() {
	bolt_color = COLOR;
}

void fragment() {
	vec4 filament = texture(TEXTURE, UV);
	float heat = smoothstep(0.78, 0.99, filament.a);
	vec3 light = mix(bolt_color.rgb, vec3(1.0, 0.95, 0.90), heat * 0.9);
	COLOR = vec4(light * filament.r, filament.a * bolt_color.a);
}
