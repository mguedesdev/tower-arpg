# Registro v0.7.1 — Nomes de clipes importados

**Problema:** laboratorio revelou clipes `walk`, `idle`, `attack`, mas codigo buscava nomes terminados em `-loop`.

**Causa:** sufixos de Actions/NLA nao foram preservados nos nomes finais pelo importador, diferentemente do pressuposto original.

**Mudancas:** `player.gd` e `animation_lab.gd` reconhecem alias sem sufixo e nomes com prefixo de biblioteca. `loop_mode` de Walk/Idle e aplicado usando o nome efetivamente encontrado; Attack permanece sem repeticao.

**Preservado:** gameplay, movimento, rotacao, dano, inimigos, rig, mesh, exportador e efeitos.

**Teste pendente no Godot:** executar laboratorio F6, reproduzir Walk 10s e Idle 10s, verificar pernas; testar jogo F5 e continuidade durante ataque. Qualidade do Attack permanece uma tarefa futura.

**Reversao:** restaurar apenas os dois scripts a partir do backup.
