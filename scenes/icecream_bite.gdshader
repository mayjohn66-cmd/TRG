shader_type canvas_item;
render_mode unshaded;

uniform float cut = 0.0;

void fragment() {
	if (cut > 0.0) {
		// Round tooth marks expose the pink interior along the broken edge.
		float tooth = fract(UV.x * 3.0 + 0.22) * 2.0 - 1.0;
		float edge = cut + sqrt(max(0.0, 1.0 - tooth * tooth)) * 0.075;
		float remaining = UV.y - edge;
		COLOR.a *= smoothstep(0.0, 0.008, remaining);
		float exposed = (1.0 - smoothstep(0.005, 0.030, remaining));
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.74, 0.82), exposed * 0.74);
	}
}
