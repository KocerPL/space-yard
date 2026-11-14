shader_type spatial;
// Glowing shell over a POI rock: a slightly larger copy of the rock, added on top, brightest at its silhouette.
// fog_disabled so the glow still shows past the fog that hides the rock itself.
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float pulse_speed = 3.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed);
	ALBEDO = color.rgb * (0.15 + rim) * pulse;
}
