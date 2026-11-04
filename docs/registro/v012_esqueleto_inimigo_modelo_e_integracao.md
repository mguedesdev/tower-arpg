# v0.12 — Esqueleto inimigo: ajuste do modelo + integracao no jogo

## Foco unico
1. Ajustar o modelo do esqueleto inimigo.
2. Integrar esse modelo ao inimigo do jogo.

## Mudancas no modelo
- removida arma
- removido escudo
- adicionado pescoco visivel
- cabeca elevada para nao ficar enterrada no peito
- mantido pano na cintura e olhos verdes

## Mudancas no Godot
- `scenes/enemy.tscn` agora tem um no `Visual`
- `scripts/enemy.gd` carrega automaticamente `res://assets/models/skeleton_enemy.glb` se existir
- placeholder antigo continua como fallback se o GLB nao existir

## Novos arquivos Blender
- `assets/blender/CRIAR_ESQUELETO_DARKFANTASY_V012.py`
- `assets/blender/GERAR_E_EXPORTAR_ESQUELETO_INIMIGO.py`

## Como validar
1. Rodar `GERAR_E_EXPORTAR_ESQUELETO_INIMIGO.py` no Blender.
2. Confirmar que `assets/models/skeleton_enemy.glb` foi criado.
3. Abrir o Godot e pressionar `F5`.
4. Conferir se os inimigos usam o novo esqueleto no lugar do placeholder.
