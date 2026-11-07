extends Control
class_name DayNightCycleHUD
## Relógio de Sol e Lua no HUD (sem texto de horas, apenas a animação artística do Sol, Lua e Luz)
## sincronizado em tempo real com o Sistema de Dia e Noite, Luz Direcional e Sombras 3D.

signal phase_changed(phase_id: String)

const FRAME_TEX_PATH: String = "res://assets/ui/hud_clock_frame.png"
const NIGHT_TEX_PATH: String = "res://assets/ui/hud_clock_night.png"
const DAWN_TEX_PATH: String = "res://assets/ui/hud_clock_dawn.png"
const NOON_TEX_PATH: String = "res://assets/ui/hud_clock_noon.png"
const DUSK_TEX_PATH: String = "res://assets/ui/hud_clock_dusk.png"

const WIDGET_SIZE: float = 136.0
const INNER_SCENE_RATIO: float = 270.0 / 440.0
const ORBIT_RADIUS_RATIO: float = 144.5 / 440.0

## Duração completa de um ciclo de Dia e Noite (em segundos reais)
@export var cycle_duration_seconds: float = 160.0
## Progresso do ciclo [0.0 .. 1.0): 0.0 = Meia-Noite, 0.25 = Amanhecer, 0.50 = Meio-Dia, 0.75 = Entardecer
@export var time_of_day: float = 0.48
@export var cycle_paused: bool = false

var _sun_light: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _env_instance: Environment = null
var _is_underground_zone: bool = false
var _current_phase_id: String = "day"
var _pulse_time: float = 0.0
var _target_advance_time: float = -1.0

var _tex_frame: Texture2D = null
var _tex_night: Texture2D = null
var _tex_dawn: Texture2D = null
var _tex_noon: Texture2D = null
var _tex_dusk: Texture2D = null


func _ready() -> void:
	name = "DayNightCycleHUD"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	size = Vector2(WIDGET_SIZE, WIDGET_SIZE)

	# Posicionado no canto superior direito do HUD
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -(WIDGET_SIZE + 18.0)
	offset_right = -18.0
	offset_top = 14.0
	offset_bottom = 14.0 + WIDGET_SIZE

	_load_textures()
	_current_phase_id = get_current_phase_id()
	_apply_world_lighting(0.0)
	queue_redraw()


func _load_textures() -> void:
	if ResourceLoader.exists(FRAME_TEX_PATH):
		_tex_frame = load(FRAME_TEX_PATH) as Texture2D
	if ResourceLoader.exists(NIGHT_TEX_PATH):
		_tex_night = load(NIGHT_TEX_PATH) as Texture2D
	if ResourceLoader.exists(DAWN_TEX_PATH):
		_tex_dawn = load(DAWN_TEX_PATH) as Texture2D
	if ResourceLoader.exists(NOON_TEX_PATH):
		_tex_noon = load(NOON_TEX_PATH) as Texture2D
	if ResourceLoader.exists(DUSK_TEX_PATH):
		_tex_dusk = load(DUSK_TEX_PATH) as Texture2D


func bind_world(sun: DirectionalLight3D, world_env: WorldEnvironment) -> void:
	_sun_light = sun
	_world_env = world_env
	if _sun_light != null:
		_sun_light.shadow_enabled = true
		_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sun_light.directional_shadow_max_distance = 64.0
		_sun_light.directional_shadow_blend_splits = true
		_sun_light.light_angular_distance = 0.0
		_sun_light.shadow_bias = 0.012
		_sun_light.shadow_normal_bias = 1.2
		_sun_light.shadow_blur = 0.25
		_sun_light.directional_shadow_split_1 = 0.12
		_sun_light.directional_shadow_split_2 = 0.28
		_sun_light.directional_shadow_split_3 = 0.55
	if _world_env != null and _world_env.environment != null:
		_env_instance = _world_env.environment.duplicate() as Environment
		_world_env.environment = _env_instance
	_apply_world_lighting(0.0)


func set_zone_context(zone_id: String) -> void:
	_is_underground_zone = (zone_id == "zone_3_crypt" or zone_id == "zone_4_mines" or zone_id.contains("crypt") or zone_id.contains("mine") or zone_id.contains("cave"))
	_apply_world_lighting(0.0)


func is_underground() -> bool:
	return _is_underground_zone


func set_time_of_day(new_time: float) -> void:
	time_of_day = fposmod(new_time, 1.0)
	_target_advance_time = -1.0
	_check_phase_change()
	_apply_world_lighting(0.0)
	queue_redraw()


func advance_to_next_phase() -> void:
	# Avança suavemente para a próxima fase (Amanhecer -> Meio-Dia -> Entardecer -> Noite)
	var phases: Array[float] = [0.25, 0.50, 0.75, 1.0]
	var next_t: float = 0.25
	for p in phases:
		if p > time_of_day + 0.04:
			next_t = p
			break
		if p == 1.0 and time_of_day < 0.21:
			next_t = 0.25
			break
	if next_t >= 1.0:
		next_t = 0.0
	set_time_of_day(next_t)


func get_current_phase_id() -> String:
	var t: float = fposmod(time_of_day, 1.0)
	if t >= 0.16 and t < 0.36:
		return "dawn"
	elif t >= 0.36 and t < 0.64:
		return "noon"
	elif t >= 0.64 and t < 0.84:
		return "dusk"
	return "night"


func get_sun_orbit_angle() -> float:
	# 0.00 (Noite) -> +90° (Fundo)
	# 0.25 (Amanhecer) -> 180° (Esquerda)
	# 0.37 (Manhã) -> 225° (Superior-Esquerdo)
	# 0.50 (Meio-Dia) -> 270° / -90° (Topo)
	# 0.75 (Entardecer) -> 0° / 360° (Direita)
	return fposmod((time_of_day + 0.25) * TAU, TAU)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			advance_to_next_phase()
			accept_event()


func _process(delta: float) -> void:
	_pulse_time += delta
	if not cycle_paused and cycle_duration_seconds > 0.1:
		time_of_day = fposmod(time_of_day + (delta / cycle_duration_seconds), 1.0)
	_check_phase_change()
	_apply_world_lighting(delta)
	queue_redraw()


func _check_phase_change() -> void:
	var new_phase: String = get_current_phase_id()
	if new_phase != _current_phase_id:
		_current_phase_id = new_phase
		phase_changed.emit(_current_phase_id)


# ============================================================================
# SISTEMA DE ILUMINAÇÃO DINÂMICA & SOMBRAS 3D (SOL / LUA / AMBIENTE / TOCHAS)
# ============================================================================
func _apply_world_lighting(_delta: float) -> void:
	var t: float = fposmod(time_of_day, 1.0)
	var state: Dictionary = _evaluate_lighting_state(t)

	if _sun_light != null:
		if _is_underground_zone:
			_sun_light.light_color = Color(0.42, 0.52, 0.78)
			_sun_light.light_energy = 0.45
			_sun_light.shadow_opacity = 0.72
			_sun_light.rotation = Vector3(-0.95, 0.45, 0.0)
		else:
			_sun_light.light_color = state["sun_color"] as Color
			_sun_light.light_energy = float(state["sun_energy"])
			_sun_light.shadow_opacity = float(state["shadow_opacity"])
			_sun_light.rotation = state["sun_rotation"] as Vector3

	if _env_instance != null:
		if _is_underground_zone:
			_env_instance.background_color = Color(0.02, 0.02, 0.035, 1.0)
			_env_instance.ambient_light_color = Color(0.16, 0.19, 0.28, 1.0)
			_env_instance.ambient_light_energy = 0.35
		else:
			_env_instance.background_color = state["bg_color"] as Color
			_env_instance.ambient_light_color = state["ambient_color"] as Color
			_env_instance.ambient_light_energy = float(state["ambient_energy"])

	# Ajusta o brilho das tochas, braseiros e fogueira da vila conforme escurece
	if is_inside_tree():
		var torch_mult: float = float(state["torch_multiplier"])
		var flicker: float = 1.0 + 0.06 * sin(_pulse_time * 5.2) + 0.03 * cos(_pulse_time * 8.7)
		for node in get_tree().get_nodes_in_group("day_night_torch_light"):
			if node is OmniLight3D and is_instance_valid(node):
				var light := node as OmniLight3D
				var base_e: float = 1.15 if light.name == "TownCampfireLight" else (0.95 if light.name == "ShrineFireLight" else (0.45 if light.name == "StationFireLight" else 0.65))
				light.light_energy = base_e * torch_mult * flicker


func _evaluate_lighting_state(t: float) -> Dictionary:
	# 5 Keyframes balanceados para ARPG Dark Fantasy Low-Poly:
	# • Manhã: iluminação suavemente quente, sombras longas e expressivas.
	# • Meio-dia: luz clara e neutra/branca (Color(0.98, 0.99, 1.0)), cores naturais das texturas, sombras curtas e nítidas.
	# • Tarde: tonalidade dourada/âmbar moderada, sombras alongadas de entardecer.
	# • Noite: ambiente azul escuro (dark fantasy), excelente contraste e legibilidade, fogueiras brilhando.
	var kf_night := {
		"sun_color": Color(0.46, 0.60, 0.90),
		"sun_energy": 0.58,
		"shadow_opacity": 0.78,
		"ambient_color": Color(0.12, 0.16, 0.28),
		"ambient_energy": 0.24,
		"bg_color": Color(0.015, 0.018, 0.038),
		"pitch": -0.78,
		"yaw": 0.45,
		"torch_multiplier": 1.30,
	}
	var kf_dawn := {
		"sun_color": Color(0.98, 0.92, 0.85),
		"sun_energy": 1.15,
		"shadow_opacity": 0.88,
		"ambient_color": Color(0.52, 0.58, 0.68),
		"ambient_energy": 0.28,
		"bg_color": Color(0.06, 0.07, 0.12),
		"pitch": -0.52,
		"yaw": 0.85,
		"torch_multiplier": 0.35,
	}
	var kf_morning := {
		"sun_color": Color(0.98, 0.99, 1.0),
		"sun_energy": 1.28,
		"shadow_opacity": 0.92,
		"ambient_color": Color(0.58, 0.64, 0.74),
		"ambient_energy": 0.30,
		"bg_color": Color(0.08, 0.12, 0.18),
		"pitch": -0.88,
		"yaw": 0.40,
		"torch_multiplier": 0.04,
	}
	var kf_afternoon := {
		"sun_color": Color(0.98, 0.99, 1.0),
		"sun_energy": 1.28,
		"shadow_opacity": 0.92,
		"ambient_color": Color(0.58, 0.64, 0.74),
		"ambient_energy": 0.30,
		"bg_color": Color(0.08, 0.12, 0.18),
		"pitch": -0.88,
		"yaw": -0.40,
		"torch_multiplier": 0.04,
	}
	var kf_dusk := {
		"sun_color": Color(0.98, 0.82, 0.68),
		"sun_energy": 1.08,
		"shadow_opacity": 0.88,
		"ambient_color": Color(0.44, 0.42, 0.56),
		"ambient_energy": 0.26,
		"bg_color": Color(0.06, 0.05, 0.09),
		"pitch": -0.50,
		"yaw": -0.85,
		"torch_multiplier": 0.65,
	}

	var a: Dictionary
	var b: Dictionary
	var local_t: float = 0.0
	if t < 0.22:
		a = kf_night
		b = kf_dawn
		local_t = smoothstep(0.0, 1.0, t / 0.22)
	elif t < 0.33:
		a = kf_dawn
		b = kf_morning
		local_t = smoothstep(0.0, 1.0, (t - 0.22) / 0.11)
	elif t < 0.66:
		a = kf_morning
		b = kf_afternoon
		local_t = smoothstep(0.0, 1.0, (t - 0.33) / 0.33)
	elif t < 0.78:
		a = kf_afternoon
		b = kf_dusk
		local_t = smoothstep(0.0, 1.0, (t - 0.66) / 0.12)
	else:
		a = kf_dusk
		b = kf_night
		local_t = smoothstep(0.0, 1.0, (t - 0.78) / 0.22)

	var pitch: float = lerpf(float(a["pitch"]), float(b["pitch"]), local_t)
	var yaw: float = lerpf(float(a["yaw"]), float(b["yaw"]), local_t)

	return {
		"sun_color": (a["sun_color"] as Color).lerp(b["sun_color"] as Color, local_t),
		"sun_energy": lerpf(float(a["sun_energy"]), float(b["sun_energy"]), local_t),
		"shadow_opacity": lerpf(float(a["shadow_opacity"]), float(b["shadow_opacity"]), local_t),
		"ambient_color": (a["ambient_color"] as Color).lerp(b["ambient_color"] as Color, local_t),
		"ambient_energy": lerpf(float(a["ambient_energy"]), float(b["ambient_energy"]), local_t),
		"bg_color": (a["bg_color"] as Color).lerp(b["bg_color"] as Color, local_t),
		"sun_rotation": Vector3(pitch, yaw, 0.0),
		"torch_multiplier": lerpf(float(a["torch_multiplier"]), float(b["torch_multiplier"]), local_t),
	}


# ============================================================================
# RENDERIZAÇÃO ARTÍSTICA DO RELÓGIO DE SOL E LUA NO HUD (SEM HORA DIGITAL)
# ============================================================================
func _draw() -> void:
	var w: float = size.x if size.x > 10.0 else WIDGET_SIZE
	var h: float = size.y if size.y > 10.0 else WIDGET_SIZE
	var center := Vector2(w * 0.5, h * 0.5)
	var inner_diam: float = w * INNER_SCENE_RATIO
	var inner_radius: float = inner_diam * 0.5
	var inner_rect := Rect2(center - Vector2(inner_radius, inner_radius), Vector2(inner_diam, inner_diam))

	# 1. Sombra suave projetada atrás do medalhão do relógio no HUD
	draw_circle(center + Vector2(0.0, 3.0), inner_radius + 12.0, Color(0.0, 0.0, 0.0, 0.55))

	# 2. Cena Interna Circular com transição contínua (Noite -> Amanhecer -> Meio-Dia -> Entardecer -> Noite)
	_draw_inner_sky_scene(center, inner_radius, inner_rect)

	# 3. Trilha luminosa dourada acompanhando a posição atual do Sol ao redor do aro interno
	var sun_angle: float = get_sun_orbit_angle()
	var orbit_r: float = w * ORBIT_RADIUS_RATIO
	_draw_ring_sun_glow_track(center, orbit_r, sun_angle)

	# 4. Moldura Ornamentada de Bronze e Ouro com os 4 Diamantes Cardeais
	if _tex_frame != null:
		draw_texture_rect(_tex_frame, Rect2(Vector2.ZERO, Vector2(w, h)), false)
	else:
		draw_arc(center, orbit_r, 0.0, TAU, 48, Color(0.76, 0.56, 0.24, 1.0), 6.0, true)

	# 5. Emblema Animado do Sol Orbitando o Aro (sem exibir números de horas!)
	var sun_pos: Vector2 = center + Vector2(cos(sun_angle), sin(sun_angle)) * orbit_r
	_draw_orbiting_sun_emblem(sun_pos, w / WIDGET_SIZE)


func _draw_inner_sky_scene(center: Vector2, inner_radius: float, inner_rect: Rect2) -> void:
	var t: float = fposmod(time_of_day, 1.0)
	var tex_a: Texture2D = _tex_night
	var tex_b: Texture2D = _tex_dawn
	var blend: float = 0.0

	if t < 0.25:
		tex_a = _tex_night
		tex_b = _tex_dawn
		blend = smoothstep(0.0, 1.0, t / 0.25)
	elif t < 0.50:
		tex_a = _tex_dawn
		tex_b = _tex_noon
		blend = smoothstep(0.0, 1.0, (t - 0.25) / 0.25)
	elif t < 0.75:
		tex_a = _tex_noon
		tex_b = _tex_dusk
		blend = smoothstep(0.0, 1.0, (t - 0.50) / 0.25)
	else:
		tex_a = _tex_dusk
		tex_b = _tex_night
		blend = smoothstep(0.0, 1.0, (t - 0.75) / 0.25)

	if tex_a != null and tex_b != null:
		draw_texture_rect(tex_a, inner_rect, false, Color(1.0, 1.0, 1.0, 1.0))
		if blend > 0.005:
			draw_texture_rect(tex_b, inner_rect, false, Color(1.0, 1.0, 1.0, blend))
	else:
		# Fallback procedural caso rode sem texturas
		var sky_col := Color(0.12, 0.16, 0.34).lerp(Color(0.28, 0.56, 0.88), sin(t * PI))
		draw_circle(center, inner_radius, sky_col)

	# Efeitos atmosféricos vivos dentro do mostrador:
	# - Cintilação suave das estrelas e janelas do castelo à noite
	var night_factor: float = clampf(1.0 - sin(t * PI) * 1.45, 0.0, 1.0)
	if night_factor > 0.05:
		var star_offsets: Array[Vector2] = [
			Vector2(-0.26, -0.52),
			Vector2(-0.02, -0.32),
			Vector2(-0.44, -0.22),
			Vector2(0.14, -0.62),
		]
		for idx in range(star_offsets.size()):
			var sp: Vector2 = center + star_offsets[idx] * inner_radius
			var twinkle: float = (0.45 + 0.55 * sin(_pulse_time * (2.6 + float(idx) * 0.7) + float(idx) * 1.9)) * night_factor
			draw_circle(sp, 1.35, Color(0.95, 0.97, 1.0, twinkle * 0.85))

		# Brilho quente vivo nas janelas do castelo à noite/crepúsculo
		var win_alpha: float = (0.22 + 0.12 * sin(_pulse_time * 3.8)) * night_factor
		draw_circle(center + Vector2(0.18, 0.38) * inner_radius, 3.2, Color(1.0, 0.68, 0.22, win_alpha))
		draw_circle(center + Vector2(0.35, 0.42) * inner_radius, 3.6, Color(1.0, 0.68, 0.22, win_alpha))


func _draw_ring_sun_glow_track(center: Vector2, orbit_r: float, sun_angle: float) -> void:
	# Ilumina o trilho interno do aro com luz dourada quente ao redor da posição atual do Sol
	for step in range(5):
		var frac: float = 1.0 - (float(step) / 5.0)
		var span: float = lerpf(0.18, 0.72, 1.0 - frac)
		var alpha: float = lerpf(0.10, 0.42, frac)
		draw_arc(
			center,
			orbit_r,
			sun_angle - span,
			sun_angle + span,
			24,
			Color(1.0, 0.68, 0.18, alpha),
			7.5 * (0.7 + 0.3 * frac),
			true
		)


func _draw_orbiting_sun_emblem(sun_pos: Vector2, scale_f: float) -> void:
	# Durante a madrugada profunda (perto do fundo do aro), os raios retraem suavemente
	# deixando o orbe solar compacto como nos 2 mostradores noturnos da referência!
	var t: float = fposmod(time_of_day, 1.0)
	var day_ray_factor: float = smoothstep(0.08, 0.20, t) * (1.0 - smoothstep(0.82, 0.94, t))
	var pulse: float = 1.0 + 0.06 * sin(_pulse_time * 3.4)

	# 1. Halo luminoso dourado/âmbar externo em múltiplas camadas
	draw_circle(sun_pos, 18.0 * scale_f * pulse, Color(1.0, 0.56, 0.10, 0.16))
	draw_circle(sun_pos, 13.5 * scale_f * pulse, Color(1.0, 0.68, 0.16, 0.30))
	draw_circle(sun_pos, 10.0 * scale_f, Color(1.0, 0.82, 0.28, 0.52))

	# 2. Coroa de 8 Pontas / Raios Solares Dourados (idêntico à arte de referência)
	if day_ray_factor > 0.02:
		var num_rays: int = 8
		var inner_r: float = 6.8 * scale_f
		var outer_r: float = (12.8 + 0.8 * sin(_pulse_time * 4.0)) * scale_f * lerpf(0.58, 1.0, day_ray_factor)
		var half_base_angle: float = 0.21
		var rot_offset: float = _pulse_time * 0.22
		for i in range(num_rays):
			var a: float = rot_offset + TAU * float(i) / float(num_rays)
			var tip: Vector2 = sun_pos + Vector2(cos(a), sin(a)) * outer_r
			var p1: Vector2 = sun_pos + Vector2(cos(a - half_base_angle), sin(a - half_base_angle)) * inner_r
			var p2: Vector2 = sun_pos + Vector2(cos(a + half_base_angle), sin(a + half_base_angle)) * inner_r
			var pts := PackedVector2Array([p1, tip, p2])
			var cols := PackedColorArray([
				Color(1.0, 0.74, 0.18, 0.95 * day_ray_factor),
				Color(1.0, 0.92, 0.48, 0.98 * day_ray_factor),
				Color(1.0, 0.74, 0.18, 0.95 * day_ray_factor),
			])
			draw_polygon(pts, cols)

	# 3. Disco Solar Central com borda ouro-bronze e núcleo incandescente
	var core_r: float = lerpf(5.6, 7.2, day_ray_factor) * scale_f
	draw_circle(sun_pos, core_r + 1.3 * scale_f, Color(0.96, 0.62, 0.12, 0.98))
	draw_circle(sun_pos, core_r, Color(1.0, 0.88, 0.36, 1.0))
	draw_circle(sun_pos, core_r * 0.72, Color(1.0, 0.97, 0.76, 1.0))
