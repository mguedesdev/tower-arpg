# Mobilidade v0.5 — Auditoria e testes

## Escopo

**Somente locomoção do guerreiro.** Não inclui nova câmera, animações de strafe, sistema de dash, alterações de combate ou de colisões do cenário.

## Problemas auditados na v0.4

1. **Arranque/pausa instantâneos:** `velocity.x/z = move_direction * move_speed` troca a velocidade sem transição física.
2. **Analógico quebrado:** `Input.get_vector()` retorna intensidade de 0 a 1, mas `move_direction.normalized()` transforma até uma inclinação leve em velocidade máxima.
3. **Reversão artificial:** trocar A → D, ou W → S, muda a direção da velocidade sem frenagem.
4. **Walk tocando parado:** o script escolhe Walk com base no input, mesmo quando uma colisão impediria o deslocamento real.
5. **Passadas dessincronizadas:** em velocidades menores, a animação caminha na velocidade padrão e não acompanha o deslocamento.

## Correção pontual

- Input relativo à câmera preserva magnitude do analógico e limita somente acima de 1.
- Velocidade horizontal usa `Vector2.move_toward` com aceleração rápida, desaceleração maior e reversão mais rápida.
- `move_and_slide` continua responsável por deslocamento/colisões; gravidade e controles antigos preservados.
- O indicador de locomocão agora usa o deslocamento efetivo medido com `get_real_velocity()` após `move_and_slide()`.
- A velocidade de Walk acompanha a velocidade real do personagem em faixa conservadora; ao atacar, o `AnimationPlayer.speed_scale` volta a 1.0 para não alterar a duração do golpe.
- A rotação suave/strafe da v0.4, o alvo e os cooldowns não foram alterados.

## Testes no Godot (executar F5)

| # | Ação | Resultado esperado |
|---|------|-------------------|
| 1 | Pressionar W por 2 s e soltar | Arranque curto; parada imediata no sentido de gameplay, sem deslizamento longo |
| 2 | Pressionar A e, sem pausar, mudar para D | Virada de movimento controlada, sem teletransporte ou deriva prolongada |
| 3 | Segurar W+D | Mesma velocidade de W sozinho, sem vantagem na diagonal |
| 4 | Fazer círculos com WASD longe de inimigos | Deslocamento acompanha a entrada e o corpo gira progressivamente |
| 5 | Fazer círculos ao redor de um inimigo | Strafe e mira suave da v0.4 continuam funcionando |
| 6 | Caminhar e atacar durante aceleração/desaceleração | Golpe acontece sem ficar acelerado ou lento pela escala do Walk |
| 7 | Com joystick conectado, inclinar 30% e 100% | Movimento parcial mais lento e movimento completo com velocidade máxima |
| 8 | Usar analogico em diagonal | Velocidade total nunca excede `move_speed` |
| 9 | Criar temporariamente uma parede com `StaticBody3D` + `CollisionShape3D`; tentar atravessar | Corpo não atravessa; Walk deve parar quando deslocamento real for zero |
| 10 | Morrer, reiniciar e testar teclas | Sem regressão no ciclo de vida, câmera ou controles |

**Atenção:** os pilares/cristais decorativos da cena `arena_art.gd` são apenas visuais, SEM colisão. Não devem ser usados para avaliar o teste #9. A cena atual tem colisão no chão, mas não em todos os props.

## Pontos conscientemente NÃO resolvidos

- Em combate, o personagem pode parecer andar para a frente enquanto se desloca lateralmente: faltam animações de strafe/backpedal no rig. Isso não é um defeito de aceleração; precisa ser tratado quando focarmos animação de locomoção.
- A câmera tem seu próprio `follow_speed`, e a defasagem do enquadramento pode ser percebida como atraso de movimento. Não foi tocada nesta atualização.
- Os primeiros frames do Walk continuam limitados pela qualidade da animação exportada do Blender. O novo código evita repetição em falso, mas não substitui um ciclo de passada bem animado.
- Ainda precisamos testar em um controle físico e em mobile; nenhum resultado de FPS ou UX foi confirmado.

## Critérios para aprovar esta tarefa

- Diagonal, aceleração, frenagem e inversão se comportam como o esperado.
- O joystick respeita intensidade analógica.
- A mira/ataque da v0.4 não apresenta regressão.
- Sem erro no depurador do Godot.
- Ao menos 5 minutos de gameplay manual sem sensação de drift/flutuação.

### Fontes oficiais (API)

- Godot CharacterBody3D: https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
- Godot Vector2: https://docs.godotengine.org/en/stable/classes/class_vector2.html
- Godot AnimationPlayer: https://docs.godotengine.org/en/stable/classes/class_animationplayer.html
