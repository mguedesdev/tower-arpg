# Progressão V0.17 — Contrato mínimo

## Estado temporário (`RunProgressionState`)
- `level`: começa em 1; nunca deve ficar abaixo de 1.
- `xp`: XP que já conta para o próximo nível.
- `total_xp`: XP acumulada nesta tentativa, sem descontos de level-up.
- `pending_upgrade_choices`: número de escolhas de level-up pendentes de resolução.
- Reset: cria novo estado por tentativa. Nenhum Resource compartilhado é modificado.

## Configuração (`ProgressionBalance`)
- `enemy_xp = 5` por morte.
- Curva `xp_para_próximo_nível = first_level_xp + xp_linear_growth × (nível−1) + xp_quadratic_growth × (nível−1)²`, mínimos de 1.
- Valores iniciais (12, 4, 1) são provisórios de teste.
- Edição em `content/progression/balance_dev.tres`.

## Serviço (`RunProgressionService`)
- Entrada: `grant_xp(amount)` ou `grant_enemy_kill_xp()`.
- Saída: sinais `progress_changed`, `level_gained`, `choices_changed`.
- Todo XP excedente permanece válido.
- Vários níveis por ganho enfileiram uma escolha por nível e emitem `level_gained` para cada um.
- `resolve_one_upgrade_choice()` existirá como contrato, mas o fluxo ainda não pode chamá-lo (nenhuma evolução é aplicada nesta etapa).
- `reset_run()` reinicia XP, nível e fila temporária.

## Visão de futuro (NÃO implementada nesta etapa)
- Gerador de três ofertas, requisitos e incompatibilidades.
- Definições orientadas a dados de Guerreiro, habilidades e evoluções.
- Cálculo central de atributos e modificadores.
- MetaProgression, Essência, save seguro, árvore e resultados.
- Pausa durante a escolha: futuramente UI com `process_mode=WHEN_PAUSED` e pausa do SceneTree, depois de a etapa de escolhas estar funcional.

## Critérios de aprovação
1. F5: jogador e arena continuam intactos; painel XP aparece.
2. Matar um inimigo: +5 XP, nunca duas vezes por morte.
3. Matar três inimigos do nível 1: nível 2, XP preservada (15−12 = 3).
4. Barra reflete XP/limiar real.
5. Reiniciar a partida: nível 1 e XP 0.
6. Sem erros do parser e sem regressões de mobilidade/ataques/waves.
7. Executar teste automatizado em Godot para múltiplos níveis e estados independentes.
