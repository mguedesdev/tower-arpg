# v0.20.1 — Limpeza de avisos GDScript

## Objetivo
Resolver avisos de shadowing (`name`, `position`) e divisao inteira no Godot.

## Diagnostico
- `scripts/arena_art.gd` v0.16: parametros `name` e `position` e calculo
  `int(indices.size() / 3)` na mensagem de diagnostico do terreno.
- `scripts/enemy.gd` v0.15: variavel local `name` na busca do clipe.
- `scripts/player.gd` v0.8.1: parametro `name` na funcao de reproduzir ataque.
- `scripts/wolf_enemy.gd` v0.19: parametro `name` no callback de animacao.

## Entregue
- `tools/corrigir_avisos_v0201.gd` (EditorScript do Godot).
- Nenhum arquivo atual do gameplay foi sobrescrito pelo ZIP.
- Ao executar, modifica somente trechos exatos e cria backup por arquivo.

## Evidencias
- Teste estatico contra as versoes auditadas, verificando localizacao das substituicoes.
- Nao executado no Godot: ainda depende da validacao no projeto local do usuario.

## Riscos/pendencias
- Versoes locais modificadas podem nao casar com os padroes. Nesse caso o script
  ignora o arquivo e registra a divergencia em vez de realizar alteracao insegura.
- Avisos antigos permanecem no historico de Output ate limpar o painel.
