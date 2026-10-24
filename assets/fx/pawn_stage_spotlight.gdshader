shader_type canvas_item;
render_mode unshaded;

uniform vec2 frame_size = vec2(1366.0,768.0);
uniform vec2 foot = vec2(683.0,380.0);
uniform vec2 source = vec2(548.0,-45.0);
uniform vec4 light_tint : source_color = vec4(1.0,0.97,0.75,1.0);

void fragment() {
	vec2 pixel = UV*frame_size;
	vec2 axis = foot-source;
	float beam_length = max(length(axis),1.0);
	vec2 direction = axis/beam_length;
	vec2 from_lamp = pixel-source;
	float along = dot(from_lamp,direction)/beam_length;
	float side = abs(dot(from_lamp,vec2(-direction.y,direction.x)));
	float span = mix(5.0,46.0,pow(clamp(along,0.0,1.0),1.2));
	float cone = (1.0-smoothstep(span*0.42,span,side));
	cone *= smoothstep(-0.02,0.12,along)*(1.0-smoothstep(0.96,1.04,along));
	// The selected pawn is above the dimmer. Only a flattened floor pool is lit.
	vec2 floor_uv = (pixel-foot)/vec2(48.0,16.0);
	float pool = exp(-dot(floor_uv,floor_uv)*2.0);
	float dim = 0.64*(1.0-pool*0.55);
	float glow = clamp(cone*mix(0.10,0.28,clamp(along,0.0,1.0))+pool*0.16,0.0,0.40);
	float alpha = dim+glow*(1.0-dim);
	vec3 colour = (vec3(0.025,0.019,0.04)*dim*(1.0-glow)+light_tint.rgb*glow)/max(alpha,0.001);
	COLOR = vec4(colour,alpha)*COLOR;
}
