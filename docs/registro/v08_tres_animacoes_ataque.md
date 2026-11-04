# Registro — v0.8 — Três golpes do guerreiro

**Escopo exclusivo:** animações da estocada, meia-lua e giro completo.

## Problema

Até aqui o mesmo `attack` do rig era reproduzido para as três formas de ataque. O movimento não comunicava a geometria do golpe. Já foi observado que os antigos clipes Walk e Attack apresentaram problemas de nomes, importação e qualidade de coreografia.

## Alterações

1. Adicionado `CRIAR_3_ANIMACOES_ATAQUE.py` para criar três Actions diferentes no rig existente sem modificar a malha.
2. Atualizado o exportador para registrar explicitamente as três Actions adicionais em NLA e incluí-las no GLB.
3. Atualizado o laboratório Godot para pré-visualização individual por teclas 1, 2 e 3.
4. Mantidos os clipes `idle-loop`, `walk-loop` e `attack` como compatibilidade.
5. Inclusos os scripts de dependência do Blender no ZIP para evitar ausência de arquivos.

## Não alterado

- Gameplay, movimentação, cálculo de dano e hitboxes.
- Scripts do personagem e do ataque no Godot.
- Hierarquia e quantidade de ossos do rig.
- Geometria, escala, materiais e cenário.

## Limitações conhecidas

- Coreografia criada por keyframes procedurais; ainda não foi inspecionada em reprodução real.
- `attack_spin` exige reprodução full-body no Godot; a sobreposição de tronco usada pelo ataque antigo não basta.
- O impacto visual e o dano ainda não estão sincronizados.
- O exportador principal recria a cena Blender; editar uma cena já personalizada requer backup e exportação manual, ou preservar alterações antes de rodar o gerador.

## Critérios de aprovação

- [ ] Todas as três Actions constam na lista do laboratório.
- [ ] Cada golpe executa e termina sem clipping grave de arma e escudo.
- [ ] Estocada claramente lança a espada para frente.
- [ ] Meia-lua faz trajetória lateral reconhecível.
- [ ] Giro apresenta rotação completa, sem retorno brusco ou deformação.
- [ ] Idle e Walk continuam presentes e não foram alterados.

## Próximo passo (somente após aprovação)

Escolher animação conforme o formato no `TowerAttackController` e integrá-la ao `AnimationTree`, com filtro superior para estocada/meia-lua, reprodução de corpo inteiro para o giro e timing de dano alinhado ao frame de impacto.
