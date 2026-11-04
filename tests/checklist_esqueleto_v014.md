# Checklist de teste: esqueleto v0.14

- [ ] Blender: rig tem 17 ossos e todas as malhas foram vinculadas.
- [ ] Blender: as duas Actions (`idle`, `walk`) existem e movem braços/pernas sem destruir o modelo.
- [ ] Godot: `skeleton_enemy.glb` reimportado, sem warnings de animação.
- [ ] Godot: inimigo olha com o crânio **para o guerreiro** ao caminhar.
- [ ] Godot: braços à frente, pernas cambaleando enquanto anda.
- [ ] Godot: Walk repete por 10s sem congelar.
- [ ] Godot: Idle toca quando não há deslocamento real.
- [ ] Godot: dano por contato funciona, sem ataque.
- [ ] Godot: matar inimigo e nascer nova wave não causa erro.

**Anote caso o rosto ainda fique invertido**: isso depende da orientação real da exportação GLB. Há `visual_yaw_degrees` no Inspector de `enemy.tscn` para correção pontual, mas a convenção padrão desta versão é 0° e direção -Z.
