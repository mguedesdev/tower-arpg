# Hotfix v0.9.1 — Correção de parser ConeMesh

## Erro
`Parser Error: Identifier "ConeMesh" not declared in the current scope.`

## Causa
`ConeMesh` não é uma classe de mesh do Godot 4.

## Mudança isolada
Em `scripts/arena_art.gd`, as duas chamas da função `_brazier` agora usam `CylinderMesh` com `top_radius = 0.0`, mantendo o raio inferior e as alturas anteriores.

## Escopo preservado
Sem alterações de personagem, ataques, animações, mobs, waves, colisões ou cena principal.

## Validação
Inspeção estática concluiu que não existem outras referências a `ConeMesh` no script. É necessário abrir o projeto no Godot e executar F5 para confirmar o funcionamento no motor.
