extends SceneTree

func _init() -> void:
	var code := """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;
instance uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);
    if (tex.a < 0.5) discard;
    ALBEDO = tex.rgb;
}
"""
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	mi.set_instance_shader_parameter("fade_amount", 0.5)
	var val = mi.get_instance_shader_parameter("fade_amount")
	print("Godot 4 instance uniform test: fade_amount = ", val)
	quit(0)
