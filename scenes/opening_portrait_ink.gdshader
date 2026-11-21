shader_type canvas_item;

float luma(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 art = COLOR;
	float tone = luma(art.rgb);
	vec2 step_uv = max(TEXTURE_PIXEL_SIZE * 1.45, fwidth(UV) * 0.8);
	float horizontal = luma(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).rgb)
		- luma(texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).rgb);
	float vertical = luma(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).rgb)
		- luma(texture(TEXTURE, UV - vec2(0.0, step_uv.y)).rgb);

	// Deep flats print as solid ink. Leave faces light and shade middle tones with hatching.
	float chroma = max(max(art.r, art.g), art.b) - min(min(art.r, art.g), art.b);
	float black = 1.0 - smoothstep(0.15, 0.79, tone - chroma * 0.22);
	float edges = smoothstep(0.11, 0.39, length(vec2(horizontal, vertical)));
	vec2 texel = UV / TEXTURE_PIXEL_SIZE;
	float streak = 0.13 * sin(texel.y * 0.037) + 0.09 * sin(texel.x * 0.061);
	float stripe = abs(fract((texel.x + texel.y * 0.71) / 10.0 + streak) - 0.5);
	float hatch = 1.0 - smoothstep(0.09, 0.22, stripe);
	float second_stripe = abs(fract((texel.x - texel.y * 0.84) / 13.0) - 0.5);
	float crosshatch = 1.0 - smoothstep(0.08, 0.19, second_stripe);
	float shadow = smoothstep(0.03, 0.35, black) * (1.0 - smoothstep(0.77, 0.99, black));
	float ink = clamp(pow(black, 1.85) * 0.96 + edges * black * 0.58
		+ hatch * shadow * 0.55 + crosshatch * shadow * black * 0.28, 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.99, 0.975, 0.947), vec3(0.035, 0.025, 0.036), ink), art.a);
}
