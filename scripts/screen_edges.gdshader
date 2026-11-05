shader_type canvas_item;
render_mode unshaded;
uniform vec2 viewport_size = vec2(1440.0, 900.0);
uniform bool demolishing = false;
uniform bool paused = false;
uniform int panel_count = 0;
uniform vec4 panels[8];
void fragment() {
	vec2 distance_to_edge = min(UV, vec2(1.0) - UV) * viewport_size;
	float edge = min(distance_to_edge.x, distance_to_edge.y);
	vec2 pixel = UV * viewport_size;
	bool inside_panel = false;
	for (int i = 0; i < 8; i++) {
		if (i >= panel_count) { break; }
		vec4 rect = panels[i];
		vec2 outside = max(max(rect.xy - pixel, pixel - rect.xy - rect.zw), vec2(0.0));
		float panel_distance = length(outside);
		inside_panel = inside_panel || (panel_distance <= 0.0);
		edge = min(edge, panel_distance);
	}
	float red = demolishing ? pow(1.0 - smoothstep(0.0, 115.0, edge), 2.0) * 0.42 : 0.0;
	float cyan = paused ? pow(1.0 - smoothstep(0.0, demolishing ? 19.0 : 57.5, edge), 2.0) * 0.45 : 0.0;
	vec3 color = mix(vec3(1.0, 0.055, 0.035), vec3(0.10, 0.86, 1.0), cyan / max(0.0001, red + cyan));
	COLOR = vec4(color, inside_panel ? 0.0 : min(0.65, red + cyan));
}

