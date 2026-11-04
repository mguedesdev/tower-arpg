# Registro — v0.10: modelagem do inimigo esqueleto

**Escopo:** somente o modelo 3D do primeiro inimigo humanoide low poly, feito por script Blender.

**Arquivo criado:** `assets/blender/CRIAR_ESQUELETO_INIMIGO.py`.

## Características
- Crânio, mandíbula, cavidades dos olhos e dentes simples.
- Coluna e costelas construídas de segmentos low poly.
- Braços e pernas ósseos em pose A, com juntas destacadas.
- Tecido rasgado, ferrugem, musgo e olhos espectrais.
- Organização por coleção e grupos de partes do corpo.
- Paleta pensada para cenário dark fantasy com grama, ruínas e altar.

## Não implementado
- Rig, armature, weight painting ou animação.
- Exportação para GLB/Godot.
- Comportamento de inimigo, vida, dano, movimentação ou colisões.
- Otimizações de instanciamento para hordas.

## Validação
- [x] Código compila sintaticamente em Python.
- [ ] Executar no Blender 4.x ou 5.x.
- [ ] Conferir silhueta frontal e isométrica.
- [ ] Avaliar proporções e acabamento.
- [ ] Aprovar modelo antes de iniciar rigging.

## Riscos conhecidos
- A modelagem em peças separadas facilita edição, mas deve ser consolidada antes do uso em massa no jogo.
- O modelo não foi renderizado nem testado neste ambiente por ausência de Blender.
