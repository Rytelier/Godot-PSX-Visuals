@tool
extends CompositorEffect
class_name PSX_Screen

var rd : RenderingDevice
var shader : RID
var pipeline : RID
var shader_apply : RID
var pipeline_apply : RID

var mutex : Mutex = Mutex.new()
var shader_is_dirty : bool = true

var sampler_state
var linear_sampler
var nearest_sampler

var shader_path = "res://Shaders/Compositor/PSX Screen.glsl"
var shader_apply_path = "res://Shaders/Compositor/PSX Screen apply.glsl"
var dither_path = "res://Shaders/Bayer matrix.png"

var last_modified

@export var dither : Texture2D
@export var resoulution : Vector2i
@export_range(1, 8) var color_depth : int = 5
@export_range(0, 16) var dither_strength : int = 8

var resolution_cached : Vector2i = Vector2i.ZERO

func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	
	var shader_file := load(shader_path)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	
	# Process pass
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)
		
	shader_file = load(shader_apply_path)
	shader_spirv = shader_file.get_spirv()
	
	# Upscale apply pass
	shader_apply = rd.shader_create_from_spirv(shader_spirv)
	if shader_apply.is_valid():
		pipeline_apply = rd.compute_pipeline_create(shader_apply)
	
	sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_sampler = rd.sampler_create(sampler_state)

	sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	nearest_sampler = rd.sampler_create(sampler_state)

	if Engine.is_editor_hint() and RenderingServer.global_shader_parameter_get("resolution"):
		resoulution = RenderingServer.global_shader_parameter_get("resolution")
	
	if dither == null: 
		dither = load(dither_path)
	
	if (Engine.is_editor_hint() and not EditorInterface.get_resource_filesystem().resources_reimported.is_connected(reload.bind())):
		EditorInterface.get_resource_filesystem().resources_reimported.connect(reload.bind())

func reload(files : PackedStringArray):
	if files.has(shader_path) or files.has(shader_apply_path):
		_init()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			rd.free_rid(shader)

func _check_shader() -> bool:
	if not rd:
		return false
	
	if shader_is_dirty:
		if shader.is_valid():
			rd.free_rid(shader)
			shader = RID()
			pipeline = RID()
		
		var shader_file := load(shader_path)
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	
		shader = rd.shader_create_from_spirv(shader_spirv)
		if shader.is_valid():
			pipeline = rd.compute_pipeline_create(shader)
		shader_is_dirty = false
	
	return pipeline.is_valid()

func get_image_uniform(image : RID, binding : int = 0) -> RDUniform:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(image)

	return uniform

func get_sampler_uniform(image : RID, binding : int = 0, linear : bool = true) -> RDUniform:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	if linear:
		uniform.add_id(linear_sampler)
	else:
		uniform.add_id(nearest_sampler)
	uniform.add_id(image)

	return uniform

func _render_callback(p_effect_callback_type, p_render_data):
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and _check_shader():
		var render_scene_buffers : RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			var size_out = render_scene_buffers.get_internal_size()
			if resoulution.x == 0 or resoulution.y == 0:
				resoulution = RenderingServer.global_shader_parameter_get("resolution")

			var x_groups = (resoulution.x - 1) / 8 + 1
			var y_groups = (resoulution.y - 1) / 8 + 1
			var z_groups = 1
			
			# Resolution and variables
			var push_constant : PackedFloat32Array = PackedFloat32Array()
			push_constant.push_back(resoulution.x)
			push_constant.push_back(resoulution.y)
			push_constant.push_back(color_depth)
			push_constant.push_back(dither_strength)
			push_constant.push_back(size_out.x)
			push_constant.push_back(size_out.y)
			push_constant.push_back(0)
			push_constant.push_back(0)
			
			var push_constant_apply : PackedFloat32Array = PackedFloat32Array()
			push_constant_apply = PackedFloat32Array()
			push_constant_apply.push_back(size_out.x)
			push_constant_apply.push_back(size_out.y)
			push_constant_apply.push_back(resoulution.x)
			push_constant_apply.push_back(resoulution.y)
			
			# Create downscaled buffer
			if !render_scene_buffers.has_texture("PSX", "screen") or resolution_cached != resoulution:
				resolution_cached = resoulution
				var usage_bits : int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
				render_scene_buffers.clear_context("PSX")
				render_scene_buffers.create_texture("PSX", "screen", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage_bits, RenderingDevice.TEXTURE_SAMPLES_1, resoulution, 1, 1, true)

			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				var screen_image = render_scene_buffers.get_color_layer(view)
				var process_image = render_scene_buffers.get_texture_slice("PSX", "screen", 0, 0, 1, 1) # Downscaled buffer
				
				var uniform_process = get_image_uniform(process_image)
				var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [ uniform_process ])
				
				var screen_sampler = render_scene_buffers.get_color_texture(view)
				
				var uniform_screen_sampler = get_sampler_uniform(screen_sampler)
				var uniform_dither = get_sampler_uniform(RenderingServer.texture_get_rd_texture(dither.get_rid()), 1, false)
				
				var uniform_set_samplers = UniformSetCacheRD.get_cache(shader, 1, [ uniform_screen_sampler, uniform_dither ])
				
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_samplers, 1)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
				
				x_groups = (size_out.x - 1) / 8 + 1
				y_groups = (size_out.y - 1) / 8 + 1
				z_groups = 1
				
				var uniform_screen = get_image_uniform(screen_image, 0)
				uniform_process = get_sampler_uniform(process_image, 0, false)
				
				uniform_set = UniformSetCacheRD.get_cache(shader_apply, 0, [ uniform_screen ])
				uniform_set_samplers = UniformSetCacheRD.get_cache(shader_apply, 1, [ uniform_process ])
				
				compute_list = rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline_apply)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set_samplers, 1)
				rd.compute_list_set_push_constant(compute_list, push_constant_apply.to_byte_array(), push_constant_apply.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
