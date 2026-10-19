shader_type canvas_item;
render_mode unshaded;
uniform float memory_amount : hint_range(0.0, 1.0) = 1.0;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// A subpixel holographic softness, retaining a solid readable silhouette.
	vec2 offset = TEXTURE_PIXEL_SIZE * 0.8;
	vec4 nearby = texture(TEXTURE, UV + vec2(offset.x, 0.0))
		+ texture(TEXTURE, UV - vec2(offset.x, 0.0))
		+ texture(TEXTURE, UV + vec2(0.0, offset.y))
		+ texture(TEXTURE, UV - vec2(0.0, offset.y));
	vec3 soft_rgb = (pixel.rgb * pixel.a * 4.0 + nearby.rgb * nearby.a) / max(pixel.a * 4.0 + nearby.a, 0.001);
	pixel.rgb = mix(pixel.rgb, soft_rgb, 0.35 * memory_amount);
	pixel.rgb = mix(pixel.rgb, pixel.rgb * vec3(0.62, 0.90, 1.18) + vec3(0.015, 0.04, 0.08), 0.55 * memory_amount);
	// Preserve cutout holes and a narrow anti-aliased edge, not translucent buildings.
	float solid_alpha = smoothstep(0.03, 0.16, pixel.a);
	COLOR = vec4(pixel.rgb, solid_alpha * mix(1.0, 0.94, memory_amount)) * item_tint;
}
