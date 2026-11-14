shader_type canvas_item;
uniform vec2 frame_size=vec2(320.0);
varying vec2 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
	float radius=min(frame_size.x,frame_size.y)*0.105;
	vec2 q=abs(local_position-frame_size*0.5)-frame_size*0.5+vec2(radius);
	float edge=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	float aa=max(fwidth(edge),0.65);
	COLOR.a*=1.0-smoothstep(-aa,aa,edge);
}
