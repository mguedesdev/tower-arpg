# v0.17 — Progressão: XP e níveis

**Foco:** somente a primeira fatia funcional de progressão na partida.

## Criados
- `core/progression/progression_balance.gd`
- `core/progression/run_progression_state.gd`
- `core/progression/run_progression_service.gd`
- `content/progression/balance_dev.tres`
- `game/ui/progression/run_xp_hud.gd`
- `tests/progression/test_run_progression.gd`
- `docs/progression/auditoria_v017.md`
- `docs/progression/contrato_v017.md`

## Modificado
- `scripts/main.gd`: acrescenta serviço/HUD em runtime, concedendo XP a partir de evento de morte. Mantém o loop de waves e sinais anteriores.

## Não modificado
- `scenes/main.tscn`, `player.gd`, `enemy.gd`, `attack_controller.gd`
- rig, assets, animações, cenário, dano, controle, cooldowns

## Testes
- Checklist estático de estrutura/caminhos: executado durante empacotamento.
- Simulação independente da curva de XP: executada em Python como conferência matemática.
- Teste real da lógica GDScript: NÃO executado (Godot não instalado no ambiente). Executar teste headless ou pelo editor local.
- Teste visual F5: PENDENTE.

## Próxima dependência (somente após validação)
Gerador de ofertas válidas e 3 cartas de escolhas; aplicar uma evolução por nível pendente.
