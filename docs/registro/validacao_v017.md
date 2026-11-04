# Evidências de validação v0.17

## Realizadas neste ambiente
- Auditoria de `main.gd`, `enemy.gd`, `player.gd` e `attack_controller.gd` disponíveis.
- Verificação de existência de arquivos referenciados via `preload()` / `load()`.
- Verificação do escopo do patch: somente `scripts/main.gd` é substituído; demais arquivos são novos.
- Conferência numérica independente em Python do mesmo algoritmo: 10 XP -> nível 1; +5 XP -> nível 2, 3 XP restante; +100 XP -> nível 5, 29 XP restante e 4 escolhas pendentes; XP negativo ignorado.

## Não realizadas
- Execução/parsing do GDScript no motor Godot (o binário não está disponível neste ambiente).
- Execução F5, teste visual da HUD e teste com modelos locais do usuário.
- Teste automatizado dentro do Godot: incluído para rodar localmente em `tests/progression/test_run_progression.gd`.

**Status:** código preparado e conferido estruturalmente; aprovação funcional depende do Godot 4.7.2 do desenvolvedor.
