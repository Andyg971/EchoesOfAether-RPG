#!/usr/bin/env python3
"""Intègre les portraits fournis par Andy en 44x44 pour la boîte de dialogue.

Les sources sont des illustrations pixel art en 784x1168 : le personnage est
cadré en buste, tête dans le tiers supérieur. On recadre sur le visage puis on
réduit — en LANCZOS pour la descente (une réduction au plus proche voisin sur
un facteur ~10 jette 9 pixels sur 10 et détruit le dessin), suivi d'une
quantification à palette réduite qui rend au résultat sa dureté pixel art.
"""
from PIL import Image
import pathlib, json

SRC = pathlib.Path("/Users/gravaandy/Desktop/ASSET ECHOES OF AETHER/portraits")
DST = pathlib.Path("/Users/gravaandy/Desktop/1 - Projets Apps/AppMaker Studio/"
                   "GameIOS/GDD GAME RPG/EchoesOfAether/EchoesOfAether/Assets.xcassets")
SIDE = 44

# (fichier source, imageset cible, centre du visage en fractions (x, y),
#  hauteur du cadre en fraction de l'image)
JOBS = [
    ("lyra.jpg",  "portrait_lyra",       0.47, 0.40, 0.50),
    ("dorin.jpg", "portrait_dorin",      0.50, 0.38, 0.50),
    ("Eren.jpg",  "portrait_eran",       0.45, 0.40, 0.50),
]

def crop_face(im, cx, cy, frac):
    w, h = im.size
    side = int(h * frac)
    x = int(w * cx - side / 2)
    y = int(h * cy - side / 2)
    x = max(0, min(x, w - side))
    y = max(0, min(y, h - side))
    return im.crop((x, y, x + side, y + side))

for src_name, target, cx, cy, frac in JOBS:
    src = SRC / src_name
    if not src.exists():
        print(f"!! introuvable : {src_name}")
        continue
    im = Image.open(src).convert("RGB")
    face = crop_face(im, cx, cy, frac)

    # Descente en deux temps : LANCZOS conserve les traits, puis la
    # quantification (32 couleurs, sans tramage) rend l'aspect pixel net.
    small = face.resize((SIDE, SIDE), Image.LANCZOS)
    small = small.quantize(colors=32, dither=Image.NONE).convert("RGBA")

    iset = DST / f"{target}.imageset"
    iset.mkdir(exist_ok=True)
    for old in iset.glob("*.png"):
        old.unlink()
    small.save(iset / f"{target}.png")
    (iset / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{target}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }, indent=2))
    colors = len({small.getpixel((x, y)) for x in range(SIDE) for y in range(SIDE)})
    print(f"{target:22} <- {src_name:10} crop {face.size[0]}px -> 44x44, {colors} couleurs")
