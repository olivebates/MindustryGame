shader_type canvas_item;
render_mode unshaded, world_vertex_coords;
// Sixteen cells per 32-world-unit tile, independent of camera zoom/position.
uniform float world_pixel_size : hint_range(0.5, 8.0) = 2.0;
varying vec4 sprite_tint;
varying vec2 world_position;
void vertex() {
	// Translate the entire sprite by one offset; retain all corner distances.
	vec2 origin = MODEL_MATRIX[3].xy;
	VERTEX += round(origin / world_pixel_size) * world_pixel_size - origin;
	world_position = VERTEX;
	sprite_tint = COLOR;
}
void fragment() {
	vec2 center = (floor(world_position / world_pixel_size) + vec2(0.5)) * world_pixel_size;
	vec2 delta = inverse(mat2(dFdx(world_position), dFdy(world_position))) * (center - world_position);
	vec2 sample_uv = UV + dFdx(UV) * delta.x + dFdy(UV) * delta.y;
	// Fetch an exact base-level texel: filtering and mipmaps must never
	// introduce blended transition colors, including during camera zooms.
	ivec2 dimensions = textureSize(TEXTURE, 0);
	// Interpolation on the quad's two triangles can put an exact texel boundary
	// a few ulps on either side of an integer. Resolve those ties consistently
	// before floor, otherwise identical sprites select different palette colors.
	vec2 texel_position = sample_uv * vec2(dimensions);
	vec2 nearest_boundary = round(texel_position);
	texel_position = mix(texel_position, nearest_boundary,
		lessThan(abs(texel_position - nearest_boundary), vec2(0.001)));
	ivec2 texel = clamp(ivec2(floor(texel_position)), ivec2(0), dimensions - ivec2(1));
	vec4 sample_color = texelFetch(TEXTURE, texel, 0);
	if (sample_color.a < 0.5) { discard; }
	COLOR = vec4(sample_color.rgb * sprite_tint.rgb, sprite_tint.a);
}
