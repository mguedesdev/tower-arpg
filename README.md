# Torre Low Poly — primeiro protótipo Godot 🎮

Protótipo inicial de um roguelite 3D isométrico para testar **formas de ataque diferentes com uma mesma habilidade**. Preparado para Godot 4.4+ (GDScript), com renderização GL Compatibility em mente.

## Abrir
1. Extraia o ZIP do projeto para uma pasta.
2. Abra o **Godot** e escolha **Importar**.
3. Selecione o arquivo `project.godot` desta pasta.
4. Abra o projeto e pressione **F6** na cena principal ou **F5** para iniciar.

## Controles (PC)
- **WASD** ou **setas:** mover, relativo à câmera isométrica.
- **Ataques:** automáticos quando há inimigos perto.
- **1:** estocada (cone estreito).
- **2:** meia-lua (180° na frente).
- **3:** giro (360° ao redor).
- **R:** reiniciar depois da morte.

## Já inclui
- Arena isométrica 3D com câmera seguindo o personagem.
- Personagem provisório low poly e sistema de substituição por arquivo `.glb`.
- Três geometrias de ataque com acerto em áreas distintas.
- Hordas em waves, inimigos perseguindo o jogador, dano e morte.
- HUD de wave, vida, ataque e abates.
- Scripts Blender originais preservados em `assets/blender/`.

## NÃO inclui ainda
- Modelo final `.glb` do cavaleiro, pois Blender não foi executado aqui.
- Rig testado no Godot, animações verificadas, escolhas de passivas, inventário, temporada e rankings.
- Controles touch/mobile (planejados na etapa seguinte).
- Testes em aparelho Android/iOS.

## Estrutura
```
project.godot
scenes/
  main.tscn                    arena + HUD + câmera
  player.tscn                  jogador + colisão
  enemy.tscn                   inimigo simples
  placeholder_knight.tscn      visual provisório
scripts/
  main.gd                      geração de waves
  player.gd                    movimento e vida
  camera_follow.gd             câmera isométrica
  enemy.gd                     perseguição e dano
  attack_controller.gd         formas e área de ataque
assets/
  blender/                     scripts recebidos
  models/                      destino do .glb futuro
```

## Próximas etapas recomendadas
1. Rodar e confirmar o protótipo na versão instalada de Godot.
2. Testar rig v3 no Blender, exportar `.glb` e substituir visual.
3. Implementar primeira escolha de evolução durante uma run, em vez das teclas 1/2/3.
4. Criar um sistema de recursos de habilidades/modificadores (`Resource`) após validar a interação de estocada, meia-lua e giro.
5. Medir desempenho mobile antes de aumentar o número de inimigos.

**Nota:** ainda não há conexão remota com o Godot local neste chat. Os arquivos são editáveis e podem ser substituídos incrementalmente. Não sobrescreva seu projeto real sem backup.
