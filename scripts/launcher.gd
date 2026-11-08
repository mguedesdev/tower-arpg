extends Control
class_name GameLauncherController
## Tela Inicial / Launcher para escolher entre o MODO ARPG e o INFINITY TOWER.
## Separação 100% limpa entre os dois projetos.

@onready var btn_arpg: Button = $CenterContainer/MainPanel/VBoxContainer/CardsContainer/ARPGCard/VBox/BtnPlayARPG
@onready var btn_tower: Button = $CenterContainer/MainPanel/VBoxContainer/CardsContainer/TowerCard/VBox/BtnPlayTower
@onready var btn_quit: Button = $CenterContainer/MainPanel/VBoxContainer/Footer/BtnQuit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	if btn_arpg != null:
		btn_arpg.pressed.connect(_on_play_arpg_pressed)
		btn_arpg.grab_focus()
	if btn_tower != null:
		btn_tower.pressed.connect(_on_play_tower_pressed)
	if btn_quit != null:
		btn_quit.pressed.connect(_on_quit_pressed)


func _on_play_arpg_pressed() -> void:
	var lm := LoadingManager.get_instance()
	if lm != null:
		lm.transition_to_scene(
			"res://scenes/arpg/arpg_game.tscn",
			"DARK FANTASY ARPG",
			"Ato 1: As Terras de Velen • Explorando o mundo...",
			"res://assets/ui/world_map/01_vila_de_velen.png"
		)
	else:
		get_tree().change_scene_to_file("res://scenes/arpg/arpg_game.tscn")


func _on_play_tower_pressed() -> void:
	var lm := LoadingManager.get_instance()
	if lm != null:
		lm.transition_to_scene(
			"res://scenes/tower/tower_game.tscn",
			"INFINITY TOWER",
			"Arena da Torre do Santuário • Sobrevivência por Ondas...",
			""
		)
	else:
		get_tree().change_scene_to_file("res://scenes/tower/tower_game.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
