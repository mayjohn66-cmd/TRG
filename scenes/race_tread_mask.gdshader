shader_type canvas_item;
render_mode unshaded;
uniform vec4 edge_ink:source_color=vec4(0.015,0.12,0.16,1.0);
uniform vec4 source_region=vec4(0.0,0.0,1.0,1.0);
varying vec4 tint;
void vertex(){tint=COLOR;}
float mask_at(sampler2D tex,vec2 uv){
 vec2 q=(uv-source_region.xy)/source_region.zw;
 // Wide channels stay readable even when the complete strip is shown on mobile.
 float channels=max(max(1.0-smoothstep(0.022,0.032,abs(q.y-0.25)),1.0-smoothstep(0.022,0.032,abs(q.y-0.50))),1.0-smoothstep(0.022,0.032,abs(q.y-0.75)));
 float phase=fract(q.x*42.0+abs(q.y-0.5)*1.9);
 float cross_gap=1.0-smoothstep(0.12,0.16,min(phase,1.0-phase));
 return texture(tex,uv).a*(1.0-channels)*(1.0-cross_gap);
}
void fragment(){
 float core=mask_at(TEXTURE,UV);
 vec2 step_uv=TEXTURE_PIXEL_SIZE*1.8;
 float edge=max(max(mask_at(TEXTURE,UV+vec2(step_uv.x,0.0)),mask_at(TEXTURE,UV-vec2(step_uv.x,0.0))),max(mask_at(TEXTURE,UV+vec2(0.0,step_uv.y)),mask_at(TEXTURE,UV-vec2(0.0,step_uv.y))));
 float alpha=max(core,edge);
 vec3 color=mix(edge_ink.rgb,tint.rgb,core/max(alpha,0.0001));
 COLOR=vec4(color,alpha*tint.a);
}
