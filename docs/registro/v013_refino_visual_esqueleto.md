# v0.13 — Refino visual do SkeletonEnemy

**Escopo único:** modelagem e materiais do esqueleto humanoide comum, sem rig, animações ou gameplay.

## Problemas identificados nas versões anteriores
- Excesso de cubos/cilindros com volumes uniformes dava aspecto mecânico e improvisado.
- Costelas retas e mandíbula em bloco prejudicavam o aspecto de esqueleto.
- Cabeça pouco expressiva para a câmera isométrica.
- Escala construída no Blender não correspondia à escala da cápsula do inimigo no Godot.
- Muitas malhas independentes poderiam gerar trabalho desnecessário de renderização em hordas.

## Decisões tomadas
- Crânio construído por perfis facetados e sombreado flat.
- Olhos em cavidades grandes e contraste alto; brilho verde moderado.
- Quatro pares de costelas com curvatura e espessura variável.
- Membros compostos de malhas de baixa resolução com afunilamento nas extremidades e articulações legíveis.
- Visual desarmado com tecido vermelho escuro na cintura, sem acessórios adicionais.
- Mesma convenção de frente (+Y no Blender), mesma raiz `SkeletonEnemy` e mesmo arquivo de exportação `skeleton_enemy.glb`.
- Exportação como duplicatas agrupadas por material; modelo de origem permanece editável em `.blend`.
- Raiz com escala 0,40 para altura aproximada de 1,8 unidade no Godot.

## Arquivos criados/substituídos
- `assets/blender/CRIAR_ESQUELETO_DARKFANTASY_V013.py`
- `assets/blender/GERAR_E_EXPORTAR_ESQUELETO_INIMIGO.py`

## Arquivos intocados
- `scripts/enemy.gd` e demais scripts Godot
- `scenes/enemy.tscn`
- `scripts/player.gd`
- Rig/armature e todas as animações

## Verificação / limites
- Sintaxe Python compilada com sucesso; geometria e exportador inspecionados estaticamente.
- Ambiente não possui Blender instalado para renderizar, contar triângulos reais ou verificar o `.glb` resultante.
- Não declarar arte final aprovada antes de print do Blender e validação no Godot.

## Critérios para aprovação visual
- Crânio e órbitas legíveis de longe.
- Pescoço com intervalo visível entre cabeça e tórax.
- Quatro pares de costelas e cavidade abdominal, sem barras planas.
- Pés no solo e escala compatível com o guerreiro.
- Silhueta consistente com a referência aprovada, sem virar um mini-chefe complexo.
