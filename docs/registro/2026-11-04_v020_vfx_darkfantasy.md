# 2026-11-04 — v0.20 — Biblioteca de VFX Dark Fantasy

## Pedido
Criar/adaptar efeitos de ataque e particulas inspirados no arquivo de referencia enviado pelo usuario, com uma mensagem explicando a outra IA onde e quando usar.

## Decisao de engenharia
Nao usar o gerador Blender fornecido de maneira literal porque o jogo ja tem efeitos e orientacoes especificas no Godot, o exportador Blender poderia introduzir problemas de eixos/material/alpha, e o pedido prioriza reutilizacao. Em vez disso, os VFX sao geometrias low-poly procedurais nativas do Godot 4, criadas quando acionadas e liberadas automaticamente.

## Efeitos
- STAB — rastro de estocada / vento branco-azulado
- ARC — arco azul da Meia-lua
- SPIN — anel do Giro 360
- IMPACT — fragmentos claros de impacto
- FIRE — pequenas lascas incandescentes de fogo, reservado para quando fogo existir de verdade
- CLAWS — cortes vermelhos, reservados ao evento de contato/ataque real do lobo

## Regras de seguranca gameplay
- Nenhum VFX aplica dano, velocidade, impulso ou area de acerto.
- Nenhum script existente do usuario e substituido.
- Limite de 36 efeitos ativos; duracao maxima de 0.40 s.
- Posicao e direcao explicitas para evitar orientacao invertida.
- Nao invocar hit effects assumindo que qualquer animação possui hitbox.

## Novos arquivos
- scripts/vfx/tower_vfx_effect.gd
- scripts/vfx/tower_vfx_spawner.gd
- scripts/vfx/vfx_gallery.gd
- scenes/vfx/vfx_gallery.tscn
- docs/vfx/MENSAGEM_PARA_OUTRA_IA.md
- tests/vfx/check_patch_integrity.py
- LEIA_PRIMEIRO.md

## Arquivos modificados
Nenhum.

## Testes
- Inspecao de estrutura e sintaxe Python: prevista.
- Script de validacao estatico: executado separadamente, resultado no log do patch.
- Teste visual Godot F6: PENDENTE.
- Integracao em gameplay: PENDENTE, entregue apenas contrato para o agente que conhece o projeto atualizado.

## Pontos para validar
- F6 abre gallery sem parser error.
- Presenca e orientacao das fitas de ataque, brilho adequado e opacidade.
- Visualizacao de texto e efeitos na camera isometrica.
- No mobile, limitar impactos por frame em waves cheias.

## Dependencias
Godot 4.x e projeto existente. Nenhuma dependencia externa de Blender, plugin, shader ou texturas.
