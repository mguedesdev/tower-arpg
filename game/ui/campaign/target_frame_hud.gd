extends Control
class_name TargetFrameHUD
## Placa de Alvo Selecionado no Topo Central (estilo Albion Online).
## Mostra Retrato Circular, Nome do Monstro, Nível e Barras de Vida / Energia.

var _target_enemy: TowerEnemy = null
var _target_ring: MeshInstance3D = null

var _panel: PanelContainer
var _name_label: Label
var _lvl_badge: Label
var _hp_bar: ProgressBar
var _hp_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(280, 58)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchors_preset = Control.PRESET_CENTER_TOP
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.position = Vector2(-140, 24)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	style.border_color = Color(0.65, 0.52, 0.25, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_panel.add_child(hbox)

	# 1. Retrato Circular do Monstro
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(44, 44)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.12, 0.14, 0.18)
	p_style.border_color = Color(0.85, 0.25, 0.25)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(22)
	portrait.add_theme_stylebox_override("panel", p_style)
	hbox.add_child(portrait)

	var p_icon := Label.new()
	p_icon.text = "☠"
	p_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_icon.position = Vector2(0, 2)
	p_icon.size = Vector2(44, 40)
	p_icon.add_theme_font_size_override("font_size", 22)
	p_icon.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	portrait.add_child(p_icon)

	# 2. Informações de Nome, Nível e Barras
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	_name_label = Label.new()
	_name_label.text = "Inimigo"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.65))
	title_row.add_child(_name_label)

	_lvl_badge = Label.new()
	_lvl_badge.text = "[VI]"
	_lvl_badge.add_theme_font_size_override("font_size", 11)
	_lvl_badge.add_theme_color_override("font_color", Color(0.90, 0.40, 0.30))
	title_row.add_child(_lvl_badge)

	# 3. Barra de Vida Vermelha
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(180, 14)
	_hp_bar.show_percentage = false
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.08, 0.08, 0.10)
	hp_bg.set_corner_radius_all(3)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.18, 0.22)
	hp_fill.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.text = "100 / 100"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(0, -2)
	_hp_label.size = Vector2(180, 16)
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_bar.add_child(_hp_label)


func set_target(enemy: TowerEnemy, area_lvl: int = 1) -> void:
	if _target_enemy == enemy:
		return
	_remove_ring()
	_target_enemy = enemy
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		visible = false
		return

	visible = true
	var e_name: String = "Esqueleto Profanado"
	if _target_enemy.is_mini_boss:
		e_name = "☠ O Carrasco Profanado"
	elif _target_enemy.name.to_lower().contains("wolf"):
		e_name = "Lobo Espectral"

	_name_label.text = e_name
	_lvl_badge.text = "[Nv. %d]" % maxi(1, area_lvl)
	_update_stats()

	# Cria o anel vermelho de seleção sob os pés do monstro
	_create_ring(_target_enemy)


func _create_ring(enemy: Node3D) -> void:
	_target_ring = MeshInstance3D.new()
	_target_ring.name = "TargetSelectionRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.08
	torus.rings = 24
	torus.ring_segments = 4
	_target_ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.18, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.20, 0.20)
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_target_ring.material_override = mat
	_target_ring.position = Vector3(0.0, 0.03, 0.0)
	enemy.add_child(_target_ring)


func _remove_ring() -> void:
	if _target_ring != null and is_instance_valid(_target_ring):
		_target_ring.queue_free()
		_target_ring = null


func _update_stats() -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		visible = false
		_remove_ring()
		return
	_hp_bar.max_value = _target_enemy.maximum_health
	_hp_bar.value = _target_enemy.health
	_hp_label.text = "%d / %d" % [_target_enemy.health, _target_enemy.maximum_health]


func _process(_delta: float) -> void:
	if not visible:
		return
	if _target_enemy == null or not is_instance_valid(_target_enemy) or _target_enemy.health <= 0:
		visible = false
		_remove_ring()
		_target_enemy = null
		return
	_update_stats()
