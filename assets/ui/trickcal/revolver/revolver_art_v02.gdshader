shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform int piece = 0;
uniform float opacity = 1.0;
uniform float spin = 0.0;

bool rect(vec2 p, vec4 r) { return p.x>r.x && p.y>r.y && p.x<r.z && p.y<r.w; }
bool hammer(vec2 p) {
    // Polygon around the exposed hammer only: never cut the silver frame.
    vec2 v[7] = vec2[7](vec2(.704,.203),vec2(.747,.239),vec2(.797,.194),vec2(.816,.203),vec2(.795,.261),vec2(.765,.301),vec2(.719,.272));
    bool inside = false;
    for (int i=0,j=6;i<7;j=i++) {
        if ((v[i].y>p.y)!=(v[j].y>p.y) && p.x<(v[j].x-v[i].x)*(p.y-v[i].y)/(v[j].y-v[i].y)+v[i].x) inside=!inside;
    }
    return inside;
}
void fragment() {
    vec2 uv = UV;
    bool disk = length((UV-vec2(.3307,.4453))*vec2(1536.0,1024.0))<231.0;
    bool h = hammer(UV);
    bool t = rect(UV,vec4(.607,.507,.653,.645));
    bool c = rect(UV,vec4(.513,.219,.659,.437));
    if (piece==1 && disk) discard;
    if (piece==2 && !disk) discard;
    if (piece==3 && (h || t || c)) discard;
    if (piece==4 && !h) discard;
    if (piece==5 && !t) discard;
    if (piece==6) {
        if (!c) discard;
        // Advancing flutes along the drum circumference, not a flat disk rotation.
        float edge = smoothstep(.219,.245,UV.y)*(1.0-smoothstep(.407,.437,UV.y));
        uv.y += sin(spin*6.283185)*.027*edge;
    }
    if (piece==7 && rect(UV,vec4(.448,.211,.605,.427))) {
        float edge = smoothstep(.211,.240,UV.y)*(1.0-smoothstep(.390,.427,UV.y));
        uv.y += sin(spin*6.283185)*.027*edge;
    }
    vec4 color = texture(art,uv);
    if (color.a<.015) discard;
    ALBEDO = color.rgb;
    ALPHA = color.a*opacity;
}
