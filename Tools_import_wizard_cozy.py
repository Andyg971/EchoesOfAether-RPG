#!/usr/bin/env python3
"""Importe la variante BOUCLIER du wizard (Eran) et le mobilier « cozy ».

Deux lots sans rapport, un seul outil parce qu'ils arrivent ensemble.

1. WIZARD — `ani(shield)` : le même personnage que `ani(char)`, bouclier au
   bras, sur le même canevas 109×128 et les mêmes clips. Publié sous le
   préfixe `battle_kaelward` (le pack wizard s'appelle `battle_kael` dans le
   catalogue pour des raisons historiques — cf. `BattleSprites.Pack`), ce qui
   permet à Eran de passer en garde sans changer de gabarit ni de pieds.
   Les FX (`fx/*.png`) sont déjà dans le catalogue depuis un import précédent.

2. COZY — planche `livingroom_LRK` (grille 16 px) : âtres, sièges, tables,
   chaises et buffets pour meubler les intérieurs. Les découpes sont
   explicites : les items sont bien séparés sur la planche, et une extraction
   automatique fusionnait les tapis clairs avec les tapis rouges du dessous.

   Le lot salle de bain n'est PAS importé : baignoire acrylique à mitigeur
   chromé, lavabo à robinet mélangeur et WC à chasse d'eau. Dans un hameau
   médiéval c'est la faute que le reste du code passe son temps à réparer
   (cf. `modernSubstitutions`).
"""
from __future__ import annotations

from PIL import Image
import json
import pathlib

SRC = pathlib.Path("/Users/gravaandy/Desktop/ASSET ECHOES OF AETHER")
DST = pathlib.Path("/Users/gravaandy/Desktop/1 - Projets Apps/AppMaker Studio/"
                   "GameIOS/GDD GAME RPG/EchoesOfAether/EchoesOfAether/Assets.xcassets")

written = 0


def write_imageset(name: str, image: Image.Image) -> None:
    global written
    iset = DST / f"{name}.imageset"
    iset.mkdir(exist_ok=True)
    for old in iset.glob("*.png"):
        old.unlink()
    image.save(iset / f"{name}.png")
    (iset / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }, indent=2))
    written += 1


# ─────────────────────────────────────────────────────────────────────────
# 1. Wizard au bouclier → la garde d'Eran
# ─────────────────────────────────────────────────────────────────────────

# (clip, nombre de frames publiées) — aligné sur `BattleSprites.Pack.wizard`.
WIZARD_CLIPS = [("idle", 5), ("move", 6), ("attack", 7),
                ("skill1", 7), ("skill2", 14)]


def import_wizard_ward() -> None:
    print("Wizard — variante bouclier (garde d'Eran)")
    folder = SRC / "wizard" / "ani(shield)"
    for clip, count in WIZARD_CLIPS:
        # Le pack numérote « skill2_12-2 » des alternatives : on garde la
        # suite principale, dans l'ordre numérique et pas alphabétique
        # (sans quoi skill2_10 passe avant skill2_2).
        files = {}
        for p in folder.glob(f"{clip}_*.png"):
            stem = p.stem[len(clip) + 1:]
            if stem.isdigit():
                files[int(stem)] = p
        for i in range(1, count + 1):
            src = files.get(i)
            if src is None:
                print(f"  !! {clip}_{i} manquante")
                continue
            write_imageset(f"battle_kaelward_{clip}_{i}",
                           Image.open(src).convert("RGBA"))
        print(f"  battle_kaelward_{clip:<7} {count} frames")


# ─────────────────────────────────────────────────────────────────────────
# 2. Mobilier cozy (living room)
# ─────────────────────────────────────────────────────────────────────────

# (nom cible, rect sur la planche). Grille 16 px, coordonnées relevées sur
# la planche : les âtres tiennent 3 cellules de haut, les sièges 2.
COZY = [
    # Âtres — le cœur d'une pièce à vivre. Deux matières, allumé et éteint.
    ("cz_hearth_stone_lit", (480, 16, 512, 64)),
    ("cz_hearth_stone", (432, 16, 464, 64)),
    ("cz_hearth_brick_lit", (480, 80, 512, 128)),
    ("cz_hearth_brick", (432, 80, 464, 128)),
    # Sièges rembourrés, deux teintes (lin et cendre)
    ("cz_sofa_linen", (16, 32, 64, 64)),
    ("cz_armchair_linen", (145, 16, 176, 64)),
    ("cz_seat_linen", (240, 32, 272, 64)),
    ("cz_settle_blanket", (336, 33, 367, 65)),
    ("cz_sofa_ash", (16, 96, 64, 128)),
    ("cz_armchair_ash", (145, 80, 176, 128)),
    ("cz_seat_ash", (240, 96, 272, 128)),
    # Bois : buffets, tables, tabouret
    ("cz_sideboard", (16, 160, 64, 192)),
    ("cz_cupboard", (82, 144, 110, 192)),
    ("cz_table_long", (288, 160, 336, 192)),
    ("cz_dresser", (354, 144, 382, 192)),
    ("cz_table_round", (224, 208, 256, 240)),
    ("cz_table_low", (568, 182, 600, 198)),
    ("cz_stool", (488, 217, 504, 233)),
    # Chaises — six dessins pour que deux voisines ne soient pas jumelles
    ("cz_chair_1", (128, 144, 144, 176)),
    ("cz_chair_2", (152, 144, 168, 176)),
    ("cz_chair_3", (224, 144, 240, 176)),
    ("cz_chair_4", (416, 144, 432, 176)),
    ("cz_chair_5", (272, 208, 288, 240)),
    ("cz_chair_6", (368, 208, 384, 240)),
]


def import_cozy() -> None:
    print("Mobilier cozy (living room)")
    sheet = Image.open(SRC / "INTERIEUR MAISON" / "pixelinterior_LRK_v1"
                             / "livingroom_LRK.png").convert("RGBA")
    for name, box in COZY:
        piece = sheet.crop(box)
        bbox = piece.getbbox()
        if bbox is None:
            print(f"  !! {name} : découpe vide")
            continue
        piece = piece.crop(bbox)
        write_imageset(name, piece)
        print(f"  {name:<22} {piece.width}×{piece.height}")


# ─────────────────────────────────────────────────────────────────────────
# 3. Cuve de bain (le SEUL morceau retenu du lot salle de bain)
# ─────────────────────────────────────────────────────────────────────────

def import_tub() -> None:
    """La baignoire, repeinte en bois, devient la cuve de bain de l'auberge.

    Le reste du lot `pixelinterior_BA` (lavabo à mitigeur, WC à chasse)
    n'a rien à faire dans un hameau médiéval. La baignoire, elle, redevient
    crédible une fois sortie de son blanc acrylique : on remplace la rampe
    de gris par une rampe de bruns, et le chrome du robinet par du laiton.
    """
    print("Cuve de bain (auberge)")
    sheet = Image.open(SRC / "INTERIEUR MAISON" / "pixelinterior_BA_v1"
                             / "fixtures_BA.png").convert("RGBA")
    tub = sheet.crop((16, 64, 80, 96))         # la baignoire PLEINE (avec eau)
    bbox = tub.getbbox()
    if bbox is None:
        print("  !! découpe vide")
        return
    tub = tub.crop(bbox)

    # Rampes de substitution : (source claire → bois clair), du plus clair au
    # plus sombre. On mappe par LUMINANCE, ce qui préserve les ombres du
    # dessin au lieu de le teinter à plat.
    wood = [(232, 205, 165), (198, 158, 108), (156, 116, 74),
            (112, 79, 48), (74, 50, 30), (44, 29, 18)]
    brass = [(236, 206, 128), (196, 158, 80), (146, 112, 52)]
    def luminance(p: tuple[int, int, int, int]) -> int:
        return (p[0] * 299 + p[1] * 587 + p[2] * 114) // 1000

    out = tub.copy()
    px = out.load()

    # L'eau reste de l'eau : on ne repeint que les gris et les blancs.
    def is_water(p: tuple[int, int, int, int]) -> bool:
        return p[2] > p[0] + 24

    # ÉTIREMENT du contraste avant de mapper. La baignaire d'origine est
    # presque uniformément blanche (luminance 230-250) : mappée telle quelle
    # sur la rampe de bois, elle ressortait d'un beige plat, sans une seule
    # douve visible. On étale d'abord la plage réelle sur 0-255.
    body = [px[x, y] for y in range(out.height) for x in range(out.width)
            if px[x, y][3] != 0 and not is_water(px[x, y])]
    lows = [luminance(p) for p in body]
    lo, hi = (min(lows), max(lows)) if lows else (0, 255)
    span = max(1, hi - lo)

    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] == 0 or is_water(p):
                continue
            r, g, b, a = p
            stretched = (luminance(p) - lo) * 255 // span
            ramp = brass if abs(r - g) < 30 and g > b + 20 else wood
            idx = min(len(ramp) - 1, (255 - stretched) * len(ramp) // 256)
            nr, ng, nb = ramp[idx]
            px[x, y] = (nr, ng, nb, a)
    write_imageset("cz_bathtub_wood", out)
    print(f"  cz_bathtub_wood        {out.width}×{out.height}")


if __name__ == "__main__":
    import_wizard_ward()
    import_cozy()
    import_tub()
    print(f"\n{written} imagesets écrits dans {DST.name}")
