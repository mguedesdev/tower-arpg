# Correção da caminhada que congela/desliza

## Sintoma relatado

O personagem anda animado no começo do clipe e depois continua se deslocando parado, como se o movimento das pernas acabasse antes da duração total.

## Causas compatíveis com os scripts enviados

- No rig v3, a animação `walk-loop` tem keyframes nos frames **1, 7, 13, 19, 25**. Ela foi criada como um ciclo de apenas **24 frames de duração**, que a **24 FPS dura 1,0 segundo**.
- A timeline do Blender pode continuar até 250 frames ou mais, mas o movimento não ganha keyframes novos automaticamente. Isso dá a impressão de que o personagem congela.
- A animação GLB pode entrar no Godot sem loop linear configurado ou com duração importada acima da duração real do movimento.

## O que foi alterado

1. `scripts/player.gd`: detecta `walk-loop`, define `Animation.LOOP_LINEAR` e faz o mesmo para `idle-loop`; `attack` permanece sem loop. Se a duração importada for anormalmente longa, a limita condicionalmente e registra aviso.
2. `assets/blender/GERAR_E_EXPORTAR_CAVALEIRO.py`: fixa FPS em 24; NLA strips recebem o tamanho dos keyframes correspondentes; após exportar, configura preview para walk frames 1–25.
3. `assets/blender/TESTAR_ANIMACAO_NO_BLENDER.py`: permite escolher uma Action e delimitar a timeline correta sem recriar modelo/rig.

## Como testar no Blender

1. **Abra cópia** do seu arquivo `.blend` atual com o cavaleiro.
2. Em Scripting, abra `assets/blender/TESTAR_ANIMACAO_NO_BLENDER.py` e clique em `Run Script`.
3. Aperte Play na Timeline. Walk deve repetir o ciclo do frame 1 ao 25, sem pausa.
4. Mude `ANIMACAO` no topo para `idle-loop` ou `attack` para conferir os outros movimentos.
5. Para gerar um GLB atualizado, rode `GERAR_E_EXPORTAR_CAVALEIRO.py` em uma **cena nova**, pois ele apaga a cena antes de gerar o personagem.

## Como testar no Godot

1. Extraia a atualização dentro da pasta do projeto, preservando o `.glb` já existente.
2. Se gerou novo GLB, retorne ao Godot e aguarde reimportação; se necessário, selecione o GLB e clique **Reimportar**.
3. F5: mantenha WASD pressionado por pelo menos 10 segundos e observe as pernas.
4. Solte WASD, confira idle; aproxime-se de inimigos, confira ataque; pressione 1/2/3.
5. Na saída/console, verifique mensagens `Animacao importada: ... (duracao, loop=...)`.

**Se continuar deslizando:** envie screenshot da aba Animation do GLB (duração e último keyframe), além das linhas do console que começam com `Animacao importada`. Isso distingue loop incorreto de animação mal exportada ou movimento de pés fora de sincronia com a velocidade do personagem.

## Limitação conhecida

Garantir o loop não garante *foot locking*. O modelo ainda pode patinar levemente se a velocidade do personagem não combinar com o ritmo das passadas. Esse ajuste fino só deve acontecer depois de confirmar que as pernas estão repetindo o ciclo, e é diferente do congelamento atual.
