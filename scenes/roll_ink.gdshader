shader_type canvas_item;
render_mode unshaded;
void fragment() {
	// Label COLOR already contains the glyph sample and its native outline.
	vec4 ink = COLOR;
	vec2 grain = floor(UV * 1800.0);
	float noise = fract(sin(dot(grain, vec2(12.9898,78.233))) * 43758.5453);
	float colored_ink = 1.0 - step(0.95, min(ink.r, min(ink.g, ink.b)));
	ink.a *= mix(1.0, smoothstep(0.02,0.075,noise), colored_ink);
	COLOR = ink;
}
