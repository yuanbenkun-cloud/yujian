shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 0.01, 0.0001) = 0.00115;
uniform float speed : hint_range(0.0, 6.0, 0.1) = 2.2;

void fragment() {
	vec2 uv = SCREEN_UV;
	float ground_band = smoothstep(0.56, 0.66, uv.y) * (1.0 - smoothstep(0.86, 0.94, uv.y));
	float kiln_zone = 1.0 - smoothstep(0.10, 0.23, abs(uv.x - 0.31));
	float work_zone = 1.0 - smoothstep(0.09, 0.21, abs(uv.x - 0.72));
	float local_mask = ground_band * max(kiln_zone, work_zone);
	float wave_x = sin(uv.y * 118.0 + TIME * speed) + sin(uv.y * 57.0 - TIME * speed * 0.73);
	float wave_y = cos(uv.x * 71.0 + TIME * speed * 0.56);
	vec2 offset = vec2(wave_x, wave_y * 0.34) * strength * local_mask;
	COLOR = texture(screen_texture, clamp(uv + offset, vec2(0.002), vec2(0.998)));
}
