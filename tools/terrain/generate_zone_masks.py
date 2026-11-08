#!/usr/bin/env python3
"""Gerador de mascaras de terreno estilizado para as zonas de campanha ARPG (Godot 4).
Gera pares de controle:
- 01_controle_base_terra_pedra.png (R = terra batida, G = pedra, B = 0)
- 02_controle_detalhes_pedrinhas.png (R = grama pedrinhas, G = terra pedrinhas, B = trilha pedregosa)
"""
import json, random, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SIZE = 1024

def curve(points, resolution=32):
    if len(points) < 2: return points
    p = [points[0]] + points + [points[-1]]
    seq = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i-1], p[i], p[i+1], p[i+2]
        for j in range(resolution):
            t = j / float(resolution)
            q = []
            for k in (0, 1):
                val = 0.5 * ((2.0 * p1[k]) + (-p0[k] + p2[k]) * t + (2.0 * p0[k] - 5.0 * p1[k] + 4.0 * p2[k] - p3[k]) * t * t + (-p0[k] + 3.0 * p1[k] - 3.0 * p2[k] + p3[k]) * t * t * t)
                q.append(val)
            seq.append(tuple(q))
    seq.append(points[-1])
    return seq

def noise_map(size, seed):
    r = random.Random(seed)
    coarse = Image.new('L', (size // 32 + 2, size // 32 + 2))
    coarse.putdata([r.randint(60, 220) for _ in range(coarse.width * coarse.height)])
    return coarse.resize((size, size), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(size / 90.0))

def draw_path(points, width, size, blur_factor=0.08):
    im = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(im)
    pts = [(max(-0.2, min(1.2, x)) * size, max(-0.2, min(1.2, y)) * size) for x, y in curve(points)]
    p = [tuple(map(int, v)) for v in pts]
    d.line(p, fill=255, width=width, joint='curve')
    for x, y in (p[0], p[-1]):
        d.ellipse((x - width // 2, y - width // 2, x + width // 2, y + width // 2), fill=255)
    return im.filter(ImageFilter.GaussianBlur(max(3.0, width * blur_factor)))

def composite_max(images):
    if not images: return Image.new('L', (SIZE, SIZE), 0)
    res = images[0]
    for x in images[1:]:
        res = ImageChops.lighter(res, x)
    return res

def build_zone_masks(out_dir: Path, config: dict):
    out_dir.mkdir(parents=True, exist_ok=True)
    seed = config.get("seed", 42)
    r = random.Random(seed)

    dirt_layers = []
    stone_layers = []
    rocky_layers = []

    for path in config.get("paths", []):
        ptype = path.get("type", "dirt")
        width = int(path.get("width", 80))
        pts = path.get("points", [])
        m = draw_path(pts, width, SIZE, 0.09)
        if ptype == "dirt":
            dirt_layers.append(m)
        elif ptype == "stone":
            stone_layers.append(m)
        elif ptype == "rocky":
            rocky_layers.append(m)
            dirt_layers.append(m)

    for patch in config.get("stone_patches", []):
        im = Image.new('L', (SIZE, SIZE), 0)
        d = ImageDraw.Draw(im)
        cx, cy = patch["center"]
        rad = float(patch.get("radius", 0.05)) * SIZE
        intens = int(patch.get("intensity", 180))
        d.ellipse((cx * SIZE - rad, cy * SIZE - rad, cx * SIZE + rad, cy * SIZE + rad), fill=intens)
        stone_layers.append(im.filter(ImageFilter.GaussianBlur(rad * 0.42)))

    for circle in config.get("dirt_circles", []):
        im = Image.new('L', (SIZE, SIZE), 0)
        d = ImageDraw.Draw(im)
        cx, cy = circle["center"]
        rad = float(circle.get("radius", 0.06)) * SIZE
        intens = int(circle.get("intensity", 240))
        d.ellipse((cx * SIZE - rad, cy * SIZE - rad, cx * SIZE + rad, cy * SIZE + rad), fill=intens)
        dirt_layers.append(im.filter(ImageFilter.GaussianBlur(rad * 0.35)))

    d_final = composite_max(dirt_layers)
    st_final = composite_max(stone_layers)
    rv_final = composite_max(rocky_layers)

    # Grama pedregosa esparsa em manchas orgânicas
    pebbles = Image.new('L', (SIZE, SIZE), 0)
    p_draw = ImageDraw.Draw(pebbles)
    pebble_count = config.get("grass_pebble_patches", 18)
    for _ in range(pebble_count):
        px = r.randint(SIZE // 10, int(SIZE * 0.9))
        py = r.randint(SIZE // 10, int(SIZE * 0.9))
        prad = r.randint(SIZE // 45, SIZE // 14)
        p_draw.ellipse((px - prad, py - int(prad * 0.75), px + prad, py + int(prad * 0.75)), fill=r.randint(90, 200))
    pebbles = pebbles.filter(ImageFilter.GaussianBlur(SIZE * 0.022))

    # Terra com pedrinhas nas bordas
    pd = d_final.filter(ImageFilter.GaussianBlur(SIZE * 0.025))
    pd = ImageChops.multiply(pd, noise_map(SIZE, seed + 101))
    pd = pd.point(lambda val: int(val * 0.82))

    # Base: R=terra, G=pedra, B=0
    base_img = Image.merge('RGB', (d_final, st_final, Image.new('L', (SIZE, SIZE), 0)))
    # Detalhe: R=grama_pedrinhas, G=terra_pedrinhas, B=trilha_pedregosa
    detail_img = Image.merge('RGB', (pebbles, pd, rv_final))

    base_path = out_dir / "01_controle_base_terra_pedra.png"
    detail_path = out_dir / "02_controle_detalhes_pedrinhas.png"
    base_img.save(base_path)
    detail_img.save(detail_path)
    print(f"  [OK] Gerado: {out_dir.name} ({base_path.name}, {detail_path.name})")

def main():
    root = Path(r"c:\Users\mathh\OneDrive\Documents\jogo\assets\terrain_v2\masks")
    root.mkdir(parents=True, exist_ok=True)

    # 1. VILA DE VELEN (town)
    # Praça central acolhedora, caminhos conectando entrada sul, baú, sábio e portão norte
    town_cfg = {
        "seed": 77701,
        "grass_pebble_patches": 14,
        "dirt_circles": [
            {"center": [0.50, 0.50], "radius": 0.12, "intensity": 255}, # Praça da fogueira
            {"center": [0.59, 0.55], "radius": 0.05, "intensity": 220}, # Waypoint
            {"center": [0.41, 0.52], "radius": 0.05, "intensity": 220}, # Baú / Mercador
        ],
        "stone_patches": [
            {"center": [0.50, 0.50], "radius": 0.05, "intensity": 160}, # Anel de pedras na fogueira
            {"center": [0.35, 0.18], "radius": 0.06, "intensity": 140}, # Muro norte
            {"center": [0.65, 0.18], "radius": 0.06, "intensity": 140}, # Muro norte
        ],
        "paths": [
            # Estrada principal de saída para o Norte
            {"type": "dirt", "width": 110, "points": [[0.50, 0.52], [0.50, 0.35], [0.50, 0.16]]},
            # Trilha sinuosa ligando entrada ao centro
            {"type": "dirt", "width": 95, "points": [[0.50, 0.72], [0.50, 0.60], [0.50, 0.50]]},
            # Ramal leste para o Waypoint
            {"type": "dirt", "width": 65, "points": [[0.50, 0.50], [0.56, 0.53], [0.60, 0.56]]},
            # Ramal oeste para Baú / Sábio
            {"type": "dirt", "width": 65, "points": [[0.50, 0.50], [0.44, 0.51], [0.40, 0.53]]},
            # Faixa com pedrinhas no portão norte
            {"type": "rocky", "width": 55, "points": [[0.50, 0.30], [0.50, 0.18]]}
        ]
    }
    build_zone_masks(root / "town", town_cfg)

    # 2. FLORESTA DE ARATH (zone_1_road)
    # Trilha sinuosa e orgânica cruzando de Sul a Norte com curvas naturais
    zone1_cfg = {
        "seed": 88101,
        "grass_pebble_patches": 22,
        "paths": [
            # Estrada principal sinuosa
            {
                "type": "dirt",
                "width": 105,
                "points": [
                    [0.50, 0.90],
                    [0.46, 0.75],
                    [0.43, 0.60],
                    [0.48, 0.48],
                    [0.56, 0.36],
                    [0.52, 0.24],
                    [0.50, 0.10]
                ]
            },
            # Faixa rochosa na curva do rio / ponte
            {
                "type": "rocky",
                "width": 45,
                "points": [
                    [0.43, 0.62],
                    [0.48, 0.48],
                    [0.55, 0.37]
                ]
            },
            # Ramal lateral suave para o Waypoint (lado oeste)
            {
                "type": "dirt",
                "width": 55,
                "points": [
                    [0.48, 0.48],
                    [0.44, 0.50],
                    [0.41, 0.50]
                ]
            }
        ],
        "stone_patches": [
            {"center": [0.40, 0.50], "radius": 0.04, "intensity": 150},
            {"center": [0.63, 0.45], "radius": 0.05, "intensity": 130},
            {"center": [0.35, 0.30], "radius": 0.04, "intensity": 120}
        ]
    }
    build_zone_masks(root / "zone_1_road", zone1_cfg)

    # 3. RUÍNAS ANTIGAS (zone_2_woods)
    # Estrada central que cruza um grande círculo cerimonial de pedra ancestral
    zone2_cfg = {
        "seed": 88202,
        "grass_pebble_patches": 24,
        "stone_patches": [
            {"center": [0.50, 0.50], "radius": 0.14, "intensity": 230}, # Círculo de ruínas de pedra
            {"center": [0.58, 0.51], "radius": 0.05, "intensity": 180}, # Waypoint leste
            {"center": [0.38, 0.65], "radius": 0.04, "intensity": 150},
            {"center": [0.62, 0.35], "radius": 0.04, "intensity": 150}
        ],
        "paths": [
            {
                "type": "dirt",
                "width": 95,
                "points": [
                    [0.50, 0.90],
                    [0.52, 0.72],
                    [0.50, 0.50],
                    [0.48, 0.30],
                    [0.50, 0.10]
                ]
            },
            {
                "type": "rocky",
                "width": 55,
                "points": [
                    [0.51, 0.62],
                    [0.50, 0.50],
                    [0.49, 0.38]
                ]
            }
        ]
    }
    build_zone_masks(root / "zone_2_woods", zone2_cfg)

    # 4. MINAS DE KARPON (zone_4_mines)
    # Chão pedregoso, caminhos com cascalho acentuado e rochas
    zone4_cfg = {
        "seed": 88404,
        "grass_pebble_patches": 30,
        "stone_patches": [
            {"center": [0.50, 0.50], "radius": 0.16, "intensity": 240},
            {"center": [0.41, 0.52], "radius": 0.06, "intensity": 190},
            {"center": [0.32, 0.38], "radius": 0.08, "intensity": 200},
            {"center": [0.68, 0.62], "radius": 0.08, "intensity": 200}
        ],
        "paths": [
            {
                "type": "dirt",
                "width": 110,
                "points": [
                    [0.50, 0.90],
                    [0.45, 0.70],
                    [0.50, 0.50],
                    [0.55, 0.30],
                    [0.50, 0.10]
                ]
            },
            {
                "type": "rocky",
                "width": 80,
                "points": [
                    [0.48, 0.75],
                    [0.50, 0.50],
                    [0.52, 0.25]
                ]
            }
        ]
    }
    build_zone_masks(root / "zone_4_mines", zone4_cfg)

    # 5. CRIPTA DO CARRASCO (zone_3_crypt)
    # Santuário profanado com piso rochoso central onde Malakor surge
    zone3_cfg = {
        "seed": 88303,
        "grass_pebble_patches": 25,
        "stone_patches": [
            {"center": [0.50, 0.45], "radius": 0.18, "intensity": 255}, # Arena do Boss
            {"center": [0.40, 0.72], "radius": 0.06, "intensity": 190}, # Waypoint
        ],
        "paths": [
            {
                "type": "dirt",
                "width": 90,
                "points": [
                    [0.50, 0.90],
                    [0.50, 0.65],
                    [0.50, 0.45]
                ]
            },
            {
                "type": "rocky",
                "width": 60,
                "points": [
                    [0.50, 0.80],
                    [0.50, 0.45]
                ]
            }
        ]
    }
    build_zone_masks(root / "zone_3_crypt", zone3_cfg)

    # 6. ARENA PADRÃO / LOBBY (lobby / fallback)
    lobby_cfg = {
        "seed": 90420,
        "grass_pebble_patches": 18,
        "stone_patches": [
            {"center": [0.50, 0.50], "radius": 0.12, "intensity": 230} # Círculo do Altar
        ],
        "paths": [
            {"type": "dirt", "width": 85, "points": [[0.50, 0.10], [0.50, 0.90]]},
            {"type": "dirt", "width": 85, "points": [[0.10, 0.50], [0.90, 0.50]]},
            {"type": "rocky", "width": 45, "points": [[0.50, 0.35], [0.50, 0.65]]}
        ]
    }
    build_zone_masks(root / "lobby", lobby_cfg)

    print("\nTodas as máscaras de zona foram geradas com sucesso!")

if __name__ == "__main__":
    main()
