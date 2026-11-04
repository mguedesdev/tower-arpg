extends SceneTree
## Suite de Testes do Sistema de Combate Ativo ARPG (Skills, Slots, Formas de Ataque, Limite de 4 Skills e HUD)
## Executar: Godot_v4.7.2-stable_win64_console.exe --headless --path "c:\Users\mathh\OneDrive\Documents\jogo" --script res://tests/progression/test_arpg_combat_suite.gd

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SKILL_DEF_SCRIPT = preload("res://core/combat/skill_definition.gd")
const SKILL_CTRL_SCRIPT = preload("res://scripts/player_skill_controller.gd")

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[OK] " + label)
	else:
		_failed += 1
		push_error("[FALHOU] " + label)


func _run_all() -> void:
	print("=== INICIANDO SUITE DE TESTES: COMBATE ATIVO ARPG & SKILLS ===")
	_test_skill_definitions_and_warrior_skills()
	_test_slot_assignment_and_four_skill_limit()
	_test_skill_shapes_and_geometry()
	_test_damage_and_cooldown_mechanics()
	_test_scene_integration_skillbar_and_modes()

	print("=== RESULTADO ARPG COMBAT: %d PASSARAM | %d FALHARAM ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_skill_definitions_and_warrior_skills() -> void:
	var skills: Dictionary = SKILL_DEF_SCRIPT.build_warrior_skills()
	_check(skills.size() == 5, "1. Guerreiro possui 5 habilidades configuradas (1 basica + 4 ativas)")
	_check(skills.has("basic_stab") and (skills["basic_stab"] as SkillDefinition).is_basic_attack, "2. Estocada frontal e o ataque basico inicial")
	_check(skills.has("cleave_arc") and not (skills["cleave_arc"] as SkillDefinition).is_basic_attack, "3. Corte em Meia-Lua e skill ativa")
	_check(skills.has("whirlwind_spin") and skills.has("impale_pierce") and skills.has("ember_strike"), "4. Redemoinho, Lanca Empaladora e Golpe Incandescente presentes")


func _test_slot_assignment_and_four_skill_limit() -> void:
	var ctrl := PlayerSkillController.new()
	root.add_child(ctrl)
	ctrl.load_class_skills(SKILL_DEF_SCRIPT.build_warrior_skills())

	# Slot default tem LMB = basic_stab
	_check(ctrl.slots[PlayerSkillController.SLOT_LMB] == "basic_stab", "5. Slot LMB inicializa com ataque basico (basic_stab)")

	# Pode atribuir ataque básico em quantos slots quiser sem estourar o limite de 4
	_check(ctrl.can_assign(PlayerSkillController.SLOT_1, "basic_stab"), "6a. Ataque basico pode ser atribuido livremente")

	# Limite de 4 skills ativas distintas
	# Atualmente tem: cleave_arc, whirlwind_spin, impale_pierce, ember_strike (4 ativas)
	_check(ctrl.count_distinct_active_skills() == 4, "6b. Inicialmente 4 skills ativas distintas equipadas")

	# Tentativa de adicionar uma 5ª skill ativa fictícia seria bloqueada
	var dummy_skill := SkillDefinition.new()
	dummy_skill.skill_id = "test_skill_5"
	dummy_skill.display_name = "Skill 5"
	dummy_skill.is_basic_attack = false
	ctrl.skills["test_skill_5"] = dummy_skill

	_check(not ctrl.can_assign(PlayerSkillController.SLOT_LMB, "test_skill_5"), "7. Bloqueia atribuicao de uma 5a skill ativa distinta (limite de 4)")

	# Esvaziar um slot permite trocar por outra
	ctrl.assign_slot(PlayerSkillController.SLOT_4, "")
	_check(ctrl.can_assign(PlayerSkillController.SLOT_4, "test_skill_5"), "8. Apos liberar slot, pode equipar a nova skill ativa")

	ctrl.queue_free()


func _test_skill_shapes_and_geometry() -> void:
	var skills: Dictionary = SKILL_DEF_SCRIPT.build_warrior_skills()
	var forward := Vector3.FORWARD # (0, 0, -1)

	# 1. Cone (Meia-Lua)
	var arc_def: SkillDefinition = skills["cleave_arc"]
	_check(PlayerSkillController.is_offset_inside_skill(arc_def, Vector3(0, 0, -1.8), forward), "9a. Meia-Lua atinge inimigo a frente dentro do raio")
	_check(not PlayerSkillController.is_offset_inside_skill(arc_def, Vector3(0, 0, 1.8), forward), "9b. Meia-Lua nao atinge inimigo nas costas")

	# 2. Circulo 360 (Redemoinho)
	var spin_def: SkillDefinition = skills["whirlwind_spin"]
	_check(PlayerSkillController.is_offset_inside_skill(spin_def, Vector3(0, 0, 1.8), forward), "10a. Redemoinho 360 atinge inimigo nas costas")
	_check(PlayerSkillController.is_offset_inside_skill(spin_def, Vector3(1.8, 0, 0), forward), "10b. Redemoinho 360 atinge inimigo na lateral")
	_check(not PlayerSkillController.is_offset_inside_skill(spin_def, Vector3(0, 0, 5.0), forward), "10c. Fora do raio do Redemoinho nao atinge")

	# 3. Linha / Perfuração (Lança Empaladora)
	var line_def: SkillDefinition = skills["impale_pierce"]
	_check(PlayerSkillController.is_offset_inside_skill(line_def, Vector3(0.2, 0, -3.2), forward), "11a. Lanca perfura inimigo alinhado a frente a 3.2m")
	_check(not PlayerSkillController.is_offset_inside_skill(line_def, Vector3(2.5, 0, -3.2), forward), "11b. Lanca nao atinge inimigo afastado lateralmente fora da linha")


func _test_damage_and_cooldown_mechanics() -> void:
	var stats := CharacterStats.new()
	stats.set_base_stat(CharacterStats.STAT_DAMAGE, 20.0)
	stats.set_base_stat(CharacterStats.STAT_CRIT_CHANCE, 0.0)
	stats.set_base_stat(CharacterStats.STAT_COOLDOWN_REDUCTION, 0.25) # -25% de CD

	var skills: Dictionary = SKILL_DEF_SCRIPT.build_warrior_skills()
	var stab: SkillDefinition = skills["basic_stab"]
	var cleave: SkillDefinition = skills["cleave_arc"]

	# Dano basico: 20 * 1.0 = 20
	_check(roundi(stats.get_damage() * stab.damage_multiplier) == 20, "12. Dano da Estocada calcula corretamente com multiplicador 1.0x")
	# Dano cleave: 20 * 1.25 = 25
	_check(roundi(stats.get_damage() * cleave.damage_multiplier) == 25, "13. Dano do Corte em Meia-Lua calcula 1.25x (25 de dano)")

	# Cooldown com CDR: cleave base 1.10s com -25% CDR = 0.825s
	var cd_calc: float = cleave.get_cooldown(stats)
	_check(absf(cd_calc - 0.825) < 0.05, "14. Reducao de recarga (CDR) reduz o cooldown da skill ativamente")


func _test_scene_integration_skillbar_and_modes() -> void:
	var main_node = MAIN_SCENE.instantiate()
	root.add_child(main_node)

	_check(main_node.skill_bar_hud != null, "15. Main instancia SkillBarHUD no HUD")
	_check(main_node.player != null and main_node.player.skill_controller != null, "16. Player possui PlayerSkillController anexado")

	# No lobby, skill bar invisivel e skill controller desativado
	_check(not main_node.skill_bar_hud.visible, "17. SkillBarHUD permanece invisivel no Lobby do Altar")
	_check(not main_node.player.skill_controller.enabled, "18. PlayerSkillController permanece desativado no Lobby do Altar")

	# Ao iniciar a Campanha ARPG
	main_node._start_campaign_mode()
	_check(main_node.skill_bar_hud.visible, "19. SkillBarHUD fica visivel ao entrar na Campanha")
	_check(main_node.player.skill_controller.enabled, "20. PlayerSkillController fica ativado ao entrar na Campanha")
	_check(not main_node.attack.auto_attack, "21. Ataque automatico da Torre fica desativado na Campanha (apenas combate ativo)")

	# Progressão ARPG: ritmo cadenciado e sem popups de cartas de sobrevivente
	var init_hp: int = main_node.player.stats.get_max_health()
	var init_str: int = int(roundi(main_node.player.stats.get_base_stat(CharacterStats.STAT_STRENGTH)))
	main_node.run_progression.grant_xp(50) # Atinge o nível 2 com balance ARPG
	_check(main_node.run_progression.state.level == 2, "22a. Ganho de XP cadenciado atinge nível 2 aos 50 XP")
	_check(not main_node.level_up_modal.visible, "22b. Modo ARPG não abre modal de cartas de sobrevivente ao subir de nível")
	_check(main_node.player.stats.get_max_health() == init_hp + 12, "22c. Nível 2 concedeu +12 de vida máxima passiva")
	_check(int(roundi(main_node.player.stats.get_base_stat(CharacterStats.STAT_STRENGTH))) == init_str + 2, "22d. Nível 2 concedeu +2 de Força passiva aos requisitos")

	# Ao morrer
	main_node._on_player_died()
	_check(not main_node.skill_bar_hud.visible, "23a. SkillBarHUD oculta ao morrer")
	_check(not main_node.player.skill_controller.enabled, "23b. PlayerSkillController desativa ao morrer")

	main_node.queue_free()
