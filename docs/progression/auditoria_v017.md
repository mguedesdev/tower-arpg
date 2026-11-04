# Auditoria — Progressão de personagem, v0.17

## Fontes realmente examinadas
- `TorreLowPoly_Godot_v03_Patio_Arcano.zip` (cena principal, main.gd, inimigos e jogador)
- `Hotfix_v081_Integracao_Ataques_Gameplay.zip` (player.gd e attack_controller.gd mais recentes disponíveis)
- `Atualizacao_v015_Esqueleto_Walk_Hit.zip` (enemy.gd, morte e dano de contato)
- Alterações posteriores disponíveis (v0.16 chão, v0.14–v0.15 rig): não introduzem progressão segundo conteúdo entregue.

**Limite da auditoria:** arquivos locais mais recentes do computador do desenvolvedor não estão acessíveis aqui. O patch supõe que `scripts/main.gd` ainda segue a interface da v0.3; antes de sobrescrever, preservar diferenças feitas localmente.

## Encontrado

| Componente | Situação | Contrato útil |
|---|---|---|
| `main.gd` | Gerencia waves e contador de abates | `_on_enemy_died()` recebe morte e já é ligado via `enemy.died.connect(...)` |
| `enemy.gd` | `TowerEnemy` possui `died` e `take_damage` | Emite `died` uma vez antes de `queue_free()` |
| `attack_controller.gd` | Escolha de estocada/meia-lua/giro por enum e ataque automático | Não possui `AbilityDefinition` / transformações orientadas a dados |
| `player.gd` | Vida, movimentação, animações e mira | Não possui classe configurável nem sistema de atributos central |
| HUD `main.tscn` | Vida, wave, abates, forma de ataque | Não tem XP nem nível |
| Salvar/carregar | Não existe nos scripts auditados | Ainda não implementar |
| Meta progresso / itens | Não existe nos scripts auditados | Ainda não implementar |

## Decisão
Nesta entrega, acrescentar SOMENTE progressão de XP e níveis por abate. Não migrar combat, estados de atributo, HUD atual ou cenas 3D. O código novo não precisa conhecer `TowerEnemy` ou o modelo Blender; `main.gd` é o adaptador entre eventos de morte e regras de progressão.

## Ponto de integração
`main.gd::_on_enemy_died()` concede `balance.enemy_xp` pela interface `run_progression.grant_enemy_kill_xp()`.

## Riscos
- Usuário modificou `main.gd` após a última cópia: comparar diferenças antes de substituir.
- Ainda não existe UI de três cartas nem aplicação de upgrades, portanto níveis geram CONTADOR de escolhas pendentes, não uma tela de seleção.
- O projeto visual do usuário pode usar HUD com layout diferente: HUD desta etapa usa painel separado criado via script.
- Não rodamos o motor Godot neste ambiente: validação em 4.7.2 no PC é pendente.
