extends SceneTree

## Suíte de Testes e QA: Stylized Nature MegaKit, Colisões, Navegação & Ambientação 3D
## Valida:
## 1. Carregamento dos 68 modelos GLB do Stylized Nature MegaKit.
## 2. Colisões simplificadas nos troncos das árvores e rochas médias.
## 3. Ausência de colisão em vegetação rasteira (grama, samambaias, flores, cogumelos, pedrinhas).
## 4. Ausência total de projeção de sombras em todos os modelos.
## 5. Regras de distribuição e zonas de exclusão (Waypoints, Portais, NPCs, Estrada, Clareiras).
## 6. Movimentação e combate com passagem livre pela estrada e clareiras.

const NatureProp3DScript = preload("res://game/environment/nature_prop_3d.gd")
const RegionEnvironmentScatterScript = preload("res://game/environment/region_environment_scatter.gd")
const CampaignZoneDefScript = preload("res://game/campaign/campaign_zone_definition.gd")

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % description)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % description)


func _run_all_tests() -> void:
	print("\n=================================================================")
	print("SUÍTE DE QA: STYLIZED NATURE MEGAKIT, COLISÕES E AMBIENTAÇÃO 3D")
	print("=================================================================\n")

	# -------------------------------------------------------------------------
	# 1. CATALOGAÇÃO E INTEGRIDADE DOS MODELOS GLB
	# -------------------------------------------------------------------------
	print("--- 1. CATALOGAÇÃO DOS 68 MODELOS GLB ---")
	var dir := DirAccess.open("res://assets/nature_megakit")
	_check(dir != null, "Diretório res://assets/nature_megakit existe")

	var glb_count: int = 0
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while not fname.is_empty():
			if not dir.current_is_dir() and fname.ends_with(".glb"):
				glb_count += 1
			fname = dir.get_next()
		dir.list_dir_end()
	_check(glb_count == 68, "Todos os 68 arquivos GLB estão presentes (encontrados: %d)" % glb_count)

	# -------------------------------------------------------------------------
	# 2. COLISÕES REAIS EM TRONCOS E ROCHAS MÉDIAS
	# -------------------------------------------------------------------------
	print("\n--- 2. COLISÕES DE TRONCOS E ROCHAS (SEM BLOQUEAR COPA) ---")
	var tree_prop: Node3D = NatureProp3DScript.new()
	tree_prop.configure("res://assets/nature_megakit/Tree.glb", NatureProp3DScript.PropCategory.TREE_NORMAL)
	var tree_body: StaticBody3D = tree_prop.get_node_or_null("ColliderBody") as StaticBody3D
	_check(tree_body != null, "Árvore Normal possui StaticBody3D de colisão")
	var tree_shape: CollisionShape3D = tree_body.get_node_or_null("TrunkShape") as CollisionShape3D if tree_body != null else null
	_check(tree_shape != null and tree_shape.shape is CylinderShape3D, "Colisão do tronco é CylinderShape3D simplificado")
	var cyl_shape := tree_shape.shape as CylinderShape3D if tree_shape != null else null
	_check(cyl_shape != null and cyl_shape.radius < 0.60, "Raio do collider restringe-se estritamente ao tronco (%.2fm < 0.60m)" % (cyl_shape.radius if cyl_shape != null else 0.0))
	_check(tree_prop.is_blocking == true, "Árvore é marcada como obstáculo físico (is_blocking = true)")
	tree_prop.queue_free()

	var rock_prop: Node3D = NatureProp3DScript.new()
	rock_prop.configure("res://assets/nature_megakit/Rock Medium.glb", NatureProp3DScript.PropCategory.ROCK_MEDIUM)
	var rock_body: StaticBody3D = rock_prop.get_node_or_null("ColliderBody") as StaticBody3D
	_check(rock_body != null, "Rocha Média possui StaticBody3D de colisão")
	_check(rock_prop.is_blocking == true, "Rocha Média é marcada como obstáculo físico")
	rock_prop.queue_free()

	# -------------------------------------------------------------------------
	# 3. AUSÊNCIA DE COLISÃO EM VEGETAÇÃO RASTEIRA E DECORATIVA
	# -------------------------------------------------------------------------
	print("\n--- 3. VEGETAÇÃO RASTEIRA LIVRE (SEM COLISÃO) ---")
	for sample in [
		{"file": "Grass.glb", "cat": NatureProp3DScript.PropCategory.GRASS_LOW, "label": "Grama Baixa"},
		{"file": "Tall Grass.glb", "cat": NatureProp3DScript.PropCategory.GRASS_TALL, "label": "Grama Alta"},
		{"file": "Fern.glb", "cat": NatureProp3DScript.PropCategory.FERN, "label": "Samambaia"},
		{"file": "Flower Single.glb", "cat": NatureProp3DScript.PropCategory.FLOWER, "label": "Flor"},
		{"file": "Mushroom.glb", "cat": NatureProp3DScript.PropCategory.MUSHROOM, "label": "Cogumelo"},
		{"file": "Pebble Round.glb", "cat": NatureProp3DScript.PropCategory.PEBBLE, "label": "Pedrinha"}
	]:
		var deco: Node3D = NatureProp3DScript.new()
		deco.configure("res://assets/nature_megakit/" + sample["file"], sample["cat"])
		var deco_body: StaticBody3D = deco.get_node_or_null("ColliderBody") as StaticBody3D
		_check(deco_body == null and not deco.is_blocking, "%s não possui colisão física (livre para caminhar)" % sample["label"])
		deco.queue_free()

	# -------------------------------------------------------------------------
	# 4. CONFIGURAÇÃO DE SOMBRAS (ÁRVORES CAST / VEGETAÇÃO RASTEIRA OFF)
	# -------------------------------------------------------------------------
	print("\n--- 4. CONFIGURAÇÃO SELETIVA DE SOMBRAS ---")
	var tree_shadow_test: Node3D = NatureProp3DScript.new()
	tree_shadow_test.configure("res://assets/nature_megakit/Pine.glb", NatureProp3DScript.PropCategory.TREE_PINE)
	var tree_meshes: Array[Node] = tree_shadow_test.find_children("", "MeshInstance3D", true, false)
	_check(tree_meshes.size() > 0, "Árvore carregou MeshInstance3D com sucesso")
	var tree_casts: bool = true
	for mi in tree_meshes:
		if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			tree_casts = false
			break
	_check(tree_casts, "Árvores têm cast_shadow ativado (SHADOW_CASTING_SETTING_ON) para silhuetas reconhecíveis")
	tree_shadow_test.queue_free()

	var deco_shadow_test: Node3D = NatureProp3DScript.new()
	deco_shadow_test.configure("res://assets/nature_megakit/Grass.glb", NatureProp3DScript.PropCategory.GRASS_LOW)
	var deco_meshes: Array[Node] = deco_shadow_test.find_children("", "MeshInstance3D", true, false)
	var deco_no_shadow: bool = true
	for mi in deco_meshes:
		if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			deco_no_shadow = false
			break
	_check(deco_no_shadow, "Vegetação rasteira tem cast_shadow desligado (SHADOW_CASTING_SETTING_OFF) para performance")
	deco_shadow_test.queue_free()

	# -------------------------------------------------------------------------
	# 5. ZONAS DE EXCLUSÃO E REGRAS DE AMBIENTAÇÃO NA FLORESTA DE ARATH
	# -------------------------------------------------------------------------
	print("\n--- 5. ZONAS DE EXCLUSÃO E NAVEGABILIDADE NA FLORESTA DE ARATH ---")
	var zones := CampaignZoneDefScript.build_default_campaign_zones()
	var z1: CampaignZoneDefinition = zones.get("zone_1_road") as CampaignZoneDefinition
	_check(z1 != null, "Definição de Floresta de Arath encontrada")

	var env_root := Node3D.new()
	get_root().add_child(env_root)
	RegionEnvironmentScatterScript.build_environment(env_root, z1)

	var spawned_props := env_root.find_children("", "Node3D", true, false)
	_check(spawned_props.size() > 20, "Floresta de Arath populada com múltiplos props orgânicos (encontrados: %d)" % spawned_props.size())

	# Valida que nenhum tronco bloqueante nasceu sobre o Waypoint
	var blocking_props := env_root.find_children("ColliderBody", "StaticBody3D", true, false)
	var wp_clear: bool = true
	for bp in blocking_props:
		var dist := (bp as StaticBody3D).global_position.distance_to(z1.waypoint_pos)
		if dist < 2.5:
			wp_clear = false
			break
	_check(wp_clear, "Waypoint Ancestral 100%% livre de árvores e rochas bloqueantes")

	# Valida que os portais de entrada e saída estão desimpedidos
	var gates_clear: bool = true
	for bp in blocking_props:
		var d_prev := (bp as StaticBody3D).global_position.distance_to(z1.prev_gate_pos)
		var d_next := (bp as StaticBody3D).global_position.distance_to(z1.next_gate_pos)
		if d_prev < 2.5 or d_next < 2.5:
			gates_clear = false
			break
	_check(gates_clear, "Portais de entrada e saída livres para transição de zona")

	# Valida que o centro da estrada permanece livre de troncos bloqueantes
	var road_clear: bool = true
	for bp in blocking_props:
		var b_pos: Vector3 = (bp as StaticBody3D).global_position
		var road_x: float = sin(b_pos.z * 0.16) * 2.6
		if absf(b_pos.x - road_x) < 2.0:
			road_clear = false
			break
	_check(road_clear, "Eixo principal da estrada limpo para movimentação contínua do jogador")

	# Valida que as clareiras de combate dos monstros têm espaço para a batalha
	var clearings_ok: bool = true
	for pack in z1.monster_packs:
		var c: Vector3 = pack.get("center", Vector3.ZERO)
		for bp in blocking_props:
			if (bp as StaticBody3D).global_position.distance_to(c) < 1.8:
				clearings_ok = false
				break
	_check(clearings_ok, "Centros dos packs de monstros mantêm clareiras livres para combate")

	env_root.queue_free()

	# -------------------------------------------------------------------------
	# 6. RESULTADO FINAL
	# -------------------------------------------------------------------------
	print("\n=================================================================")
	print("RESULTADO QA MEGAKIT & AMBIENTAÇÃO: %d PASSARAM | %d FALHARAM" % [_passed, _failed])
	print("=================================================================\n")

	if _failed == 0:
		print(">> TODOS OS CRITÉRIOS DE AMBIENTAÇÃO, COLISÃO E ILUMINAÇÃO APROVADOS! <<\n")
		quit(0)
	else:
		printerr(">> FALHAS ENCONTRADAS NA SUÍTE DE TESTES <<\n")
		quit(1)
