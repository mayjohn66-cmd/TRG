shader_type canvas_item;
render_mode unshaded;
uniform vec2 view_size=vec2(1366.0,768.0);
uniform vec2 bulb=vec2(683.0,335.0);
uniform float charge=0.0;
uniform float pulse=0.0;
uniform float afterglow=0.0;
uniform float buildup=0.0;
void fragment() {
	float unit=min(view_size.x/1366.0,view_size.y/768.0);
	vec2 delta=UV*view_size-bulb;
	float radius=(32.0+42.0*buildup+145.0*pulse+90.0*afterglow)*unit;
	float halo=exp(-dot(delta,delta)/max(radius*radius,1.0)*2.0);
	float core=exp(-dot(delta,delta)/max(11.0*11.0*unit*unit,1.0)*2.0);
	float wash=pulse*0.80+afterglow*0.035;
	float alpha=clamp(wash+halo*(charge*0.48+pulse*0.70+afterglow*0.24)+core*charge*0.76,0.0,0.98);
	vec3 light=mix(vec3(0.68,0.86,1.0),vec3(0.98,0.99,1.0),clamp(pulse*0.90+core,0.0,1.0));
	COLOR=vec4(light,alpha)*COLOR;
}
