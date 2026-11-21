shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float opacity = 0.25;

void fragment() {
	float radius = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.08, 0.14, 0.07);
	ALPHA = (1.0 - smoothstep(0.15, 0.95, radius)) * opacity;
}
