# Registro — v0.18 HUD Dark Fantasy

## Demanda
Usuário solicitou uma HUD muito melhor no protótipo de ação 3D low-poly.

## Auditoria
- `scripts/main.gd` v0.17 ainda atualiza os nós `HUD/Info/*` e `HUD/StatusLabel`.
- A HUD de XP da v0.17 é criada em runtime por `RunXpHUD` e recebe o serviço de progressão através de `attach_progression`.
- O serviço publica `progress_changed`, `level_gained` e `choices_changed`.
- `TowerPlayer` publica `health_changed` e `died`.
- `TowerAttackController` publica `form_changed`.

## Estratégia de compatibilidade
Substituir APENAS o script da HUD de XP, mantendo a interface pública `RunXpHUD.attach_progression(service)`. Em runtime, o novo script esconde visualmente os nós antigos, mas não os remove, porque o script principal ainda os referencia.

## Arquivos modificados
- `game/ui/progression/run_xp_hud.gd`

## Arquivos adicionados
- `game/ui/icons/stab.png`
- `game/ui/icons/arc.png`
- `game/ui/icons/spin.png`
- `docs/ui/hud_v018_previa_conceitual.png`
- `docs/registro/2026-11-04_v018_hud_dark_fantasy.md`
- `LEIA_PRIMEIRO.md`

## UI
- Estética dark fantasy: grafite, marfim, verde espectral, dourado e vermelho.
- Vida, XP, wave, abates e forma de ataque atual baseados nos dados verdadeiros do jogo.
- Animação suave das barras de vida e XP.
- Layout responsivo por largura; mouse passthrough para não impedir gameplay.
- Feedback de nível, wave e derrota.
- Texto explicita que evoluções estão pendentes, sem simular cartas ainda inexistentes.

## Decisões
- Não adicionar pacotes externos ou fontes.
- Não acoplar o HUD ao sistema de dano/XP; conectar apenas aos sinais existentes.
- Não modificar main.gd nem main.tscn.
- Não criar cartas de evolução nesta versão, pois faz parte do próximo vertical slice.

## Testes realizados
- Inspeção de contratos (nomes de sinais, nós e chamadas a partir do `main.gd` v0.17).
- Inspeção de arquivos PNG e organização do ZIP.
- Conferência de escopo dos arquivos do patch.

## Testes pendentes
- Godot 4.x: importação dos ícones PNG, parsing GDScript e execução do projeto.
- Gameplay: atualização real de HP, XP, wave, abates e seleção de habilidades.
- HUD em diferentes proporções de tela e escalas de DPI.

## Riscos conhecidos
- Se a versão local do projeto divergir da v0.17 e não instanciar `RunXpHUD`, a nova interface não será criada automaticamente.
- Layout compacto ainda precisa ser validado especialmente em telas pequenas de celular.
