# Testar v0.15

1. Abra `assets/blender/Esqueleto_Inimigo_v014_RIG.blend`.
2. Blender > Scripting > Open: abra `CORRIGIR_WALK_E_EXPORTAR_ESQUELETO_V015.py`.
3. Execute `Run Script` e leia o console. Esperado: `idle` ~2 s, `walk` ~1 s e mensagem de SUCESSO.
4. Volte ao Godot e aguarde reimportar `assets/models/skeleton_enemy.glb`.
5. Aperte F5 e acompanhe um esqueleto por 10–15 s. Ele deve caminhar sem parar as pernas, mesmo enquanto persegue o jogador.
6. Acerte um esqueleto sem matá-lo. Deve surgir uma tonalidade vermelha transparente por ~0,16 s e desaparecer.
7. Acerte dois esqueletos em momentos diferentes. O efeito de um não pode mudar a cor do outro.
8. Confirme que o dano por encostar e a morte seguem funcionando.
9. Se Walk ainda deslizar: anote a linha `Enemy: walk importado com XX s` no Output e envie o erro do Blender, se houver.
