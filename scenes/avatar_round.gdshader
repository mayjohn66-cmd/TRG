shader_type canvas_item;
// 정사각형 그림의 모서리를 둥글게 깎는다 (radius는 한 변 대비 비율).
uniform float radius : hint_range(0.0, 0.5) = 0.2;

void fragment() {
	vec2 q = abs(UV - vec2(0.5)) - vec2(0.5 - radius);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-0.004, 0.004, d);
}
