# v0.11 — Inimigo Esqueleto: conceito aprovado

## Escopo unico da tarefa
Criar no Blender um esqueleto low poly inspirado na arte aprovada pelo criador, sem rig e sem animacoes.

## Referencia
`assets/blender/reference/esqueleto_referencia.png`

## Direcao de arte
- caveira grande e angular, olhos verde-espectral
- caixa toracica e ossos destacados em formas poligonais legiveis
- membros longos e articulações aparentes
- pano bordô na cintura, como na referencia
- espada de aço em uma mao e escudo de madeira com aro metalico na outra
- estetica dark fantasy, mas sem microdetalhes desnecessarios em um mob comum

## Arquivo adicionado
`assets/blender/CRIAR_ESQUELETO_DARKFANTASY_V011.py`

## Decisoes tecnicas
- Blender 4.x/5.x via Python `bpy`
- origem da criatura no solo (Z=0)
- frente do modelo = eixo -Y
- escala ajustavel por `CHARACTER_SCALE`
- malhas separadas e organizadas por grupos: cabeca, torso, bracos, pernas, espada, escudo
- `SHOW_SWORD` e `SHOW_SHIELD` para ocultar itens se for criar variantes
- camera e luzes de preview, sem rig, colisoes nem animacoes
- scripts do Godot e do guerreiro NAO modificados

## Validacao realizada
- compilacao de sintaxe Python: aprovada
- teste real no Blender: ainda nao realizado (executavel Blender indisponivel no ambiente de criacao)
- correspondencia visual com referencia: requer avaliacao dentro do Blender

## Validacao pendente
1. Rodar script em arquivo novo no Blender
2. Conferir proporcoes em vista frontal e camera
3. Avaliar leitura isometrica e escala em relacao ao guerreiro
4. Ajustar visual se necessario antes de adicionar rig

## Nao incluso nesta etapa
- rig / armature
- animacoes
- exportacao GLB
- controlador de inimigo Godot
- colisoes / gameplay
