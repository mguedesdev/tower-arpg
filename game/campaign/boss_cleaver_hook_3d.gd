extends Node3D
class_name BossCleaverHook3D

## Projétil de Cutelo Encorrentado do Boss Malakor.
## Dispara um cutelo giratório colossal atrelado a correntes de ferro negro e sangue.
## Ao atingir o jogador, crava na armadura e puxa o herói violentamente para os pés do Boss.

signal hit_player(player_node: Node)
signal finished()

const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")

var boss: Node3D
var target_player: Node3D
var direction: Vector3 = Vector3.FORWARD
var speed: float = 22.0
var max_distance: float = 12.5
var damage: int = 24

var _start_pos: Vector3
var _distance_traveled: float = 0.0
var _state: int = 0 # 0: Arremesso, 1: Puxando Jogador, 2: Retornando Vazio
var _hit_target: Node3D = null

var _cleaver_pivot: Node3D
var _chain_mesh_instance: MeshInstance3D
var _chain_mat: StandardMaterial3D


func _ready() -> void:
	_build_visuals()


func launch(from_boss: Node3D, target: Node3D, forward_dir: Vector3) -> void:
	boss = from_boss
	target_player = target
	direction = forward_dir.normalized()
	_start_pos = global_position
	_distance_traveled = 0.0
	_state = 0


func _build_visuals() -> void:
	_cleaver_pivot = Node3D.new()
	add_child(_cleaver_pivot)

	# Material de ferro negro rúnico com emissão avermelhada
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.16, 0.18)
	iron_mat.roughness = 0.65
	iron_mat.emission_enabled = true
	iron_mat.emission = Color(0.85, 0.22, 0.10)
	iron_mat.emission_energy_multiplier = 0.85

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.65, 0.70, 0.75)
	steel_mat.roughness = 0.35
	steel_mat.metallic = 0.85

	# Cabo do Cutelo
	var haft := CylinderMesh.new()
	haft.top_radius = 0.04
	haft.bottom_radius = 0.04
	haft.height = 1.35
	var haft_node := MeshInstance3D.new()
	haft_node.mesh = haft
	haft_node.material_override = iron_mat
	_cleaver_pivot.add_child(haft_node)

	# Bloco e Lâmina de Aço do Cutelo
	var blade := BoxMesh.new()
	blade.size = Vector3(0.08, 0.85, 0.38)
	var blade_node := MeshInstance3D.new()
	blade_node.mesh = blade
	blade_node.material_override = steel_mat
	blade_node.position = Vector3(0.0, 0.32, 0.18)
	_cleaver_pivot.add_child(blade_node)

	# Correntes de Sangue/Ferro esticadas do Boss até o Cutelo
	_chain_mat = StandardMaterial3D.new()
	_chain_mat.albedo_color = Color(0.85, 0.25, 0.15)
	_chain_mat.emission_enabled = true
	_chain_mat.emission = Color(1.0, 0.35, 0.18)
	_chain_mat.emission_energy_multiplier = 1.2
	_chain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_chain_mesh_instance = MeshInstance3D.new()
	_chain_mesh_instance.material_override = _chain_mat
	_chain_mesh_instance.top_level = true
	add_child(_chain_mesh_instance)


func _physics_process(delta: float) -> void:
	# Atualiza malha visual das correntes conectando o Boss ao Cutelo
	_update_chain_visual()

	if _cleaver_pivot != null:
		_cleaver_pivot.rotation.x += 24.0 * delta

	match _state:
		0:
			# FASE 0: Arremesso em linha reta
			var step: float = speed * delta
			global_position += direction * step
			_distance_traveled += step

			# Checa colisão com o jogador
			if is_instance_valid(target_player):
				var p_center: Vector3 = target_player.global_position + Vector3.UP * 0.8
				if global_position.distance_to(p_center) <= 1.35:
					_on_cleaver_latched_player(target_player)
					return

			# Se atingiu a distância máxima sem acertar, retorna vazio
			if _distance_traveled >= max_distance:
				_state = 2

		1:
			# FASE 1: Acertou o jogador e puxa o herói para o Boss
			if is_instance_valid(boss) and is_instance_valid(_hit_target):
				var boss_anchor: Vector3 = boss.global_position + Vector3.UP * 1.2
				var to_boss: Vector3 = (boss_anchor - global_position)
				var dist: float = to_boss.length()
				if dist <= 2.2:
					# Chegou no boss, finaliza
					_destroy_and_finish()
				else:
					global_position = global_position.move_toward(boss_anchor, speed * 1.15 * delta)
			else:
				_destroy_and_finish()

		2:
			# FASE 2: Retornando vazio para a mão do Boss
			if is_instance_valid(boss):
				var boss_hand: Vector3 = boss.global_position + Vector3.UP * 1.4
				global_position = global_position.move_toward(boss_hand, speed * 1.4 * delta)
				if global_position.distance_to(boss_hand) <= 1.0:
					_destroy_and_finish()
			else:
				_destroy_and_finish()


func _on_cleaver_latched_player(player_node: Node3D) -> void:
	_state = 1
	_hit_target = player_node
	hit_player.emit(player_node)

	# Efeitos de impacto e ganchos de sangue
	var scene_root: Node3D = get_tree().current_scene as Node3D
	if scene_root != null:
		VFX.impact(scene_root, global_position, 1.3)
		VFX.fire_burst(scene_root, global_position, 1.4)

	# Aplica dano no jogador
	if player_node.has_method("take_damage"):
		player_node.call("take_damage", damage)

	# Puxa o jogador violentamente para os pés do Boss
	if is_instance_valid(boss) and player_node.has_method("pull_towards"):
		var to_player: Vector3 = (player_node.global_position - boss.global_position)
		to_player.y = 0.0
		var landing_pos: Vector3 = boss.global_position + to_player.normalized() * 2.0
		player_node.call("pull_towards", landing_pos, 0.42)


func _update_chain_visual() -> void:
	if not is_instance_valid(boss) or _chain_mesh_instance == null:
		return

	var start: Vector3 = boss.global_position + Vector3.UP * 1.4
	var end: Vector3 = global_position
	var seg: Vector3 = end - start
	var length: float = seg.length()
	if length < 0.2:
		_chain_mesh_instance.visible = false
		return

	_chain_mesh_instance.visible = true
	var chain_cyl := CylinderMesh.new()
	chain_cyl.top_radius = 0.035
	chain_cyl.bottom_radius = 0.035
	chain_cyl.height = length

	_chain_mesh_instance.mesh = chain_cyl
	_chain_mesh_instance.global_position = (start + end) * 0.5

	# Alinha o cilindro ao vetor entre Boss e Cutelo
	var up_axis: Vector3 = seg.normalized()
	var forward_axis: Vector3 = Vector3.UP.cross(up_axis)
	if forward_axis.length_squared() < 0.001:
		forward_axis = Vector3.RIGHT.cross(up_axis)
	forward_axis = forward_axis.normalized()
	var right_axis: Vector3 = up_axis.cross(forward_axis).normalized()

	_chain_mesh_instance.global_basis = Basis(right_axis, up_axis, forward_axis)


func _destroy_and_finish() -> void:
	finished.emit()
	if _chain_mesh_instance != null and is_instance_valid(_chain_mesh_instance):
		_chain_mesh_instance.queue_free()
	queue_free()
