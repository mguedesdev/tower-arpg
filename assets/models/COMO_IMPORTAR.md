# IMPORTAR O CAVALEIRO NO GODOT — v0.2

## UM SCRIPT PARA GERAR + RIGAR + EXPORTAR

1. Abra **Blender**, em um **arquivo novo** (o gerador limpa a cena).
2. Abra o workspace **Scripting**.
3. Clique **Open** (no editor de texto) e selecione dentro da pasta do projeto:
   `assets/blender/GERAR_E_EXPORTAR_CAVALEIRO.py`.
4. Clique **Run Script**.
5. Se tudo correr bem, será criado automaticamente:
   `assets/models/knight.glb`.
6. Volte para o **Godot**. Aguarde a importação do `.glb` terminar.
7. Pressione **F5**: o personagem provisório some em EXECUÇÃO e o GLB aparece.

**Importante:** a cena `scenes/player.tscn` mantém o placeholder visível no editor como fallback. Ao jogar, `player.gd` carrega o GLB automaticamente. Se quiser visualizar o cavaleiro no editor, pode instanciar `knight.glb` como filho de `Visual` e ocultar `PlaceholderKnight`, mas assim não use a substituição automática sem adaptá-la para evitar duplicações.

## Se aparecer um problema

- **Blender: script não encontra os arquivos**: abra o `.py` usando **Open**, não copiando o código para um texto novo.
- **Godot continua com placeholder**: confirme o nome/caminho `assets/models/knight.glb` e veja a aba `Saída` (Output) do Godot.
- **Cavaleiro de costas**: em `Player` (cena `player.tscn`), ajuste `knight_yaw_degrees` para `180`.
- **Tamanho errado**: ajuste `knight_visual_scale` no nó Player.
- **Animação não aparece**: abra o `knight.glb` no Godot, procure `AnimationPlayer` e confira se foram importados `idle-loop`, `walk-loop` e `attack`.
- **O personagem quebra ao animar**: rig v3 ainda não foi testado no Blender; envie print do resultado e erro do Blender/Godot.

## Limitações atuais

Este script **não garante** que o rig e as três animações estão corretos: é necessário executar e verificar no Blender e no Godot. O ataque usa a hitbox de teste existente; os keyframes do golpe não são responsáveis pelo instante do dano ainda. A capa do cavaleiro está presa ao tronco e não tem física.

O `GERAR_E_EXPORTAR_CAVALEIRO.py` usa as fontes originais sem modificá-las. O fluxo é reproduzível e o projeto continua funcionando com placeholder se o GLB não tiver sido exportado.
