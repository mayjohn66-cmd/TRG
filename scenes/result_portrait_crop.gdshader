shader_type canvas_item;
// Keep the enlarged face inside its comic cut, including an inset for the ink border.
uniform vec2 cut_points[8];
uniform int cut_count = 4;
uniform vec2 image_origin;
uniform float ink_inset = 7.0;
varying vec2 cut_position;
void vertex() { cut_position = VERTEX + image_origin; }
void fragment() {
 bool inside = false;
 float nearest = 100000.0;
 for (int i = 0; i < 8; i++) {
  if (i >= cut_count) { break; }
  vec2 a = cut_points[i];
  vec2 b = cut_points[(i + 1) % cut_count];
  vec2 edge = b - a;
  vec2 closest = a + edge * clamp(dot(cut_position - a, edge) / max(dot(edge, edge), 0.001), 0.0, 1.0);
  nearest = min(nearest, distance(cut_position, closest));
  if ((a.y > cut_position.y) != (b.y > cut_position.y)) {
   float crossing = (b.x - a.x) * (cut_position.y - a.y) / (b.y - a.y) + a.x;
   if (cut_position.x < crossing) { inside = !inside; }
  }
 }
 COLOR.a *= (inside && nearest >= ink_inset) ? 1.0 : 0.0;
}
