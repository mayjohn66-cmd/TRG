shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/victory_scene_tone.gdshaderinc"
uniform sampler2D screen_texture:hint_screen_texture,repeat_disable,filter_nearest;
uniform float amount:hint_range(0.0,1.0)=0.0;
uniform float caption:hint_range(0.0,1.0)=0.0;
uniform float print_scale=1.0;
uniform float backdrop_simplify:hint_range(0.0,1.0)=0.0;
void fragment(){
 // CanvasGroup gives one composite of the hills, field cards and the giant card.
 vec4 scene=textureLod(screen_texture,SCREEN_UV,0.0);
 if(scene.a>0.0001)scene.rgb/=scene.a;
 float value=dot(scene.rgb,vec3(0.299,0.587,0.114));
 vec3 ink=vec3(0.105,0.055,0.155);
 vec3 printed=floor(scene.rgb*5.0+0.5)/5.0;
 if(value<0.24)printed=ink;
 else if(value<0.46)printed=mix(printed,ink,0.16);
 vec2 cell=fract(SCREEN_UV/SCREEN_PIXEL_SIZE/(4.5*max(print_scale,0.2)))-0.5;
 float dots=(1.0-smoothstep(0.12,0.20,length(cell)))*step(0.25,value)*(1.0-step(0.78,value));
 printed=mix(printed,ink,dots*0.28*(1.0-backdrop_simplify*0.88));
 float edge=SCREEN_UV.x+sin(SCREEN_UV.y*29.0)*0.015+sin(SCREEN_UV.y*67.0)*0.008;
 float wipe=amount>=1.0?1.0:(amount<=0.0?0.0:1.0-smoothstep(amount*1.08-0.06,amount*1.08,edge));
 vec3 color=mix(scene.rgb,printed,wipe);
 // A soft caption shade overlays the intact scene; the composition never moves.
 float shade=smoothstep(0.67,0.95,SCREEN_UV.y)*(1.0-smoothstep(0.48,0.73,SCREEN_UV.x))*caption*0.87;
 color=mix(color,ink,shade);
 COLOR=vec4(victory_scene_tone(color),scene.a)*COLOR;
}
