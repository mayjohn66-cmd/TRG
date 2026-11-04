shader_type canvas_item;
render_mode unshaded;
#include "res://assets/fx/spotlight_floor.gdshaderinc"
uniform vec2 view_size = vec2(1366.0,768.0);
uniform vec2 spots[16];
uniform int spot_count = 0;
uniform float strength = 0.0;
uniform vec2 floor_axis_x = vec2(34.93,22.17);
uniform vec2 floor_axis_y = vec2(-34.93,22.17);

void fragment() {
	vec2 pixel = UV * view_size;
	float hole = 0.0;
	float beam = 0.0;
	float floor_light=0.0;
	float unit=max(length(floor_axis_x)/41.37,0.1);
	for(int i=0;i<16;i++){
		if(i>=spot_count){break;}
		vec2 point = spots[i];
		vec2 body = (pixel-(point+vec2(0.0,-27.0)*unit))/(vec2(32.0,50.0)*unit);
		hole=max(hole,1.0-smoothstep(0.60,1.25,length(body)));
		vec2 lamp=vec2(point.x,min(-45.0,point.y-350.0*unit));
		beam=max(beam,spotlight_cone(pixel,lamp,point,floor_axis_x,floor_axis_y));
		floor_light=max(floor_light,spotlight_pool(pixel,point,floor_axis_x,floor_axis_y));
	}
	float shade=0.76*strength*(1.0-max(max(hole,floor_light*0.76),beam*0.25));
	vec3 ink=vec3(0.018,0.022,0.038);
	ink=mix(ink,vec3(0.38,0.34,0.20),max(beam*0.30,floor_light*0.38));
	COLOR=vec4(ink,shade);
}
