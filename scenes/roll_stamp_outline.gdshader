shader_type canvas_item;
render_mode unshaded;

// UI pixels, independent of the much larger source artwork dimensions.
uniform vec2 draw_size = vec2(51.0);
uniform float outline_px : hint_range(0.0, 6.0) = 2.8;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float ink_grain : hint_range(0.0, 1.0) = 0.0;
varying vec2 stamp_uv;
varying vec4 stamp_tint;

void vertex() {
	vec2 padding = vec2(outline_px + 1.0);
	VERTEX += (UV * 2.0 - 1.0) * padding;
	stamp_uv = UV * (vec2(1.0) + padding * 2.0 / draw_size) - padding / draw_size;
	stamp_tint = COLOR;
}

float coverage(sampler2D source, vec2 point) {
	vec2 inside = step(vec2(0.0), point) * step(point, vec2(1.0));
	return texture(source, clamp(point, vec2(0.0), vec2(1.0))).a * inside.x * inside.y;
}

void fragment() {
	vec4 ink = texture(TEXTURE, clamp(stamp_uv, vec2(0.0), vec2(1.0)));
	ink.a = coverage(TEXTURE, stamp_uv);
	float surround = ink.a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.28318530718 / 16.0;
		vec2 direction = vec2(cos(angle), sin(angle)) * outline_px / draw_size;
		surround = max(surround, coverage(TEXTURE, stamp_uv + direction));
	}
	vec2 grain = floor(stamp_uv * 1800.0);
	float noise = fract(sin(dot(grain, vec2(12.9898, 78.233))) * 43758.5453);
	ink.a *= mix(1.0, smoothstep(0.02, 0.075, noise), ink_grain);
	float border = surround * outline_color.a;
	float alpha = ink.a + border * (1.0 - ink.a);
	vec3 rgb = (ink.rgb * ink.a + outline_color.rgb * border * (1.0 - ink.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * stamp_tint;
}
