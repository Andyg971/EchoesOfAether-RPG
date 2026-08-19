#!/usr/bin/env python3
"""Importe les décors d'arène en couches (GandalfHardcore Background layers).

Cinq plans de 1024×346, du plus lointain au plus proche :

    5 = ciel (dégradé)      3 = ligne d'arbres lointaine
    4 = montagnes           2 = ligne d'arbres médiane
                            1 = pinède au premier plan

Plus un château posé sur sa colline, à glisser entre le ciel et les arbres.

Trois saisons — normal, automne, hiver — qui donnent une arène différente
par zone au lieu du même aplat noir partout.

Nommage : `arena_<saison>_<n>` où n=5 est le fond et n=1 le premier plan,
et `arena_<saison>_castle`.
"""
from __future__ import annotations

from PIL import Image
import json
import pathlib

SRC = pathlib.Path("/Users/gravaandy/Desktop/ASSET ECHOES OF AETHER/New/"
                   "GandalfHardcore FREE Platformer Assets/"
                   "GandalfHardcore Background layers")
DST = pathlib.Path("/Users/gravaandy/Desktop/1 - Projets Apps/AppMaker Studio/"
                   "GameIOS/GDD GAME RPG/EchoesOfAether/EchoesOfAether/Assets.xcassets")

# (dossier source, suffixe cible, nom du fichier château)
SEASONS = [
    ("Normal BG", "normal", "Background Castle .png"),
    ("Autumn BG", "autumn", "Background Castle Autumn.png"),
    ("Winter BG", "winter", "Background Castle  Winter.png"),
]

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


def main() -> None:
    for folder, season, castle in SEASONS:
        base = SRC / folder
        for n in range(1, 6):
            src = base / f"GandalfHardcore Background layers_layer {n}.png"
            if not src.exists():
                print(f"  !! {season} couche {n} introuvable")
                continue
            write_imageset(f"arena_{season}_{n}", Image.open(src).convert("RGBA"))
        castle_path = base / castle
        if castle_path.exists():
            write_imageset(f"arena_{season}_castle",
                           Image.open(castle_path).convert("RGBA"))
        else:
            print(f"  !! château {season} introuvable ({castle})")
        print(f"  arena_{season}_1..5 + château")
    print(f"\n{written} imagesets écrits dans {DST.name}")


if __name__ == "__main__":
    main()
