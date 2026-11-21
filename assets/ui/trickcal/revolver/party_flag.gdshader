shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float phase = 0.0;
void vertex() {
	VERTEX.z += sin(UV.x*9.0-phase*8.0)*0.045*UV.y;
}
void fragment() {
	vec3 cream = vec3(1.0,0.95,0.78);
	vec3 pink = vec3(0.94,0.62,0.75);
	vec2 p = (UV-vec2(0.5,0.50))*vec2(1.45,0.78);
	bool inside = false;
	for(int i=0;i<10;i++) {
		float a = float(i)*0.62831853-1.57079633;
		float b = float(i+1)*0.62831853-1.57079633;
		float ra = i%2==0 ? 0.23 : 0.105;
		float rb = i%2==0 ? 0.105 : 0.23;
		vec2 v = vec2(cos(a),sin(a))*ra;
		vec2 w = vec2(cos(b),sin(b))*rb;
		if ((v.y>p.y)!=(w.y>p.y)) {
			if(p.x<(w.x-v.x)*(p.y-v.y)/(w.y-v.y)+v.x) { inside = !inside; }
		}
	}
	float edge = min(min(UV.x,1.0-UV.x)*1.45,min(UV.y,1.0-UV.y)*0.78);
	ALBEDO = (inside || edge<0.035) ? cream : pink;
}
