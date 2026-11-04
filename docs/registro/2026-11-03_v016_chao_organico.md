# Registro de desenvolvimento — v0.16: Chao organico

**Objetivo:** substituir apenas os quadrados verdes do solo por um terreno continuo com texturas estilizadas de grama e terra.

## Entrega
- `scripts/arena_art.gd`: substituida SOMENTE a funcao de geracao do chao, mantendo as demais funcoes e objetos do cenario v0.9.1.
- `assets/materials/terrain_ground.gdshader`: shader leve, duas texturas e mascara de transicao por cor de vertice + ruido.
- `assets/textures/grass_dark_tile.png`: textura de grama verde-musgo.
- `assets/textures/soil_moist_tile.png`: terra escura.
- `assets/textures/terrain_blend_noise.png`: ruido que desfaz linhas artificiais na transicao.
- `docs/referencias/preview_apenas_texturas.png`: miniatura de materiais para referencia.

## Decisoes tecnicas
- Malha continua unica de 52 x 52 unidades, 104 subdivisoes por eixo (aprox. 11.025 vertices, 21.632 triangulos).
- Transicoes organicas definidas por FastNoiseLite **uma vez na inicializacao**.
- Texturas de 512 x 512, repetiveis e com mipmap para evitar brilho/aliasing.
- Grama/terra geradas com material unico de shader em vez de dezenas de MeshInstance3D.
- Pequenas ondulacoes apenas onde o jogador nao precisa sentir relevo real; superficie visual fica ligeiramente abaixo do plano de colisao.
- Sem GridMap e sem Terrain3D no MVP: escala da arena ainda nao exige ferramentas de terreno maiores.

## Funcionalidades preservadas
- Nao alterado: `scenes/main.tscn`, `scripts/main.gd`, `scripts/player.gd`, `scripts/enemy.gd`, controladores de ataque, Blender, GLBs, colisoes e waves.
- Nao alterados: altar, ruinas, arvores, rochas, lapides, braseiros e tufos de grama ja existentes.

## Testes realizados
- Integridade de arquivos PNG e ZIP.
- Presenca dos caminhos de recursos usados pelo shader/script.
- Auditoria estatica dos dados de malha, indice e winding.
- **Nao executado no Godot neste ambiente:** teste visual e de compilacao ainda pendentes no computador do desenvolvedor.

## Critérios de aceitacao no Godot
- Nenhum erro de parser/shader.
- Nenhuma costura de tile quadrada no chao.
- Material de grama escura e terra perceptiveis, com mistura irregular.
- Jogador e inimigos mantem o mesmo deslocamento e colisoes.
- Bom contraste na camera isometrica.
