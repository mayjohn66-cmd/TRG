shader_type canvas_item;
render_mode unshaded;
uniform float age = 0.0;
uniform float travel_time = 0.07;
uniform float distance_px = 400.0;

void fragment() {
	float x = UV.x * distance_px;
	float head = min(age / travel_time, 1.0) * distance_px;
	float behind = head - x;
	float tail = min(distance_px * 0.28, 105.0);
	float along = smoothstep(-2.0, 4.0, behind) * exp(-max(behind, 0.0) / (tail * 0.32));
	along *= 1.0 - smoothstep(tail * 0.65, tail, behind);
	float taper = clamp(1.0 - behind / tail, 0.0, 1.0);
	float bend = sin(x * 0.10 + age * 65.0) * (1.0 - taper) * 0.65;
	float y = (UV.y - 0.5) * 24.0 - bend;
	float hot = exp(-y * y / (0.24 + taper * 0.70));
	float haze = exp(-y * y / (3.0 + taper * 10.0)) * 0.18;
	float flicker = 0.72 + 0.28 * sin(x * 0.31 + age * 43.0);
	float fade = 1.0 - smoothstep(travel_time, travel_time + 0.045, age);
	vec3 color = mix(vec3(1.0, 0.57, 0.16), vec3(1.0, 0.97, 0.78), hot);
	COLOR = vec4(color, (hot + haze) * along * flicker * fade);
}
