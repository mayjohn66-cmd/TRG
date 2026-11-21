shader_type canvas_item;
render_mode unshaded;
uniform float amount:hint_range(0.0,1.0)=0.0;
uniform bool native_surface=false;
uniform float backdrop_simplify:hint_range(0.0,1.0)=0.0;
uniform bool focal_card=false;
uniform float ground_offset=0.28;
uniform float ground_slope=0.0;
uniform float card_angle=0.0;
uniform vec2 dimensions=vec2(1.0);
varying vec2 local_uv;
varying vec4 pigment;
void vertex(){local_uv=VERTEX/max(dimensions,vec2(1.0));pigment=COLOR;}
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 float value=dot(source.rgb,vec3(0.299,0.587,0.114));
 vec3 ink=vec3(0.12,0.045,0.22);
 vec3 paint=value<0.22?ink:(value<0.52?vec3(0.65,0.075,0.40):(value<0.83?vec3(0.97,0.25,0.60):vec3(1.0,0.95,0.79)));
 if(source.r>0.65&&source.g>0.43&&source.b<0.43)paint=vec3(1.0,0.76,0.16);
 if(source.r<0.42&&source.g>0.48&&source.b>0.55)paint=vec3(0.20,0.81,0.89);
 vec2 cell=fract(local_uv*dimensions/4.0)-0.5;
 float dots=(1.0-smoothstep(0.10,0.18,length(cell)))*step(0.25,value)*(1.0-step(0.65,value));
 paint=mix(paint,ink,dots*0.44);
 float edge=local_uv.x+sin(local_uv.y*29.0)*0.025+sin(local_uv.y*67.0)*0.012;
 float coverage=amount>=1.0?1.0:(amount<=0.0?0.0:1.0-smoothstep(amount*1.14-0.09,amount*1.14-0.03,edge));
 vec2 point=(local_uv-0.5)*dimensions;
 vec2 rotated=vec2(point.x*cos(card_angle)-point.y*sin(card_angle),point.x*sin(card_angle)+point.y*cos(card_angle));
 float distance_to_ground=(rotated.y-ground_slope*rotated.x)/max(dimensions.y,1.0);
 float clipped=1.0-smoothstep(ground_offset-0.001,ground_offset,distance_to_ground);
 // Once the frozen scene recedes, collapse ornamental frames into one ink face.
 // Preserve the source lock silhouette and card edge rather than replacing the art.
 vec3 quiet_ink=vec3(0.16,0.085,0.22);
 vec3 quiet_edge=vec3(0.36,0.25,0.39);
 vec3 quiet=source.r>0.80&&source.g>0.78&&source.b>0.62?quiet_edge:quiet_ink;
 bool lock_area=local_uv.x>0.21&&local_uv.x<0.79&&local_uv.y>0.17&&local_uv.y<0.70;
 bool gold=source.r>0.65&&source.g>0.43&&source.b<0.43;
 if(lock_area&&gold)quiet=focal_card?vec3(0.89,0.76,0.51):vec3(0.49,0.37,0.46);
 if(lock_area&&value>0.85)quiet=focal_card?vec3(0.73,0.64,0.64):quiet_edge;
 // The central card keeps a restrained frame and the lock's original gold shading.
 // Surrounding cards remain flat silhouettes; the introduction is still untouched.
 if(focal_card)quiet=mix(quiet,source.rgb,0.42);
 vec3 surface=native_surface?source.rgb:paint;
 surface=mix(surface,quiet,backdrop_simplify);
 COLOR=vec4(surface,source.a*(native_surface?1.0-coverage:coverage)*clipped)*pigment;
}
