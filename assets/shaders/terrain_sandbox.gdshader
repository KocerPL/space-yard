shader_type sky;

uniform samplerCube sky_cubemap : filter_linear, source_color;

void sky() {
	COLOR = texture(sky_cubemap, EYEDIR).rgb;
}
