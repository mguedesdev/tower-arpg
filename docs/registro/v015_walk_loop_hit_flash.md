# v0.15 — Esqueleto: ciclo Walk + flash de hit

## Escopo
Somente o inimigo esqueleto. Nada foi alterado no guerreiro, arena, ondas, IA, dano ou classes.

## Problema A: walk toca e desliza
Identificado no exportador v0.14: a Action `walk` tem frames 1–25, mas a faixa NLA foi posicionada a partir do frame 52, o que pode provocar trecho parado/atraso na animação exportada. Corrigido na fonte do problema: as faixas NLA `idle` e `walk` agora começam ambas no frame 1 (em trilhas separadas), com limites 49 e 25, respectivamente, a 24 FPS.

O novo exportador lê o GLB gerado e verifica a duração real dos clipes. Se um clipe vier atrasado ou longo demais, ele gera um erro explicativo em vez de afirmar que deu certo.

## Problema B: hit sem feedback
No `enemy.gd`, o golpe que NÃO mata aplica um overlay de material vermelho suave com alpha inicial de 0,22, que desaparece em 0,16s. O efeito é local ao inimigo atingido, só fica ativo durante o hit e restaura o material overlay anterior ao terminar. Os parâmetros podem ser ajustados no Inspector.

O golpe letal continua removendo o inimigo imediatamente — sem alterar as regras atuais de morte. Podemos fazer uma animação de morte/efeito final em etapa separada.

## Arquivos
- Novo: `assets/blender/CORRIGIR_WALK_E_EXPORTAR_ESQUELETO_V015.py`
- Modificado: `scripts/enemy.gd`
- Novo: `tests/TESTAR_V015.md`
- Este documento.

## Testes de aceite
- `walk` reexportado deve durar aproximadamente 1 s, sem pausa no final.
- `idle` deve durar aproximadamente 2 s.
- No Godot, os inimigos devem repetir o Walk enquanto estiverem se deslocando.
- Ao sofrer hit não letal, apenas o inimigo atingido deve piscar vermelho levemente e voltar à cor normal.
- IA, dano por contato e morte permanecem iguais.

## Validação
Conferência estática e estrutura do ZIP realizadas. Blender/Godot não foram executados aqui; testes visuais ainda são necessários.
