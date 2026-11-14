shader_type sky;

uniform samplerCube sky_cubemap : filter_linear, source_color;
uniform float brightness : hint_range(0.0, 1.0) = 1.0;
uniform float dust : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dust_color = vec3(0.12, 0.08, 0.05);

void sky() {
	vec3 c = texture(sky_cubemap, EYEDIR).rgb;
	c = mix(c, dust_color, dust);
	COLOR = c * brightness;
}
