# v0.19 — Lobo low poly: revisão técnica e inclusão como inimigo

## Origem e decisão
O usuário forneceu três scripts Python (modelagem, rig, exportador) e pediu análise e adição se coerentes. A proposta foi aprovada como **novo inimigo lobo**, sem substituir o esqueleto. O design de quadrúpede agressivo é coerente com a floresta dark fantasy, desde que seja legível na câmera isométrica.

## Auditoria do projeto disponível
- `scripts/main.gd` (v0.17): as waves instanciam apenas `scenes/enemy.tscn`; XP é concedido pelo sinal `died`.
- `scripts/enemy.gd` (v0.15): movimento, dano por contato, animações, flash e morte.
- `scenes/main.tscn`: nó `Enemies` e controlador `main.gd`.
- A v0.18 altera apenas a UI de progressão, não `main.gd`.
- O arquivo do usuário não continha uma cena `wolf.tscn` ou lógica de spawn.

## Análise: pontos válidos
- Silhueta com juba, quadrúpede, focinho e patas marcadas.
- Três ações distintas: `idle-loop`, `walk-loop`, `attack`.
- Materiais separados e luz nos olhos.
- Arquitetura de gerador Blender por scripts, consistente com inimigos anteriores.

## Riscos identificados e mitigados
1. **Exportação:** o script original não inspecionava o GLB resultante. Novo exportador lê o GLB e valida skin, malha, nomes e duração das animações ANTES de substituir `wolf.glb`.
2. **Parentesco:** o rig original trocava o pai das malhas sem preservar sua matriz global. Agora mantém `matrix_world` ao reparentear.
3. **Escopo:** operações de limpar grupos e modifiers passaram a atingir apenas as peças pertencentes ao lobo.
4. **Desempenho:** dezenas de objetos por lobo; salvar `.blend` editável e depois unir as malhas somente para o GLB.
5. **Legibilidade:** clareadas levemente as três camadas principais de pelagem, para não sumir no chão escuro.
6. **Animação:** velocidade da caminhada adaptada à velocidade de movimento para reduzir deslizamento, sem garantia de correspondência perfeita sem teste visual.
7. **Gameplay:** botar o lobo no jogo sem sobrescrever `enemy.gd` nem o esqueleto existente. Usa subclasse própria e cena própria.

## Arquivos adicionados
- `assets/blender/low_poly_wolf.py`
- `assets/blender/rig_wolf.py`
- `assets/blender/GERAR_E_EXPORTAR_LOBO.py`
- `scripts/wolf_enemy.gd`
- `scenes/enemies/wolf.tscn`
- `tests/wolf/validate_wolf_glb.py`
- este registro e `LEIA_PRIMEIRO.md`

## Arquivo existente modificado
- `scripts/main.gd`: partindo da v0.17, adiciona duas constantes e seleção controlada de lobo na geração das waves. Necessário comparar se o projeto local tem modificações posteriores à v0.17. **Nenhum outro arquivo existente é substituído.**

## Spawn e balanceamento provisórios
- Wave 1: apenas esqueleto.
- Da wave 2 em diante, lobo entra em quantidade controlada, se `assets/models/wolf.glb` existir.
- O lobo possui 24 HP, 2.65 velocidade de movimento e 7 de dano por contato na cena. Valores provisórios.
- Dano do lobo ocorre somente pelo contato padrão herdado. O clipe `attack` acompanha o contato, sem causar dano adicional.
- Sua morte emite `died`, permitindo ganho normal de XP da progressão v0.17.

## Testes estáticos
- Sintaxe dos scripts Python: compilada com `compileall`.
- Estrutura e caminhos dos arquivos do ZIP: verificados.
- Diferença `main.gd` e referências checadas.

## Testes não realizados
- Execução real do Blender (bpy ausente no ambiente).
- Exportação real do `wolf.glb` e validade das animações no Godot.
- Carregamento e runtime GDScript (Godot ausente).
- Aparência do lobo no cenário, orientação, pés/contato no chão, mordida e FPS com múltiplos lobos.

## Critérios para aprovação no computador
1. Rodar o exportador no Blender: verificar que termina com mensagem `[OK]` e gera `wolf.glb`.
2. Godot importa o GLB sem erros; `AnimationPlayer` contém 3 clipes.
3. Wave 1 sem lobo; da wave 2 em diante, ao menos um lobo visível.
4. Lobo olha para o jogador, corre, para e morde sem teletransportar.
5. Só 1 dano por ciclo de contato; morte conta XP/abates, flash funciona.
6. Esqueleto, cenário, HUD e ataques do guerreiro continuam iguais.
7. Nenhum erro vermelho no debugger e desempenho aceitável.
