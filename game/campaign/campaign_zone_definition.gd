extends Resource
class_name CampaignZoneDefinition
## Definição orientada a objetos para cada zona do modo Campanha ARPG (estilo Diablo 2 / Path of Exile).
## Configura nome, nível da área, conexões de portões, sementes de terreno/estrada e packs de monstros.

@export var zone_id: String = "town"
@export var title: String = "Acampamento dos Exilados"
@export var subtitle: String = "Vila Segura • Fogueira, Baú e Mercadores"
@export var is_safe_town: bool = true
@export var area_level: int = 1
@export var terrain_seed: int = 10101
@export var prev_zone_id: String = ""
@export var prev_zone_label: String = ""
@export var prev_gate_pos: Vector3 = Vector3(0.0, 0.0, 19.5)
@export var next_zone_id: String = "zone_1_road"
@export var next_zone_label: String = "Estrada Profanada (Nv. 1)"
@export var next_gate_pos: Vector3 = Vector3(0.0, 0.0, -17.5)
@export var waypoint_pos: Vector3 = Vector3(-4.5, 0.0, 2.5)
@export var default_spawn_pos: Vector3 = Vector3(0.0, 0.0, 2.2)

## Lista de packs de inimigos posicionados ao longo dos caminhos da zona:
## Cada dicionário: { "center": Vector3, "skeletons": int, "wolves": int, "boss": int, "spread": float }
@export var monster_packs: Array[Dictionary] = []


static func build_default_campaign_zones() -> Dictionary:
	var zones: Dictionary = {}

	# 0. VILA SEGURA — Acampamento dos Exilados (estilo Rogue Encampment - Diablo 2)
	var town := CampaignZoneDefinition.new()
	town.zone_id = "town"
	town.title = "Acampamento dos Exilados"
	town.subtitle = "Vila Segura • Fogueira, Baú e Mercadores"
	town.is_safe_town = true
	town.area_level = 1
	town.terrain_seed = 77701
	town.prev_zone_id = ""
	town.next_zone_id = "zone_1_road"
	town.next_zone_label = "Estrada Profanada (Nv. 1)"
	town.next_gate_pos = Vector3(0.0, 0.0, -16.5)
	town.waypoint_pos = Vector3(4.8, 0.0, 2.8)
	town.default_spawn_pos = Vector3(0.0, 0.0, 5.2)
	zones[town.zone_id] = town

	# 1. ZONA 1 — Estrada Profanada (estilo Blood Moor / Coast)
	var z1 := CampaignZoneDefinition.new()
	z1.zone_id = "zone_1_road"
	z1.title = "Estrada Profanada"
	z1.subtitle = "Nível da Área: 1 • Antiga estrada imperial tomada por mortos-vivos"
	z1.is_safe_town = false
	z1.area_level = 1
	z1.terrain_seed = 88101
	z1.prev_zone_id = "town"
	z1.prev_zone_label = "Acampamento dos Exilados (Vila)"
	z1.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z1.next_zone_id = "zone_2_woods"
	z1.next_zone_label = "Mata das Sombras (Nv. 2)"
	z1.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z1.waypoint_pos = Vector3(-4.2, 0.0, 0.0)
	z1.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z1.monster_packs = [
		{"center": Vector3(1.5, 0.0, 8.5), "skeletons": 3, "wolves": 0, "boss": 0, "spread": 2.4},
		{"center": Vector3(-7.5, 0.0, 3.0), "skeletons": 3, "wolves": 1, "boss": 0, "spread": 2.8},
		{"center": Vector3(6.8, 0.0, -1.5), "skeletons": 2, "wolves": 2, "boss": 0, "spread": 2.6},
		{"center": Vector3(-2.0, 0.0, -9.0), "skeletons": 4, "wolves": 1, "boss": 0, "spread": 3.0},
		{"center": Vector3(8.5, 0.0, -12.5), "skeletons": 3, "wolves": 1, "boss": 0, "spread": 2.8},
	]
	zones[z1.zone_id] = z1

	# 2. ZONA 2 — Mata das Sombras (estilo Dark Wood / Grim Dawn Burrwitch Outskirts)
	var z2 := CampaignZoneDefinition.new()
	z2.zone_id = "zone_2_woods"
	z2.title = "Mata das Sombras"
	z2.subtitle = "Nível da Área: 2 • Floresta retorcida infestada por alcateias abissais"
	z2.is_safe_town = false
	z2.area_level = 2
	z2.terrain_seed = 88202
	z2.prev_zone_id = "zone_1_road"
	z2.prev_zone_label = "Estrada Profanada (Nv. 1)"
	z2.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z2.next_zone_id = "zone_3_crypt"
	z2.next_zone_label = "Cripta do Carrasco (Nv. 3)"
	z2.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z2.waypoint_pos = Vector3(4.5, 0.0, 0.5)
	z2.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z2.monster_packs = [
		{"center": Vector3(-2.5, 0.0, 9.0), "skeletons": 2, "wolves": 3, "boss": 0, "spread": 2.8},
		{"center": Vector3(8.0, 0.0, 4.5), "skeletons": 2, "wolves": 3, "boss": 0, "spread": 3.0},
		{"center": Vector3(-8.5, 0.0, -2.0), "skeletons": 3, "wolves": 3, "boss": 0, "spread": 3.2},
		{"center": Vector3(2.0, 0.0, -7.5), "skeletons": 4, "wolves": 2, "boss": 0, "spread": 3.0},
		{"center": Vector3(-1.5, 0.0, -14.0), "skeletons": 3, "wolves": 2, "boss": 1, "spread": 3.2},
	]
	zones[z2.zone_id] = z2

	# 3. ZONA 3 — Cripta do Carrasco (estilo Burial Grounds / Catacombs)
	var z3 := CampaignZoneDefinition.new()
	z3.zone_id = "zone_3_crypt"
	z3.title = "Cripta do Carrasco"
	z3.subtitle = "Nível da Área: 3 • Santuário profanado guardado pelo Carrasco"
	z3.is_safe_town = false
	z3.area_level = 3
	z3.terrain_seed = 88303
	z3.prev_zone_id = "zone_2_woods"
	z3.prev_zone_label = "Mata das Sombras (Nv. 2)"
	z3.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z3.next_zone_id = "town"
	z3.next_zone_label = "Portal de Retorno à Vila"
	z3.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z3.waypoint_pos = Vector3(-5.0, 0.0, 11.5)
	z3.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z3.monster_packs = [
		{"center": Vector3(2.5, 0.0, 9.5), "skeletons": 4, "wolves": 2, "boss": 0, "spread": 2.8},
		{"center": Vector3(-7.5, 0.0, 2.5), "skeletons": 4, "wolves": 2, "boss": 0, "spread": 3.0},
		{"center": Vector3(7.5, 0.0, -2.5), "skeletons": 4, "wolves": 3, "boss": 0, "spread": 3.0},
		{"center": Vector3(0.0, 0.0, -8.5), "skeletons": 5, "wolves": 2, "boss": 2, "spread": 3.6},
	]
	zones[z3.zone_id] = z3

	return zones
