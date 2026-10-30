shader_type canvas_item;
uniform vec2 frame_size = vec2(1366.0,768.0);
uniform vec2 focus = vec2(683.0,320.0);
uniform float strength : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec2 offset = (UV*frame_size-focus)/vec2(1.0,0.78);
	float shade = smoothstep(62.0,174.0,length(offset));
	COLOR = vec4(0.025,0.035,0.055,shade*0.46*strength);
}
