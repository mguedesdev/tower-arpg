extends RefCounted
class_name PipelineWarmupService
## Serviço técnico de pré-compilação e aquecimento de pipelines gráficos e shaders (Godot 4 / OpenGL Compatibility).
## No renderer Compatibility (OpenGL 3.3 Core), os shaders GLSL são compilados na GPU no primeiro draw call.
## Este serviço força a submissão de 1 frame de draw off-screen durante a tela de loading para todos os
## materiais e shaders críticos do jogo, eliminando micro-travamentos na primeira execução de golpes ou aparição de monstros.

const FOLIAGE_SHADER := preload("res://assets/shaders/nature_foliage_dither.gdshader")
const TERRAIN_SHADER := preload("res://assets/terrain_v2/terreno_estilizado_blend.gdshader")
const HEALTH_BAR_SHADER := preload("res://assets/ui/hud/player_health_bar_3d.gdshader")
const VFX_EFFECT_SCRIPT := preload("res://scripts/vfx/tower_vfx_effect.gd")

static var _already_warmed: bool = false


## Executa o aquecimento seguro via SubViewport isolado de 64x64 sem poluir a árvore visual principal
static func warm_up_pipelines(scene_tree: SceneTree, zone_id: String = "") -> void:
	if scene_tree == null or scene_tree.root == null:
		return

	# Em modo headless (servidor / testes unitários sem GPU real), dispensamos o draw call
	if DisplayServer.get_name() == "headless":
		return

	print("PipelineWarmupService: Iniciando aquecimento off-screen de shaders e materiais para [%s]..." % (zone_id if not zone_id.is_empty() else "global"))
	var vp := SubViewport.new()
	vp.name = "ShaderWarmupViewport"
	vp.size = Vector2i(64, 64)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	scene_tree.root.add_child(vp)

	var stage := Node3D.new()
	vp.add_child(stage)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 5.0)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	stage.add_child(cam)

	# 1. Shader de Folhagem com Dithered Fade
	var fol_quad := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.5, 0.5)
	fol_quad.mesh = quad_mesh
	var fol_mat := ShaderMaterial.new()
	fol_mat.shader = FOLIAGE_SHADER
	fol_mat.set_shader_parameter("fade_amount", 0.5)
	fol_quad.material_override = fol_mat
	fol_quad.position = Vector3(-1.0, 1.0, 0.0)
	stage.add_child(fol_quad)

	# 2. Shader de Terreno Estilizado Contínuo
	var ter_quad := MeshInstance3D.new()
	ter_quad.mesh = quad_mesh
	var ter_mat := ShaderMaterial.new()
	ter_mat.shader = TERRAIN_SHADER
	ter_quad.material_override = ter_mat
	ter_quad.position = Vector3(0.0, 1.0, 0.0)
	stage.add_child(ter_quad)

	# 3. Shader de Barra de Vida 3D
	var hp_quad := MeshInstance3D.new()
	hp_quad.mesh = quad_mesh
	var hp_mat := ShaderMaterial.new()
	hp_mat.shader = HEALTH_BAR_SHADER
	hp_quad.material_override = hp_mat
	hp_quad.position = Vector3(1.0, 1.0, 0.0)
	stage.add_child(hp_quad)

	# 4. Malhas e Materiais de VFX de Combate (Estocada, Meia-Lua, Giro, Impacto, Fogo)
	VFX_EFFECT_SCRIPT.warm_up_caches()
	for k in [
		VFX_EFFECT_SCRIPT.Kind.STAB,
		VFX_EFFECT_SCRIPT.Kind.ARC,
		VFX_EFFECT_SCRIPT.Kind.SPIN,
		VFX_EFFECT_SCRIPT.Kind.IMPACT,
		VFX_EFFECT_SCRIPT.Kind.FIRE,
		VFX_EFFECT_SCRIPT.Kind.CLAWS
	]:
		var vfx_mesh_node := MeshInstance3D.new()
		vfx_mesh_node.mesh = VFX_EFFECT_SCRIPT._get_or_build_cached_mesh(k)
		vfx_mesh_node.material_override = VFX_EFFECT_SCRIPT.get_fade_material(0.5)
		vfx_mesh_node.position = Vector3(0.0, 0.0, 0.0)
		stage.add_child(vfx_mesh_node)

	# 5. Modelos Skinned / Inimigos Principais
	if not _already_warmed:
		_warm_enemy_mesh(stage, "res://assets/models/skeleton_enemy.glb")
		_warm_enemy_mesh(stage, "res://assets/models/wolf.glb")
		_warm_enemy_mesh(stage, "res://assets/models/golem_boss.glb")
		_warm_enemy_mesh(stage, "res://assets/models/knight.glb")
		_already_warmed = true

	# Aguarda 1 frame de renderização para o OpenGL compilar e linkar os binários na GPU
	await scene_tree.process_frame

	vp.queue_free()
	print("PipelineWarmupService: Aquecimento concluído. Todos os shaders compilados com sucesso no driver gráfico.")


static func _warm_enemy_mesh(stage: Node3D, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var sc: PackedScene = load(path) as PackedScene
	if sc == null:
		return
	var inst: Node = sc.instantiate()
	if inst is Node3D:
		stage.add_child(inst)
		(inst as Node3D).position = Vector3(0.0, -1.0, 0.0)
