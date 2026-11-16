shader_type canvas_item;
render_mode unshaded;

// UVs belong to the icon, so layout, UI scale and hover motion cannot change
// its pixel pattern. Multi-tile structures receive sixteen cells per tile.
uniform vec2 pixel_cells = vec2(16.0);
varying vec4 icon_tint;

void vertex() {
	icon_tint = COLOR;
}

void fragment() {
	vec2 cell = clamp(floor(UV * pixel_cells), vec2(0.0), pixel_cells - vec2(1.0));
	vec2 sample_uv = (cell + vec2(0.5)) / pixel_cells;
	ivec2 dimensions = textureSize(TEXTURE, 0);
	ivec2 texel = clamp(ivec2(floor(sample_uv * vec2(dimensions) + vec2(0.001))), ivec2(0), dimensions - ivec2(1));
	vec4 sampled = texelFetch(TEXTURE, texel, 0);
	if (sampled.a < 0.5) { discard; }
	COLOR = vec4(sampled.rgb, 1.0) * icon_tint;
}
