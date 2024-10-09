shader_type canvas_item;

/** Color depth per channel. 15 bit (5) is the default, most common one. */
uniform int color_depth : hint_range(1, 8) = 5;
/** 4 is the accurate value. */
uniform int dither_strength : hint_range(0, 8, 1) = 4;
/** Bayer matrix texture is the one used on real hardware. */
uniform sampler2D dither_texture : filter_nearest;

uniform sampler2D screen_texture : hint_screen_texture;

global uniform ivec2 resolution;

void fragment() {
	ivec2 size = textureSize(screen_texture, 0);
	vec2 down = vec2(size)/vec2(resolution);
	vec2 screenUV = round(FRAGCOORD.xy / down);
	ivec2 uv = ivec2(screenUV * down);

	vec3 color = texelFetch(screen_texture, uv, 0).rgb;

	ivec3 c = ivec3(round(color * 255.0));

	vec2 dither_size = vec2(textureSize(dither_texture, 0));
	float dither = texture(dither_texture, mod((vec2(uv) / down) / dither_size, 1)).r;
	dither -= 0.5;

	c += ivec3(vec3(dither * float(dither_strength * 2)));

	c >>= (8 - color_depth);

	COLOR.rgb = vec3(c) / float(1 << color_depth);
}
