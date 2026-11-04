extends Resource
class_name ProgressionBalance
## Números da progressão temporária. Cada partida usa a mesma definição imutável.

@export_range(1, 100000, 1) var enemy_xp: int = 5
@export_range(1, 100000, 1) var first_level_xp: int = 12
@export_range(0, 100000, 1) var xp_linear_growth: int = 4
@export_range(0, 100000, 1) var xp_quadratic_growth: int = 1


func xp_to_next_level(current_level: int) -> int:
    var offset: int = maxi(current_level - 1, 0)
    # A conversão para float evita overflow intermediário em multiplicações de int.
    var required: float = float(first_level_xp) + float(xp_linear_growth) * float(offset)
    required += float(xp_quadratic_growth) * float(offset) * float(offset)
    return maxi(1, int(minf(required, 2147483000.0)))
