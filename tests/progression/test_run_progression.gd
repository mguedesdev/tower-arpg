extends SceneTree
## Executar: godot --headless --path /caminho/do/projeto --script res://tests/progression/test_run_progression.gd

var _failures: int = 0

func _initialize() -> void:
    call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error("FALHOU: " + message)
    else:
        print("OK: " + message)

func _run_tests() -> void:
    var service := RunProgressionService.new()
    root.add_child(service)

    _check(service.state.level == 1 and service.state.xp == 0, "Começa em nível 1 e 0 XP")
    _check(service.balance.xp_to_next_level(1) == 12, "Curva inicial editável")
    service.grant_xp(10)
    _check(service.state.level == 1 and service.state.xp == 10, "XP parcial")
    service.grant_xp(5)
    _check(service.state.level == 2 and service.state.xp == 3, "XP excedente preservado")
    _check(service.state.pending_upgrade_choices == 1, "Escolha de nível enfileirada")

    service.grant_xp(100)
    _check(service.state.level == 5, "Múltiplos níveis em um único ganho")
    _check(service.state.pending_upgrade_choices == 4, "Todas as escolhas enfileiradas")
    _check(service.state.xp == 29, "XP excedente após múltiplos níveis")
    _check(service.resolve_one_upgrade_choice(), "Consome uma escolha por vez")
    _check(service.state.pending_upgrade_choices == 3, "Fila diminui exatamente um")

    service.grant_xp(-10)
    _check(service.state.total_xp == 115, "XP negativo não modifica o total")

    var other := RunProgressionService.new()
    root.add_child(other)
    _check(other.state.level == 1 and other.state.pending_upgrade_choices == 0, "Instâncias não compartilham estado")

    service.reset_run()
    _check(service.state.level == 1 and service.state.xp == 0, "Nova partida reinicia XP e nível")
    _check(service.state.pending_upgrade_choices == 0, "Nova partida limpa escolhas temporárias")

    service.queue_free()
    other.queue_free()
    if _failures > 0:
        print("TESTES FALHARAM: %d" % _failures)
        quit(1)
    else:
        print("TESTES PASSARAM: Progressão XP e níveis")
        quit(0)
