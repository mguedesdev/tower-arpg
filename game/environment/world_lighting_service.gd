extends RefCounted
class_name WorldLightingService
## Serviço central de iluminação e sombras estilizadas por região (Godot 4).
## Implementa os três perfis visuais inspirados no estilo artístico de referência:
## 1. Floresta Natural (Exterior): Sol moderado, sombras reconhecíveis, cores vivas e naturais.
## 2. Masmorra (Interior): Escuridão profunda, tochas quentes com atenuação suave e cantos legíveis.
## 3. Floresta Mágica (Temático): Ambientação azul-esverdeada mística, luz de santuário e alto contraste.

enum LightingProfileType {
	EXTERIOR_NATURAL,
	INTERIOR_DUNGEON,
	MYSTIC_THEMATIC
}

const CONTAINER_LOCAL_LIGHTS: String = "RegionalLocalLights"


static func get_profile_type_for_zone(zone_id: String) -> LightingProfileType:
	match zone_id:
		"zone_3_crypt":
			return LightingProfileType.INTERIOR_DUNGEON
		"zone_4_mines", "zone_7_plateau", "zone_8_rift", "zone_2_woods":
			return LightingProfileType.MYSTIC_THEMATIC
		_:
			# "town", "zone_1_road", "zone_6_hills"
			return LightingProfileType.EXTERIOR_NATURAL


static func get_profile_data(profile_type: LightingProfileType) -> Dictionary:
	match profile_type:
		LightingProfileType.EXTERIOR_NATURAL:
			return {
				"type": LightingProfileType.EXTERIOR_NATURAL,
				"name": "Floresta Natural (Exterior)",
				"sun_enabled": true,
				"sun_color": Color(1.0, 0.96, 0.90),
				"sun_energy": 0.92,
				"sun_rotation": Vector3(-55.0, 38.0, 0.0),
				"shadow_enabled": true,
				"shadow_blur": 1.25,
				"shadow_bias": 0.03,
				"shadow_distance": 48.0,
				"ambient_source": Environment.AMBIENT_SOURCE_COLOR,
				"ambient_color": Color(0.52, 0.58, 0.66),
				"ambient_energy": 0.52,
				"bg_color": Color(0.18, 0.22, 0.26),
				"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
				"tonemap_exposure": 0.96,
				"has_local_torches": false
			}

		LightingProfileType.INTERIOR_DUNGEON:
			return {
				"type": LightingProfileType.INTERIOR_DUNGEON,
				"name": "Masmorra (Interior)",
				"sun_enabled": false,
				"sun_color": Color(0.1, 0.1, 0.1),
				"sun_energy": 0.0,
				"sun_rotation": Vector3(-90.0, 0.0, 0.0),
				"shadow_enabled": false,
				"shadow_blur": 1.0,
				"shadow_bias": 0.02,
				"shadow_distance": 20.0,
				"ambient_source": Environment.AMBIENT_SOURCE_COLOR,
				"ambient_color": Color(0.24, 0.28, 0.36),
				"ambient_energy": 0.32,
				"bg_color": Color(0.04, 0.04, 0.06),
				"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
				"tonemap_exposure": 0.94,
				"has_local_torches": true,
				"torch_color": Color(1.0, 0.62, 0.22),
				"torch_energy": 1.65,
				"torch_range": 10.5,
				"torch_attenuation": 1.35
			}

		LightingProfileType.MYSTIC_THEMATIC:
			return {
				"type": LightingProfileType.MYSTIC_THEMATIC,
				"name": "Floresta Mágica (Temático)",
				"sun_enabled": true,
				"sun_color": Color(0.55, 0.75, 0.92),
				"sun_energy": 0.45,
				"sun_rotation": Vector3(-58.0, 32.0, 0.0),
				"shadow_enabled": true,
				"shadow_blur": 1.30,
				"shadow_bias": 0.03,
				"shadow_distance": 44.0,
				"ambient_source": Environment.AMBIENT_SOURCE_COLOR,
				"ambient_color": Color(0.22, 0.48, 0.52),
				"ambient_energy": 0.48,
				"bg_color": Color(0.03, 0.08, 0.10),
				"tonemap_mode": Environment.TONE_MAPPER_FILMIC,
				"tonemap_exposure": 0.95,
				"has_local_torches": true,
				"torch_color": Color(0.35, 0.88, 1.0),
				"torch_energy": 1.80,
				"torch_range": 9.5,
				"torch_attenuation": 1.20
			}

	return {}


static func apply_lighting_profile(root_node: Node3D, zone_id: String) -> Dictionary:
	if root_node == null:
		return {}

	var p_type := get_profile_type_for_zone(zone_id)
	var p_data := get_profile_data(p_type)

	# 1. Configurar ou Instanciar Sun (DirectionalLight3D)
	var sun: DirectionalLight3D = root_node.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
		root_node.add_child(sun)

	var sun_active: bool = p_data.get("sun_enabled", true)
	sun.visible = sun_active
	sun.light_color = p_data.get("sun_color", Color.WHITE)
	sun.light_energy = p_data.get("sun_energy", 0.9) if sun_active else 0.0
	var rot_deg: Vector3 = p_data.get("sun_rotation", Vector3(-55.0, 38.0, 0.0))
	sun.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))

	sun.shadow_enabled = p_data.get("shadow_enabled", true) and sun_active
	sun.shadow_bias = float(p_data.get("shadow_bias", 0.03))
	sun.shadow_blur = float(p_data.get("shadow_blur", 1.2))
	sun.directional_shadow_max_distance = float(p_data.get("shadow_distance", 45.0))
	sun.directional_shadow_split_1 = 0.20
	sun.directional_shadow_split_2 = 0.50
	sun.directional_shadow_blend_splits = true

	# 2. Configurar WorldEnvironment
	var w_env: WorldEnvironment = root_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if w_env == null:
		w_env = WorldEnvironment.new()
		w_env.name = "WorldEnvironment"
		root_node.add_child(w_env)

	var env: Environment = w_env.environment
	if env == null:
		env = Environment.new()
	else:
		env = env.duplicate() as Environment

	env.background_mode = Environment.BG_COLOR
	env.background_color = p_data.get("bg_color", Color(0.18, 0.22, 0.26))
	env.ambient_light_source = p_data.get("ambient_source", Environment.AMBIENT_SOURCE_COLOR)
	env.ambient_light_color = p_data.get("ambient_color", Color(0.52, 0.58, 0.66))
	env.ambient_light_energy = float(p_data.get("ambient_energy", 0.52))
	env.tonemap_mode = p_data.get("tonemap_mode", Environment.TONE_MAPPER_FILMIC)
	env.tonemap_exposure = float(p_data.get("tonemap_exposure", 0.96))
	w_env.environment = env

	# 3. Gerenciar Luzes Locais (Tochas/Santuário)
	_setup_local_lights(root_node, p_data, zone_id)

	print("WorldLightingService: Aplicado perfil [%s] para a zona [%s]." % [p_data.get("name", "Desconhecido"), zone_id])
	return p_data


static func _setup_local_lights(root_node: Node3D, p_data: Dictionary, zone_id: String) -> void:
	var container: Node3D = root_node.get_node_or_null(CONTAINER_LOCAL_LIGHTS) as Node3D
	if container == null:
		container = Node3D.new()
		container.name = CONTAINER_LOCAL_LIGHTS
		root_node.add_child(container)
	else:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()

	if not p_data.get("has_local_torches", false):
		return

	var torch_col: Color = p_data.get("torch_color", Color(1.0, 0.62, 0.22))
	var torch_nrg: float = float(p_data.get("torch_energy", 1.4))
	var torch_rng: float = float(p_data.get("torch_range", 9.0))
	var torch_att: float = float(p_data.get("torch_attenuation", 1.35))

	var p_type: LightingProfileType = p_data.get("type", LightingProfileType.EXTERIOR_NATURAL)

	if p_type == LightingProfileType.INTERIOR_DUNGEON:
		# Masmorra: Tochas e candelabros distribuídos na entrada, corredor e altar
		var torch_positions := [
			Vector3(0.0, 2.2, 14.5),   # Entrada / Spawn
			Vector3(-3.8, 2.2, 8.5),   # Corredor Sul Esquerdo
			Vector3(3.8, 2.2, 8.5),    # Corredor Sul Direito
			Vector3(-6.5, 2.2, -1.5),  # Pilar Central Esquerdo
			Vector3(6.5, 2.2, -1.5),   # Pilar Central Direito
			Vector3(0.0, 2.5, -4.5),   # Altar do Carrasco
			Vector3(0.0, 2.2, -14.5)   # Portal Norte
		]
		for pos in torch_positions:
			var light := OmniLight3D.new()
			container.add_child(light)
			light.position = pos
			light.light_color = torch_col
			light.light_energy = torch_nrg
			light.omni_range = torch_rng
			light.omni_attenuation = torch_att
			light.shadow_enabled = true
			light.shadow_blur = 1.3
			light.shadow_bias = 0.03

	elif p_type == LightingProfileType.MYSTIC_THEMATIC:
		# Místico: Santuário central com luz etérea ciano/azul suave
		var mystic_positions := [
			Vector3(0.0, 1.8, 0.0),   # Santuário central
			Vector3(-8.0, 2.0, -8.0), # Cristal Norte
			Vector3(8.0, 2.0, 8.0)    # Cristal Sul
		]
		for pos in mystic_positions:
			var light := OmniLight3D.new()
			container.add_child(light)
			light.position = pos
			light.light_color = torch_col
			light.light_energy = torch_nrg
			light.omni_range = torch_rng
			light.omni_attenuation = torch_att
			light.shadow_enabled = true
			light.shadow_blur = 1.4
			light.shadow_bias = 0.03
