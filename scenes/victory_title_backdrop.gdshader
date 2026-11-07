shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 d=(UV-vec2(0.5))*2.0;
	float falloff=pow(clamp(1.0-dot(d,d),0.0,1.0),1.4);
	COLOR=vec4(0.025,0.015,0.04,falloff*0.32);
}
