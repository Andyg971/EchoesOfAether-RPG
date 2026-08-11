#!/usr/bin/env python3
"""Importe l'Archiviste — « Water Monster », trois teintes, un seul monstre.

La planche fait 960×1920, grille de 80×80 (12 colonnes × 24 rangées). Les
trois fichiers `Monstros (7/8/9)` sont le MÊME personnage dans trois teintes :

    Monstros (7) → bleu      Monstros (9) → vert      Monstros (8) → violet

C'est l'ordre du cycle demandé (bleu → vert → violet), pas l'ordre des
fichiers : le violet est le n°8 et le vert le n°9.

Rangées retenues (les seules qui montrent le personnage entier ; le reste de
la planche est du FX détaché — orbes, colonnes d'eau, gerbes) :

    0  idle    8 frames        5  death   8 frames
    2  walk    8 frames       11  cast    8 frames
    4  attack  9 frames

L'archive de départ est un .rar : décompresser d'abord avec `unar`.
"""
from __future__ import annotations

from PIL import Image
import json
import pathlib
import sys

DST = pathlib.Path("/Users/gravaandy/Desktop/1 - Projets Apps/AppMaker Studio/"
                   "GameIOS/GDD GAME RPG/EchoesOfAether/EchoesOfAether/Assets.xcassets")

CELL = 80

# (fichier source, suffixe de teinte) — dans l'ordre du cycle d'attaque.
TINTS = [("Monstros (7).png", "blue"),
         ("Monstros (9).png", "green"),
         ("Monstros (8).png", "violet")]

# (nom de clip, rangée, nombre de frames)
CLIPS = [("idle", 0, 8), ("walk", 2, 8), ("attack", 4, 9),
         ("cast", 11, 8), ("death", 5, 8)]

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


def clip_frames(sheet: Image.Image, row: int, count: int) -> list[Image.Image]:
    return [sheet.crop((c * CELL, row * CELL, (c + 1) * CELL, (row + 1) * CELL))
            for c in range(count)]


def main(src_dir: pathlib.Path) -> None:
    # UNE seule fenêtre de recadrage pour TOUS les clips et toutes les
    # teintes. Une boîte par clip semblait plus serrée, mais l'attaque est
    # large (le bras traverse la cellule) et l'idle étroit : recadrés
    # séparément, leurs centres ne coïncident plus et le monstre saute de
    # côté chaque fois qu'il frappe. Même fenêtre = pieds et centre fixes.
    box = None
    for filename, _ in TINTS:
        sheet = Image.open(src_dir / filename).convert("RGBA")
        for _, row, count in CLIPS:
            for frame in clip_frames(sheet, row, count):
                b = frame.getbbox()
                if b is None:
                    continue
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                             max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        sys.exit("planches vides")
    print(f"fenêtre commune {box[2] - box[0]}×{box[3] - box[1]} (cellule {CELL})")

    for filename, tint in TINTS:
        sheet = Image.open(src_dir / filename).convert("RGBA")
        for clip, row, count in CLIPS:
            for i, frame in enumerate(clip_frames(sheet, row, count), start=1):
                write_imageset(f"enemy_archivist_{tint}_{clip}_{i}", frame.crop(box))
            print(f"  enemy_archivist_{tint}_{clip:<7} {count} frames")
    print(f"\n{written} imagesets écrits dans {DST.name}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: Tools_import_water_monster.py <dossier décompressé>")
    main(pathlib.Path(sys.argv[1]))
