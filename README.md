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
- Screen downscale with color reduction and dithering

![Example screenshot](Example.png)

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

## Material
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

## Screen
Screen shader for downscaling with color reduction and dithering.
Resolution is defined in `Shader globals`.

For forward+ renderer, use compositor effect - it can be created in `WorldEnvironment` node, in `Compositor` resource, add `PSX_Screen` to the effects array.
Note: if you want to change resolution in game, you should change it both in shader globals AND the compositor effect.

For compatilibity renderer use the shader from `Shaders/Canvas` on `ColorRect` covering whole screen.

## PSX Manager
There's a node script `PSX_Manager` which allows you to set fog settings per scene and easily edit screen shader parameters as well.
The node should be added to every unique scene.
When added to scene, it will add corresponding editor settings for path to compositor effect/canvas material and will warn you about missing shader globals.

Both GDscript and C# versions are provided, use only one of them.

# Todo:
- More material features