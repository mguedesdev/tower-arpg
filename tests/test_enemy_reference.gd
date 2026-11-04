extends SceneTree
# Executar na pasta do projeto Godot:
# godot --headless --path . --script res://tests/test_enemy_reference.gd

func _initialize() -> void:
    var controller: TowerAttackController = TowerAttackController.new()
    assert(not controller._is_valid_enemy(null), "nulo precisa ser invalido")

    var wrong_type: Node = Node.new()
    assert(not controller._is_valid_enemy(wrong_type), "outro tipo precisa ser invalido")
    wrong_type.free()

    var alive_enemy: TowerEnemy = TowerEnemy.new()
    assert(controller._is_valid_enemy(alive_enemy), "inimigo vivo precisa ser valido")
    var stale_reference: Variant = alive_enemy
    alive_enemy.free()
    assert(not controller._is_valid_enemy(stale_reference), "referencia destruida nao pode causar erro")

    var queued_enemy: TowerEnemy = TowerEnemy.new()
    get_root().add_child(queued_enemy)
    queued_enemy.queue_free()
    assert(not controller._is_valid_enemy(queued_enemy), "inimigo enfileirado para destruicao precisa ser invalido")

    controller.free()
    print("PASSOU: validacao segura de referencias de inimigos")
    quit(0)
