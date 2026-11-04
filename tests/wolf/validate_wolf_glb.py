"""Verificacao independente do GLB exportado. Nao exige bpy nem Godot."""
from pathlib import Path
import json
import struct
import sys


def validate(path: Path):
    raw = path.read_bytes()
    assert len(raw) > 1000, "GLB vazio"
    assert raw[:4] == b'glTF', "Assinatura nao e glTF"
    version, length = struct.unpack_from('<II', raw, 4)
    assert version == 2 and length == len(raw), "Cabecalho invalido"
    chunk_len, chunk_type = struct.unpack_from('<I4s', raw, 12)
    assert chunk_type == b'JSON', "JSON nao e primeiro chunk"
    doc = json.loads(raw[20:20+chunk_len].decode().rstrip(' \x00'))
    assert doc.get('skins'), "Sem skeleton/skin"
    assert doc.get('meshes'), "Sem malha"
    names = {a.get('name') for a in doc.get('animations', [])}
    expected = {'idle-loop','walk-loop','attack'}
    assert expected <= names, f"Faltando animacoes: {expected - names}"
    print('OK:', path)
    print('  animacoes:', ', '.join(sorted(names)))
    print('  skins:', len(doc['skins']))
    print('  meshes:', len(doc['meshes']))


if __name__ == '__main__':
    path = Path(sys.argv[1]) if len(sys.argv)>1 else Path('assets/models/wolf.glb')
    validate(path)
