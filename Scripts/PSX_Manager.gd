@tool
extends Node
class_name PSX_Manager

var psx_compositor_effect : PSX_Screen
var psx_canvas_material : ShaderMaterial

@export var fog_range : Vector2 = Vector2(20, 40):
	get:
		return fog_range
	set(v):
		RenderingServer.global_shader_parameter_set("fog_range", fog_range)
		fog_range = v

@export var fog_color : Color:
	get:
		return fog_color
	set(v):
		RenderingServer.global_shader_parameter_set("fog_color", fog_color)
		fog_color = v

@export var fog_black : bool:
	get:
		return fog_black
	set(v):
		RenderingServer.global_shader_parameter_set("fog_black", fog_black)
		fog_black = v

static var scene_current : String


func _ready() -> void:
	_apply_settings()
	
	_get_project_settings()
	_setup_shader_globals()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if scene_current != EditorInterface.get_edited_scene_root().scene_file_path:
			_apply_settings()
			scene_current = EditorInterface.get_edited_scene_root().scene_file_path


func _get_project_settings():
	var compositor_path = "psx/compositor_effect_path"
	var canvas_path = "psx/canvas_material_path"
	
	var compositor_setting = ProjectSettings.get_setting(compositor_path)
	if !ProjectSettings.has_setting(compositor_path):
		ProjectSettings.set_setting(compositor_path, "")
		compositor_setting = ""
		print_rich("You can set [b]psx/compositor_effect_path[/b] in [b]project settings[/b] to be used by [b]PSX Manager[/b]")
	if compositor_setting and compositor_setting != "": 
		psx_compositor_effect = load(ProjectSettings.get(compositor_path))
		
	var canvas_setting = ProjectSettings.get_setting(canvas_path)
	if !ProjectSettings.has_setting(canvas_path): 
		ProjectSettings.set_setting(canvas_path, "")
		canvas_setting = ""
		print_rich("You can set [b]psx/canvas_material_path[/b] in [b]project settings[/b] to be used by [b]PSX Manager[/b]")
	if canvas_setting and canvas_setting != "": 
		psx_canvas_material = load(ProjectSettings.get(canvas_path))


func _setup_shader_globals():
	var globals : Dictionary
	globals["resolution"] = Vector2i(320, 240)
	globals["snap"] = 0.5
	globals["cull_dist"] = 0.5
	globals["fog_black"] = false
	globals["fog_range"] = Vector2(10, 20)
	globals["fog_color"] = Color.WHITE
	
	for k in globals.keys():
		if RenderingServer.global_shader_parameter_get(k) == null:
			print_rich("Shader global is missing - id: [b]{0}[/b], type: [b]{1}[/b], add it in [b]Project settings -> Globals -> Shader globals[/b]: [b]".format([k, type_string(typeof(globals[k]))]))


func _apply_settings():
	RenderingServer.global_shader_parameter_set("fog_range", fog_range)
	RenderingServer.global_shader_parameter_set("fog_color", fog_color)
	RenderingServer.global_shader_parameter_set("fog_black", fog_black)


func set_resolution(resolution : Vector2):
	RenderingServer.global_shader_parameter_set("resolution", resolution)
	
	if psx_compositor_effect:
		psx_compositor_effect.resoulution = resolution


func set_color_depth(depth : int):
	if psx_compositor_effect:
		psx_compositor_effect.color_depth = depth
	
	if psx_canvas_material:
		psx_canvas_material.set_shader_parameter("color_depth", depth)


func set_dither_strength(strength : int):
	if psx_compositor_effect:
		psx_compositor_effect.dither_strength = strength
	
	if psx_canvas_material:
		psx_canvas_material.set_shader_parameter("dither_strength", strength)


func set_dither_strength_texture(texture : Texture2D):
	if psx_compositor_effect:
		psx_compositor_effect.dither = texture
	
	if psx_canvas_material:
		psx_canvas_material.set_shader_parameter("dither_texture", texture)
