# v0.9 — Cenario Dark Fantasy

## Foco unico desta etapa
Trabalhar somente o cenario visual da arena principal.

## Objetivo
Substituir o visual mais abstrato do Patio Arcano por uma arena com:
- grama e terra
- altar de spawn central
- clima dark fantasy
- props de ruina, lapides, arvores mortas, pedras e braseiros
- melhor leitura visual sem tocar no gameplay

## Arquivos alterados
- `scripts/arena_art.gd`
- `scenes/main.tscn`

## O que foi feito
1. Reescrita da camada visual `ArenaArt`.
2. Piso com mistura de grama e terra usando instanciamento em grade.
3. Caminho de terra ao redor do centro.
4. Altar de spawn em camadas, com aneis e runas.
5. Ruinas e paredes quebradas nas bordas.
6. Arvores mortas, lapides e rochas para reforcar o tom dark fantasy.
7. Braseiros com chama verde espectral ao redor do altar.
8. Ajustes de ambiente, luz e HUD para combinar com a nova atmosfera.

## O que NAO foi alterado
- movimentacao
- combate
- inimigos
- animacoes
- colisao do chao
- logica de waves
- scripts do Blender

## Teste recomendado
1. Extrair a atualizacao na pasta do jogo.
2. Abrir `project.godot`.
3. Pressionar `F5`.
4. Validar:
   - spawn no altar central
   - legibilidade do personagem
   - leitura dos inimigos contra o fundo
   - sensacao geral de dark fantasy
   - ausencia de props bloqueando o combate

## Observacoes
Toda a cenografia desta versao e puramente visual.
Se a leitura ficar boa, a proxima iteracao pode melhorar:
- neblina
- pequenas variacoes de altura do terreno
- mais detalhe no altar
- props especificos por bioma/tema
