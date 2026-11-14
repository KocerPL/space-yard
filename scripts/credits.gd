extends Control

@export_group("Crawl Settings")
@export var scroll_speed: float = 65.0
@export var tilt_angle_degrees: float = 58.0
@export var text_color: Color = Color(1.0, 0.82, 0.12) 
@export var loop_crawl: bool = false

@export_group("Credits text")
@export_multiline var credits_text: String = """"""

var _viewport: SubViewport
var _rich_text: RichTextLabel
var _fade_shader_mat: ShaderMaterial

signal credits_finished

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 4.2)
	cam.fov = 70.0
	_viewport.add_child(cam)
	
	var text_vp := SubViewport.new()
	text_vp.size = Vector2i(1024, 2048)
	text_vp.transparent_bg = true
	text_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.add_child(text_vp)
	
	_rich_text = RichTextLabel.new()
	_rich_text.visible = false
	_rich_text.bbcode_enabled = true
	_rich_text.fit_content = true
	_rich_text.scroll_active = false
	_rich_text.size = Vector2(920, 100)
	_rich_text.position = Vector2(52, 1024)
	_rich_text.add_theme_color_override("default_color", text_color)
	_rich_text.text = "[center][font_size=42]%s[/font_size][/center]" % [credits_text]
	text_vp.add_child(_rich_text)
	
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 18.0)
	mesh_instance.mesh = quad
	mesh_instance.rotation_degrees.x = -tilt_angle_degrees
	mesh_instance.position = Vector3(0.0, -0.5, -2.5)
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = text_vp.get_texture()
	mesh_instance.material_override = mat
	_viewport.add_child(mesh_instance)
	
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		vec4 col = texture(TEXTURE, UV);
		float fade = smoothstep(0.18, 0.45, UV.y);
		col.a *= fade;
		COLOR = col;
	}
	"""
	_fade_shader_mat = ShaderMaterial.new()
	_fade_shader_mat.shader = shader
	material = _fade_shader_mat
	
	await get_tree().process_frame
	reset_credits()

func reset_credits() -> void:
	_rich_text.position.y = 1496.0
	_rich_text.visible = true

func _process(delta: float) -> void:
	if not _rich_text:
		return
		
	var speed_mult := 3.5 if Input.is_action_pressed("ui_accept") else 1.0
	_rich_text.position.y -= scroll_speed * speed_mult * delta
	queue_redraw()
	
	if _rich_text.position.y + _rich_text.size.y < 0.0:
		credits_finished.emit()
		if loop_crawl:
			get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
			reset_credits()
		else:
			set_process(false)

func _draw() -> void:
	if _viewport:
		draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
