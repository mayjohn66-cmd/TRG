shader_type canvas_item;
render_mode unshaded;

uniform float ink_opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool glitch_enabled = false;

void fragment() {
	// Preserve the fluorescent pigment while the profile beneath it is dimmed.
	vec4 ink = texture(TEXTURE, UV);
	float beat = mod(TIME, 2.6);
	bool burst = beat < 0.09 || (beat > 0.15 && beat < 0.23);
	if (glitch_enabled && burst) {
		float frame = floor(beat * 32.0);
		float band = floor(UV.y * 12.0);
		float signal = fract(sin(band * 21.73 + frame * 12.19) * 43758.55);
		float tear = step(0.60, signal) * (signal - 0.8) * 0.24;
		if (abs(tear) > 0.004) {
			vec2 scan = UV + vec2(tear, 0.0);
			ink = texture(TEXTURE, scan);
			float cyan = texture(TEXTURE, scan + vec2(0.024, 0.0)).a;
			float pink = texture(TEXTURE, scan - vec2(0.021, 0.0)).a;
			vec3 fringe = cyan > pink ? vec3(0.14, 0.95, 1.0) : vec3(1.0, 0.15, 0.58);
			ink.rgb = mix(fringe, ink.rgb, ink.a);
			ink.a = max(ink.a, max(cyan, pink) * 0.7);
		}
	}
	COLOR = vec4(ink.rgb, ink.a * ink_opacity);
}
