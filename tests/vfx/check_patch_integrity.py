"""Testes estaticos para a biblioteca VFX (nao substituem executar Godot)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EFFECT = (ROOT / 'scripts/vfx/tower_vfx_effect.gd').read_text(encoding='utf-8')
SPAWNER = (ROOT / 'scripts/vfx/tower_vfx_spawner.gd').read_text(encoding='utf-8')
GALLERY = (ROOT / 'scripts/vfx/vfx_gallery.gd').read_text(encoding='utf-8')
SCENE = (ROOT / 'scenes/vfx/vfx_gallery.tscn').read_text(encoding='utf-8')

for effect in ('STAB', 'ARC', 'SPIN', 'IMPACT', 'FIRE', 'CLAWS'):
    assert effect in EFFECT and effect in SPAWNER, f'Efeito ausente: {effect}'
for method in ('stab', 'arc', 'spin', 'impact', 'fire_burst', 'claws'):
    assert f'static func {method}(' in SPAWNER, f'API faltando: {method}'
assert 'queue_free()' in EFFECT
assert 'take_damage(' not in EFFECT and 'take_damage(' not in SPAWNER
assert 'get_tree().get_nodes_in_group("combat_vfx").size()' in EFFECT
assert 'res://scripts/vfx/vfx_gallery.gd' in SCENE
assert 'VFX.spawn(' in GALLERY
print('PASS: biblioteca VFX, contrato, limites, scene e ausência de dano.')
