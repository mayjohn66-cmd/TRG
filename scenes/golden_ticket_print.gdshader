shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform vec2 dimensions=vec2(1.0);
uniform float gilded:hint_range(0.0,1.0)=0.0;
uniform float shine:hint_range(0.0,1.0)=0.0;
uniform float reveal:hint_range(0.0,1.0)=0.0;
uniform float print_amount:hint_range(0.0,1.0)=0.0;
uniform int piece_id=-1;
uniform float sealing:hint_range(0.0,1.0)=0.0;
varying vec2 local_uv;
varying vec4 pigment;
void vertex(){local_uv=VERTEX/max(dimensions,vec2(1.0));pigment=COLOR;}
float band(float progress,vec2 p){
 float edge=progress*1.5-0.25;
 return (1.0-smoothstep(0.02,0.16,abs(p.x+p.y*0.20-edge)))*step(0.001,progress)*(1.0-step(0.999,progress));
}
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 float coverage=1.0;
 float torn_edge=0.0;
 if(piece_id>=0){
  // Adjacent fragments share exactly the same ragged boundaries.
  float a=0.333333+sin(local_uv.y*37.0)*0.014+sin(local_uv.y*79.0)*0.006;
  float b=0.666667+sin(local_uv.y*41.0+1.0)*0.014+sin(local_uv.y*83.0)*0.006;
  float middle=0.50+sin(local_uv.x*43.0)*0.025+sin(local_uv.x*91.0)*0.008;
  int column=piece_id%3;
  bool lower=piece_id>=3;
  float left=column==0?-0.01:(column==1?a:b);
  float right=column==0?a:(column==1?b:1.01);
  coverage=step(left,local_uv.x)*(1.0-step(right,local_uv.x));
  coverage*=lower?step(middle,local_uv.y):1.0-step(middle,local_uv.y);
  float distance_to_tear=min(abs(local_uv.y-middle),min(abs(local_uv.x-left),abs(local_uv.x-right)));
  torn_edge=(1.0-smoothstep(0.0015,0.005,distance_to_tear))*(1.0-sealing);
 }
 float value=dot(tex.rgb,vec3(0.299,0.587,0.114));
 float gold_mask=smoothstep(0.20,0.53,value);
 vec3 worn=mix(vec3(0.20,0.105,0.055),vec3(0.68,0.48,0.26),value);
 vec3 foil=mix(worn,tex.rgb,gilded);
 float gleam=max(band(shine,local_uv)*0.30,band(reveal,local_uv)*0.44)*gold_mask;
 foil=mix(foil,vec3(1.0,0.97,0.69),gleam*(1.0-print_amount));
 // The same torn silhouette becomes a limited-ink comic illustration, never swaps pose.
 vec3 print_color=value<0.25?vec3(0.19,0.095,0.035):(value<0.55?vec3(0.72,0.37,0.055):(value<0.82?vec3(0.97,0.70,0.16):vec3(1.0,0.91,0.57)));
 vec2 dots=fract(local_uv*dimensions/3.0)-0.5;
 float halftone=(1.0-smoothstep(0.105,0.16,length(dots)))*gold_mask*step(0.50,value)*(1.0-step(0.85,value));
 print_color=mix(print_color,vec3(0.40,0.19,0.025),halftone*0.40);
 float edge=local_uv.x+local_uv.y*0.12;
 float ink=print_amount>=1.0?1.0:(print_amount<=0.0?0.0:1.0-smoothstep(print_amount*1.25-0.08,print_amount*1.25,edge));
 vec3 color=mix(mix(foil,print_color,ink),vec3(1.0,0.91,0.65),torn_edge*0.70);
 COLOR=vec4(victory_scene_tone(color),tex.a*coverage)*pigment;
 COLOR.a=victory_backdrop_alpha(COLOR.a,SCREEN_UV);
}
