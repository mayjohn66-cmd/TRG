shader_type canvas_item;
render_mode unshaded;

// Radius in original image pixels; foreground controls are separate canvas items.
uniform float blur_radius_px : hint_range(0.0, 6.0, 0.1) = 2.0;

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_radius_px;
	vec2 edge = TEXTURE_PIXEL_SIZE * 0.5;
	vec4 blurred = texture(TEXTURE, clamp(UV, edge, vec2(1.0)-edge)) * 4.0;
	blurred += texture(TEXTURE, clamp(UV + vec2(step_uv.x,0.0), edge, vec2(1.0)-edge)) * 2.0;
	blurred += texture(TEXTURE, clamp(UV - vec2(step_uv.x,0.0), edge, vec2(1.0)-edge)) * 2.0;
	blurred += texture(TEXTURE, clamp(UV + vec2(0.0,step_uv.y), edge, vec2(1.0)-edge)) * 2.0;
	blurred += texture(TEXTURE, clamp(UV - vec2(0.0,step_uv.y), edge, vec2(1.0)-edge)) * 2.0;
	blurred += texture(TEXTURE, clamp(UV + step_uv, edge, vec2(1.0)-edge)) * 1.0;
	blurred += texture(TEXTURE, clamp(UV - step_uv, edge, vec2(1.0)-edge)) * 1.0;
	blurred += texture(TEXTURE, clamp(UV + vec2(step_uv.x,-step_uv.y), edge, vec2(1.0)-edge)) * 1.0;
	blurred += texture(TEXTURE, clamp(UV + vec2(-step_uv.x,step_uv.y), edge, vec2(1.0)-edge)) * 1.0;
	COLOR = blurred / 16.0;
}
