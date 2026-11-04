# Mudanças da versão 0.2

- Incluído `assets/blender/GERAR_E_EXPORTAR_CAVALEIRO.py` (gerador/rig/exportador em uma execução).
- `scripts/player.gd`: detecta `assets/models/knight.glb`, importa cena 3D em runtime e esconde placeholder.
- `scripts/player.gd`: aceita nomes de animação com prefixo `Library/attack`.
- Ajustes visuais de escala e rotação disponíveis via propriedades exportadas no `Player`.
- **Não foi possível executar Godot ou Blender no ambiente de preparação**. Esse pacote precisa de validação local.
