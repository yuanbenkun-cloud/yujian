shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 blue = mix(scene * vec3(0.52, 0.83, 1.18), vec3(0.08, 0.40, 0.76) * luminance, 0.28);
	blue += vec3(0.012, 0.045, 0.10);
	// Low contrast scanning, never a full-screen brightness flash.
	float line = 0.5 + 0.5 * sin(SCREEN_UV.y * 360.0 * 3.14159);
	blue *= 0.96 + 0.04 * line;
	float sweep = 1.0 - smoothstep(0.0, 0.055, abs(SCREEN_UV.y - fract(TIME * 0.065)));
	blue += vec3(0.01, 0.045, 0.065) * sweep;
	// Sparse 3x5 data glyphs in small changing packets, not a solid blue veil.
	vec2 grid = SCREEN_UV * vec2(106.0, 45.0);
	vec2 cell = floor(grid);
	vec2 pixel = floor(fract(grid) * vec2(4.0, 7.0));
	float tick = floor(TIME * 2.0);
	float packet = step(0.86, hash(vec2(floor(cell.x / 7.0), cell.y + tick)));
	float glyph = step(0.43, hash(cell + pixel * 17.0 + tick));
	glyph *= (1.0 - step(3.0, pixel.x)) * (1.0 - step(5.0, pixel.y));
	// Protect the main play lane; packets remain visible around its edges.
	float lane = mix(1.0, 0.22, step(0.43, SCREEN_UV.y) * (1.0 - step(0.88, SCREEN_UV.y)));
	blue = mix(blue, vec3(0.15, 0.65, 1.0), packet * glyph * lane * 0.50);
	COLOR = vec4(mix(scene, blue, strength), 1.0);
}
