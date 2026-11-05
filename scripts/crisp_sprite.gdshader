shader_type canvas_item;
render_mode unshaded, world_vertex_coords;
// Sixteen samples across a reference 32-pixel tile; assets retain 64px detail.
uniform float screen_pixel_size : hint_range(1.0, 4.0) = 2.0;
varying vec4 sprite_tint;
void vertex() {
	// Raster images retain their native sampling; only untextured drawing is snapped.
	if (TEXTURE_PIXEL_SIZE.x >= 0.5 && TEXTURE_PIXEL_SIZE.y >= 0.5) {
		vec2 screen_position = (CANVAS_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		VERTEX = (inverse(CANVAS_MATRIX) * vec4(round(screen_position / screen_pixel_size) * screen_pixel_size, 0.0, 1.0)).xy;
	}
	sprite_tint = COLOR;
}
void fragment() {
	if (TEXTURE_PIXEL_SIZE.x < 0.5 || TEXTURE_PIXEL_SIZE.y < 0.5) {
		COLOR = texture(TEXTURE, UV) * sprite_tint;
	} else {
	vec2 center = (floor(FRAGCOORD.xy / screen_pixel_size) + vec2(0.5)) * screen_pixel_size;
	vec2 delta = center - FRAGCOORD.xy;
	vec2 sample_uv = UV + dFdx(UV) * delta.x + dFdy(UV) * delta.y;
	vec2 pixel_uv = (floor(sample_uv / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec4 sample_color = texture(TEXTURE, pixel_uv);
	if (sample_color.a < 0.5) { discard; }
	COLOR = vec4(sample_color.rgb * sprite_tint.rgb, sprite_tint.a);
	}
}
