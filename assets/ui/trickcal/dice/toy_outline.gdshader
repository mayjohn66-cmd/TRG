shader_type spatial;
render_mode unshaded, cull_front;

void vertex() {
	VERTEX += NORMAL * 0.035;
}

void fragment() {
	ALBEDO = vec3(0.059, 0.089, 0.062);
}
