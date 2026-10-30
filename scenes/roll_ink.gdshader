shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	vec2 grain = floor(UV * 1800.0);
	float noise = fract(sin(dot(grain, vec2(12.9898,78.233))) * 43758.5453);
	ink.a *= smoothstep(0.02,0.075,noise);
	COLOR = ink;
}

