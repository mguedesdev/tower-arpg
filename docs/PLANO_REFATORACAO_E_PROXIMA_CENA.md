# Plano de integração e próxima cena — Godot v0.3

## Meta

Transformar o protótipo visualmente bruto em um **pátio arcano jogável**, preservando o combate existente e estabelecendo o primeiro teste de transformação de habilidades. Não adicionar sistemas novos até que o básico esteja estável.

## Estado atual — o que não mexer sem necessidade

| Peça | Decisão | Motivo |
|---|---|---|
| `scripts/main.gd` | **Manter** | Waves, HUD e estado da partida já existem |
| `scripts/attack_controller.gd` | **Manter** | Demonstra estocada / meia-lua / giro; lógica ainda provisória |
| `scripts/enemy.gd` | **Manter** | Inimigo de teste suficiente |
| `scenes/player.tscn` | **Manter** | Colisão e nó de apresentação independentes |
| `scripts/player.gd` | **Corrigir somente animações** | Loop/clip do GLB; não mudar velocidade de movimento |
| `scenes/main.tscn` | **Atualizar apresentação** | Preservar nós esperados pelos scripts e colisão do chão |
| `scripts/arena_art.gd` | **Novo** | Criação de piso, runas e props só visuais |
| `assets/blender/` | **Preservar, corrigir export/preview** | Fonte já existente, rig ainda requer validação |

## Nova arquitetura visual

```text
Arena (Node3D) [main.gd]
├── Ground (StaticBody3D) [colisão preservada]
├── ArenaArt (Node3D) [arena_art.gd: APENAS visual]
├── Player (CharacterBody3D) [player.gd]
│   ├── Visual [placeholder ou knight.glb]
│   └── AttackController [attack_controller.gd]
├── Enemies
├── Camera
└── HUD
```

**Regra:** `ArenaArt` não calcula wave, não cria inimigo e não acessa saúde/skills. Pode ser substituído por um cenário do Blender no futuro sem refatorar gameplay.

## Entrega desta versão (v0.3)

1. Piso modular azul-acinzentado; anéis dourados de spawn; pedestais, colunas e cristais nas bordas.
2. HUD reorganizada com título e legibilidade melhor.
3. Correção defensiva de loop de idle/walk no Godot; duração longa importada recebe limite condicional e aviso.
4. Exportador Blender com FPS explícito e strips NLA de duração controlada.
5. Script separado de teste das Actions no Blender, definindo a timeline para o ciclo certo.
6. Documentos, referência visual e instruções de teste.

**Não inclui:** gameplay novo, chefes, evolução, árvore, sistema de equipamentos, colisões dos props ou modelo `.glb` gerado. O `knight.glb` continua sendo produzido localmente no Blender.

## Próximo marco: vertical slice de combate visualmente testável

### 0. Verificar a cena v0.3

- Rodar F5, caminhar e atacar; conferir zero erros bloqueantes.
- Confirmar que inimigos não são bloqueados por props (ainda não têm colisão).

### 1. Corrigir/validar o cavaleiro (gate técnico)

- Exportar o GLB a partir dos 3 scripts do Blender e inspecionar o `AnimationPlayer` importado.
- `idle-loop` ≈2 s; `walk-loop` ≈1 s; `attack` ≈1,2 s a 24 FPS.
- Verificar que espada/escudo seguem seus ossos e não se deformam.
- Calibrar tamanho, frente, altura e rotação no `Player`.

### 2. Uma habilidade com duas transformações reais

- Manter o guerreiro e um tipo de inimigo no primeiro experimento.
- Criar somente `Estocada` e sua variação `Meia-lua` (e depois `Giro`).
- Comparar hitbox, VFX e feedback de acerto; não apenas valores numéricos.
- Medir satisfação com 3–5 minutos de jogo antes de aumentar escopo.

### 3. Feedback de impacto básico

- Flash curto, som, pequeno recuo e indicador de acerto para dar leitura ao dano.
- Garantir que não haja efeitos luminosos excessivos com muitos inimigos.

### 4. Primeiro teste mobile

- Validar proporção e UI em 16:9 e tela vertical.
- Medir o desempenho em aparelho real antes de projetar 100+ inimigos.

## Fila de trabalho após a cena

1. Validar/depurar rig e animações reais.
2. Ajustar escala do personagem e câmera para legibilidade.
3. Definir contratos de `AbilityDefinition`, `AbilityRuntime`, `AbilityModifier` mínimos.
4. Evolução de uma habilidade e HUD de escolha.
5. One-shot de 5 waves e tela de resultado.
6. Metaprogressão mínima e salvamento — só quando loop estiver bom.

## Não fazer agora

- Não migrar para ECS completo, frameworks de habilidades enormes ou pool universal.
- Não criar três classes antes da experiência de guerreiro ser divertida.
- Não implementar ranking, backend, monetização ou inventário 3D.
- Não reorganizar todos os diretórios sem testes e Git.

## Critérios de aceitação da v0.3

- [ ] Projeto importa no Godot 4.7.2 sem erros de script.
- [ ] Arena aparece com piso modular e cristais, sem afetar colisões existentes.
- [ ] WASD e teclas 1, 2, 3 continuam funcionando.
- [ ] Inimigos aparecem e recebem dano como antes.
- [ ] `walk-loop` repete durante movimento contínuo, sem longa pausa.
- [ ] `idle-loop` repete quando parado; ataque volta para idle/walk.
- [ ] O `.glb` foi gerado e inspecionado no Godot (passo ainda pendente no ambiente local).
