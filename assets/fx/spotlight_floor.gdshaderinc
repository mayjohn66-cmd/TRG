// Both overhead-light paths share this projected floor ellipse and its front edge.
vec2 spotlight_floor_uv(vec2 delta, vec2 axis_x, vec2 axis_y) {
	float determinant=axis_x.x*axis_y.y-axis_y.x*axis_x.y;
	if(abs(determinant)<0.001) return vec2(1000.0);
	return vec2(axis_y.y*delta.x-axis_y.x*delta.y,-axis_x.y*delta.x+axis_x.x*delta.y)/determinant;
}
float spotlight_pool(vec2 pixel,vec2 foot,vec2 axis_x,vec2 axis_y) {
	return 1.0-smoothstep(0.08,1.12,length(spotlight_floor_uv(pixel-foot,axis_x,axis_y)));
}
float spotlight_cone(vec2 pixel,vec2 lamp,vec2 foot,vec2 axis_x,vec2 axis_y) {
	float xx=max(axis_x.x*axis_x.x+axis_y.x*axis_y.x,1.0);
	float xy=axis_x.x*axis_x.y+axis_y.x*axis_y.y;
	float yy=axis_x.y*axis_x.y+axis_y.y*axis_y.y;
	float radius_x=sqrt(xx);
	float height=(pixel.y-lamp.y)/max(foot.y-lamp.y,1.0);
	float width=mix(4.0,radius_x,clamp(height,0.0,1.0));
	float center_x=mix(lamp.x,foot.x,height);
	float sides=1.0-smoothstep(0.52,1.0,abs(pixel.x-center_x)/max(width,1.0));
	float dx=pixel.x-foot.x;
	// Clip to the actual front arc of the ground ellipse, not a line perpendicular to the beam.
	float front_y=foot.y+xy/xx*dx+sqrt(max(yy-xy*xy/xx,0.01)*max(1.0-dx*dx/xx,0.0));
	float floor_clip=1.0-smoothstep(front_y-1.0,front_y+1.0,pixel.y);
	return sides*floor_clip*smoothstep(0.0,0.10,height);
}
