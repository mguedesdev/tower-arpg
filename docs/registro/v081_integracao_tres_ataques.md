# Registro — v0.8.1 Integrar tres ataques ao gameplay

**Origem:** laboratorio v0.8 reproduzia attack_stab, attack_arc e attack_spin, mas a cena principal tocava sempre `attack`.

**Raiz:** `AttackController` chamava `play_attack_animation()` sem informar o `Form`; o `AnimationTree` do `Player` so continha o clipe antigo.

**Alteracao:** despacho da forma 0/1/2 para clipes dedicados e tres `OneShot` de ataque. Stab/Arc possuem filtro de trilhas superiores; Spin atua no corpo inteiro. Idle/Walk mantidos na camada de locomocao.

**Arquivos alterados:** `scripts/player.gd`, `scripts/attack_controller.gd`.

**Nao alterado:** Blender, rig, animacoes GLB, danos, ataques geometricos, inimigos, waves, camera e arte.

**Validacao:** inspecao de sintaxe/estrutura, verificacao dos caminhos e nomes dos clipes, auditoria das chamadas. Teste visual F5 ainda pendente.

**Proximo passo, somente apos aceite:** sincronizar dano ao impacto sem interferir na caminhada.
