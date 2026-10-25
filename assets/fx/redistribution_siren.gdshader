shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 edge = abs(UV-vec2(0.5))*2.0;
	float rim = smoothstep(0.60,1.10,length(edge*vec2(0.78,0.78)));
	COLOR = vec4(0.85,0.055,0.045,rim*0.62);
}
