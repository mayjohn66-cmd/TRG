shader_type canvas_item;
render_mode unshaded;

uniform float print_scale = 1.0;
varying vec2 print_position;
varying vec4 tint;

void vertex() {
	print_position = VERTEX / max(print_scale, 0.2);
	tint = COLOR;
}

void fragment() {
	float coverage = texture(TEXTURE, UV).a;
	vec2 cell = fract(print_position / 6.5) - vec2(0.5);
	float dots = 1.0 - smoothstep(0.19, 0.28, length(cell));
	vec3 plum = mix(vec3(0.31, 0.16, 0.41), vec3(0.16, 0.07, 0.25), smoothstep(0.06, 0.96, UV.y));
	vec3 ink = mix(plum, vec3(0.10, 0.04, 0.16), dots * 0.64);
	COLOR = vec4(ink, coverage) * tint;
}
