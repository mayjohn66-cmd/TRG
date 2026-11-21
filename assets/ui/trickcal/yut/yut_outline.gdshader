shader_type spatial;
render_mode unshaded, cull_front;
void vertex() {
	// A closed expanded hull keeps the flat/curved hard edge continuous.
	VERTEX *= vec3(1.12,1.20,1.025);
}
void fragment() {
	ALBEDO = vec3(0.059,0.089,0.062);
}
