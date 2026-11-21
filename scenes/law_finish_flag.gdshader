shader_type canvas_item;
render_mode unshaded;
uniform float motion = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float free_end = smoothstep(0.18, 1.0, UV.x);
	// Keep the pole still; warp the continuous painted fabric, not checker cells.
	vec2 cloth = UV;
	cloth.y += sin(UV.x * 6.5 - motion * 4.2) * 0.012 * free_end;
	cloth.x += sin(UV.x * 4.0 - motion * 4.2) * 0.003 * free_end;
	COLOR = texture(TEXTURE, cloth) * tint;
}
