vec4 buff_ink(vec2 pixel,float clock,int effects,vec4 fallback) {
	float heat=0.5+0.5*sin(pixel.x*0.16+pixel.y*0.10-clock*7.0+sin(pixel.x*0.075+clock*4.0)*2.0);
	vec3 fire=mix(vec3(0.63,0.015,0.025),vec3(1.0,0.19,0.045),0.22+heat*0.78);
	fire=mix(fire,vec3(1.0,0.67,0.25),pow(heat,9.0)*0.65);
	float wave=0.5+0.5*sin(pixel.x*0.033+pixel.y*0.047-clock*2.5+sin(pixel.x*0.012-clock)*1.5);
	vec3 devil=mix(vec3(0.54,0.08,0.91),vec3(0.95,0.025,0.17),wave);
	devil*=0.86+0.14*sin(pixel.x*0.08+pixel.y*0.04-clock*3.6);
	vec3 result=fallback.rgb;
	bool flame=(effects&1)!=0;
	bool contract=(effects&2)!=0;
	bool volt=(effects&4)!=0;
	if(flame) {result=fire;}
	if(contract) {
		float blend=flame ? smoothstep(0.35,0.65,0.5+0.5*sin((pixel.x+pixel.y)*0.021-clock*0.6)) : 1.0;
		result=mix(result,devil,blend);
	}
	if(volt) {
		float drift=0.5+0.5*sin(pixel.x*0.027+pixel.y*0.036-clock*1.6);
		vec3 electric=mix(vec3(0.10,0.36,0.81),vec3(0.24,0.65,1.0),drift);
		float blend=(flame||contract) ? 0.30*(0.5+0.5*sin((pixel.x+pixel.y)*0.035+clock)) : 1.0;
		result=mix(result,electric,blend);
	}
	return vec4(result,fallback.a);
}
