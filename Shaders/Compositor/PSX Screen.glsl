#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D screen_image_out;
layout(set = 1, binding = 0) uniform sampler2D screen_texture;
layout(set = 1, binding = 1) uniform sampler2D dither_texture;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 color_and_dither;
} params;

const float gamma = 2.2;

vec3 toLinear(vec3 v) {
  return pow(v, vec3(gamma));
}

vec3 toGamma(vec3 v) {
  return pow(v, vec3(1.0 / gamma));
}

void main()
{
	vec2 coord = gl_GlobalInvocationID.xy;
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (coord.x >= size.x || coord.y >= size.y) {
		return;
	}
	
	vec2 offset = vec2(1.0) / params.raster_size;
	vec2 uv = (coord + vec2(0.5)) * offset;
	
	coord += vec2(0.5);
	
	vec2 down = vec2(size) / vec2(params.raster_size);
	vec2 screenUV = round(coord / down);
	
	vec4 screen = texture(screen_texture, uv);

	//Gamma correct like it's done automatically for canvas shader
	screen.rgb = toGamma(screen.rgb);
	
	vec2 dither_size = vec2(textureSize(dither_texture, 0));
	float dither = texture(dither_texture, mod(vec2(coord) / dither_size, 1)).r;
	dither -= 0.5;
	
	ivec3 c = ivec3(round(screen * 255.0));
	c += ivec3(dither * int(params.color_and_dither.y));
	
	c >>= (8 - int(params.color_and_dither.x));
	
	screen.rgb = vec3(c) / float(1 << int(params.color_and_dither.x));
	
	screen.rgb = toLinear(screen.rgb);

	imageStore(screen_image_out, ivec2(coord), screen);
}