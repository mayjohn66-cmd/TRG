shader_type canvas_item;
render_mode unshaded;
uniform float flow_time=0.0;
uniform float strength=1.0;
uniform float impact=0.0;
void fragment() {
	vec2 q=UV*2.0-1.0;
	float r=length(q);
	float angle=atan(q.y,q.x);
	r*=1.0+sin(angle*5.0+flow_time*0.4)*0.035+sin(angle*9.0-flow_time*0.7)*0.020;
	// Diffuse uneven spill, without readable concentric ring geometry.
	float spill=0.78+sin(angle*7.0+flow_time*1.3+r*13.0)*0.12+sin(angle*13.0-flow_time*2.0-r*9.0)*0.10;
	float core=exp(-r*r*5.5);
	float bloom=exp(-r*r*3.7);
	float fringe=exp(-r*r*3.0)*spill*0.14;
	float flash=exp(-r*r*2.4)*impact;
	float alpha=clamp(bloom*0.65*spill+core*0.65+fringe+flash*0.40,0.0,0.98)*strength;
	alpha*=1.0-smoothstep(0.75,1.0,r);
	vec3 color=mix(vec3(0.75,0.34,1.0),vec3(0.48,0.88,1.0),clamp(spill*0.65+r*0.25,0.0,1.0));
	color=mix(color,vec3(1.0,0.98,1.0),clamp(core*1.35+flash*0.50,0.0,1.0));
	COLOR=vec4(color,alpha)*COLOR;
}
