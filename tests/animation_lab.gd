extends Node3D
## Laboratorio independente da jogabilidade. Testa as Actions importadas diretamente.
## 1 = Estocada, 2 = Meia-lua, 3 = Giro 360, 4 = Walk, 5 = Idle, 6 = Ataque antigo.
const MODEL_PATH := "res://assets/models/knight.glb"
var actor: Node3D
var animator: AnimationPlayer
var current_clip := ""
var info: Label
var diagnostic := ""

func _ready() -> void:
    _setup_scene()
    if not ResourceLoader.exists(MODEL_PATH):
        _set_error("ARQUIVO AUSENTE: " + MODEL_PATH + "\nGere o GLB pelo Blender antes de testar.")
        return
    var packed: PackedScene = load(MODEL_PATH) as PackedScene
    if packed == null:
        _set_error("O arquivo knight.glb nao foi importado como uma cena.")
        return
    actor = packed.instantiate() as Node3D
    if actor == null:
        _set_error("A raiz do arquivo knight.glb nao e um Node3D.")
        return
    actor.name = "KnightDiagnostic"
    add_child(actor)
    animator = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if animator == null:
        _set_error("GLB sem AnimationPlayer. Problema no Blender ou na exportacao.")
        return

    var bones: Skeleton3D = actor.find_child("Skeleton3D", true, false) as Skeleton3D
    diagnostic = "Esqueleto: %s ossos\n" % (str(bones.get_bone_count()) if bones != null else "NAO ENCONTRADO")
    diagnostic += "Animacoes importadas:\n"
    for key in animator.get_animation_list():
        var clip: Animation = animator.get_animation(key)
        if clip == null:
            continue
        diagnostic += "  %s : %.2fs, %d trilhas\n" % [String(key), clip.length, clip.get_track_count()]
    print("=== LABORATORIO DE ANIMACOES ===\n", diagnostic)
    if animator.get_animation_list().is_empty():
        _set_error("O GLB nao possui animacoes. Corrija a exportacao no Blender.")
        return

    _play_clip("attack_stab")

func _setup_scene() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.09, 0.10, 0.12)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.65, 0.68, 0.75)
    env.ambient_light_energy = 0.65
    env_node.environment = env
    add_child(env_node)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, -25, 0)
    light.light_energy = 1.65
    add_child(light)

    var camera := Camera3D.new()
    camera.position = Vector3(2.0, 2.3, -5.0)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 3.6
    add_child(camera)
    camera.look_at(Vector3(0, 0.9, 0))
    camera.current = true

    var ground := MeshInstance3D.new()
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(10, 10)
    ground.mesh = ground_mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.21, 0.23, 0.26)
    ground.material_override = mat
    add_child(ground)

    var canvas := CanvasLayer.new()
    add_child(canvas)
    info = Label.new()
    info.position = Vector2(24, 20)
    info.add_theme_font_size_override("font_size", 19)
    canvas.add_child(info)

func _find_clip(requested: String) -> String:
    if animator == null:
        return ""
    var aliases: Array[String] = [requested]
    if requested.ends_with("-loop"):
        aliases.append(requested.trim_suffix("-loop"))
    for alias in aliases:
        for key in animator.get_animation_list():
            var name: String = String(key)
            if name == alias or name.ends_with("/" + alias) or name.ends_with("|" + alias):
                return name
    return ""

func _play_clip(suffix: String) -> void:
    if animator == null:
        return
    var name := _find_clip(suffix)
    if name.is_empty():
        _set_error("CLIP AUSENTE: " + suffix + "\n" + diagnostic)
        return
    var clip := animator.get_animation(name)
    if suffix == "walk-loop" or suffix == "idle-loop":
        clip.loop_mode = Animation.LOOP_LINEAR
    else:
        clip.loop_mode = Animation.LOOP_NONE
    animator.speed_scale = 1.0
    animator.play(name, 0.0)
    current_clip = name
    _update_info()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_1:
            _play_clip("attack_stab")
        KEY_2:
            _play_clip("attack_arc")
        KEY_3:
            _play_clip("attack_spin")
        KEY_4:
            _play_clip("walk-loop")
        KEY_5:
            _play_clip("idle-loop")
        KEY_6:
            if not _find_clip("attack_pierce").is_empty():
                _play_clip("attack_pierce")
            else:
                _play_clip("attack")
        KEY_SPACE:
            if animator != null:
                if animator.is_playing():
                    animator.pause()
                elif not current_clip.is_empty():
                    animator.play()
                _update_info()

func _process(_delta: float) -> void:
    _update_info()

func _update_info() -> void:
    if info == null:
        return
    var status := "LABORATORIO DE ANIMACOES (sem gameplay)\n1 = ESTOCADA | 2 = MEIA-LUA | 3 = GIRO 360\n4 = WALK | 5 = IDLE | 6 = PERFURACAO (PIERCE) | ESPACO = PAUSAR\n\n"
    if animator != null and not current_clip.is_empty():
        var clip := animator.get_animation(current_clip)
        status += "Reproduzindo: %s | %.2f / %.2f segundos | tocando=%s\n" % [current_clip, animator.current_animation_position, clip.length, str(animator.is_playing())]
    info.text = status + diagnostic

func _set_error(message: String) -> void:
    diagnostic = "ERRO: " + message
    push_error(diagnostic)
    if info != null:
        info.text = diagnostic
