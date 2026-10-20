shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.25,0.42,0.17,1.0);
void fragment() {
    float alpha = texture(TEXTURE,UV).a;
    COLOR = vec4(ink.rgb, smoothstep(0.12,0.88,alpha)*ink.a*COLOR.a);
}
