# Palette — état des lieux et convergence

> Audit des couleurs d'`Echoes of Aether`, et ce qu'il reste à trancher.

## Le constat

Un relevé de tous les `SKColor(red:green:blue:alpha:)` du projet a donné :

**650 valeurs RGBA distinctes pour 753 usages.**

Autrement dit, presque chaque couleur du jeu n'est employée qu'une seule fois.
En pixel art c'est exactement l'inverse de ce qu'on cherche : c'est la palette
restreinte qui fait qu'un jeu ressemble à un monde plutôt qu'à un assemblage de
zones peintes séparément. Ça ne se voit pas sur une capture isolée — ça se voit
en jouant d'affilée, quand on passe d'un décor à l'autre et que rien ne « rime ».

Mais ces 650 valeurs ne sont pas 650 intentions. En les regroupant par
proximité (distance RGB < 0,13), le motif saute aux yeux : ce sont quelques
couleurs voulues, **retapées de mémoire à chaque nouveau fichier**.

## Ce qui a déjà été fait

`EchoesOfAether/Models/Palette.swift` nomme les 15 valeurs qui se répétaient
**à l'identique** (55 usages) et les appels sont passés par ces jetons.

C'est un refactor à **zéro changement visuel** : aucune valeur n'a été
modifiée, seulement nommée. Après migration, plus aucun littéral n'est répété
3 fois ou plus dans le projet.

Ce que ça change concrètement : ces 55 points sont désormais reliés. Changer
l'or du jeu est devenu une ligne au lieu d'une chasse dans 28 700 lignes.

## Ce qui reste à trancher — et pourquoi ce n'est pas du refactoring

Il reste **636 valeurs pour 698 usages**. Les faire converger n'est pas une
tâche mécanique : décider que ces quatre ors n'en font qu'un, c'est une
décision de direction artistique. Elle appartient à l'auteur du jeu, pas à
l'outil qui la mesure.

Voici où elle se joue. Chaque ligne est **une couleur voulue** éparpillée en N
variantes :

| Couleur | Usages | Variantes | Principaux fichiers |
|---------|--------|-----------|---------------------|
| `#190F0C` noir chaud | 99 | 92 | `CombatSystem`, `GameManager+Act2`, `GameManager` |
| `#212128` gris nuit | 36 | 31 | `CombatSystem`, `CombatSprites`, `MainMenuScene` |
| `#8CCCFF` bleu clair | 23 | 18 | `CombatSystem`, `GameManager+Desert`, `GameManager+Fishing` |
| `#664C2D` brun doré | 22 | 20 | `PixelFX`, `WorldBuilder`, `WorldNode` |
| `#F2C64C` or | 19 | 15 | `CombatSystem`, `GameManager`, `WorldBuilder` |
| `#332D42` violet ardoise | 16 | 15 | `GameManager`, `DialogueSystem`, `CombatSprites` |
| `#FFD833` or vif | 14 | 10 | `CombatSystem`, `CombatSprites`, `MainMenuScene` |
| `#A572FF` violet Aether | 13 | 12 | `GameManager`, `DialogueSystem`, `MainMenuScene` |
| `#997F3F` or sombre | 11 | 10 | `CombatSystem`, `GameManager+Cave`, `DialogueSystem` |
| `#B2EAFF` bleu glace | 10 | 7 | `CombatSystem`, `WorldBuilder`, `LightingEngine` |

Le cas le plus parlant est le premier : **92 variantes pour un seul noir
chaud**. Personne n'a choisi 92 noirs — le même noir a été réécrit 92 fois.

## L'or, cas d'école

Quatre valeurs pour la même couleur, réparties par **fichier** et non par
intention — le monde et le combat ont chacun redéfini « l'or » de leur côté :

| Valeur | Où | Jeton |
|--------|-----|-------|
| `0.98 / 0.82 / 0.32` | `WorldBuilder`, `GameManager+Desert` | `Palette.gold` |
| `1.00 / 0.85 / 0.30` | `WorldBuilder`, `GameManager`, `+Forest` | `Palette.goldWorld` |
| `1.00 / 0.82 / 0.35` | `CombatSystem` | `Palette.goldCombat` |
| `1.00 / 0.80 / 0.20` | `CombatSystem` | `Palette.goldCombatBright` |

Ils sont nommés plutôt que fusionnés : la dérive est ainsi **visible dans le
code** au lieu d'être noyée dans 698 littéraux. Le jour où la décision est
prise, elle tient en trois lignes de `Palette.swift`.

## La marche à suivre proposée

1. **Ouvrir le jeu et regarder.** Rien de ce qui suit ne se décide sur des
   chiffres — c'est le seul point qu'aucun audit ne remplace.
2. **Trancher les quatre ors.** Un seul `Palette.gold` ; supprimer les trois
   variantes en pointant leurs jetons vers lui, puis vérifier en jeu.
3. **Attaquer les grappes par le haut du tableau.** Le noir chaud (99 usages)
   et le gris nuit (36) sont des fonds : les converger est peu risqué et se
   voit immédiatement sur la cohérence d'ensemble.
4. **Faire descendre le compteur.** L'objectif d'une palette pixel art tient
   généralement entre 24 et 32 couleurs. Le relevé se rejoue à tout moment
   pour mesurer le progrès.

```bash
# Relever les couleurs restantes et leurs grappes
grep -rho "SKColor(red: [0-9.]*, green: [0-9.]*, blue: [0-9.]*, alpha: [0-9.]*)" \
  --include=*.swift EchoesOfAether/ | sort | uniq -c | sort -rn | head -30
```

## Ce qui n'est pas concerné

Les 711 imagesets (sprites LimeZu, tuiles, portraits) ont leur propre palette,
celle de leurs auteurs — elle est cohérente et n'est pas en cause. Le sujet ici
est uniquement le **dessin en code** : formes, FX, interface, éclairage.
