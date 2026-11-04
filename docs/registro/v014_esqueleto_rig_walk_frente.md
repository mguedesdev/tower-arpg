# v0.14 — Rig e caminhada do esqueleto inimigo

## Escopo (exclusivo do esqueleto)
- Criar armature para o modelo v0.13, preservando modelagem e materiais.
- Criar animações `idle` (2,0 s) e `walk` (1,0 s), com braços estendidos à frente e deslocamento cambaleante.
- Corrigir orientação: o modelo foi criado com +Y frontal no Blender; no Godot usa frente -Z, e a rotação antiga apontava +Z para o jogador, gerando a caminhada de costas.
- Manter dano por contato. **Nenhum ataque, arma ou animação de ataque.**

## Arquivos alterados
- Novo: `assets/blender/RIGAR_E_EXPORTAR_ESQUELETO_INIMIGO.py` (executado com a fonte v0.13 aberta).
- Atualizado: `scripts/enemy.gd` (orientação + reprodução idle/walk).
- Documento: `docs/registro/v014_esqueleto_rig_walk_frente.md`.

## O que NÃO mudou
- Modelagem v0.13 e materiais
- Cena `enemy.tscn` e colisões
- Vida, velocidade base, dano por encostar, IA de perseguir e mecânica de morte
- Guerreiro, outros inimigos, arena, waves ou habilidade de ataque do jogador

## Padrão técnico
- Rig hierárquico humanoide com 17 ossos (root, hips, spine, neck, head + 6 por lado).
- Peças rígidas com vertex groups de peso 1, evitando deformação de costelas ou crânio.
- Duas Actions associadas ao rig e exportadas via NLA, com faixa de frames definida.
- Fonte `.blend` v0.13 preservada; saída rigada salva em `Esqueleto_Inimigo_v014_RIG.blend`.
- GLB sobrescreve apenas `assets/models/skeleton_enemy.glb`.

## Critérios de validação no Blender
1. Fonte v0.13 aberta, rig criado sem faltar peça.
2. Animation > Action Editor: `idle` e `walk` existem.
3. Walk se repete com keyframes até o frame 25; idle até o frame 49.
4. Mãos e braços continuam à frente durante a caminhada.
5. Tronco não desmonta e crânio não deforma.

## Critérios de validação no Godot
1. SkeletonEnemy surge com forma preservada.
2. Ele anda **de frente** em direção ao guerreiro.
3. Quando parado encostado, toca Idle; quando se desloca, toca Walk em loop.
4. Caminhada dura ~1 s, sem deslizar no fim do clipe.
5. Encostar ainda causa o dano original; não há animação de ataque.
6. Nenhum erro de importação, rig, AnimationPlayer ou GDScript.

## Riscos pendentes
- O novo rig e as animações ainda dependem de teste visual no Blender/Godot real.
- Como os ossos são rígidos, algumas articulações podem mostrar pequenas separações; ajustar localmente após o primeiro teste.
- Muitos inimigos rigados exigirão perfil de performance mobile antes de multiplicarmos a quantidade.
