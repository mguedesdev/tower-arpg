extends RefCounted
## Entrada publica para qualquer IA/sistema adicionar VFX ao jogo.
## As chamadas sao VISUAIS. Nao causam dano e nao dependem de cena do player.

const EFFECT_SCRIPT: Script = preload("res://scripts/vfx/tower_vfx_effect.gd")

enum Kind { STAB, ARC, SPIN, IMPACT, FIRE, CLAWS }


static func spawn(parent: Node3D, effect_kind: int, at_world: Vector3, world_forward: Vector3 = Vector3(0.0, 0.0, 1.0), size: float = 1.0) -> Node3D:
    if parent == null or not is_instance_valid(parent):
        return null
    var effect: Node3D = EFFECT_SCRIPT.new() as Node3D
    effect.set("kind", effect_kind)
    parent.add_child(effect)
    effect.global_position = at_world
    effect.scale = Vector3.ONE * clampf(size, 0.1, 5.0)
    var horizontal: Vector3 = Vector3(world_forward.x, 0.0, world_forward.z)
    if horizontal.length_squared() > 0.0001:
        effect.global_rotation.y = atan2(horizontal.x, horizontal.z)
    return effect


static func stab(parent: Node3D, at_world: Vector3, world_forward: Vector3, size: float = 1.0) -> Node3D:
    return spawn(parent, Kind.STAB, at_world, world_forward, size)


static func arc(parent: Node3D, at_world: Vector3, world_forward: Vector3, size: float = 1.0) -> Node3D:
    return spawn(parent, Kind.ARC, at_world, world_forward, size)


static func spin(parent: Node3D, at_world: Vector3, size: float = 1.0) -> Node3D:
    return spawn(parent, Kind.SPIN, at_world, Vector3(0, 0, 1), size)


static func impact(parent: Node3D, at_world: Vector3, size: float = 1.0) -> Node3D:
    return spawn(parent, Kind.IMPACT, at_world, Vector3(0, 0, 1), size)


static func fire_burst(parent: Node3D, at_world: Vector3, size: float = 1.0) -> Node3D:
    return spawn(parent, Kind.FIRE, at_world, Vector3(0, 0, 1), size)


static func claws(parent: Node3D, at_world: Vector3, world_forward: Vector3, size: float = 1.0) -> Node3D:
    return spawn(parent, Kind.CLAWS, at_world, world_forward, size)
