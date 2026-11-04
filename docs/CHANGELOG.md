# Changelog

## 0.5.2 — HOTFIX: referência de inimigo destruído (03/11/2026)

**Escopo:** corrigir exclusivamente a validação e o acesso a inimigos já removidos da cena no `scripts/attack_controller.gd`.

**Causa:** a função `_is_valid_enemy(enemy: TowerEnemy)` recebia uma referência para um objeto destruído. Godot verificava o tipo do parâmetro antes de entrar na função e lançava `Invalid type ... previously freed` antes da chamada a `is_instance_valid()`.

**Correção:** receber `Variant`, validar `is_instance_valid()` primeiro, conferir a classe e somente então acessar `alive`/`is_queued_for_deletion()`. Os loops de aquisição de alvo e de aplicação de dano validam a referência antes do cast para `TowerEnemy`.

**Preservado:** mobilidade da v0.5, suavização da orientação v0.4, seleção/alcance, dano, cooldown, ataque em estocada/meia-lua/giro, câmera, cenário, UI e animações.

**Teste:** incluído `tests/test_enemy_reference.gd` para validar referência nula, tipo errado, inimigo válido, inimigo agendado para destruição e referência já destruída. Requer execução no Godot local (não testado neste ambiente).

**Regressão manual:** iniciar F5; matar vários inimigos, especialmente o último da wave; continuar se movimentando e atacando após respawns; não deve surgir nenhum `Invalid type ... previously freed`.

**Rollback:** restaurar somente `scripts/attack_controller.gd` da v0.5.1, ciente de que isso restaura o erro.

---

## 0.5.1 — HOTFIX: contrato Player/AttackController (03/11/2026)

**Problema:** ao aplicar `scripts/player.gd` da v0.5 sobre um projeto cujo `scripts/attack_controller.gd` ainda era o da v0.3, o controlador antigo chamava `character.face_direction(...)`, método retirado na v0.4. Isso causava `Invalid call. Nonexistent function face_direction`.

**Correção:** atualizar **somente** `scripts/attack_controller.gd` para a implementação compatível com v0.4/v0.5. A mira é comunicada por `set_combat_target(...)` e os ataques frontais consultam `is_facing_direction(...)`; somente o `Player` controla a rotação suave.

**Preservado:** `scripts/player.gd` v0.5 (velocidade, aceleração, frenagem, animações e importação GLB), câmera, arena, inimigos, cenas, Blender, HUD e waves.

**Validação:** conferência estática de dependências e ausência da chamada removida. Não foi possível rodar Godot localmente; testar com F5 e verificação do Debugger.

**Teste mínimo:** iniciar F5; caminhar com WASD, atacar automaticamente e andar lateralmente em torno do alvo. Confirmar ausência de erros e rotação sem trancos.

**Rollback:** restaurar o `scripts/attack_controller.gd` anterior do backup (isso pode reintroduzir o erro com `player.gd` v0.5; restauração completa deve ser feita em conjunto).

---

## 0.5 — PERSONAGEM: mobilidade responsiva (03/11/2026)

**Escopo fechado: aceleração, frenagem, controle analógico e sincronia da animação de caminhada.**

- Revisado `scripts/player.gd` sem modificar scripts de ataques, câmera, inimigos, arena ou waves.
- Movimentação horizontal usa aceleração curta, frenagem rápida e resposta específica para reversão de direção.
- Preservada a intensidade do analógico: removida normalização que forçava velocidade total.
- Velocidade diagonal continua limitada a `move_speed`.
- `move_and_slide()` mantém tratamento de colisões; `get_real_velocity()` orienta escolha/ritmo do Walk para reduzir movimento de pernas quando bloqueado.
- `AnimationPlayer.speed_scale` acompanha a caminhada e é restaurado a 1.0 ao iniciar o ataque, evitando contaminar a duração do golpe.
- Ajustes configuráveis pelo Inspetor: `move_acceleration`, `move_deceleration`, `reverse_acceleration`, `movement_stop_threshold`, `minimum_walk_animation_speed`.
- Verificações estáticas e simulação numérica efetuadas; **a execução real no Godot ainda precisa ser validada pelo desenvolvedor**.
- Testes, limitações e plano de rollback: `docs/MOBILIDADE_V05_TESTES.md`.

---


## 0.4 — PERSONAGEM: orientação durante ataque (03/11/2026)

**Escopo fechado: somente orientação do personagem enquanto ataca.**

### Problema encontrado

Ao caminhar para um lado, o Player tentava apontar o corpo na direção do movimento a cada frame. No mesmo tempo, o AttackController forçava a rotação imediata para o alvo. Resultado: o guerreiro girava bruscamente para atacar e voltava logo em seguida, dando aparência de "tranco".

### Mudanças realizadas

- `scripts/player.gd`: somente o Player controla o giro visual; rotação com limite de graus por segundo, sem teletransporte angular.
- `scripts/attack_controller.gd`: mira automática mantém um alvo de combate até ele morrer, afastar-se ou surgir outro significativamente mais próximo. Isso reduz alternância nervosa entre inimigos.
- Enquanto existe alvo próximo, o guerreiro olha para ele mesmo se andar de lado (strafe). A movimentação continua independente.
- Estocada e meia-lua **aguardam a orientação estar alinhada** antes de executar o dano; o giro 360 não exige alinhamento frontal.
- Após iniciar um golpe, a orientação fica travada por 0,35 s, evitando que o corpo vire no meio do impacto.
- Mantidos: sistema de ataque automático, cooldown, dano, formas de ataque, movimentação, importação GLB, animações, arena, HUD e waves.
- Não alterados: `scenes/*`, `scripts/main.gd`, `scripts/enemy.gd`, `scripts/arena_art.gd`, `assets/*`.

### Ajustes no Inspetor (no Player / AttackController)

- `movement_turn_degrees`: 300 graus/s — giro fora do combate.
- `combat_turn_degrees`: 420 graus/s — giro em combate.
- `attack_facing_hold`: 0,35 s — janela em que não gira durante o golpe.
- `detection_radius`: 4,5 — começa a mirar antes de entrar em alcance de ataque.
- `release_radius`: 6,0 — evita perder o alvo por pequenas variações de distância.
- `retarget_ratio`: 0,6 — somente troca por alvo consideravelmente mais próximo.
- `attack_alignment_degrees`: 12 graus — tolerância frontal antes de causar dano.

### Teste de aceitação no Godot (F5)

1. Corra em diagonal em direção a um inimigo: o personagem deve girar progressivamente, não instantaneamente.
2. Fique perto de um inimigo e mantenha A/D ou faça um círculo: o guerreiro deve **andar de lado olhando para o inimigo** sem alternar entre movimento/mira a cada golpe.
3. Use 1 (estocada), depois 2 (meia-lua): o primeiro ataque pode aguardar uma curta virada, e deve atingir o alvo sem um giro brusco.
4. Use 3 (giro): o ataque em 360 graus continua independente de ângulo frontal.
5. Mate o último inimigo e caminhe: ele deve voltar suavemente a orientar-se na direção do deslocamento.
6. Observe a aba Debugger/Erros: sem novos erros.

### Limitações conhecidas / próxima etapa (não implementada)

- Ainda não sincronizamos o momento exato do dano com o contato visual da espada; o protótipo aplica dano no começo do ataque.
- Ainda existe uma animação-base única de espada para estocada, meia-lua e giro; os movimentos próprios de cada forma serão tratados em tarefa futura.
- Não houve validação de execução em Godot neste ambiente; é necessária a confirmação no editor local.

---

## 0.3 — Pátio Arcano + Walk

- Nova camada visual independente `scripts/arena_art.gd`, com piso modular, círculo dourado, colunas e cristais.
- HUD ajustada em `scenes/main.tscn`.
- `scripts/player.gd`: força loop nas animações de caminhada/parado e alerta/corrige duração importada excessiva.
- Exportador Blender: FPS 24 e duração de strips por Action; preview de walk nos frames 1–25.
- Script de preview de Actions no Blender.
- Documentos de direção de arte, refatoração e teste.

## Legado preservado

- `scripts/main.gd`, `scripts/attack_controller.gd`, `scripts/enemy.gd`, `scripts/camera_follow.gd`, `scenes/player.tscn`, `scenes/enemy.tscn` não foram alterados nesta entrega.
