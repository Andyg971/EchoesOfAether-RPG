#!/usr/bin/env python3
"""Intègre les packs du dossier « ASSET ECHOES OF AETHER/New » dans le catalogue.

Trois familles, trois traitements :

1. ARBRES ANIMÉS (AnimatedTreeFree / AnimatedTreesUpdates) — bandes
   horizontales de frames 64×64 (ou 128×128 pour les pins). Découpées en
   `{nom}_idle_{i}` pour que `PixelArtSprites.animated` les charge tel quel.
   Le recadrage se fait sur la boîte UNION de toutes les frames, jamais
   frame par frame : sinon chaque image a son propre centre et le sprite
   tressaute d'une frame à l'autre.

2. PERSONNAGES GandalfHardcore — paperdoll : peau + sous-vêtement + bas +
   haut + chaussures + cheveux (+ arme), composés dans l'ordre, sur la
   grille 80×64 commune à toutes les couches (10 colonnes × 7 rangées ;
   rangée 0 = idle, 5 frames). Sert aux figurants du village ET aux PNJ de
   quête, dont les planches d'origine étaient cassées.

3. DÉCOR DE JARDIN (GandalfHardcore FREE) — découpes fixes sur la grille
   32 px de la planche « Garden Decorations ».

Le pack « 8Bit Style Characters (demo) » a été essayé puis retiré : son
style de battler JRPG ne tenait pas à côté du reste du décor. Une seule
pièce est conservée, le chevalier au bouclier, qui devient Dorin.

Les imagesets sont écrits en 1× (`preserve current pixel size` côté Xcode),
`filteringMode = .nearest` étant appliqué à la lecture par PixelArtSprites.
"""
from __future__ import annotations   # `X | None` en annotation sous Python 3.9

from PIL import Image
import json
import pathlib

SRC = pathlib.Path("/Users/gravaandy/Desktop/ASSET ECHOES OF AETHER/New")
DST = pathlib.Path("/Users/gravaandy/Desktop/1 - Projets Apps/AppMaker Studio/"
                   "GameIOS/GDD GAME RPG/EchoesOfAether/EchoesOfAether/Assets.xcassets")

written = 0


def write_imageset(name: str, image: Image.Image) -> None:
    """Écrit (ou remplace) un imageset 1× à partir d'une image RGBA."""
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


def union_box(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    """Boîte englobante COMMUNE à toutes les frames (stabilité de l'anim)."""
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    if not boxes:
        return (0, 0, frames[0].width, frames[0].height)
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def emit_frames(name: str, frames: list[Image.Image], suffix: str = "idle",
                box: tuple[int, int, int, int] | None = None) -> None:
    """Publie une séquence en `{name}_{suffix}_{i}` (base 1), recadrée en bloc.

    `box` force un cadrage commun. C'est indispensable entre l'idle et la
    marche d'un même personnage : deux cadrages différents et le sprite
    change de taille ET de point d'ancrage à l'instant où il se met en
    route — il ferait un bond de côté à chaque pas.
    """
    if box is None:
        box = union_box(frames)
    frames = [f.crop(box) for f in frames]
    for i, frame in enumerate(frames, start=1):
        write_imageset(f"{name}_{suffix}_{i}", frame)
    w, h = frames[0].size
    print(f"  {name:<18} {suffix:<5} {len(frames):>2} frames  {w}×{h}")


# ─────────────────────────────────────────────────────────────────────────
# 1. Arbres animés
# ─────────────────────────────────────────────────────────────────────────

def strip(rel: str, name: str, side: int, count: int, row: int = 0) -> None:
    """Découpe une bande horizontale de `count` frames carrées de `side` px."""
    sheet = Image.open(SRC / rel).convert("RGBA")
    frames = [sheet.crop((i * side, row * side, (i + 1) * side, (row + 1) * side))
              for i in range(count)]
    emit_frames(name, frames)


def import_trees() -> None:
    print("Arbres animés")
    # AnimatedTrees.png empile 5 teintes de 16 frames : rangée 2 = vert froid
    # profond, la seule qui tienne sous la canopée de la Forêt d'Ébène.
    strip("AnimatedTreesUpdates/AnimatedClassicalTrees/AnimatedTrees.png",
          "atree_dark", 64, 16, row=2)
    strip("AnimatedTreesUpdates/AnimatedClassicalTrees/AnimatedTreeCoolColor.png",
          "atree_cool", 64, 16)
    strip("AnimatedTreeFree/AnimatedAutum.png", "atree_autumn", 64, 16)
    # « FallingLeaves » n'est pas un effet mais un arbre d'été COMPLET qui
    # perd ses feuilles : réservé au village, trop clair pour la forêt.
    strip("AnimatedTreesUpdates/FallingLeaves/Summer.png", "atree_leaf", 64, 22)
    strip("AnimatedTreesUpdates/PineTree/PineTreeCoolColor.png",
          "apine_cool", 128, 8)


# ─────────────────────────────────────────────────────────────────────────
# 2. Villageois paperdoll (GandalfHardcore Character Asset Pack)
# ─────────────────────────────────────────────────────────────────────────

PAPER = SRC / "GandalfHardcore Character Asset Pack"
FRAME_W, FRAME_H = 80, 64

# Ordre d'empilement : du corps vers l'extérieur. Une inversion et la
# chemise passe sous la peau.
VILLAGERS = [
    ("gv_farmer", ["Character skin colors/Male Skin2", "Male Clothing/Underwear",
                   "Male Clothing/Pants", "Male Clothing/Shirt",
                   "Male Clothing/Shoes", "Male Hair/Male Hair1"]),
    ("gv_smith", ["Character skin colors/Male Skin4", "Male Clothing/Red Underwear",
                  "Male Clothing/Blue Pants", "Male Clothing/Blue Shirt v2",
                  "Male Clothing/Boots", "Male Hair/Male Hair3"]),
    ("gv_elder", ["Character skin colors/Male Skin1", "Male Clothing/Purple Underwear",
                  "Male Clothing/Purple Pants", "Male Clothing/Purple Shirt v2",
                  "Male Clothing/Shoes", "Male Hair/Male Hair5"]),
    ("gv_guard", ["Character skin colors/Male Skin3", "Male Clothing/Green Underwear",
                  "Male Clothing/Green Pants", "Male Clothing/Green Shirt v2",
                  "Male Clothing/Boots", "Male Hair/Male Hair2",
                  "Male Hand/Male Sword"]),
    ("gv_maid", ["Character skin colors/Female Skin1",
                 "Female Clothing/Skyblue Panties and Bra",
                 "Female Clothing/Skyblue Socks", "Female Clothing/Skirt",
                 "Female Clothing/Blue Corset", "Female Clothing/Boots",
                 "Female Hair/Female Hair1"]),
    ("gv_herbalist", ["Character skin colors/Female Skin3",
                      "Female Clothing/Green Panties and Bra",
                      "Female Clothing/Green Socks", "Female Clothing/Skirt",
                      "Female Clothing/Green Corset", "Female Clothing/Boots",
                      "Female Hair/Female Hair3"]),
    ("gv_weaver", ["Character skin colors/Female Skin4",
                   "Female Clothing/Purple Panties and Bra",
                   "Female Clothing/Purple Socks", "Female Clothing/Skirt",
                   "Female Clothing/Purple Corset v2", "Female Clothing/Boots",
                   "Female Hair/Female Hair4"]),
    ("gv_scout", ["Character skin colors/Female Skin2",
                  "Female Clothing/Red Panties and Bra",
                  "Female Clothing/Red Socks", "Female Clothing/Skirt",
                  "Female Clothing/Orange Corset", "Female Clothing/Boots",
                  "Female Hair/Female Hair2", "Female Hand/Female Sword"]),
]


# PNJ DE QUÊTE — les planches `npc_*` du catalogue étaient des recadrages
# ratés d'une planche source : un énorme toupet suivi de bandes de torse
# hachées. Ils sont refaits ici avec le même paperdoll que les figurants,
# habillés d'après leur PORTRAIT de dialogue (couleur de cheveux, teinte du
# vêtement) — sans ça, l'interlocuteur du dialogue et celui du monde ne se
# ressemblent pas.
#
# Six frames au lieu de cinq : la rangée idle en compte 5, mais tous les
# appelants Swift chargent `frames: 6`. On boucle en aller-retour
# (1,2,3,4,5,4), ce qui donne un cycle plus doux ET zéro modification de
# compte de frames côté code.
QUEST_NPCS = [
    ("npc_bram",["Character skin colors/Male Skin4", "Male Clothing/Orange Underwear",
                  "Male Clothing/Orange Pants", "Male Clothing/orange Shirt v2",
                  "Male Clothing/Boots", "Male Hair/Male Hair1"]),
    ("npc_sage", ["Character skin colors/Male Skin1", "Male Clothing/Skyblue Underwear",
                  "Male Clothing/Blue Pants", "Male Clothing/Blue Shirt v2",
                  "Male Clothing/Shoes", "Male Hair/Male Hair5"]),
    ("npc_garen", ["Character skin colors/Male Skin2", "Male Clothing/Underwear",
                   "Male Clothing/Blue Pants", "Male Clothing/Shirt",
                   "Male Clothing/Boots", "Male Hair/Male Hair2"]),
    ("npc_villager", ["Character skin colors/Male Skin3",
                      "Male Clothing/Green Underwear", "Male Clothing/Green Pants",
                      "Male Clothing/Green Shirt v2", "Male Clothing/Shoes",
                      "Male Hair/Male Hair4"]),
    ("npc_child", ["Character skin colors/Male Skin1",
                   "Male Clothing/Green Underwear", "Male Clothing/Green Pants",
                   "Male Clothing/Green Shirt v2", "Male Clothing/Shoes",
                   "Male Hair/Male Hair1"]),
    ("npc_mara", ["Character skin colors/Female Skin2",
                  "Female Clothing/Purple Panties and Bra",
                  "Female Clothing/Purple Socks", "Female Clothing/Skirt",
                  "Female Clothing/Purple Corset", "Female Clothing/Boots",
                  "Female Hair/Female Hair5"]),
    ("npc_extra", ["Character skin colors/Female Skin1",
                   "Female Clothing/Blue Panties and Bra",
                   "Female Clothing/Skyblue Socks", "Female Clothing/Skirt",
                   "Female Clothing/Blue Corset v2", "Female Clothing/Boots",
                   "Female Hair/Female Hair1"]),
    # Lyra n'utilise ce sprite qu'en repli (son pack de combat passe avant),
    # mais un repli cassé reste cassé le jour où le pack manque.
    ("npc_lyra", ["Character skin colors/Female Skin1",
                  "Female Clothing/Skyblue Panties and Bra",
                  "Female Clothing/Socks", "Female Clothing/Skirt",
                  "Female Clothing/Corset v2", "Female Clothing/Boots",
                  "Female Hair/Female Hair4"]),
]

# Aller-retour sur la rangée idle : 5 frames sources → 6 frames publiées.
# Six et pas cinq parce que TOUS les appelants Swift chargent `frames: 6`,
# et parce qu'un aller-retour respire mieux qu'une boucle qui claque.
PING_PONG = [0, 1, 2, 3, 4, 3]
WALK_ROW = 1          # rangée 1 de la planche = cycle de marche
WALK_FRAMES = 8


def compose(layers: list[str], cache: dict[str, Image.Image],
            order: list[int], row: int = 0) -> list[Image.Image]:
    """Empile les couches du paperdoll pour les frames demandées."""
    frames = []
    for i in order:
        box = (i * FRAME_W, row * FRAME_H, (i + 1) * FRAME_W, (row + 1) * FRAME_H)
        composite = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
        for layer in layers:
            if layer not in cache:
                cache[layer] = Image.open(PAPER / f"{layer}.png").convert("RGBA")
            composite.alpha_composite(cache[layer].crop(box))
        frames.append(composite)
    return frames


def import_paperdoll(name: str, layers: list[str],
                     cache: dict[str, Image.Image]) -> None:
    """Publie l'idle ET la marche d'un personnage, sur un cadrage COMMUN.

    Sans le cycle de marche, un PNJ qui flâne glisse jambes figées — c'est
    ce qui trahissait le plus les figurants du village.
    """
    idle = compose(layers, cache, PING_PONG)
    walk = compose(layers, cache, list(range(WALK_FRAMES)), row=WALK_ROW)
    # La marche écarte les jambes : son cadrage est plus large que l'idle.
    # On prend l'union des deux pour que le sprite garde la même boîte.
    box = union_box(idle + walk)
    emit_frames(name, idle, "idle", box)
    emit_frames(name, walk, "walk", box)


def import_villagers() -> None:
    cache: dict[str, Image.Image] = {}
    print("Villageois figurants")
    for name, layers in VILLAGERS:
        import_paperdoll(name, layers, cache)
    print("PNJ de quête (remplacent les planches cassées)")
    for name, layers in QUEST_NPCS:
        import_paperdoll(name, layers, cache)
    import_dorin()


def import_dorin() -> None:
    """Dorin garde le chevalier du pack 8 bit — le seul qu'on retienne.

    Le chef du village est décrit en « armure dorée » depuis le début : ce
    chevalier au grand bouclier EST cette description. Il a déjà six frames
    d'idle, donc aucun aller-retour à fabriquer.
    """
    folder = SRC / "8Bit Style Characters pack(demo)" / "knight"
    files = sorted(folder.glob("idle*.png"),
                   key=lambda p: int("".join(c for c in p.stem if c.isdigit())))
    frames = [Image.open(p).convert("RGBA") for p in files[:6]]
    if len(frames) != 6:
        print(f"  !! knight : {len(frames)} frames trouvées sur 6")
        return
    emit_frames("npc_dorin", frames)


# ─────────────────────────────────────────────────────────────────────────
# 3. Décor de jardin (GandalfHardcore FREE Platformer Assets)
# ─────────────────────────────────────────────────────────────────────────

# Planche 224×128 sur grille 32 px. Les statues occupent deux rangées, les
# conifères la colonne entière.
GARDEN = [
    ("gh_pot_lilac", (0, 0, 32, 32)),
    ("gh_pot_bush", (32, 0, 64, 32)),
    ("gh_urn_small", (64, 0, 96, 32)),
    ("gh_pot_fern", (0, 32, 32, 64)),
    ("gh_pot_olive", (32, 32, 64, 64)),
    ("gh_urn_large", (64, 32, 96, 64)),
    ("gh_statue_bust", (0, 64, 32, 128)),
    ("gh_pedestal", (32, 64, 64, 128)),
    ("gh_urn_roses", (64, 64, 96, 128)),
    ("gh_urn_spiky", (96, 64, 128, 128)),
    ("gh_cypress", (128, 0, 160, 128)),
    ("gh_conifer", (160, 0, 224, 128)),
]


def import_garden() -> None:
    print("Décor de jardin")
    sheet = Image.open(SRC / "GandalfHardcore FREE Platformer Assets"
                             "/Garden Decorations.png").convert("RGBA")
    for name, box in GARDEN:
        piece = sheet.crop(box)
        bbox = piece.getbbox()
        if bbox is None:
            print(f"  !! {name} : découpe vide")
            continue
        piece = piece.crop(bbox)
        write_imageset(name, piece)
        print(f"  {name:<18}    {piece.width}×{piece.height}")


if __name__ == "__main__":
    import_trees()
    import_villagers()
    import_garden()
    print(f"\n{written} imagesets écrits dans {DST.name}")
