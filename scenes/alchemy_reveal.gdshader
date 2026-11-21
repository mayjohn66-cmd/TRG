shader_type canvas_item;
render_mode unshaded;
uniform float completion : hint_range(0.0, 1.0) = 0.0;
uniform float closure : hint_range(0.0, 1.0) = 0.0;
varying vec4 pigment;
void vertex() { pigment = COLOR; }
void fragment() {
 vec4 tex = texture(TEXTURE, UV);
 float turn = fract((atan(UV.y - 0.5, UV.x - 0.5) + 1.57079633) / 6.28318531 + 1.0);
 float visible = completion >= 0.999 ? 1.0 : 1.0 - smoothstep(completion - 0.012, completion, turn);
 COLOR = vec4(mix(tex.rgb, vec3(1.0, 0.97, 0.76), closure * 0.65), tex.a * visible) * pigment;
}
