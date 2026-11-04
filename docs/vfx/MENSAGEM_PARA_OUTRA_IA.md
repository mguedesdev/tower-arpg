# Mensagem pronta para outra IA / agente de gameplay

## Contexto

Estamos desenvolvendo um action RPG 3D low-poly dark fantasy no Godot 4.x. Foram criados seis VFX nativos ao Godot, sem Blender/GLB, na atualizacao v0.20. O objetivo e MELHORAR A LEITURA VISUAL do combate. Estes VFX NAO controlam dano, colisao, velocidade, XP, progressao ou hitboxes.

## Sua tarefa de integracao

**Nao reescreva scripts completos. Audite antes os arquivos atualmente instalados**, em especial `scripts/attack_controller.gd`, `scripts/enemy.gd`, `scripts/wolf_enemy.gd`, `scripts/player.gd` e quaisquer servicos de abilities/progressao que foram adicionados depois da v0.19. Faca uma integracao minima, por eventos, preservando os sistemas e cooldowns.

A biblioteca esta em:

- `scripts/vfx/tower_vfx_effect.gd`: gera geometrias, fade e movimento dos VFX.
- `scripts/vfx/tower_vfx_spawner.gd`: API publica para criar efeitos.
- `scenes/vfx/vfx_gallery.tscn`: laboratorio; abrir com F6.

A importacao em qualquer script de gameplay deve ser:

```gdscript
const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")
```

As chamadas aceitas sao:

```gdscript
VFX.stab(root_3d, posicao_global, direcao_global, escala)
VFX.arc(root_3d, posicao_global, direcao_global, escala)
VFX.spin(root_3d, posicao_global, escala)
VFX.impact(root_3d, posicao_global, escala)
VFX.fire_burst(root_3d, posicao_global, escala)
VFX.claws(root_3d, posicao_global, direcao_global, escala)
```

`root_3d` deve ser um `Node3D` valido, de preferencia o container de VFX da cena ou a propria cena principal. Nunca criar os efeitos como filhos dos inimigos que serao destruídos no mesmo frame (hit letal). Cada efeito termina e chama `queue_free()` automaticamente.

## Quando chamar

1. **Estocada** (`VFX.stab`): quando um ataque de ESTOCADA e efetivamente executado, mesmo sem acertar inimigo. A frente do ataque atual do guerreiro usa `visual.global_basis.z` (+Z), nao assuma -Z para esse personagem.
2. **Meia-lua** (`VFX.arc`): quando a forma ARCO e executada, sem modificar a area real do golpe. Efeito visual azul claro, com fita facetada.
3. **Giro** (`VFX.spin`): quando a forma GIRO e executada. Nao muda dano, cooldown ou geometria de acerto.
4. **Impacto** (`VFX.impact`): uma vez quando um inimigo realmente recebe dano. Salve `enemy.global_position` ANTES de chamar `enemy.take_damage()` para nao tentar acessar um inimigo destruido. Use `posicao + Vector3.UP * altura_aproximada`.
5. **Fogo** (`VFX.fire_burst`): apenas se um sistema de efeito de FOGO estiver realmente habilitado e o evento apropriado existir. Nao fingir que uma transformacao de fogo ja foi implementada. Nao causar dano extra pelo efeito.
6. **Garras** (`VFX.claws`): apenas no momento de contato confirmado do LOBO com o jogador (ou em um futuro evento de hit de ataque). O modelo do lobo usa frente local -Z. VFX no contato e feedback, NAO aviso antecipado: para telegraph justo, futuramente criar um windup real antes do dano, com regras proprias.

## Exemplo minimo de integracao no controlador do guerreiro

Copie apenas a linha de importacao e o trecho condicional para o ponto de `_execute_attack()` DEPOIS do calculo da direcao para frente. Nao substitua a funcao inteira.

```gdscript
const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")

# Dentro de _execute_attack, depois de calcular forward:
var world_vfx_origin: Vector3 = character.global_position + Vector3.UP * 0.8
var world_vfx_root: Node3D = get_tree().current_scene as Node3D
if world_vfx_root != null:
    match active_form:
        Form.STAB:
            VFX.stab(world_vfx_root, world_vfx_origin, forward, 1.0)
        Form.ARC:
            VFX.arc(world_vfx_root, world_vfx_origin, forward, 1.0)
        Form.SPIN:
            VFX.spin(world_vfx_root, world_vfx_origin, 1.0)
```

Para o HIT, dentro do loop de inimigos **somente apos validar a colisao da habilidade**:

```gdscript
var enemy_hit_point: Vector3 = enemy.global_position + Vector3.UP * 0.7
enemy.take_damage(damage)
if world_vfx_root != null:
    VFX.impact(world_vfx_root, enemy_hit_point, 0.6)
```

A funcao de exemplo tem de ser adaptada ao controlador REAL instalado e ao evento real de dano. Nao chamar o efeito de hit uma segunda vez por outro sinal que ja o represente.

## Regras tecnicas

- Os VFX nunca causam dano nem criam colisores.
- Respeitar o limite existente de 36 efeitos vivos ao mesmo tempo.
- Nao adicionar texturas complexas, shaders pesados, particulas persistentes nem luzes dinamicas por hit no primeiro teste.
- Nao usar o efeito de garra como justificativa para antecipar/duplicar o dano do lobo.
- Se a progressao de habilidade trocar a forma de ataque, use o executor e o evento de ataque realmente ativos, nao o texto da HUD.
- No mobile, testar sobreposicao, opacidade e quantidade de impactos nas waves grandes.
- Atualizar um arquivo `docs/registro` com arquivos alterados, testes feitos e pendencias.

## Criterios de aceite

- Abrir `scenes/vfx/vfx_gallery.tscn` e pressionar F6: todos os seis efeitos aparecem e desaparecem em loop.
- Integrar ao jogo sem sobrescrever scripts/recursos novos de progressao, lobo, HUD ou terreno.
- Confirmar nenhum hit extra, nenhuma mudanca de alcance e nenhum dano sem colisao.
- Confirmar efeito de impacto em hit fatal sem tentar acessar `enemy` depois do `queue_free()`.
- Verificar que nenhum objeto VFX permanece na arvore por mais de 0.5 s.
- Confirmar FPS satisfatorio com grande quantidade de inimigos. Se necessario, reduzir aparicoes.

## Nota importante

A biblioteca v0.20 foi validada estaticamente, mas sua aparencia e compatibilidade runtime ainda precisam ser testadas no Godot. Nao chamar testes runtime de aprovados sem executa-los.
