shader_type canvas_item;
render_mode unshaded;

varying vec4 silhouette_color;

void vertex() {
	silhouette_color = COLOR;
}

void fragment() {
	// Preserve the pawn's actual cutout, without multiplying its original colors.
	COLOR = vec4(silhouette_color.rgb, texture(TEXTURE, UV).a * silhouette_color.a);
}
