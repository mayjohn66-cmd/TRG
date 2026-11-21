shader_type canvas_item;
uniform vec4 rim_color : source_color = vec4(0.0);
uniform vec4 style_adjustment = vec4(1.0, 1.0, 0.0, 0.0);
uniform bool circular_mask = true;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	float distance_from_center = length(UV - vec2(0.5));
	float edge = max(fwidth(distance_from_center), 0.0001);
	vec4 paint = texture(TEXTURE, UV);
	if (style_adjustment.w > 0.0) {
		vec2 texel = TEXTURE_PIXEL_SIZE;
		vec4 nearby = (texture(TEXTURE, UV + vec2(texel.x, 0.0))
			+ texture(TEXTURE, UV - vec2(texel.x, 0.0))
			+ texture(TEXTURE, UV + vec2(0.0, texel.y))
			+ texture(TEXTURE, UV - vec2(0.0, texel.y))) * 0.25;
		paint = mix(paint, nearby, style_adjustment.w);
		float light = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec3 tone = mix(vec3(light), paint.rgb, style_adjustment.y);
		tone = (tone - 0.5) * style_adjustment.x + 0.5;
		tone -= max(tone - 0.6, vec3(0.0)) * style_adjustment.z;
		// Keep navy medallion backgrounds dark while easing the bright subject.
		paint.rgb = mix(paint.rgb, tone, smoothstep(0.04, 0.20, light));
	}
	COLOR = paint * vertex_tint;
	float rim = smoothstep(0.5 - edge * 1.7, 0.5 - edge * 0.7, distance_from_center);
	if (circular_mask) {
		COLOR.rgb = mix(COLOR.rgb, rim_color.rgb * vertex_tint.rgb, rim * rim_color.a);
		COLOR.a *= 1.0 - smoothstep(0.5 - edge, 0.5, distance_from_center);
	}
}
