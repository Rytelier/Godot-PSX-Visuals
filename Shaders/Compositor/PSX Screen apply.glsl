#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D screen_image_out;
layout(set = 1, binding = 0) uniform sampler2D image_in;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 resolution;
} params;

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
	
	vec4 image = texture(image_in, uv);

	imageStore(screen_image_out, ivec2(coord), image);
}