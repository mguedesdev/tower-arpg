# Hotfix v0.20.1 — Avisos amarelos do GDScript

## O que corrige
- Parametros chamados `name` que ocultam `Node.name`.
- Parametros chamados `position` que ocultam `Node3D.position`.
- Variavel local chamada `name` em `scripts/enemy.gd`.
- Divisao inteira no log de triangulos de `scripts/arena_art.gd`.

Os scripts da v0.20 (biblioteca VFX) NAO sao alterados.

## Instalacao em Godot 4.x
1. Faca backup do projeto antes de rodar qualquer utilitario.
2. Extraia este ZIP na pasta do projeto (`project.godot`).
3. Abra o Godot e encontre `tools/corrigir_avisos_v0201.gd` no FileSystem.
4. Clique com botao direito no script e selecione **Run** (Executar).
   Alternativa: abra o script e use **File > Run** ou `Ctrl+Shift+X` no editor de scripts.
5. Acompanhe as mensagens no painel Output/console. O utilitario cria backups
   em `docs/backups_v0201/` com final `.bak`.
6. Feche e reabra o projeto. Limpe o Output e observe se surgem novos avisos.

## Protecoes
- NAO substitui arquivos de gameplay completos: altera somente trechos exatos.
- Se a versao local for diferente, IGNORA o arquivo e avisa.
- Se ja corrigido, NAO duplica alteracoes.
- Cada arquivo tem copia original antes da modificacao.
- Se ja houver backup com mesmo nome, ignora aquele arquivo para nao sobrescrever.

## Restaurar
Para desfazer um arquivo alterado, copie o conteudo do `.bak` correspondente
na pasta `docs/backups_v0201/` de volta ao caminho original (removendo `.bak`).

## Testes
Validado em modo estatico contra scripts disponiveis das versoes v0.15, v0.16,
v0.8.1 e v0.19. Ainda nao validado executando o editor Godot.
