extends RefCounted
class_name RegionEnvironmentScatter
## Gerador determinístico de ambientação e vegetação estilizada (MegaKit 3D) para o modo Campanha ARPG.
## Posiciona árvores com troncos sólidos, rochas bloqueantes e vegetação decorativa sem colisão.
## Garante caminhos navegáveis, clareiras de combate, exclusão de portais/NPCs e ausência de sombras.

const NatureProp3DScript = preload("res://game/environment/nature_prop_3d.gd")
const BASE_PATH: String = "res://assets/nature_megakit/"

const MODELS_TREES: Array[String] = [
	"Tree.glb",
	"Tree-aVOxaHRPWe.glb",
	"Tree-QVOop92WmG.glb",
	"Tree-t9KbsfYdXz.glb"
]

const MODELS_PINES: Array[String] = [
	"Pine.glb",
	"Pine-699sFuLCN2.glb",
	"Pine-79gmlLnweB.glb",
	"Pine-rfnxJv0Rqa.glb"
]

const MODELS_DEAD_TREES: Array[String] = [
	"Dead Tree.glb",
	"Dead Tree-CD4edbPSGm.glb",
	"Dead Tree-Mcd2zYqyww.glb"
]

const MODELS_TWISTED_TREES: Array[String] = [
	"Twisted Tree.glb",
	"Twisted Tree-7PDBpElkQr.glb",
	"Twisted Tree-8oraKn9m0x.glb"
]

const MODELS_BUSHES: Array[String] = [
	"Bush.glb",
	"Bush with Flowers.glb"
]

const MODELS_FERNS: Array[String] = [
	"Fern.glb"
]

const MODELS_GRASS: Array[String] = [
	"Grass.glb",
	"Tall Grass.glb",
	"Grass Wispy.glb",
	"Clover.glb"
]

const MODELS_FLOWERS: Array[String] = [
	"Flower Group.glb",
	"Flower Single.glb"
]

const MODELS_MUSHROOMS: Array[String] = [
	"Mushroom.glb",
	"Mushroom Laetiporus.glb"
]

const MODELS_ROCKS_MEDIUM: Array[String] = [
	"Rock Medium.glb",
	"Rock Medium-JQxF95498B.glb",
	"Rock Medium-s1OJ3bBzqc.glb"
]

const MODELS_PEBBLES: Array[String] = [
	"Pebble Round.glb",
	"Pebble Square.glb"
]


static func build_environment(parent: Node3D, zone_def: CampaignZoneDefinition) -> void:
	if parent == null or zone_def == null:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = zone_def.terrain_seed if zone_def.terrain_seed != 0 else 88101

	var root_props := Node3D.new()
	root_props.name = "MegaKitEnvironmentProps"
	parent.add_child(root_props)

	var exclusion_zones: Array[Dictionary] = _gather_exclusion_zones(zone_def)
	var zone_id := zone_def.zone_id

	if zone_def.is_safe_town:
		_populate_town(root_props, rng, exclusion_zones)
	elif zone_id == "zone_1_road":
		_populate_arath_forest(root_props, rng, exclusion_zones, zone_def)
	elif zone_id == "zone_2_woods":
		_populate_ancient_ruins(root_props, rng, exclusion_zones, zone_def)
	elif zone_id == "zone_4_mines":
		_populate_karpon_mines(root_props, rng, exclusion_zones, zone_def)
	elif zone_id == "zone_3_crypt":
		_populate_executioner_crypt(root_props, rng, exclusion_zones, zone_def)
	elif zone_id == "zone_6_hills":
		_populate_dark_hills(root_props, rng, exclusion_zones, zone_def)
	elif zone_id == "zone_7_plateau":
		_populate_forgotten_plateau(root_props, rng, exclusion_zones, zone_def)
	elif zone_id == "zone_8_rift":
		_populate_abyssal_rift(root_props, rng, exclusion_zones, zone_def)
	else:
		_populate_arath_forest(root_props, rng, exclusion_zones, zone_def)


static func _gather_exclusion_zones(zone_def: CampaignZoneDefinition) -> Array[Dictionary]:
	var list: Array[Dictionary] = []

	# Waypoint
	if zone_def.waypoint_pos != Vector3.ZERO:
		list.append({"pos": zone_def.waypoint_pos, "radius": 3.4})

	# Portais de Entrada e Saída
	if zone_def.prev_gate_pos != Vector3.ZERO:
		list.append({"pos": zone_def.prev_gate_pos, "radius": 3.6})
	if zone_def.next_gate_pos != Vector3.ZERO:
		list.append({"pos": zone_def.next_gate_pos, "radius": 3.6})

	# Spawn do Player
	if zone_def.default_spawn_pos != Vector3.ZERO:
		list.append({"pos": zone_def.default_spawn_pos, "radius": 2.8})

	# Estações da Vila
	if zone_def.is_safe_town:
		list.append({"pos": Vector3(0.0, 0.0, 0.0), "radius": 3.2}) # Fogueira central
		list.append({"pos": Vector3(-5.8, 0.0, -3.5), "radius": 3.0}) # Baú
		list.append({"pos": Vector3(-7.4, 0.0, 3.2), "radius": 3.0}) # Ferreiro
		list.append({"pos": Vector3(7.4, 0.0, -3.2), "radius": 3.0}) # Arcanista
		list.append({"pos": Vector3(-2.6, 0.0, -5.2), "radius": 2.8}) # Sábio
		list.append({"pos": Vector3(2.6, 0.0, -5.2), "radius": 2.8}) # Escriba

	# Clareiras de combate dos packs de monstros (raio livre para combate fluido)
	for pack in zone_def.monster_packs:
		var center: Vector3 = pack.get("center", Vector3.ZERO)
		var spread: float = float(pack.get("spread", 2.6))
		list.append({"pos": center, "radius": spread * 0.95})

	return list


static func _is_in_exclusion(pos: Vector3, exclusion_zones: Array[Dictionary], extra_margin: float = 0.0) -> bool:
	for ex in exclusion_zones:
		var ex_pos: Vector3 = ex["pos"]
		var ex_rad: float = float(ex["radius"]) + extra_margin
		var d2: float = (pos.x - ex_pos.x) * (pos.x - ex_pos.x) + (pos.z - ex_pos.z) * (pos.z - ex_pos.z)
		if d2 < (ex_rad * ex_rad):
			return true
	return false


static func _is_on_main_road(pos: Vector3, clearance: float = 2.4) -> bool:
	# O caminho curvo oficial segue: road_x = sin(z * 0.16) * 2.6
	var road_x: float = sin(pos.z * 0.16) * 2.6
	return absf(pos.x - road_x) < clearance


static func _spawn_prop(
	parent: Node3D,
	rel_path: String,
	category: int,
	pos: Vector3,
	scale_val: Vector3,
	yaw: float
) -> Node3D:
	var prop: Node3D = NatureProp3DScript.new()
	parent.add_child(prop)
	prop.position = pos
	prop.configure(BASE_PATH + rel_path, category, scale_val, yaw)
	return prop


## -----------------------------------------------------------------------------
## 1. VILA DE VELEN (Segura, organizada, caminhos livres, árvores em volta)
## -----------------------------------------------------------------------------
static func _populate_town(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary]) -> void:
	# Árvores frondosas no exterior dos muros
	var perimeter_tree_spots := [
		Vector3(-18.5, 0.0, -18.5), Vector3(-14.5, 0.0, -21.0), Vector3(15.5, 0.0, -20.5), Vector3(19.0, 0.0, -17.5),
		Vector3(-20.5, 0.0, 0.0), Vector3(-21.0, 0.0, 10.5), Vector3(20.5, 0.0, -2.5), Vector3(21.0, 0.0, 8.5),
		Vector3(-16.0, 0.0, 19.5), Vector3(-9.0, 0.0, 20.5), Vector3(10.0, 0.0, 20.0), Vector3(17.5, 0.0, 18.5)
	]
	for spot in perimeter_tree_spots:
		var tree_file := MODELS_TREES[rng.randi() % MODELS_TREES.size()]
		var s := rng.randf_range(0.85, 1.15)
		_spawn_prop(parent, tree_file, NatureProp3DScript.PropCategory.TREE_NORMAL, spot, Vector3(s, s, s), rng.randf_range(-PI, PI))

	# Arbustos decorativos próximos às muralhas sem bloquear passagem
	var bush_spots := [
		Vector3(-12.5, 0.0, -14.5), Vector3(12.5, 0.0, -14.5),
		Vector3(-12.0, 0.0, 12.0), Vector3(12.0, 0.0, 12.0),
		Vector3(-6.5, 0.0, 12.5), Vector3(6.5, 0.0, 12.5)
	]
	for b_pos in bush_spots:
		var b_file := MODELS_BUSHES[rng.randi() % MODELS_BUSHES.size()]
		var bs := rng.randf_range(0.75, 1.0)
		_spawn_prop(parent, b_file, NatureProp3DScript.PropCategory.BUSH, b_pos, Vector3(bs, bs, bs), rng.randf_range(-PI, PI))

	# Pequenas pedrinhas e grama baixa nos cantos da vila
	for _i in range(16):
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(5.5, 16.0)
		var p_pos := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		if not _is_in_exclusion(p_pos, exclusion_zones, 1.0):
			var pebble_file := MODELS_PEBBLES[rng.randi() % MODELS_PEBBLES.size()]
			_spawn_prop(parent, pebble_file, NatureProp3DScript.PropCategory.PEBBLE, p_pos, Vector3(0.9, 0.9, 0.9), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 2. FLORESTA DE ARATH (Área Piloto: Bosque denso, pinheiros, samambaias e clareiras)
## -----------------------------------------------------------------------------
static func _populate_arath_forest(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	# 1. Árvores e Pinheiros estruturais nas bordas e entre as clareiras
	var tree_candidates: Array[Vector3] = [
		# Bosque Oeste (X negativo)
		Vector3(-18.5, 0.0, -16.0), Vector3(-14.0, 0.0, -18.5), Vector3(-17.0, 0.0, -10.5), Vector3(-12.5, 0.0, -12.0),
		Vector3(-19.5, 0.0, -3.5), Vector3(-15.0, 0.0, -4.0), Vector3(-18.5, 0.0, 6.5), Vector3(-13.5, 0.0, 8.0),
		Vector3(-16.5, 0.0, 15.0), Vector3(-12.0, 0.0, 17.0), Vector3(-8.5, 0.0, 19.5),
		# Bosque Leste (X positivo)
		Vector3(18.5, 0.0, -16.0), Vector3(14.5, 0.0, -18.5), Vector3(17.0, 0.0, -9.5), Vector3(12.5, 0.0, -7.0),
		Vector3(19.5, 0.0, 2.5), Vector3(14.5, 0.0, 4.0), Vector3(18.0, 0.0, 12.5), Vector3(13.0, 0.0, 14.5),
		Vector3(16.5, 0.0, 18.0), Vector3(9.5, 0.0, 19.5),
		# Divisores entre clareiras (afastados da estrada e dos monstros)
		Vector3(-4.5, 0.0, -15.5), Vector3(4.8, 0.0, -15.0),
		Vector3(-6.2, 0.0, -5.5), Vector3(5.8, 0.0, -6.5),
		Vector3(-5.5, 0.0, 6.0), Vector3(5.5, 0.0, 5.5)
	]

	for pos in tree_candidates:
		if _is_in_exclusion(pos, exclusion_zones, 0.8) or _is_on_main_road(pos, 2.5):
			continue
		var is_pine: bool = rng.randf() < 0.45
		var model: String = (MODELS_PINES if is_pine else MODELS_TREES)[rng.randi() % (MODELS_PINES.size() if is_pine else MODELS_TREES.size())]
		var cat: int = NatureProp3DScript.PropCategory.TREE_PINE if is_pine else NatureProp3DScript.PropCategory.TREE_NORMAL
		var s := rng.randf_range(0.85, 1.20)
		_spawn_prop(parent, model, cat, pos, Vector3(s, s, s), rng.randf_range(-PI, PI))

	# 2. Rochas Médias naturais marcando as bordas das clareiras
	var rock_spots: Array[Vector3] = [
		Vector3(-14.5, 0.0, -14.0), Vector3(15.0, 0.0, -13.0),
		Vector3(-15.5, 0.0, 1.5), Vector3(15.5, 0.0, -1.0),
		Vector3(-14.0, 0.0, 13.0), Vector3(14.0, 0.0, 11.5)
	]
	for r_pos in rock_spots:
		if not _is_in_exclusion(r_pos, exclusion_zones, 0.5) and not _is_on_main_road(r_pos, 2.6):
			var r_file := MODELS_ROCKS_MEDIUM[rng.randi() % MODELS_ROCKS_MEDIUM.size()]
			var rs := rng.randf_range(0.80, 1.10)
			_spawn_prop(parent, r_file, NatureProp3DScript.PropCategory.ROCK_MEDIUM, r_pos, Vector3(rs, rs, rs), rng.randf_range(-PI, PI))

	# 3. Arbustos e Samambaias (Sem colisão, bordas da floresta)
	for _i in range(18):
		var x: float = rng.randf_range(-20.0, 20.0)
		var z: float = rng.randf_range(-19.0, 19.0)
		var pos := Vector3(x, 0.0, z)
		if _is_in_exclusion(pos, exclusion_zones, 0.4) or _is_on_main_road(pos, 1.8):
			continue
		if rng.randf() < 0.5:
			var fern_file := MODELS_FERNS[0]
			# Fern unscaled tem 9m de diâmetro no modelo original, escala adequada = 0.25 a 0.35
			var fs := rng.randf_range(0.24, 0.35)
			_spawn_prop(parent, fern_file, NatureProp3DScript.PropCategory.FERN, pos, Vector3(fs, fs, fs), rng.randf_range(-PI, PI))
		else:
			var b_file := MODELS_BUSHES[rng.randi() % MODELS_BUSHES.size()]
			var bs := rng.randf_range(0.65, 0.95)
			_spawn_prop(parent, b_file, NatureProp3DScript.PropCategory.BUSH, pos, Vector3(bs, bs, bs), rng.randf_range(-PI, PI))

	# 4. Grama alta e tufos decorativos (Sem colisão)
	for _i in range(26):
		var x: float = rng.randf_range(-21.0, 21.0)
		var z: float = rng.randf_range(-20.0, 20.0)
		var pos := Vector3(x, 0.0, z)
		if _is_on_main_road(pos, 1.2):
			continue
		var g_file := MODELS_GRASS[rng.randi() % MODELS_GRASS.size()]
		var gs := rng.randf_range(0.85, 1.25)
		_spawn_prop(parent, g_file, NatureProp3DScript.PropCategory.GRASS_TALL, pos, Vector3(gs, gs, gs), rng.randf_range(-PI, PI))

	# 5. Flores e Cogumelos mágicos próximos à vegetação
	for _i in range(12):
		var x: float = rng.randf_range(-18.0, 18.0)
		var z: float = rng.randf_range(-18.0, 18.0)
		var pos := Vector3(x, 0.0, z)
		if _is_on_main_road(pos, 1.5) or _is_in_exclusion(pos, exclusion_zones, 0.5):
			continue
		var is_mushroom: bool = rng.randf() < 0.4
		var m_file: String = (MODELS_MUSHROOMS if is_mushroom else MODELS_FLOWERS)[rng.randi() % (MODELS_MUSHROOMS.size() if is_mushroom else MODELS_FLOWERS.size())]
		var ms: float = rng.randf_range(0.8, 1.1) if not is_mushroom else rng.randf_range(0.65, 0.95)
		var cat: int = NatureProp3DScript.PropCategory.MUSHROOM if is_mushroom else NatureProp3DScript.PropCategory.FLOWER
		_spawn_prop(parent, m_file, cat, pos, Vector3(ms, ms, ms), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 3. RUÍNAS ANTIGAS (Pinheiros, árvores secas, rochas e vegetação entre pedras)
## -----------------------------------------------------------------------------
static func _populate_ancient_ruins(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	for _i in range(16):
		var x: float = rng.randf_range(-21.0, 21.0)
		var z: float = rng.randf_range(-20.0, 20.0)
		var pos := Vector3(x, 0.0, z)
		if _is_in_exclusion(pos, exclusion_zones, 1.0) or _is_on_main_road(pos, 2.4):
			continue
		var is_pine: bool = rng.randf() < 0.6
		var model: String = (MODELS_PINES if is_pine else MODELS_DEAD_TREES)[rng.randi() % (MODELS_PINES.size() if is_pine else MODELS_DEAD_TREES.size())]
		var cat: int = NatureProp3DScript.PropCategory.TREE_PINE if is_pine else NatureProp3DScript.PropCategory.TREE_DEAD
		var s := rng.randf_range(0.85, 1.15)
		_spawn_prop(parent, model, cat, pos, Vector3(s, s, s), rng.randf_range(-PI, PI))

	for _i in range(10):
		var pos := Vector3(rng.randf_range(-18.0, 18.0), 0.0, rng.randf_range(-18.0, 18.0))
		if not _is_in_exclusion(pos, exclusion_zones, 0.8) and not _is_on_main_road(pos, 2.5):
			var r_file := MODELS_ROCKS_MEDIUM[rng.randi() % MODELS_ROCKS_MEDIUM.size()]
			_spawn_prop(parent, r_file, NatureProp3DScript.PropCategory.ROCK_MEDIUM, pos, Vector3(1.0, 1.0, 1.0), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 4. MINAS DE KARPON (Predomínio de rochas médias, cascalho e vegetação esparsa)
## -----------------------------------------------------------------------------
static func _populate_karpon_mines(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	for _i in range(16):
		var pos := Vector3(rng.randf_range(-19.0, 19.0), 0.0, rng.randf_range(-19.0, 19.0))
		if not _is_in_exclusion(pos, exclusion_zones, 0.8) and not _is_on_main_road(pos, 2.5):
			var r_file := MODELS_ROCKS_MEDIUM[rng.randi() % MODELS_ROCKS_MEDIUM.size()]
			var rs := rng.randf_range(0.85, 1.35)
			_spawn_prop(parent, r_file, NatureProp3DScript.PropCategory.ROCK_MEDIUM, pos, Vector3(rs, rs, rs), rng.randf_range(-PI, PI))

	for _i in range(24):
		var pos := Vector3(rng.randf_range(-21.0, 21.0), 0.0, rng.randf_range(-20.0, 20.0))
		var p_file := MODELS_PEBBLES[rng.randi() % MODELS_PEBBLES.size()]
		_spawn_prop(parent, p_file, NatureProp3DScript.PropCategory.PEBBLE, pos, Vector3(1.1, 1.1, 1.1), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 5. CRIPTA DO CARRASCO (Árvores retorcidas e mortas, cogumelos, clima opressivo)
## -----------------------------------------------------------------------------
static func _populate_executioner_crypt(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	for _i in range(12):
		var pos := Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0))
		if _is_in_exclusion(pos, exclusion_zones, 1.0) or _is_on_main_road(pos, 2.5):
			continue
		var is_twisted: bool = rng.randf() < 0.5
		var model: String = (MODELS_TWISTED_TREES if is_twisted else MODELS_DEAD_TREES)[rng.randi() % (MODELS_TWISTED_TREES.size() if is_twisted else MODELS_DEAD_TREES.size())]
		var cat: int = NatureProp3DScript.PropCategory.TREE_TWISTED if is_twisted else NatureProp3DScript.PropCategory.TREE_DEAD
		var s := rng.randf_range(0.85, 1.20)
		_spawn_prop(parent, model, cat, pos, Vector3(s, s, s), rng.randf_range(-PI, PI))

	for _i in range(14):
		var pos := Vector3(rng.randf_range(-19.0, 19.0), 0.0, rng.randf_range(-19.0, 19.0))
		if not _is_on_main_road(pos, 1.8):
			var m_file := MODELS_MUSHROOMS[rng.randi() % MODELS_MUSHROOMS.size()]
			_spawn_prop(parent, m_file, NatureProp3DScript.PropCategory.MUSHROOM, pos, Vector3(0.8, 0.8, 0.8), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 6. COLINAS SOMBRIAS (Pinheiros, rochas médias, arbustos, trilhas entre elevações)
## -----------------------------------------------------------------------------
static func _populate_dark_hills(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	for _i in range(14):
		var pos := Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0))
		if not _is_in_exclusion(pos, exclusion_zones, 0.8) and not _is_on_main_road(pos, 2.5):
			var model := MODELS_PINES[rng.randi() % MODELS_PINES.size()]
			var s := rng.randf_range(0.9, 1.25)
			_spawn_prop(parent, model, NatureProp3DScript.PropCategory.TREE_PINE, pos, Vector3(s, s, s), rng.randf_range(-PI, PI))

	for _i in range(8):
		var pos := Vector3(rng.randf_range(-18.0, 18.0), 0.0, rng.randf_range(-18.0, 18.0))
		if not _is_in_exclusion(pos, exclusion_zones, 0.8) and not _is_on_main_road(pos, 2.5):
			var r_file := MODELS_ROCKS_MEDIUM[rng.randi() % MODELS_ROCKS_MEDIUM.size()]
			_spawn_prop(parent, r_file, NatureProp3DScript.PropCategory.ROCK_MEDIUM, pos, Vector3(1.0, 1.0, 1.0), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 7. PLANALTO ESQUECIDO (Árvores isoladas, rochas e vegetação rasteira)
## -----------------------------------------------------------------------------
static func _populate_forgotten_plateau(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	for _i in range(8):
		var pos := Vector3(rng.randf_range(-19.0, 19.0), 0.0, rng.randf_range(-19.0, 19.0))
		if not _is_in_exclusion(pos, exclusion_zones, 1.0) and not _is_on_main_road(pos, 2.5):
			var model := MODELS_DEAD_TREES[rng.randi() % MODELS_DEAD_TREES.size()]
			_spawn_prop(parent, model, NatureProp3DScript.PropCategory.TREE_DEAD, pos, Vector3(1.1, 1.1, 1.1), rng.randf_range(-PI, PI))

	for _i in range(12):
		var pos := Vector3(rng.randf_range(-19.0, 19.0), 0.0, rng.randf_range(-19.0, 19.0))
		if not _is_in_exclusion(pos, exclusion_zones, 0.8) and not _is_on_main_road(pos, 2.5):
			var r_file := MODELS_ROCKS_MEDIUM[rng.randi() % MODELS_ROCKS_MEDIUM.size()]
			_spawn_prop(parent, r_file, NatureProp3DScript.PropCategory.ROCK_MEDIUM, pos, Vector3(1.0, 1.0, 1.0), rng.randf_range(-PI, PI))


## -----------------------------------------------------------------------------
## 8. FENDA ABISSAL (Solo rochoso, árvores mortas retorcidas e ambiente desolado)
## -----------------------------------------------------------------------------
static func _populate_abyssal_rift(parent: Node3D, rng: RandomNumberGenerator, exclusion_zones: Array[Dictionary], zone_def: CampaignZoneDefinition) -> void:
	for _i in range(8):
		var pos := Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0))
		if not _is_in_exclusion(pos, exclusion_zones, 1.0) and not _is_on_main_road(pos, 2.5):
			var model := MODELS_TWISTED_TREES[rng.randi() % MODELS_TWISTED_TREES.size()]
			_spawn_prop(parent, model, NatureProp3DScript.PropCategory.TREE_TWISTED, pos, Vector3(0.9, 0.9, 0.9), rng.randf_range(-PI, PI))

	for _i in range(16):
		var pos := Vector3(rng.randf_range(-19.0, 19.0), 0.0, rng.randf_range(-19.0, 19.0))
		if not _is_in_exclusion(pos, exclusion_zones, 0.8) and not _is_on_main_road(pos, 2.5):
			var r_file := MODELS_ROCKS_MEDIUM[rng.randi() % MODELS_ROCKS_MEDIUM.size()]
			_spawn_prop(parent, r_file, NatureProp3DScript.PropCategory.ROCK_MEDIUM, pos, Vector3(1.2, 1.2, 1.2), rng.randf_range(-PI, PI))
