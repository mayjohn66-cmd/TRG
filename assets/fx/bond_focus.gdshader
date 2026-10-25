shader_type canvas_item;
uniform vec2 frame_size = vec2(1366.0,768.0);
uniform vec2 first = vec2(400.0,400.0);
uniform vec2 second = vec2(900.0,400.0);
uniform float strength : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec2 p = UV*frame_size;
	vec2 delta = second-first;
	float along = clamp(dot(p-first,delta)/max(dot(delta,delta),1.0),0.0,1.0);
	float corridor = smoothstep(28.0,95.0,length(p-mix(first,second,along)));
	float ends = smoothstep(40.0,145.0,min(length(p-first),length(p-second)));
	COLOR = vec4(0.035,0.018,0.035,min(corridor,ends)*strength*0.38);
}
