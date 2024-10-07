# PSX style shader pack for Godot

Shader pack provides PSX style shaders emulating hardware's liminations.

# Features
- Vertex snapping
- Affine texture warp
- Fake adaptive subdivision effect
- Triangle based depth sorting
- Distance triangle culling
- Close triangle pushback
- Per vertex colored/black fog
- 4 blending modes: half, add, subtract, add quarter
- Flipbook and pan animation

# Usage
Required Godot version: 4.4 (previous versions have no vertex lighting implemented)
Global shader parameters are required to work. You can add them in `Project settings -> Globals -> Shader globals`.
```
float snap
ivec2 resolution
vec2 fog_range
color fog_color
bool fog_black
float cull_dist
```
Fog from `environment` will not work, as it uses hardware accurate per vertex implementation that allows additive color or black fog.
You can enable per pixel fog by removing `fog_disabled` and add #define NO_FOG in the gdshaderinc file.

Additionally to provided shader files, you can create your own combinations.
What you need to do is to create shader file and add '#include "res://Shaders/PSX Surface general.gdshaderinc"' under 'shader_type spatial;'. Add features with #define keywords.
Check the `gdshaderinc` file for available features.

Example (additive material with flipbook texture animation):
```
shader_type spatial;
#define BLEND_ADD
#define UV_FLIPBOOK

#include "res://Shaders/PSX Surface general.gdshaderinc"
```

You can modify the `PSX Surface general.gdshaderinc` file to add your own features.

# Todo:
- Vertex color affine warp
- Screen downscale shader with color limiting and dithering
- More material features