extends Resource
class_name CampaignZoneDefinition
## Definição orientada a objetos para cada zona do modo Campanha ARPG (Ato 1 — As Terras de Velen).
## Configura nome, nível da área, conexões de portões, sementes de terreno/estrada e packs de monstros.

@export var zone_id: String = "town"
@export var title: String = "Vila de Velen"
@export var subtitle: String = "Vila Segura • Nível 1 – 3 • Fogueira, Baú e Mercadores"
@export var is_safe_town: bool = true
@export var area_level: int = 1
@export var terrain_seed: int = 10101
@export var prev_zone_id: String = ""
@export var prev_zone_label: String = ""
@export var prev_gate_pos: Vector3 = Vector3(0.0, 0.0, 19.5)
@export var next_zone_id: String = "zone_1_road"
@export var next_zone_label: String = "Floresta de Arath (Nv. 3–6)"
@export var next_gate_pos: Vector3 = Vector3(0.0, 0.0, -17.5)
@export var waypoint_pos: Vector3 = Vector3(-4.5, 0.0, 2.5)
@export var default_spawn_pos: Vector3 = Vector3(0.0, 0.0, 2.2)

## Lista de packs de inimigos posicionados ao longo dos caminhos da zona:
## Cada dicionário: { "center": Vector3, "skeletons": int, "wolves": int, "boss": int, "spread": float }
@export var monster_packs: Array[Dictionary] = []


static func get_act1_ordered_zone_ids() -> Array[String]:
	return [
		"town",
		"zone_1_road",
		"zone_2_woods",
		"zone_4_mines",
		"zone_3_crypt",
		"zone_6_hills",
		"zone_7_plateau",
		"zone_8_rift",
	]


static func build_default_campaign_zones() -> Dictionary:
	var zones: Dictionary = {}

	# 1. VILA DE VELEN — Refúgio Seguro (Nível 1 – 3)
	var town := CampaignZoneDefinition.new()
	town.zone_id = "town"
	town.title = "1. Vila de Velen"
	town.subtitle = "Vila Segura (Nível 1 – 3) • Fogueira, Baú, Mercadores e Waypoint"
	town.is_safe_town = true
	town.area_level = 1
	town.terrain_seed = 77701
	town.prev_zone_id = ""
	town.next_zone_id = "zone_1_road"
	town.next_zone_label = "2. Floresta de Arath (Nv. 3–6)"
	town.next_gate_pos = Vector3(0.0, 0.0, -16.5)
	town.waypoint_pos = Vector3(4.8, 0.0, 2.8)
	town.default_spawn_pos = Vector3(0.0, 0.0, 5.2)
	zones[town.zone_id] = town

	# 2. FLORESTA DE ARATH (Nível 3 – 6)
	var z1 := CampaignZoneDefinition.new()
	z1.zone_id = "zone_1_road"
	z1.title = "2. Floresta de Arath"
	z1.subtitle = "Nível 3 – 6 • Ponte antiga e bosque ribeirinho tomado por mortos-vivos"
	z1.is_safe_town = false
	z1.area_level = 3
	z1.terrain_seed = 88101
	z1.prev_zone_id = "town"
	z1.prev_zone_label = "1. Vila de Velen (Vila Segura)"
	z1.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z1.next_zone_id = "zone_2_woods"
	z1.next_zone_label = "3. Ruínas Antigas (Nv. 6–9)"
	z1.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z1.waypoint_pos = Vector3(-4.2, 0.0, 0.0)
	z1.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z1.monster_packs = [
		{"center": Vector3(1.5, 0.0, 8.5), "skeletons": 3, "wolves": 1, "boss": 0, "spread": 2.4},
		{"center": Vector3(-7.5, 0.0, 3.0), "skeletons": 3, "wolves": 2, "boss": 0, "spread": 2.8},
		{"center": Vector3(6.8, 0.0, -1.5), "skeletons": 2, "wolves": 3, "boss": 0, "spread": 2.6},
		{"center": Vector3(-2.0, 0.0, -9.0), "skeletons": 4, "wolves": 1, "boss": 0, "spread": 3.0},
		{"center": Vector3(8.5, 0.0, -12.5), "skeletons": 3, "wolves": 2, "boss": 0, "spread": 2.8},
	]
	zones[z1.zone_id] = z1

	# 3. RUÍNAS ANTIGAS (Nível 6 – 9)
	var z2 := CampaignZoneDefinition.new()
	z2.zone_id = "zone_2_woods"
	z2.title = "3. Ruínas Antigas"
	z2.subtitle = "Nível 6 – 9 • Círculo ancestral de pedra e colunas profanadas"
	z2.is_safe_town = false
	z2.area_level = 6
	z2.terrain_seed = 88202
	z2.prev_zone_id = "zone_1_road"
	z2.prev_zone_label = "2. Floresta de Arath (Nv. 3–6)"
	z2.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z2.next_zone_id = "zone_4_mines"
	z2.next_zone_label = "4. Minas de Karpon (Nv. 9–12)"
	z2.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z2.waypoint_pos = Vector3(4.5, 0.0, 0.5)
	z2.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z2.monster_packs = [
		{"center": Vector3(-2.5, 0.0, 9.0), "skeletons": 3, "wolves": 3, "boss": 0, "spread": 2.8},
		{"center": Vector3(8.0, 0.0, 4.5), "skeletons": 3, "wolves": 3, "boss": 0, "spread": 3.0},
		{"center": Vector3(-8.5, 0.0, -2.0), "skeletons": 4, "wolves": 3, "boss": 0, "spread": 3.2},
		{"center": Vector3(2.0, 0.0, -7.5), "skeletons": 4, "wolves": 2, "boss": 0, "spread": 3.0},
		{"center": Vector3(-1.5, 0.0, -14.0), "skeletons": 3, "wolves": 2, "boss": 1, "spread": 3.2},
	]
	zones[z2.zone_id] = z2

	# 4. MINAS DE KARPON (Nível 9 – 12)
	var z4 := CampaignZoneDefinition.new()
	z4.zone_id = "zone_4_mines"
	z4.title = "4. Minas de Karpon"
	z4.subtitle = "Nível 9 – 12 • Escavações abissais iluminadas por cristais arcanos"
	z4.is_safe_town = false
	z4.area_level = 9
	z4.terrain_seed = 88404
	z4.prev_zone_id = "zone_2_woods"
	z4.prev_zone_label = "3. Ruínas Antigas (Nv. 6–9)"
	z4.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z4.next_zone_id = "zone_3_crypt"
	z4.next_zone_label = "5. Cripta do Carrasco (Nv. 12–15)"
	z4.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z4.waypoint_pos = Vector3(-4.6, 0.0, 1.2)
	z4.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z4.monster_packs = [
		{"center": Vector3(2.0, 0.0, 9.0), "skeletons": 4, "wolves": 2, "boss": 0, "spread": 2.8},
		{"center": Vector3(-7.0, 0.0, 3.5), "skeletons": 4, "wolves": 3, "boss": 0, "spread": 3.0},
		{"center": Vector3(7.2, 0.0, -3.0), "skeletons": 4, "wolves": 3, "boss": 0, "spread": 3.0},
		{"center": Vector3(-1.5, 0.0, -11.5), "skeletons": 4, "wolves": 2, "boss": 1, "spread": 3.4},
	]
	zones[z4.zone_id] = z4

	# 5. CRIPTA DO CARRASCO (Nível 12 – 15)
	var z3 := CampaignZoneDefinition.new()
	z3.zone_id = "zone_3_crypt"
	z3.title = "5. Cripta do Carrasco"
	z3.subtitle = "Nível 12 – 15 • Santuário profanado guardado pelo Carrasco"
	z3.is_safe_town = false
	z3.area_level = 12
	z3.terrain_seed = 88303
	z3.prev_zone_id = "zone_4_mines"
	z3.prev_zone_label = "4. Minas de Karpon (Nv. 9–12)"
	z3.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z3.next_zone_id = "zone_6_hills"
	z3.next_zone_label = "6. Colinas Sombrias (Nv. 15–18)"
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

	# 6. COLINAS SOMBRIAS (Nível 15 – 18)
	var z6 := CampaignZoneDefinition.new()
	z6.zone_id = "zone_6_hills"
	z6.title = "6. Colinas Sombrias"
	z6.subtitle = "Nível 15 – 18 • Desfiladeiros íngremes vigiados por hordas veteranas"
	z6.is_safe_town = false
	z6.area_level = 15
	z6.terrain_seed = 88606
	z6.prev_zone_id = "zone_3_crypt"
	z6.prev_zone_label = "5. Cripta do Carrasco (Nv. 12–15)"
	z6.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z6.next_zone_id = "zone_7_plateau"
	z6.next_zone_label = "7. Planalto Esquecido (Nv. 18–21)"
	z6.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z6.waypoint_pos = Vector3(4.4, 0.0, 0.8)
	z6.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z6.monster_packs = [
		{"center": Vector3(-2.0, 0.0, 9.0), "skeletons": 4, "wolves": 3, "boss": 0, "spread": 2.8},
		{"center": Vector3(7.5, 0.0, 3.0), "skeletons": 4, "wolves": 4, "boss": 0, "spread": 3.2},
		{"center": Vector3(-7.8, 0.0, -3.5), "skeletons": 5, "wolves": 3, "boss": 1, "spread": 3.2},
		{"center": Vector3(1.5, 0.0, -11.0), "skeletons": 5, "wolves": 3, "boss": 1, "spread": 3.4},
	]
	zones[z6.zone_id] = z6

	# 7. PLANALTO ESQUECIDO (Nível 18 – 21)
	var z7 := CampaignZoneDefinition.new()
	z7.zone_id = "zone_7_plateau"
	z7.title = "7. Planalto Esquecido"
	z7.subtitle = "Nível 18 – 21 • Arcos imperiais no topo das montanhas de Velen"
	z7.is_safe_town = false
	z7.area_level = 18
	z7.terrain_seed = 88707
	z7.prev_zone_id = "zone_6_hills"
	z7.prev_zone_label = "6. Colinas Sombrias (Nv. 15–18)"
	z7.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z7.next_zone_id = "zone_8_rift"
	z7.next_zone_label = "8. Fenda Abissal (Nv. 21–25)"
	z7.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z7.waypoint_pos = Vector3(-4.5, 0.0, 0.5)
	z7.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z7.monster_packs = [
		{"center": Vector3(2.2, 0.0, 9.2), "skeletons": 5, "wolves": 3, "boss": 0, "spread": 3.0},
		{"center": Vector3(-8.0, 0.0, 2.8), "skeletons": 5, "wolves": 3, "boss": 1, "spread": 3.2},
		{"center": Vector3(7.6, 0.0, -3.5), "skeletons": 5, "wolves": 4, "boss": 1, "spread": 3.2},
		{"center": Vector3(0.0, 0.0, -12.0), "skeletons": 6, "wolves": 3, "boss": 1, "spread": 3.5},
	]
	zones[z7.zone_id] = z7

	# 8. FENDA ABISSAL (Nível 21 – 25)
	var z8 := CampaignZoneDefinition.new()
	z8.zone_id = "zone_8_rift"
	z8.title = "8. Fenda Abissal"
	z8.subtitle = "Nível 21 – 25 • Cratera de sangue e cristais rubros no coração do abismo"
	z8.is_safe_town = false
	z8.area_level = 21
	z8.terrain_seed = 88808
	z8.prev_zone_id = "zone_7_plateau"
	z8.prev_zone_label = "7. Planalto Esquecido (Nv. 18–21)"
	z8.prev_gate_pos = Vector3(0.0, 0.0, 19.5)
	z8.next_zone_id = "town"
	z8.next_zone_label = "Portal de Retorno à Vila de Velen"
	z8.next_gate_pos = Vector3(0.0, 0.0, -19.5)
	z8.waypoint_pos = Vector3(-5.0, 0.0, 11.5)
	z8.default_spawn_pos = Vector3(0.0, 0.0, 16.5)
	z8.monster_packs = [
		{"center": Vector3(2.5, 0.0, 9.5), "skeletons": 5, "wolves": 3, "boss": 1, "spread": 3.0},
		{"center": Vector3(-7.5, 0.0, 2.5), "skeletons": 5, "wolves": 4, "boss": 1, "spread": 3.2},
		{"center": Vector3(7.5, 0.0, -2.5), "skeletons": 5, "wolves": 4, "boss": 1, "spread": 3.2},
		{"center": Vector3(0.0, 0.0, -8.5), "skeletons": 6, "wolves": 4, "boss": 2, "spread": 3.8},
	]
	zones[z8.zone_id] = z8

	return zones
