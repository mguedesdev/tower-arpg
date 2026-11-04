# V0.7 — Laboratório de animações (somente diagnóstico)

**Problemas informados:** `walk-loop` não funciona; animação de ataque está visualmente ruim.

**Constatações por revisão dos arquivos v0.6:**
- O Blender cria `walk-loop` nos frames 1–25 e `attack` nos frames 1–17.
- O exportador configura NLA e Actions, mas nenhuma validação de importação/visualização no Godot foi realizada.
- O `player.gd` combina `AnimationTree` e filtros de membros superiores; se falhar, recorre à reprodução direta que interrompe a caminhada no ataque.
- A animação de ataque foi criada com poses por rotação Euler, não revisada visualmente.

**Mudança implementada:** Cena de laboratório independente com seleção direta dos clipes importados, exibição de nomes/duração/trilhas e script de preview Blender. **Não altera gameplay nem rig.**

**A validar no computador:** F6 na cena `tests/animation_lab.tscn`; Play Walk/Attack diretamente no Blender; verificar se clips existem e qual etapa falha.

**Próxima tarefa:** uma única correção direcionada à origem identificada; depois redesenho das key poses de ataque.
