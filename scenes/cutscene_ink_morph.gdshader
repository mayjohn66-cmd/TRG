shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform float amount : hint_range(0.0,1.0) = 0.0;
uniform bool erase = false;
uniform bool whole_surface = false;
uniform bool quarter_turn = false;
uniform bool black_piece = false;
uniform bool paper_silhouette = false;
uniform float visible_fraction : hint_range(0.0,1.0) = 1.0;
uniform vec2 dimensions = vec2(1.0);
uniform vec4 areas[3];
varying vec2 local_uv;
varying vec4 pigment;
void vertex() { local_uv = VERTEX / max(dimensions,vec2(1.0)); pigment = COLOR; }
float printed(vec2 p) {
 if (amount <= 0.0) return 0.0;
 if (amount >= 1.0) return 1.0;
 float ink_edge = p.x + sin(p.y*29.0)*0.025 + sin(p.y*67.0)*0.012;
 return 1.0-smoothstep(amount*1.14-0.09,amount*1.14-0.03,ink_edge);
}
void fragment() {
 vec2 p = quarter_turn ? vec2(local_uv.y,1.0-local_uv.x) : local_uv;
 float coverage = printed(p);
 if (whole_surface) {
  coverage = 0.0;
  for (int i=0;i<3;i++) {
   vec2 q=(local_uv-areas[i].xy)/max(areas[i].zw,vec2(0.0001));
   if(q.x>=0.0 && q.x<=1.0 && q.y>=0.0 && q.y<=1.0) coverage=max(coverage,printed(q));
  }
 }
 vec4 source=texture(TEXTURE,UV);
 if(black_piece) {
  float value=dot(source.rgb,vec3(0.299,0.587,0.114));
  source.rgb=mix(vec3(0.012,0.016,0.025),vec3(0.24,0.27,0.32),pow(value,1.7));
 }
 if(paper_silhouette) source.rgb=vec3(0.98,0.95,0.86);
	source.rgb=victory_scene_tone(source.rgb);
 source.a*=1.0-smoothstep(visible_fraction-0.001,visible_fraction,local_uv.y);
 COLOR=source*pigment*vec4(1.0,1.0,1.0,erase ? 1.0-coverage : coverage);
 COLOR.a=victory_backdrop_alpha(COLOR.a,SCREEN_UV);
}
