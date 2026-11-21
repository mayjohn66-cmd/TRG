shader_type canvas_item;
uniform vec4 ink : source_color = vec4(0.25,0.42,0.17,1.0);
uniform bool cutout_dark_lines = false;
void fragment() {
    vec4 decal = texture(TEXTURE, UV);
    float alpha = decal.a;
    if (cutout_dark_lines) {
        alpha *= smoothstep(0.22, 0.27, max(decal.r, max(decal.g, decal.b)));
    }
    COLOR = vec4(ink.rgb, smoothstep(0.12,0.88,alpha)*ink.a*COLOR.a);
}
