shader_type canvas_item;
render_mode unshaded;
uniform vec2 paper_size=vec2(280.0,392.0);
uniform sampler2D paper_stock:filter_linear_mipmap,repeat_disable;
uniform vec2 card_canvas=vec2(280.0,392.0);
uniform vec2 paper_offset=vec2(0.0);
uniform float corner_radius=12.0;
uniform vec4 print_ink:source_color=vec4(0.20,0.26,0.16,1.0);
uniform float grain_strength=0.65;

void fragment() {
	vec2 pixel=UV*paper_size;
	vec2 q=abs(pixel-paper_size*0.5)-(paper_size*0.5-vec2(corner_radius));
	float edge=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-corner_radius;
	float clip=1.0-smoothstep(-0.5,0.5,edge);
	// All printed panels sample one continuous sheet; no dots or repeating grid.
	vec2 stock_uv=clamp((pixel+paper_offset)/card_canvas,vec2(0.0),vec2(1.0));
	vec3 stock=texture(paper_stock,stock_uv).rgb;
	float luminance=dot(stock,vec3(0.299,0.587,0.114));
	// Re-center the native pale stock so colored ink keeps its original hue/value.
	float relief=clamp((luminance-0.9104)*4.0,-0.55,0.55);
	float alpha=abs(relief)*grain_strength;
	vec3 color=relief>0.0?vec3(1.0):print_ink.rgb;
	COLOR=vec4(color,alpha*clip)*COLOR;
}
