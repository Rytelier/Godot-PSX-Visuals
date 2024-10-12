//PSX surface BASE
//Use #include "res://Shaders/PSX Surface general.gdshaderinc" in your shader
//Use #define to enable features

//Available blend mode defines: BLEND_HALF, BLEND_ADD, BLEND_SUB, BLEND_ADD_QUARTER, UNSHADED
//Available UV animation defines: UV_PAN, UV_FLIPBOOK
//Available various defines: NO_FOG, NO_CULL, NO_TRIANGLE_SORT, NO_AFFINE, NO_SNAP, TEX_COLOR_LINEAR

render_mode diffuse_lambert_wrap, vertex_lighting, fog_disabled
#if defined(BLEND_ADD) || defined(BLEND_ADD_QUARTER)
, blend_add
#elif defined BLEND_SUB
, blend_sub
#endif
#ifdef UNSHADED
, unshaded
#endif
#ifdef DOUBLE_SIDED
, cull_disabled
#endif
;

//Global features here
#define FAKE_SUBD_DIST 5.0
#define AFFINE_STRENGTH 2.0
#define PUSHBACK_DIST 0.4

#ifdef TEX_COLOR_LINEAR
uniform sampler2D albedo: hint_default_white, filter_nearest;
uniform sampler2D emission: hint_default_white, filter_nearest;
#else
uniform sampler2D albedo: source_color, hint_default_white, filter_nearest;
uniform sampler2D emission: source_color, hint_default_white, filter_nearest;
#endif

uniform vec4 emissionTint : source_color = vec4(0,0,0,0);
uniform vec4 albedoTint : source_color = vec4(1,1,1,1);

uniform float alpha_scissor: hint_range(0.0, 1.0) = 1.0;

#ifdef UV_PAN
uniform vec2 uv_pan;
#endif

#ifdef UV_FLIPBOOK
uniform ivec2 uv_flipbook_frames;
uniform float uv_flipbook_speed;
#endif

global uniform float snap;
global uniform ivec2 resolution;
global uniform vec2 fog_range;
global uniform vec4 fog_color;
global uniform bool fog_black;
global uniform float cull_dist;

varying vec2 warpUV;
varying vec3 warpColor;
varying flat float dist;
varying float fog;
varying flat float sort;

vec4 snap_to_position(vec4 base_position)
{
	vec4 snapped_position = base_position;
	snapped_position.xyz = base_position.xyz / base_position.w;

	vec2 snap_resulotion = floor(vec2(resolution) * (1.0 - snap));
	snapped_position.x = floor(snap_resulotion.x * snapped_position.x) / snap_resulotion.x;
	snapped_position.y = floor(snap_resulotion.y * snapped_position.y) / snap_resulotion.y;

	snapped_position.xyz *= base_position.w;
	return snapped_position;
}

void vertex() {
	vec4 vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));

	//Vertex snapping
	#ifndef NO_SNAP
	vec4 snapped_position = snap_to_position(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION = snapped_position;
	#else
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	#endif

	dist = POSITION.w;
	if (dist < PUSHBACK_DIST && dist > -PUSHBACK_DIST) POSITION.w = PUSHBACK_DIST;

	//Distance cull
	#ifndef NO_CULL
	if (dist > cull_dist) POSITION.z = -100.;
	#endif

	//UV pan animation
	#ifdef UV_PAN
	UV += vec2(TIME * uv_pan);
	#endif

	//Affine UV warp
	#ifndef NO_AFFINE
	warpUV = UV * (1. + vertex.z * -AFFINE_STRENGTH);
	warpColor = COLOR.rgb * (1. + vertex.z * -AFFINE_STRENGTH);
	#endif

	//Fog
	#ifndef NO_FOG
	fog = clamp((dist - fog_range.x) / fog_range.y, 0, 1);
	#endif
}

void fragment() {
	vec2 uv = UV;
	vec3 color = COLOR.rgb;

	#ifdef UV_FLIPBOOK
	vec2 tile = vec2(1) / vec2(uv_flipbook_frames);
	uv *= tile;
	float time = fract(TIME * uv_flipbook_speed);
	float tx = floor(float(uv_flipbook_frames.x * uv_flipbook_frames.y) * time) / float(uv_flipbook_frames.y);
	float ty = floor(float(uv_flipbook_frames.y) * time) / float(uv_flipbook_frames.x);
	uv += vec2(tx, ty);
	#endif

	#ifndef NO_AFFINE
	if (dist > FAKE_SUBD_DIST)
	{
		uv = warpUV;
		uv /= 1. + VERTEX.z * -AFFINE_STRENGTH;

		#ifdef UV_FLIPBOOK
		uv *= tile;
		uv += vec2(tx, ty);
		#endif

		color = warpColor;
		color /= 1. + VERTEX.z * -AFFINE_STRENGTH;
	}
	#endif

	#ifndef NO_TRIANGLE_SORT
	DEPTH = FRAGCOORD.w / abs(dist);
	#endif

	ALBEDO = texture(albedo, uv).rgb * albedoTint.rgb * color.rgb;
	#ifdef BLEND_HALF
	ALPHA = 0.5;
	#elif defined BLEND_ADD_QUARTER
	ALPHA = 0.25;
	#else
	ALPHA = texture(albedo, uv).a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	#endif
	EMISSION = texture(emission, uv).rgb * emissionTint.rgb * color.rgb;
	SPECULAR = 0.;
	#ifndef NO_FOG
	if (!fog_black)
	{
		#ifdef UNSHADED
		ALBEDO += vec3(1.) * fog * fog_color.rgb;
		#else
		ALBEDO *= mix(vec3(1), vec3(0), fog);
		EMISSION += vec3(1.) * fog * fog_color.rgb;
		#endif
	}
	else
		ALBEDO *= mix(vec3(1), vec3(0), fog);
	#endif
}